"""Build original, continuously fused shark mutations as GLB assets.

The body, necks, skulls and fins are one smooth-union isosurface. Mouths
are carved into that surface, not black balls stuck on its exterior.
Requires numpy and scikit-image; see docs/MULTIHEAD_ART.md.
"""
from pathlib import Path
import json, math, struct, sys
import numpy as np
from skimage.measure import marching_cubes

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/mutations"
OUT.mkdir(parents=True, exist_ok=True)
STEP = 0.035

def smooth(a, b, k=.14):
    h = np.maximum(k-np.abs(a-b), 0)/k
    return np.minimum(a,b)-h*h*k*.25

def ellipsoid(p, c, radii):
    q=(p-np.array(c,dtype=np.float32))/np.array(radii,dtype=np.float32)
    return (np.linalg.norm(q,axis=-1)-1)*min(radii)

def capsule(p,a,b,ra,rb):
    a=np.asarray(a);v=np.asarray(b)-a
    t=np.clip(np.sum((p-a)*v,axis=-1)/np.dot(v,v),0,1)
    return np.linalg.norm(p-a-t[...,None]*v,axis=-1)-(ra+(rb-ra)*t)

def triangle(p,a,b,c,thickness):
    a,b,c=map(np.asarray,(a,b,c));n=np.cross(b-a,c-a);n=n/np.linalg.norm(n)
    distance=np.sum((p-a)*n,axis=-1)
    projection=p-distance[...,None]*n
    inside=np.ones(p.shape[:-1],bool)
    edge_dist=np.full(p.shape[:-1],1e6,dtype=np.float32)
    for u,v in [(a,b),(b,c),(c,a)]:
        edge=v-u;t=np.clip(np.sum((p-u)*edge,axis=-1)/np.dot(edge,edge),0,1)
        edge_dist=np.minimum(edge_dist,np.linalg.norm(p-u-t[...,None]*edge,axis=-1))
        inside &= np.sum(np.cross(v-u,projection-u)*n,axis=-1)>=-1e-7
    return np.where(inside,np.abs(distance),edge_dist)-thickness

def heads_for(count):
    if count==2:
        specs=[(-.64,-1.00,-.22),(.64,-1.00,.22)]
    else:
        specs=[(0,-1.10,0)]
        if count==3:specs += [(-.79,-.88,-.52),(.79,-.88,.52)]
        if count==5:specs += [(-.79,-.84,-.50),(.79,-.84,.50),(-1.00,-.12,-1.13),(1.00,-.12,1.13)]
        if count==9:specs += [(-.78,-.89,-.46),(.78,-.89,.46),(-1.14,-.28,-1.0),(1.14,-.28,1.0),(-1.18,.37,-1.55),(1.18,.37,1.55),(-.94,.98,-2.12),(.94,.98,2.12)]
    heads=[]
    for i,(x,z,angle) in enumerate(specs):
        forward=np.array([math.sin(angle),0,-math.cos(angle)],np.float32)
        right=np.array([math.cos(angle),0,math.sin(angle)],np.float32)
        scale=1.0 if i==0 or count==2 else .86 if count<9 else .78
        heads.append(dict(center=np.array([x,.025,z],np.float32),forward=forward,right=right,scale=scale,angle=angle))
    return heads

def local(p,h):
    q=(p-h['center'])/h['scale']
    return np.stack([q@h['right'],q[...,1],-(q@h['forward'])],axis=-1)

def world(q,h):
    q=np.asarray(q)
    return h['center']+h['scale']*(q[...,0,None]*h['right']+q[...,1,None]*np.array([0,1,0])-q[...,2,None]*h['forward'])

