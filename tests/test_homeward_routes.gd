extends "res://tests/support/test_case.gd"
const C=preload("res://logic/content.gd")
const R=preload("res://logic/runtime.gd")
func _initialize():call_deferred('run')
func run():
 var traces=C.normalize(JSON.parse_string(FileAccess.get_file_as_string('res://tests/homeward_routes.json')))
 var xp={};var last
 for num in range(1,4):
  var d=preload('res://story/library.gd').content(num);var r=R.new(d,xp);var replay=R.new(d,xp)
  for c in traces[str(num)]:
   var ok=r.apply_command(c)
   check(ok,'legal route '+str(num)+' '+str(c))
   if not ok:print(r.units.map(func(u):return [u.id,u.pos,u.hp]));break
   check(replay.apply_command(c) and replay.state_hash()==r.state_hash(),'deterministic route')
   var restored=R.new(d);check(restored.restore(r.snapshot()) and restored.state_hash()==r.state_hash(),'each-step restore')
  check(r.outcome=='victory','real victory chapter'+str(num))
  var unchanged=r.snapshot()
  check(not r.apply_command({'kind':'finish_story','event_id':'invented','step':r.step+1}) and r.snapshot()==unchanged,'unknown completion rejected atomically')
  if num==3:check(not r.apply_command({'kind':'finish_story','event_id':'homeward_04_finish','step':r.step+1}) and r.snapshot()==unchanged,'cannot finish interlude before chapter3')
  var command={'kind':'finish_story','event_id':d.id+'_finish','step':r.step+1}
  check(r.apply_command(command),'authoritative finish')
  var finished=r.snapshot();command.step+=1
  check(not r.apply_command(command) and r.snapshot()==finished,'finish idempotent')
  last=r
  xp=r.campaign_state()
 var before=last.campaign_state();var units=last.units.duplicate(true)
 check(last.apply_command({'kind':'finish_story','event_id':'homeward_04_finish','step':last.step+1}),'pure story completion')
 check(last.units==units and last.campaign_state()==before,'no fake battle reward or stats')
 print('HOMEWARD_ROUTES ',checks,' checks failures=',failures);quit(1 if failures else 0)
