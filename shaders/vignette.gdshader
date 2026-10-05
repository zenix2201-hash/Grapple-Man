// Screen-edge flash used for damage (red), healing (green) and parries (white).
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float intensity = 0.0;

void fragment() {
	float v = smoothstep(0.25, 0.75, length(UV - vec2(0.5)) * 1.25);
	COLOR = vec4(tint.rgb, clamp(v * intensity, 0.0, 1.0));
}
