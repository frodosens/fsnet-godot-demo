#!/usr/bin/env python3
"""Check arm64 APK payload and native dependency closure after apksigner verifies it."""
import argparse, hashlib, json, pathlib, re, struct, subprocess, tempfile, zipfile
p=argparse.ArgumentParser();p.add_argument('apk');p.add_argument('--readelf',default='llvm-readelf');a=p.parse_args()
system={'libc.so','libm.so','libdl.so','liblog.so','libandroid.so','libEGL.so','libGLESv2.so','libGLESv3.so','libOpenSLES.so','libz.so','libvulkan.so','libaaudio.so','libjnigraphics.so','libcamera2ndk.so','libmediandk.so'}
with zipfile.ZipFile(a.apk) as z, tempfile.TemporaryDirectory() as tmp:
 names=z.namelist(); assert len(names)==len(set(names)), 'Duplicate ZIP entries'; libs=[n for n in names if n.startswith('lib/') and n.endswith('.so')]
 assert libs and all(n.startswith('lib/arm64-v8a/') for n in libs),libs
 required={'libamber.so','libfsnet.so','libc++_shared.so','libgodot_android.so'}
 basenames={pathlib.PurePosixPath(n).name for n in libs};assert required<=basenames,(required,basenames)
 report={}
 for n in libs:
  data=z.read(n);assert data[:4]==b'\x7fELF' and data[4]==2 and struct.unpack_from('<H',data,18)[0]==183,n
  f=pathlib.Path(tmp)/pathlib.PurePosixPath(n).name;f.write_bytes(data)
  dynamic=subprocess.check_output([a.readelf,'-d',str(f)],text=True)
  needed=re.findall(r'\(NEEDED\).*\[(.*?)\]',dynamic)
  assert set(needed)<=system|basenames,(n,needed)
  assert not re.search(r'\((?:RPATH|RUNPATH)\)',dynamic),n
  ph=subprocess.check_output([a.readelf,'-lW',str(f)],text=True)
  aligns=[int(line.split()[-1],16) for line in ph.splitlines() if line.strip().startswith('LOAD ')]
  assert aligns and min(aligns)>=16384,(n,aligns)
  report[n]={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'needed':needed,'load_alignment':aligns}
 forbidden={'build','source','sources','docs','tests','tools','native','CMakeFiles','.git','.deps'}
 for name in names:
  parts=pathlib.PurePosixPath(name).parts
  assert not any(part in forbidden or part.startswith('build-') for part in parts),("development payload",name)
  assert not name.endswith(('.dll','.keystore','.jks','.pem','.key')),("unexpected binary/key",name)
  if name.startswith('assets/') and name.endswith(('.json','.lua')):
   assert name.startswith(('assets/logic/','assets/content/','assets/assets/')),("nonruntime data",name)
   payload=z.read(name)
   assert b'/workspace/' not in payload and b'/home/agent/' not in payload,("local path leak",name)
 assert 'assets/content/white_elm_watchhouse.json' in names
 assert 'assets/logic/battle.lua' in names
 print(json.dumps({'apk_sha256':hashlib.file_digest(open(a.apk,'rb'),'sha256').hexdigest(),'libraries':report,'chapter_two_json':True,'shared_lua_rules':True},indent=2))
