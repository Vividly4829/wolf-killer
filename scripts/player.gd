class_name IslandPlayer
extends Node3D

## First person controller. The navigation grid supplies terrain and wall collision.
const WeaponVisual = preload("res://scripts/weapon_visual.gd")
const WeaponCatalog = preload("res://scripts/weapon_catalog.gd")
var controller_device := -1
var pad_buttons := {}
var pad_trigger := false
var game: Node
var nav: RefCounted
var camera: Camera3D
var enabled: bool = true
var weapon: Node3D
var weapon_index: int = 0
var yaw: float = 0.0
var pitch: float = -0.04
var sensitivity: float = 0.0022
const MAX_STAMINA := 337.5
const STANDING_EYE_HEIGHT := 1.78
const WALK_SPEED := 2.85
const SPRINT_SPEED := 6.075
var stamina: float = MAX_STAMINA
var is_crouching: bool = false
var is_sprinting := false
var supernatural_speed := 1.0
var bleeding_rate: float = 0.0
var leg_injury: float = 0.0
var arm_injury: float = 0.0
var concussion: float = 0.0
var ground_view_offset := 0.0
var _eye_height: float = STANDING_EYE_HEIGHT
var _actual_speed: float = 0.0
var _movement_noise: float = 0.035
var _noise_pulse: float = 0.0
var _noise_pulse_left: float = 0.0
var _injury_phase: float = 0.0
var _struggle_active: bool = false
var _struggle_anchor_yaw: float = 0.0
var _struggle_anchor_pitch: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _jump_height: float = 0.0
var _jump_velocity: float = 0.0
var _walk_phase: float = 0.0
var _recoil: float = 0.0
var _reload_time: float = 0.0
var _quick_throw_pose:=0.0
var _reload_duration: float = 1.0
var _damage_kick: float = 0.0
var _aim: float = 0.0
var _sprint_exhausted: bool = false
var _fire_trigger_down: bool = false
var reload_stage: String:
	get:
		return get_reload_stage()

func configure(owner_game: Node, navigation: RefCounted) -> void:
	game = owner_game
	Input.joy_connection_changed.connect(_joy_connection_changed)
	if game.get("controller_device")!=null: controller_device=game.controller_device
	nav = navigation
	name = "Player"
	camera = Camera3D.new()
	camera.name = "FirstPersonCamera"
	camera.position.y = STANDING_EYE_HEIGHT
	camera.near = 0.035
	camera.far = 900.0
	camera.fov = 78.0
	camera.current = true
	add_child(camera)
	weapon = WeaponVisual.new()
	camera.add_child(weapon)
	weapon.position = Vector3(0.26, -0.24, -0.38)
	set_weapon(0)
	_update_rotation()

func reset_at(pos: Vector3) -> void:
	position = pos
	_jump_height = 0.0
	ground_view_offset=0.0
	_jump_velocity = 0.0
	_velocity = Vector2.ZERO
	_recoil = 0.0
	_reload_time = 0.0
	_damage_kick = 0.0
	stamina = MAX_STAMINA
	_sprint_exhausted = false
	is_sprinting = false
	_aim = 0.0
	is_crouching = false
	_eye_height = STANDING_EYE_HEIGHT
	_actual_speed = 0.0
	_movement_noise = 0.035
	_noise_pulse_left = 0.0
	_struggle_active = false
	if camera:
		camera.position.y = STANDING_EYE_HEIGHT
		camera.fov = 78.0

func set_weapon(index: int) -> void:
	weapon_index = clampi(index, 0, WeaponCatalog.WEAPONS.size() - 1)
	_reload_time = 0.0
	if weapon:
		weapon.call("build", weapon_index)

func _weapon_spec() -> Dictionary:
	if is_instance_valid(game) and game.has_method("weapon_spec"):
		return game.call("weapon_spec")
	return WeaponCatalog.weapon(weapon_index)

func play_shot() -> void:
	var data: Dictionary = _weapon_spec()
	var quiet: bool = float(data.get("projectile_speed", 0.0)) > 0.0
	_emit_noise(0.16 if quiet else 1.0, 0.30 if quiet else 0.65)
	_recoil = float(data.get("recoil", 1.0))
	pitch = maxf(-1.48, pitch - float(data.get("kick", 0.025)))
	if weapon:
		weapon.call("flash")

