shader_type spatial;
render_mode cull_disabled;
varying vec3 at;

void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(at.z * 1.6 + TIME * 4.0) * 0.012;
}

void fragment() {
	float ripple = sin(at.z * 3.5 + TIME * 5.0 + sin(at.x * 5.0));
	float foam = pow(max(0.0, sin(at.z * 2.3 + at.x * 8.0 + TIME * 4.5)), 22.0);
	ALBEDO = mix(vec3(0.055, 0.085, 0.027), vec3(0.14, 0.18, 0.055), ripple * 0.25 + 0.35);
	ALBEDO += vec3(0.06, 0.07, 0.025) * foam;
	ROUGHNESS = 0.65;
	SPECULAR = 0.15;
}
