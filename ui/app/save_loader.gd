extends RefCounted
# Loading a save into a fresh session. Validation is done by save_inspector; this
# file only assembles the session and switches App over to it.

var app


func _init(owner) -> void:
    app = owner

func load_slot(slot):
    var result=app.inspect_slot(slot)
    if not result.error.is_empty():app.last_error=result.error;return false
    var data=result.data
    var replacement=Session.new();replacement.offline(data.content)
    if not replacement.logic.restore(result.migrated_snapshot):app.last_error="快照恢复失败。";return false
    replacement.authority.checkpoint=replacement.logic.snapshot();replacement.authority.history.clear()
    app.homeward_player.scene_id=""
    app.close_room();app.session=replacement;app.presentation=data.presentation.duplicate(true)
    if not app.presentation.has("campaign_instance"):app.presentation.campaign_instance=Crypto.new().generate_random_bytes(16).hex_encode()
    app.saved_snapshot=app.session.logic.snapshot();app.saved_presentation=JSON.stringify(app.presentation);app.last_error=""
    return true
