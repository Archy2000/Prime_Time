"""Read-only Unity extraction; emits standard glTF and traceable material metadata."""
import sys,json,re,struct,io,hashlib
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).parent/'python_libs'))
import UnityPy
from UnityPy.helpers.MeshHelper import MeshHandler

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets'/'extracted'; OUT.mkdir(parents=True,exist_ok=True)
env=UnityPy.load(r'D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data')
doc={'asset':{'version':'2.0','generator':'Prime Time Unity resource converter'},'scene':0,'scenes':[{'nodes':[]}], 'nodes':[], 'meshes':[], 'materials':[], 'textures':[], 'images':[], 'samplers':[{'magFilter':9728,'minFilter':9728,'wrapS':10497,'wrapT':10497}], 'buffers':[], 'bufferViews':[], 'accessors':[]}
buf=bytearray(); mesh_cache={}; geo_cache={}; mat_cache={}; tex_cache={}; records=[]; problems=[]
def key(p):
    o=p.deref() if hasattr(p,'deref') else p
    return f'{o.assets_file.name}:{o.path_id}'
def safe(s): return re.sub(r'[^a-zA-Z0-9_-]','_',s)[:65]
def accessor(arr,typ,component=5126):
    arr=np.asarray(arr,dtype=np.float32 if component==5126 else np.uint32)
    while len(buf)%4:buf.append(0)
    start=len(buf);buf.extend(arr.tobytes())
    v=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':arr.nbytes})
    a={'bufferView':v,'componentType':component,'count':len(arr),'type':typ}
    if typ=='VEC3':a.update(min=arr.min(axis=0).tolist(),max=arr.max(axis=0).tolist())
    idx=len(doc['accessors']);doc['accessors'].append(a);return idx
def texture(p):
    k=key(p)
    if k in tex_cache:return tex_cache[k]
    t=p.read();filename=f'{safe(t.m_Name)}_{p.path_id}.png'
    t.image.save(OUT/filename)
    idx=len(doc['images']);doc['images'].append({'uri':filename})
    doc['textures'].append({'source':idx,'sampler':0});tex_cache[k]=idx;return idx
def material(p):
    if not p.path_id:return None
    k=key(p)
    if k in mat_cache:return mat_cache[k]
    d=p.read();tree=p.deref().read_typetree();props=tree['m_SavedProperties']
    colors=dict(props.get('m_Colors',[]));floats=dict(props.get('m_Floats',[]))
    c=colors.get('_Color',colors.get('_BaseColor',{'r':1,'g':1,'b':1,'a':1}))
    color=[max(0,min(1,c[x])) for x in 'rgba'];color[3]=1
    m={'name':d.m_Name,'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':color,'metallicFactor':0,'roughnessFactor':0.95}}
    for name,te in d.m_SavedProperties.m_TexEnvs:
        if name in ('_MainTex','_BaseMap') and te.m_Texture.path_id:
            m['pbrMetallicRoughness']['baseColorTexture']={'index':texture(te.m_Texture)};break
    if any(w in d.m_Name.lower() for w in ['leaves','fence','grass','shadow','windowplane']):
        m.update(alphaMode='MASK',alphaCutoff=0.4)
    idx=len(doc['materials']);doc['materials'].append(m);mat_cache[k]=idx;return idx
def mesh(p,materials):
    k=(key(p),tuple(key(m) if m.path_id else '' for m in materials))
    if k in mesh_cache:return mesh_cache[k]
    gkey=key(p);m=p.read()
    if gkey not in geo_cache:
        h=MeshHandler(m);h.process()
        v=np.array(h.m_Vertices,dtype=np.float32)[:,:3];v[:,0]*=-1
        attrs={'POSITION':accessor(v,'VEC3')}
        if h.m_Normals:
            n=np.array(h.m_Normals,dtype=np.float32)[:,:3];n[:,0]*=-1;attrs['NORMAL']=accessor(n,'VEC3')
        if h.m_UV0:
            uv=np.array(h.m_UV0,dtype=np.float32)[:,:2];uv[:,1]=1-uv[:,1];attrs['TEXCOORD_0']=accessor(uv,'VEC2')
        if h.m_Colors:
            colors=np.asarray(h.m_Colors,dtype=np.float32)
            if colors.max()>1.01:colors/=255.0
            # Unity mesh colors are authored in display space; glTF vertex colors are linear.
            colors[:,:3]=np.where(colors[:,:3]<=0.04045,colors[:,:3]/12.92,((colors[:,:3]+0.055)/1.055)**2.4)
            colors[:,3]=1.0
            attrs['COLOR_0']=accessor(colors,'VEC4')
        indices=[]
        for tri in h.get_triangles():
            a=np.array(tri,dtype=np.uint32)
            indices.append(accessor(a[:,::-1].flatten(),'SCALAR',5125) if a.size else None)
        geo_cache[gkey]=(attrs,indices,v.min(axis=0).tolist(),v.max(axis=0).tolist())
    attrs,indices,lo,hi=geo_cache[gkey]
    prim=[]
    for i,a in enumerate(indices):
        if a is None:continue
        pr={'attributes':attrs,'indices':a,'mode':4}
        if materials:
            mi=material(materials[min(i,len(materials)-1)])
            if mi is not None:pr['material']=mi
        prim.append(pr)
    idx=len(doc['meshes']);doc['meshes'].append({'name':m.m_Name,'primitives':prim});mesh_cache[k]=idx
    return idx
