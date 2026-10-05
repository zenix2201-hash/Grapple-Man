// PS1-style surface: wobbly snapped vertices, chunky nearest-filtered texture,
// flat lambert lighting. Also handles hit flashes for enemies.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform bool use_texture = false;
// Project the texture from world space so big level blocks don't stretch it.
uniform bool world_uv = true;
uniform float uv_scale = 0.5;
uniform float texture_strength = 0.6;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Lower = more vertex wobble. 0 disables snapping.
uniform float snap_resolution = 140.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount = 0.0;
uniform bool unshaded = false;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (snap_resolution > 0.0 && clip.w > 0.0) {
		vec2 grid = vec2(snap_resolution * VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0), snap_resolution);
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (use_texture) {
		vec2 uv = UV * uv_scale;
		if (world_uv) {
			vec3 n = abs(normalize(world_normal));
			if (n.y >= n.x && n.y >= n.z) {
				uv = world_pos.xz;
			} else if (n.x >= n.z) {
				uv = world_pos.zy;
			} else {
				uv = world_pos.xy;
			}
			uv *= uv_scale;
		}
		vec3 t = texture(albedo_texture, uv).rgb;
		col = mix(col, col * t * 1.5, texture_strength);
	}
	float f = clamp(flash_amount, 0.0, 1.0);
	col = mix(col, flash_color.rgb, f);
	vec3 emit = emission_color.rgb * emission_energy + flash_color.rgb * f * 0.6;
	if (unshaded) {
		ALBEDO = vec3(0.0);
		EMISSION = col + emit;
	} else {
		ALBEDO = col;
		EMISSION = emit;
	}
	ROUGHNESS = 1.0;
}
