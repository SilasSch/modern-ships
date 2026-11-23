shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Soft cylinder for the railgun round: streak (bright head, fading tail) or ionised path.
// UV.y runs 0 (tail/muzzle) -> 1 (head).

uniform vec3 color : source_color = vec3(1.0);
uniform float intensity = 1.0;
uniform float opacity = 1.0;
uniform float power = 1.0;
uniform float tail_fade = 1.0;  // 1 = streak (fades toward the tail), 0 = uniform path

void fragment() {
	float f = abs(dot(NORMAL, VIEW));
	float a = pow(f, power) * opacity;
	float streak = pow(UV.y, 2.0) * (1.0 - smoothstep(0.97, 1.0, UV.y));
	float path = smoothstep(0.0, 0.02, UV.y) * (1.0 - smoothstep(0.96, 1.0, UV.y));
	a *= mix(path, streak, tail_fade);
	ALBEDO = color * intensity * a;
	ALPHA = a;
}
