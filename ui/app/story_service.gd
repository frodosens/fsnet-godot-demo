extends RefCounted
# Story reading: which event/line is current, advancing it, and the playable
# scene cues for the homeward chapters. App keeps session/presentation/
# homeward_player, so call sites and saves are unchanged.

var app


func _init(owner) -> void:
    app = owner

func speaker_name(id):
    if id=="narrator":return app.session.logic.content.story.chapterTitle
    for person in app.session.logic.content.story.characters:
        if person.id==id:return person.name
    return id

func event_by_id(id):
    for event in app.session.logic.content.story.events:
        if event.id==id:return event
    return {}

func legacy_next_story():
    if not app.session:return {}
    var logic=app.session.logic;var entries=logic.content.story.events
    # Terminal events preempt local mid-battle dialogue without changing shared flags.
    if logic.outcome!="playing":
        var terminal="battle_terminal_"+logic.outcome
        for event in entries:
            if event.trigger==terminal and event.id not in app.presentation.seen:
                if app.presentation.active!=event.id:app.presentation.active=event.id;app.presentation.line=0
                break
        if app.presentation.active!="" and event_by_id(app.presentation.active).get("trigger")!=terminal:
            app.presentation.active="";app.presentation.line=0
    if app.presentation.active=="":
        for i in range(entries.size()):
            var event=entries[i]
            if logic.outcome!="playing" and event.trigger not in ["battle_terminal_victory","battle_terminal_defeat"]:continue
            if (logic.story_flags & (1<<i))!=0 and event.id not in app.presentation.seen:
                app.presentation.active=event.id;app.presentation.line=0;break
    if app.presentation.active=="":return {}
    var current=event_by_id(app.presentation.active)
    var mid=current.trigger.begins_with("first_player_turn") or current.trigger=="round"
    while app.presentation.line<current.lines.size():
        var line=current.lines[app.presentation.line]
        var unavailable=false
        if mid:
            for u in logic.units:
                if u.id==line.speaker and u.hp<=0:unavailable=true
        if not unavailable:return {"id":current.id,"speaker":line.speaker,"text":line.text,"index":app.presentation.line+1,"total":current.lines.size()}
        app.presentation.line+=1
    complete_story();return next_story()

func complete_story():
    if app.presentation.active!="" and app.presentation.active not in app.presentation.seen:app.presentation.seen.append(app.presentation.active)
    app.presentation.active="";app.presentation.line=0

func legacy_advance_story(skip=false):
    if app.presentation.active=="":return
    if skip:complete_story()
    else:
        app.presentation.line+=1
        if app.presentation.line>=event_by_id(app.presentation.active).lines.size():complete_story()

func next_story():
    var line=legacy_next_story()
    if line.is_empty() or not app.session.logic.content.id.begins_with("homeward_"):return line
    if line.id=="ch02_after_watchhouse":return {}
    var data=preload("res://story/library.gd").scene(line.id)
    if data.is_empty():return line
    if app.homeward_player.scene_id!=line.id or app.presentation.get("cue",{}).get("scene","")!=line.id:
        app.homeward_player.start(data)
        if app.presentation.get("cue",{}).get("scene","")==line.id:app.homeward_player.restore(data,app.presentation.cue)
        else:
            var count=0
            while not app.homeward_player.current().is_empty() and count<line.index-1:
                if app.homeward_player.current().op=="say":count+=1
                app.homeward_player.revealed=true;app.homeward_player.advance()
    app.presentation.cue=app.homeward_player.save()
    var c=app.homeward_player.current()
    if c.is_empty():complete_story();app.presentation.erase("cue");return legacy_next_story()
    return {"id":line.id,"speaker":c.get("speaker","narrator"),"text":c.get("text",""),"index":app.homeward_player.index+1,"total":data.cues.size()}

func advance_story(skip=false):
    var line=next_story()
    if line.is_empty():return
    if not app.session.logic.content.id.begins_with("homeward_") or preload("res://story/library.gd").scene(line.id).is_empty():legacy_advance_story(skip);return
    if skip:app.homeward_player.skip()
    else:
        var c=app.homeward_player.current()
        # Text is immediately readable in this first slice; no mandatory typewriter delay.
        app.homeward_player.revealed=true;app.homeward_player.advance()
        if c.get("op")=="say":app.presentation.line+=1
    app.presentation.cue=app.homeward_player.save()
    if app.homeward_player.current().is_empty():complete_story();app.presentation.erase("cue")

func tick_homeward_story(delta):
    if not app.session or not app.session.logic.content.id.begins_with("homeward_"):return
    var scene=app.get_tree().current_scene
    if not scene or not scene.get("hud") or is_instance_valid(scene.hud.modal) or scene.presentation_active():return
    next_story()
    app.homeward_player.tick(int(delta*1000))
    if app.presentation.has("cue"):app.presentation.cue=app.homeward_player.save()
    scene.hud.refresh_story()

func homeward_event_done(id):
    if not app.session:return false
    for i in range(app.session.logic.content.story.events.size()):
        if app.session.logic.content.story.events[i].id==id:return (app.session.logic.story_flags & (1<<i))!=0
    return false

func finish_homeward_event(id):
    if homeward_event_done(id):return true
    return app.session.submit({"kind":"finish_story","event_id":id})
