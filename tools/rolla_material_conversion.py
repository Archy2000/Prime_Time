"""Preserve Unity texture channels and trace explicitly inferred placeholder repairs."""
import copy
import numpy as np
from PIL import Image


def install(namespace):
    original = namespace['material']
    doc = namespace['doc']
    env = namespace['env']
    key = namespace['key']
    texture = namespace['texture']
    derived = {}
    repairs = []
    namespace['material_repairs'] = repairs

    def add_image(pointer, channel):
        signature = (key(pointer), channel)
        if signature in derived:
            return derived[signature]
        source = pointer.read()
        arr = np.asarray(source.image.convert('RGBA')).astype(np.float32) / 255.0
        if channel == 'metallic_roughness':
            rgb = np.stack([np.ones_like(arr[:, :, 0]), 1.0 - arr[:, :, 3], arr[:, :, 0]], axis=-1)
        elif channel == 'normal':
            # Unity DXT5nm stores X in alpha, Y in green. BC5 already stores X/Y in R/G.
            if int(source.m_TextureFormat) in (10, 12):
                x = arr[:, :, 0] * arr[:, :, 3] * 2.0 - 1.0
            else:
                x = arr[:, :, 0] * 2.0 - 1.0
            y = arr[:, :, 1] * 2.0 - 1.0
            z = np.sqrt(np.maximum(0, 1.0 - x * x - y * y))
            rgb = np.stack([x * 0.5 + 0.5, y * 0.5 + 0.5, z * 0.5 + 0.5], axis=-1)
        elif channel == 'occlusion':
            rgb = np.repeat(arr[:, :, 1:2], 3, axis=-1)
        else:
            raise ValueError(channel)
        filename = namespace['safe'](key(pointer)) + '_' + channel + '.png'
        Image.fromarray(np.uint8(np.clip(rgb, 0, 1) * 255)).save(namespace['OUT'] / filename)
        image_index = len(doc['images'])
        doc['images'].append({'uri': filename})
        index = len(doc['textures'])
        doc['textures'].append({'source': image_index, 'sampler': 0})
        derived[signature] = index
        return index

    def info(index, te):
        value = {'index': index}
        sx, sy = te.m_Scale.x, te.m_Scale.y
        ox, oy = te.m_Offset.x, te.m_Offset.y
        if (sx, sy, ox, oy) != (1, 1, 0, 0):
            value['extensions'] = {'KHR_texture_transform': {'scale': [sx, sy], 'offset': [ox, 1.0 - sy - oy]}}
            used = doc.setdefault('extensionsUsed', [])
            if 'KHR_texture_transform' not in used:
                used.append('KHR_texture_transform')
        return value

    def material(pointer):
        index = original(pointer)
        if index is None:
            return None
        m = doc['materials'][index]
        if m.get('extras', {}).get('complete_texture_channels'):
            return index
        source = pointer.read()
        tree = pointer.deref().read_typetree()
        props = tree['m_SavedProperties']
        floats = dict(props.get('m_Floats', []))
        colors = dict(props.get('m_Colors', []))
        tex = dict(source.m_SavedProperties.m_TexEnvs)
        m['extras'] = {'unity_source': key(pointer), 'complete_texture_channels': True,
                       'source_texture_slots': {name: key(t.m_Texture) for name, t in tex.items() if t.m_Texture.path_id}}
        pbr = m['pbrMetallicRoughness']
        for slot in ('_BaseMap', '_MainTex'):
            te = tex.get(slot)
            if te and te.m_Texture.path_id:
                pbr['baseColorTexture'] = info(texture(te.m_Texture), te)
                break
        for slot, target, channel in [('_BumpMap', 'normalTexture', 'normal'),
                                      ('_Normal', 'normalTexture', 'normal'),
                                      ('_OcclusionMap', 'occlusionTexture', 'occlusion')]:
            te = tex.get(slot)
            if te and te.m_Texture.path_id:
                m[target] = info(add_image(te.m_Texture, channel), te)
                m[target]['scale' if target == 'normalTexture' else 'strength'] = max(0, floats.get('_BumpScale' if target == 'normalTexture' else '_OcclusionStrength', 1))
        te = tex.get('_MetallicGlossMap') or tex.get('_MetallicSmoothness')
        if te and te.m_Texture.path_id:
            pbr['metallicRoughnessTexture'] = info(add_image(te.m_Texture, 'metallic_roughness'), te)
            pbr['metallicFactor'] = 1.0
            pbr['roughnessFactor'] = 1.0
        emission = colors.get('_EmissionColor', {})
        ec = [max(0.0, emission.get(c, 0.0)) for c in 'rgb']
        te = tex.get('_EmissionMap') or tex.get('_Emission')
        if te and te.m_Texture.path_id:
            m['emissiveTexture'] = info(texture(te.m_Texture), te)
            ec = [c * floats.get('_EmissionPower', 1.0) for c in ec]
        if max(ec) > 0:
            strength = max(1.0, max(ec))
            m['emissiveFactor'] = [c / strength for c in ec]
            if strength > 1:
                m.setdefault('extensions', {})['KHR_materials_emissive_strength'] = {'emissiveStrength': strength}
                if 'KHR_materials_emissive_strength' not in doc.setdefault('extensionsUsed', []):
                    doc['extensionsUsed'].append('KHR_materials_emissive_strength')
        mode = floats.get('_Mode', 0)
        color = colors.get('_Color', colors.get('_BaseColor', {}))
        if mode in (2, 3) or floats.get('_Surface') == 1:
            m['alphaMode'] = 'BLEND'
            pbr['baseColorFactor'][3] = max(0, min(1, color.get('a', 1)))
        elif mode == 1 or floats.get('_AlphaClip') == 1:
            m['alphaMode'] = 'MASK'
            m['alphaCutoff'] = floats.get('_Cutoff', 0.5)
        return index

    namespace['material'] = material

    def repair_placeholders():
        # These two characters share the original LOW-POLY-COLORS atlas UV layout.
        atlas_material = next(i for i, m in enumerate(doc['materials']) if m['name'] == 'LOW-POLY-COLORS')
        for mesh in doc['meshes']:
            if mesh['name'] not in ('man_hazard', 'woman_scientist'):
                continue
            for primitive in mesh['primitives']:
                old = primitive.get('material')
                if old is None or doc['materials'][old]['name'] != 'MatteBlack':
                    continue
                new = copy.deepcopy(doc['materials'][atlas_material])
                new['name'] = mesh['name'] + '_restored_original_palette'
                new.setdefault('extras', {})['repair'] = {'inferred': True, 'original_material': 'MatteBlack',
                    'reason': 'Original placeholder has no texture; matching palette UV layout uses the existing character atlas.'}
                primitive['material'] = len(doc['materials'])
                doc['materials'].append(new)
                repairs.append({'mesh': mesh['name'], 'repair': 'character_palette', 'inferred': True})
        # Named palette materials contain a missing reference but identify the original atlas.
        palette_objects = [o for o in env.objects if o.type.name == 'Texture2D' and o.read().m_Name == 'palette_astalo']
        if palette_objects:
            pointer = namespace['SourcePointer'](next((o for o in palette_objects if o.assets_file.name == 'sharedassets2.assets'), palette_objects[0]))
            for m in doc['materials']:
                if m['name'] == 'None__palette_astalo_png' and 'baseColorTexture' not in m['pbrMetallicRoughness']:
                    m['pbrMetallicRoughness']['baseColorTexture'] = {'index': texture(pointer)}
                    m['extras']['repair'] = {'inferred': True, 'reason': 'Material name identifies palette_astalo; original texture pointer is null.'}
                    repairs.append({'material_source': m['extras']['unity_source'], 'repair': 'named_palette', 'inferred': True})
    namespace['repair_material_placeholders'] = repair_placeholders
