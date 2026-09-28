"""Read-only ROLLA NPC export. Keeps model/texture provenance in research/npc_sources.json."""
from pathlib import Path
code=Path('tools/extract_scene.py').read_text(encoding='utf-8').split('\nfor obj in env.objects:')[0]
exec(compile(code,'tools/extract_scene.py','exec'))
OUT=ROOT/'assets'/'characters'/'humans';OUT.mkdir(parents=True,exist_ok=True)
used=set();rows=[]; armed_parts={}
for obj in env.objects:
 if obj.type.name not in ('SkinnedMeshRenderer','MeshFilter'):continue
 d=obj.read()
 if not d.m_Mesh.path_id:continue
 n=d.m_Mesh.read().m_Name
 civilian=n.startswith(('man_','woman_'))
 armed=n.startswith(('enemy_cop','enemy_soldier'))
 if not (civilian or armed) or n in used:continue
 if n=='enemy_soldier' and d.m_GameObject.read().m_Name!=n:continue
 if obj.type.name=='SkinnedMeshRenderer':mats=d.m_Materials
 else:
  g=d.m_GameObject.read()
  renderer=next((c.component.read() for c in g.m_Component if c.component.deref().type.name=='MeshRenderer'),None)
  if renderer is None:continue
  mats=renderer.m_Materials
 mi=mesh(d.m_Mesh,mats)
 if armed:
  g=d.m_GameObject.read()
  t=next(c.component.read() for c in g.m_Component if c.component.deref().type.name=='Transform')
  armed_parts[n]=(mi,F@trs(t)@F)
 idx=len(doc['nodes']);doc['nodes'].append({'name':n,'mesh':mi});doc['scenes'][0]['nodes'].append(idx);used.add(n)
 rows.append({'name':n,'source':key(d.m_Mesh),'role':'police' if 'cop' in n else 'military' if armed else 'civilian','bounds':geo_cache[key(d.m_Mesh)][2:]})
for obj in env.objects:
 if obj.type.name=='AudioClip':
  d=obj.read()
  if d.m_Name=='gun1':
   for fn,data in d.samples.items():(OUT/'gun1.wav').write_bytes(data);break
   break
# Assemble the source's three rigid body pieces into each complete posed character.
for role,names in [('police',['enemy_cop','enemy_cop_001','enemy_cop_002']),('police_japan',['enemy_cop_japan','enemy_cop_001_japan','enemy_cop_002_japan']),('military',['enemy_soldier','enemy_soldier_001','enemy_soldier_002'])]:
 primitives=[]
 for name in names:
  mi,transform=armed_parts[name]
  for primitive in doc['meshes'][mi]['primitives']:
   copy=dict(primitive);attrs=dict(copy['attributes'])
   for field in ['POSITION','NORMAL']:
    a=doc['accessors'][attrs[field]];v=doc['bufferViews'][a['bufferView']]
    values=np.frombuffer(bytes(buf[v['byteOffset']:v['byteOffset']+v['byteLength']]),dtype=np.float32).reshape(-1,3)
    values=values@transform[:3,:3].T
    if field=='POSITION':values+=transform[:3,3]
    # The source's posed people face +Z; all gameplay people face -Z.
    values[:,[0,2]]*=-1
    attrs[field]=accessor(values,'VEC3')
   copy['attributes']=attrs;primitives.append(copy)
 idx=len(doc['meshes']);doc['meshes'].append({'name':role+'_assembled','primitives':primitives})
 node=len(doc['nodes']);doc['nodes'].append({'name':role+'_assembled','mesh':idx});doc['scenes'][0]['nodes'].append(node)
doc['buffers']=[{'byteLength':len(buf),'uri':'humans.bin'}]
(OUT/'humans.bin').write_bytes(buf)
(OUT/'humans.gltf').write_text(json.dumps(doc,separators=(',',':')))
(ROOT/'research'/'npc_sources.json').write_text(json.dumps(rows,indent=2))
print(json.dumps(rows,indent=2))



