import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'python_libs'))
import UnityPy
env=UnityPy.load(r'D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data')
out=[]
for obj in env.objects:
    if obj.type.name=='Transform' and obj.assets_file.name.startswith('level'):
        d=obj.read()
        if not d.m_Father.path_id:
            g=d.m_GameObject.read()
            out.append({'file':obj.assets_file.name,'id':obj.path_id,'name':g.m_Name,'active':g.m_IsActive,'pos':str(d.m_LocalPosition),'children':len(d.m_Children)})
Path('research/scene_roots.json').write_text(json.dumps(out,indent=2))
print(json.dumps(out,indent=2)[:22000])
for obj in env.objects:
    if obj.type.name=='MonoBehaviour':
        try:
            d=obj.read()
            s=d.m_Script.read()
            if s.m_Name in ('PlayerController','CameraFollow2','CameraFollowAndScale','CameraFollow','CameraAlternative'):
                print(s.m_Name,obj.assets_file.name,obj.path_id,str(obj.read_typetree())[:8000])
        except: pass
