extends Node
const Session=preload("res://logic/session.gd")
const Runtime=preload("res://logic/runtime.gd")
const Authority=preload("res://logic/authority.gd")
const Content=preload("res://logic/content.gd")
var session
var editor_draft={}
var editor_raw_draft=""
var editor_saved_hash=""
var save_root="user://saves"
var server
var server_authority
var presentation={"seen":[],"active":"","line":0}
var saved_snapshot=""
var saved_presentation=""
var connection_age=0.0
var room_port=27840
var room_token=""
var last_error=""
var character_emission=0.35 # Texture-colored baseline; presentation only.
var scene_renderer="auto" # Compatible authored scene by default; explicit session choice wins.
var cutins_enabled=true
var reduced_motion=false
var sfx_enabled=true
var sfx_volume_db=-12.0
var idle_sequence_previews={"neri":false,"adela":false,"elsbet":false}
var bram_sequence_preview=false # User-accepted provisional gesture and shuffle.
var oren_sequence_preview=false # Provisional idle/motion; old art remains available.
var finn_motion_preview=false # Motion-only trial; original Finn idle is retained.
var mara_sequence_preview=false # Local opt-in for unapproved compact art candidate.
var health_bar_avoidance=false
var presentation_preferences_path="user://presentation.cfg"
func load_presentation_preferences():
    for id in idle_sequence_previews:idle_sequence_previews[id]=false
    health_bar_avoidance=false;mara_sequence_preview=false;finn_motion_preview=false;oren_sequence_preview=false;bram_sequence_preview=false
    var config=ConfigFile.new()
    if config.load(presentation_preferences_path)==OK:
        var value=config.get_value("map","health_bar_avoidance",false)
        if value is bool:health_bar_avoidance=value
        value=config.get_value("map","mara_sequence_preview",false)
        if value is bool:mara_sequence_preview=value
        value=config.get_value("map","finn_motion_preview",false)
        if value is bool:finn_motion_preview=value
        value=config.get_value("map","oren_sequence_preview",false)
        if value is bool:oren_sequence_preview=value
        value=config.get_value("map","bram_sequence_preview",false)
        if value is bool:bram_sequence_preview=value
        for id in idle_sequence_previews:
            value=config.get_value("map",id+"_idle_preview",false)
            if value is bool:idle_sequence_previews[id]=value
func set_health_bar_avoidance(on):
    health_bar_avoidance=bool(on)
    var config=ConfigFile.new();config.load(presentation_preferences_path)
    config.set_value("map","health_bar_avoidance",health_bar_avoidance)
    var result=config.save(presentation_preferences_path)
    if result!=OK:push_warning("Cannot save local health bar preference: "+str(result))
const SLOT_IDS=["auto","slot1","slot2","slot3"]
const CHECKPOINT_PREFIX="chapter1_end_"
func _ready():
    get_tree().auto_accept_quit=false
    load_presentation_preferences()
    var fps=preload("res://ui/fps_display.gd").new();fps.name="FPSDisplay";add_child(fps)
func _process(delta):
    if server:
        for event in server.poll_events():
            server.respond(event.id,JSON.stringify(server_authority.handle(Content.parse_json(event.payload))))
    if session and session.online:
        session.tick(delta)
        if not session.status.begins_with("Online"):
            connection_age+=delta
            if connection_age>10.0 and not session.failed:
                session.failed=true;session.status="连接超时，请检查房间口令和端口。"
        else:connection_age=0.0
func close_room():
    if session and session.transport:session.transport.shutdown()
    if server:server.shutdown()
    server=null;server_authority=null
func startup_error():
    if ClassDB.class_exists("AmberLogic") and ClassDB.class_exists("AmberTransport"):return ""
    return "原生组件未加载，暂时无法开始游戏。\n当前平台：%s / %s\nWindows x86_64：请使用官方 Godot 4.6.3 标准版，确认 bin/windows/x86_64 中四个 DLL 齐全，然后完全关闭并重新打开编辑器。若仍失败，请保留输出中的 DLL 名称和错误码；参见 docs/WINDOWS_RUNTIME.md。Windows 运行尚待实机验证。Linux x86_64 仍须按 README 构建 bin/libamber.so 和外部 libfsnet；macOS 暂无对应运行库。\n请检查 Godot 输出中的 GDExtension 加载错误。" % [OS.get_name(),Engine.get_architecture_name()]
