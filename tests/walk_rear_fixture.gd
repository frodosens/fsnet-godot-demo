extends RefCounted
# Explicit legal test placement; never included in the default roster/content.
static func content(actor,direction):
    var data=preload("res://logic/content.gd").reference_content()
    if actor in ["adela","elsbet"]:
        var reserve_index=0 if actor=="adela" else 3
        data.units[reserve_index].id=actor
        data.units[reserve_index].name="阿黛拉" if actor=="adela" else "埃尔丝贝特"
        data.story.events=[]
    data.units[0].x=1;data.units[0].y=6
    data.units[1].x=2;data.units[1].y=7
    data.units[2].x=6;data.units[2].y=8
    var i=0
    for j in range(data.units.size()):
        if data.units[j].id==actor:i=j
    data.units[i].x=1 if direction=="front_right" else 4;data.units[i].y=8
    if direction=="front_left":data.units[i].y=5
    data.units[i].ally=true;data.units[i].movement=3
    return data
static func target(direction):
    if direction in ["front_right","front_left"]:return Vector2i(4,8)
    return Vector2i(1,8) if direction=="back_left" else Vector2i(4,5)
