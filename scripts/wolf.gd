class_name IslandWolf
extends Node3D

const WOLF_SCENE = preload("res://assets/wolf.glb")
const Profile = preload("res://scripts/wolf_profile.gd")
var profile: Dictionary = {}
var size_scale: float = 1.0
var bite_damage: float = 14.0
var is_alpha: bool = false
var leader_reaction: String = ""
var _leader_caution_until: float = 0.0
var _regroup_goal := Vector3.INF
var _leader_event_seen: int = 0
var _leader_howl_at: float = -1.0
var _voice_pitch_supported: bool = false
var game: Node
var nav: RefCounted
var health: float = 80.0
var reaction: Node
var max_health: float = 80.0
var dead: bool = false
var speed: float = 2.8
var charge_speed: float = 7.3
var model: Node3D
var werewolf := false
var limbs: Node
var prey: Node3D
var prey_timer := 0.0
var hunted_hunter: Node3D

func make_werewolf() -> void:
	if werewolf: return
	werewolf=true
	model.hide()
	model=preload("res://scripts/field_character.gd").new()
	model.beast=true; model.scale=Vector3.ONE*1.45; model.rotation.y=PI
	add_child(model)
	size_scale=1.45
	max_health=maxf(420,max_health*3.5); health=max_health
	bite_damage*=2.0; speed=4.8; charge_speed=11.5
	_boldness=1.0; _aggression=1.0
	for zone in _hit_zones:
		for child in _hit_zones[zone].get_children():
			if not child is CollisionShape3D: continue
			child.rotation=Vector3.ZERO
			var shape:=CapsuleShape3D.new()
			shape.radius=.32 if zone=="body" else .21 if zone=="head" else .12
			shape.height=1.35 if zone=="body" else .44 if zone=="head" else .8
			child.shape=shape
			child.position=Vector3(0,1.55,0) if zone=="body" else Vector3(0,2.35,.1) if zone=="head" else Vector3(-.49 if "left" in zone else .49,1.45,0) if "front" in zone else Vector3(-.20 if "left" in zone else .20,.65,0)
	limbs=preload("res://scripts/animal_limbs.gd").new(); limbs.animal=self; add_child(limbs)
	_hurt_label.position.y=2.85
	if not reaction:
		reaction=preload("res://scripts/animal_reaction.gd").new(); reaction.animal=self; add_child(reaction)
## These names are also used by the HUD and behavioral regression tests.
var behavior: String = "observe"
var state: String:
	get:
		return behavior
var warned: bool = false
var role: String = "flank"
var pack_slot: int = -1
var flank_side: int = 1
var last_charge_at: float = -1.0
var charge_serial: int = 0
var last_pack_event: String = ""
var pack_reaction_count: int = 0
var awareness: float = 0.0
var detection_state: String = "unaware"
var alerted: bool = false
var last_known_position := Vector3.INF
var heard_noise: bool = false
var bleeding_rate: float = 0.0
var injury_speed_scale: float = 1.0
var leg_injuries: Dictionary = {}
var severed_legs: Array[String] = []
var _last_cue_at: float = -99.0
var _last_heard_at: float = -99.0
var _patrol_origin := Vector3.INF
var _patrol_goal := Vector3.INF
var _patrol_left: float = 0.0
var _drip_left: float = 0.0
var _corpse_left: float = 75.0
var _last_bark: float = -99.0
var _howl_left: float = 20.0
var _last_awareness_update: float = 0.0
var _hearing_previous := Vector3.INF
var _hit_zones: Dictionary = {}
const LEG_BONES: Dictionary = {"front_left": "FrontLeg1_L", "front_right": "FrontLeg1_R", "rear_left": "BackLeg1_L", "rear_right": "BackLeg1_R"}
const LEG_POINTS: Dictionary = {"front_left": Vector3(.16, .28, .42), "front_right": Vector3(-.16, .28, .42), "rear_left": Vector3(.16, .28, -.48), "rear_right": Vector3(-.16, .28, -.48)}
var rng := RandomNumberGenerator.new()
var _skeleton: Skeleton3D
var _joints: Dictionary = {}
var _hurt_label: Label3D
var _hit_area: Area3D
var _time: float = 0.0
var _phase: float = 0.0
var _attack_cooldown: float = 0.0
var _attack_pose: float = 0.0
var _hurt_timer: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _state_left: float = 1.0
var _state_elapsed: float = 0.0
var _warning_until: float = INF
var _close_warning_until := -1.0
var _last_growl: float = -99.0
var _shot_cooldown: float = 0.0
var _boldness: float = 0.5
var _aggression: float = 0.0
var _circle_radius: float = 5.0
var _orbit_goal := Vector3.INF
var _orbit_timer: float = 0.0
var _retreat_from := Vector3.ZERO
var _commit_wait: float = 0.0
var _last_flinch: float = -99.0
var _safe_growl_left: float = 0.0
var _target_previous := Vector3.INF
var _target_velocity := Vector3.ZERO
var _stuck_time: float = 0.0
var _unstick_left: float = 0.0
var _unstick_direction := Vector3.ZERO
var _pack: Dictionary = {}
var _clock_offset: float = 0.0
var _personal_caution_until: float = 0.0
var _reaction_immunity_until: float = 0.0
var _sight_timer: float = 0.0
var _last_seen_at: float = -1.0
var _has_visual_contact: bool = false
var _target_facing := Vector3.FORWARD
var _flank_depth: float = 0.0
const PACK_META: String = "island_wolf_pack"
static var _coat_shader: Shader
var _coat_material: ShaderMaterial

func configure(owner_game: Node, navigation: RefCounted, level: int, profile_seed: int = -1, leader: bool = false) -> void:
	game = owner_game
	nav = navigation
	_register_pack()
	is_alpha = _pack_leader() == null and not bool(_pack.get("succession_pending", false))
	if leader and _pack_leader() == null: is_alpha = true
	profile = Profile.generate(level, profile_seed, is_alpha).duplicate(true)
	profile.make_read_only()
	if is_alpha: _pack.leader = weakref(self)
	size_scale = float(profile.size_scale)
	bite_damage = float(profile.bite_damage)
	max_health = float(profile.max_health)
	health = max_health
	speed = float(profile.walk_speed)
	charge_speed = float(profile.charge_speed)
	rng.seed = int(profile.profile_seed) ^ 572903
	_phase = rng.randf() * TAU
	_boldness = float(profile.boldness)
	_circle_radius = rng.randf_range(3.0, 3.9)
	_flank_depth = rng.randf_range(-0.8, 1.1)
	_safe_growl_left = rng.randf_range(0.4, 1.8)
	_howl_left = rng.randf_range(18.0, 30.0)
	_enter_state("observe", rng.randf_range(0.12, 0.4))
	add_to_group("wolves")
	model = WOLF_SCENE.instantiate() as Node3D
	model.name = "WolfModel"
	# Source mesh bounds: y=-0.0013..3.7938; normalize to a 1.06 m wolf.
	model.scale = Vector3.ONE * 0.27931
	model.position = Vector3(0.0, 0.00036, 0.06887)
	add_child(model)
	_style_coat(model)
	_find_skeleton(model)
	if _skeleton:
		for i: int in range(_skeleton.get_bone_count()):
			_joints[_skeleton.get_bone_name(i)] = [i, _skeleton.get_bone_pose_rotation(i)]
	_hit_area = Area3D.new()
	_hit_area.name = "WolfHitbox"
	_hit_area.collision_layer = 2
	_hit_area.collision_mask = 0
	_hit_area.monitoring = false
	_hit_area.set_meta("wolf", self)
	_hit_area.set_meta("hit_zone", "body")
	_hit_zones["body"] = _hit_area
	add_child(_hit_area)
	var body_shape := CollisionShape3D.new()
	var body := CapsuleShape3D.new()
	body.radius = 0.27
	body.height = 1.45
	body_shape.shape = body
	body_shape.position = Vector3(0.0, 0.57, 0.02)
	body_shape.rotation.x = PI / 2.0
	_hit_area.add_child(body_shape)
	var head_shape := CollisionShape3D.new()
	var head := SphereShape3D.new()
	head.radius = 0.30
	head_shape.shape = head
	head_shape.position = Vector3(0.0, 0.86, 0.55)
	var head_area := _new_hit_area("head")
	head_area.add_child(head_shape)
	for zone: String in LEG_BONES:
		var area := _new_hit_area(zone)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.115
		capsule.height = 0.5
		shape.shape = capsule
		shape.position = LEG_POINTS[zone]
		area.add_child(shape)
	_hurt_label = Label3D.new()
	_hurt_label.position.y = 1.35
	_hurt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hurt_label.font_size = 26
	_hurt_label.outline_size = 6
	_hurt_label.modulate = Color("f9dca7")
	_hurt_label.pixel_size = 0.005
	_hurt_label.visible = false
	add_child(_hurt_label)
	_apply_size()
	var sounds: Node = game.get("sounds") as Node
	if sounds:
		for method: Dictionary in sounds.get_method_list():
			if str(method.name) == "play_at": _voice_pitch_supported = method.args.size() >= 4

