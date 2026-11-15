#!/usr/bin/env python3
"""Resolve candidate library dependencies without changing original assets."""
from collections import defaultdict
import json
from pathlib import Path
import sqlite3
import struct
import sys

root,out=map(Path,sys.argv[1:])
files=json.loads((out/'files.json').read_text())
by_pack=defaultdict(list)
for f in files:by_pack[f['pack']].append(f)
issues=[];opaque=[]
for f in files:
    missing=f.get('model',{}).get('missing_dependencies',[])
    if missing:
        candidates={}
        for ref in missing:
            matches=[x for x in by_pack[f['pack']] if Path(x['path']).name==Path(ref).name]
            candidates[ref]=[{'path':x['path'],'sha256':x['sha256']} for x in matches]
        issues.append({'path':f['path'],'kind':'missing relative glTF dependency','missing':missing,'same_pack_candidates':candidates})
    if f.get('resource_references'):
        unresolved=[]
        for ref in f['resource_references']:
            if ref.startswith('uid://'):continue
            suffix=ref[6:]
            if not any(x['path'].endswith('/'+suffix) for x in by_pack[f['pack']]):unresolved.append(ref)
        if unresolved:issues.append({'path':f['path'],'kind':'Godot res:// reference with no matching suffix in this pack; static heuristic, not an engine import test','unresolved':unresolved})
    if f['extension'] in {'.bin','.ptex','.rast','.res','.db','.sqlite','.vsidx','.so','.dll','.dylib','.wasm','.pck','.x86_64','.debug','.release'} or not f['extension']:
        p=root/f['path']
        with p.open('rb') as stream:header=stream.read(64)
        info={'path':f['path'],'sha256':f['sha256']}
        if header.startswith(b'\x7fELF'):
            endian='<' if header[5]==1 else '>'
            info.update(type='ELF',bits=32 if header[4]==1 else 64,machine=struct.unpack_from(endian+'H',header,18)[0],executed=False)
        elif header.startswith(b'MZ'):info.update(type='PE/DOS header',executed=False)
        elif header.startswith(b'\x00asm'):info.update(type='WebAssembly',version=int.from_bytes(header[4:8],'little'),executed=False)
        elif header.startswith(b'SQLite format 3\x00'):
            try:
                con=sqlite3.connect(p.resolve().as_uri()+'?mode=ro&immutable=1',uri=True)
                con.execute('PRAGMA trusted_schema=OFF')
                info.update(type='SQLite',tables=con.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall());con.close()
            except Exception as e:info.update(type='SQLite',error=str(e))
        elif f['extension']=='.bin':info['type']='glTF buffer sidecar; consumed by paired glTF Blender import'
        else:info.update(type='opaque binary/cache/resource',inspection='hash and signature only; no semantic parser/runtime validation')
        opaque.append(info)
(out/'dependency-issues.json').write_text(json.dumps(issues,indent=2,ensure_ascii=False)+'\n')
(out/'binary-inspection.json').write_text(json.dumps(opaque,indent=2,ensure_ascii=False)+'\n')
print('Dependency issue records:',len(issues),'Binary/sidecar records:',len(opaque))
