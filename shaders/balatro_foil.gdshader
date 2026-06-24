// Balatro tarzı HOLOGRAFİK FOIL — akışkan yağ-tabakası gökkuşağı + parlak metalik ışık bantları.
// Kart sanatının ÜSTÜNE yarı saydam overlay (ColorRect, FULL_RECT) → kart görünür kalır, üstünde foil oynar.
// Köşeler rounded-rect SDF ile yumuşatılır (kart formuna uyar, köşede taşma yok).
// Yalnız ÖZEL kartlarda (nadir / efsanevi) kullanılır; şiddet uniform'la tier'a göre ayarlanır.
shader_type canvas_item;
render_mode blend_mix;

uniform float intensity = 1.0;      // genel şiddet (tier'a göre dışarıdan)
uniform float speed = 1.0;          // akış hızı
uniform float radius_px = 18.0;     // köşe yuvarlama yarıçapı
uniform vec2 rect_px = vec2(160.0, 218.0);  // kartın piksel boyutu (köşe SDF için)

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// Akışkan foil koordinatı — çok frekanslı dalga distorsiyonu (yağ tabakası / sıvı metal hissi)
	float flow = uv.x * 0.55 + uv.y * 0.45;
	flow += 0.12 * sin(uv.y * 9.0 + t * 0.9);
	flow += 0.09 * sin(uv.x * 11.0 - t * 0.7);
	flow += 0.06 * sin((uv.x + uv.y) * 16.0 + t * 1.6);

	// Gökkuşağı bantları (yavaş kayar) — yağ-tabakası rengi
	vec3 rainbow = hue(fract(flow * 1.6 + t * 0.08));

	// Parlak metalik ışık bantları (keskin highlight, çapraz kayar — "foil parıltısı")
	float s1 = pow(0.5 + 0.5 * sin((flow - t * 0.35) * 22.0), 10.0);
	float s2 = pow(0.5 + 0.5 * sin((flow + t * 0.22) * 14.0 + 1.7), 6.0);
	float streak = clamp(s1 + 0.5 * s2, 0.0, 1.0);

	vec3 col = mix(rainbow * 0.85, vec3(1.0), streak * 0.7);

	// Saydamlık: gökkuşağı hafif sürekli + ışık bantları belirgin (kart sanatı görünmeye devam eder)
	float a = intensity * (0.20 + 0.62 * streak);

	// Köşe yuvarlama (rounded-rect SDF) → köşelerde foil taşmasın (kartın yuvarlak formuna uy)
	vec2 p = UV * rect_px;
	vec2 cc = min(p, rect_px - p);
	float corner = radius_px - length(max(vec2(radius_px) - cc, vec2(0.0)));
	a *= clamp(corner + 0.5, 0.0, 1.0);

	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
