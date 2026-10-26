#!/usr/bin/env python3
"""Three separate Godot processes; fsnet loopback RPCs, reconnect + replay."""
import json, os, pathlib, secrets, socket, subprocess, time, queue, threading, sys, tempfile
extended = "--extended" in sys.argv
root = pathlib.Path(__file__).resolve().parents[1]
env = os.environ.copy()
env['AMBER_TOKEN'] = secrets.token_hex(24)
temporary = None
if '--mod-fixture' in sys.argv:
    temporary = tempfile.TemporaryDirectory(prefix='amber-network-mod-')
    data = json.loads((root / 'content/default.json').read_text())
    data.update(id='network_mod', title='Shared Mod fixture', revision=2)
    data['units'][0]['damage'] = 4
    fixture = pathlib.Path(temporary.name) / 'fixture.json'
    fixture.write_text(json.dumps(data, ensure_ascii=False))
    env['AMBER_MOD'] = str(fixture)
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
base = [env.get('GODOT', 'godot'), '--headless', '--path', str(root)]
server = subprocess.Popen(base + ['--script', 'res://server.gd', '--', f'--port={port}'], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
clients = []
try:
    # Server readiness is observed, not assumed from a fixed sleep.
    lines = []
    startup = queue.Queue()
    def drain():
        for line in server.stdout:
            lines.append(line)
            startup.put(line)
        startup.put(None)
    threading.Thread(target=drain, daemon=True).start()
    deadline = time.monotonic() + 10
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0: raise RuntimeError('server not ready: ' + ''.join(lines))
        try: line = startup.get(timeout=remaining)
        except queue.Empty: raise RuntimeError('server startup timeout: ' + ''.join(lines))
        if line is None: raise RuntimeError('server exited before ready: ' + ''.join(lines))
        if 'AMBER_SERVER_READY' in line: break
    for role in ('driver', 'observer'):
        clients.append(subprocess.Popen(base + ['--script', 'res://tests/network_client.gd', '--', f'--role={role}', f'--port={port}'] + (['--extended'] if extended else []), env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
    results = []
    for client in clients:
        output, _ = client.communicate(timeout=25)
        print(output, end='')
        if client.returncode or 'SCRIPT ERROR' in output or 'ERROR:' in output:
            raise RuntimeError('network client failed')
        results.append(json.loads(next(line.split('NETWORK_RESULT ', 1)[1] for line in output.splitlines() if line.startswith('NETWORK_RESULT '))))
    assert results[0]['hash'] == results[1]['hash'] and results[0]['step'] == results[1]['step'] == (7 if extended else 3)
    assert results[0]['reconnected']
    print('NETWORK_TEST_PASS: server + two clients, three OS processes, same state after reconnect')
finally:
    for child in clients + [server]:
        if child.poll() is None: child.terminate()
    for child in clients + [server]:
        try: child.wait(timeout=5)
        except subprocess.TimeoutExpired: child.kill(); child.wait()

    if temporary is not None: temporary.cleanup()
