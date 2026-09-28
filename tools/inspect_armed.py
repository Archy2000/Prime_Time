import sys
from pathlib import Path
sys.path.insert(0,str(Path('tools/python_libs').resolve()))
import UnityPy
env=UnityPy.load(r'D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data')
seen=set()
for o in env.objects:
 if o.type.name in ('Mesh','GameObject','AudioClip'):
  d=o.read();n=d.m_Name
  if any(t in n.lower() for t in ['poli','sold','army','milit','rifle','pistol','gun','swat','shoot','bullet','cop']):
   k=(o.type.name,n)
   if k not in seen: print(k);seen.add(k)
