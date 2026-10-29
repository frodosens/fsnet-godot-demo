extends "res://tests/support/test_case.gd"
const Art=preload("res://view/generic_map_art.gd")
func _initialize():call_deferred("run")
func frames():
    for n in range(4):await process_frame
func run():
    var app=root.get_node("App");var d=preload("res://logic/content.gd").reference_content();d.story.events=[]
    var ids=["ch01_bandit_a","ch01_bandit_b","ch01_bandit_c"]
    require(Art.templates().size()==6,"six data-only templates")
    for unknown in ["ch01_bandit_d","generic_bandit_02","generic_bandit_01/../mara","mara"]:require(not Art.declared(unknown),"no wildcard alias")
    for i in 3:
        d.units[i].id=ids[i];d.units[i].name=["山贼甲","山贼乙","山贼丙"][i];d.units[i].x=[1,4,6][i];d.units[i].y=6
        require(Art.canonical_id(ids[i])=="generic_bandit_01","exact chapter alias")
        require(preload("res://ui/style.gd").framed_portrait(ids[i])==null,"no hero portrait")
    require(preload("res://logic/content.gd").validate(d).is_empty(),"ordinary editor JSON schema accepts template IDs")
    app.new_game(d);change_scene_to_file("res://main.tscn");await frames();var g=current_scene;g.refresh();g.motion.set_process(false)
    for i in 3:
        require(g.hero_refresh_libraries.has("generic_bandit_01"),"shared immutable profile, independent instance clocks below")
        g.select_actor(i);g.scene_view.cancel_focus();g.selection_pending_focus=false
        require(g.selected==i and g.hud.party_selector.rows.has(i),"each allied fixture independently selectable")
        var positions=[];var textures=[]
        for f in g.figures:positions.append(f.position);textures.append(f.texture)
        require(app.session.submit({"kind":"move","unit":i,"x":[2,5,7][i],"y":6}),"independent legal move")
        g.battle=app.session.logic;g.refresh();g.motion.advance(.2/g.character_scale)
        require(g.motion.motions.keys()==[ids[i]],"only actor owns motion clock")
        for other in 3:
            if other!=i:require(g.figures[other].position==positions[other] and g.figures[other].texture==textures[other],"shared art cannot move another instance")
        g.skip_presentation();require(g.battle.units[i].pos==Vector2i([2,5,7][i],6),"settled own position")
    print("GENERIC_INSTANCES checks=",checks," failures=0");quit()
