import ctypes,json
from pathlib import Path
out=Path('research/sand_water')
dll=ctypes.WinDLL('d3dcompiler_47.dll')
dll.D3DDisassemble.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_uint,ctypes.c_char_p,ctypes.POINTER(ctypes.c_void_p)]
def disasm(code):
    raw=bytes(code);buf=ctypes.create_string_buffer(raw);blob=ctypes.c_void_p()
    hr=dll.D3DDisassemble(buf,len(raw),0,None,ctypes.byref(blob))
    if hr:return f'D3DDisassemble failed {hr}'
    vt=ctypes.cast(blob,ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    ptr=ctypes.WINFUNCTYPE(ctypes.c_void_p,ctypes.c_void_p)(vt[3])(blob)
    size=ctypes.WINFUNCTYPE(ctypes.c_size_t,ctypes.c_void_p)(vt[4])(blob)
    text=ctypes.string_at(ptr,size).decode('utf8','replace')
    ctypes.WINFUNCTYPE(ctypes.c_ulong,ctypes.c_void_p)(vt[2])(blob)
    return text
report=[]
for name in ['636_Water','647_Whitewater']:
    data=json.loads((out/(name+'.json')).read_text())
    for k in data['variants'][0]['kernels']:
        for v in k['uniqueVariants'][:1]:
            (out/(name+'_'+k['name']+'.asm.txt')).write_text(disasm(v['code']))
            report.append({'shader':name,'kernel':k['name'],'resources':{n:v.get(n) for n in ['textures','inBuffers','outBuffers']}})
    (out/(name+'_constants.json')).write_text(json.dumps(data['variants'][0]['constantBuffers'],indent=2))
(out/'kernels.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
