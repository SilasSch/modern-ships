shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// Stil B "Sturmnacht" water. Wave sum must match Ocean.wave_height() in ocean.gd.

uniform float u_time = 0.0;
uniform float wave_amp = 1.55;
uniform vec3 deep_color : source_color = vec3(0.024, 0.07, 0.118);
uniform vec3 shallow_color : source_color = vec3(0.11, 0.29, 0.4);
uniform vec3 foam_color : source_color = vec3(0.62, 0.76, 0.84);
uniform vec3 sky_color : source_color = vec3(0.23, 0.33, 0.47);
uniform vec3 beam_color : source_color = vec3(0.3, 0.91, 1.0);
uniform float foam_amount = 1.3;
uniform float ripple_strength = 0.09;

uniform vec4 rings[8];          // x, z, age, strength
uniform vec4 trenches[2];       // from.xz, to.xz
uniform vec2 trench_meta[2];    // age, width
uniform vec3 charge = vec3(0.0); // x, z, amount
uniform vec4 beam_glow_line = vec4(0.0, 0.0, 0.01, 0.0);
uniform float beam_glow = 0.0;

varying vec3 v_world;
varying float v_foam;
varying float v_h;
varying float v_beam_d;

float waves(vec2 p) {
	float h = 0.0;
	h += sin(dot(p, vec2(0.13, 0.05)) + u_time * 1.05) * 0.32;
	h += sin(dot(p, vec2(-0.06, 0.17)) + u_time * 0.85) * 0.24;
	h += sin(dot(p, vec2(0.33, 0.21)) + u_time * 1.7) * 0.08;
	h += sin(dot(p, vec2(-0.29, 0.43)) + u_time * 2.2) * 0.05;
	h += sin(dot(p, vec2(0.61, -0.37)) + u_time * 3.1) * 0.025;
	return h * wave_amp;
}

float sq(float x) { return x * x; }

float seg_d(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(p - a - ab * t);
}

float fx(vec2 p, out float foam) {
	float h = 0.0;
	foam = 0.0;
	for (int i = 0; i < 2; i++) {
		float age = trench_meta[i].x;
		if (age > 30.0) continue;
		float w = max(trench_meta[i].y, 0.5);
		float d = seg_d(p, trenches[i].xy, trenches[i].zw);
		float env = exp(-age * 1.3);
		float wall = 3.0 * w + age * 6.0;
		h -= 1.6 * exp(-d * d / (6.0 * w)) * env;
		h += 0.7 * exp(-sq(d - wall) / 2.5) * env;
		foam += (exp(-d * d / (4.0 * w + age * 8.0)) * 1.2 + exp(-sq(d - wall) / 1.6)) * env;
	}
	for (int i = 0; i < 8; i++) {
		vec4 r = rings[i];
		if (r.z > 30.0 || r.w <= 0.0) continue;
		float di = length(p - r.xy);
		float ri = 3.0 + r.z * 18.0;
		float e = exp(-r.z * 1.3) * r.w;
		h += 0.9 * exp(-sq(di - ri) / 3.0) * e - 1.4 * exp(-di * di / 8.0) * e * exp(-r.z * 2.0);
		foam += (exp(-sq(di - ri) / 3.0) + exp(-di * di / 14.0) * 1.4) * e;
	}
	float c2 = charge.z * charge.z;
	if (c2 > 0.0) {
		float ds = length(p - charge.xy);
		float cr = sin(ds * 1.6 - u_time * 14.0);
		h += c2 * 0.25 * cr * exp(-ds * 0.08);
		foam += c2 * 0.6 * exp(-ds * 0.12) * smoothstep(0.6, 1.0, cr);
	}
	return h;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz;
	float foam;
	float f2;
	float h = waves(p) + fx(p, foam);
	float e = 0.4;
	float hx = waves(p + vec2(e, 0.0)) + fx(p + vec2(e, 0.0), f2);
	float hz = waves(p + vec2(0.0, e)) + fx(p + vec2(0.0, e), f2);
	VERTEX.y += h;
	NORMAL = normalize(vec3(h - hx, e, h - hz));
	v_world = vec3(wp.x, h, wp.z);
	v_foam = foam;
	v_h = h;
	v_beam_d = seg_d(p, beam_glow_line.xy, beam_glow_line.zw);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	// Small ripple normals so moonlight breaks into a glitter path.
	vec2 q = v_world.xz;
	float e = 0.15;
	float r0 = vnoise(q * 0.9 + vec2(u_time * 0.6, u_time * 0.3)) + 0.5 * vnoise(q * 1.7 - vec2(u_time * 0.9, -u_time * 0.5));
	float rx = vnoise((q + vec2(e, 0.0)) * 0.9 + vec2(u_time * 0.6, u_time * 0.3)) + 0.5 * vnoise((q + vec2(e, 0.0)) * 1.7 - vec2(u_time * 0.9, -u_time * 0.5));
	float rz = vnoise((q + vec2(0.0, e)) * 0.9 + vec2(u_time * 0.6, u_time * 0.3)) + 0.5 * vnoise((q + vec2(0.0, e)) * 1.7 - vec2(u_time * 0.9, -u_time * 0.5));
	vec3 ripple_world = vec3(r0 - rx, 0.0, r0 - rz) * (ripple_strength / e);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(ripple_world, 0.0)).xyz);
	float hn = clamp(v_h / (0.75 * max(wave_amp, 0.2)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(deep_color, shallow_color, hn * 0.85);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sky_color, fres * 0.5);
	float nz = vnoise(v_world.xz * 0.65 + u_time * 0.25) * 0.6 + vnoise(v_world.xz * 1.6 - u_time * 0.4) * 0.4;
	float foam = clamp(v_foam * foam_amount, 0.0, 1.6) + smoothstep(0.78, 1.0, hn) * 0.35;
	foam = smoothstep(0.35, 0.75, foam * (0.55 + 0.8 * nz));
	ALBEDO = mix(col, foam_color, foam * 0.9);
	ROUGHNESS = mix(0.2, 0.85, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	float bd = v_beam_d;
	EMISSION = beam_color * beam_glow * (exp(-bd * bd / 8.0) * 2.0 + exp(-bd * 0.08) * 0.2);
}
