extends SceneTree
const Sides=preload('res://ui/combat_sides.gd')
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL: ',label)
func _initialize():call_deferred('run')
func run():
 var units=[]
 for id in ['mara','finn','neri','oren','tessa','bram','adela','elsbet']:
  var own=id in ['mara','finn','neri']
  units.append({'id':id,'name':id,'ally':own,'controller':'player' if own else 'ai','faction':'party' if own else 'watch','hp':33,'max_hp':40})
 var cutin=load('res://ui/battle_cutin.gd').new();root.add_child(cutin);cutin.set_process(false)
 var step=0
 for size in [Vector2i(1280,800),Vector2i(960,600)]:
  root.size=size;cutin.layout_surface()
  for viewer in ['', 'watch']:
   for unit in units:
    var target='oren' if unit.ally else 'mara'
    for terminal in [false,true]:
     step+=1
     var e={'kind':'attack','actor':unit.id,'target':target,'ability':'focus_bolt' if unit.id=='neri' else 'attack','damage':7,'hp':0 if terminal else 33,'is_critical':terminal}
     var before=JSON.stringify(units)
     cutin.consume(step,[e],units,{},viewer)
     check(cutin.active,'supported actor '+unit.id)
     var expected=unit.ally if viewer=='' else not unit.ally
     check(cutin.actor_left==expected,'own faction left '+unit.id+viewer)
     check((cutin.attacker.position.x<cutin.defender.position.x)==expected,'initial side')
     var status=cutin.combat_status;var target_side='right' if expected else 'left'
     check(status.labels[target_side].text==target,'target name on target side')
     check(status.bars[target_side].value==int(e.hp)+7,'before HP')
     for tick in [0,5,9,cutin.hit_tick(),18,23,0,cutin.hit_tick()]:
      cutin.draw_tick(tick)
      check(cutin.attacker.flip_h==not expected,'attack facing resets every tick')
      check(not status.portraits.left.flip_h and status.portraits.right.flip_h,'portrait inward without mirrored text')
      check(status.labels.left.scale==Vector2.ONE and status.labels.right.scale==Vector2.ONE,'text remains readable')
      if tick==cutin.hit_tick():
       if DisplayServer.get_name()!="headless":await process_frame
       var tip=cutin.weapon_screen_point() if cutin.is_melee() else cutin.projectile_screen_point()
       check(tip.distance_to(cutin.hurt_screen_point())<0.01,'mirrored contact socket '+unit.id)
       check(status.bars[target_side].value==e.hp,'after HP correct side')
       check(cutin.damage_label.position.y<cutin.defender.position.y,'numbers above victim')
     check(JSON.stringify(units)==before and not e.has('actor_left'),'input event and state untouched')
     cutin.finish();check(not cutin.active and not cutin.surface.visible,'skip reset')
 # Same-side and spectator order is stable across a reverse/counter sequence.
 for pair in [['mara','finn'],['oren','bram']]:
  var a={'actor':pair[0],'target':pair[1]};var b={'actor':pair[1],'target':pair[0]}
  check(Sides.actor_on_left(a,units,'spectator')!=Sides.actor_on_left(b,units,'spectator'),'stable spectator/counter ordering')
  check(Sides.actor_on_left(a,units)!=Sides.actor_on_left(b,units),'stable ally interaction ordering')
 check(Sides.actor_on_left({'actor':'missing','target':'mara'},units),'identity-less fallback')
 var sequence=[{'kind':'attack','actor':'mara','target':'oren','damage':7,'hp':33},{'kind':'attack','actor':'oren','target':'mara','damage':7,'hp':33},{'kind':'attack','actor':'finn','target':'oren','damage':0,'hp':33}]
 cutin.consume(1000,sequence,units)
 check(cutin.actor_left and cutin.pending_events.size()==2,'forward attack queues reversed and zero-damage events')
 cutin.speed=0;cutin._process(0.25);check(cutin.elapsed==0 and cutin.actor_left,'paused event keeps side and time')
 cutin.speed=3;cutin._process(0.1);check(is_equal_approx(cutin.elapsed,0.3),'fast-forward uses existing timing')
 cutin.play_next();check(not cutin.actor_left and cutin.attacker.flip_h,'reverse/counter-shaped event enters from right')
 check(cutin.combat_status.labels.left.text=='mara','counter-shaped event keeps own status left')
 cutin.play_next();cutin.draw_tick(cutin.hit_tick())
 check(cutin.actor_left and cutin.damage_label.text=='−0','zero-damage event retains own side without inventing miss rules')
 check(cutin.projectile_screen_point().distance_to(cutin.hurt_screen_point())<0.01,'zero-damage projectile contact')
 cutin.finish();check(cutin.pending_events.is_empty() and not cutin.active,'skip clears all queue state')

 print('COMBAT_SIDES checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
