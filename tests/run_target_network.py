#!/usr/bin/env python3
"""Actual fsnet server + remote player + viewport-driven client; no concurrent requests."""
import os,pathlib,secrets,socket,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
env=os.environ.copy();env['AMBER_TOKEN']=secrets.token_hex(24);env['AMBER_MOD']=str(root/'content/reference_bridge.json')
with socket.socket() as sock:
    sock.bind(('127.0.0.1',0));env['AMBER_TEST_PORT']=str(sock.getsockname()[1])
base=[env.get('GODOT','godot'),'--path',str(root)]
children=[]
with tempfile.TemporaryDirectory(prefix='target-network-') as folder:
    env['AMBER_CONFIRM_CONTROL']=folder
    try:
        server=subprocess.Popen(base+['--headless','--script','res://server.gd','--','--port='+env['AMBER_TEST_PORT']],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);children.append(server)
        for line in server.stdout:
            if 'AMBER_SERVER_READY' in line:break
        else:raise RuntimeError('server exited before ready')
        remote=subprocess.Popen(base+['--headless','--script','res://tests/network_target_remote.gd'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);children.append(remote)
        graphical=env.get('AMBER_GRAPHICAL')=='1'
        driver=subprocess.Popen(base+(['--audio-driver','Dummy'] if graphical else ['--headless'])+['--script','res://tests/network_target_confirm.gd'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);children.append(driver)
        try:output,_=driver.communicate(timeout=100)
        except subprocess.TimeoutExpired:
            driver.kill();output,_=driver.communicate();print(output,end='');raise
        print(output,end='')
        assert driver.returncode==0 and 'NETWORK_TARGET_CONFIRM checks=' in output and 'FAIL:' not in output and 'SCRIPT ERROR' not in output
        output,_=remote.communicate(timeout=10);print(output,end='');assert remote.returncode==0
        print('TARGET_NETWORK_PASS: three OS processes; ordinary polling, deferred confirmation, remote change, reconnect')
    finally:
        for child in children:
            if child.poll() is None:child.terminate()
        for child in children:
            try:child.wait(timeout=5)
            except subprocess.TimeoutExpired:child.kill();child.wait()
