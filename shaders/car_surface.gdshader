shader_type spatial;
render_mode cull_disabled;

instance uniform float wheel_angle = 0.0;

void vertex() {
	if (CUSTOM0.w > 0.5) {
		// Axles point along local X. Apply the same rotation to geometry and
		// normals so the spokes, highlights and shadows all turn together.
		float c = cos(wheel_angle);
		float s = sin(wheel_angle);
		mat2 roll = mat2(vec2(c, s), vec2(-s, c));
		VERTEX.yz = CUSTOM0.yz + roll * (VERTEX.yz - CUSTOM0.yz);
		NORMAL.yz = roll * NORMAL.yz;
	}
}

// Vertex alpha tags opaque materials; none of the car needs transparency.
// Paint=1, glass=.75, rubber/snow=.5, metal=.25, lamps=0.
void fragment() {
	float glass = 1.0 - step(0.05, abs(COLOR.a - 0.75));
	float matte = 1.0 - step(0.05, abs(COLOR.a - 0.5));
	float metal = 1.0 - step(0.05, abs(COLOR.a - 0.25));
	ALBEDO = COLOR.rgb;
	ROUGHNESS = mix(mix(0.46, 0.18, glass), 0.94, matte);
	ROUGHNESS = mix(ROUGHNESS, 0.28, metal);
	METALLIC = metal * 0.65;
	SPECULAR = mix(0.35, 0.65, glass);
	EMISSION = COLOR.rgb * (1.0 - step(0.05, COLOR.a)) * 2.5;
}
