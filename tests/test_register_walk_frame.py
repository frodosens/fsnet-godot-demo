"""Synthetic registration checks; do not imply raw generator sources are present."""
import hashlib,json,pathlib,subprocess,sys,tempfile,unittest
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
            self.assertEqual(result.size,(96,128));self.assertEqual(result.mode,'RGBA')
            receipt=json.loads(a.with_suffix('.registration.json').read_text());self.assertEqual(receipt['source_sha256'],hashlib.sha256(source.read_bytes()).hexdigest())
            self.assertEqual(receipt['output_sha256'],hashlib.sha256(a.read_bytes()).hexdigest())
            before=a.read_bytes();self.assertNotEqual(run(a).returncode,0);self.assertEqual(before,a.read_bytes())
            for value in ['-1','256','bad']:
                self.assertNotEqual(run(d/'bad.png','--alpha-floor',value).returncode,0);self.assertFalse((d/'bad.png').exists())
            self.assertNotEqual(run(d/'bad.jpg').returncode,0)
            (d/'receipt.registration.json').write_text('keep');self.assertNotEqual(run(d/'receipt.png').returncode,0)
            link=d/'link.png';link.symlink_to(d/'missing.png');self.assertNotEqual(run(link).returncode,0);self.assertFalse((d/'missing.png').exists())
            Image.new('RGBA',(128,96)).save(source);self.assertNotEqual(run(d/'nonsquare.png').returncode,0);self.assertFalse((d/'nonsquare.png').exists())
if __name__=='__main__':unittest.main()
