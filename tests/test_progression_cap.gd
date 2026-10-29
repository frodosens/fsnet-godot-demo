extends "res://tests/support/test_case.gd"
const C=preload("res://logic/content.gd")
const R=preload("res://logic/runtime.gd")
func ledger(count):
 var c={'roster':[],'completed':[]}
 for i in range(count):c.completed.append('done_'+str(i).pad_zeros(2))
 return c
func _initialize():call_deferred('run')
func run():
 var d=C.default_content();d.victory={'kind':'survive','round':2}
 var full=ledger(32);var room=ledger(31)
 check(R.validate_campaign(full) and not R.campaign_fits(d,full),'shape valid but new chapter lacks reserved slot')
 var app=root.get_node('App');check(app.new_game(d),'baseline live session')
 var session=app.session;var snap=session.logic.snapshot();var story=app.presentation.duplicate(true)
 check(not app.new_game(d,full) and app.session==session and app.session.logic.snapshot()==snap and app.presentation==story,'invalid import preserves active session and story')
 check(not app.start_room(true,27849,'unused-cap-test-token',d,full) and app.session==session and app.server==null,'invalid host import rejected before network/session replacement')
 # The lower-level VM boundary also rejects before mutation, not just the UI.
 var r=session.logic;var old_content=r.call_rule('view').terrain
 check(r.vm.invoke('reset',{'content':d,'seed':12345,'campaign':full})==null,'Lua reset rejects invalid combination')
 check(not r.vm.last_error().is_empty(),'invalid Lua import diagnosed')
 check(r.snapshot()==snap and r.call_rule('view').terrain==old_content,'Lua reset rejection leaves prior authoritative state intact')
 check(R.campaign_fits(d,room) and app.new_game(d,room),'31 plus new chapter admitted')
 check(app.session.submit({'kind':'end_turn'}) and app.session.logic.outcome=='victory','31 plus new chapter can finish')
 check(app.session.logic.campaign_state().completed.size()==32 and d.id in app.session.logic.campaign_state().completed,'last slot recorded without truncation')
 check(app.session.logic.units[0].xp==30,'last slot still awards normal XP')
 var truth=app.session.logic.snapshot();var restored=R.new(d)
 check(restored.restore(truth) and restored.snapshot()==truth,'full terminal ledger snapshot exact restore')
 var completed=app.session.logic.campaign_state()
 check(R.campaign_fits(d,completed) and app.new_game(d,completed),'32 with current chapter already recorded admitted')
 check(app.session.submit({'kind':'end_turn'}) and app.session.logic.outcome=='victory','full repeat chapter can still finish')
 check(app.session.logic.campaign_state()==completed and app.session.logic.units[0].xp==30,'full repeat gives no duplicate reward and drops no history')
 check(app.session.submit({'kind':'equip','unit':0,'slot':0,'item':0}) and app.session.logic.campaign_state()==completed,'postterminal equip remains usable')
 # A forged full ledger for an unrecorded active chapter must fail restore atomically.
 var other=d.duplicate(true);other.id='unrecorded_chapter'
 var outsider=R.new(other);var prior=outsider.snapshot()
 check(not outsider.restore(truth) and outsider.snapshot()==prior,'restore rejects incompatible full ledger without state loss')
 var authority=Authority.new(d,room)
 var client=Session.new();client.logic=R.new(d)
 var req={'rules':authority.logic.rules_hash,'content':authority.logic.content_hash,'client':'cap-test-client'}
 req.id=1;req.command={'kind':'end_turn','step':1}
 var reply=authority.handle(req)
 check(reply.accepted and client.synchronize(reply) and client.logic.snapshot()==authority.logic.snapshot(),'authority/client terminal settlement at cap')
 var duplicate=authority.handle(req)
 check(not duplicate.accepted and duplicate.reason=='duplicate' and client.synchronize(duplicate),'duplicate network command at cap rejected without replay reward')
 check(client.logic.campaign_state()==completed,'client cap ledger exact')
 print('PROGRESSION_CAP checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
