extends "res://tests/test_mobile_touch_camera.gd"
func run():
    app=root.get_node("App");app.mobile_presentation=true;app.sfx_enabled=false
    var data=Content.reference_content()
    data.units[0].id="rodd";data.units[0].name="罗德";data.story.events=[]
    for physical in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=physical;await frames();await fresh(data)
        var roster=game.hud.party_selector;var row=roster.rows[0];var crop=row.eye.texture
        check(crop is AtlasTexture,"allied Rodd uses original atlas crop")
        check(crop.atlas.resource_path=="res://assets/characters/chapter3/rodd/portrait.png","exact Rodd portrait identity")
        check(crop.region==Rect2(215,110,170,70),"Rodd-specific eyebrow/eye region excludes moustache")
        var source=crop.atlas.get_image();var pixels=crop.get_image()
        check(pixels.get_data()==source.get_region(Rect2i(215,110,170,70)).get_data(),"crop bytes originate from original portrait")
        var displayed_height=crop.region.size.x/(226.0/70.0)
        var center=crop.region.get_center().y
        check(center-displayed_height/2<138 and center+displayed_height/2>148 and center+displayed_height/2<180,"aspect-cover keeps both eye rows and excludes moustache row")
        var truth=game.battle.snapshot()
        await tap(roster.rows[1].button.get_global_rect().get_center());await tap(row.button.get_global_rect().get_center())
        check(game.selected==0 and game.battle.units[0].id=="rodd" and game.battle.snapshot()==truth,"allied Rodd selects without a command")
        var out=OS.get_environment("PARTY_RODD_CAPTURE")
        if not out.is_empty():
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(out+"/rodd-"+str(physical.x)+".png")
    print("PARTY_RODD_EYES checks=",checks," failures=0");quit()
