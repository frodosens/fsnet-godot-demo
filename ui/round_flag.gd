extends Control
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw():
    var points=PackedVector2Array([Vector2(-12,3),Vector2(220,3),Vector2(238,21),Vector2(220,39),Vector2(-12,39),Vector2(-30,21),Vector2(-12,3)])
    draw_colored_polygon(points,Color("20312e"));draw_polyline(points,Color("857b58"),1)
    for x in [-30,238]:
        draw_colored_polygon(PackedVector2Array([Vector2(x,16),Vector2(x+4,21),Vector2(x,26),Vector2(x-4,21)]),Color("dfa75f"))