func _apply_size() -> void:
	model.scale *= size_scale
	model.position *= size_scale
	_hurt_label.position *= size_scale
	for zone: String in _hit_zones:
		for child: Node in _hit_zones[zone].get_children():
			var collision := child as CollisionShape3D
			if not collision: continue
			collision.position *= size_scale
			if collision.shape is CapsuleShape3D:
				collision.shape.height *= size_scale
				collision.shape.radius *= size_scale
			elif collision.shape is SphereShape3D:
				collision.shape.radius *= size_scale

func get_identification() -> String:
	if werewolf: return "BLOOD MOON / WEREWOLF"
	var size_name := "SMALL" if size_scale < .92 else ("LARGE" if size_scale > 1.08 else "ADULT")
	return "%s%s / %s" % ["ALPHA / " if is_alpha else "", str(profile.coat_name).to_upper(), size_name]

func get_struggle_resistance() -> float:
	return clampf(.92 + (size_scale - 1.0) * .8 + (_boldness - .5) * .15, .78, 1.22)

func get_maul_interval() -> float:
	return clampf(float(profile.attack_interval) * .12, .68, .85)

func _new_hit_area(zone: String) -> Area3D:
	var area := Area3D.new()
	area.name = "Hit_" + zone
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("wolf", self)
	area.set_meta("hit_zone", zone)
	add_child(area)
	_hit_zones[zone] = area
	return area

func get_pursuit_target() -> Vector3:
	return last_known_position if (alerted or awareness > 0.12) else Vector3.INF

func _gore() -> Node:
	return game.get("gore") as Node if is_instance_valid(game) else null

func _blood_burst(point: Vector3, direction: Vector3, intensity: float) -> void:
	var gore: Node = _gore()
	if gore and gore.has_method("blood_burst"):
		gore.call("blood_burst", point, direction, intensity)

func _blood_pool(size: float) -> void:
	var gore: Node = _gore()
	if gore and gore.has_method("blood_pool"):
		gore.call("blood_pool", global_position, size * size_scale)

func receive_ballistic_hit(amount: float, world_hit: Vector3, shot_direction: Vector3, hit_zone: String, limb_force: float, vital_bonus: float = 1.0, penetration_m: float = .7) -> Dictionary:
	if werewolf and limbs and limbs.parts.has(hit_zone):
		if behavior=="maul":
			if hunted_hunter==game.player: game.end_wolf_struggle(true)
			elif is_instance_valid(hunted_hunter): game.coop.release_remote_maul(hunted_hunter.peer_id)
		var result: Dictionary=limbs.hit(hit_zone,amount,limb_force,world_hit,shot_direction)
		injury_speed_scale=limbs.speed_factor()
		if not dead: _alert_to(world_hit-shot_direction*10)
		return result
	var entry := to_local(world_hit) / size_scale
	var direction := (global_basis.inverse() * shot_direction).normalized()
	var penetration := penetration_m / size_scale
	var report: Dictionary = preload("res://scripts/wolf_anatomy.gd").trace(entry, direction, penetration, hit_zone)
	if werewolf:
		report=preload("res://scripts/human_xray.gd").trace(to_local(world_hit)/1.45,direction,amount,penetration_m/1.45)
		report.species="werewolf"; report.bleed=4.0 if not report.organs.is_empty() else .5
		report.zone="WEREWOLF / "+("HEAD" if entry.y>1.5 else "BODY")
	var before := health
	if not report.organs.is_empty(): report.multiplier *= vital_bonus
	if LEG_BONES.has(hit_zone) and not werewolf:
		receive_hit(amount, world_hit, shot_direction, hit_zone, limb_force)
		report.multiplier = (before-health)/maxf(.001,amount)
	else:
		_blood_burst(world_hit, shot_direction, clampf(amount / 60.0, .4, 2.0))
		bleeding_rate = maxf(bleeding_rate, float(report.bleed))
		if report.organs.has("spine"):
			injury_speed_scale = minf(injury_speed_scale, .2)
		var fatal_vital: bool = report.organs.has("brain") or report.organs.has("heart")
		damage(health if fatal_vital else amount * float(report.multiplier))
		report["instant_fatal"] = fatal_vital
		if not dead: _alert_to(world_hit - shot_direction.normalized() * 10.0)
	report["damage"] = before - maxf(0.0, health)
	report["calculated_damage"] = amount*float(report.multiplier)
	report["fatal"] = dead
	return report

func receive_hit(amount: float, world_hit: Vector3, shot_direction: Vector3, hit_zone: String = "body", limb_force: float = 1.0) -> void:
	if dead:
		return
	_blood_burst(world_hit, shot_direction, clampf(amount / 60.0, 0.4, 2.0))
	if LEG_BONES.has(hit_zone) and not severed_legs.has(hit_zone):
		var severity: float = minf(1.0, float(leg_injuries.get(hit_zone, 0.0)) + amount * limb_force / preload("res://scripts/animal_limbs.gd").threshold(max_health))
		leg_injuries[hit_zone] = severity
		bleeding_rate = maxf(bleeding_rate, 1.5 + severity * 3.0)
		injury_speed_scale = minf(injury_speed_scale, 0.78 - severity * 0.23)
		if severity >= 1.0:
			_sever_leg(hit_zone, world_hit, shot_direction)
			# A destructive limb hit is survivable for a few seconds; the blood
			# loss, rather than an immediate reward, determines the eventual death.
			damage(minf(amount * 0.2, maxf(0.0, health - 12.0)))
		else:
			damage(amount * 0.5)
	else:
		damage(amount * (1.35 if hit_zone == "head" else 1.0))
	if not dead:
		_alert_to(world_hit - shot_direction.normalized() * 10.0)

