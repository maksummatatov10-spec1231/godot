#!/usr/bin/env python3
"""Read every external library file; record inspection depth rather than guessing."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
import re
import struct
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageOps
import mutagen

TEXT = {'.txt','.md','.gd','.gdshader','.gdshaderinc','.glsl','.comp','.cs','.py','.cfg','.ini','.json','.tscn','.tres','.mtl','.obj','.gltf','.svg','.uid','.import','.url','.gdextension'}
AUDIO = {'.wav','.ogg','.mp3','.m4a'}
IMAGES = {'.png','.jpg','.tga'}


def pack_name(path):
    for part in path.parts:
        if part.endswith('.contents'):
            return part[:-9]
    return 'loose files'


def gltf_metadata(doc, path):
    result = {key:len(doc.get(key,[])) for key in ['meshes','nodes','materials','skins','animations','textures','images','accessors']}
    result['animation_names'] = [a.get('name',str(i)) for i,a in enumerate(doc.get('animations',[]))]
    result['vertices'] = sum(doc['accessors'][p['attributes']['POSITION']]['count'] for m in doc.get('meshes',[]) for p in m['primitives'] if 'POSITION' in p.get('attributes',{}))
    result['external_dependencies'] = []
    result['missing_dependencies'] = []
    for item in doc.get('buffers',[]) + doc.get('images',[]):
        uri = item.get('uri','')
        if uri and not uri.startswith('data:'):
            result['external_dependencies'].append(uri)
            # Never access remote URLs or traverse outside the asset directory.
            from urllib.parse import unquote
            ref = (path.parent / unquote(uri)).resolve()
            if '://' in uri or not ref.is_relative_to(path.parent.resolve()):
                result.setdefault('nonlocal_dependencies',[]).append(uri)
            elif not ref.is_file():
                result['missing_dependencies'].append(uri)
    return result


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('root',type=Path); ap.add_argument('output',type=Path)
    args=ap.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    files=[]; licenses=[]; hashes=defaultdict(list); sheets=[]; tiles=[]
    def flush_tiles():
        if not tiles:return
        sheet=Image.new('RGB',(1200, math.ceil(len(tiles)/6)*150),'#20242b')
        d=ImageDraw.Draw(sheet)
        index=len(sheets)+1
        for j,(thumb,label) in enumerate(tiles):
            x=(j%6)*200; y=(j//6)*150
            sheet.paste(thumb,(x+(200-thumb.width)//2,y))
            d.text((x+4,y+117),label,fill='white')
        name=f'textures-{index:02d}.jpg'; sheet.save(args.output/name,quality=85)
        sheets.append({'file':name,'paths':[p for _,_,p in tile_refs]})
        tiles.clear();tile_refs.clear()
    tile_refs=[]
    for p in sorted(args.root.rglob('*')):
        if not p.is_file():continue
        rel=p.relative_to(args.root).as_posix(); ext=p.suffix.lower()
        data=p.read_bytes(); digest=hashlib.sha256(data).hexdigest()
        entry={'path':rel,'pack':pack_name(p.relative_to(args.root)),'bytes':len(data),'sha256':digest,'extension':ext,'inspection':['full-byte SHA-256','file signature']}
        hashes[digest].append(rel)
        entry['signature_hex']=data[:16].hex()
        try:
            if ext in TEXT or p.name.upper() in {'LICENSE','COPYING'}:
                try:text=data.decode('utf-8-sig');entry['encoding']='utf-8'
                except UnicodeDecodeError:text=data.decode('cp1252');entry['encoding']='cp1252'
                entry.update(lines=len(text.splitlines()),characters=len(text));entry['inspection'].append('full text read')
                if any(x in p.name.lower() for x in ['licen','readme','copyright','copying']):
                    licenses.append({'path':rel,'pack':entry['pack'],'text':text})
                if ext in {'.gd','.py','.cs','.gdshader','.gdshaderinc','.glsl','.comp'}:
                    entry['code_risk_indicators']=sorted(set(re.findall(r'OS\.execute|OS\.create_process|HTTPClient|HTTPRequest|load\(|preload\(|FileAccess|DirAccess|Process\.Start|subprocess|eval\(|exec\(|@tool|class_name',text)))
                    entry['inspection'].append('static code pattern scan; NOT executed or security audited')
                if ext in {'.tscn','.tres','.import','.gdextension','.cfg','.gd','.gdshader'}:
                    entry['resource_references']=sorted(set(re.findall(r'(?:res|uid)://[^\s\"\)\]]+',text)))
                if ext in {'.gltf','.json'}:
                    doc=json.loads(text);entry['inspection'].append('JSON parsed')
                    if ext=='.gltf':entry['model']=gltf_metadata(doc,p)
                if ext=='.svg':
                    svg=ET.fromstring(text);entry['svg']={k:svg.attrib.get(k) for k in ['width','height','viewBox']};entry['inspection'].append('XML parsed; no external resources loaded')
                if ext=='.obj':
                    lines=text.splitlines()
                    vertices=[]
                    for line in lines:
                        if line.startswith('v '):vertices.append([float(x) for x in line.split()[1:4]])
                    entry['model']={'vertices':len(vertices),'faces':sum(l.startswith('f ') for l in lines),'triangles':sum(max(0,len(l.split())-3) for l in lines if l.startswith('f ')), 'objects':sum(l.startswith('o ') for l in lines),'material_libraries':[l[7:].strip() for l in lines if l.startswith('mtllib ')]}
                    if vertices:entry['model']['bounds']=[[min(v[i] for v in vertices) for i in range(3)],[max(v[i] for v in vertices) for i in range(3)]]
                    entry['inspection'].append('OBJ geometry parsed')
                if ext=='.mtl':entry['texture_maps']=[l.strip() for l in text.splitlines() if re.match(r'\s*(?:map_|bump\s)',l)]
            if ext in IMAGES:
                with Image.open(p) as im:
                    entry['image']={'width':im.width,'height':im.height,'mode':im.mode,'format':im.format}
                    im.load();entry['inspection'].append('all image pixels decoded')
                    if im.width*im.height>4096**2:entry['image']['large_texture']=True
                    thumb=ImageOps.contain(im.convert('RGBA'),(192,112))
                    background=Image.new('RGB',thumb.size,'#808080');background.paste(thumb,mask=thumb.getchannel('A'))
                    label=f'{len(files):04d} '+p.name.encode('ascii','replace').decode()[:24]
                    tiles.append((background,label));tile_refs.append((background,label,rel))
                    if len(tiles)==48:flush_tiles()
            if ext in AUDIO:
                audio=mutagen.File(p)
                if audio is None:raise ValueError('Unsupported audio container')
                info=audio.info
                entry['audio']={k:getattr(info,k) for k in ['length','sample_rate','channels','bitrate','bits_per_sample'] if hasattr(info,k)}
                entry['inspection'].append('audio container/header parsed; decode tested separately')
            if ext=='.glb':
                magic,version,length=struct.unpack_from('<4sII',data)
                if magic!=b'glTF' or length!=len(data):raise ValueError('Invalid GLB header')
                chunklen,kind=struct.unpack_from('<II',data,12)
                if kind!=0x4e4f534a:raise ValueError('Missing GLB JSON')
                entry['model']=gltf_metadata(json.loads(data[20:20+chunklen]),p)
                entry['inspection'].append('GLB JSON and header parsed')
            if ext in {'.so','.dll','.dylib','.wasm','.pck','.x86_64','.debug','.release'}:
                entry['warning']='Binary/code asset: not executed, loaded, or audited'
            if ext in {'.fbx','.blend'}:
                entry['inspection'].append('Blender inspection recorded separately by SHA-256')
            if ext in {'.exr','.hdr'}:entry['inspection'].append('HDR decode recorded separately using Blender')
        except Exception as e:entry['error']=f'{type(e).__name__}: {e}'
        files.append(entry)
    flush_tiles()
    duplicates=[{'sha256':h,'paths':paths} for h,paths in hashes.items() if len(paths)>1]
    summary={'file_count':len(files),'bytes':sum(f['bytes'] for f in files),'unique_hashes':len(hashes),'extensions':dict(Counter(f['extension'] for f in files)), 'packs':dict(Counter(f['pack'] for f in files)), 'errors':[{'path':f['path'],'error':f['error']} for f in files if 'error' in f], 'duplicate_groups':len(duplicates),'texture_sheets':sheets}
    for name,obj in [('files.json',files),('licenses.json',licenses),('duplicates.json',duplicates),('summary.json',summary)]:
        (args.output/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in summary.items() if k!='texture_sheets'},indent=2))

if __name__=='__main__':main()
