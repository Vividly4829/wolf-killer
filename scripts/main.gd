extends Node3D

const WorldScript = preload("res://scripts/island_world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const WolfScript = preload("res://scripts/wolf.gd")
const ProgressScript = preload("res://scripts/progress_store.gd")
const HudScript = preload("res://scripts/hud.gd")
const SoundScript = preload("res://scripts/soundscape.gd")
const GoreScript = preload("res://scripts/gore_effects.gd")
const WeaponCatalog = preload("res://scripts/weapon_catalog.gd")
const WeaponModelBuilder = preload("res://scripts/weapon_model_builder.gd")
const BoltScript = preload("res://scripts/crossbow_bolt.gd")
const WOLF_SPAWN_MIN_DISTANCE := 28.0
const WOLF_SPAWN_MAX_DISTANCE := 42.0
const WOLF_SPAWN_SPACING := 2.5
const WEAPONS: Array[Dictionary] = WeaponCatalog.WEAPONS

var controller_device := -1
var split_session: Node
var combat_fx: Node3D
var world: Node3D
var player: Node3D
var hud_detail_left := 0.0
var hud: Control
var shot_review: Control
var sounds: Node
var progress = ProgressScript.new()
var wolves: Array[Node3D] = []
var free_play := false
var campaign_progress: RefCounted
var free_respawn := 0.0
var mode: String = "menu"
var level: int = 1
var menu_start_level := 1
var menu_start_money := -1 # Unchanged means preserve the saved wallet.
var session_start_money := -1
var health: float = 100.0
var affliction: Node
func maximum_health() -> float:
	return affliction.maximum_health() if affliction else 100.0

var current_weapon: int = 0
var current_slot:=0
var copy_magazines: Array[Dictionary]=[]
var ammo: Array[int] = WeaponCatalog.full_magazines()
var reserve_ammo: Array[int] = WeaponCatalog.full_reserves()
var lemat_secondary: bool = false
var lemat_shot_ammo: int = 1
var lemat_shot_reserve: int = 4
var _reload_weapon_id: int = -1
var _reload_secondary: bool = false
var reload_left: float = 0.0
var fire_cooldown: float = 0.0
var quick_throw_left:=0.0
var intermission: bool = true
var wave_countdown: float = 15.0
var wave_total: int = 3
var pending_spawns: int = 0
var wave_kills: int = 0
var run_kills: int = 0
var survived: float = 0.0
var nav_timer: float = 0.0
var spawn_timer: float = 0.0
var notice: String = ""
var notice_left: float = 0.0
var hit_flash: float = 0.0
var damage_flash: float = 0.0
var death_level: int = 1
var menu_camera: Camera3D
var started: bool = false
const OPENING_LINE := "Should go out and do something about these wolves."
var dialogue_left: float = 0.0
var last_reload_stage: String = ""
var last_pursuit_cell: int = -1
var gore: Node3D
var rest_left: float = 0.0
var bandages: int = 2
var bandage_left: float = 0.0
var struggle_wolf: Node3D
var struggle_progress: float = 0.0
var struggle_tick: float = 0.0
var struggle_grace: float = 0.0
var run_bites: int = 0
var reload_duration: float = 6.5
var spotted_wolves: Dictionary = {}
var spotting_timer: float = 0.0
var blood_timer: float = 0.0
var focused_wolf: WeakRef
var werewolf_spawned := false
var campaign: Node
var coop: Node

func weapon_spec() -> Dictionary:
	return WeaponCatalog.secondary_weapon() if current_weapon == 9 and lemat_secondary else WeaponCatalog.weapon(current_weapon)

func current_ammo() -> int:
	return lemat_shot_ammo if current_weapon == 9 and lemat_secondary else ammo[current_weapon]

func current_reserve() -> int:
	return lemat_shot_reserve if current_weapon == 9 and lemat_secondary else reserve_ammo[current_weapon]

func weapon_display_name() -> String:
	var count: int=progress.owned.count(current_weapon)
	if count<2: return str(WEAPONS[current_weapon].name)
	var number:=0
	for i in mini(current_slot+1,progress.owned.size()):
		if progress.owned[i]==current_weapon: number+=1
	return "%s / COPY %d OF %d"%[WEAPONS[current_weapon].name,number,count]

func _sync_weapon_visual() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.weapon):
		return
	if player.weapon.has_method("set_secondary"):
		player.weapon.set_secondary(current_weapon == 9 and lemat_secondary)
	if player.weapon.has_method("set_loaded"):
		player.weapon.set_loaded(current_ammo() > 0)
	if current_weapon in [30,31,32]: player.weapon.set_dual_ammo(current_ammo())

func _replenish_ammunition() -> void:
	ammo = WeaponCatalog.full_magazines()
	reserve_ammo = WeaponCatalog.full_reserves()
	for index in WEAPONS.size(): reserve_ammo[index]*=maxi(1,progress.owned.count(index))
	lemat_shot_ammo = 1
	lemat_shot_reserve = 4*maxi(1,progress.owned.count(9))
	copy_magazines.clear(); _ensure_copy_magazines()
	if current_slot>=progress.owned.size() or current_slot<0 or progress.owned[current_slot]!=current_weapon:
		current_slot=progress.owned.find(current_weapon)
	_reload_weapon_id = -1
	_sync_weapon_visual()

func _clear_projectiles() -> void:
	for bolt in nodes_in_group("player_bolts"):
		bolt.queue_free()

func _ready() -> void:
	name = "WolfIsland"
	get_tree().set_multiplayer(SceneMultiplayer.new(),get_path())
	# Prepare immutable model resources during loading, before browsing or combat.
	WeaponModelBuilder.warm_cache()
	if OS.get_cmdline_user_args().has("--qa"):
		progress.save_path = "user://qa_progress.cfg"
	else:
		progress.load_progress()
	world = WorldScript.new()
	add_child(world)
	combat_fx=preload("res://scripts/combat_fx.gd").new(); combat_fx.game=self; add_child(combat_fx)
	gore = GoreScript.new()
	add_child(gore)
	player = PlayerScript.new()
	add_child(player)
	player.configure(self, world.nav)
	player.reset_at(world.spawn_position)
	menu_camera = Camera3D.new()
	add_child(menu_camera)
	menu_camera.position = Vector3(12, 16, 25)
	menu_camera.look_at(Vector3(-2, 4, -2))
	menu_camera.fov = 65
	menu_camera.current = true
	sounds = SoundScript.new()
	add_child(sounds)
	coop = preload("res://scripts/coop_session.gd").new()
	coop.game = self
	add_child(coop)
	campaign = preload("res://scripts/campaign_director.gd").new()
	campaign.game = self
	add_child(campaign)
	affliction = preload("res://scripts/lycanthropy.gd").new()
	affliction.game = self
	add_child(affliction)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = HudScript.new()
	hud.game = self
	canvas.add_child(hud)
	var blood_hud=preload("res://scripts/damage_overlay.gd").new()
	blood_hud.game=self; canvas.add_child(blood_hud)
	shot_review = preload("res://scripts/shot_review.gd").new()
	shot_review.game = self
	hud.add_child(shot_review)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().auto_accept_quit = false
	if OS.get_cmdline_user_args().has("--qa"):
		call_deferred("_run_visual_qa")