func _sever_leg(zone: String, point: Vector3, direction: Vector3) -> void:
	if behavior == "maul" and game.has_method("end_wolf_struggle"):
		if is_instance_valid(hunted_hunter) and hunted_hunter!=game.player:
			game.coop.release_remote_maul(hunted_hunter.peer_id)
		else: game.call("end_wolf_struggle", true)
	severed_legs.append(zone)
	bleeding_rate = 12.0 + float(severed_legs.size() - 1) * 7.0
	injury_speed_scale = 0.34 if severed_legs.size() == 1 else 0.16
	var bone_name: String = str(LEG_BONES[zone])
	var joint_position: Vector3 = to_global((LEG_POINTS[zone] + Vector3.UP * 0.3) * size_scale)
	if _skeleton and _joints.has(bone_name):
		var bone_index: int = int(_joints[bone_name][0])
		joint_position = _skeleton.to_global(_skeleton.get_bone_global_pose(bone_index).origin)
		_skeleton.set_bone_pose_scale(bone_index, Vector3.ONE * 0.008)
	if _hit_zones.has(zone):
		(_hit_zones[zone] as Area3D).set_deferred("collision_layer", 0)
	var stump := MeshInstance3D.new()
	stump.name = "WoundStump_" + zone
	var mesh := SphereMesh.new()
	mesh.radius = 0.082
	mesh.height = 0.12
	mesh.radial_segments = 10
	mesh.rings = 5
	stump.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8d1e27")
	material.roughness = 0.85
	stump.material_override = material
	model.add_child(stump)
	stump.position = model.to_local(joint_position)
	stump.scale = Vector3.ONE * size_scale / model.scale.x
	var gore: Node = _gore()
	if gore and gore.has_method("severed_limb"):
		var supports_size := false
		for method: Dictionary in gore.get_method_list():
			if str(method.name) == "severed_limb": supports_size = method.args.size() >= 4
		if supports_size: gore.call("severed_limb", point, direction, profile.coat_dark, size_scale)
		else: gore.call("severed_limb", point, direction, profile.coat_dark)
	_begin_retreat(point - direction, 0.35)
	_blood_pool(0.28)

func _register_pack() -> void:
	var existing: Dictionary = game.get_meta(PACK_META+str(get_meta("campaign_pack","")), {})
	var retained: Array[WeakRef] = []
	for reference: WeakRef in existing.get("members", []):
		var member: Node = reference.get_ref() as Node
		if is_instance_valid(member) and not member.is_queued_for_deletion() and not bool(member.get("dead")):
			retained.append(reference)
	if retained.is_empty():
		existing = {"members": [], "clock": 0.0, "next_commit": 0.0, "next_slot": 0, "serial": 0, "caution_until": 0.0, "injury_event_until": 0.0, "leader": null, "disruption_until": 0.0, "succession_at": 0.0, "succession_pending": false, "leader_loss_serial": 0, "loss_immunity_until": 0.0}
	else:
		existing["members"] = retained
	_pack = existing
	pack_slot = int(_pack.next_slot)
	_pack.next_slot = pack_slot + 1
	flank_side = -1 if pack_slot % 2 == 0 else 1
	_clock_offset = float(_pack.clock)
	_pack.members.append(weakref(self))
	game.set_meta(PACK_META+str(get_meta("campaign_pack","")), _pack)

func get_pack_debug() -> Dictionary:
	var members: Array[Node3D] = _pack_members()
	var active: int = 0
	for member: Node3D in members:
		active += int(str(member.get("behavior")) == "charge")
	var now: float = float(_pack.get("clock", 0.0))
	var leader := _pack_leader()
	return {"clock": now, "next_commit": float(_pack.get("next_commit", 0.0)), "active_charge": active, "caution_until": float(_pack.get("caution_until", 0.0)), "caution_left": maxf(0.0, float(_pack.get("caution_until", 0.0)) - now), "members": members.size(), "leader_slot": int(leader.pack_slot) if leader else -1, "leader_alive": leader != null, "disruption_left": maxf(0., float(_pack.get("disruption_until", 0.)) - now), "charge_limit": 1 if now < float(_pack.get("disruption_until", 0.)) else 2, "succession_pending": bool(_pack.get("succession_pending", false))}

func _pack_leader() -> Node3D:
	var reference: WeakRef = _pack.get("leader") as WeakRef
	var leader: Node3D = reference.get_ref() as Node3D if reference else null
	return leader if is_instance_valid(leader) and not leader.is_queued_for_deletion() and not leader.dead else null

func _perceives_pack_event(source: Vector3) -> bool:
	var distance := position.distance_to(source)
	# A close yelp can be heard out of view; farther reactions need a witness.
	if distance < 8.0 * float(profile.hearing_multiplier): return true
	if distance > 22.0 * float(profile.sight_multiplier): return false
	var bearing := source - position
	bearing.y = 0.0
	if global_basis.z.dot(bearing.normalized()) < -.10: return false
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * .8 * size_scale, source + Vector3.UP * .65, 1)
	ray.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _leader_lost() -> void:
	var now: float = float(_pack.get("clock", _time))
	_pack.leader = null
	_pack.succession_pending = true
	_pack.leader_loss_serial = int(_pack.get("leader_loss_serial", 0)) + 1
	var protected: bool = now < float(_pack.get("loss_immunity_until", 0.))
	var recovery := 2.0 if protected else rng.randf_range(5.5, 7.0)
	_pack.succession_at = now + recovery
	var witnesses: Array[Node3D] = []
	for member: Node3D in _pack_members():
		if member._perceives_pack_event(position): witnesses.append(member)
	if not witnesses.is_empty() and not protected:
		_pack.disruption_until = now + recovery
		_pack.caution_until = maxf(float(_pack.caution_until), now + .45)
		_pack.next_commit = maxf(float(_pack.next_commit), now + 1.4)
		_pack.loss_immunity_until = now + 16.0
	for member: Node3D in witnesses:
		member._on_leader_loss(position, now, int(_pack.leader_loss_serial), protected)

func _on_leader_loss(source: Vector3, now: float, serial: int, brief: bool) -> void:
	if dead or serial == _leader_event_seen: return
	_leader_event_seen = serial
	last_pack_event = "leader_killed"
	pack_reaction_count += 1
	heard_noise = true
	_last_heard_at = _time
	if not alerted:
		awareness = maxf(awareness, .38)
		last_known_position = source
		_last_cue_at = _time
		detection_state = "investigating"
	if behavior == "maul":
		leader_reaction = "engaged"
		return
	var hold: bool = _boldness > .67 and rng.randf() < .72
	leader_reaction = "hold" if hold else "retreat"
	var caution := .45 if brief else (rng.randf_range(.65, 1.2) if hold else rng.randf_range(2.5, 4.5))
	_leader_caution_until = now + caution
	_personal_caution_until = maxf(_personal_caution_until, _leader_caution_until)
	_aggression = maxf(.1, _aggression - (.05 if hold else .25))
	var away := position - source
	away.y = 0.0
	if away.length_squared() < .1: away = global_basis.z
	var regroup := position + away.normalized() * (1.0 if hold else 2.4)
	var cell: int = nav.nearest(regroup.x, regroup.z, 2.0)
	_regroup_goal = nav.point(cell) if cell >= 0 else position
	if hold or brief: _enter_state("recover", caution)
	else: _begin_retreat(source, rng.randf_range(.65, 1.15))
	if not brief and rng.randf() < .55: _leader_howl_at = _time + rng.randf_range(.35, 1.7)

func _tick_pack_leadership() -> void:
	if _pack_leader() or not bool(_pack.get("succession_pending", false)): return
	var now: float = float(_pack.clock)
	if now < float(_pack.get("succession_at", 0.)): return
	var candidate: Node3D = null
	var best := -1.0
	for member: Node3D in _pack_members():
		if int(member._leader_event_seen) != int(_pack.leader_loss_serial): continue
		var score: float = float(member.profile.experience) * .8 + float(member.profile.boldness) * .2
		if score > best:
			best = score
			candidate = member
	if candidate:
		candidate.is_alpha = true
		_pack.leader = weakref(candidate)
		_pack.succession_pending = false
	else:
		# An unseen loss can leave nobody eligible. Share the retry deadline so
		# the other wolves do not repeat the same full-pack search this frame.
		_pack.succession_at = now + 1.0

