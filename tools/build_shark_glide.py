"""Create a seamless subdued underwater glide from the calm-water recording."""
from pathlib import Path
import wave,json
import numpy as np
root=Path(__file__).resolve().parents[1]
source=root/'assets/audio/water/WaterCalm_02.wav'
with wave.open(str(source),'rb') as w:
 rate=w.getframerate();channels=w.getnchannels()
 a=np.frombuffer(w.readframes(w.getnframes()),'<i2').reshape(-1,channels).mean(axis=1)/32768.
a=a[int(rate*8):int(rate*24)]
f=np.fft.rfftfreq(len(a),1/rate)
# Retain soft water texture, remove splattery highs and sub-bass rumble.
curve=(1/(1+(f/650)**6))*(1-1/(1+(f/85)**4))
a=np.fft.irfft(np.fft.rfft(a)*curve,len(a))
a=np.tanh(a/max(np.std(a),1e-6)*.65)
a*=.10/max(np.sqrt(np.mean(a*a)),1e-6)
# Equal-amplitude overlap removes the cut without an audible level swell.
n=int(rate*.75);t=np.linspace(0,1,n)
a=np.concatenate((a[n:-n],a[-n:]*(1-t)+a[:n]*t))
p=root/'assets/audio/water/SharkGlide.wav'
with wave.open(str(p),'wb') as w:
 w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate)
 w.writeframes((a*32767).astype('<i2').tobytes())
print(json.dumps({'seconds':len(a)/rate,'peak':float(abs(a).max()),'rms':float(np.sqrt(np.mean(a*a)))}))
