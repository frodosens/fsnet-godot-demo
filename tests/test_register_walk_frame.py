"""Synthetic registration checks; do not imply raw generator sources are present."""
import hashlib,json,pathlib,subprocess,sys,tempfile,unittest,runpy,io
from unittest import mock
from contextlib import redirect_stdout
from PIL import Image
SCRIPT=pathlib.Path(__file__).resolve().parents[1]/'tools/art/register_walk_frame.py'
class RegisterTests(unittest.TestCase):
    def test_registration_and_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            d=pathlib.Path(directory);source=d/'source.png';image=Image.new('RGBA',(256,256));image.putpixel((96,200),(200,100,40,255));image.putpixel((100,200),(1,2,3,7));image.save(source)
            def run(out,*args):return subprocess.run([sys.executable,str(SCRIPT),str(source),str(out),*args],capture_output=True,text=True)
            a=d/'a.png';b=d/'b.png'
            self.assertEqual(run(a).returncode,0);self.assertEqual(run(b).returncode,0)
            self.assertEqual(a.read_bytes(),b.read_bytes());result=Image.open(a)
            self.assertEqual(result.size,(96,128));self.assertEqual(result.mode,'RGBA');result.close()
            receipt=json.loads(a.with_suffix('.registration.json').read_text());self.assertEqual(receipt['source_sha256'],hashlib.sha256(source.read_bytes()).hexdigest())
            self.assertEqual(receipt['output_sha256'],hashlib.sha256(a.read_bytes()).hexdigest())
            before=a.read_bytes();self.assertNotEqual(run(a).returncode,0);self.assertEqual(before,a.read_bytes())
            for value in ['-1','256','bad']:
                self.assertNotEqual(run(d/'bad.png','--alpha-floor',value).returncode,0);self.assertFalse((d/'bad.png').exists())
            self.assertNotEqual(run(d/'bad.jpg').returncode,0)
            (d/'receipt.registration.json').write_text('keep');self.assertNotEqual(run(d/'receipt.png').returncode,0)
            link=d/'link.png';link.symlink_to(d/'missing.png');self.assertNotEqual(run(link).returncode,0);self.assertFalse((d/'missing.png').exists())
            Image.new('RGBA',(128,96)).save(source);self.assertNotEqual(run(d/'nonsquare.png').returncode,0);self.assertFalse((d/'nonsquare.png').exists())
    def test_receipt_failure_cleanup_and_retry(self):
        for failure in ('open', 'partial_write', 'competing_receipt'):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                d=pathlib.Path(directory);source=d/'source.png';out=d/'candidate.png';receipt=out.with_suffix('.registration.json')
                Image.new('RGBA',(128,128),(50,100,150,255)).save(source)
                source_bytes=source.read_bytes();original_open=pathlib.Path.open
                class FailingWriter:
                    def __init__(self,file):self.file=file
                    def __enter__(self):return self
                    def __exit__(self,*args):return self.file.__exit__(*args)
                    def fileno(self):return self.file.fileno()
                    def write(self,payload):
                        self.file.write(payload[:12]);self.file.flush()
                        raise OSError('injected receipt write failure')
                def failing_open(path,*args,**kwargs):
                    if path==receipt and args and args[0]=='xb':
                        if failure=='open':raise OSError('injected receipt open failure')
                        if failure=='competing_receipt':
                            with original_open(path,'xb') as existing:existing.write(b'not owned by this invocation')
                            raise FileExistsError('injected competing receipt')
                        return FailingWriter(original_open(path,*args,**kwargs))
                    return original_open(path,*args,**kwargs)
                with mock.patch.object(pathlib.Path,'open',failing_open), mock.patch.object(sys,'argv',[str(SCRIPT),str(source),str(out)]), redirect_stdout(io.StringIO()):
                    with self.assertRaises(OSError):runpy.run_path(str(SCRIPT),run_name='__main__')
                self.assertFalse(out.exists());self.assertEqual(source.read_bytes(),source_bytes)
                if failure=='competing_receipt':
                    self.assertEqual(receipt.read_bytes(),b'not owned by this invocation')
                    # Test fixture removes its own simulated competitor, not production cleanup.
                    receipt.unlink()
                else:self.assertFalse(receipt.exists())
                result=subprocess.run([sys.executable,str(SCRIPT),str(source),str(out)],capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stderr)
                reference=d/'reference.png'
                self.assertEqual(subprocess.run([sys.executable,str(SCRIPT),str(source),str(reference)],capture_output=True).returncode,0)
                self.assertEqual(out.read_bytes(),reference.read_bytes())
                self.assertEqual(receipt.read_bytes(),reference.with_suffix('.registration.json').read_bytes())
if __name__=='__main__':unittest.main()
