shader_type spatial;
render_mode cull_disabled;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = sin(world_pos.x * 1.7 + sin(world_pos.z * 0.21) * 4.0 + world_pos.y * 0.7);
	float vein = pow(abs(grain), 100.0);
	ALBEDO = mix(COLOR.rgb, vec3(0.36, 0.72, 0.85), vein * 0.12);
	ROUGHNESS = 0.22 + vein * 0.3;
	SPECULAR = 0.75;
	EMISSION = COLOR.rgb * 0.1 + vec3(0.01, 0.045, 0.065) * vein;
}
