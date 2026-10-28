extends "res://tests/test_mobile_targeting.gd"
func run():
 app=root.get_node('App');app.mobile_presentation=true;app.sfx_enabled=false;Input.emulate_mouse_from_touch=true
 for physical in [Vector2i(2400,1080),Vector2i(1280,800)]:
  root.size=physical;await frames();await fresh(fixture())
  game.selected=2;game.select_mode('ability:ember');await frames()
  await tap(cell(Vector2i(5,7)))
  check(not game.pending_target.is_empty() and Targeting.describe(game).hover_legal,'skill preview staged before remote event')
  var source=game.battle;var copy=preload('res://logic/runtime.gd').new(source.content);check(copy.restore(source.snapshot()),'same-step sync fixture')
  app.session.logic=copy;game.battle=copy;await frames()
  check(not game.pending_target.is_empty() and Targeting.describe(game).hover_legal,'same-state Runtime preserves target preview')
  # Actual authority advances while a proposal is open, as another client can do.
  app.session.logic=source;game.battle=source
  check(app.session.submit({'kind':'end_turn'}),'authority AI events accepted')
  game.battle=app.session.logic;game.refresh();await frames()
  check(game.event_sequence.active() and game.pending_target.is_empty(),'new step clears proposal and starts queue')
  check(game.target_hover_cell==Vector2i(-1,-1) and not Targeting.describe(game).active,'no stale hover/range over queued actions')
  var truth=game.battle.snapshot();var requests=game.session.request_id
  await tap(cell(Vector2i(5,7)));await tap(cell(Vector2i(5,7)))
  check(game.battle.snapshot()==truth and game.session.request_id==requests,'two taps cannot submit during sequence')
  var center=root.get_visible_rect().size*Vector2(0.55,0.4)
  await drag(center,center+Vector2(30,20))
  check(game.battle.snapshot()==truth and game.pending_target.is_empty(),'pan during queue cannot cast')
  game.skip_presentation();await frames()
  check(not game.presentation_active() and game.battle.snapshot()==truth,'skip settles queue without rule change')
  while not app.next_story().is_empty():app.advance_story(true)
  game.hud.refresh();await frames()
  game.selected=2;game.select_mode('ability:ember');await frames()
  check(Targeting.describe(game).active,'range resumes after presentation')
  game.hud.cancel_targeting();await frames()
  check(not Targeting.describe(game).active and game.target_hover_cell==Vector2i(-1,-1),'cancel clears combined state')
  await fresh(fixture());check(not Targeting.describe(game).active and not game.event_sequence.active(),'scene change resets both presentation systems')
 print('COMBINED_MOBILE_SEQUENCE checks=',checks,' failures=0');quit()
