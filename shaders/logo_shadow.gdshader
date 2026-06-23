// GLYPHIX logosu için YUMUŞAK gölge — keskin offset kopya DEĞİL: logonun warp'ıyla aynı bükülür,
// sonra alfası disk-blur ile yumuşatılıp koyu silüet olarak basılır. Ana logonun ARKASINA konur.
shader_type canvas_item;

uniform float bow = 0.05;        // ana logoyla AYNI büküm (hizalı kalsın)
uniform float wave_amp = 0.006;
uniform float wave_speed = 0.7;
uniform float softness = 0.014;  // gölge yumuşaklığı (disk yarıçapı, UV)
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 0.42;   // gölge koyuluğu

void fragment() {
	vec2 uv = UV;
	float t = TIME * wave_speed;
	float cx = uv.x - 0.5;
	uv.y -= bow * (0.25 - cx * cx);
	uv.y += sin(uv.x * 6.2831 + t) * wave_amp;
	uv.x += cos(uv.y * 4.0 + t * 0.7) * wave_amp * 0.5;

	// 5×5 disk blur (sadece alfa) → yumuşak gölge silüeti
	float a = 0.0;
	float wsum = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 o = vec2(float(x), float(y)) * (softness * 0.5);
			float w = 1.0 - length(vec2(float(x), float(y))) * 0.28;  // merkez ağırlıklı
			a += texture(TEXTURE, uv + o).a * w;
			wsum += w;
		}
	}
	COLOR = vec4(shadow_color.rgb, (a / wsum) * strength);
}
