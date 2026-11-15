#!/usr/bin/env python3
"""Build compact GitHub-readable catalog and model contact sheets, not assets."""
from collections import Counter, defaultdict
import csv
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys
from PIL import Image, ImageDraw

source,dest=map(Path,sys.argv[1:]);dest.mkdir(parents=True,exist_ok=True)
files=json.loads((source/'files.json').read_text())
models={r['sha256']:r for r in map(json.loads,(source/'blender-models.jsonl').read_text().splitlines())}
audio={r['sha256']:r for r in map(json.loads,(source/'audio-inspection.jsonl').read_text().splitlines())}
previews=dest/'previews';previews.mkdir(exist_ok=True)
packs=defaultdict(list)
for f in files:packs[f['pack']].append(f)
preview_lookup={};sheets=[]

def projection(record):
    image=Image.new('RGB',(192,142),'#242b36');draw=ImageDraw.Draw(image)
    path=source/'geometry'/(record['sha256']+'.json')
    if not path.exists():return image
    data=json.loads(path.read_text())
    points=[p for poly in data['polygons'] for p in poly['points']]+[p for line in data['bones'] for p in line]
    points=[p for p in points if all(math.isfinite(v) for v in p)]
    if not points:return image
    low=[min(p[i] for p in points) for i in (0,1)];high=[max(p[i] for p in points) for i in (0,1)]
    scale=min(180/max(1e-8,high[0]-low[0]),130/max(1e-8,high[1]-low[1]))
    center=[(high[i]+low[i])/2 for i in (0,1)]
    def xy(p):return (96+(p[0]-center[0])*scale,71-(p[1]-center[1])*scale)
    for poly in sorted(data['polygons'],key=lambda p:p['depth']):
        if len(poly['points'])>=3 and all(all(math.isfinite(v) for v in p) for p in poly['points']):
            draw.polygon([xy(p) for p in poly['points']],fill=tuple(poly['rgb']))
    if not data['polygons']:
        for line in data['bones']:draw.line([xy(p) for p in line],fill='#55dda0',width=2)
    return image

representatives=[]
for pack,members in sorted(packs.items()):
    slug=hashlib.sha256(pack.encode()).hexdigest()[:10]
    seen=set();items=[]
    for f in members:
        m=models.get(f['sha256'])
        if m and m.get('status')=='ok' and f['sha256'] not in seen and f['extension'] in {'.fbx','.blend','.gltf','.glb','.obj'}:
            seen.add(f['sha256']);items.append(f)
    for offset in range(0,len(items),42):
        group=items[offset:offset+42]
        canvas=Image.new('RGB',(1200,40+math.ceil(len(group)/6)*180),'#171c24');d=ImageDraw.Draw(canvas)
        d.text((10,10),pack.encode('ascii','replace').decode()+' | geometry only, NOT textured render',fill='white')
        page=f'models-{slug}-{offset//42+1:02d}.jpg'
        for i,f in enumerate(group):
            tile=projection(f);x=i%6*200;y=40+i//6*180
            canvas.paste(tile,(x+4,y))
            name=Path(f['path']).name.encode('ascii','replace').decode()
            d.text((x+4,y+145),name[:30],fill='white')
            m=models[f['sha256']]
            d.text((x+4,y+160),str(m.get('triangles',0))+' tris',fill='#9ab4c8')
            preview_lookup[f['sha256']]='previews/'+page
        canvas.save(previews/page,quality=80)
        sheets.append({'file':'previews/'+page,'pack':pack,'paths':[f['path'] for f in group]})
    if items:
        # Prefer glTF and render varied members, not simply the first alphabetic item.
        preferred=[f for f in items if f['extension'] in {'.gltf','.glb'}] or items
        selected=[preferred[min(len(preferred)-1,int((len(preferred)-1)*q))] for q in [0,0.33,0.66,1]]
        representatives.append((pack,selected))

for offset in range(0,len(representatives),8):
    group=representatives[offset:offset+8]
    canvas=Image.new('RGB',(1000,45+len(group)*180),'#171c24');d=ImageDraw.Draw(canvas)
    d.text((10,10),'LIBRARY GEOMETRY OVERVIEW - isometric projections, NOT game renders',fill='white')
    for row,(pack,items) in enumerate(group):
        y=45+row*180
        d.text((8,y+4),pack[:27],fill='white')
        for col,f in enumerate(items):
            x=200+col*200
            canvas.paste(projection(f),(x,y))
            d.text((x,y+145),Path(f['path']).name[:26].encode('ascii','replace').decode(),fill='white')
    canvas.save(previews/f'overview-{offset//8+1:02d}.jpg',quality=88)

