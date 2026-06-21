// Akışkan keçe arka plan — "sıvı whirl" (Balatro hissi, kendi palet/dilimiz)
// KEÇE & KEMİK: derin keçe yeşili, üstte lamba ışığı, altta vinyet. NEON YOK.
// Domain-warp fbm ile yavaşça dönen/akan sıvı bantlar.
shader_type canvas_item;

uniform vec3 color_deep : source_color = vec3(0.055, 0.165, 0.133); // #0E2A22
uniform vec3 color_felt : source_color = vec3(0.106, 0.275, 0.227); // #1B463A
uniform vec3 color_high : source_color = vec3(0.180, 0.430, 0.350); // açık keçe vurgu
uniform float speed : hint_range(0.0, 1.0) = 0.18;
uniform float swirl : hint_range(0.0, 6.0) = 3.6;
uniform float warp_scale : hint_range(0.5, 6.0) = 2.2;
uniform float whirl : hint_range(0.0, 3.0) = 1.1; // merkez etrafında dönme
uniform float contrast : hint_range(0.0, 2.0) = 1.15;
uniform float aspect = 0.5625; // 1080/1920; script güncelleyebilir

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
				   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
			   mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
				   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// merkeze göre, en-boy düzeltmeli koordinat
	vec2 p = (UV - 0.5);
	p.x *= 1.0 / max(aspect, 0.001);
	float t = TIME * speed;

	// WHIRL: merkez etrafında yarıçapa+zamana bağlı yavaş dönme (girdap hissi)
	float rad = length(p);
	float ang = whirl * (sin(t * 0.5) * 0.6 + rad * 1.6) + t * 0.25;
	float cs = cos(ang);
	float sn = sin(ang);
	p = mat2(vec2(cs, -sn), vec2(sn, cs)) * p;

	// çift kademeli domain warp = akan/dönen sıvı
	vec2 q = vec2(fbm(p * warp_scale + vec2(0.0, t)),
				  fbm(p * warp_scale + vec2(5.2, 1.3 - t)));
	vec2 r = vec2(fbm(p * warp_scale + swirl * q + vec2(1.7, 9.2) + t * 0.6),
				  fbm(p * warp_scale + swirl * q + vec2(8.3, 2.8) - t * 0.5));
	float f = fbm(p * warp_scale + swirl * r);
	f = clamp((f * 0.55 + 0.5 - 0.5) * contrast + 0.5, 0.0, 1.0);

	vec3 col = mix(color_deep, color_felt, smoothstep(0.1, 0.8, f));
	col = mix(col, color_high, clamp(smoothstep(0.5, 1.0, f) * length(r) * 1.1, 0.0, 1.0));

	// lamba: üstten aydınlık → alta vinyet (KEÇE & KEMİK tek tepe lambası)
	float vig = smoothstep(1.25, 0.15, length((UV - vec2(0.5, 0.32))));
	col *= 0.62 + 0.55 * vig;

	COLOR = vec4(col, 1.0);
}
