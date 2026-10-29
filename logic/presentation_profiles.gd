extends RefCounted
# Stable, data-only admission. These are asset profiles, never unit instance IDs.
const HEROES=["mara","finn","neri","oren","tessa","bram","adela","elsbet","rodd","vera"]
const GENERICS=["generic_soldier_01","generic_knight_01","generic_beast_01","generic_caster_01","generic_archer_01","generic_bandit_01"]
const LEGACY={"ch01_bandit_a":"generic_bandit_01","ch01_bandit_b":"generic_bandit_01","ch01_bandit_c":"generic_bandit_01"}
static func allowed(id):return id in HEROES or id in GENERICS
static func resolve(unit):
    if unit.has("presentation_ref"):return unit.presentation_ref if allowed(unit.presentation_ref) else ""
    var id=unit.get("id","")
    return id if allowed(id) else LEGACY.get(id,"")
const MAP_ROLES={"mara":"knight","finn":"archer","neri":"mage","oren":"raider","tessa":"scout","bram":"brute"}
static func map_role(unit):return MAP_ROLES.get(resolve(unit),unit.role) if unit.has("presentation_ref") else unit.role
static var capabilities={}
static func combat(profile):
    if capabilities.has(profile):return capabilities[profile]
    # Authored capability metadata: no instance-name conditions in playback.
    var data={"melee":true,"projectile":"arrow","head_contact":false,"guard_sequence":false,"actor_sequence":false,"idle_side":"right","allowed_actions":[],"head_x":48.0,"head_y":60.5}
    if profile not in HEROES:return {}
    match profile:
        "mara":data.actor_sequence=true;data.head_x=67.0
        "finn":data.melee=false;data.head_x=80.0
        "neri":data.melee=false;data.projectile="magic";data.allowed_actions=["attack","ember","focus_bolt"];data.head_x=96.0
        "oren":data.guard_sequence=true;data.idle_side="left";data.head_x=114.0
        "tessa":data.head_x=80.0
        "bram":data.head_x=98.0
        "adela":data.allowed_actions=["attack"]
        "elsbet":data.allowed_actions=["attack"];data.head_contact=true
        "rodd":data.head_y=64.5
        "vera":data.melee=false;data.head_y=64.5
    data.allowed_actions.make_read_only();data.make_read_only();capabilities[profile]=data
    return data