def field(p,heads):
    d=ellipsoid(p,(0,0,.34),(.58,.35,1.07))
    d=smooth(d,capsule(p,(0,0,.90),(0,.015,1.91),.28,.065),.13)
    # Widened scapular mass under every branch; no exposed neck-end seams.
    for h in heads:
        c=h['center'];attach=np.array([0,0,np.clip(c[2]+.45,-.25,.85)])
        base=c-h['forward']*.28
        d=smooth(d,capsule(p,attach,base,.31,.265*h['scale']),.21)
        q=local(p,h)
        skull=ellipsoid(q,(0,.04,-.16),(.31,.28,.60))*h['scale']
        # Blunt rostrum and broad cheeks, tapering smoothly into the neck.
        snout=ellipsoid(q,(0,.045,-.62),(.24,.16,.32))*h['scale']
        head=smooth(skull,snout,.09)
        jaw=ellipsoid(q,(0,-.225,-.39),(.255,.105,.52))*h['scale']
        head=smooth(head,jaw,.045)
        d=smooth(d,head,.13)
    # Fins also belong to the same remeshed surface.
    fins=[((0,.21,.03),(0,1.0,.60),(0,.22,.88),.032),
          ((0,0,1.77),(0,.80,2.42),(0,.045,2.18),.025),
          ((0,0,1.78),(0,-.37,2.27),(0,-.03,2.16),.025)]
    for side in [-1,1]:
        fins += [((side*.34,-.08,-.05),(side*1.13,-.25,.76),(side*.37,-.12,.61),.031),
                 ((side*.23,-.11,1.05),(side*.55,-.22,1.49),(side*.18,-.11,1.47),.02)]
    for a,b,c,t in fins:d=smooth(d,triangle(p,a,b,c,t),.065)
    # Mouth tunnel opens out through the front and sides while the jaw hinge
    # remains part of the same manifold body. This is not a separate head cap.
    for h in heads:
        q=local(p,h)
        cavity=ellipsoid(q,(0,-.115,-.73),(.31,.097,.48))*h['scale']
        d=np.maximum(d,-cavity)
    return d

def attributes(p,heads,detail_color=None,skin=1,surface_normals=None):
    nearest=np.zeros(len(p),np.int32);distance=np.full(len(p),1e6)
    for i,h in enumerate(heads):
        q=local(p,h);d=np.linalg.norm(q*np.array([1,1,.62]),axis=-1)
        take=d<distance;nearest[take]=i;distance[take]=d[take]
    uv=np.zeros((len(p),2),np.float32);uv2=np.zeros((len(p),2),np.float32);uv2[:,0]=skin
    belly=np.clip((.055-p[:,1])/.17,0,1)
    if surface_normals is not None:belly*=np.clip((.3-surface_normals[:,1])/.55,0,1)
    colors=np.array([.24,.32,.35])*(1-belly[:,None])+np.array([.74,.77,.72])*belly[:,None]
    for i,h in enumerate(heads):
        mask=nearest==i;q=local(p[mask],h)
        weight=np.clip((.4-q[:,2])/.85,0,1)
        # Only the end of the head sways; roots are fixed in the shared torso.
        weight*=np.clip(1.3-np.linalg.norm(q[:,:2],axis=-1),0,1)
        uv[mask,0]=i;uv[mask,1]=weight
        jaw=(q[:,1]<-.13)*np.clip((.03-q[:,2])/.5,0,1)
        uv2[mask,1]=jaw*.7*h['scale']
        mouth=(q[:,2]<-.30)&(q[:,1]<-.02)&(q[:,1]>-.30)&(np.abs(q[:,0])<.225)
        indices=np.flatnonzero(mask)[mouth]
        colors[indices]=[.105,.028,.035];uv2[indices,0]=.05
    # Tail must not inherit the last rear-facing head's swaying weight.
    uv[p[:,2]>1.35,1]=0
    if detail_color is not None:colors[:]=detail_color
    return np.column_stack([np.clip(colors,0,1),np.ones(len(p))]).astype(np.float32),uv,uv2

def sphere(center,radii):
    vertices=[];faces=[]
    for j in range(9):
        a=math.pi*j/8
        for k in range(12):
            b=2*math.pi*k/12;vertices.append(np.asarray(center)+np.asarray(radii)*[math.sin(a)*math.cos(b),math.cos(a),math.sin(a)*math.sin(b)])
    for j in range(8):
        for k in range(12):
            a=j*12+k;b=j*12+(k+1)%12;faces.extend([(a,b,a+12),(b,b+12,a+12)])
    return np.array(vertices),np.array(faces)

def tooth(center,length,direction=1):
    c=np.asarray(center);vertices=[c+[0,length*direction,0],c+[-.024,0,0],c+[.024,0,0],c+[0,0,.028],c+[0,0,-.028]]
    faces=[(0,1,3),(0,3,2),(0,2,4),(0,4,1),(1,4,2),(1,2,3)]
    return np.array(vertices),np.array(faces)

def normals(vertices,faces):
    n=np.zeros_like(vertices);f=np.cross(vertices[faces[:,1]]-vertices[faces[:,0]],vertices[faces[:,2]]-vertices[faces[:,0]])
    for col in range(3):np.add.at(n,faces[:,col],f)
    return n/np.maximum(1e-8,np.linalg.norm(n,axis=1))[:,None]

