extends RefCounted
# Chapter selection and starting a game: which chapter follows, whether it is
# ready, and assembling the next session. App keeps session/presentation.

var app


func _init(owner) -> void:
    app = owner

func new_game(data={},campaign={}):
    if not data.is_empty():
        var expanded=Content.expand(data)
        if not expanded.error.is_empty():app.last_error=expanded.error;return false
        data=expanded.data
    app.last_error=app.startup_error()
    if not app.last_error.is_empty():return false
    if not campaign is Dictionary or (not campaign.is_empty() and not Runtime.campaign_fits(Content.default_content() if data.is_empty() else data,campaign)):
        app.last_error="成长记录无效，当前对局未改变。";return false
    app.close_room();app.session=Session.new();app.session.offline(data,campaign)
    app.presentation={"seen":[],"active":"","line":0,"campaign_instance":Crypto.new().generate_random_bytes(16).hex_encode()};app.saved_snapshot="";app.saved_presentation="";app.last_error=""
    app.homeward_player.scene_id=""
    return true

func next_chapter_number():
    if app.session==null:return 0
    return {"amber_bridge_reference":2,"white_elm_watchhouse":3,"homeward_01":2,"homeward_02":3,"homeward_03":4}.get(app.session.logic.content.id,0)

func next_chapter_label():
    if app.session and app.session.logic.content.id=="homeward_02" and "ch02_after_watchhouse" not in app.presentation.seen:return "旅店后屋"
    return {2:"第二章",3:"第三章",4:"第四章 · 驿站"}.get(next_chapter_number(),"")

func next_chapter_ready():
    return next_chapter_number()!=0 and app.session.logic.outcome=="victory" and app.next_story().is_empty()

func enter_next_chapter():
    if not next_chapter_ready():app.last_error="请先完成当前章节胜利剧情。";return false
    if app.session.online:app.last_error="网络房间内容固定。请双方退出后选择"+next_chapter_label()+"创建/加入新房间。";return false
    var number=next_chapter_number()
    if app.session.logic.content.id=="homeward_02" and "ch02_after_watchhouse" not in app.presentation.seen:
        var saved=app.save_chapter_checkpoint()
        if not saved.is_empty():app.last_error=saved;return false
        app.get_tree().call_deferred("change_scene_to_file","res://story/interlude.tscn");return true
    var homeward=app.session.logic.content.id.begins_with("homeward_")
    var error=complete_homeward_checkpoint(app.session.logic.content.id+"_finish") if homeward else app.save_chapter_checkpoint()
    if not error.is_empty():app.last_error=error;return false
    if homeward:
        if number==4:
            app.get_tree().call_deferred("change_scene_to_file","res://story/interlude.tscn")
            return true
        var identity=app.presentation.get("campaign_instance","")
        var started=new_game(preload("res://story/library.gd").content(number),app.session.logic.campaign_state())
        if started and not identity.is_empty():app.presentation.campaign_instance=identity
        return started
    return new_game(Content.chapter_two_content() if number==2 else Content.chapter_three_content(),app.session.logic.campaign_state())

func complete_homeward_checkpoint(id,interlude=0):
    # Offline copy-on-write: publish the completed app.session only after durable save.
    # Never roll back or replace a distributed authority.
    if not app.session or app.session.online or not next_chapter_ready():return "仅离线已完成章节可以建立章节检查点。"
    var candidate=Session.new();candidate.offline(app.session.logic.content)
    if not candidate.logic.restore(app.session.logic.snapshot()):return "无法准备章节检查点。"
    candidate.authority.checkpoint=candidate.logic.snapshot()
    if not app.homeward_event_done(id) and not candidate.submit({"kind":"finish_story","event_id":id}):return "章节完成命令未获确认。"
    var local_story=app.presentation.duplicate(true)
    if interlude==4:local_story.interlude_completed=4
    var r=candidate.logic
    var slot=app.checkpoint_id(r.rules_hash,r.content_hash,r.snapshot(),local_story,r.content.id)
    if FileAccess.file_exists(app.save_path(slot)):
        var existing=app.inspect_slot(slot)
        if not existing.error.is_empty():return existing.error
    else:
        var data={"format":3,"rules_hash":r.rules_hash,"content_hash":r.content_hash,"content":r.content,"snapshot":r.snapshot(),"hash":r.state_hash(),"presentation":local_story,"saved_at":Time.get_datetime_string_from_system(false,true)}
        var error=app._persist_save_data(slot,data)
        if not error.is_empty():return error
    app.session=candidate;app.presentation=local_story
    app.saved_snapshot=r.snapshot();app.saved_presentation=JSON.stringify(app.presentation)
    return ""
