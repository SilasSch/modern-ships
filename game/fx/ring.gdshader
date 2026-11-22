shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Expanding air shock ring on a quad.

uniform vec3 color : source_color = vec3(1.0);
uniform float intensity = 2.0;
uniform float opacity = 1.0;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(0.72, 0.9, d) * (1.0 - smoothstep(0.9, 1.0, d)) * opacity;
	ALBEDO = color * intensity * a;
	ALPHA = a;
}
