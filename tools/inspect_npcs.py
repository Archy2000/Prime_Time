import sys,json
from pathlib import Path
sys.path.insert(0,str(Path('tools/python_libs').resolve()))
import UnityPy
env=UnityPy.load(r'D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data')
rows=[];seen=set()
for o in env.objects:
 if o.type.name=='SkinnedMeshRenderer':
  d=o.read()
  if not d.m_Mesh.path_id:continue
  n=d.m_Mesh.read().m_Name
  mats=[p.read().m_Name for p in d.m_Materials if p.path_id]
  sig=(n,tuple(mats))
  if sig in seen:continue
  seen.add(sig);rows.append({'mesh':n,'materials':mats,'object':d.m_GameObject.read().m_Name})
Path('research/npc_inventory.json').write_text(json.dumps(rows,indent=2))
print(json.dumps(rows,indent=2))
