extends Node
var session
var _inspector_impl
var _writer_impl
var mobile_presentation=OS.has_feature("android")
var safe_area_override=Rect2i() # Test-only physical screen inset fixture; never saved.
func ui_safe_rect():return preload("res://ui/mobile_layout.gd").safe_rect(get_viewport(),mobile_presentation,safe_area_override)
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
var hero_map_refresh_previews={"mara":true,"finn":true,"neri":true} # Latest accepted hero profiles; obsolete saved toggles are ignored.
var idle_sequence_previews={"neri":true,"adela":true,"elsbet":true}
var bram_sequence_preview=true # User-accepted provisional gesture and shuffle.
var oren_sequence_preview=true # Provisional idle/motion; old art remains available.
var tessa_motion_preview=true
const NERI_MOTION_DEFAULT_VERSION=1
var elsbet_motion_preview=true # Latest shipped map resources.
var rodd_motion_preview=true # Latest shipped map resources.
var adela_motion_preview=true # Independent movement-only two-panel trial.
var neri_motion_preview=true # User-approved default; independent of Neri idle.
var finn_motion_preview=true # Latest shipped map resources.
var mara_sequence_preview=true # Latest shipped map resources.
var health_bar_avoidance=false
var presentation_preferences_path="user://presentation.cfg"
# Animation selection is a shipped resource policy, not a saved user preference.
# Obsolete animation keys are ignored without rewriting unrelated settings.
func load_presentation_preferences():
    for id in hero_map_refresh_previews:hero_map_refresh_previews[id]=true
    for id in idle_sequence_previews:idle_sequence_previews[id]=true
    rodd_motion_preview=true;elsbet_motion_preview=true
    adela_motion_preview=true;neri_motion_preview=true;tessa_motion_preview=true
    mara_sequence_preview=true;finn_motion_preview=true;oren_sequence_preview=true;bram_sequence_preview=true
    health_bar_avoidance=false
    var config=ConfigFile.new();var loaded=config.load(presentation_preferences_path)
    if loaded==OK:
        var value=config.get_value("map","health_bar_avoidance",false)
        if value is bool:health_bar_avoidance=value
    elif loaded!=ERR_FILE_NOT_FOUND:push_warning("Presentation preferences unreadable; preserving file and using defaults")
func neri_motion_preference_version(config):
    var version=config.get_value("map","neri_motion_default_version",0)
    return version if version is int and version>=0 else 0
func set_health_bar_avoidance(on):
    health_bar_avoidance=bool(on)
    var config=ConfigFile.new();config.load(presentation_preferences_path)
    config.set_value("map","health_bar_avoidance",health_bar_avoidance)
    var result=config.save(presentation_preferences_path)
    if result!=OK:push_warning("Cannot save local health bar preference: "+str(result))
const SLOT_IDS=["auto","slot1","slot2","slot3"]
const CHECKPOINT_PREFIX="chapter1_end_"
const CHAPTER_CHECKPOINTS={"amber_bridge_reference":"chapter1_end_","white_elm_watchhouse":"chapter2_end_","homeward_01":"homeward1_end_","homeward_02":"homeward2_end_","homeward_03":"homeward3_end_","homeward_04":"homeward4_end_"}
func _ready():
    get_tree().auto_accept_quit=false
    load_presentation_preferences()
    var fps=preload("res://ui/fps_display.gd").new();fps.name="FPSDisplay";add_child(fps)
func _writer():
    if _writer_impl==null:_writer_impl=preload("res://ui/app/save_writer.gd").new(self)
    return _writer_impl

func _inspector():
    if _inspector_impl==null:_inspector_impl=preload("res://ui/app/save_inspector.gd").new(self)
    return _inspector_impl

func _process(delta):
    tick_homeward_story(delta)
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
func new_game(data={},campaign={}):
    if not data.is_empty():
        var expanded=Content.expand(data)
        if not expanded.error.is_empty():last_error=expanded.error;return false
        data=expanded.data
    last_error=startup_error()
    if not last_error.is_empty():return false
    if not campaign is Dictionary or (not campaign.is_empty() and not Runtime.campaign_fits(Content.default_content() if data.is_empty() else data,campaign)):
        last_error="成长记录无效，当前对局未改变。";return false
    close_room();session=Session.new();session.offline(data,campaign)
    presentation={"seen":[],"active":"","line":0,"campaign_instance":Crypto.new().generate_random_bytes(16).hex_encode()};saved_snapshot="";saved_presentation="";last_error=""
    homeward_player.scene_id=""
    return true
func next_chapter_number():
    if session==null:return 0
    return {"amber_bridge_reference":2,"white_elm_watchhouse":3,"homeward_01":2,"homeward_02":3,"homeward_03":4}.get(session.logic.content.id,0)