func new_game(data={}):
    last_error=startup_error()
    if not last_error.is_empty():return false
    close_room();session=Session.new();session.offline(data)
    presentation={"seen":[],"active":"","line":0};saved_snapshot="";saved_presentation="";last_error=""
    return true
func next_chapter_ready():
    return session!=null and session.logic.content.id=="amber_bridge_reference" and session.logic.outcome=="victory" and next_story().is_empty()
func enter_next_chapter():
    if not next_chapter_ready():last_error="请先完成第一章胜利剧情。";return false
    if session.online:last_error="网络房间内容固定。请双方退出后选择第二章创建/加入新房间。";return false
    var error=save_chapter_checkpoint()
    if not error.is_empty():last_error=error;return false
    return new_game(Content.chapter_two_content())
func start_room(host,port,secret,data={}):
    last_error=startup_error()
    if not last_error.is_empty():return false
    if data.is_empty() and not OS.get_environment("AMBER_MOD").is_empty():
        var loaded=Content.from_file(OS.get_environment("AMBER_MOD"))
        if not loaded.error.is_empty():last_error=loaded.error;return false
        data=loaded.data
    close_room();new_game(data);room_port=port;room_token=secret;connection_age=0.0
    if host:
        server_authority=Authority.new(session.logic.content);server=ClassDB.instantiate("AmberTransport")
        if not server.start(true,port,secret):last_error=server.last_error();close_room();return false
    if not session.connect_local(port,secret):last_error=session.status;close_room();return false
    return true
func dirty():
    return session and (session.logic.snapshot()!=saved_snapshot or JSON.stringify(presentation)!=saved_presentation)
func save_path(slot):return save_root+"/"+slot+".json"
func is_chapter_checkpoint(slot):
    if not slot is String or not slot.begins_with(CHECKPOINT_PREFIX):return false
    var digest=slot.trim_prefix(CHECKPOINT_PREFIX)
    if digest.length()!=64:return false
    for c in digest:
        if c not in "0123456789abcdef":return false
    return true
func checkpoint_id(rules_hash,content_hash,snapshot,local_story):
    return CHECKPOINT_PREFIX+(rules_hash+content_hash+snapshot+JSON.stringify(local_story,"",true)).sha256_text()
func loadable_slots():
    var result=SLOT_IDS.duplicate()
    var checkpoints=[]
    if DirAccess.dir_exists_absolute(save_root):
        for file in DirAccess.get_files_at(save_root):
            if file.ends_with(".json") and is_chapter_checkpoint(file.trim_suffix(".json")):checkpoints.append(file.trim_suffix(".json"))
    checkpoints.sort();result.append_array(checkpoints)
    return result
func save_chapter_checkpoint():
    if not next_chapter_ready() or session.online:return "仅离线第一章结尾可以建立章节检查点。"
    var slot=checkpoint_id(session.logic.rules_hash,session.logic.content_hash,session.logic.snapshot(),presentation)
    if FileAccess.file_exists(save_path(slot)):
        var existing=inspect_slot(slot)
        if not existing.error.is_empty():return "已有章节检查点校验失败，未覆盖文件："+existing.error
        return ""
    return _write_save(slot)
func save_slot(slot):
    if slot not in SLOT_IDS:return "无效存档槽。"
    return _write_save(slot)
