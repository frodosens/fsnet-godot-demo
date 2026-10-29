extends SceneTree
# Golden regression for the shared rules contract.
#
# The refactor must not change the Lua rules, the canonical snapshot layout or the
# content hash. This test freezes all three: any accidental edit to logic/*.lua,
# logic/rules/*.lua, logic/runtime.gd or content/default.json breaks it loudly.
#
# Regenerate only when a rules/content change is intentional:
#   AMBER_UPDATE_GOLDEN=1 <godot> --headless --path . --script res://tests/test_golden_snapshot.gd
const Runtime=preload("res://logic/runtime.gd")

const RULES_HASH="7dd510122458af062e62933faa6a21a55f618afb20966d5d72676e8b5fb3e341"
const CONTENT_HASH="e3522933bf3137160005d6ba59ae822b2d121cf2bf6037ee6ed461391a1773ed"
const HASH_INITIAL="7b90629e5e06903cbe5817d95b4195aa803314364af5435cd1c1895219efbe54"
const HASH_AFTER_MOVE="65e7f4e76a36f070a1729986e7cfeafac545f0f3ece23cd9f27c555bc26a6abb"
const HASH_AFTER_SKILL="91cba9d385749d799968730b8a55be319b6cab19b0aacea102028c42c09ebe67"
const HASH_AFTER_TURN="cbd87450c7bd84c36e22978231819df4c9796b9349419d47c22cea017671322b"
const SNAPSHOT_AFTER_TURN="6,3,12345,2,0,3,0,6,3,5,12,0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,4,6,8,0,0,1,0,0,0,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,5,6,8,0,0,1,6,0,0,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,3,2,6,0,0,1,0,0,0,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,0,0,1,0,0,0,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,5,3,8,0,0,1,0,0,0,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,2,5,0,4,1,1,0,12345,0,2,7,1,12345,1,6,0,3,2,1,12345,1,7,0,4,8,0,12345,0,0,3,4,102,105,110,110,0,4,109,97,114,97,0,4,110,101,114,105,0,0"

var checks=0
var failures=0

func check(value,label):
    checks+=1
    if not value: failures+=1;printerr("FAIL: ",label)

func _initialize():
    var runtime=Runtime.new()
    var initial=runtime.state_hash()
    var snapshot_initial=runtime.snapshot()
    var after_move=""
    var after_skill=""
    var after_turn=""

    var moved=runtime.apply_command({"step":1,"kind":"move","unit":0,"x":3,"y":5})
    if moved: after_move=runtime.state_hash()
    var skilled=runtime.apply_command({"step":2,"kind":"skill","unit":0,"target":0})
    if skilled: after_skill=runtime.state_hash()
    var turned=runtime.apply_command({"step":3,"kind":"end_turn"})
    if turned: after_turn=runtime.state_hash()
    var final_snapshot=runtime.snapshot()

    if OS.get_environment("AMBER_UPDATE_GOLDEN")=="1":
        print("RULES_HASH=",runtime.rules_hash)
        print("CONTENT_HASH=",runtime.content_hash)
        print("HASH_INITIAL=",initial)
        print("HASH_AFTER_MOVE=",after_move)
        print("HASH_AFTER_SKILL=",after_skill)
        print("HASH_AFTER_TURN=",after_turn)
        print("SNAPSHOT_AFTER_TURN=",final_snapshot)
        print("SNAPSHOT_INITIAL_LENGTH=",snapshot_initial.length())
        quit(0)
        return

    check(moved and skilled and turned,"scripted command sequence is legal")
    check(runtime.rules_hash==RULES_HASH,"rules source hash unchanged")
    check(runtime.content_hash==CONTENT_HASH,"content hash unchanged")
    check(initial==HASH_INITIAL,"initial state hash unchanged")
    check(after_move==HASH_AFTER_MOVE,"hash after move unchanged")
    check(after_skill==HASH_AFTER_SKILL,"hash after knight skill unchanged")
    check(after_turn==HASH_AFTER_TURN,"hash after deterministic enemy turn unchanged")
    check(final_snapshot==SNAPSHOT_AFTER_TURN,"canonical snapshot bytes unchanged")

    # A snapshot restored into a fresh VM must reproduce the same hash and bytes.
    var replica=Runtime.new()
    check(replica.restore(final_snapshot),"golden snapshot restores")
    check(replica.state_hash()==after_turn and replica.snapshot()==final_snapshot,"restore is byte-identical")

    print("GOLDEN_SNAPSHOT checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