func next_chapter_label():
    if session and session.logic.content.id=="homeward_02" and "ch02_after_watchhouse" not in presentation.seen:return "旅店后屋"
    return {2:"第二章",3:"第三章",4:"第四章 · 驿站"}.get(next_chapter_number(),"")
func next_chapter_ready():
    return next_chapter_number()!=0 and session.logic.outcome=="victory" and next_story().is_empty()
func enter_next_chapter():
    if not next_chapter_ready():last_error="请先完成当前章节胜利剧情。";return false
    if session.online:last_error="网络房间内容固定。请双方退出后选择"+next_chapter_label()+"创建/加入新房间。";return false
    var number=next_chapter_number()
    if session.logic.content.id=="homeward_02" and "ch02_after_watchhouse" not in presentation.seen:
        var saved=save_chapter_checkpoint()
        if not saved.is_empty():last_error=saved;return false
        get_tree().call_deferred("change_scene_to_file","res://story/interlude.tscn");return true
    var homeward=session.logic.content.id.begins_with("homeward_")
    var error=complete_homeward_checkpoint(session.logic.content.id+"_finish") if homeward else save_chapter_checkpoint()
    if not error.is_empty():last_error=error;return false
    if homeward:
        if number==4:
            get_tree().call_deferred("change_scene_to_file","res://story/interlude.tscn")
            return true
        var identity=presentation.get("campaign_instance","")
        var started=new_game(preload("res://story/library.gd").content(number),session.logic.campaign_state())
        if started and not identity.is_empty():presentation.campaign_instance=identity
        return started
    return new_game(Content.chapter_two_content() if number==2 else Content.chapter_three_content(),session.logic.campaign_state())
func start_room(host,port,secret,data={},campaign={}):
    last_error=startup_error()
    if not last_error.is_empty():return false
    if data.is_empty() and not OS.get_environment("AMBER_MOD").is_empty():
        var loaded=Content.from_file(OS.get_environment("AMBER_MOD"))
        if not loaded.error.is_empty():last_error=loaded.error;return false
        data=loaded.data
    if not new_game(data,campaign):return false
    room_port=port;room_token=secret;connection_age=0.0
    if host:
        server_authority=Authority.new(session.logic.content,session.logic.campaign_state());server=ClassDB.instantiate("AmberTransport")
        if not server.start(true,port,secret):last_error=server.last_error();close_room();return false
    if not session.connect_local(port,secret):last_error=session.status;close_room();return false
    return true
func dirty():
    return _inspector().dirty()
func save_path(slot):
    return _inspector().save_path(slot)
func is_chapter_checkpoint(slot):
    return _inspector().is_chapter_checkpoint(slot)
func checkpoint_id(rules_hash,content_hash,snapshot,local_story,content_id=""):
    return _inspector().checkpoint_id(rules_hash, content_hash, snapshot, local_story, content_id)
func loadable_slots():
    return _inspector().loadable_slots()
func save_chapter_checkpoint():
    return _writer().save_chapter_checkpoint()
func save_slot(slot):
    return _writer().save_slot(slot)
func _write_save(slot):
    return _writer()._write_save(slot)
func _persist_save_data(slot,data):
    return _writer()._persist_save_data(slot, data)
func complete_homeward_checkpoint(id,interlude=0):
    # Offline copy-on-write: publish the completed session only after durable save.
    # Never roll back or replace a distributed authority.
    if not session or session.online or not next_chapter_ready():return "仅离线已完成章节可以建立章节检查点。"
    var candidate=Session.new();candidate.offline(session.logic.content)
    if not candidate.logic.restore(session.logic.snapshot()):return "无法准备章节检查点。"
    candidate.authority.checkpoint=candidate.logic.snapshot()
    if not homeward_event_done(id) and not candidate.submit({"kind":"finish_story","event_id":id}):return "章节完成命令未获确认。"
    var local_story=presentation.duplicate(true)
    if interlude==4:local_story.interlude_completed=4
    var r=candidate.logic
    var slot=checkpoint_id(r.rules_hash,r.content_hash,r.snapshot(),local_story,r.content.id)
    if FileAccess.file_exists(save_path(slot)):
        var existing=inspect_slot(slot)
        if not existing.error.is_empty():return existing.error
    else:
        var data={"format":3,"rules_hash":r.rules_hash,"content_hash":r.content_hash,"content":r.content,"snapshot":r.snapshot(),"hash":r.state_hash(),"presentation":local_story,"saved_at":Time.get_datetime_string_from_system(false,true)}
        var error=_persist_save_data(slot,data)
        if not error.is_empty():return error
    session=candidate;presentation=local_story
    saved_snapshot=r.snapshot();saved_presentation=JSON.stringify(presentation)
    return ""
func inspect_slot(slot):
    return _inspector().inspect_slot(slot)
func valid_presentation(p,logic):
    return _inspector().valid_presentation(p, logic)
