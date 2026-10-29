extends RefCounted
# Reconstruct per-event presentation HP from settled state. Never mutates rules.
static func annotate(events:Array,units:Array)->Array:
    var health={};var identities={}
    for unit in units:
        health[unit.id]=int(unit.hp);identities[unit.id]=unit
    for index in range(events.size()-1,-1,-1):
        var item=events[index];var target=item.get("target","")
        if not health.has(target):continue
        if item.get("kind")=="attack":health[target]=int(item.hp)+int(item.damage)
        elif item.get("kind")=="heal":health[target]-=int(item.amount)
    var result=[]
    for original in events:
        var item=original.duplicate(true)
        var actor=item.get("actor","");var target=item.get("target","")
        if identities.has(actor) and identities.has(target):
            item.presentation={"actor_profile":PresentationProfiles.resolve(identities[actor]),"target_profile":PresentationProfiles.resolve(identities[target]),"actor_name":identities[actor].name,"target_name":identities[target].name,
                "actor_ally":identities[actor].get("ally",false),"target_ally":identities[target].get("ally",false),
                "actor_hp":health[actor],"actor_max_hp":int(identities[actor].max_hp),
                "target_before":health[target],"target_max_hp":int(identities[target].max_hp)}
            if item.get("kind")=="attack":health[target]=int(item.hp)
            elif item.get("kind")=="heal":health[target]+=int(item.amount)
            item.presentation.target_after=health[target]
            item.presentation.actor_after=health[actor]
        result.append(item)
    return result
