extends "res://tests/support/test_case.gd"
const C=preload("res://logic/content.gd")
const R=preload("res://logic/runtime.gd")
func _initialize():call_deferred('run')
func run():
 var app=root.get_node('App');app.save_root='user://progression_'+str(Time.get_ticks_usec())
 var d=C.reference_content()
 for p in [[3,4,6],[4,3,7],[5,5,7]]:d.units[p[0]].hp=1;d.units[p[0]].x=p[1];d.units[p[0]].y=p[2]
 # New levelled ending carries XP only; immutable checkpoint preserves gear and state.
 app.new_game(d)
 for i in range(3):check(app.session.submit({'kind':'attack','unit':i,'target':i+3}),'new battle command')
 while not app.next_story().is_empty():app.advance_story(true)
 var xp=app.session.logic.campaign_state();var truth=app.session.logic.snapshot()
 var slot=app.checkpoint_id(app.session.logic.rules_hash,app.session.logic.content_hash,truth,app.presentation)
 var blocked=app.save_path(slot)+'.tmp';DirAccess.make_dir_recursive_absolute(blocked)
 check(not app.enter_next_chapter() and app.session.logic.snapshot()==truth,'failed checkpoint prevents XP transition')
 DirAccess.remove_absolute(blocked)
 check(app.enter_next_chapter(),'new ending transfer')
 check(app.session.logic.campaign_state()==xp and app.session.logic.units[0].level==2,'crosschapter XP stable IDs')
 check(app.session.logic.inventory.size()==4 and app.session.logic.units[0].equipment==[0,0,0,0,0,0,0,0,0],'inventory still chapter preset')
 check(app.save_slot('auto').is_empty() and app.load_slot(slot) and app.session.logic.snapshot()==truth,'chapter two save then chapter one exact recovery')
 check(app.enter_next_chapter() and app.session.logic.campaign_state()==xp,'repeat transition no duplicate reward')
 # Chapter two -> three uses the same durable transition and stable IDs.
 var two=C.chapter_two_content();two.victory={'kind':'survive','round':2}
 check(app.new_game(two,xp) and app.session.submit({'kind':'end_turn'}),'chapter two terminal fixture')
 while not app.next_story().is_empty():app.advance_story(true)
 var xp_two=app.session.logic.campaign_state()
 check(app.next_chapter_ready() and app.enter_next_chapter(),'chapter two durable checkpoint before third')
 check(app.session.logic.content.id=='mill_receipts' and app.session.logic.campaign_state()==xp_two,'chapter three receives exact campaign ledger')
 check(app.save_slot('slot3').is_empty() and app.inspect_slot('slot3').data.format==3,'third chapter current-format save')
 var third=app.session.logic.snapshot()
 check(app.load_slot('slot3') and app.session.logic.snapshot()==third,'third chapter growth save round trip')
 # Malformed progression inputs rejected without mutating active state.
 var r=app.session.logic;var stable=r.snapshot()
 for bad in [null,[],{}, {'roster':null,'completed':[]},{'roster':[null],'completed':[]},{'roster':[{'id':'mara','xp':-1}],'completed':[]},{'roster':[{'id':'mara','xp':1621}],'completed':[]},{'roster':[{'id':'mara','xp':0},{'id':'mara','xp':1}],'completed':[]},{'roster':[],'completed':['a','a']},{'roster':[],'completed':['../bad']},{'roster':[{'id':'mara','xp':1,'level':10}],'completed':[]}]:
  check(not R.validate_campaign(bad) and r.snapshot()==stable,'bad campaign atomic rejection '+JSON.stringify(bad))
 var crowded={'roster':[],'completed':[]}
 for i in range(32):crowded.roster.append({'id':'absent_'+str(i),'xp':0})
 check(not app.new_game(d,crowded) and app.session.logic.snapshot()==stable,'oversized merged roster rejects before closing active session')
 # Tamper a current-format save; rejection must leave the running session intact.
 var corrupted=app.inspect_slot('slot3').data.duplicate(true);corrupted.hash='bad'
 var f=FileAccess.open(app.save_path('slot2'),FileAccess.WRITE);f.store_string(JSON.stringify(corrupted));f.close()
 check(not app.load_slot('slot2') and app.session.logic.snapshot()==stable,'tampered current save leaves running session intact')
 print('PROGRESSION_SAVE checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