func load_slot(slot):
    var result=inspect_slot(slot)
    if not result.error.is_empty():last_error=result.error;return false
    var data=result.data
    var replacement=Session.new();replacement.offline(data.content)
    if not replacement.logic.restore(result.migrated_snapshot):last_error="快照恢复失败。";return false
    replacement.authority.checkpoint=replacement.logic.snapshot();replacement.authority.history.clear()
    homeward_player.scene_id=""
    close_room();session=replacement;presentation=data.presentation.duplicate(true)
    if not presentation.has("campaign_instance"):presentation.campaign_instance=Crypto.new().generate_random_bytes(16).hex_encode()
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
func legacy_next_story():
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
func legacy_advance_story(skip=false):
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

# In-memory hooks used by fallback/asset QA; no settings UI or persistence.
func set_mara_sequence_preview(on):
    mara_sequence_preview=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("mara")

func map_sequence_enabled(id):
    if id=="tessa":return tessa_motion_preview
    if idle_sequence_previews.has(id):return idle_sequence_previews[id]
    if id=="bram":return bram_sequence_preview
    if id=="oren":return oren_sequence_preview
    return mara_sequence_preview if id=="mara" else (finn_motion_preview if id=="finn" else false)
func set_finn_motion_preview(on):
    finn_motion_preview=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("finn")

func set_oren_sequence_preview(on):
    oren_sequence_preview=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("oren")

func set_bram_sequence_preview(on):
    bram_sequence_preview=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("bram")

func set_idle_sequence_preview(on,id):
    if not idle_sequence_previews.has(id):return
    idle_sequence_previews[id]=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art(id)

func set_tessa_motion_preview(on):
    tessa_motion_preview=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("tessa")

func set_neri_motion_preview(on):
    neri_motion_preview=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("neri")

func set_adela_motion_preview(on):
    adela_motion_preview=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("adela")

func set_hero_map_refresh_preview(on,id):
    if not hero_map_refresh_previews.has(id):return
    hero_map_refresh_previews[id]=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art(id)

func set_rodd_motion_preview(on):
    rodd_motion_preview=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_map_sequence_art"):game.refresh_map_sequence_art("rodd")

func set_elsbet_motion_preview(on):
    elsbet_motion_preview=bool(on)
    var game=get_tree().current_scene
    if game and game.has_method("refresh_elsbet_motion_art"):game.refresh_elsbet_motion_art()

# Homeward cues are local presentation; battle flags/outcome remain authoritative.
var homeward_player=preload("res://story/player.gd").new()
func next_story():
    var line=legacy_next_story()
    if line.is_empty() or not session.logic.content.id.begins_with("homeward_"):return line
    if line.id=="ch02_after_watchhouse":return {}
    var data=preload("res://story/library.gd").scene(line.id)
    if data.is_empty():return line
    if homeward_player.scene_id!=line.id or presentation.get("cue",{}).get("scene","")!=line.id:
        homeward_player.start(data)
        if presentation.get("cue",{}).get("scene","")==line.id:homeward_player.restore(data,presentation.cue)
        else:
            var count=0
            while not homeward_player.current().is_empty() and count<line.index-1:
                if homeward_player.current().op=="say":count+=1
                homeward_player.revealed=true;homeward_player.advance()
    presentation.cue=homeward_player.save()
    var c=homeward_player.current()
    if c.is_empty():complete_story();presentation.erase("cue");return legacy_next_story()
    return {"id":line.id,"speaker":c.get("speaker","narrator"),"text":c.get("text",""),"index":homeward_player.index+1,"total":data.cues.size()}
func advance_story(skip=false):
    var line=next_story()
    if line.is_empty():return
    if not session.logic.content.id.begins_with("homeward_") or preload("res://story/library.gd").scene(line.id).is_empty():legacy_advance_story(skip);return
    if skip:homeward_player.skip()
    else:
        var c=homeward_player.current()
        # Text is immediately readable in this first slice; no mandatory typewriter delay.
        homeward_player.revealed=true;homeward_player.advance()
        if c.get("op")=="say":presentation.line+=1
    presentation.cue=homeward_player.save()
    if homeward_player.current().is_empty():complete_story();presentation.erase("cue")
func tick_homeward_story(delta):
    if not session or not session.logic.content.id.begins_with("homeward_"):return
    var scene=get_tree().current_scene
    if not scene or not scene.get("hud") or is_instance_valid(scene.hud.modal) or scene.presentation_active():return
    next_story()
    homeward_player.tick(int(delta*1000))
    if presentation.has("cue"):presentation.cue=homeward_player.save()
    scene.hud.refresh_story()

func homeward_event_done(id):
    if not session:return false
    for i in range(session.logic.content.story.events.size()):
        if session.logic.content.story.events[i].id==id:return (session.logic.story_flags & (1<<i))!=0
    return false
func finish_homeward_event(id):
    if homeward_event_done(id):return true
    return session.submit({"kind":"finish_story","event_id":id})
