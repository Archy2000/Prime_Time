import sys,json
from pathlib import Path
sys.path.insert(0,str(Path('tools/python_libs').resolve()))
import UnityPy
env=UnityPy.load(r'D:\SteamLibrary\steamapps\common\Sandcastle Demo\Sandcastle_Data')
rows=[]
for o in env.objects:
 if o.type.name=='AudioClip':
  d=o.read();rows.append({'name':d.m_Name,'id':o.path_id,'seconds':d.m_Length,'channels':d.m_Channels})
Path('research/sand_audio_inventory.json').write_text(json.dumps(rows,indent=2))
print(json.dumps(rows,indent=2))
