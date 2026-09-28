"""Encode raw Godot frames; comparison panels use identical timestamps, no retouching."""
from pathlib import Path
import sys
import subprocess
import json

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/python_libs'))
import imageio_ffmpeg

ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
revision = int(sys.argv[1]) if len(sys.argv) > 1 else 10
out = ROOT / f'research/v{revision}_compare'

def run(args):
    result = subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', *args],
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr)

for name in ['before', 'after']:
    frames = list((out / name).glob('frame_*.png'))
    assert len(frames) == 120, (name, len(frames))
    run(['-framerate', '15', '-i', str(out / name / 'frame_%03d.png'),
         '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p',
         '-movflags', '+faststart', str(out / f'{name}.mp4')])

font = 'C\\:/Windows/Fonts/arial.ttf'
filters = (
    f"[0:v]scale=960:540,pad=960:588:0:48:color=0x14272c,drawtext=fontfile='{font}':"
    f"text='BEFORE - V{revision-1:02d}':x=24:y=13:fontsize=24:fontcolor=white[left];"
    f"[1:v]scale=960:540,pad=960:588:0:48:color=0x14272c,drawtext=fontfile='{font}':"
    f"text='AFTER - V{revision:02d}':x=24:y=13:fontsize=24:fontcolor=white[right];"
    "[left][right]hstack=inputs=2[out]"
)
run(['-i', str(out / 'before.mp4'), '-i', str(out / 'after.mp4'),
     '-filter_complex', filters, '-map', '[out]', '-an', '-c:v', 'libx264',
     '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
     str(out / 'comparison.mp4')])
# Decode all frames as a playback sanity check.
run(['-i', str(out / 'comparison.mp4'), '-f', 'null', '-'])
print(json.dumps({p.name: p.stat().st_size for p in out.glob('*.mp4')}, indent=2))
