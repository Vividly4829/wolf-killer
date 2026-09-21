extends SceneTree

const Wolf=preload("res://scripts/wolf.gd")
const Profile=preload("res://scripts/wolf_profile.gd")
const Nav=preload("res://scripts/island_nav.gd")
const Main=preload("res://scripts/main.gd")

class Prey extends Node3D:
	var is_crouching:=false
	func get_visibility() -> float: return 1.0
	func get_noise_level() -> float: return .03
class Sounds extends Node:
	var pitches: Array[float]=[]
	func play_at(_kind: String,_point: Vector3,_volume: float=-12.0,pitch: float=1.0) -> void: pitches.append(pitch)
class Gore extends Node3D:
	var limb_scale:=0.0
	func blood_burst(_point: Vector3,_direction: Vector3,_intensity: float=1.) -> void: pass
	func blood_pool(_point: Vector3,_size: float=.25) -> void: pass
	func severed_limb(_point: Vector3,_direction: Vector3,_coat: Color,_size: float=1.) -> void: limb_scale=_size
class Ground extends Node3D:
	var nav: RefCounted
	var exterior_rally_point:=Vector3(0,0,5)
class Fixture extends Node3D:
	var player: Prey
	var world: Ground
	var sounds: Sounds
	var gore: Gore
	var wolves: Array[Node3D]=[]
	var damage_total:=0.0
	var defeats:=0
	func is_playing() -> bool: return true
	func is_player_safe() -> bool: return false
	func damage_player(amount: float) -> void: damage_total+=amount
	func wolf_defeated(_wolf: Node3D) -> void: defeats+=1

var game: Fixture
var nav: RefCounted
var checks:=0
var failures: Array[String]=[]
var small_seed:=0
var large_seed:=0
var bold_seeds: Array[int]=[]
var shy_seeds: Array[int]=[]

func _initialize() -> void: call_deferred("run_checks")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition: failures.append(message)

func make_wolf(point: Vector3, profile_seed: int) -> Node3D:
	var wolf:=Wolf.new()
	wolf.configure(game,nav,1,profile_seed)
	game.add_child(wolf)
	wolf.position=point
	wolf.set_physics_process(false)
	game.wolves.append(wolf)
	return wolf

func simulate(seconds: float) -> void:
	for step: int in ceili(seconds*60.):
		for wolf: Node3D in game.wolves:
			if is_instance_valid(wolf): wolf._physics_process(1./60.)

