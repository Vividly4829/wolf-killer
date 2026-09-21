extends Node
var world: Node3D
var season := 2
var hour := 23
var blood_moon := false
var revision := 0
const SEASONS := ["SPRING","SUMMER","AUTUMN","WINTER"]
func wake(wave: int) -> void:
	revision += 1
	season = randi_range(0,3)
	hour = randi_range(0,23)
	blood_moon = wave % 5 == 0
	if blood_moon: hour = 0
	apply()
func description() -> String:
	return "%s / %02d:00%s" % [SEASONS[season],hour," / BLOOD MOON" if blood_moon else ""]
func apply() -> void:
	var daylight := clampf(sin((hour-6)*PI/12.0)*1.5,0,1)
	var env: Environment = world.get_node("CoastalAtmosphere").environment
	env.sky.sky_material.set_shader_parameter("daylight",daylight)
	env.sky.sky_material.set_shader_parameter("blood_moon",blood_moon)
	env.ambient_light_color = Color("afcad5") if daylight>.2 else Color("798795")
	env.ambient_light_energy = lerpf(.42,.8,daylight)
	env.fog_light_color = Color("713332") if blood_moon else Color("a2b5ba").lerp(Color("53647c"),1-daylight)
	world.sun.light_color = Color("e89682") if blood_moon else Color("9cbed5").lerp(Color("fff0c9"),daylight)
	world.sun.light_energy = lerpf(.40,1.3,daylight)
	world.sun.rotation_degrees.x = -lerpf(22,65,daylight)
	for batch in world.leaf_batches:
		batch.visible = season != 3
		var mat: ShaderMaterial = batch.multimesh.mesh.surface_get_material(0)
		mat.set_shader_parameter("season",season)
	for node in world.find_children("*","GeometryInstance3D",true,false):
		if node.material_override is ShaderMaterial:
			node.material_override.set_shader_parameter("season",season)
