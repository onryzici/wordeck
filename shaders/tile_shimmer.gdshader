// Geliştirilmiş (foil/holo/cam…) harf taşı için ÇAPRAZ kayan PARILTI (specular sweep).
// Glow halo DEĞİL — taşın üzerinden geçen hareketli bir ışık bandı (Balatro foil hissi).
// Bir ColorRect'e tak; tint = enhancement rengi. Pixel-art için ızgaraya snap + Nearest filter.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 0.55;     // sweep hızı
uniform float band_w = 0.14;    // ışık bandı genişliği
uniform float strength = 0.42;  // en yüksek opaklık
uniform float cells = 34.0;     // pixel ızgara

void fragment() {
	vec2 uv = (floor(UV * cells) + 0.5) / cells;   // pixelate
	float diag = uv.x * 0.7 + uv.y * 0.3;          // çapraz eksen
	float t = fract(TIME * speed);
	float d = abs(fract(diag - t + 0.5) - 0.5);    // banda uzaklık (0 merkez .. 0.5)
	float band = smoothstep(band_w, 0.0, d);       // merkezde 1, kenarda 0
	// İkinci, daha zayıf yansıma (foil çoklu parıltı hissi)
	float t2 = fract(TIME * speed + 0.5);
	float d2 = abs(fract(diag - t2 + 0.5) - 0.5);
	band += 0.4 * smoothstep(band_w * 0.6, 0.0, d2);
	COLOR = vec4(tint.rgb, clamp(band, 0.0, 1.0) * strength);
}
