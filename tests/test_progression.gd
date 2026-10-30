extends "res://tests/support/test_case.gd"
const C=preload("res://logic/content.gd")
const R=preload("res://logic/runtime.gd")
func _initialize():call_deferred('run')
func terminal_fixture():
 var d=C.reference_content()
 for p in [[3,4,6],[4,3,7],[5,5,7]]:
  d.units[p[0]].hp=1;d.units[p[0]].x=p[1];d.units[p[0]].y=p[2]
 return d
func finish(r):
 for p in [[0,3],[1,4],[2,5]]:check(r.apply_command({'kind':'attack','unit':p[0],'target':p[1],'step':r.step+1}),'legal terminal attack')
func run():
 var d=terminal_fixture();var r=R.new(d);var replica=R.new(d)
 check(r.units[0].level==1 and r.units[0].xp==0 and r.units[2].xp_next==60,'initial progression')
 check(r.apply_command({'kind':'attack','unit':0,'target':3,'step':1}),'first kill')
 check(r.units[0].xp==0 and not r.progression.settled,'kills do not pay until terminal')
 var first=r.snapshot()
 check(not r.apply_command({'kind':'attack','unit':0,'target':3,'step':1}) and r.snapshot()==first,'duplicate kill no mutation')
 for p in [[1,4],[2,5]]:check(r.apply_command({'kind':'attack','unit':p[0],'target':p[1],'step':r.step+1}),'finish other kills')
 check(r.outcome=='victory' and r.progression.settled,'terminal settled')
 for i in range(3):
  var u=r.units[i]
  check(u.xp==60 and u.level==2 and u.hp==d.units[i].hp and u.max_hp==d.units[i].hp+1 and u.acted,'equal share no healing/action reset')
 check(r.units[0].max_mp==0 and r.units[1].max_mp==0 and r.units[2].max_mp==7 and r.units[2].mp==6,'no new magic pool or refill')
 check(replica.restore(r.snapshot()) and replica.snapshot()==r.snapshot(),'new state exact restoration')
 var xp=r.campaign_state();var rng=r.call_rule('view').rng
 check(r.apply_command({'kind':'equip','unit':0,'slot':0,'item':1,'step':4}),'postvictory gear remains legal')
 check(r.campaign_state()==xp and r.call_rule('view').rng==rng,'postterminal gear never pays XP or rolls RNG')
 var again=R.new(d,xp);finish(again)
 for i in range(3):check(again.units[i].xp==60,'completed chapter cannot pay twice')
 var next=R.new(C.chapter_two_content(),xp)
 check(next.units[0].xp==60 and next.units[0].hp==13 and next.units[2].mp==7,'chapter entry growth and normal full initialization')
 check(next.inventory.size()==4 and next.units[0].equipment==[0,0,0,0,0,0,0,0,0],'no implicit inventory inheritance')
 # Multiple levels and cap; retained absent party members; stable sorting.
 var campaign={'roster':[{'id':'neri','xp':1590},{'id':'mara','xp':149},{'id':'absent_hero','xp':270},{'id':'finn','xp':59}],'completed':[]}
 var grown=R.new(d,campaign);finish(grown)
 check(grown.units[0].xp==209 and grown.units[0].level==3 and grown.units[0].base_damage==4,'threshold growth base attack')
 check(grown.units[2].xp==1620 and grown.units[2].level==10 and grown.units[2].xp_next==1620,'capped XP')
 check(grown.campaign_state().roster[0]=={'id':'absent_hero','xp':270},'stable IDs preserve absent roster')
 var multi=R.new(d,{'roster':[{'id':'mara','xp':0}],'completed':[]})
 # Large configured defeat count is bounded; multi-level seeding/derivation itself verified at every threshold.
 for threshold in [0,60,150,270,420,600,810,1050,1320,1620]:
  var vm=R.new(d,{'roster':[{'id':'mara','xp':threshold}],'completed':[]})
  check(vm.units[0].xp_floor==threshold and vm.units[0].base_damage==3+(vm.units[0].level-1)/2,'fixed thresholds integer growth')
 # One action can cross multiple thresholds; area damage pays each opponent once.
 var area=C.default_content();area.units=[area.units[0],area.units[3],area.units[4],area.units[5]]
 area.units[0].x=4;area.units[0].y=6;area.units[0].damage=20;area.units[0].reach=3
 for i in range(1,4):area.units[i].x=2+i;area.units[i].y=5;area.units[i].hp=1
 area.abilities[0].effects[0].radius=1
 check(C.validate(area).is_empty(),'legal multi-kill fixture')
 var jump=R.new(area)
 check(jump.apply_command({'kind':'attack','unit':0,'target':2,'step':1}),'one real area attack')
 check(jump.outcome=='victory' and jump.units[0].xp==180 and jump.units[0].level==3 and jump.units[0].hp==12,'multi-level award without healing')
 var four=C.default_content();four.victory={'kind':'survive','round':2}
 var extra=four.units[1].duplicate(true);extra.id='aaaa';extra.x=2;extra.y=6;four.units.append(extra)
 var share=R.new(four);check(share.apply_command({'kind':'end_turn','step':1}),'four-player victory')
 var expected={'aaaa':23,'finn':23,'mara':22,'neri':22}
 for u in share.units:
  if expected.has(u.id):check(u.xp==expected[u.id],'stable ID remainder '+u.id)
 # Physical and magic actual damage match grown preview, including equipped base HP clamp.
 var combat=C.default_content();combat.units[3].x=5;combat.units[3].y=5;combat.units[3].hp=40
 for kind in ['attack','ability']:
  var vm=R.new(combat,{'roster':[{'id':'neri','xp':150}],'completed':[]})
  var cmd={'kind':kind,'unit':2,'target':3,'ability':'focus_bolt','step':1}
  var preview=vm.preview_action(cmd);check(preview.legal,'grown action legal')
  check(vm.apply_command(cmd),'grown action applies')
  var hit=vm.events[0].damage;check(hit>=preview.low and hit<=preview.high,'actual and preview use same grown base')
  check(vm.units[2].mp==(8 if kind=='attack' else 6),'ordinary MP0 / spell MP2 unchanged')
 var gear=R.new(combat,{'roster':[{'id':'mara','xp':150}],'completed':[]})
 for cmd in [{'slot':5,'item':2},{'slot':6,'item':4},{'slot':6,'item':0},{'slot':6,'item':4}]:
  cmd.merge({'kind':'equip','unit':0,'step':gear.step+1});check(gear.apply_command(cmd),'gear command')
 check(gear.units[0].hp==14 and gear.units[0].max_hp==16,'HP equipment cannot heal or erase growth')
 # Defeat: no reward or resurrection; both terminal condition precedence retained.
 var loss=d.duplicate(true);loss.defeat={'kind':'survive','round':2};loss.victory={'kind':'survive','round':2}
 var failed=R.new(loss);check(failed.apply_command({'kind':'end_turn','step':1}) and failed.outcome=='defeat','simultaneous defeat priority')
 check(failed.units[0].xp==0 and failed.progression.settled and failed.campaign_state().completed.is_empty(),'defeat gives no XP/completion')
 # A knocked-out participant still shares the victory pool; no resurrection.
 var ko=C.default_content();ko.victory={'kind':'survive','round':2}
 ko.units[1].hp=1;ko.units[1].x=5;ko.units[1].y=4
 ko.units[3].x=5;ko.units[3].y=3;ko.units[3].damage=20
 var knocked=R.new(ko);check(knocked.apply_command({'kind':'end_turn','step':1}),'natural enemy phase for KO')
 check(knocked.outcome=='victory' and knocked.units[1].hp==0 and knocked.units[1].xp==30,'KO still receives share without revival')
 var reordered=d.duplicate(true);reordered.units.reverse()
 var mapped=R.new(reordered,xp)
 for u in mapped.units:
  if u.controller=='player':check(u.xp==60,'stable IDs independent of roster index')
 for bad in [r.snapshot()+',0','7'+r.snapshot().substr(1)]:
  var before=replica.snapshot();check(not replica.restore(bad) and replica.snapshot()==before,'malformed snapshot atomic')
 print('PROGRESSION checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
