extends "res://tests/support/test_case.gd"
const C=preload("res://logic/content.gd")
const R=preload("res://logic/runtime.gd")
func _initialize():call_deferred('run')
func run():
 var app=root.get_node('App');app.save_root='user://progression_'+str(Time.get_ticks_usec())
 var d=C.reference_content()
 for p in [[3,4,6],[4,3,7],[5,5,7]]:d.units[p[0]].hp=1;d.units[p[0]].x=p[1];d.units[p[0]].y=p[2]
 var old=ClassDB.instantiate('AmberLogic');check(old.load_rules(R.legacy_rule_source()),'frozen v5 load')
 old.invoke('reset',{'seed':12345,'content':d})
 for i in range(3):check(old.invoke('apply',{'kind':'attack','unit':i,'target':i+3,'step':i+1})==true,'old legitimate ending')
 var raw=str(old.invoke('snapshot',{}));var old_hash=raw.sha256_text()
 var seen=[]
 for event in d.story.events:seen.append(event.id)
 var story={'seen':seen,'active':'','line':0}
 var payload={'format':2,'rules_hash':R.legacy_rule_source().sha256_text(),'content_hash':C.hash_of(d),'content':d,'snapshot':raw,'hash':old_hash,'presentation':story}
 DirAccess.make_dir_recursive_absolute(app.save_root)
 var checkpoint=app.checkpoint_id(payload.rules_hash,payload.content_hash,raw,story,d.id)
 for slot in ['slot1',checkpoint]:
  var file=FileAccess.open(app.save_path(slot),FileAccess.WRITE);file.store_string(JSON.stringify(payload));file.close()
 var original=FileAccess.get_file_as_bytes(app.save_path('slot1'));var checkpoint_bytes=FileAccess.get_file_as_bytes(app.save_path(checkpoint))
 check(app.load_slot('slot1'),'legacy migration from manual slot')
 check(app.session.logic.units[0].xp==0 and app.session.logic.progression.settled,'legacy terminal no retroactive rewards')
 check(app.session.logic.inventory.size()==5 and app.session.logic.outcome=='victory','legacy inventory and outcome retained')
 var legacy_view=old.invoke('view',{})
 for i in range(legacy_view.units.size()):
  for key in ['x','y','hp','mp','equipment','cooldowns','charges','moves_used','acted','max_hp','max_mp','damage','armor','resist']:
   check(app.session.logic.units[i][key]==legacy_view.units[i][key],'legacy field preserved '+str(i)+'/'+key)
 check(app.session.logic.inventory==legacy_view.inventory and app.session.logic.supplies==legacy_view.supplies,'legacy full inventory and supply values exact')

 check(FileAccess.get_file_as_bytes(app.save_path('slot1'))==original,'legacy file never rewritten on load')
 check(app.load_slot(checkpoint),'legacy content-addressed checkpoint remains recoverable')
 check(FileAccess.get_file_as_bytes(app.save_path(checkpoint))==checkpoint_bytes,'legacy checkpoint bytes preserved')
 check(app.enter_next_chapter() and app.session.logic.content.id=='white_elm_watchhouse','old ending safely enters next chapter')
 check(app.save_slot('auto').is_empty() and app.inspect_slot('auto').data.format==3,'new format written separately')
 var truth=app.session.logic.snapshot();check(app.load_slot('auto') and app.session.logic.snapshot()==truth,'new save reload exact')
 check(FileAccess.get_file_as_bytes(app.save_path(checkpoint))==checkpoint_bytes,'new autosave cannot erase original checkpoint')
 # New levelled ending carries XP only; immutable checkpoint preserves gear and state.
 app.new_game(d)
 for i in range(3):check(app.session.submit({'kind':'attack','unit':i,'target':i+3}),'new battle command')
 while not app.next_story().is_empty():app.advance_story(true)
 var xp=app.session.logic.campaign_state();truth=app.session.logic.snapshot()
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
 check(app.save_slot('slot3').is_empty(),'third chapter save')
 var third=app.session.logic.snapshot()
 check(app.load_slot('slot3') and app.session.logic.snapshot()==third,'third chapter growth save round trip')
 # Malformed progression inputs rejected without mutating active state.
 var r=app.session.logic;var stable=r.snapshot()
 for bad in [null,[],{}, {'roster':null,'completed':[]},{'roster':[null],'completed':[]},{'roster':[{'id':'mara','xp':-1}],'completed':[]},{'roster':[{'id':'mara','xp':1621}],'completed':[]},{'roster':[{'id':'mara','xp':0},{'id':'mara','xp':1}],'completed':[]},{'roster':[],'completed':['a','a']},{'roster':[],'completed':['../bad']},{'roster':[{'id':'mara','xp':1,'level':10}],'completed':[]}]:
  check(not R.validate_campaign(bad) and r.snapshot()==stable,'bad campaign atomic rejection '+JSON.stringify(bad))
 var crowded={'roster':[],'completed':[]}
 for i in range(32):crowded.roster.append({'id':'absent_'+str(i),'xp':0})
 check(not app.new_game(d,crowded) and app.session.logic.snapshot()==stable,'oversized merged roster rejects before closing active session')
 check(not R.validate_legacy(d,raw, 'bad'),'legacy hash tamper rejected')
 var corrupted=payload.duplicate(true);corrupted.hash='bad'
 var f=FileAccess.open(app.save_path('slot2'),FileAccess.WRITE);f.store_string(JSON.stringify(corrupted));f.close()
 check(not app.load_slot('slot2') and app.session.logic.snapshot()==stable,'tampered old save leaves running session intact')
 print('PROGRESSION_SAVE checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
