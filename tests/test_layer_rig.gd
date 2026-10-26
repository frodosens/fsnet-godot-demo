extends SceneTree
const Rig=preload("res://view/mara_layer_rig.gd")
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():
    var hip=Vector2(48,80);var knee=Vector2(40,98);var ankle=Vector2(49,113);var sole=Vector2(51,120)
    var upper=hip.distance_to(knee);var lower=knee.distance_to(ankle)
    for target in [ankle,ankle+Vector2(2,-2),ankle+Vector2(-2,2),Vector2(48,145),hip]:
        var pose=Rig.solve_leg(hip,target,upper,lower,-1)
        check(absf(hip.distance_to(pose.knee)-upper)<0.001,"upper bone never stretched")
        check(absf(pose.knee.distance_to(pose.ankle)-lower)<0.001,"lower bone never stretched")
        if target==Vector2(48,145):check(pose.clamp_error>10,"unreachable request exposed, not hidden by scaling")
    var canvas=Rig.LayerCanvas.new();canvas.solver=Rig.solve_leg
    for side in ["near","far"]:canvas.legs[side]={"hip":hip,"knee":knee,"ankle":ankle,"sole":sole,"upper":upper,"lower":lower,"bend":-1}
    var delta=Vector2(8,-8);var planted=Vector2.ZERO
    for n in range(61):
        var phase=n*0.01
        canvas.pose(phase,delta)
        var boot=canvas.commands.near_boot
        check(boot.rotation==0,"boot does not inherit shin twist")
        if phase<canvas.stance:
            var foot=boot.position+(sole-ankle)+delta*phase
            if n==0:planted=foot
            check(foot.distance_to(planted)<0.001,"support foot remains fixed with moving body")
            check(canvas.max_error<0.001,"fixture target reachable without stretch")
    canvas.pose(0.99999,delta);var before=canvas.commands.near_boot.position
    canvas.pose(0,delta);check(before.distance_to(canvas.commands.near_boot.position)<0.01,"cycle boundary continuous")
    canvas.free()
    print("LAYER_RIG_MATH checks=",checks," failures=",failures," synthetic_joints=true real_art_acceptance=false")
    quit(1 if failures else 0)
