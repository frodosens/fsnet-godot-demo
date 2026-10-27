extends SceneTree
func _initialize():call_deferred("run")
func run():
    var data=preload("res://logic/content.gd").reference_content();data.units[3].x=data.units[0].x+1;data.units[3].y=data.units[0].y
    var logic=preload("res://logic/runtime.gd").new(data)
    assert(logic.apply_command({"kind":"attack","unit":0,"target":3,"step":1}))
    var original=logic.snapshot();var cutin=load("res://ui/battle_cutin.gd").new();root.add_child(cutin)
    cutin.consume(logic.step,logic.events,logic.units,logic.content)
    assert(cutin.reference_background.visible)
    assert(cutin.combat_status.bars.right.value==logic.events[0].hp+logic.events[0].damage)
    cutin.draw_tick(cutin.hit_tick())
    assert(cutin.combat_status.bars.right.value==logic.events[0].hp)
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;cutin.layout_surface()
        assert(cutin.surface.scale.x==cutin.surface.scale.y)
        assert(cutin.surface.position.x>=0 and cutin.surface.position.y>=0)
    cutin.finish();assert(logic.snapshot()==original)
    cutin.consume(99,logic.events,logic.units,preload("res://logic/content.gd").default_content())
    assert(not cutin.reference_background.visible)
    cutin.finish();print("COMBAT_STATUS checks=9 failures=0");quit()
