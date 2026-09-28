exec(open('tools/inspect_armed.py').read().split('seen=set()')[0])
for o in env.objects:
 if o.type.name!='MeshFilter':continue
 d=o.read()
 if not d.m_Mesh.path_id or d.m_Mesh.read().m_Name not in ['enemy_soldier','enemy_soldier_001','enemy_soldier_002']:continue
 g=d.m_GameObject.read();t=next(c.component.read() for c in g.m_Component if c.component.deref().type.name=='Transform')
 print(g.m_Name,t.m_LocalPosition,t.m_LocalRotation,t.m_LocalScale,'parent',t.m_Father.read().m_GameObject.read().m_Name if t.m_Father.path_id else '')
