extends Node
var game
var library=preload("res://view/idle_library.gd").new()
var clocks={}
var directions={}
func _ready():process_priority=20 # After path movement, before material sync.
func _process(delta):advance(delta)
func advance(delta):
    var paused=(game.hud and game.hud.blocks_input()) or (game.cutin and game.cutin.active)
    for i in range(game.battle.units.size()):
        var unit=game.battle.units[i];var id=unit.id;var profile=game.presentation_id(unit)
        var direction=game.facing.get(id,"front")
        if directions.get(id,"")!=direction:clocks[id]=0.0;directions[id]=direction
        if unit.hp<=0 or game.motion.motions.has(id):clocks[id]=0.0;continue
        var time=float(clocks.get(id,0.0))
        if not paused:time+=maxf(0,delta)
        clocks[id]=time
        var fallback=game.direction_textures.get(id+":"+direction,game.figures[i].texture)
        var reserve=preload("res://view/reserve_art.gd").profile(profile)
        var texture=reserve.map.get(direction,fallback) if not reserve.is_empty() else library.sample("map",preload("res://logic/presentation_profiles.gd").map_role(unit)+":"+direction,time,fallback,App.reduced_motion,profile)
        if App.map_sequence_enabled(profile):
            var guard=game.base_directional_idle_texture(i,direction)
            var sequences=preload("res://view/map_sequence.gd").shared()
            var entry=sequences.matching(profile,direction,guard)
            if not entry.is_empty() and not entry.idle.is_empty():texture=sequences.idle(profile,direction,time,guard,App.reduced_motion)

        game.apply_map_idle_texture(i,direction,texture)