def trs(t):
    q=t.m_LocalRotation;x,y,z,w=q.x,q.y,q.z,q.w
    r=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)], [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)], [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    a=np.eye(4);s=t.m_LocalScale;a[:3,:3]=r@np.diag([s.x,s.y,s.z]);p=t.m_LocalPosition;a[:3,3]=[p.x,p.y,p.z];return a
F=np.diag([-1,1,1,1])
def walk(ptr,parent=np.eye(4),path=''):
    t=ptr.read();g=t.m_GameObject.read()
    if not g.m_IsActive:return
    path=path+'/'+g.m_Name;world=parent@trs(t)
    comp={}
    for item in g.m_Component:
        p=item.component
        try:comp[p.deref().type.name]=p.read()
        except:pass
    if 'MeshFilter' in comp and 'MeshRenderer' in comp:
        mf=comp['MeshFilter'];mr=comp['MeshRenderer']
        if mr.m_Enabled and mf.m_Mesh.path_id and abs(world[0,3])<310 and -400<world[2,3]<250:
            try:
                mat=F@world@F
                mi=mesh(mf.m_Mesh,mr.m_Materials)
                node={'name':f'{safe(g.m_Name)}__{ptr.path_id}','matrix':mat.T.flatten().tolist(),'mesh':mi}
                idx=len(doc['nodes']);doc['nodes'].append(node);doc['scenes'][0]['nodes'].append(idx)
                bounds=geo_cache[key(mf.m_Mesh)][2:]
                records.append({'node':node['name'],'name':g.m_Name,'path':path,'matrix':mat.T.flatten().tolist(),'bounds':bounds,'mesh':doc['meshes'][mi]['name'],'source':key(mf.m_Mesh),'collider':any(n in comp for n in ('BoxCollider','MeshCollider'))})
            except Exception as e:problems.append([path,str(e)])
    for p in t.m_Children:walk(p,world,path)
for obj in env.objects:
    if obj.type.name=='Transform' and obj.assets_file.name=='level2' and obj.path_id==14213:
        walk(obj)
doc['buffers']=[{'byteLength':len(buf),'uri':'rolla_city.bin'}]
(OUT/'rolla_city.bin').write_bytes(buf)
(OUT/'rolla_city.gltf').write_text(json.dumps(doc,separators=(',',':')))
(ROOT/'assets'/'city_metadata.json').write_text(json.dumps(records,separators=(',',':')))

# Water texture: keep actual source normal-map data and a conventional RGB normal derivative.
senv=UnityPy.load(r'D:\SteamLibrary\steamapps\common\Sandcastle Demo\Sandcastle_Data')
water={}
for obj in senv.objects:
    if obj.type.name=='Material' and obj.read().m_Name=='Water':
        water=obj.read_typetree()
        for name,t in obj.read().m_SavedProperties.m_TexEnvs:
            if name=='waterNormalMap' and t.m_Texture.path_id:
                tex=t.m_Texture.read();im=tex.image.convert('RGBA');im.save(OUT/'sandcastle_water_normal_raw.png')
                arr=np.asarray(im).astype(np.float32)/255
                # Unity DXT5nm uses A*R and G; this also handles unpacked RGB normals.
                x=arr[:,:,0]*arr[:,:,3]*2-1;y=arr[:,:,1]*2-1;z=np.sqrt(np.maximum(0,1-x*x-y*y))
                from PIL import Image
                rgb=np.stack([x*.5+.5,y*.5+.5,z*.5+.5],axis=-1)
                Image.fromarray((rgb*255).astype('uint8')).save(OUT/'sandcastle_water_normal.png')
                water['source_texture']={'name':tex.m_Name,'width':tex.m_Width,'height':tex.m_Height,'id':t.m_Texture.path_id}
(ROOT/'research'/'water_source.json').write_text(json.dumps(water,indent=2))
report={'instances':len(records),'mesh_variants':len(doc['meshes']),'unique_meshes':len(geo_cache),'materials':len(mat_cache),'textures':len(tex_cache),'errors':problems}
(ROOT/'research'/'extraction_report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
