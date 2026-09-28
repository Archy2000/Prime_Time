import sys,json,io,wave,hashlib
from pathlib import Path
sys.path.insert(0,str(Path('tools/python_libs').resolve()))
import UnityPy,numpy as np
root=Path(r'D:\SteamLibrary\steamapps\common\Sandcastle Demo\Sandcastle_Data')
out=Path('assets/audio/water');out.mkdir(parents=True,exist_ok=True)
loops={'WaterCalm_02','WaterAgitated_01','WaterFlowing'}
rows=[]
for o in UnityPy.load(str(root)).objects:
 if o.type.name!='AudioClip':continue
 d=o.read();name=d.m_Name
 if name not in loops and not name.startswith(('WaterSplashSmall_','WaterSplashMedium_','WaterDrop_','Bubble_')):continue
 raw=next(iter(d.samples.values()))
 with wave.open(io.BytesIO(raw),'rb') as w:
  rate=w.getframerate();channels=w.getnchannels();width=w.getsampwidth();frames=w.getnframes();pcm=w.readframes(frames)
 if width!=2:raise ValueError((name,width))
 a=np.frombuffer(pcm,dtype='<i2').reshape(-1,channels).astype(np.float64)/32768
 if name!='WaterCalm_02':a=a.mean(axis=1,keepdims=True)
 if name in loops:
  n=min(int(rate*.18),len(a)//8);t=np.linspace(0,1,n)[:,None]
  a=np.concatenate((a[n:-n],a[-n:]*(1-t)+a[:n]*t))
 peak=float(np.max(np.abs(a)));a*=min(3.,.8/max(peak,.001))
 if name not in loops:
  n=min(int(rate*.004),len(a)//8);a[:n]*=np.linspace(0,1,n)[:,None];a[-n:]*=np.linspace(1,0,n)[:,None]
 p=out/(name+'.wav')
 with wave.open(str(p),'wb') as w:
  w.setnchannels(a.shape[1]);w.setsampwidth(2);w.setframerate(rate);w.writeframes((np.clip(a,-1,1)*32767).astype('<i2').tobytes())
 rows.append({'name':name,'source':str(root/o.assets_file.name),'path_id':o.path_id,'source_sha256':hashlib.sha256(raw).hexdigest(),'seconds':len(a)/rate,'loop':name in loops,'peak':float(np.max(np.abs(a)))})
Path('research/water_audio_sources.json').write_text(json.dumps(rows,indent=2))
print('Prepared',len(rows),'clips')
