"""A green count/zero exit must never conceal Godot assertion or script errors."""
from pathlib import Path
import subprocess
import sys
import os
import tempfile
runner=Path(__file__).resolve().parents[1]/'tools/run_checked.py'
cases=[("print('CHECKS checks=10 failures=0')",0),
       ("print('WARNING: expected warning')",0),
       ("print('SCRIPT ERROR: Assertion failed.'); print('CHECKS checks=10 failures=0')",1),
       ("import sys; print('ERROR: invalid call',file=sys.stderr)",1),
       ("print('FAIL: stale persistence assertion')",1),
       ("print('FAIL stale persistence assertion')",1),
       ("print('Assertion failed'); print('all checks complete')",1),
       ("print('CHECKS checks=10 failures=2')",1),
       ("raise SystemExit(7)",7)]
for program,expected in cases:
 result=subprocess.run([sys.executable,str(runner),sys.executable,'-c',program],capture_output=True,text=True)
 assert result.returncode==expected,(program,result.returncode,result.stdout,result.stderr)
with tempfile.TemporaryDirectory(prefix='checked-godot-') as folder:
 fixture=Path(folder)/'assert_then_quit.gd'
 fixture.write_text('extends SceneTree\nfunc _initialize():call_deferred("intentional_failure");call_deferred("finish")\nfunc intentional_failure():assert(false,"intentional runner selftest")\nfunc finish():quit(0)\n')
 command=[os.environ.get('GODOT','godot'),'--headless','--path',str(runner.parent.parent),'--script',str(fixture)]
 direct=subprocess.run(command,capture_output=True,text=True,timeout=30)
 assert direct.returncode==0 and 'SCRIPT ERROR' in direct.stdout+direct.stderr,'fixture must reproduce Godot zero-exit assertion'
 checked=subprocess.run([sys.executable,str(runner),*command],capture_output=True,text=True,timeout=30)
 assert checked.returncode!=0 and 'CHECKED_RUNNER:' in checked.stderr,'actual assertion must fail wrapper'
print(f'CHECKED_RUNNER_SELFTEST synthetic={len(cases)} real_godot=2 failures=0')
