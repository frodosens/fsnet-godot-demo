extends Control
var game
func _ready():
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta):queue_redraw()
func _draw():
    if game.mode=="move" and game.selected>=0 and game.battle.usable(game.selected) and not game.battle.units[game.selected].moved and not game.presentation_active():
        for cell in game.preview_reachable:
            if cell==game.battle.units[game.selected].pos:continue
            var outline=PackedVector2Array()
            for corner in [Vector2(-0.46,-0.46),Vector2(0.46,-0.46),Vector2(0.46,0.46),Vector2(-0.46,0.46),Vector2(-0.46,-0.46)]:outline.append(game.camera.unproject_position(Vector3(cell.x+corner.x,0.07,cell.y+corner.y)))
            draw_polyline(outline,Color(0.42,0.61,0.61,0.55),1,true)
    if game.preview_path.size()<2:return
    var points=PackedVector2Array()
    for cell in game.preview_path:points.append(game.camera.unproject_position(Vector3(cell.x,0.07,cell.y)))
    draw_polyline(points,Color("23332f"),6,true);draw_polyline(points,Color("e4c58a"),3,true)
    draw_arc(points[0],8,0,TAU,24,Color("e4c58a"),2,true)
    for i in range(points.size()-1):
        var direction=(points[i+1]-points[i]).normalized();var side=Vector2(-direction.y,direction.x)*4
        var tip=points[i].lerp(points[i+1],0.72)
        draw_colored_polygon(PackedVector2Array([tip,tip-direction*9+side,tip-direction*9-side]),Color("eee2c6"))
    var end=points[-1]
    draw_polyline(PackedVector2Array([end+Vector2(0,-12),end+Vector2(12,0),end+Vector2(0,12),end+Vector2(-12,0),end+Vector2(0,-12)]),Color("dfa75f"),2,true)