func play_reload(duration: float = 1.25) -> void:
	_reload_duration = maxf(duration, 0.1)
	_reload_time = _reload_duration
	if not bool(_weapon_spec().get("move_reload", true)):
		_velocity = Vector2.ZERO

func get_reload_stage() -> String:
	var remaining := float(game.get("reload_left")) if is_instance_valid(game) else _reload_time
	if remaining <= 0.0:
		return ""
	var stages: Array = _weapon_spec().get("reload_stages", [])
	if stages.is_empty():
		return "RELOADING"
	var progress := clampf(1.0 - remaining / _reload_duration, 0.0, 1.0)
	# Preserve the starter musket's longer ramming stage and visual timing.
	if weapon_index == 0 and stages.size() == 4:
		return str(stages[0 if progress < 0.30 else (1 if progress < 0.45 else (2 if progress < 0.84 else 3))])
	return str(stages[mini(stages.size() - 1, int(progress * stages.size()))])

func damage(amount: float) -> void:
	if game:
		game.call("damage_player", amount)

func play_hurt() -> void:
	_damage_kick = 1.0
	_emit_noise(0.65, 0.35)

func apply_injury(kind: String, severity: float) -> void:
	var amount := clampf(severity, 0.0, 1.0)
	match kind.to_lower():
		"bleed", "bleeding":
			bleeding_rate = minf(3.0, bleeding_rate + amount * 1.4)
		"leg":
			leg_injury = minf(1.0, leg_injury + amount)
		"arm":
			arm_injury = minf(1.0, arm_injury + amount)
		"head", "concussion":
			concussion = minf(1.0, concussion + amount)

func clear_injuries() -> void:
	bleeding_rate = 0.0
	leg_injury = 0.0
	arm_injury = 0.0
	concussion = 0.0
	_injury_phase = 0.0
	stamina = MAX_STAMINA
	_sprint_exhausted = false

func stop_bleeding() -> void:
	bleeding_rate = 0.0

func tick_injuries(delta: float) -> float:
	# Health is owned by main.gd. It calls this only while play is advancing,
	# including inside shelter; the controller never applies bleeding twice.
	var elapsed := maxf(0.0, delta)
	concussion = move_toward(concussion, 0.0, elapsed * 0.05)
	return bleeding_rate * elapsed

func get_reload_multiplier() -> float:
	return (1.0 + clampf(arm_injury, 0.0, 1.0) * 0.65) * game.rituals.factor("reload")

func get_aim_spread_multiplier() -> float:
	return ((4.0 if is_sprinting else 1.0) + clampf(arm_injury, 0.0, 1.0) * 1.5) * game.rituals.factor("accuracy")

func get_injury_summary() -> String:
	var injuries := PackedStringArray()
	if bleeding_rate > 0.0:
		injuries.append("BLEEDING")
	if leg_injury > 0.0:
		injuries.append("LEG INJURY")
	if arm_injury > 0.0:
		injuries.append("ARM INJURY")
	if concussion > 0.0:
		injuries.append("CONCUSSION")
	return " / ".join(injuries)

func get_noise_level() -> float:
	var pulse := _noise_pulse if _noise_pulse_left > 0.0 else 0.0
	return clampf(maxf(maxf(_movement_noise, pulse), 0.85 if _struggle_active else 0.0), 0.0, 1.0) * game.rituals.factor("noise")

func get_visibility() -> float:
	if _jump_height > 0.04 or _struggle_active:
		return 1.0
	var movement := clampf(_actual_speed / 8.0, 0.0, 1.0)
	return clampf((0.38 + movement * 0.3) if is_crouching else (0.8 + movement * 0.2), 0.0, 1.0)

func _emit_noise(level: float, duration: float) -> void:
	_noise_pulse = maxf(_noise_pulse if _noise_pulse_left > 0 else 0.0, level)
	_noise_pulse_left = maxf(_noise_pulse_left, duration)

func _is_struggling() -> bool:
	var active: bool = is_instance_valid(game) and game.has_method("is_struggling") and bool(game.call("is_struggling"))
	if active and not _struggle_active:
		_struggle_anchor_yaw = yaw
		_struggle_anchor_pitch = pitch
		_velocity = Vector2.ZERO
	_struggle_active = active
	return active

