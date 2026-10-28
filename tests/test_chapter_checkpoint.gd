extends SceneTree
const C=preload('res://logic/content.gd')
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL: ',label)
func _initialize():call_deferred('run')
func run():
 var app=root.get_node('App');app.save_root='user://checkpoint_'+str(Time.get_ticks_usec())
 var content=C.reference_content()
 for spec in [[3,4,6],[4,3,7],[5,5,7]]:
  content.units[spec[0]].hp=1;content.units[spec[0]].x=spec[1];content.units[spec[0]].y=spec[2]
 app.new_game(content)
 for pair in [[0,3],[1,4],[2,5]]:check(app.session.submit({'kind':'attack','unit':pair[0],'target':pair[1]}),'terminal fixture command')
 while not app.next_story().is_empty():app.advance_story(true)
 var snapshot=app.session.logic.snapshot();var truth=app.session.logic.state_hash();var story=app.presentation.duplicate(true)
 check(app.next_chapter_ready(),'chapter one ending')
 check(app.save_slot('slot1').is_empty(),'manual slot sentinel')
 var manual=FileAccess.get_file_as_bytes(app.save_path('slot1'))
 var failed_slot=app.checkpoint_id(app.session.logic.rules_hash,app.session.logic.content_hash,snapshot,story)
 var blocker=app.save_path(failed_slot)+'.tmp'
 DirAccess.make_dir_recursive_absolute(blocker)
 var original_session=app.session
 check(not app.enter_next_chapter(),'failed checkpoint write blocks transition')
 check(app.session==original_session and app.session.logic.snapshot()==snapshot and app.presentation==story,'write failure preserves current entire state')
 check(DirAccess.dir_exists_absolute(blocker),'write failure never removes existing directory')
 DirAccess.remove_absolute(blocker)
 check(app.enter_next_chapter(),'successful durable checkpoint before transition')
 var slots=app.loadable_slots().filter(func(slot):return app.is_chapter_checkpoint(slot))
 check(slots.size()==1,'one checkpoint discoverable')
 var slot=slots[0];var bytes=FileAccess.get_file_as_bytes(app.save_path(slot))
 check(not app.save_slot(slot).is_empty() and not app._write_save(slot).is_empty(),'chapter two cannot overwrite checkpoint via either write entry')
 check(app.save_slot('auto').is_empty(),'chapter two autosave')
 check(FileAccess.get_file_as_bytes(app.save_path(slot))==bytes,'autosave preserves chapter one checkpoint bytes')
 check(FileAccess.get_file_as_bytes(app.save_path('slot1'))==manual,'manual slot preserved')
 # Remove only this test's sentinel to exercise recovery with no manual save at all.
 check(DirAccess.remove_absolute(app.save_path('slot1'))==OK,'remove test-owned manual sentinel')
 check(not FileAccess.file_exists(app.save_path('slot1')) and app.inspect_slot('auto').data.content.id=='white_elm_watchhouse','only ordinary save is now chapter two')
 check(app.load_slot(slot),'checkpoint load accepted')
 check(app.session.logic.snapshot()==snapshot and app.session.logic.state_hash()==truth and app.presentation==story,'exact snapshot inventory gear RNG and local story restored')
 check(not app._write_save(slot).is_empty(),'existing checkpoint cannot be overwritten even from chapter one')
 check(app.enter_next_chapter(),'same ending can transition again')
 check(FileAccess.get_file_as_bytes(app.save_path(slot))==bytes,'same ending reuses original bytes')
 check(app.loadable_slots().size()==5,'no duplicate checkpoint for same ending')
 check(app.load_slot(slot),'reload ending for independent second state')
 for event in app.session.logic.content.story.events:
  if event.id not in app.presentation.seen:app.presentation.seen.append(event.id);break
 check(app.presentation!=story,'fixture distinguishes valid reading histories')
 check(app.enter_next_chapter(),'different valid ending gets own checkpoint')
 check(app.loadable_slots().size()==6,'second ending does not overwrite first')
 check(FileAccess.get_file_as_bytes(app.save_path(slot))==bytes,'older checkpoint retained after distinct ending')
 check(app.load_slot(slot),'return to original ending')
 var f=FileAccess.open(app.save_path(slot),FileAccess.WRITE);f.store_string('{}');f.close()
 check(not app.enter_next_chapter() and app.session.logic.snapshot()==snapshot,'corrupt existing checkpoint prevents transition')
 check(FileAccess.get_file_as_string(app.save_path(slot))=='{}','corrupt checkpoint retained rather than overwritten')
 check(not app.inspect_slot('../escape').error.is_empty() and not app.save_slot('../escape').is_empty(),'path traversal rejected')
 print('CHAPTER_CHECKPOINT checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
