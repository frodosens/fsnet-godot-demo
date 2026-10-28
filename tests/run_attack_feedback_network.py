#!/usr/bin/env python3
"""Real authority/client touch attack feedback across ordinary snapshot polls."""
import json,os,pathlib,secrets,socket,subprocess,tempfile,queue,threading
root=pathlib.Path(__file__).resolve().parents[1]
env=os.environ.copy();env['AMBER_TOKEN']=secrets.token_hex(24)
with tempfile.TemporaryDirectory(prefix='event-network-') as folder:
    data=json.loads((root/'content/reference_bridge.json').read_text())
    for unit,point in zip(data['units'][:4],[(2,7),(2,8),(4,7),(5,7)]):unit.update(x=point[0],y=point[1])
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
        result=subprocess.run(base+['--script','res://tests/network_attack_feedback.gd'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
        print(result.stdout,end='')
        assert result.returncode==0 and 'NETWORK_ATTACK_FEEDBACK checks=' in result.stdout and 'SCRIPT ERROR' not in result.stdout
    finally:
        server.terminate()
        try:server.wait(timeout=5)
        except subprocess.TimeoutExpired:server.kill();server.wait()
