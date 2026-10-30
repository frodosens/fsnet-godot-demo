extends RefCounted
# Story panel: objective text, the current dialogue line and advancing it.
# It owns no nodes; every label lives on the HUD it is given.

const ContentPicker=preload("res://ui/content_picker.gd")

var hud


func _init(owner) -> void:
    hud = owner

func objective_text(goal):
    match goal.kind:
        "defeat_all":return "目标 · 击退所有敌人"
        "all_allies":return "目标 · 所有友方失去战力"
        "reach":
            if hud.game.battle.content.id=="mill_receipts":return "目标 · 到接洽点 (8,1)"
            return "目标 · 玛拉送信至门前 (8,1)" if hud.game.battle.content.id=="white_elm_watchhouse" else "目标 · %s到达 (%d,%d)"%[goal.unit,goal.x,goal.y]
        "survive":return "目标 · 坚持到第 %d 回合"%goal.round
        "protect":return "条件 · %s失去战力"%goal.unit
        "all","any":
            var parts=[]
            for child in goal.children:parts.append(objective_text(child).trim_prefix("目标 · "))
            return ("全部：" if goal.kind=="all" else "任一：")+"；".join(parts)
    return "目标条件"

func refresh_story():
    if not hud.root.has_node("HomewardBubbles"):
        var bubbles=preload("res://story/head_bubbles.gd").new();bubbles.name="HomewardBubbles";bubbles.game=hud.game;hud.root.add_child(bubbles)
    var line=App.next_story()
    hud.story_panel.visible=not line.is_empty() and not is_instance_valid(hud.modal) and not hud.game.presentation_active()
    # z_index only changes drawing: the later hud.dock otherwise steals story clicks.
    # Synchronize here as dialogue/hud.modal transitions need not call full hud.refresh().
    if hud.dock:
        hud.dock.visible=not hud.story_panel.visible and (not is_instance_valid(hud.modal) or hud.modal is ContentPicker)
        hud.dock.refresh_dock()
        hud.turn_button.disabled=not hud.dock.visible or is_instance_valid(hud.modal) or hud.game.battle.outcome!="playing"
    hud.chapter_button.text="前往"+App.next_chapter_label()
    hud.chapter_button.visible=not hud.story_panel.visible and not is_instance_valid(hud.modal) and App.next_chapter_ready()
    if line.is_empty():hud.story_key="";return
    var key=line.id+":"+str(line.index)
    if key==hud.story_key:return
    hud.story_key=key;hud.story_name.text=App.speaker_name(line.speaker);hud.story_text.text=line.text;hud.story_count.text="%d / %d · 剧情仅控制本地阅读，联机对局不会因此暂停。"%[line.index,line.total] if hud.game.session.online else "%d / %d"%[line.index,line.total]
    hud.portrait.texture=null
    var path=preload("res://view/reserve_art.gd").portrait_path(line.speaker)
    if ResourceLoader.exists(path):
        hud.portrait.texture=load(path)
    hud.portrait_initial.visible=hud.portrait.texture==null
    hud.portrait_initial.text="信" if line.speaker=="narrator" else App.speaker_name(line.speaker).left(1)

func advance(skip):
    App.advance_story(skip);refresh_story()
