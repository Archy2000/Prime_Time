import sys, json, collections
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent / 'python_libs'))
import UnityPy

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    'rolla': Path(r'D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data'),
    'sandcastle': Path(r'D:\SteamLibrary\steamapps\common\Sandcastle Demo\Sandcastle_Data'),
}
out = ROOT / 'research'
out.mkdir(exist_ok=True)
for game, path in SOURCES.items():
    env = UnityPy.load(str(path))
    counts = collections.Counter()
    rows = []
    errors = []
    for obj in env.objects:
        kind = obj.type.name
        counts[kind] += 1
        if kind not in ('Mesh','Texture2D','Material','Shader','MonoScript','GameObject','TextAsset'):
            continue
        try:
            data = obj.read()
            row = {'file':obj.assets_file.name, 'id':obj.path_id, 'type':kind, 'name':getattr(data,'m_Name','')}
            if kind == 'Texture2D':
                row.update(width=data.m_Width, height=data.m_Height)
            if kind == 'Mesh':
                row.update(vertices=data.m_VertexData.m_VertexCount if data.m_VertexData else 0)
            if kind == 'Material':
                row['tree'] = obj.read_typetree()
            if kind == 'Shader':
                row['parsed_name'] = getattr(getattr(data,'m_ParsedForm',None),'m_Name','')
            rows.append(row)
        except Exception as e:
            errors.append(f'{kind} {obj.path_id}: {e}')
    (out / f'{game}_inventory.json').write_text(json.dumps({'counts':counts,'assets':rows,'errors':errors},indent=2,default=str),encoding='utf-8')
    print(game,dict(counts), 'errors',len(errors))
    for kind in ('Mesh','Material','Shader','MonoScript'):
        print(kind, [r.get('parsed_name') or r['name'] for r in rows if r['type']==kind][:220])
