"""Inspect cached local Sandcastle render bytecode, preserving evidence rather than guessing HLSL."""
import ctypes
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/python_libs'))
import lz4.block

water = len(sys.argv) > 1 and sys.argv[1] == 'water'
source = ROOT / ('research/sand_water/587_Lit_Water.json' if water else 'research/sand_water/626_Lit_Whitewater.json')
out = ROOT / ('research/sand_water/water_render' if water else 'research/sand_water/whitewater_render')
out.mkdir(exist_ok=True)
d = json.loads(source.read_text())
blob = lz4.block.decompress(bytes(d['compressedBlob']), uncompressed_size=d['decompressedLengths'][0][0])
dll = ctypes.WinDLL('d3dcompiler_47.dll')
dll.D3DDisassemble.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint, ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p)]
found = []
offset = 0
while True:
    offset = blob.find(b'DXBC', offset)
    if offset < 0:
        break
    size = struct.unpack_from('<I', blob, offset + 24)[0]
    code = blob[offset:offset + size]
    buffer = ctypes.create_string_buffer(code)
    result = ctypes.c_void_p()
    hr = dll.D3DDisassemble(buffer, len(code), 0, None, ctypes.byref(result))
    if hr:
        raise RuntimeError(hr)
    vt = ctypes.cast(result, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    ptr = ctypes.WINFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p)(vt[3])(result)
    length = ctypes.WINFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p)(vt[4])(result)
    assembly = ctypes.string_at(ptr, length).decode('utf-8').rstrip('\0')
    ctypes.WINFUNCTYPE(ctypes.c_ulong, ctypes.c_void_p)(vt[2])(result)
    file = f'program_{len(found):02d}.asm.txt'
    (out / file).write_text(assembly, encoding='utf-8')
    stage = next((line for line in assembly.splitlines() if line.startswith(('vs_','ps_','gs_'))), 'unknown')
    found.append({'file':file,'stage':stage,'blob_offset':offset,'byte_size':size})
    offset += size
(out / 'index.json').write_text(json.dumps(found, indent=2), encoding='utf-8')
print(json.dumps(found, indent=2))
