extends RefCounted
# Presentation preferences (which animation/idle preview is on) and the on-disk
# preference file. App keeps the fields so call sites and tests can read them;
# this file owns the rules for reading/writing them.

var app


func _init(owner) -> void:
    app = owner

func load_presentation_preferences():
    for id in app.hero_map_refresh_previews:app.hero_map_refresh_previews[id]=true
    for id in app.idle_sequence_previews:app.idle_sequence_previews[id]=true
    app.rodd_motion_preview=true;app.elsbet_motion_preview=true
    app.adela_motion_preview=true;app.neri_motion_preview=true;app.tessa_motion_preview=true
    app.mara_sequence_preview=true;app.finn_motion_preview=true;app.oren_sequence_preview=true;app.bram_sequence_preview=true
    app.health_bar_avoidance=false
    var config=ConfigFile.new();var loaded=config.load(app.presentation_preferences_path)
    if loaded==OK:
        var value=config.get_value("map","health_bar_avoidance",false)
        if value is bool:app.health_bar_avoidance=value
    elif loaded!=ERR_FILE_NOT_FOUND:push_warning("Presentation preferences unreadable; preserving file and using defaults")

func neri_motion_preference_version(config):
    var version=config.get_value("map","neri_motion_default_version",0)
    return version if version is int and version>=0 else 0

func set_health_bar_avoidance(on):
    app.health_bar_avoidance=bool(on)
    var config=ConfigFile.new();config.load(app.presentation_preferences_path)
    config.set_value("map","health_bar_avoidance",app.health_bar_avoidance)
    var result=config.save(app.presentation_preferences_path)
    if result!=OK:push_warning("Cannot save local health bar preference: "+str(result))

func set_mara_sequence_preview(on):
    app.mara_sequence_preview=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("mara")

func map_sequence_enabled(id):
    if id=="tessa":return app.tessa_motion_preview
    if app.idle_sequence_previews.has(id):return app.idle_sequence_previews[id]
    if id=="bram":return app.bram_sequence_preview
    if id=="oren":return app.oren_sequence_preview
    return app.mara_sequence_preview if id=="mara" else (app.finn_motion_preview if id=="finn" else false)

func set_finn_motion_preview(on):
    app.finn_motion_preview=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("finn")

func set_oren_sequence_preview(on):
    app.oren_sequence_preview=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("oren")

func set_bram_sequence_preview(on):
    app.bram_sequence_preview=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("bram")

func set_idle_sequence_preview(on,id):
    if not app.idle_sequence_previews.has(id):return
    app.idle_sequence_previews[id]=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art(id)

func set_tessa_motion_preview(on):
    app.tessa_motion_preview=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("tessa")

func set_neri_motion_preview(on):
    app.neri_motion_preview=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("neri")

func set_adela_motion_preview(on):
    app.adela_motion_preview=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("adela")

func set_hero_map_refresh_preview(on,id):
    if not app.hero_map_refresh_previews.has(id):return
    app.hero_map_refresh_previews[id]=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art(id)

func set_rodd_motion_preview(on):
    app.rodd_motion_preview=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("rodd")

func set_elsbet_motion_preview(on):
    app.elsbet_motion_preview=bool(on)
    var game=app.get_tree().current_scene
    if game and game.has_method("refresh_elsbet_motion_art"):game.refresh_elsbet_motion_art()

# Homeward cues are local app.presentation; battle flags/outcome remain authoritative.
