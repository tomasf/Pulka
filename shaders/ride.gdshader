shader_type spatial;
render_mode cull_disabled;

// Ride meshes remain a single opaque surface. Vertex alpha encodes finish:
// metal uses .2-.39; plastic and wood .5-1. No emissive parts/transparency.
void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = (1.0 - step(0.4, COLOR.a)) * 0.72;
	ROUGHNESS = COLOR.a < 0.4 ? max(0.32, COLOR.a) : mix(0.23, 0.67, (COLOR.a - 0.4) / 0.6);
	SPECULAR = 0.4;
}
