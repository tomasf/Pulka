shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// Northern lights: a wavy curtain of green fading to violet, with fine vertical
// rays drifting sideways. `strength` fades the whole effect in and out.

uniform float strength = 0.0;
uniform float seed = 0.0;

void vertex() {
	VERTEX.z += sin(VERTEX.x * 0.02 + TIME * 0.25 + seed) * 25.0;
}

void fragment() {
	float x = UV.x * 6.0 + seed;
	float wave = sin(x * 2.0 + TIME * 0.35) * 0.5 + sin(x * 5.3 - TIME * 0.2) * 0.25;
	float bottom = 0.78 + wave * 0.12;
	float band = smoothstep(bottom, bottom - 0.08, UV.y) * smoothstep(0.0, 0.55, UV.y);
	float rays = 0.55 + 0.45 * sin(UV.x * 160.0 + wave * 6.0 + TIME * 0.8);
	vec3 color = mix(vec3(0.1, 1.0, 0.45), vec3(0.55, 0.25, 1.0), smoothstep(0.65, 0.1, UV.y));
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	ALBEDO = color * band * rays * edge * strength * 1.4;
}
