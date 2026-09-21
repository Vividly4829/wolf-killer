shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform int season = 2;
varying vec3 crown_position;
void vertex() {
	crown_position = VERTEX;
	vec3 center = MODEL_MATRIX[3].xyz;
	VERTEX.x += sin(TIME * .65 + center.x * .31 + center.z * .21) * .024 * (VERTEX.y + 1.0);
}
void fragment() {
	float brush = .91 + floor((sin(crown_position.x * 6.0 + crown_position.y * 3.0) * .5 + .5) * 3.0) * .04;
	float pigment_value = dot(COLOR.rgb, vec3(.3, .5, .2));
	vec3 autumn_pigment = mix(vec3(pigment_value), COLOR.rgb, .80);
	ALBEDO = mix(autumn_pigment, vec3(.065, .15, .155), .25) * brush * .70;
	if (season < 2) ALBEDO = mix(vec3(.09,.22,.035),vec3(.30,.44,.10),pigment_value)*brush;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = ALBEDO * .025;
	BACKLIGHT = vec3(.10, .06, .015);
}
void light() {
	float band = .36 + .64 * smoothstep(.05, .35, abs(dot(NORMAL, LIGHT)));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band / 3.14159265;
}
