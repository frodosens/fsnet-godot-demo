#!/usr/bin/env python3
"""Real authority/client test: unchanged sync must not restart map gait."""
import json,os,pathlib,secrets,socket,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
env=os.environ.copy();env['AMBER_TOKEN']=secrets.token_hex(24)
with tempfile.TemporaryDirectory(prefix='walk-network-') as folder:
    data=json.loads((root/'content/reference_bridge.json').read_text())
    actor=env.get('AMBER_WALK_ACTOR','finn');direction=env.get('AMBER_WALK_DIRECTION','front_right')
    if actor in ('adela','elsbet'):
        data['units'][0 if actor=='adela' else 3].update(id=actor,name='阿黛拉' if actor=='adela' else '埃尔丝贝特')
        data['story']['events']=[]
    if actor=='rodd':
        data['units'][0].update(id='rodd',name='罗德');data['story']['events']=[]
    if actor=='vera':
        data['units'][1].update(id='vera',name='维拉');data['story']['events']=[]
    if direction=='front_right' and actor=='finn':data['units'][1].update(x=1,y=8)
    else:
        data['units'][0].update(x=1,y=6);data['units'][1].update(x=2,y=7);data['units'][2].update(x=6,y=8)
        unit=next(u for u in data['units'] if u['id']==actor)
        unit.update(x=1 if direction=='front_right' else 4,y=5 if direction=='front_left' else 8,ally=True,movement=3)
    path=pathlib.Path(folder)/'fixture.json';path.write_text(json.dumps(data));env['AMBER_MOD']=str(path)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0));env['AMBER_TEST_PORT']=str(sock.getsockname()[1])
    base=[env.get('GODOT','godot'),'--headless','--path',str(root)]
    server=subprocess.Popen(base+['--script','res://server.gd','--','--port='+env['AMBER_TEST_PORT']],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    try:
        for line in server.stdout:
            if 'AMBER_SERVER_READY' in line:break
        else:raise RuntimeError('authority failed startup')
        result=subprocess.run(base+['--script','res://tests/network_walk.gd'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=30)
        print(result.stdout,end='')
        assert result.returncode==0 and 'NETWORK_WALK failures=0' in result.stdout and 'SCRIPT ERROR' not in result.stdout
    finally:
        server.terminate()
        try:server.wait(timeout=5)
        except subprocess.TimeoutExpired:server.kill();server.wait()
