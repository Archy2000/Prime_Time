"""Complete, additive ROLLA asset migration; never modifies the Steam installation."""
from pathlib import Path
import collections
import copy
import hashlib
import json
import shutil
import time

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r'D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data')
# Reuse the established coordinate/material converter without its selective scene export.
prefix = (ROOT / 'tools/extract_scene.py').read_text(encoding='utf-8').split('\nfor obj in env.objects:')[0]
prefix = prefix.replace("filename=f'{safe(t.m_Name)}_{p.path_id}.png'", "filename=f'{safe(key(p).split(\":\")[0])}_{safe(t.m_Name)}_{p.path_id}.png'")
exec(compile(prefix, 'extract_scene_helpers', 'exec'))
OUT = ROOT / 'assets/rolla_complete'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').write_text('')
ARCHIVE = ROOT / 'research/rolla_source'
ARCHIVE.mkdir(parents=True, exist_ok=True)
(ARCHIVE / '.gdignore').write_text('')
shutil.copytree(SOURCE, ARCHIVE / 'Rolla Demo_Data', dirs_exist_ok=True)
errors = []
inventory = []
counts = collections.Counter()
objects = list(env.objects)

class SourcePointer:
    """ObjectReader exposes optional deref=None; helpers expect a PPtr interface."""
    def __init__(self, obj):
        self.obj = obj
        self.path_id = obj.path_id
    def deref(self):
        return self.obj
    def read(self):
        return self.obj.read()

def identity(obj):
    return f'{obj.assets_file.name}:{obj.path_id}'

def export_error(obj, stage, exc):
    errors.append({'source': identity(obj), 'type': obj.type.name, 'stage': stage, 'error': str(exc)})

def write_model(path, payload):
    for attempt in range(40):
        try:
            path.write_text(payload, encoding='utf-8')
            return
        except PermissionError:
            if attempt == 39:
                raise
            time.sleep(0.25)

def trim_materials(model):
    used_materials = sorted({p['material'] for m in model['meshes'] for p in m['primitives'] if 'material' in p})
    mapping = {old: new for new, old in enumerate(used_materials)}
    model['materials'] = [copy.deepcopy(model['materials'][i]) for i in used_materials]
    for m in model['meshes']:
        for p in m['primitives']:
            if 'material' in p:
                p['material'] = mapping[p['material']]
    slots = []
    for m in model['materials']:
        for container in (m, m['pbrMetallicRoughness']):
            slots.extend(v for k, v in container.items() if k.endswith('Texture') and isinstance(v, dict) and 'index' in v)
    used_textures = sorted({v['index'] for v in slots})
    mapping = {old: new for new, old in enumerate(used_textures)}
    model['textures'] = [copy.deepcopy(model['textures'][i]) for i in used_textures]
    for value in slots:
        value['index'] = mapping[value['index']]
    used_images = sorted({t['source'] for t in model['textures']})
    mapping = {old: new for new, old in enumerate(used_images)}
    model['images'] = [model['images'][i] for i in used_images]
    for t in model['textures']:
        t['source'] = mapping[t['source']]

# File hashes make completeness independently checkable, including streaming mesh/texture data.
source_files = []
for path in sorted(SOURCE.rglob('*')):
    if path.is_file():
        rel = path.relative_to(SOURCE)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        destination = ARCHIVE / 'Rolla Demo_Data' / rel
        if hashlib.sha256(destination.read_bytes()).hexdigest() != digest:
            raise RuntimeError(f'Archive mismatch: {rel}')
        source_files.append({'path': str(rel), 'bytes': path.stat().st_size, 'sha256': digest})
print(f'Archived and verified {len(source_files)} source files', flush=True)

