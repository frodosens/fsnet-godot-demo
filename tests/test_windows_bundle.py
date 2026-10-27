"""Portable checks for a clone's Windows runtime; does not execute Windows code."""
import hashlib,json,pathlib,struct
root=pathlib.Path(__file__).resolve().parents[1]
folder=root/'bin/windows/x86_64'
data=json.loads((folder/'manifest.json').read_text())
for name,expected in data['files'].items():
    raw=(folder/name).read_bytes()
    assert len(raw)==expected['bytes'] and hashlib.sha256(raw).hexdigest()==expected['sha256'],name
    assert raw[:2]==b'MZ',name
    offset=struct.unpack_from('<I',raw,0x3c)[0]
    assert raw[offset:offset+4]==b'PE\0\0' and struct.unpack_from('<H',raw,offset+4)[0]==0x8664,name
for path,digest in data['native_source_sha256'].items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==digest,'Native source changed: rebuild Windows bundle: '+path
config=(root/'amber.gdextension').read_text()
for name in data['files']:assert 'res://bin/windows/x86_64/'+name in config,name
assert 'linux.debug.x86_64 = "res://bin/libamber.so"' in config
print('WINDOWS_BUNDLE hashes/source identity/PE AMD64/declarations: PASS; Windows execution NOT tested')
