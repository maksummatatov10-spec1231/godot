#!/usr/bin/env python3
"""Decode all library audio with ffmpeg; technical checks, not listening review."""
import array
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import imageio_ffmpeg

root,out=map(Path,sys.argv[1:])
records=json.loads((out/'files.json').read_text())
files=[r for r in records if r['extension'] in {'.wav','.ogg','.mp3','.m4a'}]
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()

def inspect(r):
    result={'path':r['path'],'sha256':r['sha256'],'method':'full ffmpeg decode to mono 8000 Hz s16le; technical analysis only, not human listening'}
    try:
        process=subprocess.run([ffmpeg,'-v','error','-nostdin','-threads','1','-i',str(root/r['path']),'-vn','-ac','1','-ar','8000','-f','s16le','-'],capture_output=True,timeout=90)
        if process.returncode:raise RuntimeError(process.stderr.decode(errors='replace')[:2000])
        samples=array.array('h');samples.frombytes(process.stdout)
        if sys.byteorder!='little':samples.byteswap()
        if not samples:raise ValueError('No decoded samples')
        n=len(samples);peak=max(abs(v) for v in samples);rms=math.sqrt(sum(v*v for v in samples)/n)
        step=max(1,math.ceil(n/100))
        result.update(status='ok',decoded_seconds=n/8000,peak=peak/32768,rms=rms/32768,near_zero_fraction=sum(abs(v)<=2 for v in samples)/n,clipped_sample_fraction=sum(abs(v)>=32767 for v in samples)/n,envelope=[max(abs(v) for v in samples[i:i+step])/32768 for i in range(0,n,step)],decoder_stderr=process.stderr.decode(errors='replace')[:2000])
    except Exception as e:result.update(status='error',error=str(e))
    return result

with (out/'audio-inspection.jsonl').open('w') as f:
    for i,result in enumerate(ThreadPoolExecutor(3).map(inspect,files)):
        f.write(json.dumps(result)+'\n');f.flush()
        print(i+1,'/',len(files),result['status'],result['path'],flush=True)
