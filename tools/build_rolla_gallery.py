"""Assemble real Godot renders into a searchable gallery and numbered contact sheets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
import html
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'research/rolla_previews'
rows = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))
font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 15)
heading = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 30)
assert len(rows) == 278 and all(row['save_error'] == 0 for row in rows)
for row in rows:
    path = OUT / row['image']
    reverse = path.with_name(path.stem + '_reverse.png')
    if reverse.exists():
        front = Image.open(path).convert('RGB')
        if front.width == 420:
            pair = Image.new('RGB', (840, 340), '#e0e6eb')
            pair.paste(front, (0, 0))
            pair.paste(Image.open(reverse).convert('RGB'), (420, 0))
            pair.save(path)

def sheet(items, columns, tile_width, filename, title):
    tile_height = round(tile_width * 340 / 840) + 48
    canvas = Image.new('RGB', (columns * tile_width, math.ceil(len(items) / columns) * tile_height + 76), '#f4f6f8')
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 15), title, font=heading, fill='#162a3b')
    draw.text((20, 51), 'Real Godot renders | IDs match model filenames | Characters shown in bind pose', font=font, fill='#516373')
    for i, row in enumerate(items):
        x, y = i % columns * tile_width, i // columns * tile_height + 76
        image = Image.open(OUT / row['image']).convert('RGB')
        image.thumbnail((tile_width - 8, tile_height - 48))
        canvas.paste(image, (x + (tile_width - image.width) // 2, y))
        label = Path(row['model']).stem
        for line, offset in [(label[:31], 0), (label[31:62], 18)]:
            draw.text((x + 7, y + tile_height - 44 + offset), line, font=font, fill='#233b4e')
    canvas.save(OUT / filename)

sheet(rows, 12, 240, 'all_models.png', 'ROLLA / ALL 278 MODEL VARIANTS')
for start in range(0, len(rows), 36):
    sheet(rows[start:start + 36], 6, 320, f'page_{start // 36 + 1:02d}.png',
          f'ROLLA / {start + 1:03d} - {min(start + 36, len(rows)):03d} / 278')

cards = '\n'.join(f'<a class="card" href="{html.escape(r["image"])}" target="_blank" data-name="{html.escape(r["model"].lower())}"><img src="{html.escape(r["image"])}" loading="lazy"><span>{html.escape(Path(r["model"]).stem)}</span></a>' for r in rows)
document = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ROLLA 全部模型图册</title>
<style>body{margin:0;background:#eff3f6;color:#172d3e;font:15px system-ui,sans-serif}header{padding:24px 32px;background:#fff;position:sticky;top:0;z-index:2;border-bottom:1px solid #d4dfe8}h1{margin:0 0 8px;font-size:25px}p{margin:5px 0;color:#53697b}input{margin-top:16px;padding:12px 15px;width:min(600px,85%);border:1px solid #bdcdda;border-radius:8px;font-size:16px}#count{margin-left:15px}main{padding:20px;display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px}.card{background:white;border:1px solid #d4dfe8;border-radius:10px;overflow:hidden;color:inherit;text-decoration:none}.card:hover{border-color:#267eac;box-shadow:0 4px 20px #23456022}.card img{display:block;width:100%;aspect-ratio:420/340;object-fit:contain;background:#e0e6eb}.card span{display:block;padding:12px;overflow-wrap:anywhere;font:13px Consolas,monospace}a{color:#1a719d}</style>
<header><h1>ROLLA · 全部模型图册</h1><p>278 个材质变体，覆盖 233 个有效网格。点击图片查看原图。</p><p>来自项目内的真实 Godot 渲染。人物以绑定姿态展示；部分模型为建筑构件、人物零件或特效平面。</p><p><a href="all_models.png" target="_blank">全部模型总览图</a> · ''' + ' · '.join(f'<a href="page_{i:02d}.png" target="_blank">分图 {i}</a>' for i in range(1, 9)) + '''</p><input id="search" placeholder="搜索模型名称，例如 man / woman / enemy / truck / wall / tree"><span id="count">278 / 278</span></header><main>''' + cards + '''</main><script>const cards=[...document.querySelectorAll('.card')];document.querySelector('#search').addEventListener('input',e=>{let n=0;const q=e.target.value.toLowerCase().trim();for(const c of cards){const ok=c.dataset.name.includes(q);c.style.display=ok?'':'none';if(ok)n++}document.querySelector('#count').textContent=n+' / 278'})</script></html>'''
document = document.replace('aspect-ratio:420/340', 'aspect-ratio:840/340').replace('真实 Godot 渲染。', '真实 Godot 渲染，每项展示两个相反方向。')
(OUT / 'index.html').write_text(document, encoding='utf-8')
print(f'Gallery complete: {len(rows)} renders, 8 contact sheets, full overview')