func _play_voice(kind: String, volume: float) -> void:
	var session = game.get("coop")
	if session: session.broadcast_voice(kind,global_position,volume,float(profile.voice_pitch))
	var sounds: Node = game.get("sounds") as Node
	if not sounds or not sounds.has_method("play_at"): return
	if _voice_pitch_supported: sounds.call("play_at", kind, global_position, volume, float(profile.voice_pitch))
	else: sounds.call("play_at", kind, global_position, volume)

func _clearance_at(point: Vector3) -> bool:
	# The navigation is already sampled for the base animal footprint. Large
	# individuals need an additional margin rather than scaling a physics body.
	var margin := maxf(0., size_scale - .8) * .18
	for offset: Vector2 in [Vector2(margin,0),Vector2(-margin,0),Vector2(0,margin),Vector2(0,-margin)]:
		if not nav.valid(nav.at(point.x + offset.x, point.z + offset.y)): return false
	return true

func _move_scaled(dx: float, dz: float) -> Vector3:
	var proposed: Vector3 = nav.move_position(position, dx, dz)
	if _clearance_at(proposed): return proposed
	var x_only: Vector3 = nav.move_position(position, dx, 0.)
	if _clearance_at(x_only): return x_only
	var z_only: Vector3 = nav.move_position(position, 0., dz)
	if _clearance_at(z_only): return z_only
	return position

func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D:
		_skeleton = node as Skeleton3D
	for child: Node in node.get_children():
		_find_skeleton(child)