from rolla_material_conversion import install
install(globals())
metadata_types = {'Material', 'AnimationClip', 'Avatar', 'AnimatorController', 'AnimatorOverrideController', 'MonoScript'}
for obj in objects:
    kind = obj.type.name
    counts[kind] += 1
    if kind not in {'Mesh', 'Texture2D', 'AudioClip', 'TextAsset'} | metadata_types:
        continue
    row = {'source': identity(obj), 'type': kind}
    inventory.append(row)
    try:
        data = obj.read()
        row['name'] = getattr(data, 'm_Name', '')
        stem = f'{safe(obj.assets_file.name)}_{obj.path_id}_{safe(row["name"])}'
        if kind == 'Texture2D':
            row['texture_index'] = texture(SourcePointer(obj))
            row['file'] = doc['images'][row['texture_index']]['uri']
        elif kind in metadata_types:
            folder = ARCHIVE / 'metadata' / kind
            folder.mkdir(parents=True, exist_ok=True)
            (folder / (stem + '.json')).write_text(json.dumps(obj.read_typetree(), default=str, ensure_ascii=False), encoding='utf-8')
        elif kind == 'AudioClip':
            folder = OUT / 'audio'
            folder.mkdir(exist_ok=True)
            row['files'] = []
            for number, (name, contents) in enumerate(data.samples.items()):
                filename = f'{stem}_{number}{Path(name).suffix or ".wav"}'
                (folder / filename).write_bytes(contents)
                row['files'].append('audio/' + filename)
        elif kind == 'TextAsset':
            folder = ARCHIVE / 'text'
            folder.mkdir(exist_ok=True)
            payload = data.m_Script
            (folder / (stem + '.txt')).write_bytes(payload if isinstance(payload, bytes) else payload.encode('utf-8', errors='surrogateescape'))
    except Exception as exc:
        export_error(obj, 'resource', exc)
print(f'Resources scanned: {dict(counts)}', flush=True)

# Every renderer supplies its actual material list; include inactive NPCs and every level.
bindings = {}
renderers = []
for obj in objects:
    if obj.type.name not in ('MeshRenderer', 'SkinnedMeshRenderer'):
        continue
    try:
        renderer = obj.read()
        pointer = getattr(renderer, 'm_Mesh', None)
        if pointer is None:
            game_object = renderer.m_GameObject.read()
            for component in game_object.m_Component:
                if component.component.deref().type.name == 'MeshFilter':
                    pointer = component.component.read().m_Mesh
                    break
        if pointer is None or not pointer.path_id:
            continue
        raw_mesh = pointer.read()
        if not raw_mesh.m_VertexData.m_VertexCount and not raw_mesh.m_CompressedMesh.m_Vertices.m_NumItems:
            continue  # Source contains deliberately empty mesh placeholders.
        mi = mesh(pointer, renderer.m_Materials)
        bindings.setdefault(key(pointer), []).append(mi)
        renderers.append((obj, renderer, mi))
    except Exception as exc:
        export_error(obj, 'renderer', exc)

# Also export meshes/materials that are not used in loaded scenes.
for obj in objects:
    try:
        if obj.type.name == 'Mesh':
            k = identity(obj)
            data = obj.read()
            if not data.m_VertexData.m_VertexCount and not data.m_CompressedMesh.m_Vertices.m_NumItems:
                next(row for row in inventory if row['source'] == k)['status'] = 'empty_source_mesh'
                continue
            if k not in bindings:
                bindings[k] = [mesh(SourcePointer(obj), [])]
            next(row for row in inventory if row['source'] == k)['mesh_indices'] = sorted(set(bindings[k]))
        elif obj.type.name == 'Material':
            material(SourcePointer(obj))
    except Exception as exc:
        export_error(obj, 'unreferenced_resource', exc)

repair_material_placeholders()
transforms = {}
go_transforms = {}
for obj in objects:
    if obj.type.name not in ('Transform', 'RectTransform'):
        continue
    try:
        t = obj.read()
        g = t.m_GameObject.read()
        idx = len(doc['nodes'])
        node = {'name': f'{safe(g.m_Name)}__{safe(obj.assets_file.name)}_{obj.path_id}',
                'matrix': (F @ trs(t) @ F).T.flatten().tolist(),
                'extras': {'unity_source': identity(obj), 'unity_name': g.m_Name, 'unity_active': bool(g.m_IsActive)}}
        doc['nodes'].append(node)
        transforms[identity(obj)] = (idx, t)
        go_transforms[key(t.m_GameObject)] = idx
    except Exception as exc:
        export_error(obj, 'transform', exc)

doc['scenes'] = []
scene_roots = collections.defaultdict(list)
for k, (idx, t) in transforms.items():
    children = [transforms[key(p)][0] for p in t.m_Children if p.path_id and key(p) in transforms]
    if children:
        doc['nodes'][idx]['children'] = children
    if not t.m_Father.path_id or key(t.m_Father) not in transforms:
        scene_roots[k.split(':')[0]].append(idx)

for obj, renderer, mi in renderers:
    idx = go_transforms.get(key(renderer.m_GameObject))
    if idx is None:
        continue
    if 'mesh' in doc['nodes'][idx]:
        child = len(doc['nodes'])
        doc['nodes'].append({'name': 'renderer_' + str(obj.path_id), 'mesh': mi})
        doc['nodes'][idx].setdefault('children', []).append(child)
    else:
        doc['nodes'][idx]['mesh'] = mi
    doc['nodes'][idx]['extras']['unity_renderer_enabled'] = bool(renderer.m_Enabled)

