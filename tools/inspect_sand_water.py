import sys,json,re,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'python_libs'))
import UnityPy
root=Path(r'D:\SteamLibrary\steamapps\common\Sandcastle Demo\Sandcastle_Data')
out=Path('research/sand_water');out.mkdir(exist_ok=True)
env=UnityPy.load(str(root))
report=[]
for o in env.objects:
    if o.type.name not in ('Shader','ComputeShader','MonoBehaviour','MonoScript'):continue
    try:
        d=o.read_typetree(); name=d.get('m_Name','')
        if o.type.name=='Shader':name=d.get('m_ParsedForm',{}).get('m_Name',name)
        if o.type.name=='MonoBehaviour' and d.get('m_Script',{}).get('m_PathID'):
            try:name+=' '+o.read().m_Script.read().m_ClassName
            except Exception:pass
        if not re.search('water|wave|simulat|fluid|foam|buoy|obstacle|hydro',name,re.I):continue
        safe=re.sub(r'[^\w.-]','_',name)
        report.append([o.type.name,o.path_id,name])
        (out/f'{o.path_id}_{safe}.json').write_text(json.dumps(d,ensure_ascii=False,indent=2,default=str),encoding='utf8')
        if o.type.name=='Shader':
            try:(out/f'{o.path_id}_{safe}.shader.txt').write_text(o.read().export(),encoding='utf8')
            except Exception as e:report.append(['export_error',name,str(e)])
    except Exception as e:pass
meta=(root/'il2cpp_data/Metadata/global-metadata.dat').read_bytes()
# IL2CPP metadata string table, not recovered C# method bodies.
hits=[]
(out/'metadata_symbols.txt').write_text('Metadata version 39: string layout not decoded. No C# method bodies recovered. Use ComputeShader kernels and constantBuffers as evidence.',encoding='utf8')
(out/'index.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report));print('metadata version',struct.unpack_from('<I',meta,4)[0],'symbols',len(hits))
