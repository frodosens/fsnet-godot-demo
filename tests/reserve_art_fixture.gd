extends RefCounted
# Existing knight/raider rules carry reserve art. This is not a new class roster.
static func content():
    var data=preload("res://logic/content.gd").reference_content()
    data.id="reserve_art_demo";data.title="备用美术验证 · 非新职业"
    data.units[0].id="adela";data.units[0].name="阿黛拉"
    data.units[3].id="elsbet";data.units[3].name="埃尔丝贝特"
    data.units[3].x=5;data.units[3].y=7;data.units[3].controller="player"
    data.story.events=[]
    return data