func run_checks() -> void:
	AudioServer.set_bus_mute(0,true)
	var smallest:=INF
	var largest:=0.0
	for seed_value: int in 2500:
		var candidate:=Profile.generate(1,seed_value)
		if float(candidate.size_scale)<smallest:
			smallest=float(candidate.size_scale)
			small_seed=seed_value
		if float(candidate.size_scale)>largest:
			largest=float(candidate.size_scale)
			large_seed=seed_value
		if float(candidate.boldness)>.76 and bold_seeds.size()<4: bold_seeds.append(seed_value)
		if float(candidate.boldness)<.28 and shy_seeds.size()<4: shy_seeds.append(seed_value)
	game=Fixture.new()
	root.add_child(game)
	game.player=Prey.new()
	game.add_child(game.player)
	game.sounds=Sounds.new()
	game.add_child(game.sounds)
	game.gore=Gore.new()
	game.add_child(game.gore)
	game.world=Ground.new()
	game.add_child(game.world)
	nav=Nav.new()
	var heights: Array=[]
	heights.resize(201*201)
	heights.fill(0.)
	var blocked:=PackedByteArray()
	blocked.resize(201*201)
	nav.setup({"width":201,"depth":201,"cellSize":.5,"origin":[-50.,-50.],"heights":heights,"blocked":blocked})
	nav.field(0,0)
	game.world.nav=nav
	var small:=make_wolf(Vector3(-3,0,4),small_seed)
	var large:=make_wolf(Vector3(3,0,4),large_seed)
	check(small.size_scale<.85 and large.size_scale>1.18,"Real configured wolves preserve both generated size extremes")
	check(small.profile.is_read_only() and large.profile.is_read_only(),"Birth profiles are immutable after configuration")
	check(small.health==float(small.profile.max_health) and large.speed==float(large.profile.walk_speed) and large.charge_speed==float(large.profile.charge_speed),"Live health and both movement speeds consume profile values")
	check(large.bite_damage>small.bite_damage and large.get_struggle_resistance()>small.get_struggle_resistance(),"Size-linked damage and struggle strength affect real actors")
	check(small.is_alpha and not large.is_alpha and large.size_scale>small.size_scale,"The first social leader is not forced to be the largest animal")
	check(small._coat_material!=large._coat_material and small._coat_material.shader==large._coat_material.shader,"Wolves share compiled shader code but own separate tint materials")
	var small_color: Color=small._coat_material.get_shader_parameter("coat_dark")
	large._coat_material.set_shader_parameter("coat_dark",Color.RED)
	check(small._coat_material.get_shader_parameter("coat_dark")==small_color,"Changing one coat material cannot tint its packmate")
	large._coat_material.set_shader_parameter("coat_dark",large.profile.coat_dark)
	for wolf: Node3D in [small,large]:
		var body: CollisionShape3D=wolf._hit_zones.body.get_child(0)
		var head: CollisionShape3D=wolf._hit_zones.head.get_child(0)
		var leg: CollisionShape3D=wolf._hit_zones.front_left.get_child(0)
		check(is_equal_approx(body.shape.radius,.27*wolf.size_scale) and is_equal_approx(head.shape.radius,.30*wolf.size_scale) and is_equal_approx(leg.shape.height,.5*wolf.size_scale),"Collision resources resize with the visible body at seed %d"%wolf.profile.profile_seed)
		check(body.scale==Vector3.ONE and head.scale==Vector3.ONE and leg.scale==Vector3.ONE and wolf.scale==Vector3.ONE,"Physics nodes keep unit scale at seed %d"%wolf.profile.profile_seed)
		check(leg.position.is_equal_approx(Vector3(.16,.28,.42)*wolf.size_scale) and is_equal_approx(wolf.model.scale.x,.27931*wolf.size_scale),"Model and limb target positions scale together at seed %d"%wolf.profile.profile_seed)
		wolf._growl()
	check(game.sounds.pitches.has(float(small.profile.voice_pitch)) and game.sounds.pitches.has(float(large.profile.voice_pitch)),"Spatial voices receive each animal's actual pitch")
	# Isolate commitment eligibility from each animal's randomized first warning.
	for member: Node3D in [small,large]:
		member.alerted=true
		member.warned=true
		member._warning_until=0.
		member._attack_cooldown=0.
		member._personal_caution_until=0.
		member._commit_wait=0.
	small._pack.next_commit=0.
	small._pack.caution_until=0.
	check(small._can_start_charge(small._pack_members()) and not large._can_start_charge(large._pack_members()),"An eligible nearby leader receives a brief first commitment opportunity")
	large._commit_wait=.95
	check(large._can_start_charge(large._pack_members()),"A hesitant leader cannot indefinitely prevent a ready follower from committing")
	await physics_frame
	await physics_frame
	for wolf: Node3D in [small,large]:
		var leg: CollisionShape3D=wolf._hit_zones.front_left.get_child(0)
		var target: Vector3=leg.global_position-Vector3.UP*.10*wolf.size_scale
		var ray:=PhysicsRayQueryParameters3D.create(target+Vector3.RIGHT*1.2,target-Vector3.RIGHT*1.2,2)
		ray.collide_with_areas=true
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider.get_meta("wolf")==wolf and str(hit.collider.get_meta("hit_zone"))=="front_left","Physical rays reach the correctly scaled leg at seed %d"%wolf.profile.profile_seed)
	large.receive_hit(80.,large.position+Vector3.UP*.4,Vector3.LEFT,"front_left")
	var stump: Node3D=large.model.get_node("WoundStump_front_left")
	check(is_equal_approx(stump.global_basis.get_scale().x,large.size_scale) and is_equal_approx(game.gore.limb_scale,large.size_scale),"Wound stump and world-space detached leg preserve the source animal's size")
	for wolf: Node3D in game.wolves: wolf.free()
	game.wolves.clear()
	var leader:=make_wolf(Vector3(0,0,4),72)
	for i: int in 6:
		var seed_value: int=bold_seeds[i/2] if i%2==0 else shy_seeds[i/2]
		var member:=make_wolf(Vector3(float(i-3)*.75,0,3.2),seed_value)
		member.hear_gunshot(Vector3.ZERO)
	leader.hear_gunshot(Vector3.ZERO)
	var distant:=make_wolf(Vector3(38,0,38),121)
	simulate(1.25)
	check(leader.role=="lead" and int(leader._pack.serial)>0,"The living leader guides pack positioning while coordinated attacks proceed")
	var survivor_health: Dictionary={}
	var assignments: Dictionary={}
	for member: Node3D in game.wolves:
		survivor_health[member.get_instance_id()]=member.health
		assignments[member.get_instance_id()]=Vector2i(member.pack_slot,member.flank_side)
	leader.damage(999.)
	var debug: Dictionary=distant.get_pack_debug()
	check(leader.dead and leader.is_alpha and debug.disruption_left>=5.4 and debug.charge_limit==1,"Leader death retains corpse identity and briefly reduces simultaneous pack rushes")
	check(distant.pack_reaction_count==0 and distant.awareness<.12 and not distant.alerted,"A distant unaware wolf receives no instant casualty knowledge")
	var responses: Dictionary={}
	var witnesses:=0
	for member: Node3D in game.wolves:
		if member!=leader and member!=distant:
			responses[member.leader_reaction]=true
			witnesses+=int(member.last_pack_event=="leader_killed")
	check(witnesses==6 and responses.size()>=2,"Nearby individuals vary between holding ground and withdrawing after the loss")
	var damage_before: float=game.damage_total
	simulate(8.0)
	var successor: Node3D=null
	var alpha_count:=0
	var preserved:=true
	for member: Node3D in game.wolves:
		if member.dead: continue
		alpha_count+=int(member.is_alpha)
		if member.is_alpha: successor=member
		preserved=preserved and is_equal_approx(member.health,float(survivor_health[member.get_instance_id()])) and Vector2i(member.pack_slot,member.flank_side)==assignments[member.get_instance_id()]
	check(alpha_count==1 and successor!=distant and not successor.profile.leader_at_birth,"A surviving witness assumes leadership after recovery without changing its birth profile")
	check(preserved,"Succession preserves health and stable flank assignments")
	check(game.damage_total>damage_before and distant.get_pack_debug().disruption_left==0.,"Survivors resume dangerous pursuit after a bounded recovery")
	var prior_until: float=distant._pack.disruption_until
	if successor: successor.damage(999.)
	check(is_equal_approx(float(distant._pack.disruption_until),prior_until),"A rapid successor death cannot repeatedly extend full-pack disruption")
	var reacquiring: Node3D=null
	for member: Node3D in game.wolves:
		if not member.dead and member!=distant:
			reacquiring=member
			break
	reacquiring.warned=true
	reacquiring.alerted=false
	reacquiring._leader_caution_until=float(reacquiring._pack.clock)+.4
	reacquiring._enter_state("regroup",99.)
	reacquiring._alert_to(Vector3.ZERO)
	simulate(1.2)
	check(reacquiring.alerted and reacquiring.behavior!="regroup","Reacquiring a target while regrouping cannot leave a previously warned wolf frozen")
	for member: Node3D in game.wolves:
		if is_instance_valid(member): member.free()
	game.wolves.clear()
	var unseen_leader:=make_wolf(Vector3(0,0,4),72)
	var distant_members: Array[Node3D]=[]
	for i: int in 3:
		distant_members.append(make_wolf(Vector3(35+i,0,38),121+i))
	unseen_leader.damage(999.)
	var waiting: Node3D=distant_members[0]
	waiting._pack.clock=float(waiting._pack.succession_at)+.01
	waiting._tick_pack_leadership()
	var retry_at: float=waiting._pack.succession_at
	check(is_equal_approx(retry_at,float(waiting._pack.clock)+1.0) and waiting._pack.succession_pending,"An unseen leader loss schedules a shared one-second retry when no witness qualifies")
	for frame: int in 50:
		waiting._pack.clock+=1./60.
		for member: Node3D in distant_members: member._tick_pack_leadership()
	check(is_equal_approx(float(waiting._pack.succession_at),retry_at),"Every packmate respects the existing retry deadline instead of repeating an unsuccessful succession search")
	waiting._pack.clock=retry_at+.01
	waiting._tick_pack_leadership()
	var unaware:=true
	for member: Node3D in distant_members:
		unaware=unaware and not member.is_alpha and not member.alerted and member.awareness==0.0 and member.pack_reaction_count==0
	check(unaware and is_equal_approx(float(waiting._pack.succession_at),retry_at+1.01),"A due retry advances once without inventing a leader or awareness among distant non-witnesses")
	game.queue_free()
	await process_frame
	await process_frame
	await check_real_island()
	for failure: String in failures: push_error(failure)
	print("%s: %d live wolf variation and leader checks; size seeds %d/%d."%["PASS" if failures.is_empty() else "FAIL",checks,small_seed,large_seed])
	quit(0 if failures.is_empty() else 1)

