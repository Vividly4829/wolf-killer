extends Node3D
## Swept physics ray each step prevents a fast bolt tunnelling through an animal.
var game: Node3D
var velocity := Vector3.ZERO
var spec: Dictionary
var distance: float = 0.0
var age: float = 0.0
var review_serial: int = 0
var shooter_peer := 1
var landed := false
var flight := preload("res://scripts/shot_path.gd").new()
var review_tick := 0.0
var fuse_label: Label3D

func launch(owner_game: Node3D, origin: Vector3, direction: Vector3, weapon: Dictionary) -> void:
	game = owner_game
	review_serial = game.shot_review.serial
	spec = weapon.duplicate()
	global_position = origin
	velocity = direction * float(spec.projectile_speed)
	# Fixed bow sight elevation: a level shot crosses the bead's sight line at 20 m.
	# Preserve the original sight direction in the review so the true arc is visible.
	if spec.has("sight_zero") and absf(direction.y)<.95:
		var elevation:=asin(clampf(9.8*float(spec.sight_zero)/velocity.length_squared(),0,.9))*.5
		var up:=(Vector3.UP-direction*direction.y).normalized()
		velocity=(direction*cos(elevation)+up*sin(elevation))*float(spec.projectile_speed)
	flight.begin(origin,direction,spec)
	add_to_group("player_bolts")
	var shaft := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.009
	mesh.bottom_radius = 0.009
	mesh.height = 0.38
	mesh.radial_segments = 8
	shaft.mesh = mesh
	shaft.rotation.x = PI / 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c2a17a")
	shaft.material_override = material
	add_child(shaft)
	for angle in [0.0, PI / 2.0]:
		var vane := MeshInstance3D.new()
		var vane_mesh := BoxMesh.new()
		vane_mesh.size = Vector3(0.075, 0.004, 0.09)
		vane.mesh = vane_mesh
		vane.material_override = material
		vane.position.z = 0.14
		vane.rotation.z = angle
		add_child(vane)
	if spec.get("launcher",false):
		for child in get_children(): child.queue_free()
		var shell:=MeshInstance3D.new(); var round:=SphereMesh.new(); round.radius=.05; round.height=.15
		shell.mesh=round; shell.material_override=material; add_child(shell)
	look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT)
	if str(spec.id) in ["throwing_knife","throwing_axe","hunting_spear","iron_grenade","dynamite"]:
		for child in get_children(): child.queue_free()
		var catalog = preload("res://scripts/weapon_catalog.gd")
		for i in catalog.WEAPONS.size():
			if catalog.WEAPONS[i].id == spec.id:
				var model: Dictionary = preload("res://scripts/weapon_model_builder.gd").new().build(i)
				add_child(model.root)
				break
	if spec.get("explosive",false) and not spec.get("launcher",false):
		fuse_label=Label3D.new(); fuse_label.position.y=.35; fuse_label.font_size=42; fuse_label.pixel_size=.006
		fuse_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; fuse_label.modulate=Color("ffb25b")
		add_child(fuse_label); fuse_label.text="%.1f s"%float(spec.fuse)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or is_queued_for_deletion():
		queue_free()
		return
	if not game.is_playing():
		return
	age += delta
	if spec.get("explosive",false):
		if is_instance_valid(fuse_label): fuse_label.text="%.1f s"%maxf(0,float(spec.fuse)-age)
		if age>=float(spec.fuse): detonate(); return
		if landed: return
	var next := global_position + velocity * delta + Vector3.DOWN * 4.9 * delta * delta
	velocity += Vector3.DOWN * 9.8 * delta
	if game.campaign: velocity += game.campaign.wind*delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 3)
	query.collide_with_areas = true
	if is_instance_valid(game.coop.local_area) and shooter_peer==1: query.exclude = [game.coop.local_area.get_rid()]
	elif game.coop.avatars.has(shooter_peer): query.exclude = [game.coop.avatars[shooter_peer].area.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# Clip the last step at the range limit; never review an overshoot as a hit.
	var remaining := maxf(0,float(spec.range)-distance)
	var step_length := global_position.distance_to(next)
	if step_length>remaining:
		next = global_position.lerp(next,remaining/maxf(step_length,.0001))
		query.to = next
		hit = get_world_3d().direct_space_state.intersect_ray(query)
	var endpoint: Vector3 = hit.position if not hit.is_empty() else next
	distance += global_position.distance_to(endpoint)
	flight.append(endpoint,delta*global_position.distance_to(endpoint)/maxf(step_length,.000001))
	if not hit.is_empty():
		if spec.get("explosive",false):
			global_position=hit.position+hit.normal*.08
			if spec.get("impact_fuse",false): detonate(); return
			landed=true
			game.coop.deliver_path(shooter_peer,review_serial,flight.report("LANDED / FUSE BURNING",false))
			return
		game.coop.deliver_path(shooter_peer,review_serial,flight.report("IMPACT / NO ANIMAL HIT"))
		game.coop.shooter = shooter_peer
		game.resolve_weapon_hit(hit, velocity.normalized(), spec, distance, review_serial)
		game.coop.shooter = 1
		game.coop.projectile_finished(shooter_peer,review_serial)
		queue_free()
		return
	global_position = next
	var direction := velocity.normalized()
	look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT)
	if spec.get("explosive",false) and (distance>=float(spec.range)-.001 or global_position.y<-.25):
		if spec.get("impact_fuse",false): detonate(); return
		landed=true; velocity=Vector3.ZERO
		game.coop.deliver_path(shooter_peer,review_serial,flight.report("LANDED / FUSE BURNING",false))
		return
	if distance >= float(spec.range)-.001 or age > 6.0:
		game.coop.deliver_path(shooter_peer,review_serial,flight.report("MISS / WEAPON RANGE LIMIT" if distance>=float(spec.range)-.001 else "MISS / FLIGHT TIME LIMIT"))
		game.coop.projectile_finished(shooter_peer,review_serial)
		queue_free()
	elif age-review_tick>=.2:
		review_tick = age
		game.coop.deliver_path(shooter_peer,review_serial,flight.report("PROJECTILE IN FLIGHT",false))

