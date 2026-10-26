extends SceneTree
const Authority=preload("res://logic/authority.gd")
var authority
var transport
func _initialize():
    var data={}
    var mod_path=OS.get_environment("AMBER_MOD")
    if not mod_path.is_empty():
        var loaded=Authority.Runtime.Content.from_file(mod_path)
        if not loaded.error.is_empty():printerr("Invalid server Mod: ",loaded.error);quit(1);return
        data=loaded.data
    authority=Authority.new(data)
    transport=AmberTransport.new()
    var port=27840
    var token=OS.get_environment("AMBER_TOKEN")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--port="): port=int(arg.trim_prefix("--port="))
    if not transport.start(true,port,token):
        printerr(transport.last_error());quit(1);return
    print("AMBER_SERVER_READY loopback=127.0.0.1 port=",port," rules=",authority.logic.rules_hash)
func _process(_delta):
    if not transport: return false
    for event in transport.poll_events():
        var request=Authority.Runtime.Content.parse_json(event.payload)
        var response=authority.handle(request)
        transport.respond(event.id,JSON.stringify(response))
    return false
func _finalize():
    if transport: transport.shutdown()
