#!/usr/bin/env python3
"""Real authority/client allied transit and ordered move/action presentation."""
import json,os,pathlib,secrets,socket,subprocess,tempfile,queue,threading
root=pathlib.Path(__file__).resolve().parents[1]
env=os.environ.copy();env['AMBER_TOKEN']=secrets.token_hex(24)
with tempfile.TemporaryDirectory(prefix='event-network-') as folder:
    data=json.loads((root/'content/default.json').read_text())
    data['terrain']=['G'*data['width'] for _ in range(data['height'])]
    for unit,point in zip(data['units'][3:],[(5,3),(6,3),(7,4)]):unit.update(x=point[0],y=point[1])
    for unit,x in zip(data['units'][:3],[0,1,2]):unit.update(x=x,y=3)
    path=pathlib.Path(folder)/'fixture.json';path.write_text(json.dumps(data));env['AMBER_MOD']=str(path)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0));env['AMBER_TEST_PORT']=str(sock.getsockname()[1])
    base=[env.get('GODOT','godot'),'--headless','--path',str(root)]
    server=subprocess.Popen(base+['--script','res://server.gd','--','--port='+env['AMBER_TEST_PORT']],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    try:
        startup=queue.Queue()
        def drain():
            for line in server.stdout:startup.put(line)
            startup.put(None)
        threading.Thread(target=drain,daemon=True).start()
        while True:
            line=startup.get(timeout=15)
            if line is None:raise RuntimeError('authority failed startup')
            if 'AMBER_SERVER_READY' in line:break
        result=subprocess.run(base+['--script','res://tests/network_event_sequence.gd'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
        print(result.stdout,end='')
        assert result.returncode==0 and 'NETWORK_EVENT_SEQUENCE failures=0' in result.stdout and 'SCRIPT ERROR' not in result.stdout
    finally:
        server.terminate()
        try:server.wait(timeout=5)
        except subprocess.TimeoutExpired:server.kill();server.wait()
