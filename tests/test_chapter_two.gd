extends "res://tests/support/test_case.gd"
const C=preload("res://logic/content.gd")
const R=preload("res://logic/runtime.gd")
const Profile=preload('res://view/authored_scene.gd')
func _initialize():call_deferred('run')
func command(r,c):
 c.step=r.step+1;check(r.apply_command(c),'legal '+str(c))
func run():
 var d=C.chapter_two_content();check(C.validate(d).is_empty(),'valid complete chapter')
 check(d.terrain[1][7]=='D' and d.terrain[1][8]=='D' and d.terrain[2][8]=='D','only required door approach openings')
 var r=R.new(d);var initial=r.snapshot();check(r.path_to(0,Vector2i(2,7)).is_empty(),'occupied ally not traversable')
 var trace=[]
 for point in [Vector2i(3,4),Vector2i(3,2),Vector2i(6,2),Vector2i(8,1)]:
  var c={"kind":"move","unit":0,"x":point.x,"y":point.y,"step":r.step+1};trace.append(c.duplicate());command(r,c)
  if point!=Vector2i(8,1):
   c={"kind":"end_turn","step":r.step+1};trace.append(c.duplicate());command(r,c)
 check(r.outcome=='victory' and r.units[0].hp>0,'natural four-turn reach victory')
 check(r.units[3].hp>0 and r.units[4].hp>0,'victory does not require defeating guards')
 var replay=R.new(d)
 for c in trace:check(replay.apply_command(c),'deterministic replay accepts')
 check(replay.state_hash()==r.state_hash(),'replay exact hash')
 var restored=R.new(d);check(restored.restore(r.snapshot()) and restored.state_hash()==r.state_hash(),'terminal snapshot restore')
 var loss=R.new(d)
 for point in [Vector2i(3,4),Vector2i(3,2),Vector2i(6,2)]:
  command(loss,{"kind":"move","unit":0,"x":point.x,"y":point.y});command(loss,{"kind":"end_turn"})
 for turn in range(10):
  if loss.outcome!='playing':break
  command(loss,{"kind":"end_turn"})
 check(loss.outcome=='defeat' and loss.units[0].hp==0,'natural protected-unit defeat')
 var app=root.get_node('App');app.save_root='user://chapter2_test';app.new_game(d)
 check(not app.enter_next_chapter(),'chapter two cannot loop transition')
 app.session.logic=r;app.session.authority.logic=r
 while not app.next_story().is_empty():app.advance_story(true)
 check(app.save_slot('slot1').is_empty(),'save chapter two')
 var truth=r.state_hash();app.new_game(C.reference_content());check(app.load_slot('slot1') and app.session.logic.state_hash()==truth,'load content embedded chapter two')
 check(app.session.logic.content.id==d.id,'load does not substitute first chapter')
 var ch1=C.reference_content();ch1.units[3].hp=1;ch1.units[3].x=4;ch1.units[3].y=6;ch1.units[4].hp=1;ch1.units[4].x=3;ch1.units[4].y=7;ch1.units[5].hp=1;ch1.units[5].x=5;ch1.units[5].y=7
 app.new_game(ch1)
 for pair in [[0,3],[1,4],[2,5]]:command(app.session.logic,{"kind":"attack","unit":pair[0],"target":pair[1]})
 check(app.session.logic.outcome=='victory','first chapter terminal fixture')
 check(not app.next_chapter_ready(),'must finish victory dialogue')
 while not app.next_story().is_empty():app.advance_story(true)
 check(app.next_chapter_ready(),'explicit transition available')
 app.session.online=true;var before=app.session.logic.snapshot();check(not app.enter_next_chapter() and app.session.logic.snapshot()==before,'no local-only online transition');app.session.online=false
 check(app.enter_next_chapter(),'offline transition after autosave')
 check(app.session.logic.content.id==d.id and app.session.logic.round_number==1,'new chapter fresh content')
 var checkpoint=app.loadable_slots().filter(func(slot):return app.is_chapter_checkpoint(slot))
 check(not checkpoint.is_empty() and app.inspect_slot(checkpoint[-1]).data.content.id=='amber_bridge_reference','independent checkpoint preserves previous chapter')
 var custom=d.duplicate(true);custom.terrain[7]='XGGGGGGGGG'
 check(Profile.profile(custom).is_empty(),'altered layout cannot receive painted plate')
 check(not Profile.profile(d).is_empty() and not Profile.profile(C.reference_content()).is_empty(),'both authored backgrounds admitted')
 check(initial==R.new(d).snapshot(),'all presentation/fixtures preserve initial deterministic content')
 print('CHAPTER_TWO checks=',checks,' failures=',failures,' reach_hp=',r.units[0].hp,' victory_step=',r.step)
 quit(1 if failures else 0)
