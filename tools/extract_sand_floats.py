"""Read-only extraction of Sandcastle float/rock meshes and their source materials."""
from pathlib import Path
code=Path('tools/extract_scene.py').read_text(encoding='utf-8').split('\ndef walk(')[0]
code=code.replace("OUT=ROOT/'assets'/'extracted'", "OUT=ROOT/'assets'/'sand_floats'")
code=code.replace(r'D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data',r'D:\SteamLibrary\steamapps\common\Sandcastle Demo\Sandcastle_Data')
exec(compile(code,'tools/extract_scene.py','exec'))
names={'Boat_01','WoodenBoat_01','Buoy_01'}|{f'Rock_{i:02d}' for i in range(1,7)}
used=set();sources=[]
for o in env.objects:
    if o.type.name!='MeshFilter':continue
    try:
        d=o.read()
        if not d.m_Mesh.path_id:continue
        n=d.m_Mesh.read().m_Name
        if n not in names or n in used:continue
        go=d.m_GameObject.read();renderer=None
        for c in go.m_Component:
            if c.component.deref().type.name=='MeshRenderer':renderer=c.component.read()
        if renderer is None:continue
        mi=mesh(d.m_Mesh,renderer.m_Materials)
        node={'name':n,'mesh':mi};doc['scenes'][0]['nodes'].append(len(doc['nodes']));doc['nodes'].append(node)
        sources.append({'name':n,'mesh':key(d.m_Mesh),'materials':[key(p) for p in renderer.m_Materials],'bounds':geo_cache[key(d.m_Mesh)][2:]});used.add(n)
    except Exception as e:sources.append({'error':str(e),'id':o.path_id})
doc['buffers']=[{'uri':'sand_floats.bin','byteLength':len(buf)}]
(OUT/'sand_floats.bin').write_bytes(buf)
(OUT/'sand_floats.gltf').write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
Path('research/sand_water/float_sources.json').write_text(json.dumps(sources,indent=2),encoding='utf-8')
print(json.dumps(sources));print('Exported',sorted(used))
