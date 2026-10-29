extends "res://tests/support/test_case.gd"
const Art=preload("res://view/reserve_art.gd")
const Content=preload("res://logic/content.gd")
const Runtime=preload("res://logic/runtime.gd")
const Fixture=preload("res://tests/reserve_art_fixture.gd")
func _initialize():call_deferred("run")
func frames():
    for i in range(3):await process_frame
func malformed_manifests():
    var id="adela";var base=Art.ROOT+id+"/"
    var good=Content.normalize(JSON.parse_string(FileAccess.get_file_as_string(base+"manifest.json")))
    var cached=Art.profile(id)
    check(not Art.decode_profile(good,id,base).is_empty(),"decoder accepts normal manifest")
    var paths=[["map"],["battle"],["portrait"],["map","directions"],["map","directions","front_left"],["battle","frames"],["battle","frames","idle_00.png"],["battle","geometry"]]
    for path in paths:
        for bad in [null,[],5,"invalid",true]:
            var data=good.duplicate(true);var parent=data
            for index in range(path.size()-1):parent=parent[path[index]]
            parent[path[-1]]=bad
            check(Art.decode_profile(data,id,base).is_empty(),"nested malformed value safely rejects "+str(path)+" "+str(bad))
            check(Art.cache[id]==cached,"failed decode never publishes partial cache")
        var missing=good.duplicate(true);var parent=missing
        for index in range(path.size()-1):parent=parent[path[index]]
        parent.erase(path[-1])
        check(Art.decode_profile(missing,id,base).is_empty(),"missing nested key safely rejects "+str(path))
    for key in ["attack_contact_tip_xy","hurt_body_anchor_xy","hurt_head_anchor_xy"]:
        for value in [null,{},[],[1],[1,2,3],[null,2],[true,2],["1",2],[INF,2],[NAN,2],[-1,2],[192,2],[1,160]]:
            var data=good.duplicate(true);data.battle.geometry[key]=value
            check(Art.decode_profile(data,id,base).is_empty(),"invalid vector safely rejects "+key+str(value))
        var data=good.duplicate(true);data.battle.geometry.erase(key)
        check(Art.decode_profile(data,id,base).is_empty(),"missing geometry key rejects")
    for bad in [null,[],1,"bad",{}]:
        check(Art.decode_profile(bad,id,base).is_empty(),"invalid root safely rejects")
    check(Art.profile(id)==cached,"valid profile cache remains intact after malformed inputs")
