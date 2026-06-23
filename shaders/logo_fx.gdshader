// Ana menü GLYPHIX logosu efekti — hafif BÜKEYLİK (banner kavisi) + yumuşak nefes alan dalga
// warp + ÇOK HAFİF/YAVAŞ yatay motion blur (hayalet/çift YOK). Bir TextureRect'e tak (logo aspect'i
// rect aspect'iyle eşit olmalı; custom shader UV'yi tüm texture'a eşler → stretch_mode'u baypas eder).
shader_type canvas_item;

uniform float bow = 0.05;        // dikey büküm (orta hafif yukarı kavislenir)
uniform float wave_amp = 0.006;  // yumuşak dalga warp genliği
uniform float wave_speed = 0.7;  // dalga hızı (yavaş nefes)
uniform float blur = 0.0032;     // yatay motion blur tabanı — KÜÇÜK (çift gözükmesin)

void fragment() {
	vec2 uv = UV;
	float t = TIME * wave_speed;

	// 1) BÜKEYLİK — banner kavisi: orta yukarı, kenarlar aşağı (UV.x parabolü)
	float cx = uv.x - 0.5;
	uv.y -= bow * (0.25 - cx * cx);

	// 2) yumuşak nefes alan dalga (canlılık)
	uv.y += sin(uv.x * 6.2831 + t) * wave_amp;
	uv.x += cos(uv.y * 4.0 + t * 0.7) * wave_amp * 0.5;

	// 3) MOTION BLUR — YAVAŞ, yumuşak nabız; 7 örnek + küçük yayılım → hayalet/çift YOK
	float vel = 0.5 + 0.5 * sin(TIME * 0.5);   // 0..1 yavaş salınım
	float amt = blur * vel;
	vec4 col = vec4(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 7; i++) {
		float k = float(i) / 6.0 - 0.5;        // -0.5..0.5
		float w = 1.0 - abs(k) * 1.2;          // merkez ağırlıklı (kenarlar zayıf → iz, çift değil)
		col += texture(TEXTURE, uv + vec2(k * amt, 0.0)) * w;
		wsum += w;
	}
	col /= wsum;

	// 4) MATLIK + CRT — arka planla daha güçlü uyum
	vec3 c = col.rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, 0.56);              // ~%44 desatüre (daha mat, cam his azalır)
	c = (c - 0.5) * 0.78 + 0.5;               // kontrastı daha kıs (mat)
	float g = fract(sin(dot(UV * vec2(431.0, 289.0) + TIME * 0.25, vec2(12.9898, 78.233))) * 43758.5453);
	c += (g - 0.5) * 0.075;                    // daha belirgin film grain
	// CRT tarama çizgileri — global CRT'yle AYNI (SCREEN_UV × 220) → hizalı + logoda daha yoğun
	float scan = 0.5 + 0.5 * sin(SCREEN_UV.y * 220.0 * 6.28318);
	c *= 1.0 - 0.09 * (1.0 - scan);
	col.rgb = clamp(c, 0.0, 1.0);

	COLOR = col;
}