func _style_coat(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if _coat_material == null:
			var original := mesh_instance.get_active_material(0) as BaseMaterial3D
			_coat_material = ShaderMaterial.new()
			if _coat_shader == null:
				_coat_shader = Shader.new()
				_coat_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;
uniform sampler2D coat_texture : source_color, filter_linear_mipmap;
uniform vec4 coat_dark : source_color = vec4(.19,.23,.24,1.);
uniform vec4 coat_light : source_color = vec4(.43,.45,.43,1.);
uniform float coat_patch = .4;
uniform float coat_phase = 0.;
varying vec3 coat_position;
void vertex() { coat_position = VERTEX; }
void fragment() {
    vec3 source = texture(coat_texture, UV).rgb;
    float value = dot(source, vec3(0.299, 0.587, 0.114));
    float back = smoothstep(0.6, 3.7, coat_position.y);
    float broad_patch = sin(coat_position.z * 2.0 + coat_position.y * 1.7 + coat_phase);
    vec3 coat = mix(coat_light.rgb, coat_dark.rgb, clamp(back + broad_patch * coat_patch * .18, 0., 1.));
    coat *= .56 + value * .95;
    float strands = sin(coat_position.y*195.0+sin(coat_position.z*83.0)*4.0+coat_position.x*310.0);
    coat *= .95+strands*.055;
    // Preserve the source facial markings and fine coat texture.
    coat = mix(vec3(0.055, 0.069, 0.069), coat, smoothstep(0.07, 0.22, value));
    ALBEDO = coat;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}
"""
			_coat_material.shader = _coat_shader
			_coat_material.set_shader_parameter("coat_dark", profile.coat_dark)
			_coat_material.set_shader_parameter("coat_light", profile.coat_light)
			_coat_material.set_shader_parameter("coat_patch", profile.coat_patch)
			_coat_material.set_shader_parameter("coat_phase", profile.coat_phase)
			if original:
				_coat_material.set_shader_parameter("coat_texture", original.albedo_texture)
		mesh_instance.material_override = _coat_material
	for child: Node in node.get_children():
		_style_coat(child)

func damage(amount: float) -> void:
	if game.coop.client(): return
	_ensure_reaction()
	if dead:
		return
	if reaction and amount>2: reaction.hit(amount/max_health)
	health = maxf(0.0, health - amount)
	if reaction: reaction.hold_incapacitated()
	_hurt_timer = 1.5
	_hurt_label.text = "%d / %d" % [ceili(health), ceili(max_health)]
	_hurt_label.visible = true
	_attack_pose = 0.35
	_aggression = minf(1.0, _aggression + 0.3)
	if health > max_health*.07:
		_notify_pack("injured")
		var player: Node3D = game.get("player") as Node3D
		if behavior != "maul" and player and _time - _last_flinch > 2.5 and rng.randf() < 0.25:
			_last_flinch = _time
			_begin_retreat(player.position, rng.randf_range(0.18, 0.3))
		elif not warned:
			_begin_warning()
	if health <= 0.0:
		_die()

func _die() -> void:
	if dead:
		return
	dead = true
	if werewolf: model.set_process(false)
	health = 0.0
	behavior = "dead"
	detection_state = "dead"
	if is_alpha: _leader_lost()
	else: _notify_pack("killed")
	remove_from_group("wolves")
	add_to_group("wolf_corpses")
	for zone: String in _hit_zones:
		(_hit_zones[zone] as Area3D).set_deferred("collision_layer", 0)
	_hurt_label.visible = false
	_blood_pool(0.48)
	game.call("wolf_defeated", self)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(model, "rotation:z", 1.45, 0.3).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(model, "position:y", -0.12 * size_scale, 0.3)
	var corpses: Array[Node] = game.nodes_in_group("wolf_corpses")
	while corpses.size() > 12:
		var old: Node = corpses.pop_front()
		if old != self:
			old.queue_free()

func _alert_to(point: Vector3) -> void:
	if game.get("free_play"): return
	var newly_alert: bool = not alerted
	awareness = 1.0
	alerted = true
	detection_state = "alert"
	last_known_position = point
	_last_cue_at = _time
	if newly_alert:
		warned = false
		_close_warning_until = -1.0
		_bark()
		_begin_warning()
		for mate: Node3D in _pack_members():
			if mate != self and mate.position.distance_to(position) < (23.0 if is_alpha else 18.0):
				mate.call("hear_pack_warning", point)

func hear_pack_warning(point: Vector3) -> void:
	if dead:
		return
	awareness = maxf(awareness, 0.55)
	last_known_position = point
	_last_cue_at = _time
	detection_state = "investigating" if not alerted else "alert"

func hear_gunshot(origin: Vector3) -> void:
	if dead or _shot_cooldown > 0.0 or position.distance_to(origin) > 55.0:
		return
	_alert_to(origin)
	heard_noise = true
	_last_heard_at = _time
	_shot_cooldown = 2.5
	_aggression = minf(1.0, _aggression + 0.35)
	if behavior == "maul":
		return
	var fear_chance: float = 0.25 - _boldness * 0.12
	if position.distance_to(origin) < 10.0:
		fear_chance += 0.08
	if _time - _last_flinch > 2.5 and rng.randf() < fear_chance:
		_last_flinch = _time
		_begin_retreat(origin, rng.randf_range(0.20, 0.38))
	elif not warned:
		_begin_warning()
	else:
		# Alert wolves do not restart a full warning every time the gun fires.
		_growl()
		_commit_wait = maxf(_commit_wait, 1.2)
		if _time - _last_flinch > 2.5:
			_last_flinch = _time
			_enter_state("recover", rng.randf_range(0.15, 0.3))

func _notify_pack(kind: String) -> void:
	var now: float = float(_pack.get("clock", _time))
	if kind == "injured" and now < float(_pack.get("injury_event_until", 0.0)):
		return
	_pack.injury_event_until = now + 2.5
	var heard: bool = false
	for member: Node3D in _pack_members():
		if member != self and member.position.distance_to(position) <= 16.0 and member._perceives_pack_event(position):
			member.call("_on_pack_event", kind, position, now)
			heard = true
	if heard:
		_pack.caution_until = maxf(float(_pack.caution_until), now + (0.65 if kind == "killed" else 0.3))

func _on_pack_event(kind: String, source: Vector3, now: float) -> void:
	if dead or now < _reaction_immunity_until:
		return
	last_pack_event = kind
	pack_reaction_count += 1
	_reaction_immunity_until = now + 2.5
	if behavior == "maul":
		return
	var caution: float = rng.randf_range(0.65, 1.0) if kind == "killed" else rng.randf_range(0.30, 0.55)
	_personal_caution_until = now + caution
	_aggression = maxf(_aggression, 0.3)
	if position.distance_to(source) < 3.0:
		_begin_retreat(source, minf(0.35, caution))
	else:
		_enter_state("recover", caution)

func _enter_state(next_state: String, duration: float) -> void:
	behavior = next_state
	_state_left = duration
	_state_elapsed = 0.0
	_orbit_timer = 0.0
	if behavior == "charge":
		_commit_wait = 0.0
	if behavior == "warn" or behavior == "observe" or behavior == "recover":
		_velocity *= 0.3

func _begin_warning() -> void:
	if warned:
		_growl()
		return
	warned = true
	_warning_until = _time + (rng.randf_range(.7,1.1) if werewolf else rng.randf_range(4.0,6.0))
	_enter_state("warn", .6 if werewolf else rng.randf_range(1.6,2.4))
	_growl()

func _growl() -> void:
	if _time - _last_growl < (1.7 if behavior in ["warn","circle"] else 3.0):
		return
	_last_growl = _time
	_play_voice("growl", -5.0)

func _bark() -> void:
	if _time - _last_bark < 2.0:
		return
	_last_bark = _time
	_play_voice("bark", -5.0)

func _tick_vocalizations(delta: float) -> void:
	if alerted and behavior in ["warn","circle","charge","hunt","approach","flank"]: _growl()
	if _leader_howl_at >= 0.0 and _time >= _leader_howl_at:
		_leader_howl_at = -1.0
		_howl_left = rng.randf_range(18.0, 30.0)
		_play_voice("howl", -14.0)
	_howl_left -= delta
	if _howl_left <= 0.0 and behavior not in ["maul", "charge"]:
		_howl_left = rng.randf_range(18.0, 30.0)
		_play_voice("howl", -17.0)

func _struggle_active() -> bool:
	if is_instance_valid(hunted_hunter) and hunted_hunter!=game.player:
		return hunted_hunter.mauling!=0
	return game.has_method("is_struggling") and bool(game.call("is_struggling"))

func end_struggle(escaped: bool) -> void:
	if dead:
		return
	if escaped:
		_ensure_reaction(); reaction.down=maxf(reaction.down,3.0); reaction.flinch=.4
	_attack_cooldown = maxf(3.0 if escaped else 0.0,float(profile.attack_interval) * (.65 if escaped else .5))
	var player: Node3D = hunted_hunter if is_instance_valid(hunted_hunter) else game.get("player") as Node3D
	_begin_retreat(player.position if player else position - global_basis.z, 0.65)

func _tick_maul(player: Node3D, delta: float) -> void:
	if _player_is_safe() and _struggle_active() and game.has_method("end_wolf_struggle"):
		if is_instance_valid(hunted_hunter) and hunted_hunter!=game.player:
			game.coop.release_remote_maul(hunted_hunter.peer_id)
		else: game.call("end_wolf_struggle", true)
		return
	if not _struggle_active() or _player_is_safe():
		end_struggle(true)
		return
	# Keep the snout in front of the lowered struggle camera, not underneath it.
	var jaw_target: Vector3 = player.position - player.global_basis.z * (.72 + .58 * size_scale)
	var step: Vector3 = jaw_target - position
	step.y = 0.0
	step = step.limit_length(3.0 * delta * injury_speed_scale)
	position = _move_scaled(step.x, step.z)
	var toward: Vector3 = player.position - position
	rotation.y = atan2(toward.x, toward.z)
	_velocity = Vector3.ZERO
	_animate(0.8, true)

func _tick_hunting(delta: float) -> void:
	var goal: Vector3 = last_known_position
	var pace: float = speed * 0.6
	if not goal.is_finite() or awareness <= 0.12:
		behavior = "patrol"
		if not _patrol_origin.is_finite():
			_patrol_origin = position
		_patrol_left -= delta
		if _patrol_left <= 0.0 or not _patrol_goal.is_finite():
			_patrol_left = rng.randf_range(3.0, 5.5)
			_patrol_goal = position
			for attempt: int in range(10):
				var angle: float = rng.randf() * TAU
				var candidate: Vector3 = _patrol_origin + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.0, 4.0)
				var cell: int = int(nav.call("nearest", candidate.x, candidate.z, 1.0))
				if cell >= 0:
					candidate = nav.call("point", cell)
					if nav.call("line_clear", position.x, position.z, candidate.x, candidate.z):
						_patrol_goal = candidate
						break
		goal = _patrol_goal
		pace = speed * 0.38
	else:
		behavior = "investigate" if detection_state == "investigating" else "search"
	var direction: Vector3 = goal - position
	direction.y = 0.0
	if direction.length_squared() < 0.7:
		direction = Vector3.ZERO
		rotation.y += delta * 0.48
	elif behavior == "patrol":
		direction = direction.normalized()
	else:
		direction = _toward_goal(goal)
	_velocity = _velocity.move_toward(direction * pace * injury_speed_scale, delta * 4.0)
	position = _move_scaled(_velocity.x * delta, _velocity.z * delta)
	if _velocity.length_squared() > 0.03:
		rotation.y = lerp_angle(rotation.y, atan2(_velocity.x, _velocity.z), minf(1., delta * float(profile.turn_rate) * .43))
	_animate(_velocity.length(), false)

func _begin_retreat(origin: Vector3, duration: float) -> void:
	_retreat_from = origin
	_enter_state("retreat", duration)

func _player_is_safe() -> bool:
	if is_instance_valid(hunted_hunter): return (game.health<=0 if hunted_hunter==game.player else hunted_hunter.health<=0) or game.world.is_safe_position(hunted_hunter.position)
	return game.has_method("is_player_safe") and bool(game.call("is_player_safe"))

func _pack_members() -> Array[Node3D]:
	var pack: Array[Node3D] = []
	for reference: WeakRef in _pack.get("members", []):
		var other: Node3D = reference.get_ref() as Node3D
		if is_instance_valid(other) and not other.is_queued_for_deletion() and not bool(other.get("dead")):
			pack.append(other)
	return pack

func _can_start_charge(pack: Array[Node3D]) -> bool:
	if not alerted or _struggle_active() or not warned or _close_warning_until<0 or _time < maxf(_warning_until,_close_warning_until) or _attack_cooldown > 0.0 or _player_is_safe():
		return false
	var now: float = float(_pack.get("clock", _time))
	if now < float(_pack.get("next_commit", 0.0)) or now < float(_pack.get("caution_until", 0.0)) or now < _personal_caution_until:
		return false
	var leader := _pack_leader()
	# At the first close encounter, nearby followers give their alert breeding
	# adult a short chance to initiate. This never waits for a distant leader.
	if not is_alpha and int(_pack.get("serial", 0)) == 0 and _commit_wait < .9 and leader and leader.alerted and leader.position.distance_to(position) < 12.0 and leader._attack_cooldown <= 0.0:
		return false
	var charging: int = 0
	for other: Node3D in pack:
		if other != self and str(other.get("behavior")) == "charge":
			charging += 1
	var limit := 1 if now < float(_pack.get("disruption_until", 0.)) else 2
	return charging < mini(limit, pack.size())

func _start_charge(pack: Array[Node3D]) -> bool:
	if not _can_start_charge(pack):
		return false
	last_charge_at = float(_pack.clock)
	var disrupted: bool = last_charge_at < float(_pack.get("disruption_until", 0.))
	_pack.next_commit = last_charge_at + rng.randf_range(1.35 if disrupted else .75, 1.8 if disrupted else 1.0)
	_pack.serial = int(_pack.serial) + 1
	charge_serial = int(_pack.serial)
	_bark()
	_enter_state("charge", rng.randf_range(3.2, 4.2))
	return true

func _update_perception(player: Node3D, delta: float) -> void:
	_sight_timer -= delta
	if _sight_timer > 0.0:
		return
	_sight_timer = 0.16
	var elapsed: float = maxf(0.016, _time - _last_awareness_update)
	_last_awareness_update = _time
	var target: Vector3 = player.position
	var distance: float = position.distance_to(target)
	var visibility: float = clampf(float(player.call("get_visibility")), 0.05, 1.0) if player.has_method("get_visibility") else 1.0
	var noise: float = clampf(float(player.call("get_noise_level")), 0.0, 1.0) if player.has_method("get_noise_level") else (0.48 if _hearing_previous.is_finite() and _hearing_previous.distance_to(target) > 0.05 else 0.03)
	_hearing_previous = target
	var crouching: bool = player.get("is_crouching") == true
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8 * size_scale, player.global_position + Vector3.UP * (0.85 if crouching else 1.25), 1)
	query.collide_with_areas = false
	var clear: bool = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	var bearing: Vector3 = target - position
	bearing.y = 0.0
	var in_cone: bool = global_basis.z.normalized().dot(bearing.normalized()) > 0.34 or distance < 1.25
	var sight_range: float = 30.0 * visibility * float(profile.sight_multiplier)
	_has_visual_contact = distance < sight_range and in_cone and clear
	var hearing_range: float = (1.0 + noise * 24.0) * float(profile.hearing_multiplier)
	var audible: bool = noise > 0.055 and distance < hearing_range * (1.0 if clear else 0.6)
	heard_noise = audible or _time - _last_heard_at < 0.7
	if _has_visual_contact or audible:
		_last_cue_at = _time
		last_known_position = target
		if audible:
			_last_heard_at = _time
		var gain: float = (1.5 * visibility * clampf(1.2 - distance / maxf(sight_range, 0.1), 0.3, 1.0)) if _has_visual_contact else (0.45 + noise * 0.9)
		awareness = minf(1.0, awareness + elapsed * gain)
		if awareness >= 0.82 and not alerted:
			_alert_to(target)
		if _has_visual_contact:
			if _target_previous.is_finite() and _last_seen_at >= 0.0:
				var observed: Vector3 = (target - _target_previous) / maxf(_time - _last_seen_at, 0.001)
				observed.y = 0.0
				_target_velocity = _target_velocity.lerp(observed.limit_length(8.0), 0.65)
			_target_previous = target
			_last_seen_at = _time
			_target_facing = -player.global_basis.z
			_target_facing.y = 0.0
			_target_facing = _target_facing.normalized()
	else:
		_target_velocity = _target_velocity.move_toward(Vector3.ZERO, 2.0)
		if _time - _last_cue_at > 2.0:
			awareness = maxf(0.0, awareness - elapsed * 0.10)
		if _time - _last_cue_at > 8.0:
			alerted = false
	if alerted:
		detection_state = "alert" if _has_visual_contact else "searching"
	elif awareness > 0.12:
		detection_state = "investigating" if _time - _last_cue_at < 2.0 else "searching"
	else:
		detection_state = "unaware"
		last_known_position = Vector3.INF

func _visible_opportunity(target: Vector3) -> float:
	if not _has_visual_contact:
		return 0.0
	var away_from_wolf: Vector3 = target - position
	away_from_wolf.y = 0.0
	away_from_wolf = away_from_wolf.normalized()
	var opportunity: float = 0.3 if _target_velocity.length() < 0.8 else 0.0
	if _target_velocity.dot(away_from_wolf) > 1.5:
		opportunity += 0.4
	if _target_facing.dot(-away_from_wolf) < -0.15:
		opportunity += 0.4
	return minf(1.0, opportunity)

func _bite_navigation() -> RefCounted:
	var world: Node = game.get("world") as Node
	if world:
		var player_navigation: Variant = world.get("nav")
		if player_navigation is RefCounted:
			return player_navigation as RefCounted
	return nav

func _choose_attack(pack: Array[Node3D]) -> void:
	# One wolf briefly draws attention while the others press the flanks. Once
	# its short distraction ends, it also commits; randomness cannot defer forever.
	var direct_chance: float = (.35 if role == "lead" else (.18 if role == "distract" else .45)) + (_boldness - .5) * .2
	var commit: bool = werewolf or _commit_wait >= (8.0 if pack.size() == 1 else 6.0)
	if _can_start_charge(pack) and (commit or rng.randf() < direct_chance):
		_start_charge(pack)
	else:
		_enter_state("circle", rng.randf_range(1.4,2.4))

func _think(_target: Vector3, distance: float, safe: bool, pack: Array[Node3D]) -> void:
	# A distant gunshot is not a warning the approaching hunter could hear.
	# Require a fresh close standoff, including after the hunter leaves shelter.
	if safe: _close_warning_until = -1.0
	elif distance<16 and _close_warning_until<0:
		warned=false
		_begin_warning()
		_close_warning_until=_warning_until
	if _struggle_active():
		if behavior != "circle":
			_enter_state("circle", 0.5)
		return
	if safe:
		if _safe_growl_left <= 0.0 and distance < 22.0:
			if not warned:
				warned = true
				_warning_until = _time + 0.65
			_growl()
			_safe_growl_left = rng.randf_range(4.0, 7.0)
		if behavior != "circle" and behavior != "retreat" and behavior != "recover":
			_enter_state("circle", rng.randf_range(2.5, 4.5))
		elif _state_left <= 0.0:
			_enter_state("circle", rng.randf_range(2.5, 4.5))
		return
	match behavior:
		"observe":
			if _state_left <= 0.0:
				if distance < 16.0 and not warned:
					_begin_warning()
				else:
					_enter_state("approach", 0.0)
		"approach":
			if distance < 15.0:
				if not warned:
					_begin_warning()
				else:
					_choose_attack(pack)
		"warn":
			if _state_left <= 0.0:
				_choose_attack(pack)
		"circle":
			if distance > 17.0:
				_enter_state("approach", 0.0)
			elif _state_left <= 0.0:
				if not warned:
					_begin_warning()
				else:
					if _time - _last_growl > 7.0:
						_growl()
					_choose_attack(pack)
		"charge":
			if _state_left <= 0.0:
				# A missed rush becomes a short lateral reposition, not a long flight.
				_enter_state("circle", 0.35)
		"retreat":
			if _state_left <= 0.0:
				if float(_pack.clock) < _leader_caution_until:
					leader_reaction = "regroup"
					_enter_state("regroup", _leader_caution_until - float(_pack.clock))
				else: _enter_state("recover", rng.randf_range(0.3, 0.55))
		"regroup":
			if _state_left <= 0.0: _enter_state("recover", .35)
		"recover":
			if _state_left <= 0.0:
				if not warned and distance < 16.0:
					_begin_warning()
				else:
					_enter_state("circle", rng.randf_range(0.4, 0.7))

var campaign_route := PackedVector3Array()
var campaign_route_at := 0.0
var campaign_search: RefCounted
func _toward_goal(goal: Vector3) -> Vector3:
	if not goal.is_finite():
		return Vector3.ZERO
	var offset: Vector3 = goal - position
	offset.y = 0.0
	if offset.length_squared() < 0.12:
		return Vector3.ZERO
	if offset.length_squared() < 256.0 and nav.call("line_clear", position.x, position.z, goal.x, goal.z):
		return offset.normalized()
	if game.get("campaign") and game.campaign.running:
		if campaign_search:
			campaign_search.advance()
			if campaign_search.finished: campaign_route=campaign_search.result; campaign_search=null
		if _time>=campaign_route_at and not campaign_search:
			campaign_route_at=_time+1.2+rng.randf()*.4
			var cell: int=nav.nearest(goal.x,goal.z,3)
			if cell>=0:
				campaign_search=preload("res://scripts/route_search.gd").new()
				campaign_search.start(nav,position,nav.point(cell))
		while not campaign_route.is_empty() and Vector2(position.x-campaign_route[0].x,position.z-campaign_route[0].z).length()<.30: campaign_route.remove_at(0)
		for shortcut in 2:
			if campaign_route.size()>1 and preload("res://scripts/animal_route.gd").corridor_clear(nav,position,campaign_route[1]): campaign_route.remove_at(0)
			else: break
		if not campaign_route.is_empty():
			var direction:=campaign_route[0]-position; direction.y=0
			return direction.normalized()
	var next: Vector3 = nav.call("next_point", position.x, position.z)
	if not next.is_finite():
		return Vector3.ZERO
	next -= position
	next.y = 0.0
	return next.normalized()

func _circle_goal(center: Vector3, _pack_members_unused: Array[Node3D]) -> Vector3:
	if _orbit_timer > 0.0 and _orbit_goal.is_finite():
		return _orbit_goal
	_orbit_timer = rng.randf_range(0.35, 0.6)
	var radius: float = _circle_radius + (1.2 if _player_is_safe() else 0.0)
	var forward: Vector3 = _target_facing if _target_facing.length_squared() > 0.1 else Vector3.FORWARD
	var leader := _pack_leader()
	if leader and leader != self and leader.alerted and leader.position.distance_to(position) < 12.0:
		var leading: Vector3 = center - leader.position
		leading.y = 0.0
		if leading.length_squared() > .5: forward = leading.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	# Persistent sides and local repositioning replace the synchronized orbit.
	# Losing a packmate never rotates all remaining wolves into new numbered slots.
	var band: float = float(pack_slot / 2) * 0.7
	var lateral: float = float(flank_side) * (radius + band * 0.3)
	var depth: float = _flank_depth - band
	if role in ["distract", "lead"]:
		lateral *= 0.45
		depth += radius * 0.65
	var goal: Vector3 = center + right * lateral + forward * depth
	var nearest: int = int(nav.call("nearest", goal.x, goal.z, 2.0))
	_orbit_goal = nav.call("point", nearest) if nearest >= 0 else center
	return _orbit_goal

func _can_bite(target: Vector3) -> bool:
	if not alerted or _struggle_active() or not warned or _close_warning_until<0 or _time < maxf(_warning_until,_close_warning_until) or _player_is_safe() or _attack_cooldown > 0.0:
		return false
	var offset: Vector3 = target - position
	if Vector2(offset.x, offset.z).length() > .65 + .90 * size_scale or absf(offset.y) > .25 + .75 * size_scale:
		return false
	# The movement grid excludes a buffer OUTSIDE the safe cabin. That buffer
	# must not protect an exposed survivor from the wolf's bite reach.
	var bite_nav: RefCounted = _bite_navigation()
	if not bite_nav.call("line_clear", position.x, position.z, target.x, target.z):
		return false
	# Sampled navigation rejects walls; the physics ray also rejects railings,
	# counters and geometry between the wolf's head and the player's body.
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.68 * size_scale, target + Vector3.UP * 0.75, 1)
	ray.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	_ensure_reaction()
	if reaction and reaction.hold_incapacitated(): return
	if is_queued_for_deletion() or not is_instance_valid(game):
		return
	if dead:
		_corpse_left -= delta
		if _corpse_left <= 0.0:
			queue_free()
		return
	if not game.call("is_playing"):
		return
	var player: Node3D = game.get("player") as Node3D
	if is_instance_valid(game.get("coop")) and game.coop.active and not game.coop.client():
		if behavior!="maul" or not is_instance_valid(hunted_hunter): hunted_hunter = game.coop.nearest_hunter(position)
		player = hunted_hunter
	if not is_instance_valid(player):
		return
	_time += delta
	if bleeding_rate > 0.0:
		health = maxf(0.0, health - bleeding_rate * delta)
		_drip_left -= delta
		if _drip_left <= 0.0:
			_drip_left = 0.45 if not severed_legs.is_empty() else 0.85
			_blood_pool(0.12 if severed_legs.is_empty() else 0.22)
		if health <= 0.0:
			_die()
			return
	if reaction and reaction.down>0: return
	if _hunt_raider(delta,player): return
	if game.get("free_play"):
		alerted = false
		awareness = 0
		last_known_position = Vector3.INF
		_tick_hunting(delta)
		return
	_tick_vocalizations(delta)
	_pack.clock = maxf(float(_pack.get("clock", 0.0)), _time + _clock_offset)
	_tick_pack_leadership()
	_state_elapsed += delta
	_state_left -= delta
	_orbit_timer -= delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_attack_pose = maxf(0.0, _attack_pose - delta)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_safe_growl_left -= delta
	_hurt_label.visible = _hurt_timer > 0.0
	var target: Vector3 = player.position
	var safe: bool = _player_is_safe()
	_update_perception(player, delta)
	if behavior == "maul":
		_tick_maul(player, delta)
		return
	if not alerted:
		if _hunt_wildlife(delta): return
		if float(_pack.clock) < _leader_caution_until and _regroup_goal.is_finite():
			var retreat: Vector3 = _regroup_goal - position
			retreat.y = 0.0
			retreat = retreat.limit_length(speed * .7 * injury_speed_scale * delta)
			position = _move_scaled(retreat.x, retreat.z)
			behavior = "regroup"
			_animate(retreat.length() / maxf(delta, .001), false)
			return
		_tick_hunting(delta)
		return
	if last_known_position.is_finite():
		target = last_known_position
	if behavior in ["patrol", "investigate", "search"] or (behavior == "regroup" and float(_pack.clock) >= _leader_caution_until):
		_enter_state("approach", 0.0)
	if safe:
		_aggression = maxf(0.0, _aggression - delta * 0.08)
		_commit_wait = 0.0
	else:
		_aggression = minf(1.0, _aggression + delta * (0.035 + 0.08 * _visible_opportunity(target)))
		if behavior != "charge":
			_commit_wait += delta
	var center: Vector3 = target
	if safe:
		var world: Node3D = game.get("world") as Node3D
		if world:
			center = world.get("exterior_rally_point")
	var toward: Vector3 = target - position
	toward.y = 0.0
	var distance: float = toward.length()
	var pack: Array[Node3D] = _pack_members()
	var slot: int = pack_slot
	role = "lone" if pack.size() == 1 else ("lead" if is_alpha else ("distract" if slot % 3 == 0 else ("flank_left" if flank_side < 0 else "flank_right")))
	_think(target, distance, safe, pack)
	var direction := Vector3.ZERO
	var pace: float = 0.0
	match behavior:
		"approach":
			direction = _toward_goal(center)
			pace = speed * 1.35
		"circle":
			direction = _toward_goal(_circle_goal(center, pack))
			pace = speed * (0.8 if safe else 1.05)
		"charge":
			var pursuit: Vector3 = target + _target_velocity * 0.22
			if distance > 4.5 and _state_elapsed < 0.6 and role != "distract":
				var flank := Vector3(-toward.z, 0.0, toward.x).normalized()
				pursuit += flank * (1.15 if role == "flank_left" else -1.15)
			direction = _toward_goal(pursuit)
			pace = charge_speed
		"retreat":
			direction = position - _retreat_from
			direction.y = 0.0
			direction = direction.normalized()
			pace = speed * 0.85
		"regroup":
			direction = _toward_goal(_regroup_goal)
			pace = speed * .7
		"warn":
			if distance < 2.2:
				direction = -toward.normalized()
				pace = speed * 0.3
	if pace > 0.0:
		var separation := Vector3.ZERO
		for other: Node3D in pack:
			if other == self:
				continue
			var away: Vector3 = position - other.position
			away.y = 0.0
			var apart: float = away.length()
			var spacing: float = .525 * (size_scale + float(other.size_scale))
			if apart > 0.01 and apart < spacing:
				separation += away / apart * (spacing - apart) * (0.45 if behavior == "charge" else 1.0)
		direction = (direction + separation).normalized()
	if _unstick_left > 0.0:
		_unstick_left -= delta
		direction = _unstick_direction
	pace *= injury_speed_scale
	if nav.has_method("vegetation_factor"): pace *= nav.call("vegetation_factor",position)
	_velocity = _velocity.move_toward(direction * pace, delta * (12.0 if behavior == "charge" else 7.0))
	var previous: Vector3 = position
	position = _move_scaled(_velocity.x * delta, _velocity.z * delta)
	if pace > 0.0 and position.distance_squared_to(previous) < 0.00001:
		_stuck_time += delta
		if _stuck_time > 0.35:
			campaign_route.clear(); campaign_search=null; campaign_route_at=0
			if direction.length_squared()<.01: direction=Vector3(sin(rotation.y),0,cos(rotation.y))
			var side: Vector3 = Vector3(-direction.z, 0.0, direction.x) * (1.0 if slot % 2 == 0 else -1.0)
			var sidestep: Vector3 = nav.call("move_position", position, side.x * 0.4, side.z * 0.4)
			_unstick_direction = side if sidestep.distance_squared_to(position) > 0.01 else -side
			_unstick_left = 0.3
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0
	var facing: Vector3 = toward if behavior in ["warn", "observe", "recover"] else _velocity
	if facing.length_squared() > 0.02:
		rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), minf(1.0, delta * float(profile.turn_rate)))
	if behavior == "charge" and _can_bite(player.position):
		_attack_cooldown = float(profile.attack_interval)
		_attack_pose = 0.38
		if player!=game.player and is_instance_valid(game.get("coop")):
			if game.coop.begin_remote_maul(self,player): _enter_state("maul",99)
		elif game.has_method("start_wolf_struggle"):
			if bool(game.call("start_wolf_struggle", self)):
				_enter_state("maul", 99.0)
				_bark()
			else:
				# Root rejection includes the escape grace window. It must not turn
				# into an unguarded legacy bite that bypasses that protection.
				_attack_cooldown = 1.0
				_begin_retreat(target, 0.4)
		else:
			if game.has_method("receive_wolf_bite"):
				game.call("receive_wolf_bite", bite_damage, global_position,werewolf)
			else:
				game.call("damage_player", bite_damage)
			_begin_retreat(target, rng.randf_range(0.35, 0.55))
	_animate(_velocity.length(), _attack_pose > 0.0 or behavior == "warn")

func _pose(bone_name: String, angle: float) -> void:
	if _skeleton == null or not _joints.has(bone_name):
		return
	var joint: Array = _joints[bone_name]
	var rest: Quaternion = joint[1]
	_skeleton.set_bone_pose_rotation(int(joint[0]), rest * Quaternion(Vector3.RIGHT, angle))

func _animate(velocity: float, attacking: bool) -> void:
	if werewolf:
		model.set_motion(velocity,false,false,attacking or behavior=="maul")
		return
	var activity: float = clampf(velocity / 2.5, 0.0, 1.0)
	var phase: float = _time * (9.5 / sqrt(size_scale)) + _phase
	for side: String in ["L", "R"]:
		var offset: float = 0.0 if side == "L" else PI
		var fore: float = sin(phase + offset) * activity
		var rear: float = sin(phase + offset + PI) * activity
		var front_zone: String = "front_left" if side == "L" else "front_right"
		var rear_zone: String = "rear_left" if side == "L" else "rear_right"
		fore *= 1.0 - float(leg_injuries.get(front_zone, 0.0)) * 0.8
		rear *= 1.0 - float(leg_injuries.get(rear_zone, 0.0)) * 0.8
		_pose("FrontLeg1_" + side, fore * 0.36)
		_pose("FrontLeg2_" + side, maxf(0.0, -fore) * 0.45)
		_pose("FrontLeg3_" + side, -fore * 0.13)
		_pose("BackLeg1_" + side, rear * 0.38)
		_pose("BackLeg2_" + side, -maxf(0.0, -rear) * 0.42)
		_pose("BackLeg3_" + side, rear * 0.18)
	_pose("Neck1", sin(phase * 2.0) * 0.035 * activity + (-0.32 if behavior == "maul" else (0.10 if attacking else 0.0)))
	_pose("Head", (-0.18 if behavior == "maul" else -0.10) + sin(_time * 16.0) * 0.07 if attacking else sin(_time * 1.2 + _phase) * 0.025)
	_pose("Jaw1", (0.40 + sin(_time * 16.0) * 0.16) if behavior == "maul" else (0.15 + sin(_time * 16.0) * 0.10 if attacking else 0.015))
	for i: int in range(1, 5):
		_pose("Tail%d" % i, sin(phase * 0.5 - float(i) * 0.5) * 0.06)
	if not severed_legs.is_empty():
		model.position.y = (-0.08 + absf(sin(phase * 0.7)) * 0.025 * activity) * size_scale
		model.rotation.z = (0.12 if severed_legs[0].ends_with("left") else -0.12) + sin(phase) * 0.035 * activity

func _hunt_wildlife(delta: float) -> bool:
	prey_timer -= delta
	if not is_instance_valid(prey) or prey.dead or position.distance_to(prey.position)>25:
		prey = null
		if prey_timer>0: return false
		prey_timer = rng.randf_range(4,10)
		for animal in game.nodes_in_group("wildlife"):
			if not animal.dead and position.distance_to(animal.position)<18 and rng.randf()<.55:
				prey = animal
				break
	if not is_instance_valid(prey): return false
	var direction: Vector3 = prey.position-position
	direction.y = 0
	if direction.length()<1.2*size_scale:
		if _attack_cooldown<=0:
			prey.damage(bite_damage*1.5,false)
			_attack_cooldown = .9
			_attack_pose = .8
	else:
		direction = direction.normalized()
		var movement: Vector3 = direction*speed*1.7*injury_speed_scale*delta
		position = _move_scaled(movement.x,movement.z)
		rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),delta*5)
	_animate(speed*1.7,false)
	return true

func _hunt_raider(delta: float,hunter: Node3D) -> bool:
	if game.get("free_play") or behavior=="maul": return false
	var prey: Node3D
	var distance: float=minf(18.0,position.distance_to(hunter.position))
	for actor in game.nodes_in_group("campaign_threats"):
		if actor.species!="raider" or actor.dead: continue
		var d: float=position.distance_to(actor.position)
		if d<distance and nav.line_clear(position.x,position.z,actor.position.x,actor.position.z): prey=actor; distance=d
	if not prey: return false
	var direction: Vector3=prey.position-position; direction.y=0
	position=_move_scaled(direction.normalized().x*speed*1.3*delta,direction.normalized().z*speed*1.3*delta)
	rotation.y=lerp_angle(rotation.y,atan2(direction.x,direction.z),delta*7)
	_attack_cooldown=maxf(0,_attack_cooldown-delta)
	if distance<1.7 and _attack_cooldown<=0:
		prey.damage(bite_damage); _attack_cooldown=1.5; _bark()
	_animate(speed*1.3,distance<1.7)
	return true

func _ensure_reaction() -> void:
	if not reaction and is_instance_valid(model):
		reaction = preload("res://scripts/animal_reaction.gd").new()
		reaction.animal = self
		add_child(reaction)
