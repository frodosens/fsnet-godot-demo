extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func run():
    var app=root.get_node("App");app.mobile_presentation=true
    var cutin=load("res://ui/battle_cutin.gd").new();root.add_child(cutin);cutin.set_process(false)
    for physical in [Vector2i(2400,1080),Vector2i(1280,800),Vector2i(1600,1200)]:
        root.size=physical;app.safe_area_override=Rect2i(48,20,physical.x-72,physical.y-36);await frames();cutin.layout_surface()
        var view=root.get_visible_rect();var safe=app.ui_safe_rect()
        var transform=cutin.scene_surface.get_global_transform()
        var scene=transform*Rect2(Vector2.ZERO,Vector2(1586,992))
        require(scene.grow(0.01).encloses(view),"battle scene uniformly covers "+str(physical))
        require(is_equal_approx(transform.get_scale().x,transform.get_scale().y),"scene never distorted")
        require(is_equal_approx(cutin.surface.scale.x,minf(safe.size.x/1586.0,safe.size.y/992.0)),"interface fit is independent of scene cover")
        for control in cutin.combat_status.get_children():
            if control is Button:require(safe.grow(0.01).encloses(control.get_global_rect()),"battle controls within safe area")
        require(cutin.arena.get_parent()==cutin.scene_surface and cutin.reference_background.get_parent()==cutin.scene_surface,"actors and background share coherent scene transform")
        require(cutin.combat_status.get_parent()==cutin.surface,"HUD independent of scene cover")
        require(cutin.reference_background.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"texture aspect preserved")
    app.mobile_presentation=false;cutin.layout_surface()
    require(cutin.scene_surface.scale==Vector2.ONE and cutin.scene_surface.position==Vector2.ZERO,"desktop retains layout")
    cutin.finish();require(not cutin.surface.visible,"finish hides both scene and HUD")
    print("MOBILE_CUTIN_LAYOUT checks=",checks," failures=0");quit()