func is_playing() -> bool:
	return mode == "playing" or (is_instance_valid(coop) and coop.active and mode in ["shop","paused","waiting"])

func is_player_safe() -> bool:
	return is_instance_valid(world) and is_instance_valid(player) and world.is_safe_position(player.position)

func is_struggling() -> bool:
	return is_instance_valid(struggle_wolf) and not struggle_wolf.dead

func _update_pursuit() -> void:
	# Navigation follows an observed cue, never the hidden player's live location.
	var target := Vector3.INF
	for wolf in wolves:
		if is_instance_valid(wolf):
			var cue: Vector3 = wolf.get_pursuit_target()
			if cue.is_finite():
				target = cue
				if wolf.alerted:
					break
	if not target.is_finite():
		if last_pursuit_cell >= 0:
			return
		target = world.exterior_rally_point
	if world.is_safe_position(target):
		target = world.exterior_rally_point
	var target_cell: int = world.wolf_nav.at(target.x, target.z)
	if target_cell != last_pursuit_cell:
		world.wolf_nav.request_field(target.x, target.z)
		last_pursuit_cell = target_cell

func _process(delta: float) -> void:
	hud_detail_left = maxf(0.0, hud_detail_left-delta)
	world.wolf_nav.pump_field()
	hit_flash = maxf(0, hit_flash - delta)
	damage_flash = maxf(0, damage_flash - delta)
	sounds.set_context(is_player_safe(), is_playing())
	if mode == "resting":
		rest_left = maxf(0.0, rest_left - delta)
		if rest_left == 0.0:
			finish_rest()
		return
	if not is_playing():
		return
	survived += delta
	dialogue_left = maxf(0.0, dialogue_left - delta)
	notice_left = maxf(0, notice_left - delta)
	fire_cooldown = maxf(0, fire_cooldown - delta)
	struggle_grace = maxf(0.0, struggle_grace - delta)
	quick_throw_left=maxf(0,quick_throw_left-delta)
	var bleeding: float = player.tick_injuries(delta)
	if bleeding > 0.0:
		_apply_health_damage(bleeding, false)
		blood_timer -= delta
		if blood_timer <= 0.0:
			gore.blood_pool(player.position, 0.08 + player.bleeding_rate * 0.025)
			blood_timer = 1.1
	if not is_playing():
		return
	if is_struggling():
		_update_struggle(delta)
	elif is_instance_valid(struggle_wolf):
		end_wolf_struggle(false)
	if not is_playing():
		return
	if bandage_left > 0.0:
		bandage_left = maxf(0.0, bandage_left - delta)
		if bandage_left == 0.0:
			player.stop_bleeding()
			bandages -= 1
			show_notice("Bleeding stopped. Other injuries need first aid or rest.", 4)
	spotting_timer -= delta
	if spotting_timer <= 0.0:
		_update_spotted_wolves()
		spotting_timer = 0.2
	if reload_left > 0:
		reload_left = maxf(0, reload_left - delta)
		var stage: String = player.get_reload_stage()
		if not stage.is_empty() and stage != last_reload_stage:
			last_reload_stage = stage
			sounds.play("reload", -23)
		if reload_left == 0:
			_finish_reload()
			sounds.play("reload", -18)
	if coop.client(): return
	if free_play:
		reserve_ammo = WeaponCatalog.full_reserves()
		for index in [24,25]: ammo[index]=1
		lemat_shot_reserve = 4
		free_respawn -= delta
		if free_respawn<=0: _spawn_free_animals()
		return
	if intermission:
		# Preparation waits indoors. Crossing the cabin boundary begins the hunt.
		if not is_player_safe() or coop.anyone_outside():
			wave_countdown = maxf(0.0, wave_countdown - delta)
			if wave_countdown <= 0:
				begin_wave()
	else:
		nav_timer -= delta
		if nav_timer <= 0:
			_update_pursuit()
			nav_timer = 0.25
		spawn_timer -= delta
		if pending_spawns > 0 and wolves.size() < 24 and spawn_timer <= 0:
			_spawn_wolf()
			spawn_timer = 0.7

func _unhandled_input(event: InputEvent) -> void:
	if controller_device>=0: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if mode == "weapon_stats":
				set_mode("menu")
			elif mode == "shop":
				close_shop()
			elif mode == "playing":
				set_mode("paused")
			elif mode == "paused":
				set_mode("playing")
		elif event.physical_keycode == KEY_ENTER and mode=="playing" and intermission:
			begin_wave()
		elif event.physical_keycode == KEY_B and is_playing():
			use_bandage()
		elif event.physical_keycode == KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "playing" and not OS.get_cmdline_user_args().has("--qa"):
		set_mode("paused")

func set_mode(value: String) -> void:
	mode = value
	if controller_device<0: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "playing" else Input.MOUSE_MODE_VISIBLE
	if hud:
		hud.refresh_panel()

func start_free_play() -> void:
	coop.leave()
	start_run(true)
func restore_campaign() -> void:
	if campaign_progress:
		progress = campaign_progress
		campaign_progress = null
	free_play = false
func start_from_menu() -> void:
	hud.commit_start_options()
	start_run(false,true)

func start_run(sandbox: bool = false, use_menu_settings: bool = false) -> void:
	coop.reset_round_earnings()
	combat_fx.shots.clear()
	restore_campaign()
	campaign.reset()
	free_play = sandbox
	if sandbox:
		campaign_progress = progress
		progress = ProgressScript.new()
		progress.transient = true
		progress.owned.assign(range(WEAPONS.size()))
	if affliction: affliction.infected_wave = -1
	for animal in nodes_in_group("wildlife"): animal.queue_free()
	if is_instance_valid(coop) and coop.client() and mode in ["dead","victory"]:
		coop.send_to(1,"restart_run",[])
		return
	end_wolf_struggle(false)
	focused_wolf = null
	_clear_projectiles()
	for wolf in wolves:
		if is_instance_valid(wolf):
			wolf.queue_free()
	wolves.clear()
	for corpse in nodes_in_group("wolf_corpses"):
		corpse.queue_free()
	gore.clear()
	spotted_wolves.clear()
	player.clear_injuries()
	bandages = 2
	bandage_left = 0.0
	run_bites = 0
	struggle_grace = 0.0
	level = clampi(menu_start_level,1,30) if use_menu_settings and not sandbox else 1
	if use_menu_settings and not sandbox and menu_start_money>=0:
		session_start_money=clampi(menu_start_money,0,2000000000)
		progress.money=session_start_money
		progress.save_progress()
		menu_start_money=-1
	health = maximum_health()
	world.weather.wake(level)
	shot_review.reset_history()
	current_slot=0
	while progress.stowed.has(progress.owned[current_slot]): current_slot+=1
	current_weapon=progress.owned[current_slot]
	lemat_secondary = false
	_replenish_ammunition()
	reload_left = 0
	fire_cooldown = 0.3
	wave_kills = 0
	run_kills = 0
	pending_spawns = 0
	survived = 0
	last_pursuit_cell = -1
	nav_timer = 0.0
	intermission = true
	wave_countdown = 0.0
	wave_total = objective_total()
	player.reset_at(world.spawn_position)
	player.yaw = world.spawn_yaw
	player.pitch = -0.04
	player.set_weapon(current_weapon)
	_sync_weapon_visual()
	player.camera.current = true
	_update_pursuit()
	started = true
	set_mode("playing")
	if not coop.client(): world.houses.reroll()
	dialogue_left = 6.0
	show_notice("Leave the cabin to begin the hunt.", 8)
	coop.host_started()
	if free_play:
		intermission = false
		wave_total = 0
		pending_spawns = 0
		dialogue_left = 0
		world.weather.hour = 12
		world.weather.apply()
		player.reset_at(world.shooting_range.firing_point)
		player.yaw = world.shooting_range.facing_yaw
		player.pitch = 0
		player._update_rotation()
		_spawn_free_animals()
		show_notice("FREE PLAY / All weapons / Q or wheel to cycle / R to reload",8)

