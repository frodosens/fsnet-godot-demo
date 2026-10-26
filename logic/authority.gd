extends RefCounted
# Same authoritative sequencer used by offline play and headless server.
const Runtime = preload("res://logic/runtime.gd")
var logic
var checkpoint = ""
var history = []
var clients = {}
const MAX_CLIENTS = 8

func _init(data={}):
    logic=Runtime.new(data)
    checkpoint=logic.snapshot()

# JSON only transports values; canonical state hashing happens in the rules VM.
static func command_from_json(value):
    if not value is Dictionary: return {}
    var result = {}
    for key in value:
        if key in ["kind","actor_id","target_id","ability","consumable"]:
            if not value[key] is String: return {}
            result[key] = value[key]
        elif key in ["step","unit","target","x","y","slot","item"]:
            var v = value[key]
            if not (v is int or v is float) or not is_finite(float(v)) or float(v) != floor(float(v)) or abs(float(v)) > 1000000: return {}
            result[key] = int(v)
        else: return {}
    return result

func handle(request):
    var accepted = false
    var reason = "sync"
    if not request is Dictionary or request.get("rules","") != logic.rules_hash or request.get("content","") != logic.content_hash:
        return {"error":"rules mismatch"}
    var client = request.get("client","")
    if not client is String or client.length() < 8 or client.length() > 64:
        return {"error":"invalid client id"}
    if not clients.has(client):
        if clients.size() >= MAX_CLIENTS: return {"error":"session full"}
        clients[client] = 0
    if request.has("command"):
        var raw_id = request.get("id",-1)
        if not (raw_id is int or raw_id is float) or not is_finite(float(raw_id)) or float(raw_id) != floor(float(raw_id)) or raw_id < 1 or raw_id > 1000000:
            return {"error":"invalid request id"}
        var id = int(raw_id)
        if id <= clients[client]: reason = "duplicate"
        elif id != clients[client]+1: reason = "request id gap"
        else:
            clients[client] = id
            var command = command_from_json(request.command)
            accepted = logic.apply_command(command)
            reason = "accepted" if accepted else "stale or illegal command"
            if accepted:
                history.append({"command":command,"hash":logic.state_hash()})
                # Bounded snapshot + tail log: clients may reconnect at any step.
                if history.size() >= 16:
                    checkpoint = logic.snapshot()
                    history.clear()
    return {"rules":logic.rules_hash,"content":logic.content_hash,"snapshot":checkpoint,"history":history.duplicate(true),
        "step":logic.step,"hash":logic.state_hash(),"accepted":accepted,"reason":reason,"ack":clients[client]}
