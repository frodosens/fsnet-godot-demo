extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames():
    await process_frame;await process_frame;await process_frame
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");preload("res://tests/legacy_map_fixture.gd").apply(app);app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;var adapter=game.scene_view;var truth=game.battle.snapshot()
    var image=Image.create(2,2,false,Image.FORMAT_RGB8);image.fill(Color("81765c"))
    var fixture=ImageTexture.create_from_image(image) # Explicit synthetic test fixture, never a production background.
    check(adapter.set_fixed(true,fixture),"compatible authored map enables fixture background")
    check(game.figures[0].visible and game.figures[0].shaded and not game.tiles[Vector2i(4,7)].node.visible,"retain shaded units, hide physical terrain")
    check(is_equal_approx(game.character_scale,1.25),"fixed-only character scale")
    for figure in game.figures:
        check(is_zero_approx(figure.position.y) and figure.offset==Vector2(0,56),"scaled sole anchor remains on ground")
    var contract=JSON.parse_string(FileAccess.get_file_as_string("res://docs/fixed-background-contract.json"))
    for size in [Vector2i(960,600),Vector2i(1280,720),Vector2i(1280,800),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(2560,1080),Vector2i(1280,1024)]:
        root.size=size;await frames();adapter.fit()
        var ratio=adapter.art_rect.size.x/1280.0
        var worst=0.0
        for cell in contract.cells:
            var actual=game.camera.unproject_position(Vector3(cell.cell[0],0,cell.cell[1]))
            var expected=adapter.art_rect.position+Vector2(cell.center[0],cell.center[1])*ratio
            worst=maxf(worst,actual.distance_to(expected))
            check(game.mouse_cell(actual)==Vector2i(cell.cell[0],cell.cell[1]),"grid picking remains aligned")
        check(worst<0.06,"art affine projection remains aligned at "+str(size))
        if adapter.art_rect.position.length()>1:check(game.mouse_cell(Vector2.ZERO)==Vector2i(-1,-1),"letterbox does not accept world input")
        for light in adapter.painted_lights:
            var expected=adapter.art_rect.position+light.get_meta("anchor_pixel")*ratio
            check(game.camera.unproject_position(light.position).distance_to(expected)<0.06,"painted lamp anchor stable across resolution")
        check(adapter.painted_lights.size()==4,"exactly four painted lights, no switch duplication")
        print("FIXED_BACKGROUND_VIEW ",size," max_projection_error=",worst)
    root.size=Vector2i(1280,800);await frames()
    check(app.session.submit({"kind":"move","unit":0,"x":4,"y":4}),"same Lua command works in fixed view")
    game.battle=app.session.logic;game.refresh();game.motion.set_process(false);game.motion.advance(0.25);adapter.sync_shadows()
    check(adapter.shadows[0].position.x==game.figures[0].position.x and adapter.shadows[0].position.z==game.figures[0].position.z,"contact shadow follows interpolated path")
    game.skip_presentation();adapter.sync_shadows()
    check(adapter.shadows[0].position.is_equal_approx(Vector3(4,0.008,4)),"skip settles shadow on authoritative tile")
    var after=game.battle.snapshot();check(after!=truth,"test issued a real move")
    check(adapter.set_fixed(false) and game.tiles[Vector2i(4,7)].node.visible,"restore original 3D visibility")
    check(is_equal_approx(game.character_scale,1.0),"3D original scale restored")
    check(game.battle.snapshot()==after and game.camera.keep_aspect==adapter.saved_aspect,"renderer toggle preserves rules and restores camera")
    app.new_game(Content.default_content());change_scene_to_file("res://main.tscn");await frames()
    check(not current_scene.scene_view.set_fixed(true,fixture),"legacy/other map cannot use mismatched painting")
    print("FIXED_BACKGROUND checks=",checks," failures=",failures," synthetic_fixture=true artistic_acceptance=false")
    quit(1 if failures else 0)
