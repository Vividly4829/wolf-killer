shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform bool terrain = false;
uniform bool photo_architecture = false;
uniform int season = 2;
uniform vec2 cabin_outline[10];
varying vec3 world_position;
varying vec3 world_normal;

float brush(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

bool indoors(vec2 p) {
	bool inside = false;
	int j = 9;
	for (int i = 0; i < 10; i++) {
		vec2 a = cabin_outline[i];
		vec2 b = cabin_outline[j];
		if ((a.y > p.y) != (b.y > p.y)) {
			if (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
		}
		j = i;
	}
	return inside;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 n = normalize(world_normal);
	vec2 uv = world_position.xz;
	if (abs(n.x) > abs(n.y) && abs(n.x) > abs(n.z)) uv = world_position.zy;
	else if (abs(n.z) > abs(n.y)) uv = world_position.xy;
	float wash = floor(brush(uv * .65) * 4.0) / 4.0;
	float grain = .96 + wash * .07;
	bool grass = base.g > base.r * 1.06 && base.g > base.b * 1.22;
	bool red_paint = base.r > base.g * 1.65 && base.r > base.b * 1.75;
	bool timber = base.r > base.b * 1.38 && base.g > base.b * 1.1 && !grass;
	bool pale = base.r > .63 && base.g > .57 && base.b > .45;
	bool sheltered = indoors(world_position.xz) && world_position.y < 6.35;
	vec3 result;
	if (terrain && grass) {
		float meadow = floor(brush(world_position.xz * .27) * 4.0) / 3.0;
		result = mix(vec3(.19, .225, .085), vec3(.36, .315, .155), meadow);
		float litter = smoothstep(.57, .70, brush(world_position.xz * .62 + vec2(12.0, -4.0)));
		result = mix(result, vec3(.40, .20, .095), litter * .68) * grain;
	} else if (terrain) {
		float earth = smoothstep(.035, .15, base.r - base.b);
		result = mix(vec3(.23, .265, .265), vec3(.30, .245, .155), earth) * (.83 + wash * .27);
	} else if (red_paint) result = vec3(.31, .095, .085) * grain;
	else if (pale) result = vec3(.68, .71, .66) * grain;
	else if (timber) result = vec3(.30, .21, .135) * (.78 + min(base.r * 1.6, .5)) * grain;
	else if (grass) result = mix(vec3(.18, .21, .08), vec3(.39, .255, .11), wash) * grain;
	else {
		float value = dot(base, vec3(.25, .5, .25));
		result = mix(vec3(.075, .125, .16), vec3(.32, .39, .42), clamp(value * 1.8, 0.0, 1.0)) * grain;
	}
	if (sheltered && (timber || red_paint)) result = vec3(.36, .23, .13) * grain;
	if (photo_architecture && COLOR.a < .9) result = base * grain;
	// Cool shadow pigment retains exposed autumn earth and warm cabin timber.
	if (!sheltered) result = mix(result, vec3(.065, .15, .17) * (.75 + dot(result, vec3(.3, .5, .2))), .28);
	if (grass && season < 2 && !(photo_architecture && COLOR.a < .9)) result = mix(vec3(.12,.24,.06),vec3(.32,.42,.12),wash);
	if (season == 3 && !sheltered && n.y > .3) result = mix(result,vec3(.78,.84,.87),smoothstep(.3,.8,n.y)*.92);
	ALBEDO = result;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = sheltered ? vec3(.038, .017, .004) : result * vec3(.055, .11, .12);
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float band = .22 + .42 * smoothstep(-.1, .12, facing) + .36 * smoothstep(.5, .58, facing);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band / 3.14159265;
}
