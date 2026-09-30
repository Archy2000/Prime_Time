import sys,json,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'python_libs'))
import UnityPy
root=Path(r'D:\SteamLibrary\steamapps\common\Sandcastle Demo\Sandcastle_Data')
env=UnityPy.load(str(root))
rows=[]
for o in env.objects:
    if o.type.name not in ('Mesh','GameObject','MonoScript','MonoBehaviour'):continue
    try:
        d=o.read()
        name=getattr(d,'m_Name','')
        if o.type.name=='MonoBehaviour' and d.m_Script.path_id:
            name+=' '+d.m_Script.read().m_ClassName
        if not re.search('boat|ship|buoy|beacon|float|rock|stone|rubble',name,re.I):continue
        row={'file':o.assets_file.name,'id':o.path_id,'type':o.type.name,'name':name}
        if o.type.name=='MonoBehaviour':
            try:row['fields']=o.read_typetree()
            except Exception as e:row['error']=str(e)
        rows.append(row)
    except Exception:pass
out=Path('research/sand_water/float_inventory.json');out.write_text(json.dumps(rows,indent=2,default=str),encoding='utf-8')
print(json.dumps(rows,default=str)[:15000])
