"""Stage toolchain DLL closure and verify PE AMD64; not Windows execution."""
import pathlib,re,shutil,subprocess,sys
root=pathlib.Path(sys.argv[1]); tc=pathlib.Path(sys.argv[2]); tool=tc/'bin/llvm-readobj'
system={'kernel32.dll','ntdll.dll','advapi32.dll','bcrypt.dll','crypt32.dll','ws2_32.dll','mswsock.dll','iphlpapi.dll','user32.dll','shell32.dll','ole32.dll','oleaut32.dll','userenv.dll','secur32.dll','msvcrt.dll','ucrtbase.dll'}
queue=list(root.glob('*.dll'));seen=set()
if not queue:raise SystemExit('No DLL candidates')
while queue:
 p=queue.pop(0)
 if p.name.lower() in seen:continue
 seen.add(p.name.lower())
 header=subprocess.check_output([str(tool),'--file-headers',str(p)],text=True)
 if 'IMAGE_FILE_MACHINE_AMD64' not in header:raise SystemExit(f'{p.name}: not AMD64 PE')
 imports=subprocess.check_output([str(tool),'--coff-imports',str(p)],text=True)
 needed=re.findall(r'^  Name: (.+)$',imports,re.M)
 for name in needed:
  if name.lower() in system or name.lower().startswith('api-ms-win-crt-'):continue
  dst=root/name
  if not dst.exists():
   src=tc/'x86_64-w64-mingw32/bin'/name
   if not src.is_file():raise SystemExit(f'{p.name}: unresolved {name}')
   shutil.copyfile(src,dst)
  queue.append(dst)
 print(p.name,'AMD64 imports:',','.join(needed))
exports=subprocess.check_output([str(tool),'--coff-exports',str(root/'libamber.dll')],text=True)
if 'Name: amber_library_init' not in exports:raise SystemExit('GDExtension entry missing')
print('amber_library_init export present; runtime execution NOT verified')

matched=0
for p in root.glob('*.dll'):
 imports=subprocess.check_output([str(tool),'--coff-imports',str(p)],text=True)
 for block in re.findall(r'Import \{(.*?)\n\}',imports,re.S):
  name=re.search(r'Name: (.+)',block).group(1); other=root/name
  if not other.exists():continue
  exp=subprocess.check_output([str(tool),'--coff-exports',str(other)],text=True)
  names=set(re.findall(r'^  Name: (.*)$',exp,re.M))
  for symbol in re.findall(r'^  Symbol: (.*?) \(',block,re.M):
   if symbol not in names:raise SystemExit(f'{p.name}: {symbol} not exported by {name}')
   matched+=1
print('Matched sibling DLL named imports:',matched)
