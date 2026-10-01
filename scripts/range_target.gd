extends Node3D
var dead := false
var hits := 0
var label: Label3D
var distance_label := ""
var rings: Array[MeshInstance3D]=[]
var flash_left:=0.0
var total_score:=0
var best_score:=0
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
		rings.append(disc)
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
func receive_ballistic_hit(amount: float,point: Vector3,direction: Vector3,_zone: String,_force: float,_bonus: float = 1,_penetration: float = .7) -> Dictionary:
	hits += 1
	var local := to_local(point)
	var radius := Vector2(local.x,local.y-1.5).length()
	var score := clampi(10-int(radius/.07),1,10)
	var multiplier:=.25+float(score)*.175
	var damage:=amount*multiplier
	total_score+=score; best_score=maxi(best_score,score); flash_left=1.5
	for i in rings.size():
		var mat: StandardMaterial3D=rings[i].material_override
		mat.emission_enabled=i==clampi(int((.7-radius)/.13),0,4)
		mat.emission=Color("75ff83"); mat.emission_energy_multiplier=2.0
	label.text=distance_label+" / %d hits\n%d / 10 · %.0f DAMAGE\nBEST %d · TOTAL %d"%[hits,score,damage,best_score,total_score]
	return {"entry":local,"end":local+global_basis.inverse()*direction*.1,"organs":[],"species":"target","zone":"RING %d / 10"%score,"multiplier":multiplier,"damage":damage,"calculated_damage":damage,"fatal":false,"score":score}
func _process(delta: float) -> void:
	if flash_left<=0: return
	flash_left-=delta
	if flash_left<=0:
		for ring in rings: ring.material_override.emission_enabled=false

func get_identification() -> String: return "RANGE TARGET / "+distance_label
