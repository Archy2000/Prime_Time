"""Additional source fracture parts, particles and baked civilian meshes."""
from pathlib import Path
code=Path('tools/extract_scene.py').read_text(encoding='utf-8').split('\nfor obj in env.objects:')[0]
exec(compile(code,'tools/extract_scene.py','exec'))
# Isolate additions: existing city files are not rewritten.
OUT=ROOT/'assets'/'effects';OUT.mkdir(parents=True,exist_ok=True)
used=set();rows=[]
world_cache={}
def world_for(p):
    k=key(p)
    if k in world_cache:return world_cache[k]
    t=p.read();w=trs(t)
    if t.m_Father.path_id:w=world_for(t.m_Father)@w
    world_cache[k]=w;return w
for obj in env.objects:
    if obj.type.name=='MeshFilter':
        d=obj.read()
        if not d.m_Mesh.path_id:continue
        m=d.m_Mesh.read();n=m.m_Name
        if n in used or not ('_cell' in n or n in ('rubbleparticle','rubble_asphalt','rubbleparticle_simple','murut')):continue
        g=d.m_GameObject.read();mr=None;t=None
        for c in g.m_Component:
            kind=c.component.deref().type.name
            if kind=='MeshRenderer':mr=c.component.read()
            if kind=='Transform':t=c.component.read()
        if not mr:continue
        mi=mesh(d.m_Mesh,mr.m_Materials)
        idx=len(doc['nodes']);doc['nodes'].append({'name':n,'mesh':mi});doc['scenes'][0]['nodes'].append(idx);used.add(n)
        rows.append({'name':n,'source':key(d.m_Mesh),'bounds':geo_cache[key(d.m_Mesh)][2:]})
    if obj.type.name=='Material':
        d=obj.read()
        if d.m_Name in ('smoke_bally','smoke_smudgy','cartoonSmoke_alphaBlend','EnemyBlood','liquidfire2_3x3','decal_explode_alphaBlend'):
            for name,t in d.m_SavedProperties.m_TexEnvs:
                if name=='_MainTex' and t.m_Texture.path_id:
                    tex=t.m_Texture.read();tex.image.save(OUT/f'{safe(tex.m_Name)}.png')
    if obj.type.name=='AudioClip':
        d=obj.read()
        rows.append({'audio':d.m_Name,'id':obj.path_id,'file':obj.assets_file.name})
        if d.m_Name in ('buildingCrumble','carbreak','qdeath1','qdeath3','button_squiish','dash_mid'):
            try:
                for fn,data in d.samples.items():
                    (OUT/f'{safe(d.m_Name)}.wav').write_bytes(data);break
            except Exception as e:print('Audio decode skipped',d.m_Name,str(e)[:160])
    if obj.type.name=='SkinnedMeshRenderer':
        d=obj.read()
        if not d.m_Mesh.path_id:continue
        n=d.m_Mesh.read().m_Name
        if n not in ('man_casual','man_business','woman_scientist') or n in used:continue
        g=d.m_GameObject.read()
        tp=next(c.component for c in g.m_Component if c.component.deref().type.name=='Transform')
        mat=F@world_for(tp)@F;mat[:3,3]=0
        mi=mesh(d.m_Mesh,d.m_Materials)
        idx=len(doc['nodes']);doc['nodes'].append({'name':n,'mesh':mi,'matrix':mat.T.flatten().tolist()});doc['scenes'][0]['nodes'].append(idx);used.add(n)
doc['buffers']=[{'byteLength':len(buf),'uri':'fracture_parts.bin'}]
(OUT/'fracture_parts.bin').write_bytes(buf)
(OUT/'fracture_parts.gltf').write_text(json.dumps(doc,separators=(',',':')))
(ROOT/'research'/'effects_sources.json').write_text(json.dumps(rows,indent=2))
print('Exported',len(used),'fracture meshes')
print([r for r in rows if 'audio' in r])