func wolves_for_level(number: int) -> int:
	var job: Dictionary = preload("res://scripts/campaign_catalog.gd").wave(number)
	return int(job.wolves)+int(job.bosses)

func begin_wave(announce: bool = true) -> void:
	if free_play: return
	if coop.client(): return
	if not is_playing() or not intermission:
		return
	if is_player_safe() and not coop.anyone_outside():
		show_notice("Leave the cabin to begin the hunt.", 3)
		return
	intermission = false
	campaign.begin()
	_update_pursuit()
	if announce: sounds.play("wave", -15)

func _spawn_wolf() -> void:
	if pending_spawns <= 0:
		return
	var reachable: PackedInt32Array = world.wolf_nav.reachable
	if reachable.is_empty():
		return
	var origin := Vector2(player.position.x, player.position.z)
	var minimum_squared := WOLF_SPAWN_MIN_DISTANCE * WOLF_SPAWN_MIN_DISTANCE
	var maximum_squared := WOLF_SPAWN_MAX_DISTANCE * WOLF_SPAWN_MAX_DISTANCE
	# Uniform rejection sampling avoids scanning the whole island for every wolf.
	# A bounded exhaustive fallback preserves sparse-shore and crowded-pack cases.
	for attempt in mini(128, reachable.size() * 2):
		var point: Vector3 = world.wolf_nav.point(reachable[randi_range(0, reachable.size() - 1)])
		var distance_squared := origin.distance_squared_to(Vector2(point.x, point.z))
		if distance_squared >= minimum_squared and _wolf_spawn_clear(point):
			_add_wolf_at(point)
			return
	var candidates: Array[int] = []
	var distant_candidates: Array[int] = []
	for value in reachable:
		var point: Vector3 = world.wolf_nav.point(value)
		var distance_squared := origin.distance_squared_to(Vector2(point.x, point.z))
		if distance_squared < minimum_squared or not _wolf_spawn_clear(point):
			continue
		if distance_squared <= maximum_squared:
			candidates.append(value)
		else:
			distant_candidates.append(value)
	if candidates.is_empty():
		# A narrow shore may need a farther spawn; never fall back beside the player.
		candidates = distant_candidates
	if candidates.is_empty():
		return
	var spawn: Vector3 = world.wolf_nav.point(candidates.pick_random())
	_add_wolf_at(spawn)

func _wolf_spawn_clear(point: Vector3) -> bool:
	if world.is_safe_position(point):
		return false
	for other: Node3D in wolves:
		if Vector2(point.x - other.position.x, point.z - other.position.z).length_squared() < WOLF_SPAWN_SPACING * WOLF_SPAWN_SPACING:
			return false
	return true

func _add_wolf_at(spawn: Vector3, profile_seed: int = -1) -> void:
	var wolf: Node3D = WolfScript.new()
	wolf.configure(self, world.wolf_nav, level, profile_seed)
	add_child(wolf)
	wolf.position = spawn
	if level % 5 == 0 and not werewolf_spawned:
		wolf.make_werewolf()
		werewolf_spawned = true
	wolves.append(wolf)
	pending_spawns -= 1

func objective_species() -> String:
	var job: Dictionary = campaign.job if campaign and campaign.running else preload("res://scripts/campaign_catalog.gd").wave(level)
	var keys: Array = job.hunt.keys()+job.kill.keys()
	return str(keys[0]) if keys.size()==1 else "mission"
func objective_total() -> int:
	return preload("res://scripts/campaign_catalog.gd").total(preload("res://scripts/campaign_catalog.gd").wave(level,1+coop.avatars.size() if coop else 1))
func wildlife_defeated(animal: Node3D) -> void:
	if free_play or coop.client() or intermission or not is_playing(): return
	campaign.animal_killed(animal)
func complete_wave() -> void:
	if coop.client() or not is_playing() or not campaign.job_ready(): return
	if coop.active and not coop.any_living(): return
	progress.earn(40+level*8)
	coop.award(40+level*8)
	progress.best_level=maxi(progress.best_level,level)
	progress.save_progress()
	campaign.running=false
	if level>=30:
		campaign.finished=true
		set_mode("victory")
		return
	level+=1
	intermission=true
	wave_countdown=0
	campaign.clear_round()
	begin_rest()
func objective_targets() -> Array[Node3D]:
	if campaign and not free_play: return campaign.target_nodes()
	var empty: Array[Node3D]=[]
	return empty

func nodes_in_group(group: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group):
		if is_ancestor_of(node): result.append(node)
	return result

func frighten_wildlife(origin: Vector3,radius: float) -> void:
	if campaign and not coop.client(): campaign.shot_fired(origin)
	for animal in nodes_in_group("wildlife"):
		if not animal.is_queued_for_deletion() and not animal.dead and animal.position.distance_to(origin)<radius: animal.frighten(origin,12.0)
func _spawn_wildlife() -> void:
	for animal in nodes_in_group("wildlife"): animal.queue_free()
	var species_list: Array = ["deer","deer","duck","duck","goose","mink"]
	if level<=2: species_list = ["deer","deer","deer","deer","duck","goose","mink"]
	if level==3: species_list = ["deer","deer","duck","duck","goose","goose","goose","mink"]
	var local_count := species_list.size()
	# Additional wildlife across the connected map, independent of the quota.
	species_list.append_array(["deer","deer","deer","deer","deer","deer","duck","duck","duck","goose","goose","mink","mink"])
	var nearby: Array[int] = []
	for cell in world.wolf_nav.reachable:
		var point: Vector3 = world.wolf_nav.point(cell)
		var distance := point.distance_to(world.exterior_rally_point)
		if distance>22 and distance<65 and not world.is_safe_position(point): nearby.append(cell)
	var used: Array[Vector3] = []
	for animal_index in species_list.size():
		var species: String = species_list[animal_index]
		var animal := preload("res://scripts/wildlife.gd").new()
		animal.game = self
		animal.species = species
		var candidates = nearby if animal_index<local_count and level<=3 and not nearby.is_empty() else world.wolf_nav.reachable
		var best_position:=Vector3.ZERO
		var best_score:=-INF
		for attempt in 50:
			var candidate: Vector3=world.wolf_nav.point(candidates[randi_range(0,candidates.size()-1)])
			var spacing:=8.0
			for p in used: spacing=minf(spacing,p.distance_to(candidate))
			var room: float=animal.land_room(candidate) if species=="deer" else 1.0
			var score:=spacing+room*6
			if score>best_score: best_position=candidate; best_score=score
			if spacing>=6 and room>=.625 and candidate.y>.1:
				best_position=candidate; break
		animal.position=best_position
		if species=="goose" and level==3:
			animal.aquatic = true
			animal.position = Vector3(11+randf_range(-2,2),-.1,35+randf_range(-5,5))
			animal.water_home = animal.position
		used.append(animal.position)
		add_child(animal)

