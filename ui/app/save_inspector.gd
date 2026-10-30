extends RefCounted
# Save inspection, extracted from App in small steps. Only decoding/validation
# lives here; loading and writing stay on App so a mistake cannot corrupt saves.

var app


func _init(owner) -> void:
    app = owner

func inspect_slot(slot):
    var issue_startup=app.startup_error()
    if not issue_startup.is_empty():return {"error":issue_startup}
    if slot not in app.SLOT_IDS and not app.is_chapter_checkpoint(slot):return {"error":"无效存档槽。"}
    if not FileAccess.file_exists(app.save_path(slot)):return {"error":"无存档","empty":true}
    var file=FileAccess.open(app.save_path(slot),FileAccess.READ)
    if not file or file.get_length()>262144:return {"error":"存档无法读取或大小异常。"}
    var data=Content.normalize(Content.parse_json(file.get_as_text()))
    if not data is Dictionary or data.get("format") not in [2,3]:return {"error":"存档损坏或版本不兼容。"}
    if not Runtime.accepts_saved_rules(data.get("rules_hash")):return {"error":"规则版本不兼容，请保留旧存档。"}
    var issue=Content.validate(data.get("content"))
    if not issue.is_empty() or Content.hash_of(data.content)!=data.get("content_hash"):return {"error":"内容版本校验失败："+issue}
    var candidate=Runtime.new(data.content)
    var legacy=data.format==2 and data.rules_hash!=Runtime.rule_source().sha256_text()
    if not data.get("snapshot") is String:return {"error":"战斗快照格式错误。"}
    if legacy:
        if not Runtime.validate_legacy(data.content,data.snapshot,data.get("hash")) or not candidate.restore(data.snapshot,true):return {"error":"旧战斗快照损坏或校验不符。"}
    elif not candidate.restore(data.snapshot) or candidate.state_hash()!=data.get("hash"):return {"error":"战斗快照损坏或校验不符。"}
    var p=data.get("presentation")
    if not app.valid_presentation(p,candidate):return {"error":"剧情阅读进度损坏。"}
    if app.is_chapter_checkpoint(slot) and (not app.CHAPTER_CHECKPOINTS.has(data.content.id) or candidate.outcome!="victory" or slot!=app.checkpoint_id(data.rules_hash,data.content_hash,data.snapshot,p,data.content.id)):
        return {"error":"章节检查点身份校验失败。"}
    return {"error":"","data":data,"round":candidate.round_number,"step":candidate.step,"title":data.content.title,"saved_at":data.get("saved_at",""),"migrated_snapshot":candidate.snapshot(),"legacy":legacy}

func save_path(slot):return app.save_root+"/"+slot+".json"

func is_chapter_checkpoint(slot):
    if not slot is String:return false
    var prefix=""
    for candidate in app.CHAPTER_CHECKPOINTS.values():
        if slot.begins_with(candidate):prefix=candidate;break
    if prefix.is_empty():return false
    var digest=slot.trim_prefix(prefix)
    if digest.length()!=64:return false
    for c in digest:
        if c not in "0123456789abcdef":return false
    return true

func loadable_slots():
    var result=app.SLOT_IDS.duplicate()
    var checkpoints=[]
    if DirAccess.dir_exists_absolute(app.save_root):
        for file in DirAccess.get_files_at(app.save_root):
            if file.ends_with(".json") and is_chapter_checkpoint(file.trim_suffix(".json")):checkpoints.append(file.trim_suffix(".json"))
    checkpoints.sort();result.append_array(checkpoints)
    return result

func dirty():
    return app.session and (app.session.logic.snapshot()!=app.saved_snapshot or JSON.stringify(app.presentation)!=app.saved_presentation)

func checkpoint_id(rules_hash,content_hash,snapshot,local_story,content_id=""):
    if content_id.is_empty() and app.session!=null:content_id=app.session.logic.content.id
    var prefix=app.CHAPTER_CHECKPOINTS.get(content_id,"")
    if content_id=="homeward_03" and local_story.get("interlude_completed",0)==4:prefix="homeward4_end_"
    if prefix.is_empty():return ""
    return prefix+(rules_hash+content_hash+snapshot+JSON.stringify(local_story,"",true)).sha256_text()

func valid_presentation(p,logic):
    if p is Dictionary and p.has("campaign_instance"):
        if not p.campaign_instance is String or p.campaign_instance.length()!=32 or not p.campaign_instance.is_valid_hex_number():return false
    if not p is Dictionary or not p.get("seen") is Array or p.seen.size()>24 or not p.get("active") is String or not Content.integer(p.get("line"),0,32):return false
    if p.has("interlude_completed"):
        if p.interlude_completed!=4 or logic.content.id!="homeward_03":return false
        var marked=false
        for i in range(logic.content.story.events.size()):
            if logic.content.story.events[i].id=="homeward_04_finish" and (logic.story_flags & (1<<i))!=0:marked=true
        if not marked:return false
    if p.has("cue"):
        var data=preload("res://story/library.gd").scene(p.get("active",""))
        var probe=preload("res://story/player.gd").new()
        if not logic.content.id.begins_with("homeward_") or not probe.restore(data,p.cue):return false
    var known={}
    for event in logic.content.story.events:known[event.id]=event.lines.size()
    for id in p.seen:
        if not known.has(id):return false
    if p.active!="" and (not known.has(p.active) or p.line>=known[p.active] or p.active in p.seen):return false
    return true
