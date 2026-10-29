extends RefCounted
const C=preload("res://logic/content.gd")
static func pack(data):
    var result=data.duplicate(true);result.version=2;result.unit_definitions=[];result.units=[]
    for u in data.units:
        var definition=u.duplicate(true)
        for key in ["x","y","ally","controller","faction","policy","leash","escort"]:definition.erase(key)
        definition.id="def_"+u.id
        definition.presentation_ref=u.get("presentation_ref",PresentationProfiles.resolve(u))
        result.unit_definitions.append(definition)
        var instance={"id":u.id,"template_ref":definition.id,"x":u.x,"y":u.y,"ally":u.ally}
        for key in ["controller","faction","policy","leash","escort"]:
            if u.has(key):instance[key]=u[key]
        result.units.append(instance)
    return result
static func twins(profile="generic_bandit_01"):
    var d=C.reference_content();d.story.events=[]
    for i in 2:
        d.units[i]=d.units[0].duplicate(true)
        d.units[i].id="custom_guard_"+str(i);d.units[i].presentation_ref=profile
        d.units[i].x=1+3*i;d.units[i].y=6
    var result=pack(d)
    result.units[1].template_ref=result.units[0].template_ref
    result.unit_definitions.remove_at(1)
    return result