for p in source.glob('textures-*.jpg'):shutil.copyfile(p,previews/p.name)
for name in ['files.json','summary.json','duplicates.json','licenses.json','dependency-issues.json','binary-inspection.json','blender-models.jsonl','audio-inspection.jsonl']:
    shutil.copyfile(source/name,dest/name)
# CSVs are safe to open in spreadsheet software: prefix formula-leading strings.
def csvsafe(value):
    text=str(value)
    return "'"+text if text.startswith(('=','+','-','@','\t','\r')) else text
with (dest/'files.csv').open('w',newline='') as stream:
    writer=csv.writer(stream);writer.writerow(['path','pack','extension','bytes','sha256','inspection','vertices','triangles','bones','actions','audio_seconds','preview'])
    for f in files:
        m=models.get(f['sha256'],f.get('model',{}));a=audio.get(f['sha256'],{})
        writer.writerow([csvsafe(v) for v in [f['path'],f['pack'],f['extension'],f['bytes'],f['sha256'],'; '.join(f['inspection']),m.get('vertices',''),m.get('triangles',''),m.get('bones',''),len(m.get('actions',[])),a.get('decoded_seconds',''),preview_lookup.get(f['sha256'],'')]])
index=['# Пофайловый каталог\n','Индексы ниже охватывают каждый файл, включая архивы, служебные файлы и альтернативные форматы. Число файлов — не число уникальных игровых объектов.\n','[CSV всех файлов](files.csv) · [Полные метаданные](files.json) · [Дубликаты](duplicates.json) · [Зависимости](dependency-issues.json)\n','| Набор | Файлов | Форматы |\n|---|---:|---|']
packdir=dest/'packs';packdir.mkdir(exist_ok=True)
for pack,members in sorted(packs.items()):
    slug=hashlib.sha256(pack.encode()).hexdigest()[:10]
    exts=', '.join(f'{ext or "без расширения"}: {n}' for ext,n in Counter(f['extension'] for f in members).most_common())
    index.append(f'| [{pack}](packs/{slug}.md) | {len(members)} | {exts} |')
    lines=[f'# {pack}\n',f'Файлов: **{len(members)}**. Форматы: {exts}.\n','Полные SHA-256, технические проверки и ссылки зависимостей доступны в `../files.json`; параметры импорта — в `../blender-models.jsonl`.\n']
    pack_sheets=[s for s in sheets if s['pack']==pack]
    for s in pack_sheets:lines.append(f'[Геометрия: {Path(s["file"]).name}](../{s["file"]})')
    lines+=['\n| Файл относительно `extracted/` | Байт | Результат технического разбора |\n|---|---:|---|']
    for f in members:
        m=models.get(f['sha256']);a=audio.get(f['sha256']);info=[]
        if m:
            if m['status']=='ok':
                if 'image' in m:info.append(str(m['image']['width'])+'×'+str(m['image']['height'])+' HDR decoded')
                else:info.append(f'Blender OK; {m["vertices"]} vertices, {m["triangles"]} triangles, {m["bones"]} bones, {len(m["actions"])} actions')
            else:info.append('Blender ERROR: '+m.get('error',''))
        elif a:info.append(f'Audio {a["status"]}; {a.get("decoded_seconds",0):.3f} s')
        elif f.get('image'):info.append(f'Pixels decoded; {f["image"]["width"]}×{f["image"]["height"]}')
        elif f['extension'] in {'.zip','.rar'}:info.append('Archive extracted, CRC checked')
        else:info.append('; '.join(f['inspection']))
        if f.get('model',{}).get('missing_dependencies'):info.append('MISSING RELATIVE DEPENDENCIES — see dependency report')
        if f.get('warning'):info.append(f['warning'])
        name=f['path'].replace('|','&#124;')
        lines.append(f'| `{name}` | {f["bytes"]} | '+ '; '.join(info).replace('|','&#124;')+' |')
    (packdir/(slug+'.md')).write_text('\n'.join(lines)+'\n')
(dest/'INDEX.md').write_text('\n'.join(index)+'\n')
(dest/'model-preview-index.json').write_text(json.dumps(sheets,ensure_ascii=False,indent=2)+'\n')
print('Published',len(files),'file records,',len(models),'unique Blender inspection results,',len(audio),'unique audio hashes,',len(sheets),'model sheets')
