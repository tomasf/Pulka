shader_type spatial;
render_mode cull_disabled;

// Shared material for all procedural geometry. Vertex color drives albedo; a
// vertex alpha below 1 marks emissive parts (lit windows, headlights). Normals
// come from the mesh, so curved surfaces shade smoothly and boxes stay crisp.

uniform float emission_strength = 3.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	EMISSION = COLOR.rgb * (1.0 - COLOR.a) * emission_strength;
}
