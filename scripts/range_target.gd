extends Node3D
var dead := false
var hits := 0
var label: Label3D
var distance_label := ""
func _ready() -> void:
	for ring in 5:
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = .7-ring*.13
		mesh.bottom_radius = mesh.top_radius
		mesh.height = .02
		mesh.radial_segments = 48
		disc.mesh = mesh
		disc.rotation.x = PI/2
		disc.position = Vector3(0,1.5,-.025-ring*.012)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("9c3434") if ring==4 else (Color("ede3cc") if ring%2==0 else Color("283539"))
		disc.material_override = material
		add_child(disc)
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.set_meta("wolf",self)
	area.set_meta("hit_zone","target")
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4,1.4,.14)
	collider.shape = box
	collider.position.y = 1.5
	area.add_child(collider)
	add_child(area)
	label = Label3D.new()
	label.text = distance_label
	label.font_size = 40
	label.pixel_size = .008
	label.position = Vector3(0,2.5,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
func receive_ballistic_hit(amount: float,point: Vector3,direction: Vector3,_zone: String,_force: float,_bonus: float = 1) -> Dictionary:
	hits += 1
	var local := to_local(point)
	var radius := Vector2(local.x,local.y-1.5).length()
	var score := clampi(10-int(radius/.07),1,10)
	label.text = distance_label+" / %d hits\nLAST: %d / 10"%[hits,score]
	return {"entry":local,"end":local+direction*.1,"organs":[],"species":"target","zone":"TARGET / %d POINTS"%score,"multiplier":1.0,"damage":amount,"calculated_damage":amount,"fatal":false}

func get_identification() -> String: return "RANGE TARGET / "+distance_label
