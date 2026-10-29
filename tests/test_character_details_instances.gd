extends "res://tests/support/test_case.gd"
const F=preload("res://tests/unit_definition_fixture.gd")
const R=preload("res://logic/runtime.gd")
const Model=preload("res://ui/character_details_model.gd")
const Art=preload("res://view/reserve_art.gd")
func _initialize():call_deferred("run")
func frames():
    for i in 6:await process_frame
func click(node):
    for pressed in [true,false]:
        var e=InputEventScreenTouch.new();e.position=root.get_final_transform()*node.get_global_rect().get_center();e.pressed=pressed
        Input.parse_input_event(e);Input.flush_buffered_events();await frames()
func run():
    var app=root.get_node("App");app.sfx_enabled=false;Input.emulate_mouse_from_touch=true
    var data=F.twins("mara");data.units[0].name="守卫甲";data.units[1].name="守卫乙"
    var campaign={"roster":[{"id":"custom_guard_0","xp":60},{"id":"custom_guard_1","xp":150}],"completed":[]}
    require(app.new_game(data,campaign),"admit shared template with independent campaign identities")
    var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game;await frames()
    game.select_actor(0);game.hud.show_character_details();await frames();var page=game.hud.modal
    var model=Model.new();var first=game.battle.units[0];var second=game.battle.units[1].duplicate(true)
    require(first.template_ref==second.template_ref and first.id!=second.id,"shared immutable definition, distinct instances")
    require(page.actor_id==first.id and page.identity.text=="守卫甲","details binds instance identity/name")
    require(page.portrait.texture==load(Art.portrait_path("mara")),"portrait uses admitted presentation profile, not renamed instance ID")
    require(page.level_label.text=="Lv."+str(first.level) and first.xp==60,"XP/level from first instance")
    var growth=model.progression(first)
    require(page.xp_bar.value==growth.current and page.summary.text=="经验 %d / %d"%[growth.current,growth.required],"XP contract preserved after definition expansion")
    require(page.stat_rows[0].value.text=="%s / %s"%[first.hp,first.max_hp],"grid displays grown instance stats")
    await click(page.tabs[3]);page.choose_slot(5);page.choose_equipment(2);await frames()
    var before=game.battle.snapshot();var preview=model.preview_equipment(game.battle,0,5,2)
    require(preview.allowed and not page.equip.disabled and game.battle.snapshot()==before,"preview isolated for renamed instance")
    await click(page.equip)
    require(game.battle.units[0].equipment[5]==2 and game.battle.units[0].move_actions==2,"actual touch equips target instance")
    require(game.battle.units[1]==second,"equip and derived stats cannot leak through shared template")
    require(game.battle.units[0].xp==60 and game.battle.units[1].xp==150,"equipment cannot change either XP")
    game.hud.clear_modal();await frames();game.select_actor(1);await frames();game.hud.show_character_details();await frames();page=game.hud.modal
    require(is_instance_valid(page),"second instance details opens after previous modal disposal")
    require(page.actor_id==second.id and page.identity.text=="守卫乙" and page.level_label.text=="Lv."+str(second.level),"second instance keeps own name and progression")
    require(page.portrait.texture==load(Art.portrait_path("mara")),"shared profile remains same original art")
    await click(page.tabs[3]);page.choose_slot(5);page.choose_equipment(2);await frames()
    before=game.battle.snapshot();page.commit_equipment()
    require(page.equip.disabled and game.battle.snapshot()==before,"shared inventory ownership prevents taking twin's equipment")
    var replacement=R.new(game.battle.content);require(replacement.restore(before),"expanded instance snapshot restores")
    game.session.logic=replacement;game.battle=replacement;game.refresh();await frames()
    require(is_instance_valid(page) and page.actor_id==second.id and page.identity.text=="守卫乙","same-state runtime replacement preserves details binding")
    require(game.battle.content.units.is_read_only() and game.battle.content.units[0].is_read_only(),"definition query contract remains immutable")
    game.session.connection_generation+=1;await frames();require(not is_instance_valid(game.hud.modal),"reconnect invalidates renamed-instance details")
    game.queue_free();await frames();print("DETAILS_INSTANCES checks=",checks," failures=0");quit()