func run():
    root.size=Vector2i(960,600) if OS.get_environment("AMBER_RESERVE_SMALL")=="1" else Vector2i(1280,800)
    var app=root.get_node("App");preload("res://tests/legacy_map_fixture.gd").apply(app);app.sfx_enabled=false;app.save_root="user://reserve_art_"+str(Time.get_ticks_usec())
    malformed_manifests()
    var original=Content.reference_content();var original_hash=Content.hash_of(original)
    for id in Art.IDS:
        var profile=Art.profile(id)
        check(not profile.is_empty(),"valid complete art profile "+id)
        if profile.is_empty():continue
        check(load(Art.portrait_path(id)).get_size()==Vector2(512,512),"portrait available")
        for direction in Art.DIRECTIONS:check(profile.map[direction].get_size()==Vector2(96,128),"direction texture "+direction)
    for id in ["mara","finn","neri","oren","tessa","bram","unknown-mod-knight","../adela"]:
        check(Art.profile(id).is_empty(),"profile cannot replace other identity "+id)
    var data=Fixture.content();check(Content.validate(data)=="","existing schema accepts fixture without new fields")
    var imported=Content.from_file("res://docs/examples/reserve_art_demo.json")
    check(imported.error=="" and imported.data==data,"example imports through existing Mod parser")
    check(Content.write_mod(data,true)=="" and Content.from_file("user://mods/reserve_art_demo.json").data==data,"existing editor Mod storage accepts profile IDs")
    # A rejected profile is cached as empty by the loader: actual scene retains role art.
    var valid_adela=Art.cache.adela;Art.cache.adela={}
    app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
    check(current_scene.figures[0].texture is Texture2D,"rejected profile retains visible role fallback")
    Art.cache.adela=valid_adela
    change_scene_to_file("res://main.tscn");await frames()
    var game=current_scene;game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
    for index in [0,3]:
        var unit=game.battle.units[index];var profile=Art.profile(unit.id)
        for direction in Art.DIRECTIONS:
            game.facing[unit.id]=direction;game.get_node("MapIdle").advance(0)
            var texture=game.figures[index].texture
            check(texture==profile.map[direction],"unit ID map binding "+unit.id+direction)
            game.get_node("MapIdle").advance(1.7)
            check(game.figures[index].texture==texture,"reserve map idle remains static")
        game.selected=index;game.hud.refresh()
        check(game.hud.dock.portrait.texture==load(Art.portrait_path(unit.id)),"actual dock portrait binding")
    var truth=game.battle.snapshot();game.hud.toggle_pause();game.get_node("MapIdle").advance(2);game.hud.clear_modal()
    check(game.battle.snapshot()==truth,"pause presentation preserves logic")
    check(app.session.submit({"kind":"move","unit":0,"x":3,"y":7}),"real move for reserve art")
    game.battle=app.session.logic;game.refresh();game.motion.advance(.2)
    check(game.figures[0].texture==Art.profile("adela").map[game.facing.adela],"moving uses matching static direction")
    game.skip_presentation();game.get_node("MapIdle").advance(1)
    check(game.figures[0].texture==Art.profile("adela").map[game.facing.adela],"settled idle remains same static source")
    var saved=game.battle.snapshot();check(app.save_slot("slot1")=="" and app.load_slot("slot1") and app.session.logic.snapshot()==saved,"save reload retains IDs and exact rule state")
    var cutin=game.cutin;cutin.set_process(false)
    for actor in [0,3]:
        var logic=Runtime.new(data);var target=3 if actor==0 else 0
        check(logic.apply_command({"kind":"attack","unit":actor,"target":target,"step":1}),"real reserve attack")
        var state=logic.snapshot();var hits=cutin.impact_play_count
        cutin.last_seen_step=-1;cutin.consume(1,logic.events,logic.units,data)
        check(cutin.active and cutin.release_tick==9 and cutin.actor_sets[logic.units[actor].id].timeline.size()==24,"existing 24-tick/contact cadence")
        cutin.draw_tick(cutin.hit_tick())
        check(cutin.weapon_screen_point().distance_to(cutin.hurt_screen_point())<.01,"weapon reaches victim socket")
        check(is_equal_approx(cutin.attacker.position.y,205) and is_equal_approx(cutin.defender.position.y,205),"contact never lifts planted baseline")
        var pixel=cutin.contact_target
        if cutin.defender.flip_h:pixel.x=192-pixel.x
        var rgba=cutin.defender.texture.get_image().get_pixelv(Vector2i(pixel))
        check(rgba.a>.5,"contact lies on actual opaque victim pixel")
        check(cutin.defender.texture==Art.profile(logic.units[target].id).poses.hurt,"independent hurt pose")
        cutin.draw_tick(14);check(cutin.defender.texture==Art.profile(logic.units[target].id).poses.idle_00,"recover uses documented neutral")
        for rate in [1.0,2.0,4.0]:
            cutin.finish();cutin.last_seen_step=-1;cutin.speed=rate;cutin.consume(1,logic.events,logic.units,data)
            var start=cutin.impact_play_count
            for tick in range(400):
                if not cutin.active:break
                cutin._process(1.0/120)
            check(not cutin.active and cutin.impact_play_count==start+1,"fast-forward produces one hit")
        cutin.last_seen_step=-1;cutin.consume(1,logic.events,logic.units,data);cutin.finish()
        cutin.consume(1,logic.events,logic.units,data);check(not cutin.active,"skip/replayed event not repeated")
        check(logic.snapshot()==state,"all combat presentation preserves full Lua snapshot")
    # Visible reserve defender breathing is possible during Mara's longer windup.
    for id in Art.IDS:
        var fixture=Content.reference_content();fixture.units[3].id=id;fixture.units[3].x=5;fixture.units[3].y=7
        var logic=Runtime.new(fixture);check(logic.apply_command({"kind":"attack","unit":0,"target":3,"step":1}),"Mara versus reserve")
        cutin.last_seen_step=-1;cutin.consume(1,logic.events,logic.units,fixture);cutin.draw_tick(6)
        check(cutin.defender.texture==Art.profile(id).poses.idle_01 and cutin.defender.flip_h,"visible mirrored inhale before brace")
        cutin.elapsed=.5;cutin.set_process(true);paused=true;await create_timer(.03,true).timeout
        check(cutin.elapsed==.5,"tree pause freezes presentation clock")
        paused=false;cutin.set_process(false);cutin.finish()
    # High staff contact against every original silhouette; no changed old assets.
    for attacker_id in Art.IDS:
        for index in range(6):
            var fixture=Fixture.content();var victim=original.units[index].duplicate(true)
            victim.x=5;victim.y=7;victim.ally=false;victim.controller="player"
            var actor=fixture.units[0].duplicate(true);actor.id=attacker_id
            fixture.units=[actor,victim];fixture.story.events=[]
            var logic=Runtime.new(fixture)
            check(logic.apply_command({"kind":"attack","unit":0,"target":1,"step":1}),"legal staff versus "+victim.id)
            cutin.last_seen_step=-1;cutin.consume(1,logic.events,logic.units,fixture);cutin.draw_tick(9)
            var point=cutin.contact_target
            if cutin.defender.flip_h:point.x=192-point.x
            check(cutin.defender.texture.get_image().get_pixelv(Vector2i(point)).a>.5,"high strike lands on opaque old silhouette "+victim.id)
            check(cutin.attacker.position.y==205 and cutin.defender.position.y==205,"old-victim staff contact retains feet "+victim.id)
            cutin.finish()
    check(Content.hash_of(Content.reference_content())==original_hash,"default content unchanged")
    check(Art.profile("adela").map.front_left!=game.direction_textures.get("finn:front_left"),"other original role not overwritten")
    print("RESERVE_ART checks=",checks," failures=",failures)
    quit(1 if failures else 0)
