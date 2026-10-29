extends "res://tests/support/test_case.gd"
const S=preload('res://logic/session.gd')
const R=preload('res://logic/runtime.gd')
var s
var role='driver'
var elapsed=0.0
var reconnected=false
var expected_xp=59 if OS.get_environment('AMBER_PROGRESSION_CAP')=='32' else 89
func _initialize():
 var port=27840
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--role='):role=arg.trim_prefix('--role=')
  if arg.begins_with('--port='):port=int(arg.trim_prefix('--port='))
 var content=R.Content.from_file(OS.get_environment('AMBER_MOD')).data
 s=S.new();s.logic=R.new(content);s.connect_local(port,OS.get_environment('AMBER_TOKEN'))
func _process(delta):
 elapsed+=delta
 if elapsed>20:printerr('TIMEOUT ',role);quit(1);return false
 s.tick(delta)
 if s.failed:printerr(s.status);quit(1);return false
 if s.pending or not s.ready:return false
 if s.logic.step==0:
  require(s.logic.units[0].xp==59,'host campaign seed received by fresh client')
  if role=='driver':s.submit({'kind':'end_turn'})
 elif s.logic.step<18:
  require(s.logic.outcome=='victory' and s.logic.units[0].xp==expected_xp and s.logic.units[0].level==(1 if expected_xp==59 else 2),'one settlement authoritative XP')
  if role=='driver':s.submit({'kind':'equip','unit':0,'slot':0,'item':0})
 else:
  require(s.logic.units[0].xp==expected_xp and s.logic.progression.settled,'postcheckpoint no repeated settlement')
  if not reconnected:
   s.transport.shutdown();s.logic=R.new(s.logic.content);s.connect_local(s.port,s.token);reconnected=true
  else:
   var baseline=R.new(s.logic.content,preload('res://tests/progression_server.gd').campaign_seed(s.logic.content))
   require(baseline.apply_command({'kind':'end_turn','step':1}),'offline terminal')
   for i in range(2,19):require(baseline.apply_command({'kind':'equip','unit':0,'slot':0,'item':0,'step':i}),'offline same equip sequence')
   require(baseline.snapshot()==s.logic.snapshot(),'offline / authority / client exact equality')
   if OS.get_environment('AMBER_PROGRESSION_CAP') in ['31','32']:require(s.logic.campaign_state().completed.size()==32,'bounded ledger preserved across real reconnect')
   print('NETWORK_RESULT ',JSON.stringify({'role':role,'hash':s.logic.state_hash(),'step':18,'reconnected':true,'checks':checks,'xp':expected_xp}))
   s.transport.shutdown();quit()
 return false
func _finalize():
 if s and s.transport:s.transport.shutdown()
