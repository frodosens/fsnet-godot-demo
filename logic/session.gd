extends RefCounted
const Runtime = preload("res://logic/runtime.gd")
const Authority = preload("res://logic/authority.gd")
var logic = Runtime.new()
var authority
var transport
var online = false
var client_id = Crypto.new().generate_random_bytes(16).hex_encode()
var request_id = 0
var pending = false
var port = 27840
var token = ""
var retry_clock = 0.0
var status = "Offline · shared Lua rules"
var failed = false

func offline(data={}):
    if transport: transport.shutdown()
    transport = null
    online = false
    authority = Authority.new(data)
    logic = authority.logic
    request_id = 0
    pending = false
    failed = false
    status = "Offline · shared Lua rules"

func connect_local(p,secret):
    port=p; token=secret;online=true;failed=false
    transport=ClassDB.instantiate("AmberTransport")
    if not transport.start(false,port,token):
        status=transport.last_error();failed=true;return false
    status="Connecting to local authority…";pending=false;retry_clock=0.0
    return true

func envelope(): return {"rules":logic.rules_hash,"content":logic.content_hash,"client":client_id}

func submit(command):
    if failed or pending: return false
    command=command.duplicate(true)
    command.step=logic.step+1
    request_id+=1
    var request=envelope()
    request.id=request_id
    request.command=command
    if not online:
        var reply=authority.handle(request)
        status=reply.get("reason","error")
        return reply.get("accepted",false)
    if not transport.send(JSON.stringify(request)):
        request_id-=1;status="Transport rejected send";return false
    pending=true
    status="Waiting for ordered command…"
    return true

func synchronize(reply):
    if not reply is Dictionary or reply.has("error") or reply.get("rules","") != logic.rules_hash or reply.get("content","") != logic.content_hash:
        status="Protocol/rules mismatch";failed=true;return false
    # Validate in a separate VM; never expose a partially applied or mismatched state.
    var candidate=Runtime.new(logic.content)
    if not reply.get("snapshot") is String or not candidate.restore(reply.snapshot):
        status="Invalid snapshot";failed=true;return false
    var entries=reply.get("history")
    if not entries is Array or entries.size()>16:
        status="Invalid replay log";failed=true;return false
    for entry in entries:
        if not entry is Dictionary or not candidate.apply_command(Authority.command_from_json(entry.get("command"))) or candidate.state_hash()!=entry.get("hash"):
            status="Replay hash mismatch";failed=true;return false
    if candidate.state_hash()!=reply.get("hash") or candidate.step!=reply.get("step"):
        status="State hash mismatch";failed=true;return false
    if candidate.step<logic.step:
        status="Stale server state rejected";failed=true;return false
    var ack=reply.get("ack",-1)
    if not (ack is int or ack is float) or not is_finite(float(ack)) or float(ack)!=floor(float(ack)) or ack<0 or ack>1000000:
        status="Invalid acknowledgement";failed=true;return false
    request_id=int(ack)
    logic=candidate
    status="Online · action %d · %s" % [logic.step,reply.get("reason","sync")]
    return true

func tick(delta):
    if not online or failed: return
    for event in transport.poll_events():
        pending=false
        if event.status!=0:
            status="Disconnected; reconnecting (no blind command retry)…"
            transport.shutdown()
            transport.start(false,port,token)
            retry_clock=0.5
        else: synchronize(Runtime.Content.parse_json(event.payload))
    retry_clock-=delta
    if not pending and retry_clock<=0.0:
        pending=transport.send(JSON.stringify(envelope()))
        retry_clock=0.15