# Callers select either an ordinary user slot or a content-addressed chapter checkpoint.
func _write_save(slot):
    if not session:return "当前没有战斗。"
    if session.online:return "本版网络对局不支持本地存档；房间状态由主机维护。"
    if slot not in SLOT_IDS:
        if not is_chapter_checkpoint(slot) or not next_chapter_ready() or slot!=checkpoint_id(session.logic.rules_hash,session.logic.content_hash,session.logic.snapshot(),presentation):return "无效章节检查点。"
        if FileAccess.file_exists(save_path(slot)):return "章节检查点已存在，不允许覆盖。"
    var data={"format":2,"rules_hash":session.logic.rules_hash,"content_hash":session.logic.content_hash,
        "content":session.logic.content,"snapshot":session.logic.snapshot(),"hash":session.logic.state_hash(),
        "presentation":presentation.duplicate(true),"saved_at":Time.get_datetime_string_from_system(false,true)}
    DirAccess.make_dir_recursive_absolute(save_root)
    var path=save_path(slot);var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
    if not file:return "无法写入存档，原存档未改变。"
    file.store_string(JSON.stringify(data,"",true));file.flush();var write_error=file.get_error();file.close()
    if write_error!=OK:
        DirAccess.remove_absolute(path+".tmp")
        return "存档写入未完成，原存档未改变。"
    if DirAccess.rename_absolute(path+".tmp",path)!=OK:return "无法完成存档替换，原存档未改变。"
    saved_snapshot=session.logic.snapshot();saved_presentation=JSON.stringify(presentation)
    return ""
func inspect_slot(slot):
    var issue_startup=startup_error()
    if not issue_startup.is_empty():return {"error":issue_startup}
    if slot not in SLOT_IDS and not is_chapter_checkpoint(slot):return {"error":"无效存档槽。"}
    if not FileAccess.file_exists(save_path(slot)):return {"error":"无存档","empty":true}
    var file=FileAccess.open(save_path(slot),FileAccess.READ)
    if not file or file.get_length()>262144:return {"error":"存档无法读取或大小异常。"}
    var data=Content.normalize(Content.parse_json(file.get_as_text()))
    if not data is Dictionary or data.get("format")!=2:return {"error":"存档损坏或版本不兼容。"}
    if data.get("rules_hash")!=preload("res://logic/runtime.gd").rule_source().sha256_text():return {"error":"规则版本不兼容，请保留旧存档。"}
    var issue=Content.validate(data.get("content"))
    if not issue.is_empty() or Content.hash_of(data.content)!=data.get("content_hash"):return {"error":"内容版本校验失败："+issue}
    var candidate=Runtime.new(data.content)
    if not data.get("snapshot") is String or not candidate.restore(data.snapshot) or candidate.state_hash()!=data.get("hash"):return {"error":"战斗快照损坏或校验不符。"}
    var p=data.get("presentation")
    if not valid_presentation(p,candidate):return {"error":"剧情阅读进度损坏。"}
    if is_chapter_checkpoint(slot) and (data.content.id!="amber_bridge_reference" or candidate.outcome!="victory" or slot!=checkpoint_id(data.rules_hash,data.content_hash,data.snapshot,p)):
        return {"error":"章节检查点身份校验失败。"}
    return {"error":"","data":data,"round":candidate.round_number,"step":candidate.step,"title":data.content.title,"saved_at":data.get("saved_at","")}
func valid_presentation(p,logic):
    if not p is Dictionary or not p.get("seen") is Array or p.seen.size()>24 or not p.get("active") is String or not Content.integer(p.get("line"),0,32):return false
    var known={}
    for event in logic.content.story.events:known[event.id]=event.lines.size()
    for id in p.seen:
        if not known.has(id):return false
    if p.active!="" and (not known.has(p.active) or p.line>=known[p.active] or p.active in p.seen):return false
    return true
func load_slot(slot):
    var result=inspect_slot(slot)
    if not result.error.is_empty():last_error=result.error;return false
    var data=result.data
    var replacement=Session.new();replacement.offline(data.content)
    if not replacement.logic.restore(data.snapshot):last_error="快照恢复失败。";return false
    replacement.authority.checkpoint=replacement.logic.snapshot();replacement.authority.history.clear()
    close_room();session=replacement;presentation=data.presentation.duplicate(true)
    saved_snapshot=session.logic.snapshot();saved_presentation=JSON.stringify(presentation);last_error=""
    return true
func speaker_name(id):
    if id=="narrator":return session.logic.content.story.chapterTitle
    for person in session.logic.content.story.characters:
        if person.id==id:return person.name
    return id
func event_by_id(id):
    for event in session.logic.content.story.events:
        if event.id==id:return event
    return {}
