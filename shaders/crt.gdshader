// CRT post-process — tüm ekranı kaplar, arkasındakini örnekler (screen texture).
// Hafif kavis (barrel) + tarama çizgileri + renk kayması (aberration) + vinyet.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float curvature : hint_range(0.0, 0.2) = 0.05;
uniform float aberration : hint_range(0.0, 4.0) = 1.4;
uniform float scan_strength : hint_range(0.0, 0.4) = 0.16;
uniform float vignette_amt : hint_range(0.0, 0.6) = 0.22;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 cc = uv - 0.5;
	uv += cc * dot(cc, cc) * curvature;  // hafif tüp ekran kavisi

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float a = aberration * SCREEN_PIXEL_SIZE.x;
		vec3 col;
		col.r = texture(screen_tex, uv + vec2(a, 0.0)).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - vec2(a, 0.0)).b;

		// tarama çizgileri (TV hissi — biraz daha kalın, ~3px periyot, yine hafif)
		float s = 0.5 + 0.5 * sin(FRAGCOORD.y * 2.1);
		col *= 1.0 - scan_strength * (1.0 - s);

		// vinyet
		float vig = smoothstep(0.85, 0.25, length(cc));
		col *= mix(1.0, vig, vignette_amt);

		COLOR = vec4(col, 1.0);
	}
}
