extends SceneTree
const Context=preload("res://ui/combat_context.gd")
func _initialize():
    var units=[{"id":"a","name":"甲","hp":8,"max_hp":10},{"id":"b","name":"乙","hp":0,"max_hp":12}]
    var events=[{"kind":"attack","actor":"a","target":"b","hp":6,"damage":6},
        {"kind":"heal","actor":"b","target":"b","amount":2},
        {"kind":"attack","actor":"b","target":"a","hp":8,"damage":2},
        {"kind":"attack","actor":"a","target":"b","hp":0,"damage":8,"is_critical":true}]
    var before=JSON.stringify([units,events]);var frames=Context.annotate(events,units)
    assert(frames[0].presentation.target_before==12 and frames[0].presentation.target_after==6)
    assert(frames[1].presentation.target_before==6 and frames[1].presentation.target_after==8)
    assert(frames[2].presentation.actor_hp==8 and frames[2].presentation.target_before==10)
    assert(frames[3].presentation.actor_hp==8 and frames[3].presentation.target_after==0)
    assert(JSON.stringify([units,events])==before)
    assert(not Context.annotate([{"kind":"attack","actor":"unknown","target":"b","hp":0,"damage":0}],units)[0].has("presentation"))
    print("COMBAT_CONTEXT checks=6 failures=0");quit()
