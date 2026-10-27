extends CanvasLayer
# Local presentation of actual healing amounts; never executes battle logic.
const UI=preload("res://ui/style.gd")
var game
var last_step=-1
var numbers=[]
func consume(step,events):
    if step==last_step:return
    clear();last_step=step
    var lanes={}
    for event in events:
        if event.get("kind")!="heal":continue
        for i in range(game.battle.units.size()):
            if game.battle.units[i].id!=event.target:continue
            var label=UI.label("+"+str(event.amount),32,Color("b6d5a2"));label.add_theme_color_override("font_outline_color",Color("1f2c2a"));label.add_theme_constant_override("outline_size",2);add_child(label)
            var lane=lanes.get(event.target,0);lanes[event.target]=lane+1
            var base=game.camera.unproject_position(game.badge_position(i))+Vector2(-15+lane*24,-18)
            numbers.append({"label":label,"base":base,"age":0.0})
func _process(delta):
    for entry in numbers.duplicate():
        entry.age+=delta
        var t=entry.age/0.75
        if t>=1:entry.label.queue_free();numbers.erase(entry);continue
        entry.label.position=entry.base+(Vector2.ZERO if App.reduced_motion else Vector2(0,-20*sin(t*PI)))
        entry.label.modulate.a=clampf((1-t)/0.25,0,1)
func clear():
    for entry in numbers:entry.label.queue_free()
    numbers.clear()
