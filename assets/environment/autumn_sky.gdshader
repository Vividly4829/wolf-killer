shader_type sky;
render_mode use_half_res_pass;
uniform float daylight = 0.0;
uniform bool blood_moon = false;
float cloud_brush(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void sky() {
	float height = max(EYEDIR.y, 0.0);
	vec3 horizon = vec3(.51, .46, .51);
	vec3 zenith = vec3(.18, .205, .30);
	vec3 autumn = mix(horizon, zenith, smoothstep(0.0, .85, height));
	autumn = mix(autumn,mix(vec3(.74,.81,.84),vec3(.20,.43,.65),height),daylight);
	if(blood_moon) autumn = mix(vec3(.39,.095,.09),vec3(.075,.035,.08),height);
	vec2 uv = EYEDIR.xz / max(.15, EYEDIR.y + .24);
	float wash = cloud_brush(uv * .68);
	float broad = floor(wash * 5.0) / 5.0;
	float clouds = smoothstep(.28, .7, broad);
	autumn = mix(autumn, vec3(.45, .415, .49), clouds * .40);
	float moon_angle = dot(normalize(vec3(-.50, .40, -.77)), EYEDIR);
	float moon_halo = pow(max(moon_angle, 0.0), 90.0);
	float moon_disk = smoothstep(.9964, .9970, moon_angle);
	if(!blood_moon && daylight < .1) {
		float shadow = smoothstep(.9965,.9970,dot(normalize(vec3(-.468,.410,-.77)),EYEDIR));
		moon_disk *= 1.0-shadow;
	}
	COLOR = mix(autumn + vec3(.14, .13, .18) * moon_halo, vec3(.93, .91, .80), moon_disk);
	if(blood_moon) COLOR = mix(COLOR,vec3(1.0,.48,.29),moon_disk);
}
