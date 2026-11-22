shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Fresnel-soft cylinder for beam core / sheath / outer glow. UV.y runs along the beam.

uniform vec3 color : source_color = vec3(1.0);
uniform float intensity = 1.0;
uniform float opacity = 1.0;
uniform float power = 1.0;

void fragment() {
	float f = abs(dot(NORMAL, VIEW));
	float a = pow(f, power) * opacity;
	a *= smoothstep(0.0, 0.004, UV.y) * smoothstep(0.0, 0.12, 1.0 - UV.y);
	ALBEDO = color * intensity * a;
	ALPHA = a;
}
