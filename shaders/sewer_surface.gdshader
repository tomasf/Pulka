shader_type spatial;
render_mode cull_disabled;
varying vec3 at;

void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float stains = sin(at.x * 1.4 + sin(at.z * 0.13) * 2.0) * sin(at.y * 0.7 + at.z * 0.18);
	float streaks = smoothstep(0.1, 0.85, sin(at.x * 3.1 + sin(at.z * 0.48) * 2.0)) * (0.65 + 0.35 * sin(at.y * 0.19));
	float pores = fract(sin(dot(floor(at * 18.0), vec3(12.3, 46.7, 83.1))) * 4375.5);
	vec3 concrete = COLOR.rgb * (0.72 + stains * 0.18 + pores * 0.14);
	ALBEDO = mix(concrete, concrete * vec3(0.36, 0.40, 0.22), streaks * 0.65);
	ROUGHNESS = 0.97;
	SPECULAR = 0.02;
}
