exec(open('tools/inspect_armed.py').read().split('seen=set()')[0])
seen=set()
for o in env.objects:
 if o.type.name!='GameObject':continue
 g=o.read()
 if g.m_Name not in ['man_police','woman_police','man_soldier','woman_soldier','enemy_cop','enemy_cop_001','enemy_soldier','enemy_soldier_001']:continue
 if g.m_Name in seen:continue
 seen.add(g.m_Name);print('\nOBJECT',g.m_Name)
 for c in g.m_Component:
  p=c.component;d=p.read();print(p.deref().type.name)
  if p.deref().type.name=='Transform':
   print('local',d.m_LocalRotation,d.m_LocalScale,d.m_LocalPosition)
   print('children',[ch.read().m_GameObject.read().m_Name for ch in d.m_Children])
  if p.deref().type.name=='MeshFilter':print('mesh',d.m_Mesh.read().m_Name)
  if p.deref().type.name=='SkinnedMeshRenderer':print('meshptr',d.m_Mesh)
