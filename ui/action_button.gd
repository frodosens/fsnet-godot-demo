extends Button
var kind="move"
var hover_amount=0.0
func _ready():
    alignment=HORIZONTAL_ALIGNMENT_LEFT;custom_minimum_size=Vector2(150,50)
    add_theme_font_size_override("font_size",20)
    add_theme_color_override("font_outline_color",Color("1f2c2a"));add_theme_constant_override("outline_size",2)
    for state in ["normal","hover","pressed","disabled","focus"]:
        var box=StyleBoxEmpty.new();box.content_margin_left=50;box.content_margin_right=4;add_theme_stylebox_override(state,box)
func _process(delta):
    hover_amount=move_toward(hover_amount,1.0 if is_hovered() and not disabled else 0.0,delta/0.08);queue_redraw()
func _draw():
    var center=Vector2(23,25-hover_amount*2);var radius=23.0*(0.96 if button_pressed else 1.0)
    var points=PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0),center+Vector2(0,-radius)])
    var ink=Color("dfa75f") if has_focus() else Color("c4cbb9")
    if disabled:ink=Color("7b8880")
    draw_colored_polygon(points,Color("293b36"));draw_polyline(points,ink,2)
    match kind:
        "move":
            var boot=PackedVector2Array()
            for point in [Vector2(-6,-12),Vector2(2,-12),Vector2(2,1),Vector2(10,5),Vector2(10,10),Vector2(-10,10),Vector2(-10,5),Vector2(-4,1)]:boot.append(center+point)
            draw_colored_polygon(boot,ink);draw_line(center+Vector2(-7,-6),center+Vector2(3,-6),Color("293b36"),2);draw_line(center+Vector2(-10,7),center+Vector2(10,7),Color("293b36"),1)
        "attack":
            draw_line(center+Vector2(-7,8),center+Vector2(9,-10),ink,4);draw_line(center+Vector2(-8,1),center+Vector2(0,9),ink,2)
        "skill":
            for d in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:draw_line(center+d*3,center+d*12,ink,3)
            draw_circle(center,3,ink)
        "item":
            var bag=PackedVector2Array()
            for point in [Vector2(-5,-6),Vector2(-10,4),Vector2(-7,11),Vector2(7,11),Vector2(10,4),Vector2(5,-6)]:bag.append(center+point)
            draw_colored_polygon(bag,ink);draw_line(center+Vector2(-5,-8),center+Vector2(5,-8),ink,3);draw_line(center+Vector2(0,-7),center+Vector2(-2,7),Color("293b36"),1)
    if has_focus():draw_colored_polygon(PackedVector2Array([Vector2(0,25),Vector2(5,20),Vector2(10,25),Vector2(5,30)]),Color("dfa75f"))
