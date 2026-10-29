extends RefCounted
# Explicit authored-map admission. Similar-looking/custom layouts retain 3D fallback.
static var chapter_three_contract={}
static var chapter_three_battle_contract={}
static func third_profile():
    var root="res://assets/backgrounds/sluice_watchhouse/"
    if chapter_three_contract.is_empty():
        var map_file=FileAccess.open(root+"map-background-contract.json",FileAccess.READ)
        var battle_file=FileAccess.open(root+"battle-background-contract.json",FileAccess.READ)
        if not map_file or not battle_file:return {}
        var parser=preload("res://logic/content.gd")
        var map_data=JSON.parse_string(map_file.get_as_text());var battle_data=JSON.parse_string(battle_file.get_as_text())
        if not map_data is Dictionary or not battle_data is Dictionary:return {}
        var data=preload("res://logic/content.gd").chapter_three_content()
        if map_data.get("rows")!=data.terrain or parser.normalize(map_data.get("source_size"))!=[1586,992]:return {}
        for pair in [["origin",Vector2(618.8,120.34128)],["basis_x",Vector2(42.4,29.98104)],["basis_y",Vector2(-42.4,29.98104)]]:
            var v=map_data.get(pair[0])
            if not v is Array or v.size()!=2:return {}
            if not (v[0] is float or v[0] is int) or not (v[1] is float or v[1] is int):return {}
            if not Vector2(v[0],v[1]).is_equal_approx(pair[1]):return {}
        if map_data.get("asset")!="Chapter-3-clean-map-candidate-v2.png" or battle_data.get("asset")!="Chapter-3-sluice-battle-background.png" or parser.normalize(battle_data.get("feet_source_px"))!=[[532,642],[1052,642]]:return {}
        chapter_three_contract=map_data;chapter_three_battle_contract=battle_data
    var c=chapter_three_contract
    return {"data":preload("res://logic/content.gd").chapter_three_content(),"root":root,"map":root+c.asset,"battle":root+chapter_three_battle_contract.asset,"canvas":Vector2(c.source_size[0],c.source_size[1]),"camera_offset":Vector2.ZERO,"projection_contract":c,"battle_contract":chapter_three_battle_contract}
static func profile(content):
    var C=preload("res://logic/content.gd")
    for entry in [
        {"data":C.reference_content(),"root":"res://assets/backgrounds/amber_bridge/","battle":"res://assets/backgrounds/amber_bridge_battle/background.png","canvas":Vector2(1280,800),"camera_offset":Vector2.ZERO},
        {"data":C.chapter_two_content(),"root":"res://assets/backgrounds/white_elm_watchhouse/","battle":"res://assets/backgrounds/white_elm_watchhouse/battle.png","canvas":Vector2(1586,992),"camera_offset":Vector2(1.0,0.0375233)},third_profile()]:
        if entry.is_empty():continue
        var authored=entry.data
        if (content.get("id")==authored.id or {"homeward_01":"amber_bridge_reference","homeward_02":"white_elm_watchhouse","homeward_03":"mill_receipts"}.get(content.get("id",""),"")==authored.id) and content.get("width")==authored.width and content.get("height")==authored.height and content.get("terrain")==authored.terrain:
            if not entry.has("map"):entry["map"]=entry.root+("map.png" if authored.id=="white_elm_watchhouse" else "background.png")
            return entry
    return {}
