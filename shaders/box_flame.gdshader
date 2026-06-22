// Çip/çarpan kutusu ÜSTÜ — PUAN ALIRKEN beliren BLOBLU pixel alev tacı (image-5 tarzı).
// Kutunun hemen üstündeki bir crown ColorRect'e takılır. Tabandan (kutu üst kenarı) köklenir,
// yumru yumru alçak alev; boyu `intensity` ile büyür (0 = ALEV YOK → normalde kutu sade).
// PİKSELLİ (UV ızgaraya snap) + KESKİN kenar (step/discard, smoothstep YOK). Renk kutuya göre.
shader_type canvas_item;

uniform vec4 flame_color : source_color = vec4(0.25, 0.56, 0.80, 1.0); // taban = kutu rengi (dikişsiz)
uniform float intensity : hint_range(0.0, 1.0) = 0.0;  // PUAN değeri → alev boyu (0 = alev yok)
uniform float cells_x = 28.0;   // yatay piksel sayısı (küçük = iri/retro)
uniform float cells_y = 12.0;   // dikey piksel sayısı
uniform float speed : hint_range(0.0, 8.0) = 2.4;  // alev oynaması hızı

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	if (intensity < 0.01) {
		discard;  // puan yokken alev YOK (kutu sade kalır)
	}
	// pixel ızgarasına KİLİTLE
	vec2 cell = vec2(1.0 / cells_x, 1.0 / cells_y);
	vec2 uv = (floor(UV / cell) + 0.5) * cell;
	float x = uv.x;
	float h = 1.0 - uv.y;        // 0 = taban (kutu üstü), 1 = taç tepe
	float t = TIME * speed;

	// alçak, yumru yumru blob yüzey (sin katmanları + noise + ara sıra sivri tepe)
	float blob = 0.45
		+ 0.20 * sin(x * 6.2831 * 1.3 + t * 1.4)
		+ 0.12 * sin(x * 6.2831 * 2.7 - t * 1.9)
		+ 0.30 * (vnoise(vec2(x * 4.0, t * 0.7)) - 0.5);
	float spike = vnoise(vec2(x * 8.0 + 3.0, t * 0.5));
	blob += 0.35 * pow(spike, 4.0);
	// yatay merkez yanlılığı (kenarlar alçalır)
	float cx = abs(x - 0.5) * 2.0;
	blob *= 1.0 - smoothstep(0.45, 1.08, cx);
	float surf = clamp(intensity, 0.0, 1.0) * blob;

	float inside = step(h, surf);  // gövde — KESKİN

	// birkaç KOPUK pixel (yüzeyin hemen üstünde, seyrek; "uçuşan noktalar")
	float stray = step(0.92, vnoise(vec2(x * 9.0 + t * 1.3, floor(t * 3.0) * 1.7)));
	float strayband = step(h, surf + 0.24) * step(surf + 0.03, h);
	inside = max(inside, stray * strayband * step(0.35, intensity));

	if (inside < 0.5) {
		discard;
	}
	// renk: taban kutu rengi (dikişsiz) → tepe daha açık/sıcak
	float fh = clamp(h / max(surf, 0.001), 0.0, 1.0);
	vec3 base = flame_color.rgb;
	vec3 tip = clamp(base * 1.35 + vec3(0.25), 0.0, 1.0);
	COLOR = vec4(mix(base, tip, fh * fh), flame_color.a);
}
