"""Read-only NPC voice/gun extraction; deterministic synthesized rooftop footsteps."""
import sys,json,io,wave,hashlib
from pathlib import Path
sys.path.insert(0,str(Path('tools/python_libs').resolve()))
import UnityPy,numpy as np
out=Path('assets/audio/npc');out.mkdir(parents=True,exist_ok=True)
rows=[];seen=set()
def write(name,a,rate):
 a=np.asarray(a,dtype=np.float64).reshape(-1)
 a-=a.mean();peak=float(np.max(np.abs(a)))
 a*=min(4.0,0.78/max(peak,0.0001))
 n=min(int(rate*0.004),len(a)//8);a[:n]*=np.linspace(0,1,n);a[-n:]*=np.linspace(1,0,n)
 with wave.open(str(out/(name+'.wav')),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes((np.clip(a,-1,1)*32767).astype('<i2').tobytes())
 return {'name':name,'seconds':len(a)/rate,'peak':float(np.max(np.abs(a)))}
for o in UnityPy.load(r'D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data').objects:
 if o.type.name!='AudioClip':continue
 d=o.read();name=d.m_Name
 if name not in ['lscream0','lscream1','lscream2','lscream3','lscream4','gun1']:continue
 raw=next(iter(d.samples.values()));digest=hashlib.sha256(raw).hexdigest()
 if digest in seen:continue
 seen.add(digest)
 with wave.open(io.BytesIO(raw),'rb') as w:
  rate=w.getframerate();channels=w.getnchannels();width=w.getsampwidth();data=w.readframes(w.getnframes())
 if width!=2:raise ValueError(width)
 a=np.frombuffer(data,dtype='<i2').reshape(-1,channels).mean(axis=1)/32768
 filename=('gun_'+str(sum(r['name'].startswith('gun_') for r in rows)+1)) if name=='gun1' else name
 row=write(filename,a,rate);row.update(source=o.assets_file.name,path_id=o.path_id,source_name=name,sha256=digest);rows.append(row)
# No isolated running steps in the ROLLA audio bank. Make short, non-looping boot impacts.
for i in range(4):
 rate=24000;t=np.arange(int(rate*0.16))/rate;rng=np.random.default_rng(780+i)
 noise=rng.normal(0,1,len(t));soft=np.convolve(noise,np.ones(7)/7,mode='same')
 a=0.48*np.sin(2*np.pi*(105+i*9)*t)*np.exp(-t*42)+soft*0.36*np.exp(-t*31)+noise*0.08*np.exp(-t*95)
 row=write('roof_step_'+str(i+1),a,rate);row['source']='deterministic synthesized boot thud and grit';rows.append(row)
Path('research/npc_audio_sources.json').write_text(json.dumps(rows,indent=2))
print(json.dumps(rows,indent=2))
