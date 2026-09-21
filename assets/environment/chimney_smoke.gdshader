shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
varying float smoke_age;
varying float smoke_seed;

void vertex() {
	smoke_age = fract(TIME * .075 + INSTANCE_CUSTOM.x);
	smoke_seed = INSTANCE_CUSTOM.y;
	vec3 center = MODEL_MATRIX[3].xyz;
	float rise = smoke_age * 6.8;
	center += vec3(rise * .31 + sin(smoke_age * 7.0 + smoke_seed * 3.0) * .16, rise, rise * .13);
	// Camera-facing mesh cards are supported by the Compatibility renderer.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(center, 1.0));
	VERTEX *= .45 + smoke_age * 2.1;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float edge = .79 + sin(angle * 5.0 + smoke_seed * 5.0) * .08 + sin(angle * 3.0) * .07;
	float shape = 1.0 - smoothstep(edge * .46, edge, length(p));
	float life = smoothstep(0.0, .07, smoke_age) * (1.0 - smoothstep(.65, 1.0, smoke_age));
	ALBEDO = mix(vec3(.18, .225, .255), vec3(.35, .375, .41), smoke_age);
	ALPHA = shape * life * .38;
}