func wolf_defeated(wolf: Node3D) -> void:
	if not wolves.has(wolf):
		return
	if wolf == struggle_wolf:
		end_wolf_struggle(false)
	spotted_wolves.erase(wolf.get_instance_id())
	wolves.erase(wolf)
	if free_play: return
	campaign.animal_killed(wolf)
	run_kills += 1
	progress.earn(25)
	coop.award(25)
	sounds.play("coin", -21)
	show_notice("+25 CREDITS  /  Alpha defeated" if wolf.is_alpha else "+25 CREDITS  /  Wolf defeated", 2.5 if wolf.is_alpha else 1.7)


func begin_rest() -> void:
	coop.reset_round_earnings()
	if not coop.client(): world.houses.reroll()
	world.weather.wake(level)
	end_wolf_struggle(false)
	_clear_projectiles()
	health = maximum_health()
	player.clear_injuries()
	_replenish_ammunition()
	reload_left = 0.0
	bandage_left = 0.0
	bandages = 2
	player.reset_at(coop.local_spawn if coop.active else world.bed_position)
	player.yaw = coop.local_yaw if coop.active else world.bed_yaw
	player.pitch = -0.12
	player.camera.position.y = 0.85
	player._update_rotation()
	player.weapon.visible = false
	dialogue_left = 0.0
	rest_left = 3.5
	set_mode("resting")

func finish_rest() -> void:
	player.reset_at(coop.local_spawn if coop.active else world.bed_wake_position)
	player.yaw = coop.local_yaw if coop.active else world.bed_wake_yaw
	player.pitch = -0.04
	player._update_rotation()
	player.weapon.visible = true
	fire_cooldown = 0.5
	set_mode("playing")
	show_notice("Rested. Wounds healed. Leave the cabin when you are ready.", 7)

func _update_spotted_wolves() -> void:
	_update_wolf_focus()
	for id in spotted_wolves.keys():
		if survived - float(spotted_wolves[id].seen_at) > 4.0:
			spotted_wolves.erase(id)
	var camera: Camera3D = player.camera
	for wolf in wolves:
		if not is_instance_valid(wolf) or wolf.dead:
			continue
		var point: Vector3 = wolf.position + Vector3.UP * 0.7 * float(wolf.size_scale)
		var offset: Vector3 = point - camera.global_position
		if offset.length() > 46.0 or (-camera.global_basis.z).dot(offset.normalized()) < 0.73:
			continue
		var sight := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1)
		if get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			spotted_wolves[wolf.get_instance_id()] = {"position": wolf.position, "seen_at": survived}

func _update_wolf_focus() -> void:
	focused_wolf = null
	if not is_playing() or is_struggling():
		return
	var camera: Camera3D = player.camera
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 40.0, 3)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Node = hit.collider
	var wolf: Node = collider.get_meta("wolf") if collider.has_meta("wolf") else null
	if is_instance_valid(wolf) and not wolf.dead:
		focused_wolf = weakref(wolf)

func get_focused_wolf_text() -> String:
	if focused_wolf == null or not is_playing() or is_struggling():
		return ""
	var wolf: Node = focused_wolf.get_ref()
	if not is_instance_valid(wolf) or wolf.is_queued_for_deletion() or wolf.dead:
		return ""
	return str(wolf.get_identification()) if wolf.has_method("get_identification") else ""

func quick_throw() -> bool:
	if player.is_sprinting: return false
	if not is_playing() or is_struggling() or is_player_safe() or bandage_left>0 or quick_throw_left>0: return false
	_save_current_magazine()
	var best:=-1; var power:=-1.0
	for slot in progress.owned.size():
		var id: int=progress.owned[slot]
		if id not in [18,19,20] or progress.stowed.has(id): continue
		if int(copy_magazines[slot].loaded)+reserve_ammo[id]<=0: continue
		if float(WEAPONS[id].damage)>power: best=slot; power=float(WEAPONS[id].damage)
	if best<0: show_notice("No carried throwing weapons left.",2); return false
	var id: int=progress.owned[best]
	if int(copy_magazines[best].loaded)>0: copy_magazines[best].loaded-=1
	else: reserve_ammo[id]-=1
	if best==current_slot: ammo[id]=int(copy_magazines[best].loaded)
	var spec:=WeaponCatalog.weapon(id); spec.spread=float(spec.spread)*.65
	quick_throw_left=.24
	shot_review.begin_shot(true)
	var origin: Vector3=player.camera.global_position
	var direction: Vector3=-player.camera.global_basis.z
	direction=(direction+player.camera.global_basis.x*randf_range(-spec.spread,spec.spread)+Vector3.UP*randf_range(-spec.spread,spec.spread)).normalized()
	if coop.client(): coop.send_to(1,"quick_throw_shot",[origin,direction,id,shot_review.serial])
	else:
		var bolt:=BoltScript.new(); add_child(bolt); bolt.launch(self,origin+direction*.24,direction,spec)
	frighten_wildlife(player.position,3); sounds.play("crossbow",-10)
	player._quick_throw_pose=.24
	return true

