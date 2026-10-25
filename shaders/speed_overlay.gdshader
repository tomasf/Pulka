shader_type canvas_item;

// Full-screen speed effect: radial blur towards the edges, streaking speed
// lines and a soft vignette, all scaled by `intensity` (0 = off).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.5) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);

float rand(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 focus = vec2(0.5, 0.46);
	vec2 c = uv - focus;
	float r = length(c * vec2(1.6, 1.0));

	float blur = intensity * 0.05 * smoothstep(0.15, 0.85, r);
	vec3 col = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		col += texture(screen_tex, uv - c * blur * float(i) / 8.0).rgb;
	}
	col /= 8.0;

	float angle = atan(c.y, c.x);
	float cells = 90.0;
	float cell = floor((angle / 6.28318 + 0.5) * cells);
	float f = fract((angle / 6.28318 + 0.5) * cells);
	float seed = rand(cell);
	float phase = fract(r * 1.8 - TIME * (2.5 + seed * 2.0) + seed * 7.0);
	float line = smoothstep(0.42, 0.5, f) * smoothstep(0.58, 0.5, f);
	float visible = step(0.55, rand(cell + 13.0));
	float streak = line * visible * smoothstep(0.0, 0.25, phase) * (1.0 - phase);
	streak *= smoothstep(0.25, 0.7, r) * clamp(intensity - 0.25, 0.0, 1.0);
	col = mix(col, vec3(1.0), streak * 0.55);

	float vignette = smoothstep(0.55, 1.15, r) * (0.25 + 0.35 * intensity);
	col *= 1.0 - vignette;
	col = mix(col, flash_color, flash);

	COLOR = vec4(col, 1.0);
}