func detonate() -> void:
	if is_queued_for_deletion(): return
	set_meta("detonated",true)
	game.coop.deliver_path(shooter_peer,review_serial,flight.report("DETONATED / NO ANIMAL HIT"))
	var radius: float = spec.blast_radius
	game.frighten_wildlife(global_position,radius*10)
	game.coop.explosion_effect(global_position,radius)
	if game.coop.active: game.coop.send_all("explosion_effect",[global_position,radius])
	var targets: Array = game.wolves.duplicate()
	targets.append_array(game.nodes_in_group("wildlife"))
	targets.append_array(game.nodes_in_group("campaign_threats"))
	for animal in targets:
		if not is_instance_valid(animal) or animal.dead: continue
		var center: Vector3 = animal.position+Vector3.UP*.5
		var d := global_position.distance_to(center)
		if d>radius or not blast_visible(center): continue
		var amount: float = float(spec.damage)*(1-d/radius)
		var before: float = animal.health
		animal.set_meta("ruined_meat",true)
		if animal.is_in_group("campaign_threats"): animal.damage(amount,true)
		else: animal.damage(amount)
		var report := {"entry":Vector3.ZERO,"end":Vector3.UP*.4,"organs":[],"zone":"BLAST","species":animal.get("species") if animal.get("species")!=null else "wolf","damage":before-animal.health,"calculated_damage":amount,"base_damage":spec.damage,"range_factor":1-d/radius,"multiplier":1.0,"distance":d,"weapon":spec.name}
		if shooter_peer==1:
			game.shot_review.record(report,review_serial)
		else:
			game.coop.shooter=shooter_peer; game.coop.deliver_report(report,review_serial); game.coop.shooter=1
	var hunters: Array = [game.player]
	hunters.append_array(game.coop.avatars.values())
	for hunter in hunters:
		var center: Vector3=hunter.position+Vector3.UP*.8
		var d:=global_position.distance_to(center)
		if d>radius or not blast_visible(center): continue
		var amount: float=float(spec.damage)*(1-d/radius)
		if hunter==game.player: game.damage_player(amount)
		else:
			game.coop.shooter=0; game.coop.friendly_hit(hunter.peer_id,amount); game.coop.shooter=1
	queue_free()
func blast_visible(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.15,point,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
