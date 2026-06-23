// Joker kartı NADİRLİK foil efekti — tek shader, uniform'larla nadirliğe göre farklı kimlik:
//  common/uncommon : beyaz çapraz parıltı bandı (sheen sweep)
//  rare            : holografik gökkuşağı foil (holo=1 → banda hue verir)
//  legendary       : gökkuşağı foil + tüm-kart polychrome + parıldayan kıvılcımlar
// Bir ColorRect'e tak (kartın üstünde, FULL_RECT). Pixel-art ızgarasına snap (oyun tarzıyla uyumlu).
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 0.55;     // sweep hızı
uniform float band_w = 0.14;    // ışık bandı genişliği
uniform float strength = 0.32;  // band opaklığı
uniform float cells = 28.0;     // pixel ızgara (0 = kapalı)
uniform float holo = 0.0;       // 0..1 banda holografik gökkuşağı tonu (foil)
uniform float rainbow = 0.0;    // 0..1 tüm-kart polychrome titreşim
uniform float sparkle = 0.0;    // 0..1 parıldayan kıvılcımlar
uniform float edge_glow = 0.0;  // 0..1 nabız atan kenar (rim) parıltısı — tint renginde (premium his)

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	if (cells > 0.5) uv = (floor(UV * cells) + 0.5) / cells;  // pixelate
	float diag = uv.x * 0.7 + uv.y * 0.3;

	// Çapraz kayan parıltı bandı (iki yansıma = foil çokluğu)
	float t = fract(TIME * speed);
	float d = abs(fract(diag - t + 0.5) - 0.5);
	float band = smoothstep(band_w, 0.0, d);
	float t2 = fract(TIME * speed + 0.5);
	float d2 = abs(fract(diag - t2 + 0.5) - 0.5);
	band += 0.4 * smoothstep(band_w * 0.6, 0.0, d2);
	band = clamp(band, 0.0, 1.0);

	// Band rengi: beyaz sheen → holografik gökkuşağı (holo ile karışır)
	vec3 bandcol = mix(tint.rgb, hue(fract(diag * 1.5 + TIME * 0.15)), holo);

	// Tüm-kart polychrome titreşim (legendary)
	float poly = rainbow * (0.5 + 0.5 * sin((uv.x + uv.y) * 8.0 + TIME * 1.3));
	vec3 polycol = hue(fract((uv.x * 0.5 + uv.y * 0.5) + TIME * 0.1));

	// Kıvılcımlar (legendary) — rastgele hücrelerde parıldayan noktalar
	float spk = 0.0;
	if (sparkle > 0.01) {
		vec2 g = floor(UV * 7.0);
		float rnd = hash(g);
		float tw = 0.5 + 0.5 * sin(TIME * 3.0 + rnd * 30.0);
		spk = sparkle * step(0.93, rnd) * pow(tw, 6.0);
	}

	// Nabız atan kenar (rim) parıltısı — tint renginde, kenara yakın yoğun (premium çerçeve hissi)
	float rim = 0.0;
	if (edge_glow > 0.01) {
		float e = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		float pulse = 0.55 + 0.45 * sin(TIME * 2.2);
		rim = edge_glow * smoothstep(0.17, 0.0, e) * pulse;
	}

	float a = band * strength + poly * 0.5 + spk + rim * 0.7;
	vec3 col = bandcol;
	col = mix(col, polycol, clamp(poly, 0.0, 1.0));
	col = mix(col, tint.rgb, clamp(rim, 0.0, 1.0));  // kenar parıltısı tint (legendary = altın) tonunda
	col = mix(col, vec3(1.0), spk);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
