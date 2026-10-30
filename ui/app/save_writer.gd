extends RefCounted
# Save writing: ordinary slots and content-addressed chapter checkpoints. Atomic
# write (tmp file + rename) lives here; validation stays in save_inspector.

var app


func _init(owner) -> void:
    app = owner

func save_chapter_checkpoint():
    if not app.next_chapter_ready() or app.session.online:return "仅离线已完成章节可以建立章节检查点。"
    var slot=app.checkpoint_id(app.session.logic.rules_hash,app.session.logic.content_hash,app.session.logic.snapshot(),app.presentation)
    if FileAccess.file_exists(app.save_path(slot)):
        var existing=app.inspect_slot(slot)
        if not existing.error.is_empty():return "已有章节检查点校验失败，未覆盖文件："+existing.error
        return ""
    return _write_save(slot)

func save_slot(slot):
    if slot not in app.SLOT_IDS:return "无效存档槽。"
    return _write_save(slot)
# Callers select either an ordinary user slot or a content-addressed chapter checkpoint.

func _write_save(slot):
    if not app.session:return "当前没有战斗。"
    if app.session.online:return "本版网络对局不支持本地存档；房间状态由主机维护。"
    if slot not in app.SLOT_IDS:
        if not app.is_chapter_checkpoint(slot) or not app.next_chapter_ready() or slot!=app.checkpoint_id(app.session.logic.rules_hash,app.session.logic.content_hash,app.session.logic.snapshot(),app.presentation):return "无效章节检查点。"
        if FileAccess.file_exists(app.save_path(slot)):return "章节检查点已存在，不允许覆盖。"
    var data={"format":3,"rules_hash":app.session.logic.rules_hash,"content_hash":app.session.logic.content_hash,
        "content":app.session.logic.content,"snapshot":app.session.logic.snapshot(),"hash":app.session.logic.state_hash(),
        "presentation":app.presentation.duplicate(true),"saved_at":Time.get_datetime_string_from_system(false,true)}
    var error=_persist_save_data(slot,data)
    if error.is_empty():app.saved_snapshot=app.session.logic.snapshot();app.saved_presentation=JSON.stringify(app.presentation)
    return error

func _persist_save_data(slot,data):
    DirAccess.make_dir_recursive_absolute(app.save_root)
    var path=app.save_path(slot);var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
    if not file:return "无法写入存档，原存档未改变。"
    file.store_string(JSON.stringify(data,"",true));file.flush();var write_error=file.get_error();file.close()
    if write_error!=OK:
        DirAccess.remove_absolute(path+".tmp")
        return "存档写入未完成，原存档未改变。"
    if DirAccess.rename_absolute(path+".tmp",path)!=OK:return "无法完成存档替换，原存档未改变。"
    return ""
