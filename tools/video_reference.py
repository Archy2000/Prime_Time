import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'python_libs'))
import imageio_ffmpeg
from PIL import Image,ImageDraw
root=Path('research/reference_video');root.mkdir(parents=True,exist_ok=True)
files=[Path('research/reference_video/rolla_clip.mp4'),Path('research/reference_video/sandcastle_clip.mp4')]
prefix='v'
if len(sys.argv)>1:
    files=[Path(sys.argv[1])];prefix='splash'
for n,path in enumerate(files,1):
    reader=imageio_ffmpeg.read_frames(str(path),pix_fmt='rgb24',output_params=['-vf','fps=1/2,scale=640:-2'])
    meta=next(reader);print(n,meta)
    frames=[]
    # ffmpeg reader metadata uses source sizes, output is deliberately 640 px wide.
    w,h=meta['size'];h=round(h*640/w/2)*2;w=640
    for i,data in enumerate(reader):
        im=Image.frombytes('RGB',(w,h),data);im.save(root/f'{prefix}{n}_{i*2:03d}.jpg');frames.append(im)
    for start in range(0,len(frames),12):
        sheet=Image.new('RGB',(1280,(h+30)*min(6,(len(frames)-start+1)//2)),(24,24,24));draw=ImageDraw.Draw(sheet)
        for k,im in enumerate(frames[start:start+12]):
            x=(k%2)*640;y=(k//2)*(h+30);sheet.paste(im,(x,y));draw.text((x+8,y+h+7),f'Video {n} | {(start+k)*2}s',fill='white')
        sheet.save(root/f'{prefix}{n}_sheet_{start//12}.jpg')

