extends SceneTree
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL: ',label)
func _initialize():call_deferred('run')
func run():
 var app=root.get_node('App');app.sfx_enabled=false;var fixture=preload('res://logic/content.gd').default_content()
 for y in range(fixture.height):fixture.terrain[y]='G'.repeat(fixture.width)
 fixture.units[3].x=3;fixture.units[3].y=3;fixture.units[4].x=5;fixture.units[4].y=3;fixture.units[5].x=6;fixture.units[5].y=4
 app.new_game(fixture)
 change_scene_to_file('res://main.tscn');await process_frame;await process_frame
 while not app.next_story().is_empty():app.advance_story(true)
 var g=current_scene;g.refresh()
 for node in [g,g.motion,g.cutin,g.heal_feedback,g.event_sequence]:node.set_process(false)
 check(app.session.submit({'kind':'end_turn'}),'actual AI turn')
 g.battle=app.session.logic;var truth=g.battle.snapshot();var emitted=g.battle.events.duplicate(true);g.refresh()
 var expected=[];var starts={}
 for e in emitted:
  if e.get('kind') in ['move','attack','heal']:expected.append({'kind':e.kind,'actor':e.get('actor',''),'step':g.battle.step})
  if e.get('kind')=='move' and not starts.has(e.actor):starts[e.actor]=Vector3(e.path[0].x,g.figure_height(0),e.path[0].y)
 check(starts.size()>=2 and expected.any(func(e):return e.kind=='attack'),'fixture contains several moves interleaved with actual attacks')
 check(g.motion.motions.size()==1 and g.presentation_active(),'one enemy starts, full queue gates input')
 for i in range(g.battle.units.size()):
  var id=g.battle.units[i].id
  if starts.has(id):check(g.figures[i].position.is_equal_approx(starts[id]),'waiting movers remain at start '+id)
 var first=g.event_sequence.current.duplicate(true);var pos=g.figures.map(func(n):return n.position)
 g.motion.speed=0;g.motion.advance(10);g.event_sequence._process(10)
 check(g.figures.map(func(n):return n.position)==pos and g.event_sequence.current==first,'speed zero freezes queue')
 g.motion.speed=1
 var source=app.session.logic
 var replacement=preload('res://logic/runtime.gd').new(source.content);check(replacement.restore(truth),'ordinary sync fixture')
 app.session.logic=replacement;g.battle=replacement;g.refresh()
 check(g.event_sequence.current==first and g.figures.map(func(n):return n.position)==pos,'same-step Runtime preserves visual progress')
 var count=0
 while g.presentation_active() and count<4000:
  check(g.motion.motions.size()<=1,'never concurrent enemy moves')
  g.motion.advance(1.0/60);g.cutin._process(1.0/60);g.heal_feedback._process(1.0/60);g.event_sequence._process(1.0/60);count+=1
 check(count<4000,'bounded complete presentation')
 var actual=g.event_sequence.trace.filter(func(e):return e.kind in ['move','attack','heal'])
 check(actual==expected,'visual order matches Lua exactly')
 check(g.battle.snapshot()==truth,'presentation preserves state')
 for i in range(g.battle.units.size()):check(g.figures[i].position==Vector3(g.battle.units[i].x,g.figure_height(i),g.battle.units[i].y),'final figure settles truth')
 var seen=g.event_sequence.trace.duplicate(true);g.refresh();check(g.event_sequence.trace==seen and not g.presentation_active(),'completed step not replayed')
 app.session.logic=source;g.battle=source
 check(app.session.submit({'kind':'end_turn'}),'next step');g.refresh()
 var current_step=g.event_sequence.last_step
 check(app.session.submit({'kind':'end_turn'}),'step arriving during presentation');g.refresh()
 check(g.event_sequence.last_step==current_step+1,'contiguous step received')
 check(g.event_sequence.batches.size()==1 or not g.event_sequence.active(),'contiguous batch queues behind current effects')
 var final=g.battle.snapshot();g.skip_presentation()
 check(not g.presentation_active() and g.event_sequence.batches.is_empty(),'skip clears complete queue')
 check(g.battle.snapshot()==final,'skip preserves latest snapshot')
 g.refresh();check(not g.presentation_active(),'refresh after skip cannot replay')
 g.restart();check(g.event_sequence.last_step==0 and not g.presentation_active(),'restart resets sequence gate')
 # Actual lethal AI: settled death must not hide a target before its event.
 fixture.units[0].hp=1;fixture.units[3].damage=20
 app.new_game(fixture);g.session=app.session;g.battle=app.session.logic;g.event_sequence.last_step=-1;g.refresh()
 check(app.session.submit({'kind':'end_turn'}),'lethal AI fixture command');g.battle=app.session.logic;g.refresh()
 var kills=g.battle.events.filter(func(e):return e.get('kind')=='attack' and e.hp==0)
 check(not kills.is_empty(),'actual lethal event present')
 var target_index=-1
 for i in range(g.battle.units.size()):
  if g.battle.units[i].id==kills[0].target:target_index=i
 check(target_index>=0 and g.figures[target_index].visible,'future death remains visible before damage presentation')
 g.motion.speed=8;g.cutin.speed=8
 var accelerated=0
 while g.presentation_active() and accelerated<600:
  g.motion.advance(1.0/60);g.cutin._process(1.0/60);g.heal_feedback._process(1.0/60);g.event_sequence._process(1.0/60);accelerated+=1
 check(accelerated<600 and not g.figures[target_index].visible,'accelerated queue finishes and hides defeated target')
 var finished_trace=g.event_sequence.trace.size()
 # A reconnect gap supplies only latest events: abandon old animation safely.
 var future_step=g.battle.step+3;g.event_sequence.consume(future_step,[])
 check(not g.presentation_active() and g.event_sequence.last_step==future_step,'snapshot gap settles without inventing/replaying history')
 check(g.event_sequence.trace.size()==finished_trace,'gap adds no fictitious actions')
 print('EVENT_SEQUENCE checks=',checks,' failures=',failures,' frames=',count,' ordered_events=',expected)
 quit(1 if failures else 0)
