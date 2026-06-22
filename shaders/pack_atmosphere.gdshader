// Booster paket açma atmosferi — zarif koyu vinyet + ince CRT tarama çizgileri.
// Renkli kenar parıltısı KALDIRILDI (kullanıcı: çok güzel değildi + glow yok tercihi).
// Tam ekran ColorRect, normal (mix) karışım: kenarları koyulaştırır, merkezi açık bırakır.
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;     // giriş fade'i (tween)
uniform float scan_strength : hint_range(0.0, 0.4) = 0.08; // tarama çizgisi
uniform float vignette : hint_range(0.0, 1.0) = 0.55;      // kenar koyuluğu

void fragment() {
	vec2 uv = UV;
	float d = length(uv - vec2(0.5));

	// vinyet: kenara doğru koyulaşan siyah (merkez berrak kalır)
	float vig = smoothstep(0.28, 0.85, d);

	// ince CRT tarama çizgileri (piksel-hassas)
	float s = 0.5 + 0.5 * sin(FRAGCOORD.y * 2.0);
	float scan = scan_strength * (1.0 - s);

	float a = (vig * vignette + scan) * intensity;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(a, 0.0, 1.0));
}