func fire_weapon() -> void:
	if player.is_sprinting: return
	if not free_play and not progress.owned.has(current_weapon):
		show_notice("Used up. Buy another at the store.",3)
		return
	if mode != "playing": return
	if is_player_safe():
		show_notice("Lower your weapon indoors. Leave through either door to hunt.",2)
		return
	if not is_playing() or is_struggling() or bandage_left > 0 or fire_cooldown > 0 or reload_left > 0:
		return
	if current_ammo() <= 0:
		reload_weapon()
		return
	var weapon: Dictionary = weapon_spec()
	shot_review.begin_shot(float(weapon.projectile_speed) > 0.0)
	if current_weapon == 9 and lemat_secondary:
		lemat_shot_ammo -= 1
	else:
		ammo[current_weapon] -= 1

	fire_cooldown = float(weapon.interval)
	# Capture the shot before recoil moves the camera.
	var camera: Camera3D = player.camera
	var shot_transform := camera.global_transform
	player.play_shot()
	_sync_weapon_visual()
	sounds.play_weapon(str(weapon.sound))
	if coop.client():
		coop.submit_shot(shot_transform.origin,-shot_transform.basis.z,current_weapon,shot_review.serial,lemat_secondary)
		return
	coop.broadcast_gunshot(str(weapon.sound),shot_transform.origin,1)
	frighten_wildlife(player.position,float(weapon.noise_radius))
	for wolf in wolves:
		if is_instance_valid(wolf) and wolf.position.distance_to(player.position) <= float(weapon.noise_radius):
			wolf.hear_gunshot(player.position)
	for pellet in range(int(weapon.pellets)):
		if not is_playing():
			break
		var spread: float = maxf(float(weapon.spread) * player.get_aim_spread_multiplier(), .085 if player.is_sprinting else 0.0)
		if player.aim_held() and not player.is_sprinting:
			spread *= 0.58
		if player._actual_speed > 0.5:
			spread *= 1.0 + minf(1.5, player._actual_speed / 5.0)
		var direction := (-shot_transform.basis.z + shot_transform.basis.x * randf_range(-spread, spread) + shot_transform.basis.y * randf_range(-spread, spread)).normalized()
		var origin := shot_transform.origin
		if float(weapon.projectile_speed) > 0.0:
			var bolt := BoltScript.new()
			add_child(bolt)
			bolt.launch(self, origin + direction * 0.24, direction, weapon)
			continue
		var excluded: Array[RID]=[]
		if is_instance_valid(coop.local_area): excluded.append(coop.local_area.get_rid())
		fire_ballistic(origin,direction,weapon,shot_review.serial,1,excluded)

func fire_ballistic(origin: Vector3,direction: Vector3,weapon: Dictionary,review_serial: int,peer: int,excluded: Array[RID]) -> void:
	var result: Dictionary=preload("res://scripts/ballistic_trace.gd").cast(get_world_3d().direct_space_state,origin,direction,weapon,excluded)
	coop.deliver_path(peer,review_serial,result.path)
	if not weapon.get("laser",false):
		var points: PackedVector3Array=result.path.points.duplicate()
		if peer==1: points[0]=player.weapon.to_global(player.weapon.muzzle_position)
		elif coop.avatars.has(peer) and is_instance_valid(coop.avatars[peer].weapon): points[0]=coop.avatars[peer].weapon.to_global(coop.avatars[peer].muzzle)
		var token := "%d:%d"%[peer,review_serial]
		coop.ballistic_effect(points,token,peer)
		if coop.active: coop.send_all("ballistic_effect",[points,token,peer])
	if weapon.get("laser",false):
		var endpoint: Vector3=result.path.points[-1]
		var beam_start:=origin+Vector3(0,-.18,0)
		if peer==1: beam_start=player.weapon.to_global(player.weapon.muzzle_position)
		beam_effect(beam_start,endpoint)
		if coop.active: coop.send_all("laser_effect",[beam_start,endpoint])
	if not result.hit.is_empty(): resolve_weapon_hit(result.hit,result.direction,weapon,result.path.travelled,review_serial)

func damage_at_distance(weapon: Dictionary, distance: float) -> float:
	var fraction := clampf((distance - float(weapon.effective_range)) / maxf(1.0, float(weapon.range) - float(weapon.effective_range)), 0.0, 1.0)
	return float(weapon.damage) * lerpf(1.0, float(weapon.minimum_damage), fraction)

func resolve_weapon_hit(hit: Dictionary, direction: Vector3, weapon: Dictionary, distance: float, review_serial: int = -1) -> void:
	if not is_playing() or hit.is_empty():
		return
	var collider: Node = hit.collider
	if collider.has_meta("hunter_peer"):
		var id: int = collider.get_meta("hunter_peer")
		var victim: Node3D = player if id==1 else coop.avatars.get(id)
		if not is_instance_valid(victim): return
		var base := damage_at_distance(weapon,distance)
		var target_pose: Transform3D=victim.global_transform
		var report: Dictionary = preload("res://scripts/human_xray.gd").trace(victim.to_local(hit.position),(victim.global_basis.inverse()*direction).normalized(),base,float(weapon.get("penetration",.7))*clampf(base/float(weapon.damage),.35,1))
		var fatal_vital: bool = report.organs.has("brain") or report.organs.has("heart")
		report.instant_fatal = fatal_vital
		report.damage = coop.friendly_hit(id,100000.0 if fatal_vital else float(report.calculated_damage))
		report.target_uid = victim.get_instance_id()
		report.target_transform=target_pose
		report.body_depth_m=report.entry.distance_to(report.end)
		report.base_damage = weapon.damage
		report.distance = distance
		report.range_factor = base/float(weapon.damage)
		report.weapon = weapon.name
		if coop.shooter!=1: coop.deliver_report(report,review_serial)
		else: shot_review.record(report,review_serial)
		return
	var hit_zone: String = str(collider.get_meta("hit_zone", "body"))
	var target: Node = collider.get_meta("wolf") if collider.has_meta("wolf") else null
	if is_instance_valid(target) and not target.dead:
		var target_pose: Transform3D=target.global_transform
		if target is IslandWolf: target_pose.basis=target_pose.basis.scaled_local(Vector3.ONE*target.size_scale)
		var report: Dictionary = target.receive_ballistic_hit(damage_at_distance(weapon, distance), hit.position, direction, hit_zone, float(weapon.limb_force),float(weapon.get("vital_bonus",1.0)),float(weapon.get("penetration",.7))*clampf(damage_at_distance(weapon,distance)/float(weapon.damage),.35,1))
		report.target_uid=target.get_instance_id()
		report.target_transform=target_pose
		report.body_depth_m=report.entry.distance_to(report.end)*(float(target.size_scale) if target is IslandWolf else 1.0)
		report["base_damage"] = float(weapon.damage)
		report["distance"] = distance
		report["range_factor"] = damage_at_distance(weapon,distance)/float(weapon.damage)
		report["weapon"] = str(weapon.name)
		report["penetration_budget"] = float(weapon.get("penetration",.7))
		if coop.active and not coop.client() and coop.shooter!=1:
			coop.deliver_report(report,review_serial)
		else:
			shot_review.record(report,review_serial)
		hit_flash = 0.15
	else:
		var surface := str(collider.get_parent().name).to_lower() if is_instance_valid(collider) else "ground"
		var kind := "wood" if ["tree","trunk","pine","birch","wood","fence","cabin","house"].any(func(word):return surface.contains(word)) else "stone" if surface.contains("rock") or surface.contains("stone") else "soil"
		coop.surface_impact(hit.position,hit.get("normal",Vector3.UP),kind)
		if coop.active: coop.send_all("surface_impact",[hit.position,hit.get("normal",Vector3.UP),kind])

func _spawn_impact(point: Vector3, on_wolf: bool) -> void:
	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("d6e99c") if on_wolf else Color("ffd39b")
	marker.material_override = material
	add_child(marker)
	marker.global_position = point
	var tween := create_tween()
	tween.tween_property(marker, "scale", Vector3.ONE * 0.02, 0.18)
	tween.tween_callback(marker.queue_free)