def write_glb(path,v,f,n,color,uv,uv2):
    blob=bytearray();views=[];accessors=[]
    def array(a,component,kind):
        while len(blob)%4:blob.append(0)
        raw=a.tobytes();offset=len(blob);blob.extend(raw)
        views.append(dict(buffer=0,byteOffset=offset,byteLength=len(raw)))
        acc=dict(bufferView=len(views)-1,componentType=component,count=len(a),type=kind)
        if kind=='VEC3':acc.update(min=a.min(0).tolist(),max=a.max(0).tolist())
        accessors.append(acc);return len(accessors)-1
    pos=array(v.astype('<f4'),5126,'VEC3');normal=array(n.astype('<f4'),5126,'VEC3');col=array(color.astype('<f4'),5126,'VEC4');tex=array(uv.astype('<f4'),5126,'VEC2');tex2=array(uv2.astype('<f4'),5126,'VEC2');idx=array(f.astype('<u4').ravel(),5125,'SCALAR')
    data=dict(asset=dict(version='2.0',generator='Flooded City original implicit creature builder'),scene=0,scenes=[dict(nodes=[0])],nodes=[dict(mesh=0,name='UnifiedHydra')],meshes=[dict(primitives=[dict(attributes=dict(POSITION=pos,NORMAL=normal,COLOR_0=col,TEXCOORD_0=tex,TEXCOORD_1=tex2),indices=idx,material=0)])],materials=[dict(name='SharkSkin',pbrMetallicRoughness=dict(baseColorFactor=[1,1,1,1],metallicFactor=0,roughnessFactor=.52),doubleSided=True)],buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    js=json.dumps(data,separators=(',',':')).encode();js+=b' '*((-len(js))%4);blob+=b'\0'*((-len(blob))%4)
    path.write_bytes(struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(blob))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(blob),0x004E4942)+blob)

def build(count):
    heads=heads_for(count)
    lower=np.array([-2.45,-.52,-2.35],np.float32);upper=np.array([2.45,1.15,2.55])
    axes=[np.arange(a,b+STEP,STEP,dtype=np.float32) for a,b in zip(lower,upper)]
    grid=np.stack(np.meshgrid(*axes,indexing='ij'),axis=-1)
    values=field(grid.reshape(-1,3),heads).reshape(grid.shape[:-1])
    v,f,_,_=marching_cubes(values,0,spacing=(STEP,)*3,allow_degenerate=False);v+=lower
    # Exact central-difference normals keep the union visually smooth.
    epsilon=.002;grad=[]
    for axis in range(3):
        d=np.eye(3)[axis]*epsilon;grad.append(field(v+d,heads)-field(v-d,heads))
    n=np.stack(grad,axis=1);n/=np.maximum(1e-8,np.linalg.norm(n,axis=1))[:,None]
    body_vertices=len(v);body_faces=len(f)
    col,uv,uv2=attributes(v,heads,surface_normals=n)
    for h in heads:
        # Inset black lateral eyes, small catchlights, and anatomical gill slits.
        details=[]
        for side in [-1,1]:
            details.append((*sphere([side*.285,.115,-.26],[.045,.043,.052]),[.012,.018,.019],0))
            details.append((*sphere([side*.314,.131,-.272],[.008,.01,.014]),[.62,.71,.7],0))
            for gill in range(5):
                z=.035+gill*.055
                details.append((*sphere([side*(.288-gill*.013),.015,z],[.009,.12-gill*.007,.012]),[.095,.13,.14],0))
            for row in range(2):
                for t in np.linspace(.18,.92,7):
                    z=-.36-.43*t
                    jaw_width=.255*math.sqrt(max(.05,1-((z+.39)/.52)**2))
                    x=side*(jaw_width*.90-row*.018)
                    length=.055 if row==0 else .033
                    details.append((*tooth([x,-.007,z],length,-1),[.88,.86,.73],0))
                    details.append((*tooth([x,-.235,z+.012],length,.95),[.82,.81,.7],0))
        for vertices,faces,color,skin in details:
            vertices=world(vertices,h);face_normals=normals(vertices,faces)
            colors,a,b=attributes(vertices,heads,color,skin)
            f=np.concatenate([f,faces+len(v)]);v=np.concatenate([v,vertices]);n=np.concatenate([n,face_normals]);col=np.concatenate([col,colors]);uv=np.concatenate([uv,a]);uv2=np.concatenate([uv2,b])
    write_glb(OUT/f'hydra_{count}.glb',v,f,n,col,uv,uv2)
    mouths=[world([0,-.12,-.72],h).tolist() for h in heads]
    report=dict(heads=count,body_vertices=body_vertices,body_triangles=body_faces,total_triangles=len(f),mouths=mouths)
    print(json.dumps(report),flush=True)
    return report

if __name__=='__main__':
    reports={str(n):build(n) for n in [2,3,5,9]}
    (OUT/'anatomy.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
