extends RefCounted
# Co-op clients share all controller=player factions. No client owns the enemy
# faction in the current Session protocol. An explicit viewer faction can be
# supplied by a future observer/client adapter without changing combat rules.
static func actor_on_left(event,units,local_faction=""):
    var identities={};var owned={}
    for unit in units:
        identities[unit.id]=unit
        if unit.get("controller", "player" if unit.get("ally",false) else "ai")=="player":
            owned[unit.get("faction", "allies" if unit.get("ally",false) else "enemies")]=true
    if not local_faction.is_empty():owned={local_faction:true}
    if not identities.has(event.actor) or not identities.has(event.target):return true # Legacy identity-less presentation callers.
    var actor=identities[event.actor];var target=identities[event.target]
    var af=actor.get("faction","allies" if actor.get("ally",false) else "enemies")
    var tf=target.get("faction","allies" if target.get("ally",false) else "enemies")
    if owned.has(af)!=owned.has(tf):return owned.has(af)
    # Same-side interactions or spectators: stable faction/id order, including
    # reversed events. Neither participant pretends to be the local player.
    return str(af)+":"+str(actor.id)<str(tf)+":"+str(target.id)
