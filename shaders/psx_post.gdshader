// Full-screen PS1 filter: low resolution, reduced colour depth and ordered dithering.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 3.0;
uniform float color_depth = 32.0;
uniform float dither_strength = 0.5;

void fragment() {
	float px = max(pixel_size, 1.0);
	vec2 cell = floor(FRAGCOORD.xy / px);
	vec2 uv = (cell * px + px * 0.5) * SCREEN_PIXEL_SIZE;
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;

	float bayer[16] = {
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0
	};
	int bx = int(mod(cell.x, 4.0));
	int by = int(mod(cell.y, 4.0));
	float d = (bayer[by * 4 + bx] / 16.0 - 0.5) / color_depth * dither_strength;
	c = floor((c + d) * color_depth + 0.5) / color_depth;
	COLOR = vec4(c, 1.0);
}
