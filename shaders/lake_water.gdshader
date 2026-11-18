shader_type spatial;
render_mode cull_disabled;

// Opaque water: the lake bed is genuinely below it, with no screen-copy
// refraction passes. Vertex alpha measures distance from the ice edge.
uniform vec3 deep : source_color = vec3(0.025, 0.14, 0.19);
uniform vec3 shallow : source_color = vec3(0.10, 0.38, 0.43);
uniform vec3 sky_tint : source_color = vec3(0.67, 0.83, 0.94);
varying vec3 world_pos;
varying float depth_weight;

vec3 wave(vec2 p, vec2 direction, float amplitude, float length, float speed) {
	float k = 6.283185 / length;
	float phase = dot(p, normalize(direction)) * k + TIME * speed;
	return vec3(amplitude * sin(phase), amplitude * k * cos(phase) * normalize(direction));
}

vec3 waves(vec2 p) {
	p += vec2(sin(p.y * 0.07 + TIME * 0.11), cos(p.x * 0.08 - TIME * 0.09)) * 2.0;
	vec3 w = wave(p, vec2(1.0, 0.35), 0.028, 8.5, 1.4);
	w += wave(p, vec2(-0.25, 1.0), 0.014, 4.0, 1.9);
	w += wave(p, vec2(0.8, -0.6), 0.004, 1.3, 2.7);
	return w;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth_weight = COLOR.a;
	VERTEX.y += waves(world_pos.xz).x * smoothstep(0.0, 0.35, depth_weight);
}

void fragment() {
	vec3 w = waves(world_pos.xz);
	float amplitude = smoothstep(0.0, 0.35, depth_weight);
	vec3 n = normalize(vec3(-w.y * amplitude, 1.0, -w.z * amplitude));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 0.035 + 0.965 * pow(1.0 - facing, 5.0);
	float shore = 1.0 - smoothstep(0.05, 0.8, depth_weight);
	float wash = 0.72 + 0.28 * sin(world_pos.x * 1.3 + world_pos.z * 0.8 + TIME * 1.7);
	float foam = (1.0 - smoothstep(0.0, 0.15, depth_weight)) * wash;
	ALBEDO = mix(deep, shallow, shore * 0.85);
	ALBEDO = mix(ALBEDO, vec3(0.78, 0.91, 0.94), foam * 0.85);
	ROUGHNESS = mix(0.16, 0.65, foam);
	SPECULAR = 0.85;
	// Broad moving glints read as water from a following camera too.
	float crest = smoothstep(0.015, 0.040, w.x) * amplitude;
	EMISSION = sky_tint * (fresnel * 0.22 + crest * 0.012) * (1.0 - foam);
}