func reload_weapon() -> void:
	if not is_playing() or is_struggling() or bandage_left > 0 or reload_left > 0 or current_ammo() == int(weapon_spec().magazine):
		return
	if free_play and current_weapon in [18,20,24,25]:
		ammo[current_weapon]=int(weapon_spec().magazine)
		fire_cooldown=float(weapon_spec().interval)
		_sync_weapon_visual()
		show_notice("Practice throws replenished.",2)
		return
	if current_reserve() <= 0 and not weapon_spec().get("laser",false):
		show_notice("Used this round. One is restored free next round." if current_weapon in [24,25] else "Out of ammunition. Visit the store or switch weapons.", 2.5)
		fire_cooldown = 0.5
		return
	_reload_weapon_id = current_weapon
	_reload_secondary = current_weapon == 9 and lemat_secondary
	reload_left = float(weapon_spec().reload) * player.get_reload_multiplier()
	reload_duration = reload_left
	last_reload_stage = ""
	player.play_reload(reload_left)
	sounds.play("reload", -18)

func _finish_reload() -> void:
	if _reload_weapon_id != current_weapon or _reload_secondary != (current_weapon == 9 and lemat_secondary):
		return
	var amount := mini(int(weapon_spec().magazine) - current_ammo(), 5 if weapon_spec().get("laser",false) else current_reserve())
	if _reload_secondary:
		lemat_shot_ammo += amount
		lemat_shot_reserve -= amount
	else:
		ammo[current_weapon] += amount
		if not weapon_spec().get("laser",false): reserve_ammo[current_weapon] -= amount
	_reload_weapon_id = -1
	_sync_weapon_visual()

func cycle_weapon(direction: int) -> void:
	if progress.owned.is_empty():
		return
	var slot:=current_slot
	if slot<0 or slot>=progress.owned.size() or progress.owned[slot]!=current_weapon: slot=progress.owned.find(current_weapon)
	for offset in range(1,progress.owned.size()+1):
		var next:=posmod(slot+direction*offset,progress.owned.size())
		if not progress.stowed.has(progress.owned[next]):
			select_owned_slot(next); return

func select_owned_slot(slot: int) -> void:
	if slot >= 0 and slot < progress.owned.size() and not progress.stowed.has(progress.owned[slot]):
		if is_playing() and not is_struggling() and bandage_left<=0: _equip_slot(slot)

func _ensure_copy_magazines() -> void:
	while copy_magazines.size()<progress.owned.size():
		var index: int=progress.owned[copy_magazines.size()]
		copy_magazines.append({"loaded":int(WEAPONS[index].magazine),"secondary":1})

func _save_current_magazine() -> void:
	_ensure_copy_magazines()
	if current_slot>=0 and current_slot<progress.owned.size() and progress.owned[current_slot]==current_weapon:
		copy_magazines[current_slot]={"loaded":ammo[current_weapon],"secondary":lemat_shot_ammo if current_weapon==9 else 1}

func _equip_slot(slot: int) -> void:
	if slot<0 or slot>=progress.owned.size() or progress.stowed.has(progress.owned[slot]): return
	if slot==current_slot and current_weapon==progress.owned[slot]: return
	_save_current_magazine()
	current_slot=slot; current_weapon=progress.owned[slot]
	ammo[current_weapon]=int(copy_magazines[slot].loaded)
	if current_weapon==9: lemat_shot_ammo=int(copy_magazines[slot].secondary)
	reload_left=0; _reload_weapon_id=-1
	fire_cooldown=float(weapon_spec().switch_time)
	player.set_weapon(current_weapon); _sync_weapon_visual()

func toggle_fire_mode() -> void:
	if not is_playing() or is_struggling() or bandage_left > 0 or current_weapon != 9:
		return
	lemat_secondary = not lemat_secondary
	reload_left = 0.0
	_reload_weapon_id = -1
	fire_cooldown = maxf(fire_cooldown, 0.65)
	_sync_weapon_visual()
	show_notice("LeMat: central shot barrel" if lemat_secondary else "LeMat: nine-shot cylinder", 2.5)

func select_weapon(index: int) -> void:
	if not is_playing() or is_struggling() or bandage_left > 0 or index < 0 or index >= WEAPONS.size():
		return
	if not progress.owned.has(index):
		show_notice("Purchase this weapon at the supply store.", 2)
		return
	if current_weapon == index:
		return
	_equip_slot(progress.owned.find(index))

func damage_player(amount: float) -> void:
	if not is_playing() or health <= 0 or is_player_safe():
		return
	_apply_health_damage(amount)

func receive_wolf_bite(amount: float, source: Vector3, werewolf: bool = false) -> void:
	if not is_playing() or health <= 0 or is_player_safe():
		return
	if werewolf: affliction.infect()
	sounds.play_maul(source)
	run_bites += 1
	player.apply_injury("bleeding", 0.20)
	match run_bites % 3:
		1: player.apply_injury("leg", 0.20)
		2: player.apply_injury("arm", 0.22)
		0: player.apply_injury("concussion", 0.32)
	gore.blood_burst(player.position + Vector3.UP * 0.65, (player.position - source).normalized(), 0.65)
	damage_flash=.7; player.play_hurt()
	_apply_health_damage(amount,false)

func receive_gunshot(amount: float) -> void:
	if health<=0 or is_player_safe(): return
	player.apply_injury("bleeding",clampf(amount/45.0,.2,1))
	gore.blood_burst(player.position+Vector3.UP*1.1,player.camera.global_basis.z,clampf(amount/30,.5,2))
	gore.blood_pool(player.position,.18)
	sounds.play("gun_pain",-7)
	_apply_health_damage(amount)
	damage_flash=1.8
	player._damage_kick=1.6

func _apply_health_damage(amount: float, impact: bool = true) -> void:
	if not is_playing() or health <= 0.0:
		return
	health = maxf(0, health - amount)
	if impact:
		damage_flash = 0.55
		player.play_hurt()
		sounds.play("hurt", -14)
	if health <= 0:
		end_wolf_struggle(false)
		bandage_left = 0.0
		death_level = level
		if not coop.active: level = 1
		progress.stowed.clear()
		progress.owned.clear()
		progress.owned.append(0)
		current_weapon = 0
		lemat_secondary = false
		reload_left = 0
		player.set_weapon(current_weapon)
		_sync_weapon_visual()
		_clear_projectiles()
		progress.save_progress()
		set_mode("waiting" if coop.active else "dead")
		if coop.active: coop.local_down()

func start_wolf_struggle(wolf: Node3D) -> bool:
	if free_play: return false
	if not is_playing() or is_player_safe() or health <= 0.0 or is_struggling() or struggle_grace > 0.0 or not is_instance_valid(wolf) or wolf.dead:
		return false
	struggle_wolf = wolf
	struggle_progress = 0.0
	struggle_tick = wolf.get_maul_interval()
	reload_left = 0.0
	bandage_left = 0.0
	var direction: Vector3 = wolf.position - player.position
	player.yaw = atan2(-direction.x, -direction.z)
	player.pitch = -0.48
	player._update_rotation()
	player.weapon.visible = false
	sounds.play_at("bark", wolf.position, -3, float(wolf.profile.voice_pitch))
	receive_wolf_bite(8.0 * float(wolf.bite_damage) / 14.0, wolf.position,wolf.werewolf)
	return is_playing()

