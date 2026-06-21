// Çip/çarpan kutusu ALEV TACI — PİKSEL (Balatro tarzı). Kutu üst kenarına BİRLEŞİK,
// SÜREKLİ durur (kaybolmaz). Tabandan köklenir, pikselli diller yukarı yükselir.
shader_type canvas_item;

uniform vec4 flame_color : source_color = vec4(0.25, 0.56, 0.80, 1.0); // taban = kutu rengi (dikişsiz)
uniform float speed : hint_range(0.0, 12.0) = 7.0;  // daha hızlı animasyon (kullanıcı)
uniform float cols = 14.0;   // yatay piksel sayısı
uniform float rows = 9.0;    // dikey piksel sayısı (taç yükseldi)
uniform float intensity : hint_range(0.0, 1.0) = 0.4;  // ÇİP/ÇARPAN DEĞERİ → alev boyu (0=küçük, 1=büyük)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
	// UV'yi piksel ızgarasına KİLİTLE
	vec2 cell = vec2(1.0 / cols, 1.0 / rows);
	vec2 q = (floor(UV / cell) + 0.5) * cell;
	float x = q.x;
	float h = 1.0 - q.y;                  // tabandan yükseklik (0 alt = kutu üstü)
	float t = TIME * speed * 0.4;

	// YUKARI AKAN DALGA (rastgele titreme değil — düzgün sinüs dalgası, kullanıcı "alev dalgası gibi")
	float wave = 0.5 + 0.26 * sin(x * 9.0 - t * 2.0) + 0.18 * sin(x * 15.0 + t * 2.6 + 1.3);

	// kenar şekillendirme (köşelere uzamasın) — ama TABAN sabit (sondaki/dip pikseller hep durur)
	float cx = abs(x - 0.5) * 2.0;
	float center = 1.0 - smoothstep(0.55, 1.12, cx);
	// reach TAMAMEN intensity ile çarpılır → intensity 0 iken ALEV YOK (düşük değerde hiç alev).
	float shape = clamp(0.35 + wave * 0.7 * center, 0.0, 1.0);
	float reach = intensity * shape;

	float on = step(h, reach);            // hücre alevin içinde mi (keskin piksel)

	// renk: tabanda kutu rengi (dikişsiz), tepeye doğru daha açık/sıcak
	vec3 base = flame_color.rgb;
	vec3 tip = clamp(base * 1.4 + vec3(0.2), 0.0, 1.0);
	float frac = clamp(h / max(reach, 0.001), 0.0, 1.0);
	vec3 col = mix(base, tip, frac * frac);

	COLOR = vec4(col, on * flame_color.a);
}
