// Kart YANMA — burn-edge dissolve (temel: godotshaders.com/shader/2d-dissolve-with-burn-edge).
// İyileştirmeler: düz renk yerine ATEŞ GRADYANI (beyaz-sıcak → turuncu → kömür) +
// kenardan içe doğru yanma biası. dissolve_value 1.0 (sağlam) → 0.0 (tamamen kül).
shader_type canvas_item;

uniform sampler2D dissolve_texture : source_color, repeat_enable;
uniform float dissolve_value : hint_range(0, 1) = 1.0;
uniform float burn_size : hint_range(0.0, 1.0, 0.01) = 0.13;
uniform float edge_bias : hint_range(0.0, 1.0, 0.01) = 0.28; // kenarlar önce yansın
// Ateş gradyanı durakları
uniform vec4 fire_hot : source_color = vec4(1.0, 0.97, 0.72, 1.0);  // beyaz-sıcak çekirdek
uniform vec4 fire_mid : source_color = vec4(1.0, 0.42, 0.08, 1.0);  // turuncu
uniform vec4 fire_char : source_color = vec4(0.06, 0.03, 0.02, 1.0); // kömür

void fragment() {
	vec4 main_texture = texture(TEXTURE, UV);
	float noise = texture(dissolve_texture, UV).x;

	// kenardan içe bias: merkez 0 → köşe ~1; kenarda gürültü yükselir → önce orada yanar
	float ed = clamp(length(UV - vec2(0.5)) * 1.42, 0.0, 1.0);
	float n = clamp(noise * (1.0 - edge_bias) + ed * edge_bias, 0.0, 1.0);

	float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);
	float threshold = smoothstep(n - burn_size_step, n, dissolve_value);
	float border = smoothstep(n, n + burn_size_step, dissolve_value);

	// yanan bant (border: 0 = tam cephe/en sıcak, 1 = sağlam kart):
	// beyaz-sıcak → turuncu → kömür → kart
	vec3 edge = mix(fire_hot.rgb, fire_mid.rgb, smoothstep(0.0, 0.45, border));
	edge = mix(edge, fire_char.rgb, smoothstep(0.5, 0.92, border));
	vec3 rgb = mix(edge, main_texture.rgb, border);

	COLOR = vec4(rgb, main_texture.a * threshold);
}