func _joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device==controller_device:
		pad_buttons.clear(); pad_trigger=false
		if not is_instance_valid(game.split_session): use_input_device(-1)

func use_input_device(device: int) -> void:
	if controller_device==device: return
	controller_device=device; game.controller_device=device
	pad_buttons.clear(); pad_trigger=false; _fire_trigger_down=false
	if not is_instance_valid(game.split_session):
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if game.mode=="playing" else Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(game.hud): game.hud.refresh_input_hints()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(game): return
	var joy := event is InputEventJoypadButton or event is InputEventJoypadMotion
	# Outside split screen, the last deliberately used device controls this hunter.
	# Split screen keeps keyboard and controller ownership fixed.
	if not is_instance_valid(game.split_session):
		if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>.3):
			use_input_device(event.device)
		elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			use_input_device(-1)
	if joy and event.device==controller_device and event is InputEventJoypadButton:
		var fresh: bool=event.pressed and not pad_buttons.get(event.button_index,false)
		pad_buttons[event.button_index]=event.pressed
		if game.mode!="menu":
			# Handle before GUI focus can activate an unrelated store button. This
			# also captures short taps entirely between two physics frames.
			get_viewport().set_input_as_handled()
			if fresh: controller_button(event.button_index)
	# UI panels may consume a release before unhandled input reaches the player.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_fire_trigger_down = false

