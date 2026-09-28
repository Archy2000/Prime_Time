import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'python_libs'))
import UnityPy
env=UnityPy.load(r'D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data')
def pathof(g):
    names=[g.m_Name]
    for c in g.m_Component:
        if c.component.deref().type.name=='Transform':
            t=c.component.read()
            for _ in range(15):
                if not t.m_Father.path_id:break
                t=t.m_Father.read();names.append(t.m_GameObject.read().m_Name)
            break
    return '/'.join(names[::-1])
seen=set()
for o in env.objects:
    if o.type.name=='MeshFilter':
        d=o.read()
        if not d.m_Mesh.path_id:continue
        m=d.m_Mesh.read();n=m.m_Name
        if ('_cell' in n or 'rubble' in n) and n not in seen:
            seen.add(n);g=d.m_GameObject.read()
            print('FRAGMENT',n,pathof(g))
    if o.type.name=='Material':
        d=o.read()
        if any(x in d.m_Name.lower() for x in ['smoke','blood','fire','explode']):
            print('FX_MAT',d.m_Name,[(n,t.m_Texture.path_id, t.m_Texture.read().m_Name if t.m_Texture.path_id else '') for n,t in d.m_SavedProperties.m_TexEnvs])
