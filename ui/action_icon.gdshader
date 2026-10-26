shader_type canvas_item;
uniform vec4 ink : source_color = vec4(0.94, 0.87, 0.69, 1.0);
void fragment() {
    // Reuse the approved icon silhouette; discard noisy internal shading only.
    vec4 source = texture(TEXTURE, UV);
    float coverage = smoothstep(0.15, 0.9, source.a);
    float light = dot(source.rgb, vec3(0.299, 0.587, 0.114));
    vec3 two_tone = ink.rgb * mix(0.66, 1.0, smoothstep(0.18, 0.78, light));
    COLOR = vec4(two_tone, coverage * ink.a);
}
