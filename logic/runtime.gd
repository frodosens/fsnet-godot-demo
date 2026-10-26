extends RefCounted
# The ONLY rules implementation is battle.lua; this adapter only marshals data.
const SIZE = Vector2i(10,8)
var vm = AmberLogic.new()
var units = []
var round_number = 1
var outcome = "playing"
var step = 0
var last_event = "A small bridge, a warm evening. Keep your crew safe."
var rules_hash = ""

func _init():
    var source = FileAccess.get_file_as_string("res://logic/battle.lua")
    rules_hash = source.sha256_text()
    assert(vm.load_rules(source),vm.last_error())
    reset()

func call_rule(method,args={}):
    var value = vm.invoke(method,args)
    assert(vm.last_error().is_empty(),vm.last_error())
    return value

func reset():
    call_rule("reset",{"seed":12345})
    refresh()

func refresh():
    var data = call_rule("view")
    units = data.units
    for u in units: u.pos = Vector2i(u.x,u.y)
    round_number = data.round_number
    outcome = data.outcome
    step = data.step

func snapshot(): return str(call_rule("snapshot"))
func state_hash(): return snapshot().sha256_text()
func restore(raw):
    var ok = call_rule("restore",{"snapshot":raw}) == true
    if ok: refresh()
    return ok
func apply_command(command):
    var ok = call_rule("apply",command) == true
    if ok:
        refresh()
        last_event = "Action %d · %s" % [step,command.kind]
        if outcome == "victory": last_event = "Bridge secured. Supper at the inn is on us!"
        elif outcome == "defeat": last_event = "The crew retreats. Start a new local battle to try again."
    return ok
func reachable(index):
    var result = {}
    for cell in call_rule("reachable",{"unit":index}): result[Vector2i(cell.x,cell.y)] = cell.d
    return result
# Presentation queries; movement legality is decided only by Lua.
func walkable(pos): return pos.x >= 0 and pos.x < 10 and pos.y >= 0 and pos.y < 8 and (pos.y not in [3,4] or pos.x in [4,5])
func at(pos):
    for i in range(units.size()):
        if units[i].hp > 0 and units[i].pos == pos: return i
    return -1
func usable(index): return outcome == "playing" and index >= 0 and index < 3 and units[index].hp > 0
