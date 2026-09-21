shader_type spatial;
render_mode cull_disabled, specular_disabled;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float stroke = sin(p.x * .16 + sin(p.y * .12) * 2.0 + TIME * .18);
	float ripple = sin(p.y * .85 + sin(p.x * .23) * 1.4 - TIME * .5);
	vec3 sea_color = mix(vec3(.055, .105, .13), vec3(.105, .18, .205), smoothstep(-.4, .4, stroke));
	ALBEDO = sea_color + vec3(.035, .043, .060) * smoothstep(.6, .85, ripple);
	EMISSION = sea_color * .06;
	ROUGHNESS = .76;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
