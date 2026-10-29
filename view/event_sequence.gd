extends Node
# Settled authoritative events are immutable. This queue owns only their visual
# order and temporary map positions/health; commands keep using game.battle.
var game
var last_step=-1
var batches=[]
var events=[]
var current={}
var units=[]
var content={}
var positions={}
var health={}
var facings={}
var trace=[] # Bounded diagnostic history, no shared state.
func active():return not current.is_empty() or not events.is_empty() or not batches.is_empty()
func consume(step,items):
    if step<=last_step:return
    if last_step>=0 and step>last_step+1:finish() # Snapshot catch-up: never invent missing events.
    last_step=step
    batches.append({'step':step,'events':items.duplicate(true),'units':game.battle.units.duplicate(true),'content':game.battle.content})
    if current.is_empty() and events.is_empty():start_batch()
func start_batch():
    if batches.is_empty():
        settle_truth()
        if game.hud:game.hud.action_menu_open=true
        return
    var batch=batches.pop_front();units=batch.units;content=batch.content
    events=preload('res://ui/combat_context.gd').annotate(batch.events,units)
    positions.clear();health.clear();facings=game.facing.duplicate()
    for u in units:positions[u.id]=Vector2i(u.x,u.y);health[u.id]=int(u.hp)
    for i in range(events.size()-1,-1,-1):
        var e=events[i]
        if e.get('kind')=='move' and e.get('path') is Array and not e.path.is_empty():positions[e.actor]=Vector2i(e.path[0].x,e.path[0].y)
        if e.get('kind')=='attack' and health.has(e.get('target')):health[e.target]=int(e.hp)+int(e.damage)
        elif e.get('kind')=='heal' and health.has(e.get('target')):health[e.target]-=int(e.amount)
    for e in events:e['_visual_step']=batch.step
    sync_visuals();play_next()
func visual_units():
    var result=units.duplicate(true)
    for u in result:u.hp=health.get(u.id,u.hp)
    return result
func record(e):
    trace.append({'kind':e.get('kind',''),'actor':e.get('actor',''),'step':e.get('_visual_step',-1)})
    if trace.size()>128:trace.pop_front()
func play_next():
    current={}
    while not events.is_empty():
        current=events.pop_front();record(current)
        match current.get('kind',''):
            'move':
                game.motion.last_step=-1
                game.motion.consume(current._visual_step,[current])
                if game.motion.active():return
            'attack':
                if positions.has(current.actor) and positions.has(current.target):
                    for u in units:
                        if u.id==current.actor:facings[u.id]=game.projected_facing(positions[u.id],positions[current.target],game.iso_roles.has(u.role));game.facing[u.id]=facings[u.id]
                game.cutin.last_seen_step=-1
                game.cutin.consume(current._visual_step,[current],visual_units(),content)
                if game.cutin.active:return
                if game.generic_attack_feedback.start(current):return
            'heal':
                game.heal_feedback.last_step=-1
                game.heal_feedback.consume(current._visual_step,[current])
                if not game.heal_feedback.numbers.is_empty():return
        apply_result()
        current={}
    start_batch()
func apply_result():
    if current.get('kind')=='move' and current.get('path') is Array and not current.path.is_empty():
        var end=current.path[-1];positions[current.actor]=Vector2i(end.x,end.y);facings[current.actor]=game.facing.get(current.actor,"front")
    if current.get('kind')=='attack':health[current.target]=int(current.hp)
    elif current.get('kind')=='heal':health[current.target]=health.get(current.target,0)+int(current.amount)
    sync_visuals()
func motion_finished():
    if current.get('kind')!='move':return
    apply_result();play_next()
func _process(_delta):
    if current.is_empty():return
    var done=false
    match current.get('kind'):
        'move':done=not game.motion.active()
        'attack':done=not game.cutin.active and not game.generic_attack_feedback.active()
        'heal':done=game.heal_feedback.numbers.is_empty()
    if done:apply_result();play_next()
func sync_visuals():
    if not active():return
    for i in range(game.battle.units.size()):
        var u=game.battle.units[i]
        if positions.has(u.id) and not game.motion.motions.has(u.id):
            var point=positions[u.id];game.figures[i].position=Vector3(point.x,game.figure_height(i),point.y)
            game.facing[u.id]=facings.get(u.id,game.facing.get(u.id,"front"))
        var hp=health.get(u.id,u.hp)
        game.figures[i].visible=hp>0;game.badges[i].visible=hp>0
        game.badges[i].position=game.badge_position(i)
        game.badges[i].update_health(hp,u.max_hp,u.ally,i==game.selected)
    if game.selected>=0 and game.selected<game.figures.size():
        var p=game.figures[game.selected].position;game.selection_ring.position=Vector3(p.x,0.04,p.z)
func settle_truth():
    positions.clear();health.clear()
    for i in range(game.battle.units.size()):
        var u=game.battle.units[i]
        game.figures[i].position=Vector3(u.x,game.figure_height(i),u.y)
        game.figures[i].visible=u.hp>0;game.badges[i].visible=u.hp>0
        game.badges[i].position=game.badge_position(i);game.badges[i].update_health(u.hp,u.max_hp,u.ally,i==game.selected)
func finish():
    batches.clear();events.clear();current={}
    if game.motion:game.motion.finish(false)
    if game.cutin:game.cutin.finish()
    if game.heal_feedback:game.heal_feedback.clear()
    if game.generic_attack_feedback:game.generic_attack_feedback.clear()
    settle_truth()
