class_name CommandGate
extends RefCounted
# One place for "is a command allowed right now, and how is it sent".
#
# main.gd used to repeat the same step/hash/context checks in confirm_move,
# confirm_proposal and the _process poll, and kept its own queue for a command
# that arrives while a poll is in flight. Both now live here; the host is passed
# in untyped on purpose so this file never depends on the scene script.

var host


func _init(owner) -> void:
    host = owner


func state() -> String:
    return host.battle.content_hash+":"+host.battle.rules_hash+":"+host.battle.state_hash()


func blocked() -> bool:
    var s=host.session
    return s.command_pending or s.failed or (s.online and not s.ready) or host.presentation_active() or host.hud.blocks_input()


func locked() -> bool:
    return blocked() or not host.queued_confirmation.is_empty()


func context_matches(proposal) -> bool:
    return host.selected==proposal.unit and host.mode==proposal.mode and host.battle.step==proposal.step \
        and host.session.get_instance_id()==proposal.session_id \
        and host.session.connection_generation==proposal.connection


func is_stale(proposal) -> bool:
    return blocked() or not context_matches(proposal) or state()!=proposal.state


func dispatch(proposal,command) -> bool:
    # Poll and command share one transport slot. Never overlap sends or blindly retry.
    if host.session.pending:
        host.queued_confirmation={"proposal":proposal,"command":command}
        host.session.defer_poll=true
        host.hud.refresh()
        return true
    var accepted=host.session.submit(command)
    host.battle=host.session.logic
    host.hud.action_menu_open=true
    host.refresh()
    return accepted


func flush() -> void:
    if host.queued_confirmation.is_empty():return
    var proposal=host.queued_confirmation.proposal
    if is_stale(proposal):
        host.clear_move_preview()
        return
    if host.session.pending:return
    var command=host.queued_confirmation.command
    host.queued_confirmation={}
    host.session.defer_poll=false # Consume once, even when submission is rejected.
    host.session.submit(command)
    host.battle=host.session.logic
    host.hud.action_menu_open=true
    host.refresh()
