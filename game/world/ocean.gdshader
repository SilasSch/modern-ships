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
uniform vec3 trench_meta[2];    // age, width, speed (0 = instant)
uniform vec3 charge = vec3(0.0); // x, z, amount
uniform vec4 beam_glow_line = vec4(0.0, 0.0, 0.01, 0.0);
uniform float beam_glow = 0.0;
uniform bool far_lod = false;     // far ring: big waves only, no effects
uniform float cut_inner = 0.0;    // far ring: discard inside this half-size around cut_center
uniform vec2 cut_center = vec2(0.0);
uniform vec4 wakes[16];           // x, z, heading, speed

varying vec3 v_world;
varying float v_foam;
varying float v_h;
varying float v_beam_d;

float waves(vec2 p, float detail) {
	p += vec2(sin(p.y * 0.013 + u_time * 0.1), sin(p.x * 0.011 - u_time * 0.08)) * 9.0;
	p += vec2(sin(p.y * 0.031 + u_time * 0.2), sin(p.x * 0.027 - u_time * 0.17)) * 2.0;
	float h = 0.0;
	h += sin(dot(p, vec2(0.1052, 0.0322)) + u_time * 1.0) * 0.27;
	h += sin(dot(p, vec2(-0.0661, 0.0535)) + u_time * 0.85) * 0.23;
	h += sin(dot(p, vec2(0.0441, 0.1538)) + u_time * 1.25) * 0.1;
	h += detail * sin(dot(p, vec2(-0.3038, -0.1289)) + u_time * 1.7) * 0.065;
	h += detail * sin(dot(p, vec2(0.2491, -0.3986)) + u_time * 2.2) * 0.035;
	h += detail * sin(dot(p, vec2(-0.2312, -0.6713)) + u_time * 3.1) * 0.02;
	return h * wave_amp;
}

float sq(float x) { return x * x; }

float seg_t(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
}

float seg_d(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(p - a - ab * t);
}

float fx(vec2 p, out float foam) {
	float h = 0.0;
	foam = 0.0;
	if (far_lod) return 0.0;
	for (int i = 0; i < 2; i++) {
		float age = trench_meta[i].x;
		if (age > 30.0) continue;
		float w = max(trench_meta[i].y, 0.5);
		float d = seg_d(p, trenches[i].xy, trenches[i].zw);
		float env = exp(-age * 1.3);
		float spd = trench_meta[i].z;
		if (spd > 0.0) {
			float along = seg_t(p, trenches[i].xy, trenches[i].zw) * length(trenches[i].zw - trenches[i].xy);
			float front = age * spd;
			env *= smoothstep(front + 4.0, front - 10.0, along);
		}
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
	for (int i = 0; i < 16; i++) {
		vec4 w = wakes[i];
		if (abs(w.w) < 0.3) continue;
		vec2 fwd = vec2(-sin(w.z), -cos(w.z));
		vec2 rel = p - w.xy;
		float behind = -dot(rel, fwd);
		if (behind < -6.0) continue;
		float lat = abs(rel.x * fwd.y - rel.y * fwd.x);
		float spd = clamp(abs(w.w) / 14.0, 0.0, 1.0);
		float len = 20.0 + 70.0 * spd;
		float fade = (1.0 - smoothstep(0.0, len, behind)) * spd;
		float arm = 1.6 + max(behind, 0.0) * 0.36;
		foam += exp(-sq(lat - arm) / (0.35 + behind * 0.03)) * fade * step(0.0, behind) * 0.55;
		foam += exp(-sq(lat) / (1.2 + behind * 0.08)) * fade * smoothstep(-6.0, 4.0, behind) * 0.65;
		h -= exp(-sq(lat) / 3.0) * fade * 0.25 * step(0.0, behind);
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
	vec2 oc = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	vec2 dc = abs(p - oc);
	float detail = far_lod ? 0.0 : 1.0 - smoothstep(200.0, 252.0, max(dc.x, dc.y));
	float h = waves(p, detail) + fx(p, foam);
	float e = 0.4;
	float hx = waves(p + vec2(e, 0.0), detail) + fx(p + vec2(e, 0.0), f2);
	float hz = waves(p + vec2(0.0, e), detail) + fx(p + vec2(0.0, e), f2);
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
	if (cut_inner > 0.0) {
		vec2 dc = abs(v_world.xz - cut_center);
		if (max(dc.x, dc.y) < cut_inner) discard;
	}
	// Small ripple normals so moonlight breaks into a glitter path. Rotated domains avoid a visible
	// grid; ripples fade out with view distance (prevents moire at far zoom).
	vec2 q = v_world.xz;
	float view_dist = length(v_world - CAMERA_POSITION_WORLD);
	float rfade = 1.0 - smoothstep(160.0, 380.0, view_dist);
	float e = 0.15;
	mat2 r1 = mat2(vec2(0.866, 0.5), vec2(-0.5, 0.866));
	mat2 r2 = mat2(vec2(0.342, -0.94), vec2(0.94, 0.342));
	vec2 o1 = vec2(u_time * 0.6, u_time * 0.3);
	vec2 o2 = vec2(u_time * 0.9, -u_time * 0.5);
	float r0 = vnoise(r1 * q * 0.9 + o1) + 0.5 * vnoise(r2 * q * 1.7 - o2);
	float rx = vnoise(r1 * (q + vec2(e, 0.0)) * 0.9 + o1) + 0.5 * vnoise(r2 * (q + vec2(e, 0.0)) * 1.7 - o2);
	float rz = vnoise(r1 * (q + vec2(0.0, e)) * 0.9 + o1) + 0.5 * vnoise(r2 * (q + vec2(0.0, e)) * 1.7 - o2);
	vec3 ripple_world = vec3(r0 - rx, 0.0, r0 - rz) * (ripple_strength * rfade / e);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(ripple_world, 0.0)).xyz);
	// Far away, flatten the wave normals so the wave lattice doesn't read as a pattern.
	vec3 up_view = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up_view, smoothstep(140.0, 460.0, view_dist) * 0.75));
	float hn = clamp(v_h / (0.75 * max(wave_amp, 0.2)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(deep_color, shallow_color, hn * 0.85);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sky_color, fres * 0.5);
	float nz = vnoise(v_world.xz * 0.65 + u_time * 0.25) * 0.6 + vnoise(v_world.xz * 1.6 - u_time * 0.4) * 0.4;
	float foam = clamp(v_foam * foam_amount, 0.0, 1.6) + smoothstep(0.78, 1.0, hn) * 0.35;
	foam = smoothstep(0.35, 0.75, foam * (0.55 + 0.8 * nz));
	ALBEDO = mix(col, foam_color, foam * 0.9);
	ROUGHNESS = mix(0.26, 0.85, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	float bd = v_beam_d;
	EMISSION = beam_color * beam_glow * (exp(-bd * bd / 8.0) * 2.0 + exp(-bd * 0.08) * 0.2);
}
