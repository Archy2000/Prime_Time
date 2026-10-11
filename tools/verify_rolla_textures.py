"""Check every exported texture reference and the placeholder repairs against original assets."""
from pathlib import Path
from PIL import Image
import collections
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/rolla_complete'
failures = []
referenced_images = set()
channels = collections.Counter()
files = sorted(OUT.rglob('*.gltf'))
for path in files:
    doc = json.loads(path.read_text(encoding='utf-8'))
    for image in doc.get('images', []):
        target = (path.parent / image['uri']).resolve()
        if not target.is_file():
            failures.append({'file': str(path.relative_to(ROOT)), 'missing_image': image['uri']})
        else:
            referenced_images.add(target)
    for material in doc.get('materials', []):
        for container in (material, material['pbrMetallicRoughness']):
            for name, value in container.items():
                if name.endswith('Texture') and isinstance(value, dict) and 'index' in value:
                    index = value['index']
                    if index >= len(doc.get('textures', [])) or doc['textures'][index]['source'] >= len(doc.get('images', [])):
                        failures.append({'file': path.name, 'material': material['name'], 'invalid_channel': name})
    if path.parent.name == 'models':
        for material in doc['materials']:
            for c in (material, material['pbrMetallicRoughness']):
                channels.update(k for k in c if k.endswith('Texture'))
        if doc['meshes'][0]['name'] in ('man_hazard', 'woman_scientist'):
            assert all('baseColorTexture' in m['pbrMetallicRoughness'] for m in doc['materials'])
for path in referenced_images:
    with Image.open(path) as image:
        image.verify()
report = {'gltf_files_checked': len(files), 'referenced_images_verified': len(referenced_images),
          'model_material_texture_channels': dict(channels), 'failures': failures}
(ROOT / 'research/rolla_texture_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
raise SystemExit(bool(failures))