func _unhandled_input(event: InputEvent) -> void:
	if controller_device>=0: return
	if game and game.get("mode")=="waiting": return
	# Remember release across pause/struggle boundaries; holding a trigger never
	# turns a historical single-action weapon into an automatic weapon.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _fire_trigger_down:
			return
		_fire_trigger_down = event.pressed
	if not enabled or not is_instance_valid(game) or not game.call("is_playing"):
		return
	var struggling := _is_struggling()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var look_speed := sensitivity * lerpf(1.0, 0.65, _aim) * (0.4 if struggling else 1.0)
		# UI stretch must not change mouse sensitivity when switching to 4K.
		var motion: Vector2 = event.screen_relative if event.screen_relative!=Vector2.ZERO else event.relative
		yaw -= motion.x * look_speed
		pitch = clampf(pitch - motion.y * look_speed, -1.48, 1.48)
		if struggling:
			yaw = _struggle_anchor_yaw + clampf(wrapf(yaw - _struggle_anchor_yaw, -PI, PI), -0.55, 0.55)
			pitch = clampf(pitch, _struggle_anchor_pitch - 0.35, _struggle_anchor_pitch + 0.35)
		_update_rotation()
	if struggling:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F: game.quick_throw()
			KEY_R:
				game.call("reload_weapon")
			KEY_E:
				game.call("interact_shop")
			KEY_C:
				game.call("drink_coffee")
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				game.call("select_owned_slot", int(event.physical_keycode) - KEY_1)
			KEY_Q:
				game.call("cycle_weapon", -1)
			KEY_V:
				game.call("toggle_fire_mode")
			KEY_SPACE:
				if _jump_height < 0.02 and not is_crouching and (bool(_weapon_spec().get("move_reload", true)) or float(game.get("reload_left")) <= 0.0):
					_jump_velocity = 6.1 * (1.0 - leg_injury * 0.45)
					_emit_noise(0.85, 0.35)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			game.call("cycle_weapon", 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			game.call("cycle_weapon", -1)
		elif event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			game.call("fire_weapon")

func _physics_process(delta: float) -> void:
	if is_instance_valid(game) and game.rituals and game.rituals.channeling():
		_velocity=Vector2.ZERO; is_sprinting=false; return
	if is_instance_valid(game) and controller_device < 0 and _fire_trigger_down and _weapon_spec().get("automatic",false): game.fire_weapon()
	if controller_device>=0: poll_controller(delta)
	if game.mode in ["shop","paused","waiting"]: return
	if camera == null or not enabled or not is_instance_valid(game) or not game.call("is_playing"):
		return
	var reloading: bool = float(game.get("reload_left")) > 0.0
	var struggling := _is_struggling()
	var weapon_data: Dictionary = _weapon_spec()
	var movement_locked: bool = (reloading and not bool(weapon_data.get("move_reload", true))) or struggling
	is_crouching = key_held(KEY_CTRL) and not struggling
	_noise_pulse_left = maxf(0.0, _noise_pulse_left - delta)
	_injury_phase += delta
	var axis := Vector2.ZERO
	if not movement_locked:
		axis.x = float(key_held(KEY_D)) - float(key_held(KEY_A))
		axis.y = float(key_held(KEY_S)) - float(key_held(KEY_W))
	if controller_device>=0 and not movement_locked: axis=pad_move()
	axis = axis.limit_length(1.0)
	var aiming: bool = aim_held() and not reloading and not struggling
	if stamina <= 0.5:
		_sprint_exhausted = true
	elif stamina >= 20.0:
		_sprint_exhausted = false
	var sprinting: bool = key_held(KEY_SHIFT) and not is_crouching and leg_injury < 0.85 and not _sprint_exhausted and axis.length_squared() > 0.0
	is_sprinting = sprinting
	aiming = aiming and not sprinting
	if sprinting: _aim = 0.0
	stamina = maxf(0.0, stamina - delta * 18.0 * game.rituals.factor("stamina") * (1.0 + leg_injury * 0.4)) if sprinting else minf(MAX_STAMINA, stamina + delta * 39.0 * (.38 if game.campaign and game.campaign.fever else 1.0) * (1.0 - leg_injury * 0.2))
	var speed: float = (SPRINT_SPEED if sprinting else WALK_SPEED) * (1.0 - leg_injury * (0.45 if sprinting else 0.38))
	if aiming:
		speed = minf(speed, 1.65 * (1.0 - leg_injury * 0.3))
	if is_crouching:
		speed = 1.25 * game.rituals.factor("sneak") * (1.0 - leg_injury * 0.3)
	speed *= supernatural_speed
	if nav.has_method("vegetation_factor"): speed *= nav.call("vegetation_factor",position)
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var desired: Vector3 = (right * axis.x - forward * axis.y) * speed
	# Musket loading plants the feet; gravity still resolves a jump already
	# in progress. The game timer also releases this lock when a weapon is changed.
	_velocity = Vector2.ZERO if movement_locked else _velocity.move_toward(Vector2(desired.x, desired.z), delta * 8.5 * (1.0 - leg_injury * 0.35))
	var moved: Vector3 = nav.call("move_position", position, _velocity.x * delta, _velocity.y * delta)
	_actual_speed = Vector2(moved.x - position.x, moved.z - position.z).length() / maxf(delta, 0.0001)
	var previous_ground := position.y-_jump_height
	var was_airborne := _jump_height > 0.02
	if movement_locked and _jump_height <= 0.0:
		_jump_velocity = minf(_jump_velocity, 0.0)
	_jump_velocity -= 18.0 * delta
	_jump_height = maxf(0.0, _jump_height + _jump_velocity * delta)
	if _jump_height == 0.0:
		_jump_velocity = 0.0
		if was_airborne:
			_emit_noise(0.7, 0.3)
	ground_view_offset=clampf(ground_view_offset-(moved.y-previous_ground),-.25,.25)
	ground_view_offset*=exp(-delta*16)
	position = Vector3(moved.x, moved.y + _jump_height, moved.z)
	_movement_noise = 0.025 if is_crouching else 0.035
	if _actual_speed > 0.2:
		_movement_noise = 0.14 if is_crouching else (0.95 if sprinting else 0.48)
	if _jump_height > 0.04:
		_movement_noise = maxf(_movement_noise, 0.75)
	_walk_phase += delta * _actual_speed * 1.7
	var bob: float = sin(_walk_phase * 2.0) * minf(_actual_speed / 5.0, 1.0) * (0.010 if is_crouching else 0.014)
	_aim = move_toward(_aim, 1.0 if aiming else 0.0, delta * 7.0)
	var aim_fov: float = float(weapon_data.get("aim_fov", 56.0 if str(weapon_data.get("family", "")) in ["rifle", "carbine", "crossbow"] else 64.0))
	camera.fov = (70.0 if struggling else lerpf(78.0, aim_fov, _aim)) + sin(_injury_phase * 1.6) * concussion * 0.6
	var eye_target: float = 1.12 if struggling else (1.05 if is_crouching else STANDING_EYE_HEIGHT)
	_eye_height = move_toward(_eye_height, eye_target, delta * 3.2)
	camera.position.y = _eye_height + bob + ground_view_offset
	_recoil = move_toward(_recoil, 0.0, delta * (4.8 if weapon_index == 0 else 7.5))
	_damage_kick = move_toward(_damage_kick, 0.0, delta * 4.5)
	# The game owns this timer: pausing and changing guns cannot desynchronize loading.
	_quick_throw_pose=maxf(0,_quick_throw_pose-delta)
	_reload_time = maxf(0.0, float(game.get("reload_left")))
	var reload_progress: float = clampf(1.0 - _reload_time / _reload_duration, 0.0, 1.0)
	var reload_angle: float = sin((_reload_time / _reload_duration) * PI) if _reload_time > 0.0 else 0.0
	var held_position := Vector3(lerpf(0.26, 0.08, _aim), -0.24, -0.38)
	var iron_sight := Vector3(-weapon.model_meta.sight.x,-weapon.model_meta.sight.y,-.48)
	held_position = Vector3(.04 if weapon_index in [30,31,32] else .26,-.24,-.38).lerp(iron_sight,_aim)
	held_position.y-=sin(_quick_throw_pose/.24*PI)*.16
	if weapon_index in [21,22,23]:
		held_position=Vector3(.25,-.18,-.45).lerp(Vector3(-.13,-.075,-.65),_aim)
	if weapon_data.has("view_position"):
		var rest_position: Vector3 = weapon_data.view_position
		var aim_position: Vector3 = weapon_data.get("aim_position", Vector3(0.06, rest_position.y, rest_position.z))
		held_position = rest_position.lerp(aim_position, _aim)
	# Bring the action into view while loading so the opening breech, cylinder,
	# cartridge and bow mechanisms remain visible throughout their animations.
	weapon.position = held_position.lerp(Vector3(0.18, -0.22, -0.46), reload_angle) + Vector3(sin(_walk_phase) * 0.008 * (1.0-_aim), -absf(bob) * 0.65 * (1.0-_aim), _recoil * 0.09)
	weapon.rotation = Vector3(_recoil * 0.16 + reload_angle * 0.25, reload_angle * 0.25, -reload_angle * 0.18)
	if weapon_index == 0 and _reload_time > 0.0:
		var lift: float = smoothstep(0.0, 0.14, reload_progress) * (1.0 - smoothstep(0.84, 1.0, reload_progress)) if _reload_time > 0 else 0.0
		weapon.position = Vector3(lerpf(0.24, 0.035, _aim) - lift * 0.07, -0.29 - absf(bob) * 0.5 - lift * 0.15, -0.42 + _recoil * 0.13 - lift * 0.10)
		weapon.rotation = Vector3(_recoil * 0.20 + lift * 0.90, lift * 0.09, -lift * 0.20)
	if is_sprinting:
		weapon.position += Vector3(.08,-.12,.06)
		weapon.rotation.x += .18
	weapon.call("animate_reload", reload_progress, _reload_time > 0.0)
	_update_rotation()

func _update_rotation() -> void:
	rotation.y = yaw
	if camera:
		var arm_sway := arm_injury * (0.55 if _aim > 0.5 else 1.0)
		var shake := 0.009 if _struggle_active else 0.0
		camera.rotation = Vector3(clampf(pitch + sin(_injury_phase * 2.3) * arm_sway * 0.009 + sin(_injury_phase * 1.6) * concussion * 0.006 + sin(_injury_phase * 19.0) * shake, -1.5, 1.5), sin(_injury_phase * 1.7) * arm_sway * 0.012, sin(_damage_kick * 13.0) * _damage_kick * 0.018 + sin(_injury_phase * 1.9) * concussion * 0.018 + sin(_injury_phase * 17.0) * shake)

func pad_move() -> Vector2:
	var value := Vector2(Input.get_joy_axis(controller_device,JOY_AXIS_LEFT_X),Input.get_joy_axis(controller_device,JOY_AXIS_LEFT_Y))
	return Vector2.ZERO if value.length()<.18 else value.limit_length(1)
func key_held(key: Key) -> bool:
	if controller_device<0: return Input.is_physical_key_pressed(key)
	if key==KEY_SHIFT: return Input.is_joy_button_pressed(controller_device,JOY_BUTTON_LEFT_STICK)
	if key==KEY_CTRL: return Input.is_joy_button_pressed(controller_device,JOY_BUTTON_B)
	return false
func aim_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) if controller_device<0 else Input.get_joy_axis(controller_device,JOY_AXIS_TRIGGER_LEFT)>.3
func fight_held() -> bool:
	return Input.is_physical_key_pressed(KEY_F) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) if controller_device<0 else Input.get_joy_axis(controller_device,JOY_AXIS_TRIGGER_RIGHT)>.3
