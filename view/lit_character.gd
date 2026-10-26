extends Sprite3D
# One shaded material with texture-colored emission; never changes source pixels.
var actor_material:StandardMaterial3D
func _ready():
    process_priority=90
    layers=2 # Dedicated character lighting layer; original world lights include it.
    actor_material=StandardMaterial3D.new()
    actor_material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
    actor_material.billboard_keep_scale=true
    actor_material.cull_mode=BaseMaterial3D.CULL_DISABLED
    actor_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    actor_material.alpha_scissor_threshold=0.5
    actor_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
    actor_material.vertex_color_use_as_albedo=true
    actor_material.diffuse_mode=BaseMaterial3D.DIFFUSE_LAMBERT_WRAP # Broad response for flat sprite cards, no invented normal map.
    actor_material.roughness=1.0;actor_material.metallic_specular=0.0
    actor_material.emission_enabled=true
    actor_material.emission=Color.WHITE
    actor_material.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY
    material_override=actor_material
    sync_material()
func sync_material():
    if not actor_material:return
    if actor_material.albedo_texture!=texture:
        actor_material.albedo_texture=texture;actor_material.emission_texture=texture
    actor_material.emission_energy_multiplier=clampf(App.character_emission,0.0,0.6)
func _process(_delta):sync_material()