func next_story():
    if not session:return {}
    var logic=session.logic;var entries=logic.content.story.events
    # Terminal events preempt local mid-battle dialogue without changing shared flags.
    if logic.outcome!="playing":
        var terminal="battle_terminal_"+logic.outcome
        for event in entries:
            if event.trigger==terminal and event.id not in presentation.seen:
                if presentation.active!=event.id:presentation.active=event.id;presentation.line=0
                break
        if presentation.active!="" and event_by_id(presentation.active).get("trigger")!=terminal:
            presentation.active="";presentation.line=0
    if presentation.active=="":
        for i in range(entries.size()):
            var event=entries[i]
            if logic.outcome!="playing" and event.trigger not in ["battle_terminal_victory","battle_terminal_defeat"]:continue
            if (logic.story_flags & (1<<i))!=0 and event.id not in presentation.seen:
                presentation.active=event.id;presentation.line=0;break
    if presentation.active=="":return {}
    var current=event_by_id(presentation.active)
    var mid=current.trigger.begins_with("first_player_turn") or current.trigger=="round"
    while presentation.line<current.lines.size():
        var line=current.lines[presentation.line]
        var unavailable=false
        if mid:
            for u in logic.units:
                if u.id==line.speaker and u.hp<=0:unavailable=true
        if not unavailable:return {"id":current.id,"speaker":line.speaker,"text":line.text,"index":presentation.line+1,"total":current.lines.size()}
        presentation.line+=1
    complete_story();return next_story()
func complete_story():
    if presentation.active!="" and presentation.active not in presentation.seen:presentation.seen.append(presentation.active)
    presentation.active="";presentation.line=0
func advance_story(skip=false):
    if presentation.active=="":return
    if skip:complete_story()
    else:
        presentation.line+=1
        if presentation.line>=event_by_id(presentation.active).lines.size():complete_story()
func return_to_menu():
    close_room();session=null
    get_tree().call_deferred("change_scene_to_file","res://ui/menu.tscn")
func _notification(what):
    if what==NOTIFICATION_WM_CLOSE_REQUEST:
        var scene=get_tree().current_scene
        if scene and scene.has_method("request_exit"):scene.request_exit()
        else:get_tree().quit()
func _exit_tree():close_room()

func set_mara_sequence_preview(on):
    mara_sequence_preview=bool(on)
    var config=ConfigFile.new();config.load(presentation_preferences_path)
    config.set_value("map","mara_sequence_preview",mara_sequence_preview)
    if config.save(presentation_preferences_path)!=OK:push_warning("Cannot save map sequence preference")
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("mara")

func map_sequence_enabled(id):
    if idle_sequence_previews.has(id):return idle_sequence_previews[id]
    if id=="bram":return bram_sequence_preview
    if id=="oren":return oren_sequence_preview
    return mara_sequence_preview if id=="mara" else (finn_motion_preview if id=="finn" else false)
func set_finn_motion_preview(on):
    finn_motion_preview=bool(on)
    var config=ConfigFile.new();config.load(presentation_preferences_path)
    config.set_value("map","finn_motion_preview",finn_motion_preview)
    if config.save(presentation_preferences_path)!=OK:push_warning("Cannot save Finn motion preference")
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("finn")

func set_oren_sequence_preview(on):
    oren_sequence_preview=bool(on)
    var config=ConfigFile.new();config.load(presentation_preferences_path)
    config.set_value("map","oren_sequence_preview",oren_sequence_preview)
    if config.save(presentation_preferences_path)!=OK:push_warning("Cannot save Oren sequence preference")
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("oren")

func set_bram_sequence_preview(on):
    bram_sequence_preview=bool(on)
    var config=ConfigFile.new();config.load(presentation_preferences_path)
    config.set_value("map","bram_sequence_preview",bram_sequence_preview)
    if config.save(presentation_preferences_path)!=OK:push_warning("Cannot save Bram sequence preference")
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("bram")

func set_idle_sequence_preview(on,id):
    if not idle_sequence_previews.has(id):return
    idle_sequence_previews[id]=bool(on)
    var config=ConfigFile.new();config.load(presentation_preferences_path)
    config.set_value("map",id+"_idle_preview",bool(on))
    if config.save(presentation_preferences_path)!=OK:push_warning("Cannot save idle sequence preference")
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art(id)