func _update_struggle(delta: float) -> void:
	if not is_struggling():
		return
	var fighting: bool = player.fight_held()
	if fighting:
		var resistance: float = struggle_wolf.get_struggle_resistance()
		struggle_progress = minf(1.0, struggle_progress + delta * 0.29 / ((1.0 + player.arm_injury * 0.25) * resistance))
		player.stamina = maxf(0.0, player.stamina - delta * 17.0)
	else:
		struggle_progress = maxf(0.0, struggle_progress - delta * 0.06)
	struggle_tick -= delta
	if struggle_tick <= 0.0:
		struggle_tick += struggle_wolf.get_maul_interval()
		receive_wolf_bite(5.5 * float(struggle_wolf.bite_damage) / 14.0, struggle_wolf.position,struggle_wolf.werewolf)

	if is_struggling() and struggle_progress >= 1.0:
		end_wolf_struggle(true)
		show_notice("You shook it loose. Move! [ B ] bandage bleeding.", 4)

func end_wolf_struggle(escaped: bool) -> void:
	if is_instance_valid(coop) and coop.client() and is_instance_valid(struggle_wolf): coop.send_to(1,"escape",[])
	var attacker := struggle_wolf
	struggle_wolf = null
	struggle_progress = 0.0
	struggle_grace = 2.0 if escaped else 0.0
	if is_instance_valid(attacker):
		attacker.end_struggle(escaped)
	if is_instance_valid(player) and is_instance_valid(player.weapon):
		player.weapon.visible = true
	fire_cooldown = maxf(fire_cooldown, 0.6)

func use_bandage() -> void:
	if health<=0 or not is_playing() or is_struggling() or bandage_left > 0.0:
		return
	if player.bleeding_rate <= 0.0:
		show_notice("No bleeding to treat. First aid treats other injuries.", 3)
	elif bandages <= 0:
		show_notice("No bandages left. Visit the store for first aid.", 3)
	else:
		reload_left = 0.0
		bandage_left = 2.4
		show_notice("Applying a bandage…", 2.4)

func interaction_prompt() -> String:
	if health<=0 or is_struggling(): return ""
	var key := "Y" if controller_device>=0 else "E"
	if campaign.running:
		var mission: String=campaign.prompt()
		if not mission.is_empty(): return mission.replace("E / Y",key)
	var loot: int=world.houses.nearby(player.position)
	var prompt := ""
	if loot>=0: prompt = "[ %s ] TAKE %s" % [key,WEAPONS[world.houses.drops[loot]].name]
	elif near_shop(): prompt = "[ %s ] OPEN SUPPLY STORE" % key
	if world.services.nearby_coffee(player.position)>=0:
		prompt += "  |  [ %s ] COFFEE +30 HP" % ("D-PAD RIGHT" if controller_device>=0 else "C")
	return prompt

func near_shop() -> bool:
	return world.services.near_store(player.position)

func nearest_store_distance() -> float:
	return player.position.distance_to(world.services.nearest_store(player.position))

func drink_coffee() -> void:
	if not is_playing() or health<=0 or is_struggling() or bandage_left>0: return
	var cabin: int=world.services.nearby_coffee(player.position)
	if cabin<0:
		show_notice("Get close to a steaming coffee cup inside a cabin.",3)
		return
	if coop.client(): coop.send_to(1,"request_coffee",[cabin])
	else: coop.serve_coffee(1,cabin)

func interact_shop() -> void:
	if health<=0: return
	if is_playing() and not is_struggling() and campaign.running:
		if coop.client():
			if not campaign.prompt().is_empty():
				coop.send_to(1,"mission_interact",[])
				return
		elif campaign.interact(1): return
	if is_playing() and not is_struggling():
		var loot: int = world.houses.nearby(player.position)
		if loot>=0:
			if coop.client(): coop.send_to(1,"take_loot",[loot])
			else: world.houses.take(loot,self)
			return
	if is_playing() and not is_struggling() and bandage_left <= 0.0:
		if near_shop():
			set_mode("shop")
		else:
			show_notice("Nearest supply store: %.0f m. Every building has supplies." % nearest_store_distance(), 2.5)

func close_shop() -> void:
	set_mode("playing")
	fire_cooldown = 0.25

func purchase_weapon(index: int, another: bool=false) -> void:
	if mode != "shop" or index < 0 or index >= WEAPONS.size():
		return
	if another and not WeaponCatalog.is_gun(index): return
	if progress.owned.has(index) and not another:
		progress.stowed.erase(index); progress.save_progress()
		_equip_slot(progress.owned.find(index))
	elif progress.buy(index, int(WEAPONS[index].price)):
		progress.stowed.erase(index); progress.save_progress()
		_equip_slot(progress.owned.size()-1)
		reserve_ammo[index] += int(WEAPONS[index].reserve) if progress.owned.count(index)>1 else 0
		if progress.owned.count(index)==1: reserve_ammo[index]=int(WEAPONS[index].reserve)
		if index == 9:
			lemat_shot_reserve = lemat_shot_reserve+4 if progress.owned.count(index)>1 else 4
		reload_left = 0
		sounds.play("coin", -14)
	_reload_weapon_id = -1
	_sync_weapon_visual()
	hud.refresh_panel()

func toggle_store_weapon(index: int) -> void:
	if mode!="shop" or not progress.owned.has(index): return
	if progress.stowed.has(index):
		progress.stowed.erase(index); _equip_slot(progress.owned.find(index))
	else:
		var remaining: Array=progress.owned.filter(func(id): return id!=index and not progress.stowed.has(id))
		if remaining.is_empty():
			show_notice("Keep at least one weapon equipped.",3); return
		_save_current_magazine(); progress.stowed.append(index)
		if current_weapon==index: _equip_slot(progress.owned.find(remaining[0]))
	progress.save_progress(); hud.refresh_panel()

func ammo_refill_cost() -> int:
	var cost := 0
	var counted: Dictionary={}
	for index: int in progress.owned:
		if counted.has(index): continue
		counted[index]=true
		cost += maxi(0, int(WEAPONS[index].reserve)*progress.owned.count(index) - reserve_ammo[index]) * int(WeaponCatalog.weapon(index).ammo_cost)
		if index in [18,20]: cost += maxi(0,int(WEAPONS[index].magazine)-ammo[index])*int(WeaponCatalog.weapon(index).ammo_cost)
	if progress.owned.has(9):
		cost += maxi(0, 4*progress.owned.count(9) - lemat_shot_reserve) * 4
	return cost

func purchase_ammo() -> void:
	var cost := ammo_refill_cost()
	if mode != "shop" or cost <= 0 or progress.money < cost:
		return
	progress.money -= cost
	for index: int in progress.owned:
		reserve_ammo[index] = maxi(reserve_ammo[index],int(WEAPONS[index].reserve)*progress.owned.count(index))
		if index in [18,20]: ammo[index]=int(WEAPONS[index].magazine)
	if progress.owned.has(9):
		lemat_shot_reserve = maxi(lemat_shot_reserve,4*progress.owned.count(9))
	_sync_weapon_visual()
	progress.save_progress()
	sounds.play("coin", -14)
	hud.refresh_panel()

