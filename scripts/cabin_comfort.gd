extends Node3D
var world: Node3D
var doors: Array[Node3D] = []
var fire: OmniLight3D
var time := 0.0
func _ready() -> void:
	for position in [Vector3(-1.0,3.85,4.207),Vector3(-3.5,3.85,-.64)]:
		var hinge := Node3D.new()
		hinge.position = position+Vector3(-.52,0,.105)
		hinge.rotation.y = .2
		add_child(hinge)
		var wood: StandardMaterial3D = world._solid_material(Color("55392c"))
		var leaf: MeshInstance3D = world._bed_box(hinge,"Automatic timber door",Vector3(1.1,2.06,.07),Vector3(.55,1.03,0),wood)
		leaf.create_trimesh_collision()
		doors.append(hinge)
	# Dress the existing surveyed stove, rather than hiding a new fireplace behind it.
	var window := MeshInstance3D.new()
	var glass := QuadMesh.new()
	glass.size = Vector2(.30,.33)
	window.mesh = glass
	window.position = Vector3(.392,4.38,.983)
	window.rotation.y = .2
	var flame := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded,cull_disabled; void fragment(){vec2 p=UV;float tips=.42+.16*sin(p.x*23.+TIME*5.)+.08*sin(p.x*43.-TIME*8.);float fire=smoothstep(tips-.13,tips+.08,p.y);float logline=step(.85,p.y);vec3 coal=mix(vec3(.03,.012,.005),vec3(1.,.23,.018),fire);ALBEDO=mix(coal,vec3(.10,.033,.008),logline);EMISSION=coal*(1.2+.2*sin(TIME*7.));}"
	flame.shader = shader
	window.material_override = flame
	add_child(window)
	fire = OmniLight3D.new()
	fire.position = Vector3(.39,4.55,1.15)
	fire.light_color = Color("ffa651")
	fire.omni_range = 5
	add_child(fire)
	var linen: StandardMaterial3D = world._solid_material(Color("b59d73"))
	var runner: MeshInstance3D = world._bed_box(self,"Woven table runner",Vector3(.46,.009,1.10),Vector3(-.577,4.457,2.464),linen)
	runner.rotation.y = .2
	var rug: MeshInstance3D = world._bed_box(self,"Wool hearth rug",Vector3(1.15,.012,1.9),Vector3(-1.15,3.86,2.55),world._solid_material(Color("703f35")))
	rug.rotation.y = .2
	add_coffee(Vector3(-.58,4.514,2.464))

func add_coffee(tea: Vector3) -> void:
	var cup := MeshInstance3D.new()
	cup.name = "CoffeeCup%d"%get_child_count()
	var ceramic := CylinderMesh.new()
	ceramic.top_radius = .066
	ceramic.bottom_radius = .045
	ceramic.height = .11
	cup.mesh = ceramic
	cup.position = tea
	cup.material_override = world._solid_material(Color("e4d9bc"))
	add_child(cup)
	var handle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .023
	ring.outer_radius = .039
	handle.mesh = ring
	handle.position = tea+Vector3(.068,0,0)
	handle.rotation.x = PI/2
	handle.material_override = cup.material_override
	add_child(handle)
	var saucer := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = .10
	disk.bottom_radius = .085
	disk.height = .01
	saucer.mesh = disk
	saucer.position = tea+Vector3.DOWN*.054
	saucer.material_override = cup.material_override
	add_child(saucer)
	var drink := MeshInstance3D.new()
	var surface := CylinderMesh.new()
	surface.top_radius = .057
	surface.bottom_radius = .057
	surface.height = .005
	drink.mesh = surface
	drink.position = tea+Vector3.UP*.056
	drink.material_override = world._solid_material(Color("633017"))
	add_child(drink)
	var steam := GPUParticles3D.new()
	steam.name = "CoffeeSteam%d"%get_child_count()
	steam.position = tea+Vector3.UP*.08
	steam.amount = 18
	steam.lifetime = 1.8
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 12
	process.initial_velocity_min = .09
	process.initial_velocity_max = .15
	process.gravity = Vector3(0,.05,0)
	process.scale_min = .012
	process.scale_max = .03
	steam.process_material = process
	var puff := SphereMesh.new()
	puff.radius = 1
	puff.height = 2
	var mist: StandardMaterial3D = world._solid_material(Color(.9,.9,.88,.16))
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = mist
	steam.draw_pass_1 = puff
	add_child(steam)
func _process(delta: float) -> void:
	time += delta
	fire.light_energy = 1.5+sin(time*8)*.15+sin(time*13)*.08
	var game := world.get_parent()
	if not is_instance_valid(game.get("player")): return
	for door in doors:
		var distance: float = game.player.global_position.distance_to(door.global_position)
		var near: bool = distance<.9 or (distance<2.2 and game.player._actual_speed>.1)
		if is_instance_valid(game.get("coop")):
			for hunter in game.coop.avatars.values():
				if hunter.global_position.distance_to(door.global_position)<1.9: near = true
		door.rotation.y = move_toward(door.rotation.y,-1.35 if near else .2,delta*3)
