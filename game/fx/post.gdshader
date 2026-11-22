shader_type canvas_item;
// Screen post: chromatic aberration, vignette, flash.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float ca = 0.0;
uniform float vignette = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_color = vec3(0.75, 0.95, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c);
	vec2 off = c * ca * (0.4 + d);
	vec3 col = vec3(texture(screen_tex, uv - off).r, texture(screen_tex, uv).g, texture(screen_tex, uv + off).b);
	col += flash_color * flash;
	float v = 1.0 - smoothstep(0.32, 0.95, d) * (0.38 + vignette);
	COLOR = vec4(col * v, 1.0);
}
