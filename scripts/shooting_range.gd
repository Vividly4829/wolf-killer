extends Node3D
var world: Node3D
var firing_point := Vector3.ZERO
var facing_yaw := 0.0
var targets: Array[Node3D] = []
func _ready() -> void:
	var nav = world.nav
	var best := INF
	var chosen := Vector3.FORWARD
	for x in range(-100,-55,5):
		for z in range(-25,31,5):
			var cell: int = nav.at(x,z)
			if cell<0 or not nav.valid(cell) or nav.distances[cell]<0: continue
			var origin: Vector3 = nav.point(cell)
			for angle in 16:
				var direction := Vector3.FORWARD.rotated(Vector3.UP,angle*TAU/16)
				var valid_lane := true
				var uneven := 0.0
				for distance in range(0,26,2):
					var p := origin+direction*distance
					var i: int = nav.at(p.x,p.z)
					if not nav.valid(i): valid_lane = false; break
					p = nav.point(i)
					uneven += absf(p.y-origin.y)
					for house: Dictionary in world.exploration_data.houses:
						if Vector2(p.x-house.center[0],p.z-house.center[1]).length()<13: valid_lane = false
				if valid_lane and uneven<best:
					best = uneven
					firing_point = origin
					chosen = direction
	facing_yaw = atan2(-chosen.x,-chosen.z)
	for distance in [8,16,24]:
		var side := -3.0 if distance==8 else (3.0 if distance==24 else 0.0)
		var p: Vector3 = firing_point+chosen*sqrt(float(distance*distance)-side*side)+chosen.cross(Vector3.UP)*side
		p = nav.point(nav.nearest(p.x,p.z,2))
		var target := preload("res://scripts/range_target.gd").new()
		target.position = p
		target.rotation.y = facing_yaw+PI
		target.distance_label = "%d M"%distance
		add_child(target)
		targets.append(target)
		# A solid timber backstop catches both bullets and travelling arrows.
		var backstop := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.2,2.5,.25)
		backstop.mesh = box
		backstop.position = p+chosen*.35+Vector3.UP*1.25
		backstop.rotation.y = facing_yaw
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("564435")
		backstop.material_override = wood
		add_child(backstop)
		backstop.create_trimesh_collision()
	var sign := Label3D.new()
	sign.text = "SHOOTING RANGE\n8 / 16 / 24 METRES\nFree Play: all weapons, replenished reserves\nQ / WHEEL: cycle   R: reload"
	sign.position = firing_point-chosen.cross(Vector3.UP)*4+chosen*2+Vector3.UP*1.7
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 36
	sign.pixel_size = .002
	add_child(sign)
