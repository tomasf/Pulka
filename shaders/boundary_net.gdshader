shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float strength = 0.0;
uniform vec3 rider_position;
uniform vec4 net_color : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform vec4 danger_color : source_color = vec4(1.0, 0.16, 0.06, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cells = UV / vec2(0.65, 0.4);
	vec2 edge = abs(fract(cells + 0.5) - 0.5);
	vec2 lines = 1.0 - smoothstep(vec2(0.025), vec2(0.025) + fwidth(cells), edge);
	float posts = abs(fract(UV.x / 4.0 + 0.5) - 0.5) * 4.0;
	float post = 1.0 - smoothstep(0.025, 0.025 + fwidth(UV.x), posts);
	float rope = 1.0 - smoothstep(0.025, 0.025 + fwidth(UV.y), abs(UV.y - 2.88));
	float mesh = max(max(lines.x, lines.y), max(post, rope));
	float ahead = rider_position.z - world_position.z;
	float reach = smoothstep(-18.0, -7.0, ahead) * (1.0 - smoothstep(30.0, 56.0, ahead));
	float bottom = smoothstep(0.0, 0.2, UV.y);
	ALBEDO = mix(net_color.rgb, danger_color.rgb, strength * strength);
	ALPHA = mesh * reach * bottom * strength * 0.65;
	if (ALPHA < 0.005) { discard; }
}
