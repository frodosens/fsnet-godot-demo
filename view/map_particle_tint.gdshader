shader_type canvas_item;
render_mode blend_add, unshaded;
// Reuse the authored spark's alpha silhouette; per-particle ramps supply color.
varying vec4 particle_tint;
void vertex() { particle_tint = COLOR; }
void fragment() { COLOR = vec4(particle_tint.rgb, texture(TEXTURE, UV).a * particle_tint.a); }
