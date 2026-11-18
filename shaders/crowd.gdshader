shader_type spatial;
// Static crowd poses share one surface and one mesh for every outfit.
// Material IDs ride in CUSTOM0; the seven clothing colours stay per instance.
instance uniform vec4 jacket : source_color = vec4(0.9, 0.2, 0.2, 1.0);
instance uniform vec4 jacket_trim : source_color = vec4(0.935, 0.48, 0.48, 1.0);
instance uniform vec4 pants : source_color = vec4(0.12, 0.14, 0.25, 1.0);
instance uniform vec4 trunks : source_color = vec4(0.12, 0.14, 0.25, 1.0);
instance uniform vec4 hat : source_color = vec4(0.2, 0.7, 0.35, 1.0);
instance uniform vec4 hat_cuff : source_color = vec4(0.16, 0.56, 0.28, 1.0);
instance uniform vec4 scarf : source_color = vec4(0.98, 0.75, 0.1, 1.0);
varying vec3 albedo;

void vertex() {
	int part = int(CUSTOM0.x + 0.5);
	albedo = COLOR.rgb;
	if (part == 1) { albedo = jacket.rgb; }
	else if (part == 2) { albedo = jacket_trim.rgb; }
	else if (part == 3) { albedo = pants.rgb; }
	else if (part == 4) { albedo = trunks.rgb; }
	else if (part == 5) { albedo = hat.rgb; }
	else if (part == 6) { albedo = hat_cuff.rgb; }
	else if (part == 7) { albedo = scarf.rgb; }
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 0.85;
	SPECULAR = 0.5;
}
