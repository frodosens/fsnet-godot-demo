extends Control
signal cell_clicked(cell)
var data={}
var cell_size=40.0
func _ready():custom_minimum_size=Vector2(480,480);mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _draw():
    if data.is_empty():return
    cell_size=minf(480.0/data.width,480.0/data.height)
    for y in range(data.height):
        for x in range(data.width):
            var colors={"G":Color("91a26d"),"W":Color("628b9d"),"B":Color("c4af87"),"X":Color("6b6257")}
            var rect=Rect2(Vector2(x,y)*cell_size,Vector2.ONE*(cell_size-1))
            draw_rect(rect,colors[data.terrain[y][x]])
    var font=get_theme_default_font()
    for u in data.units:
        var pos=(Vector2(u.x,u.y)+Vector2(0.5,0.5))*cell_size
        draw_circle(pos,cell_size*0.30,Color("edd6a1") if u.ally else Color("9f5a40"))
        draw_string(font,pos+Vector2(-8,6),u.name.left(1),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("28251f"))
func _gui_input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
        var cell=Vector2i(floori(event.position.x/cell_size),floori(event.position.y/cell_size))
        if cell.x>=0 and cell.y>=0 and cell.x<data.width and cell.y<data.height:cell_clicked.emit(cell)
        accept_event()
