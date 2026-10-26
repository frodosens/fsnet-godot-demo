shader_type canvas_item;
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    // Fragment COLOR already includes the texture sample in Godot 4.
    vec4 source = COLOR;
    COLOR = vec4(mix(source.rgb, vec3(1.0), flash_strength), source.a);
}