func check_real_island() -> void:
	var island:=Main.new()
	var save_path: String="user://wolf_variant_test_%s.cfg"%OS.get_process_id()
	island.progress.save_path=save_path
	root.add_child(island)
	await physics_frame
	island.start_run()
	island.intermission=false
	island.pending_spawns=1
	island.player.reset_at(island.world.nav.point(island.world.nav.nearest(-1.,4.75,1.)))
	var spawn: Vector3=island.world.wolf_nav.point(island.world.wolf_nav.nearest(-1.,15.,2.))
	island._add_wolf_at(spawn,large_seed)
	var wolf: Node3D=island.wolves.back()
	wolf.hear_gunshot(island.player.position)
	island._update_pursuit()
	var valid_positions:=true
	var attack_at:=-1.0
	for frame: int in 1500:
		await physics_frame
		valid_positions=valid_positions and island.world.wolf_nav.valid(island.world.wolf_nav.at(wolf.position.x,wolf.position.z)) and not island.world.is_safe_position(wolf.position)
		if island.is_struggling():
			attack_at=float(frame+1)/60.
			break
	check(wolf.size_scale>1.18 and valid_positions,"Exceptional-large wolf remains on valid real-island terrain outside the cabin")
	check(attack_at>0. and attack_at<25.,"Exceptional-large wolf navigates the actual lawn and latches onto an exposed doorway player")
	print("LARGE_ISLAND_PURSUIT: first latch %.2fs, size %.3f, position %s"%[attack_at,wolf.size_scale,str(wolf.position)])
	island.queue_free()
	await process_frame
	await process_frame
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
