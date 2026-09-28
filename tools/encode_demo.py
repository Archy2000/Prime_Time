import sys,subprocess
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'python_libs'))
import imageio_ffmpeg
from PIL import Image,ImageDraw
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
base=sys.argv[1] if len(sys.argv)>1 else 'v2_demo'
subprocess.run([ffmpeg,'-y','-i',f'research/{base}.avi','-c:v','libx264','-preset','fast','-crf','21','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart',f'research/{base}.mp4'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
reader=imageio_ffmpeg.read_frames(f'research/{base}.mp4',pix_fmt='rgb24',output_params=['-vf','fps=2,scale=640:360'])
meta=next(reader);frames=[]
for i,data in enumerate(reader):
    im=Image.frombytes('RGB',(640,360),data);frames.append(im)
for start in range(0,len(frames),12):
    rows=(min(12,len(frames)-start)+1)//2
    sheet=Image.new('RGB',(1280,rows*384),(20,20,20));d=ImageDraw.Draw(sheet)
    for j,im in enumerate(frames[start:start+12]):
        x=j%2*640;y=j//2*384;sheet.paste(im,(x,y));d.text((x+8,y+363),f'Godot actual capture | {(start+j)*0.5:.1f}s',fill='white')
    sheet.save(f'research/{base}_sheet_{start//12}.jpg')
print(meta)
print('MP4 bytes',Path(f'research/{base}.mp4').stat().st_size)
