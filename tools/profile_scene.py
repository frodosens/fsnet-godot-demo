#!/usr/bin/env python3
"""Disposable-checkout script timing probe. Not a GPU/device benchmark."""
import argparse,json,os,pathlib,re,shutil,subprocess,tempfile,socket
TARGETS={'main.gd':['_process'],'ui/battle_hud.gd':['refresh','refresh_story'],'ui/bottom_dock.gd':['refresh_dock'],'logic/runtime.gd':['call_rule'],'logic/session.gd':['tick','synchronize'],'view/path_preview.gd':['_process'],'view/unit_health.gd':['_process'],'view/map_idle.gd':['advance'],'view/fixed_background.gd':['_process']}
def instrument(root):
    for path,functions in TARGETS.items():
        target=root/path;text=target.read_text()
        for name in functions:
            match=re.search(r'^func '+name+r'\((.*?)\):',text,re.M)
            if not match:raise ValueError(f'Missing probe function: {path}:{name}')
            args=match[1]
            params=','.join(x.split('=')[0].split(':')[0].strip() for x in args.split(',') if x.strip())
            text=text[:match.start()]+text[match.start():].replace('func '+name+'(','func _perf_body_'+name+'(',1)
            text+=f'\nfunc {name}({args}):\n    var started=Time.get_ticks_usec()\n    var result=_perf_body_{name}({params})\n    preload("res://tests/perf_stats.gd").record("{path}:{name}",Time.get_ticks_usec()-started)\n    return result\n'
        target.write_text(text)
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument('--output',type=pathlib.Path,required=True)
    parser.add_argument('--godot',default=os.environ.get('GODOT','godot'))
    args=parser.parse_args();source=args.project.resolve();output=args.output.resolve()
    if output.exists():parser.error('Output exists; choose a new report path')
    tool_root=pathlib.Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='amber-perf-') as folder:
        root=pathlib.Path(folder)/'project';root.mkdir()
        tracked=subprocess.check_output(['git','-C',str(source),'ls-files','-z']).decode().split('\0')
        for name in tracked:
            if not name or name.startswith('docs/'):continue
            original=source/name
            if original.is_symlink():raise ValueError(f'Symlink not admitted: {name}')
            if not original.is_file():continue
            target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(original,target)
        # Linux native bridge is locally built, deliberately not tracked. Its external
        # dependencies must already be installed as described by the project README.
        native=source/'bin/libamber.so'
        if native.is_file():shutil.copy2(native,root/'bin/libamber.so')
        for name in ['perf_stats.gd','perf_scenarios.gd']:
            shutil.copy2(tool_root/'tests'/name,root/'tests'/name)
        instrument(root)
        env=os.environ.copy()
        for name in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:env[name]=str(pathlib.Path(folder)/name)
        local_report=pathlib.Path(folder)/'result.json';env['PERF_OUTPUT']=str(local_report)
        with socket.socket() as sock:
            sock.bind(('127.0.0.1',0));env['PERF_PORT']=str(sock.getsockname()[1])
        subprocess.run([args.godot,'--headless','--path',str(root),'--editor','--import','--quit'],env=env,check=True,timeout=180,stdout=subprocess.DEVNULL)
        subprocess.run([args.godot,'--path',str(root),'--audio-driver','Dummy','--script','res://tests/perf_scenarios.gd'],env=env,check=True,timeout=180)
        result=json.loads(local_report.read_text())
        result['source_revision']=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD']).decode().strip()
        result['source_tracked_dirty']=bool(subprocess.check_output(['git','-C',str(source),'diff','--name-only']).strip())
        output.parent.mkdir(parents=True,exist_ok=True)
        with output.open('x') as stream:json.dump(result,stream,indent=2)
if __name__=='__main__':main()
