extends Node3D
var attacker: Node3D
var game: Node3D
var velocity:=Vector3.ZERO
var life:=0.0
var power:=20.0
var spec: Dictionary={"id":"enemy_arrow"}
func _ready() -> void:
	add_to_group("enemy_bolts")
	var field_id: int=["throwing_knife","throwing_axe","hunting_spear"].find(spec.id)
	if field_id>=0:
		add_child(preload("res://scripts/weapon_model_builder.gd").new().build(18+field_id).root)
		return
	var shaft:=MeshInstance3D.new(); var shape:=CylinderMesh.new()
	shape.top_radius=.008; shape.bottom_radius=.008; shape.height=.55
	shaft.mesh=shape; shaft.rotation.x=PI/2
	var material:=StandardMaterial3D.new(); material.albedo_color=Color("936544")
	shaft.material_override=material; add_child(shaft)
func _physics_process(delta: float) -> void:
	if not is_instance_valid(attacker) or life>5: queue_free(); return
	if not game.is_playing(): return
	life+=delta
	var next:=position+velocity*delta+Vector3.DOWN*4.9*delta*delta
	velocity+=Vector3.DOWN*9.8*delta
	var query:=PhysicsRayQueryParameters3D.create(position,next,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3=hit.position if not hit.is_empty() else next
	# Check the swept path only as far as the first solid wall. Works in solo too.
	var victims: Array=[game.player]+game.coop.avatars.values()+game.wolves
	victims.sort_custom(func(a,b): return a.position.distance_squared_to(position)<b.position.distance_squared_to(position))
	for victim in victims:
		if victim.get("dead")==true: continue
		if game.world.is_safe_position(victim.position): continue
		var chest: Vector3=victim.position+Vector3.UP
		if Geometry3D.get_closest_point_to_segment(chest,position,end).distance_to(chest)<.38:
			var visibility:=PhysicsRayQueryParameters3D.create(position,chest,1)
			if not get_world_3d().direct_space_state.intersect_ray(visibility).is_empty(): continue
			attacker.strike(victim,power); queue_free(); return
	if not hit.is_empty(): queue_free(); return
	position=next
	look_at(position+velocity,Vector3.UP)