for name, roots in sorted(scene_roots.items()):
    doc['scenes'].append({'name': name, 'nodes': roots})
doc['buffers'] = [{'byteLength': len(buf), 'uri': 'rolla_all.bin'}]
(OUT / 'rolla_all.bin').write_bytes(buf)
(OUT / 'rolla_scenes.gltf').write_text(json.dumps(doc, separators=(',', ':')), encoding='utf-8')
for scene_index, scene in enumerate(doc['scenes']):
    scene_doc = dict(doc, scene=scene_index)
    write_model(OUT / f'rolla_{safe(scene["name"])}.gltf', json.dumps(scene_doc, separators=(',', ':')))

# A compact, importable catalogue and one standalone glTF per mesh variant.
catalogue = copy.deepcopy(doc)
catalogue['nodes'] = [{'name': m['name'] + '__' + str(i), 'mesh': i,
                       'translation': [(i % 20) * 15.0, 0, (i // 20) * 15.0]}
                      for i, m in enumerate(doc['meshes'])]
catalogue['scenes'] = [{'name': 'All ROLLA meshes', 'nodes': list(range(len(catalogue['nodes'])))}]
(OUT / 'rolla_catalogue.gltf').write_text(json.dumps(catalogue, separators=(',', ':')), encoding='utf-8')
models = OUT / 'models'
models.mkdir(exist_ok=True)
for i, source_mesh in enumerate(doc['meshes']):
    model = {'asset': doc['asset'], 'scene': 0, 'scenes': [{'nodes': [0]}],
             'nodes': [{'name': source_mesh['name'], 'mesh': 0}], 'meshes': [copy.deepcopy(source_mesh)],
             'materials': doc['materials'], 'textures': doc['textures'], 'samplers': doc['samplers'],
             'images': [{'uri': '../' + im['uri']} for im in doc['images']],
             'buffers': [{'uri': '../rolla_all.bin', 'byteLength': len(buf)}],
             'bufferViews': [], 'accessors': []}
    if doc.get('extensionsUsed'):
        model['extensionsUsed'] = doc['extensionsUsed']
    accessors = {}
    for primitive in model['meshes'][0]['primitives']:
        primitive['attributes'] = dict(primitive['attributes'])
        for target, field in [(primitive, 'indices')] + [(primitive['attributes'], f) for f in primitive['attributes']]:
            old = target[field]
            if old not in accessors:
                a = copy.deepcopy(doc['accessors'][old])
                v = copy.deepcopy(doc['bufferViews'][a['bufferView']])
                a['bufferView'] = len(model['bufferViews'])
                model['bufferViews'].append(v)
                accessors[old] = len(model['accessors'])
                model['accessors'].append(a)
            target[field] = accessors[old]
    filename = f'{i:03d}_{safe(source_mesh["name"])}.gltf'
    trim_materials(model)
    write_model(models / filename, json.dumps(model, separators=(',', ':')))

report = {'source': str(SOURCE), 'source_files': source_files, 'source_counts': dict(counts),
          'exported_unique_meshes': len(geo_cache), 'mesh_variants': len(doc['meshes']),
          'materials': len(doc['materials']), 'source_materials_converted': len(mat_cache),
          'textures': len(tex_cache), 'exported_images_including_channel_conversions': len(doc['images']), 'renderer_instances': len(renderers),
          'scene_nodes': len(doc['nodes']), 'scenes': list(scene_roots), 'inventory': inventory, 'errors': errors,
          'material_repairs': material_repairs,
          'limitations': ['Skinned meshes exported in bind pose; bones, weights and clips retained in source archive, not converted to Godot animations.',
                          'Unity shaders, scripts, physics and AI require Godot adaptation.',
                          'Inactive objects and disabled renderers preserved as extras; imported visibility requires selection.',
                          'Full source archive contains every resource even when a format cannot be converted.']}
(ROOT / 'research/rolla_complete_report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
(OUT / '.gdignore').unlink(missing_ok=True)
print(json.dumps({k: v for k, v in report.items() if k not in ('source_files', 'inventory', 'errors', 'source_counts')}, indent=2, ensure_ascii=False), flush=True)
print('Errors:', dict(collections.Counter((e['stage'], e['error']) for e in errors)), flush=True)
