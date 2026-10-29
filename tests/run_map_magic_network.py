"""Real authority plus two scene clients; spell playback survives polling/reconnect."""
import json, os, pathlib, secrets, socket, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
env = os.environ.copy()
env['AMBER_TOKEN'] = secrets.token_hex(24)
with tempfile.TemporaryDirectory(prefix='map-magic-network-') as folder:
    data = json.loads((root / 'content/default.json').read_text())
    data['terrain'] = ['G' * data['width']] * data['height']
    data['units'][2].update(x=5, y=6)
    data['units'][3].update(x=5, y=5)
    fixture = pathlib.Path(folder) / 'fixture.json'
    fixture.write_text(json.dumps(data))
    env['AMBER_MOD'] = str(fixture)
    env['AMBER_MAGIC_CONTROL'] = folder
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        env['AMBER_TEST_PORT'] = str(sock.getsockname()[1])
    base = [env.get('GODOT', 'godot'), '--headless', '--path', str(root)]
    children = []
    try:
        server = subprocess.Popen(base + ['--script', 'res://server.gd', '--', '--port=' + env['AMBER_TEST_PORT']], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        children.append(server)
        for line in server.stdout:
            if 'AMBER_SERVER_READY' in line: break
        else: raise RuntimeError('server not ready')
        for role in ('driver', 'observer'):
            children.append(subprocess.Popen(base + ['--script', 'res://tests/network_map_magic.gd', '--', '--role=' + role], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
        results = []
        for client in children[1:]:
            output, _ = client.communicate(timeout=35)
            print(output, end='')
            assert client.returncode == 0 and 'ERROR:' not in output and 'FAIL:' not in output
            results.append(json.loads(next(line.split('MAP_MAGIC_NETWORK_RESULT ', 1)[1] for line in output.splitlines() if line.startswith('MAP_MAGIC_NETWORK_RESULT '))))
        assert results[0]['hash'] == results[1]['hash']
        assert all(r['step'] == 1 and r['impacts'] == 1 for r in results)
        assert results[0]['reconnected']
        print('MAP_MAGIC_NETWORK_PASS: three processes, real focus_bolt, two scene timelines, same-step reconnect, one impact each')
    finally:
        for child in children:
            if child.poll() is None: child.terminate()
        for child in children:
            try: child.wait(timeout=5)
            except subprocess.TimeoutExpired: child.kill(); child.wait()
