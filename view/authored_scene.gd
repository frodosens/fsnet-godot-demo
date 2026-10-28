extends RefCounted
# Explicit authored-map admission. Similar-looking/custom layouts retain 3D fallback.
static func profile(content):
    var C=preload("res://logic/content.gd")
    for entry in [
        {"data":C.reference_content(),"root":"res://assets/backgrounds/amber_bridge/","battle":"res://assets/backgrounds/amber_bridge_battle/background.png","canvas":Vector2(1280,800),"camera_offset":Vector2.ZERO},
        {"data":C.chapter_two_content(),"root":"res://assets/backgrounds/white_elm_watchhouse/","battle":"res://assets/backgrounds/white_elm_watchhouse/battle.png","canvas":Vector2(1586,992),"camera_offset":Vector2(1.0,0.0375233)}]:
        var authored=entry.data
        if content.get("id")==authored.id and content.get("width")==authored.width and content.get("height")==authored.height and content.get("terrain")==authored.terrain:
            entry["map"]=entry.root+("map.png" if authored.id=="white_elm_watchhouse" else "background.png")
            return entry
    return {}
