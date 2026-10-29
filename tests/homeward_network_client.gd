extends SceneTree
const S=preload('res://logic/session.gd')
const R=preload('res://logic/runtime.gd')
var s
var role='driver'
var elapsed=0.0
var reconnected=false
var commands=[]
var baseline
var chapter=3
var settled={}
func _initialize():
 var port=27840
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--role='):role=arg.trim_prefix('--role=')
  if arg.begins_with('--port='):port=int(arg.trim_prefix('--port='))
 var content=R.Content.from_file(OS.get_environment('AMBER_MOD')).data
 chapter=int(OS.get_environment('AMBER_HOMEWARD_CHAPTER')) if not OS.get_environment('AMBER_HOMEWARD_CHAPTER').is_empty() else 3
 commands=R.Content.normalize(JSON.parse_string(FileAccess.get_file_as_string('res://tests/homeward_routes.json')))[str(chapter)]
 var endings=['homeward_01_finish'] if chapter==1 else ['homeward_03_finish','homeward_04_finish']
 for id in endings:commands.append({'kind':'finish_story','event_id':id,'step':commands.size()+1})
 while commands.size()<18:commands.append({'kind':'equip','unit':0,'slot':0,'item':0,'step':commands.size()+1})
 baseline=R.new(content)
 for c in commands:
  assert(baseline.apply_command(c))
  if baseline.outcome=='victory' and settled.is_empty():settled=baseline.campaign_state()
 s=S.new();s.logic=R.new(content);s.connect_local(port,OS.get_environment('AMBER_TOKEN'))
func _process(delta):
 elapsed+=delta
 if elapsed>25:printerr('TIMEOUT ',role);quit(1);return false
 s.tick(delta)
 if s.failed:printerr(s.status);quit(1);return false
 if s.pending or not s.ready:return false
 if s.logic.step<commands.size():
  if role=='driver':
   var c=commands[s.logic.step].duplicate();c.erase('step');s.submit(c)
 elif not reconnected:
  s.transport.shutdown();s.logic=R.new(s.logic.content);s.connect_local(s.port,s.token);reconnected=true
 else:
  assert(s.logic.snapshot()==baseline.snapshot(),'host/client/replay mismatch')
  assert(s.logic.campaign_state()==settled,'story finish must not duplicate settlement')
  var flags=8 if chapter==1 else 24
  assert((s.logic.story_flags & flags)==flags,'finish flags authoritative')
  print('NETWORK_RESULT ',JSON.stringify({'role':role,'hash':s.logic.state_hash(),'step':18,'reconnected':true}))
  s.transport.shutdown();quit()
 return false
func _finalize():
 if s and s.transport:s.transport.shutdown()
