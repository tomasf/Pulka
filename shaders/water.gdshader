shader_type spatial;
render_mode cull_disabled;

// Open water: a sum of travelling waves drives both a gentle swell and the
// surface normal, so the sun glints and the sky reflects more at grazing
// angles (Fresnel), the way real water does.

uniform vec3 deep : source_color = vec3(0.02, 0.1, 0.17);
uniform vec3 shallow : source_color = vec3(0.07, 0.27, 0.34);
uniform vec3 sky : source_color = vec3(0.72, 0.84, 0.95);

varying vec3 world_pos;

// Height and slope of one wave travelling along `dir`.
vec3 wave(vec2 p, vec2 dir, float amplitude, float length, float speed) {
	float k = 6.28318 / length;
	float phase = dot(p, dir) * k + TIME * speed;
	return vec3(amplitude * sin(phase), amplitude * k * cos(phase) * dir);
}

vec3 waves(vec2 p) {
	vec3 sum = wave(p, normalize(vec2(1.0, 0.3)), 0.05, 7.0, 1.3);
	sum += wave(p, normalize(vec2(-0.4, 1.0)), 0.04, 4.3, 1.7);
	sum += wave(p, normalize(vec2(0.8, -0.7)), 0.02, 2.1, 2.6);
	sum += wave(p, normalize(vec2(-1.0, -0.2)), 0.012, 1.1, 3.4);
	return sum;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += waves(world_pos.xz).x;
}

void fragment() {
	vec3 w = waves(world_pos.xz);
	vec3 n = normalize(vec3(-w.y, 1.0, -w.z));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - facing, 5.0);
	ALBEDO = mix(deep, shallow, 0.35 + w.x * 3.0);
	EMISSION = sky * fresnel * 0.55;
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
}
