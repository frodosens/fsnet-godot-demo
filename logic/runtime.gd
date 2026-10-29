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
var progression={}
var vm = ClassDB.instantiate("AmberLogic")
var units = []
var round_number = 1
var outcome = "playing"
var step = 0
var last_event = "A small bridge, a warm evening. Keep your crew safe."
var rules_hash = ""

func _init(data={},campaign={}):
    content=Content.default_content() if data.is_empty() else data.duplicate(true)
    content_hash=Content.hash_of(content)
    size=Vector2i(content.width,content.height)
    var source = rule_source()
    rules_hash = source.sha256_text()
    assert(vm.load_rules(source),vm.last_error())
    reset(campaign)

# Snapshot-only compatibility: this reviewed predecessor has identical v5 state layout.
# Command replay and network handshakes continue requiring the current rule hash.
const SNAPSHOT_COMPATIBLE_RULES=["ff0209fc228021e6c2a82a3a4858fe20e26996d3e0b75f3a16966125a7855ca5"]
static func accepts_saved_rules(hash_value):
    return hash_value==rule_source().sha256_text() or hash_value==LEGACY_V5_HASH or hash_value in SNAPSHOT_COMPATIBLE_RULES

const LEGACY_V5_HASH="eca9005795cd476b1b996a9b2c87ffa6a79364def71d2d4a87f1335427659d5b"
static func legacy_rule_source():
    var source=FileAccess.get_file_as_string("res://logic/legacy_v5_rules.lua")
    return source if source.sha256_text()==LEGACY_V5_HASH else ""
static func validate_legacy(data,snapshot,expected_hash):
    var legacy=ClassDB.instantiate("AmberLogic")
    if not legacy.load_rules(legacy_rule_source()):return false
    legacy.invoke("reset",{"seed":12345,"content":data})
    if not legacy.last_error().is_empty() or legacy.invoke("restore",{"snapshot":snapshot})!=true:return false
    return str(legacy.invoke("snapshot",{})).sha256_text()==expected_hash
static func validate_campaign(c):
    if not c is Dictionary or c.size()!=2 or not c.get("roster") is Array or not c.get("completed") is Array:return false
    if c.roster.size()>32 or c.completed.size()>32:return false
    var ids={}
    for entry in c.roster:
        if not entry is Dictionary or entry.size()!=2 or not Content.identifier(entry.get("id")) or not Content.integer(entry.get("xp"),0,1620) or ids.has(entry.id):return false
        ids[entry.id]=true
    ids={}
    for id in c.completed:
        if not Content.identifier(id) or ids.has(id):return false
        ids[id]=true
    return true
static func campaign_fits(data,c):
    if not validate_campaign(c):return false
    if c.completed.size()==32 and data.id not in c.completed:return false
    var ids={}
    for entry in c.roster:ids[entry.id]=true
    for u in data.units:
        if u.get("controller","player" if u.ally else "ai")=="player":ids[u.id]=true
    return ids.size()<=32
func campaign_state():return progression.campaign.duplicate(true)

static func rule_source():
    var source = FileAccess.get_file_as_string("res://logic/battle.lua")
    # Fixed trusted modules only. Their complete source participates in peer/save compatibility.
    for module in ["board","progression","equipment","objectives","abilities","actions","ai","snapshot"]:
        var code=FileAccess.get_file_as_string("res://logic/rules/"+module+".lua")
        assert(not code.is_empty(),"Missing trusted rule module: "+module)
        source=source.replace("-- @module "+module,code)
    return source

func call_rule(method,args={}):
    var value = vm.invoke(method,args)
    assert(vm.last_error().is_empty(),vm.last_error())
    return value

func reset(campaign={}):
    var args={"seed":12345,"content":content}
    if not campaign.is_empty():
        assert(campaign_fits(content,campaign),"Invalid campaign progression")
        args.campaign=campaign
    call_rule("reset",args)
    refresh()

func refresh():
    var data = call_rule("view")
    units = data.units
    inventory=data.inventory
    supplies=data.supplies
    progression=call_rule("progression")
    for u in units: u.pos = Vector2i(u.x,u.y)
    round_number = data.round_number
    outcome = data.outcome
    step = data.step
    story_flags=data.story_flags
    preparation=data.preparation

func snapshot(): return str(call_rule("snapshot"))
func state_hash(): return snapshot().sha256_text()
func restore(raw,allow_legacy=false):
    var ok = call_rule("restore",{"snapshot":raw,"allow_legacy":allow_legacy}) == true
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
