// Kara delik geçişi — ekran içeriği merkeze doğru AKAR (gravitasyonel çekim, ekran
// dolu kalır; siyah çerçeve YOK), merkezden büyüyen kara delik her şeyi yutar.
// progress 0 = normal, 1 = tamamen yutulmuş (siyah). Çok hafif spiral.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 0.5625;   // 1080/1920; script güncelleyebilir (daire olsun diye)
uniform float swirl = 1.6;        // ÇOK HAFİF spiral (kara delik, baş döndüren girdap değil)
uniform float pull = 2.4;         // merkeze çekim gücü (içerik içe akar)

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	c.x /= max(aspect, 0.001);    // en-boy düzelt → daire
	float r = length(c);
	float ang = atan(c.y, c.x);
	float a = progress;

	// HAFİF SPİRAL: merkeze yakın azıcık daha çok döner
	ang += a * swirl * (1.0 - smoothstep(0.0, 0.95, r));

	// ÇEKİM: örnek yarıçapı dışarı kaydır → dış içerik merkeze AKAR (ekran dolu kalır,
	// kenarlar sabit r=1 → siyah çerçeve oluşmaz). pow ile yumuşak çekim.
	float e = 1.0 / (1.0 + a * pull);
	float nr = pow(clamp(r, 0.0, 1.0), e);

	vec2 cc = vec2(cos(ang), sin(ang)) * nr;
	cc.x *= max(aspect, 0.001);
	vec2 suv = clamp(cc + 0.5, vec2(0.0), vec2(1.0));
	vec3 col = texture(screen_tex, suv).rgb;

	// KARA DELİK: merkezden büyüyen karanlık disk her şeyi yutar
	float hole = smoothstep(0.0, 1.0, a) * 1.6;
	float dark = smoothstep(hole, hole - 0.35, r);   // r < hole → karanlık
	col *= 1.0 - dark;

	COLOR = vec4(col, 1.0);
}