func jump() -> void:
	if game.mode!="playing" or _is_struggling(): return
	if _jump_height<.02 and not is_crouching and (bool(_weapon_spec().get("move_reload",true)) or float(game.reload_left)<=0):
		_jump_velocity=6.1*(1-leg_injury*.45); _emit_noise(.85,.35)
func controller_button(button: int) -> void:
	if game.mode=="weapon_stats":
		if button in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER]: game.hud.step_stats_page(-1)
		elif button in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER]: game.hud.step_stats_page(1)
		elif button in [JOY_BUTTON_B, JOY_BUTTON_Y]: game.set_mode("menu")
		return
	if button==JOY_BUTTON_START and game.mode in ["playing","paused"]:
		game.set_mode("paused" if game.mode=="playing" else "playing"); return
	if game.mode in ["connecting","connection_error"]:
		if button==JOY_BUTTON_Y: game.return_to_menu()
		elif game.mode=="connection_error" and button==JOY_BUTTON_A: game.coop.retry_connection()
		return
	if game.mode in ["dead","victory"]:
		if button==JOY_BUTTON_A: game.start_run()
		return
	if game.mode=="paused":
		if button==JOY_BUTTON_Y: game.return_to_menu()
		elif button in [JOY_BUTTON_A,JOY_BUTTON_B]: game.set_mode("playing")
		return
	if game.mode=="shop":
		match button:
			JOY_BUTTON_DPAD_UP: game.hud.step_shop_selection(-1)
			JOY_BUTTON_DPAD_DOWN: game.hud.step_shop_selection(1)
			JOY_BUTTON_LEFT_SHOULDER: game.hud.step_shop_filter(-1)
			JOY_BUTTON_RIGHT_SHOULDER: game.hud.step_shop_filter(1)
			JOY_BUTTON_A: game.hud._purchase_selected_weapon()
			JOY_BUTTON_X: game.purchase_ammo()
			JOY_BUTTON_RIGHT_STICK: game.hud._purchase_another()
			JOY_BUTTON_LEFT_STICK: game.toggle_store_weapon(game.hud.shop_selection)
			JOY_BUTTON_DPAD_RIGHT: game.purchase_health()
			JOY_BUTTON_B,JOY_BUTTON_Y: game.close_shop()
		return
	if game.mode!="playing" or _is_struggling(): return
	match button:
		JOY_BUTTON_A: jump()
		JOY_BUTTON_X: game.reload_weapon()
		JOY_BUTTON_Y: game.interact_shop()
		JOY_BUTTON_RIGHT_STICK: game.quick_throw()
		JOY_BUTTON_DPAD_UP: game.use_bandage()
		JOY_BUTTON_DPAD_LEFT: game.toggle_fire_mode()
		JOY_BUTTON_DPAD_DOWN: game.shot_review.cycle_review()
		JOY_BUTTON_DPAD_RIGHT: game.drink_coffee()
		JOY_BUTTON_LEFT_SHOULDER: game.cycle_weapon(-1)
		JOY_BUTTON_RIGHT_SHOULDER: game.cycle_weapon(1)

func poll_controller(delta: float) -> void:
	var trigger := Input.get_joy_axis(controller_device,JOY_AXIS_TRIGGER_RIGHT)>.3
	var fire := trigger and not pad_trigger; pad_trigger=trigger
	var look := Vector2(Input.get_joy_axis(controller_device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(controller_device,JOY_AXIS_RIGHT_Y))
	if game.mode=="shop":
		if look.length()>.15: game.hud.preview_pivot.rotation.y-=look.x*delta*2
		return
	if game.mode!="playing": return
	if look.length()>.15:
		yaw-=look.x*delta*2.4*(1-_aim*.4); pitch=clampf(pitch-look.y*delta*1.8,-1.48,1.48); _update_rotation()
	if fire or (trigger and _weapon_spec().get("automatic",false)): game.fire_weapon()
