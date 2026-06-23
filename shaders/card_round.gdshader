// Bir TextureRect'in (kart görseli) köşelerini YUVARLAR — kare pixel-art art'ın köşeleri
// yuvarlak karta uysun diye. radius texture-pikseli cinsinden (kaynak çözünürlükten bağımsız his).
shader_type canvas_item;

uniform float radius_px = 20.0;  // köşe yarıçapı (texture pikseli)

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;     // texture boyutu (px)
	vec2 p = UV * size;
	vec2 q = min(p, size - p);                 // en yakın kenara uzaklık (px)
	vec2 c = max(vec2(radius_px) - q, vec2(0.0));
	float dist = length(c) - radius_px;        // rounded-rect SDF (köşede)
	float aa = clamp(0.5 - dist, 0.0, 1.0);    // ~1px yumuşatma
	vec4 col = texture(TEXTURE, UV);
	col.a *= aa;
	COLOR = col;
}
