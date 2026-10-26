extends RefCounted
# The ONLY rules implementation is battle.lua; this adapter only marshals data.
const Content=preload("res://logic/content.gd")
var content={}
var content_hash=""
var story_flags=0
var preparation=true
var size=Vector2i(10,8)
var events=[]
var inventory=[]
var supplies=[]
var vm = ClassDB.instantiate("AmberLogic")
var units = []
var round_number = 1
var outcome = "playing"
var step = 0
var last_event = "A small bridge, a warm evening. Keep your crew safe."
var rules_hash = ""

func _init(data={}):
    content=Content.default_content() if data.is_empty() else data.duplicate(true)
    content_hash=Content.hash_of(content)
    size=Vector2i(content.width,content.height)
    var source = rule_source()
    rules_hash = source.sha256_text()
    assert(vm.load_rules(source),vm.last_error())
    reset()

static func rule_source():
    var source = FileAccess.get_file_as_string("res://logic/battle.lua")
    # Fixed trusted modules only. Their complete source participates in peer/save compatibility.
    for module in ["board","equipment","objectives","abilities","actions","ai","snapshot"]:
        var code=FileAccess.get_file_as_string("res://logic/rules/"+module+".lua")
        assert(not code.is_empty(),"Missing trusted rule module: "+module)
        source=source.replace("-- @module "+module,code)
    return source

func call_rule(method,args={}):
    var value = vm.invoke(method,args)
    assert(vm.last_error().is_empty(),vm.last_error())
    return value

func reset():
    call_rule("reset",{"seed":12345,"content":content})
    refresh()

func refresh():
    var data = call_rule("view")
    units = data.units
    inventory=data.inventory
    supplies=data.supplies
    for u in units: u.pos = Vector2i(u.x,u.y)
    round_number = data.round_number
    outcome = data.outcome
    step = data.step
    story_flags=data.story_flags
    preparation=data.preparation

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
        var emitted=call_rule("events")
        events=emitted if emitted is Array else []
        last_event = "Action %d · %s" % [step,command.kind]
        if outcome == "victory": last_event = "Bridge secured. Supper at the inn is on us!"
        elif outcome == "defeat": last_event = "The crew retreats. Start a new local battle to try again."
    return ok
func preview_action(command):return call_rule("preview",command)
func path_to(index,pos):return call_rule("path",{"unit":index,"x":pos.x,"y":pos.y})
func reachable(index):
    var result = {}
    for cell in call_rule("reachable",{"unit":index}): result[Vector2i(cell.x,cell.y)] = cell.d
    return result
# Presentation queries; movement legality is decided only by Lua.
func walkable(pos): return pos.x >= 0 and pos.x < size.x and pos.y >= 0 and pos.y < size.y and content.terrain[pos.y][pos.x] not in ["W","X"]
func at(pos):
    for i in range(units.size()):
        if units[i].hp > 0 and units[i].pos == pos: return i
    return -1
func usable(index): return outcome == "playing" and index >= 0 and index < units.size() and units[index].controller == "player" and units[index].hp > 0
