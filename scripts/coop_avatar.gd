extends Node3D
var status_label: Label3D
var peer_id := 1
var health := 100.0
var is_crouching := false
var noise := .03
var visibility_factor := 1.0
var mauling := 0
var _actual_speed := 0.0
var area: Area3D
var weapon_index := -1
var muzzle:=Vector3.ZERO
var weapon: Node3D
var character: Node3D
var previous_position:=Vector3.INF
var rendered_speed:=0.0
func equip(index: int) -> void:
	if index==weapon_index or index<0 or index>=preload("res://scripts/weapon_catalog.gd").WEAPONS.size(): return
	weapon_index = index
	if is_instance_valid(weapon): weapon.queue_free()
	var model: Dictionary = preload("res://scripts/weapon_model_builder.gd").new().build(index)
	muzzle=model.muzzle
	weapon = model.root
	weapon.position = Vector3(.16,1.15,-.27)
	add_child(weapon)
func get_visibility() -> float: return visibility_factor
func get_noise_level() -> float: return noise
func _ready() -> void:
	character=preload("res://scripts/field_character.gd").new()
	character.coat_color=Color("52675c") if peer_id%2 else Color("876449")
	add_child(character)
	area = hitbox(self,peer_id)
	var label := Label3D.new(); status_label=label
	label.text = "HUNTER"
	label.font_size = 32
	label.pixel_size = .004
	label.position.y = 2.05
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
static func hitbox(parent: Node3D,id: int) -> Area3D:
	var hit := Area3D.new()
	hit.collision_layer = 2
	hit.collision_mask = 0
	hit.set_meta("hunter_peer",id)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = .9
	hit.add_child(collision)
	parent.add_child(hit)
	return hit

func _process(delta: float) -> void:
	status_label.text="DOWN / REVIVE" if health<=0 else "HUNTER"
	status_label.modulate=Color("ffbb77") if health<=0 else Color.WHITE
	if is_instance_valid(weapon): weapon.visible=health>0
	if not previous_position.is_finite(): previous_position=position
	var moved:=position.distance_to(previous_position)/maxf(delta,.001)
	rendered_speed=lerpf(rendered_speed,minf(10,moved),1-exp(-delta*8))
	previous_position=position
	character.set_motion(rendered_speed,is_crouching,true,mauling!=0)
	character.set_process(health>0)
	character.rotation.z=lerp_angle(character.rotation.z,1.4 if health<=0 else 0,1-exp(-delta*6))

func set_beast(value: bool) -> void:
	if not is_instance_valid(character) or character.beast == value: return
	character.queue_free()
	character=preload("res://scripts/field_character.gd").new(); character.beast=value
	add_child(character)
