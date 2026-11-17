shader_type sky;
render_mode use_debanding;
// Explicit sun uniforms avoid the renderer's shared directional-light sky
// buffer changing between split-screen cameras and refiltering both skies.
uniform vec4 top_color : source_color;
uniform vec4 horizon_color : source_color;
uniform vec4 ground_color : source_color;
uniform vec3 sun_direction;
uniform vec4 sun_color : source_color;
uniform float sun_energy;
uniform float sun_radius_cos = 1.0;
uniform float sun_halo_cos = 0.9396926;

void sky() {
	float elevation = clamp(EYEDIR.y, -1.0, 1.0);
	float horizon = pow(clamp(1.0 - elevation, 0.0, 1.0), 4.0);
	vec3 upper = mix(top_color.rgb, horizon_color.rgb, horizon);
	float alignment = dot(sun_direction, EYEDIR);
	if (alignment > sun_halo_cos) {
		float glow = clamp((alignment - sun_halo_cos) / (sun_radius_cos - sun_halo_cos), 0.0, 1.0);
		upper = mix(upper, sun_color.rgb * sun_energy, pow(glow, 22.78));
	}
	float ground_horizon = pow(clamp(1.0 + elevation, 0.0, 1.0), 30.0);
	vec3 lower = mix(ground_color.rgb, horizon_color.rgb, ground_horizon);
	COLOR = elevation >= 0.0 ? upper : lower;
}