func purchase_health() -> void:
	if campaign.running:
		show_notice("Rest heals injuries after the mission. Use bandages in the field.",4)
		return
	if mode == "shop" and (health < maximum_health() or not player.get_injury_summary().is_empty()) and progress.money >= 40:
		progress.money -= 40
		health = maximum_health()
		player.clear_injuries()
		if coop.client(): coop.send_to(1,"treated",[])
		progress.save_progress()
		sounds.play("coin", -14)
		hud.refresh_panel()

func show_notice(message: String, duration: float = 3) -> void:
	notice = message
	notice_left = duration

func return_to_menu() -> void:
	if campaign: campaign.running=false
	if is_instance_valid(split_session):
		split_session.close.call_deferred()
		return
	coop.leave()
	progress.save_progress()
	restore_campaign()
	sounds.stop_dialogue()
	dialogue_left = 0
	menu_camera.current = true
	set_mode("menu")

func quit_game() -> void:
	if not OS.get_cmdline_user_args().has("--qa"):
		progress.save_progress()
	get_tree().quit()

func _run_visual_qa() -> void:
	await get_tree().create_timer(2.0).timeout
	_capture("menu")
	start_run()
	await get_tree().create_timer(1.0).timeout
	_capture("playing")
	await get_tree().create_timer(4.0).timeout
	_capture("waiting_in_cabin")
	# Walk through the real doorway; leave the naturally spawned pack untouched.
	await _qa_walk_to(world.nav.point(world.nav.nearest(-1.0, 9.0, 3.0)))
	_capture("wave_started")
	# A real sky shot gives the distant pack a sound cue; stealthy players can
	# otherwise stay unheard, which is now intentional.
	player.pitch = 1.1
	player._update_rotation()
	fire_cooldown = 0.0
	fire_weapon()
	reload_weapon()
	player.pitch = -0.04
	# Let the distant pack approach naturally before inspecting its appearance.
	for frame: int in 1200:
		var nearby := false
		for wolf: Node3D in wolves:
			nearby = nearby or player.position.distance_to(wolf.position) < 8.0
		if (nearby and reload_left <= 0.0) or not is_playing():
			break
		await get_tree().physics_frame
	var closest: Node3D = null
	for wolf: Node3D in wolves:
		if closest == null or player.position.distance_to(wolf.position) < player.position.distance_to(closest.position):
			closest = wolf
	if closest:
		var direction: Vector3 = (closest.position + Vector3.UP * 0.7 - player.camera.global_position).normalized()
		player.yaw = atan2(-direction.x, -direction.z)
		player.pitch = asin(direction.y)
		player._update_rotation()
	await get_tree().create_timer(0.2).timeout
	_capture("wolves")
	print("RENDERED_QA: wolves=%d, safe_spawn=%s" % [wolves.size(), world.is_safe_position(world.spawn_position)])
	fire_cooldown = 0
	fire_weapon()
	reload_weapon()
	await get_tree().create_timer(2.6).timeout
	_capture("musket_reload")
	damage_player(100)
	await get_tree().create_timer(0.3).timeout
	_capture("defeat")
	player.reset_at(world.shop_position)
	health = maximum_health()
	set_mode("playing")
	progress.money = 500
	interact_shop()
	await get_tree().create_timer(0.3).timeout
	_capture("store")
	print("VISUAL_QA_COMPLETE")
	get_tree().quit()

func _qa_walk_to(goal: Vector3) -> void:
	world.nav.field(goal.x, goal.z)
	var forward := InputEventKey.new()
	forward.keycode = KEY_W
	forward.physical_keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	for frame: int in 600:
		var offset: Vector3 = goal - player.position
		offset.y = 0
		if offset.length() < 0.3 or not is_playing():
			break
		var next: Vector3 = world.nav.next_point(player.position.x, player.position.z)
		if not next.is_finite():
			break
		var direction: Vector3 = next - player.position
		if direction.length_squared() < 0.012:
			direction = offset
		player.yaw = atan2(-direction.x, -direction.z)
		await get_tree().physics_frame
	forward.pressed = false
	Input.parse_input_event(forward)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var directory := ProjectSettings.globalize_path("res://qa")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))

func _spawn_free_animals() -> void:
	for wolf in wolves:
		if is_instance_valid(wolf): wolf.queue_free()
	wolves.clear()
	_spawn_wildlife()
	var nav = world.wolf_nav
	for animal in nodes_in_group("wildlife"):
		if animal.is_queued_for_deletion(): continue
		var p: Vector3 = world.shooting_range.firing_point+Vector3(randf_range(-18,18),0,randf_range(-18,18))
		var cell: int = nav.nearest(p.x,p.z,12)
		if cell>=0: animal.position = nav.point(cell)
	for i in 3:
		var p: Vector3 = world.shooting_range.firing_point+Vector3(8+i*5,0,-10)
		var cell: int = nav.nearest(p.x,p.z,15)
		if cell>=0: _add_wolf_at(nav.point(cell))
	pending_spawns = 0
	free_respawn = 60

func radar_animals() -> Array[Node3D]:
	var found: Array[Node3D]=[]
	var candidates: Array=wolves+nodes_in_group("wildlife")+nodes_in_group("campaign_threats")
	if coop.client(): candidates.append_array(coop.replicas.values())
	for animal in candidates:
		if not is_instance_valid(animal) or animal.is_queued_for_deletion() or animal.dead or found.has(animal): continue
		if animal.position.distance_to(player.position)<=75: found.append(animal)
	return found

func radar_color(animal: Node3D) -> Color:
	if animal.get("fear_left")!=null and float(animal.fear_left)>0: return Color("58b8ff")
	if animal.get("behavior") in ["flee","retreat"]: return Color("58b8ff")
	if not free_play and animal.get("alerted")==true: return Color("ff4d4d")
	return Color("ed9fc8")

func beam_effect(a: Vector3,b: Vector3) -> void:
	if a.distance_squared_to(b)<.0001: return
	var effect:=Node3D.new(); effect.name="RedLaserBeam"; add_child(effect)
	for layer in 2:
		var beam:=MeshInstance3D.new()
		var mesh:=CylinderMesh.new()
		mesh.top_radius=.045 if layer==0 else .105; mesh.bottom_radius=mesh.top_radius
		mesh.height=a.distance_to(b); mesh.radial_segments=12
		beam.mesh=mesh; beam.position=(a+b)*.5
		beam.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color=Color(1,.035,.015,1 if layer==0 else .22)
		material.emission_enabled=true; material.emission=Color(1,.015,.005)
		material.emission_energy_multiplier=2.5 if layer==0 else 1.0
		beam.material_override=material; beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effect.add_child(beam)
		var fade:=beam.create_tween()
		fade.tween_interval(.12); fade.tween_property(material,"albedo_color:a",0.0,.23)
	get_tree().create_timer(.36).timeout.connect(effect.queue_free)

func start_split() -> void:
	var session = load("res://scripts/split_session.gd").new()
	get_tree().root.add_child(session)
	session.launch.call_deferred(self)
