extends Node
## Three-player ENet co-op. The host owns waves, animals and projectile hit tests.
const PORT := 27896
var port := PORT
const Avatar = preload("res://scripts/coop_avatar.gd")
var game: Node3D
var slots: Dictionary = {}
# Gross rewards received this round; purchases never subtract from this ledger.
var round_earnings: Dictionary = {1: 0}
var earning_slots: Dictionary = {1: 1}
var local_spawn := Vector3.ZERO
var local_yaw := 0.0
var generation := 0
var active := false
var avatars: Dictionary = {}
var replicas: Dictionary = {}
var bolt_replicas: Dictionary = {}
var local_area: Area3D
var clock := 0.0
var last_snapshot := 0.0
var last_shot: Dictionary = {}
var coffee_ready: Dictionary = {}
var shooter := 1
var current_serial := -1
var previous_wave := -1
var previous_mode := ""
var status := "Solo"
var join_address := "127.0.0.1"
var awaiting_spawn := false
var join_deadline := 0
var connection_error := ""
var requested_host := false
func _ready() -> void:
	name = "Coop"
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_failed)
# Local split screen uses no network peer, socket, handshake or public slot.
var local_partner: Node
var local_peer_id := 0
var local_sender := 0
func server() -> bool: return local_peer_id==1 if local_peer_id>0 else multiplayer.is_server()
func peer_id() -> int: return local_peer_id if local_peer_id>0 else multiplayer.get_unique_id()
func sender_id() -> int: return local_sender if local_peer_id>0 else multiplayer.get_remote_sender_id()
func client() -> bool: return active and not server()
func send_to(id: int,method: String,args: Array = []) -> void:
	if local_peer_id>0:
		if is_instance_valid(local_partner) and local_partner.active and id==local_partner.local_peer_id:
			local_partner.receive_local(method,args.duplicate(true),local_peer_id)
		return
	callv("rpc_id",[id,method]+args)
func send_all(method: String,args: Array = [],include_self: bool = false) -> void:
	if local_peer_id>0:
		if is_instance_valid(local_partner): send_to(local_partner.local_peer_id,method,args)
		if include_self: callv(method,args)
		return
	# Existing @rpc annotations retain authority, reliability and call_local.
	callv("rpc",[method]+args)
func receive_local(method: String,args: Array,source: int) -> void:
	if not active or not is_instance_valid(local_partner) or source!=local_partner.local_peer_id: return
	var previous:=local_sender
	local_sender=source
	callv(method,args)
	local_sender=previous
func setup_local(partner: Node,id: int) -> void:
	leave()
	local_partner=partner; local_peer_id=id; active=true
	status="LOCAL TWO-PLAYER / FRIENDLY FIRE ON"
	local_area=Avatar.hitbox(game.player,id)
func host_session() -> void:
	if is_instance_valid(game.split_session): return
	leave()
	requested_host=true
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port,2)
	if result!=OK:
		fail_connection("Could not host on UDP %d: %s. Close another hosted game before retrying." % [port,error_string(result)])
		return
	multiplayer.multiplayer_peer = peer
	active = true
	status = "HOST / UDP %d / 1 OF 3" % port
	local_area = Avatar.hitbox(game.player,1)
	game.start_from_menu()
func join_session(address: String) -> void:
	if is_instance_valid(game.split_session): return
	leave()
	requested_host=false
	join_address=address.strip_edges()
	if join_address.is_empty():
		fail_connection("Enter the host's IP address before joining.")
		return
	connection_error=""
	status="CONNECTING TO "+join_address
	awaiting_spawn=true
	join_deadline=Time.get_ticks_msec()+30000
	game.set_mode("connecting")
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(join_address,port)
	if result!=OK:
		fail_connection("Could not join %s: %s" % [join_address,error_string(result)])
		return
	multiplayer.multiplayer_peer = peer
	active = true
func leave() -> void:
	local_partner=null; local_peer_id=0; local_sender=0
	active = false
	awaiting_spawn=false
	slots.clear()
	generation = 0
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for avatar in avatars.values(): avatar.queue_free()
	avatars.clear()
	for animal in replicas.values(): animal.queue_free()
	replicas.clear()
	for bolt in bolt_replicas.values(): bolt.queue_free()
	bolt_replicas.clear()
	if is_instance_valid(local_area): local_area.queue_free()
	status = "Solo"
	previous_wave = -1
func _failed() -> void:
	fail_connection("Connection to %s ended. Check that the host is running, has a free player slot, and accepts UDP %d." % [join_address,port])
func fail_connection(message: String) -> void:
	leave()
	connection_error=message
	status=message
	game.set_mode("connection_error")
func retry_connection() -> void:
	if requested_host: host_session()
	else: join_session(join_address)
func _connected() -> void:
	status = "CONNECTED / WAITING FOR HOST SPAWN"
	game.start_from_menu()
	game.set_mode("connecting")
	local_area = Avatar.hitbox(game.player,peer_id())
	send_to(1,"ready_player",[])
func _peer_connected(id: int) -> void:
	if not server(): return
	var avatar = Avatar.new()
	avatar.peer_id = id
	var slot := 1
	while slots.values().has(slot): slot += 1
	slots[id] = slot
	round_earnings[id] = 0
	earning_slots[id] = slot+1
	avatar.position = spawn_point(id)
	game.add_child(avatar)
	avatars[id] = avatar
	status = "LOCAL TWO-PLAYER / FRIENDLY FIRE ON" if local_peer_id>0 else "HOST / UDP %d / %d OF 3" % [port,avatars.size()+1]
func _peer_left(id: int) -> void:
	if avatars.has(id): release_remote_maul(id)
	if avatars.has(id): avatars[id].queue_free(); avatars.erase(id)
	last_shot.erase(id)
	slots.erase(id)
	round_earnings.erase(id)
	earning_slots.erase(id)
	check_team_wipe()
@rpc("any_peer","reliable")
func ready_player() -> void:
	if not server(): return
	var id := sender_id()
	if not avatars.has(id): return
	avatars[id].position = spawn_point(id)
	if not avatars[id].has_meta("start_money_applied"):
		avatars[id].set_meta("start_money_applied",true)
		if game.session_start_money>=0: send_to(id,"starting_wallet",[game.session_start_money])
	wake_remote(id,false)
@rpc("authority","reliable")
func starting_wallet(amount: int) -> void:
	game.progress.money=clampi(amount,0,2000000000)
	game.progress.save_progress()

func spawn_point(id: int) -> Vector3:
	if id==1: return game.world.bed_wake_position
	var house: Dictionary = game.world.exploration_data.houses[int(slots.get(id,1))-1]
	var nav = game.world.nav
	return nav.point(nav.nearest(house.center[0],house.center[1],2))
func spawn_yaw(id: int) -> float:
	if id==1: return game.world.bed_wake_yaw
	var house: Dictionary = game.world.exploration_data.houses[int(slots.get(id,1))-1]
	var p := spawn_point(id)
	return atan2(p.x-float(house.door[0]),p.z-float(house.door[2]))
func wake_remote(id: int,recovery: bool) -> void:
	send_to(id,"wake_player",[game.level,game.world.weather.season,game.world.weather.hour,game.world.weather.blood_moon,spawn_point(id),spawn_yaw(id),generation,recovery])
@rpc("authority","reliable")
func wake_player(wave: int,season: int,hour: int,blood: bool,spawn: Vector3,yaw: float,epoch: int,recovery: bool = false) -> void:
	awaiting_spawn=false
	status="LOCAL TWO-PLAYER / FRIENDLY FIRE ON" if local_peer_id>0 else "CONNECTED / FRIENDLY FIRE ON"
	generation = epoch
	local_spawn = spawn
	local_yaw = yaw
	game.level = wave
	game.health = game.maximum_health()
	game.player.clear_injuries()
	game.player.reset_at(spawn)
	game.player.yaw = yaw
	game.player._update_rotation()
	game._replenish_ammunition()
	game.bandages = 2
	game.progress.best_level = maxi(game.progress.best_level,wave)
	game.progress.save_progress()
	if recovery: game.begin_rest()
	game.world.weather.season = season
	game.world.weather.hour = hour
	game.world.weather.blood_moon = blood
	game.world.weather.apply()
	if is_instance_valid(local_area): local_area.collision_layer = 2
	if not recovery:
		game.affliction.infected_wave = -1
		game.set_mode("playing")

func nearest_hunter(point: Vector3) -> Node3D:
	var best: Node3D = game.player
	var distance := point.distance_squared_to(best.position)
	if game.health<=0 or game.world.is_safe_position(best.position): distance = INF
	for avatar in avatars.values():
		if avatar.health>0 and not game.world.is_safe_position(avatar.position) and point.distance_squared_to(avatar.position)<distance:
			best = avatar
			distance = point.distance_squared_to(avatar.position)
	return best

func host_started() -> void:
	if not active or client(): return
	generation += 1
	previous_wave = game.level
	local_spawn = spawn_point(1)
	local_yaw = spawn_yaw(1)
	game.player.reset_at(local_spawn)
	game.player.yaw = local_yaw
	game.player._update_rotation()
	if is_instance_valid(local_area): local_area.collision_layer = 2
	for id in avatars:
		avatars[id].remove_meta("infected_wave")
		avatars[id].health = avatar_maximum(avatars[id])
		avatars[id].mauling = 0
		avatars[id].position = spawn_point(id)
		wake_remote(id,false)
@rpc("any_peer","reliable")
func restart_run() -> void:
	if server() and avatars.has(sender_id()) and game.mode in ["dead","victory"]: game.start_run()
@rpc("any_peer","reliable")
func treated() -> void:
	if not server(): return
	var id := sender_id()
	if avatars.has(id) and game.world.services.near_store(avatars[id].position): avatars[id].health = avatar_maximum(avatars[id])

@rpc("any_peer","reliable")
func request_coffee(cabin: int) -> void:
	if server(): serve_coffee(sender_id(),cabin)
func serve_coffee(peer: int,cabin: int) -> void:
	if cabin<0 or cabin>=game.world.services.cabins.size(): return
	if peer!=1 and not avatars.has(peer): return
	var hunter: Node3D=game.player if peer==1 else avatars[peer]
	var hp: float=game.health if peer==1 else hunter.health
	if hp<=0 or game.world.services.nearby_coffee(hunter.position)!=cabin: return
	if (peer==1 and game.is_struggling()) or (peer!=1 and hunter.mauling!=0): return
	var key: String="%d:%d"%[peer,cabin]
	var now:=Time.get_ticks_msec()/1000.0
	var wait_left:=maxf(0,float(coffee_ready.get(key,0))-now)
	var maximum: float=game.maximum_health() if peer==1 else avatar_maximum(hunter)
	var gained:=0.0
	if wait_left<=0 and hp<maximum:
		gained=minf(30,maximum-hp)
		hp+=gained
		coffee_ready[key]=now+20
	if peer==1: coffee_result(hp,gained,wait_left)
	else:
		hunter.health=hp
		send_to(peer,"coffee_result",[hp,gained,wait_left])
@rpc("authority","reliable")
func coffee_result(hp: float,gained: float,wait_left: float) -> void:
	game.health=clampf(hp,0,game.maximum_health())
	game.show_notice("Warm coffee / +%d HP"%roundi(gained) if gained>0 else ("Coffee brewing / %d seconds"%ceili(wait_left) if wait_left>0 else "Already at full health."),3)
func anyone_outside() -> bool:
	for avatar in avatars.values():
		if avatar.health>0 and not game.world.is_safe_position(avatar.position) and avatar.position.distance_to(spawn_point(avatar.peer_id))>5: return true
	return false
func _process(delta: float) -> void:
	if awaiting_spawn and Time.get_ticks_msec()>join_deadline:
		fail_connection("The host did not finish joining within 30 seconds. Check the IP address, free player slots and UDP %d, then retry." % port)
		return
	if not active: return
	if is_instance_valid(local_area): local_area.collision_layer = 2 if game.health>0 else 0
	clock += delta
	if clock-last_snapshot<.08: return
	last_snapshot = clock
	if client():
		if local_peer_id>0 or multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
			send_to(1,"pose",[game.player.position,game.player.yaw,game.player.is_crouching,game.player.get_noise_level(),game.health,game.current_weapon,game.player.is_sprinting,generation])
		return
	check_team_wipe()
	var hunters: Array = [{"id":1,"p":game.player.position,"yaw":game.player.yaw,"health":game.health,"weapon":game.current_weapon,"earned":round_earnings.get(1,0),"slot":1}]
	for id in avatars:
		var avatar = avatars[id]
		if avatar.mauling!=0:
			var attacker=instance_from_id(avatar.mauling) if is_instance_id_valid(avatar.mauling) else null
			if not is_instance_valid(attacker) or attacker.dead or avatar.health<=0 or game.world.is_safe_position(avatar.position): release_remote_maul(id)
		hunters.append({"id":id,"p":avatar.position,"yaw":avatar.rotation.y,"health":avatar.health,"weapon":maxi(0,avatar.weapon_index),"earned":round_earnings.get(id,0),"slot":int(slots.get(id,1))+1})
	var animals: Array = []
	for wolf in game.wolves+game.nodes_in_group("wolf_corpses"):
		animals.append({"id":wolf.get_instance_id(),"limbs":wolf.limbs.snapshot() if wolf.limbs else {},"p":wolf.position,"yaw":wolf.rotation.y,"health":wolf.health,"seed":int(wolf.profile.profile_seed),"boss":wolf.werewolf,"mission":wolf.get_meta("mission",false),"type":"wolf","move":wolf._velocity.length(),"max_health":wolf.max_health,"behavior":wolf.behavior,"injuries":wolf.leg_injuries,"severed":wolf.severed_legs,"side":wolf.reaction.side if wolf.reaction else 1.0,"alerted":wolf.alerted,"dead":wolf.dead,"down":wolf.reaction.down if wolf.reaction else 0.0,"flinch":wolf.reaction.flinch if wolf.reaction else 0.0})
	for animal in game.nodes_in_group("wildlife"):
		animals.append({"id":animal.get_instance_id(),"limbs":animal.limbs.snapshot(),"max_health":animal.max_health,"p":animal.position,"yaw":animal.rotation.y,"health":animal.health,"type":animal.species,"bleed":animal.bleeding_rate,"fear":animal.fear_left,"alerted":animal.alerted,"move":animal.velocity.length(),"aquatic":animal.aquatic,"dead":animal.dead,"down":animal.reaction.down,"flinch":animal.reaction.flinch})
	for actor in game.nodes_in_group("campaign_threats"):
		animals.append({"id":actor.get_instance_id(),"limbs":actor.limbs.snapshot() if actor.limbs else {},"p":actor.position,"yaw":actor.rotation.y,"health":actor.health,"type":actor.species,"weapon":actor.raider_weapon,"dead":actor.dead,"mission":actor.get_meta("mission",false),"down":actor.reaction.down,"flinch":actor.reaction.flinch,"move":2.8 if not actor.route.is_empty() else 0.0,"alerted":actor.alerted,"reload":actor.cooldown>1.0,"attack":actor.species=="legionary" and actor.cooldown>.85})
	var projectiles: Array = []
	for bolt in game.nodes_in_group("player_bolts")+game.nodes_in_group("enemy_bolts"):
		projectiles.append({"id":bolt.get_instance_id(),"p":bolt.position,"v":bolt.velocity,"type":bolt.spec.id,"fuse":maxf(0,float(bolt.spec.get("fuse",0))-float(bolt.get("age"))) if bolt.spec.get("explosive",false) and not bolt.spec.get("launcher",false) else -1.0})
	for id in connected_peers():
		send_to(id,"state",[hunters,animals,game.level,game.mode,game.intermission,game.pending_spawns,game.wave_total,projectiles,game.world.houses.drops,game.wave_kills,generation,game.campaign.snapshot()])
	if game.level!=previous_wave and game.mode=="resting":
		generation += 1
		for id in avatars:
			avatars[id].health = avatar_maximum(avatars[id])
			avatars[id].position = spawn_point(id)
			avatars[id].mauling = 0
		for id in avatars: wake_remote(id,true)
		previous_wave = game.level
@rpc("any_peer","unreliable_ordered")
func pose(p: Vector3,yaw: float,crouch: bool,noise: float,hp: float,weapon: int,sprinting: bool = false,epoch: int = 0) -> void:
	if epoch!=generation: return
	if not server() or not p.is_finite() or not is_finite(yaw) or not is_finite(hp): return
	var id := sender_id()
	if not avatars.has(id): return
	var avatar = avatars[id]
	var offset: Vector3 = p-avatar.position
	if offset.length()>3.0: send_to(id,"correct_position",[avatar.position]); return
	avatar.position = game.world.nav.move_position(avatar.position,offset.x,offset.z)
	avatar.rotation.y = yaw
	avatar.equip(weapon)
	avatar.set_meta("sprinting",sprinting)
	avatar.is_crouching = crouch
	avatar.noise = clampf(noise,0,1)
	avatar.visibility_factor = .48 if crouch else 1.0
	avatar._actual_speed = Vector2(offset.x,offset.z).length()/.08
	avatar.health = minf(avatar.health,clampf(hp,0,avatar_maximum(avatar)))
	if avatar.health<=0: avatar.mauling = 0
	avatar.visible = avatar.health>0
	avatar.area.collision_layer = 2 if avatar.health>0 else 0
	check_team_wipe()
@rpc("authority","reliable")
func correct_position(p: Vector3) -> void: game.player.position = p
@rpc("authority","call_remote","reliable",1)
func state(hunters: Array,animals: Array,wave: int,mode: String,waiting: bool,pending: int,total: int,projectiles: Array,loot: Array,hunted: int,epoch: int,mission: Dictionary = {}) -> void:
	if not client() or epoch!=generation: return
	game.campaign.apply_snapshot(mission)
	if mode=="victory" and game.mode!="victory": game.set_mode("victory")
	game.wave_kills = hunted
	game.world.houses.apply_drops(loot)
	game.level = wave
	game.intermission = waiting
	game.pending_spawns = pending
	game.wave_total = total
	if mode=="dead" and game.mode!="dead": team_failed()
	round_earnings.clear(); earning_slots.clear()
	var seen: Array = []
	for hunter: Dictionary in hunters:
		var id: int = hunter.id
		round_earnings[id] = int(hunter.get("earned",0))
		earning_slots[id] = int(hunter.get("slot",1))
		if id==peer_id(): continue
		seen.append(id)
		if not avatars.has(id):
			var avatar = Avatar.new()
			avatar.peer_id = id
			game.add_child(avatar)
			avatars[id] = avatar
		avatars[id].position = hunter.p
		avatars[id].rotation.y = hunter.yaw
		avatars[id].health = hunter.health
		avatars[id].visible = hunter.health>0
		avatars[id].area.collision_layer = 2 if hunter.health>0 else 0
		avatars[id].equip(int(hunter.weapon))
	for id in avatars.keys():
		if not seen.has(id): avatars[id].queue_free(); avatars.erase(id)
	seen.clear()
	game.wolves.clear()
	for animal: Dictionary in animals:
		var id: int = animal.id
		seen.append(id)
		if not replicas.has(id):
			var node: Node3D
			if animal.type=="wolf":
				node = preload("res://scripts/wolf.gd").new()
				node.configure(game,game.world.wolf_nav,mini(wave,12),int(animal.seed))
			elif animal.type in ["bear","raider","legionary","musketeer"]:
				node=preload("res://scripts/musketeer.gd").new() if animal.type=="musketeer" else preload("res://scripts/legionary.gd").new() if animal.type=="legionary" else preload("res://scripts/campaign_threat.gd").new()
				node.game=game; node.species=animal.type
				node.raider_weapon=int(animal.get("weapon",21))
			else:
				node = preload("res://scripts/wildlife.gd").new()
				node.game = game
				node.species = animal.type
			game.add_child(node)
			node.set_physics_process(false)
			if animal.type=="wolf" and animal.boss: node.make_werewolf()
			replicas[id] = node
		var node: Node3D = replicas[id]
		node.set_meta("mission",animal.get("mission",false))
		if node.has_method("set_network_pose"): node.set_network_pose(animal.p,animal.yaw)
		else:
			node.position = animal.p
			node.rotation.y = animal.yaw
		apply_animal_life(node,animal)
		if animal.type in ["raider","legionary","musketeer"]:
			node.model.get_child(0).set_motion(float(animal.get("move",0)),false,animal.get("alerted",false),animal.get("attack",false))
			node.model.get_child(0).set_process(not node.dead)
		if animal.type=="musketeer": node.model.get_child(0).reloading=animal.get("reload",false)
		if animal.type=="wolf" and node.werewolf: node.model.set_process(not node.dead)
		if animal.type not in ["wolf","bear","raider","legionary","musketeer"]:
			node.aquatic = animal.get("aquatic",false)
			if animal.get("bleed",0)>0 and not node.aquatic and clock-float(node.get_meta("last_trail",-10))>.55:
				game.gore.blood_pool(node.position,.13)
				node.set_meta("last_trail",clock)
			node.update_animation(float(animal.get("move",0)))
		if animal.type=="wolf":
			if not node.dead: game.wolves.append(node)
			node.alerted = animal.get("alerted",false)
			node._phase += .08
			if not node.dead and node.reaction.down<=0: node._animate(float(animal.move),node.behavior in ["charge","maul"])
	for id in replicas.keys():
		if not seen.has(id):
			if game.struggle_wolf==replicas[id]: game.end_wolf_struggle(true)
			replicas[id].queue_free()
			replicas.erase(id)
	seen.clear()
	for projectile: Dictionary in projectiles:
		var id: int = projectile.id
		seen.append(id)
		if not bolt_replicas.has(id):
			var visual := Node3D.new()
			game.add_child(visual)
			var catalog = preload("res://scripts/weapon_catalog.gd")
			var field_id: int={"throwing_knife":18,"throwing_axe":19,"hunting_spear":20,"iron_grenade":24,"dynamite":25}.get(projectile.type,-1)
			if field_id>=0:
				var model: Dictionary = preload("res://scripts/weapon_model_builder.gd").new().build(field_id)
				visual.add_child(model.root)
			else:
				var shaft := MeshInstance3D.new()
				var shape := CylinderMesh.new()
				shape.top_radius = .008
				shape.bottom_radius = .008
				shape.height = .48
				shaft.mesh = shape
				shaft.rotation.x = PI/2
				visual.add_child(shaft)
			bolt_replicas[id] = visual
		bolt_replicas[id].position = projectile.p
		if float(projectile.get("fuse",-1))>=0:
			var label=bolt_replicas[id].get_node_or_null("Fuse")
			if not label:
				label=Label3D.new(); label.name="Fuse"; label.position.y=.35; label.font_size=42; label.pixel_size=.006; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.modulate=Color("ffb25b"); bolt_replicas[id].add_child(label)
			label.text="%.1f s"%float(projectile.fuse)
		if projectile.v.length_squared()>.001: bolt_replicas[id].look_at(projectile.p+projectile.v)
	for id in bolt_replicas.keys():
		if not seen.has(id): bolt_replicas[id].queue_free(); bolt_replicas.erase(id)
func submit_shot(origin: Vector3,direction: Vector3,weapon: int,serial: int,secondary: bool = false) -> void:
	send_to(1,"shoot",[origin,direction,weapon,serial,secondary])
@rpc("any_peer","reliable")
func shoot(origin: Vector3,direction: Vector3,weapon: int,serial: int,secondary: bool = false) -> void:
	if not server(): return
	var id := sender_id()
	if not avatars.has(id) or weapon<0 or weapon>=game.WEAPONS.size() or not origin.is_finite() or not direction.is_finite(): return
	var avatar = avatars[id]
	if avatar.get_meta("sprinting",false) or avatar.health<=0 or game.world.is_safe_position(avatar.position) or origin.distance_to(avatar.position)>2.3 or direction.length()<.9: return
	var spec: Dictionary = preload("res://scripts/weapon_catalog.gd").secondary_weapon() if weapon==9 and secondary else preload("res://scripts/weapon_catalog.gd").weapon(weapon)
	if clock-float(last_shot.get(id,-100)) < float(spec.interval)*.9: return
	last_shot[id] = clock
	shooter = id
	current_serial = serial
	broadcast_gunshot(str(spec.sound),origin,id)
	game.frighten_wildlife(origin,float(spec.noise_radius))
	for wolf in game.wolves:
		if wolf.position.distance_to(origin)<float(spec.noise_radius): wolf.hear_gunshot(origin)
	if avatar.get_meta("sprinting",false): spec.spread = maxf(float(spec.spread)*4,.085)
	for pellet in int(spec.pellets):
		var dir := (direction.normalized()+Vector3(randf_range(-spec.spread,spec.spread),randf_range(-spec.spread,spec.spread),randf_range(-spec.spread,spec.spread))).normalized()
		if float(spec.projectile_speed)>0:
			var bolt := preload("res://scripts/crossbow_bolt.gd").new()
			game.add_child(bolt)
			bolt.launch(game,origin,dir,spec)
			bolt.shooter_peer = id
			bolt.review_serial = serial
		else:
			var excluded: Array[RID]=[avatar.area.get_rid()]
			game.fire_ballistic(origin,dir,spec,serial,id,excluded)
	shooter = 1
	current_serial = -1
func friendly_hit(id: int,amount: float) -> float:
	if not active or client() or id==shooter: return 0
	if id==1:
		var before: float = game.health
		game.receive_gunshot(amount)
		return before-game.health
	elif avatars.has(id) and not game.world.is_safe_position(avatars[id].position):
		var before: float = avatars[id].health
		avatars[id].health = maxf(0,avatars[id].health-amount)
		send_to(id,"hurt",[amount])
		return before-avatars[id].health
	return 0
@rpc("authority","reliable")
func hurt(amount: float) -> void: game.receive_gunshot(amount)
func deliver_report(report: Dictionary,serial: int) -> void:
	send_to(shooter,"shot_result",[report,serial])
@rpc("authority","reliable")
func shot_result(report: Dictionary,serial: int) -> void:
	game.shot_review.record(report,serial)
func deliver_path(peer: int,serial: int,path: Dictionary) -> void:
	if peer==1: game.shot_review.record_path(path,serial)
	elif active: send_to(peer,"shot_path_result",[path,serial])
@rpc("authority","reliable")
func shot_path_result(path: Dictionary,serial: int) -> void:
	game.shot_review.record_path(path,serial)
func projectile_finished(peer: int,serial: int) -> void:
	if active and peer!=1: send_to(peer,"shot_miss",[serial])
@rpc("authority","reliable")
func shot_miss(serial: int) -> void:
	if game.shot_review.serial==serial and game.shot_review.reports.is_empty() and game.shot_review.trajectories.is_empty():
		game.shot_review.caption = "MISS — NO ANIMAL HIT"
		if not game.shot_review.dismissed: game.shot_review.remaining = game.shot_review.DISPLAY_SECONDS
		game.shot_review.queue_redraw()
func reset_round_earnings() -> void:
	round_earnings = {1: 0}; earning_slots = {1: 1}
	if not client():
		for id in avatars:
			round_earnings[id] = 0
			earning_slots[id] = int(slots.get(id,1))+1
func earnings_text() -> String:
	var ids: Array = round_earnings.keys()
	ids.sort_custom(func(a,b): return int(earning_slots.get(a,1)) < int(earning_slots.get(b,1)))
	var parts: PackedStringArray = []
	for id in ids:
		parts.append("P%d +%d" % [int(earning_slots.get(id,1)),int(round_earnings[id])])
	return "ROUND CR  /  " + " · ".join(parts)
func award(amount: int) -> void:
	if client(): return
	round_earnings[1] = int(round_earnings.get(1,0))+amount
	if active:
		for id in connected_peers(): round_earnings[id] = int(round_earnings.get(id,0))+amount
		send_all("grant_money",[amount])
@rpc("authority","reliable")
func grant_money(amount: int) -> void:
	game.progress.money += amount
	game.progress.save_progress()
func begin_remote_maul(wolf: Node3D,avatar: Node3D) -> bool:
	if avatar.mauling!=0: return false
	if wolf.werewolf and not avatar.has_meta("infected_wave"): avatar.set_meta("infected_wave",game.level)
	avatar.mauling = wolf.get_instance_id()
	send_to(avatar.peer_id,"maul",[wolf.get_instance_id()])
	return avatar.mauling==wolf.get_instance_id()
@rpc("authority","reliable")
func maul(id: int) -> void:
	if not replicas.has(id) or not game.start_wolf_struggle(replicas[id]): send_to(1,"escape",[])
@rpc("any_peer","reliable")
func escape() -> void:
	if not server(): return
	var id := sender_id()
	if not avatars.has(id): return
	release_remote_maul(id)

func release_remote_maul(id: int) -> void:
	if not avatars.has(id): return
	var wolf_id: int=avatars[id].mauling
	avatars[id].mauling=0
	if wolf_id==0: return
	if is_instance_id_valid(wolf_id): instance_from_id(wolf_id).end_struggle(true)
	send_to(id,"release_maul",[])

@rpc("authority","reliable")
func release_maul() -> void:
	game.end_wolf_struggle(true)

func broadcast_gunshot(kind: String,point: Vector3,source: int) -> void:
	if not active or client() or not game.sounds.Gunshots.SAMPLES.has(kind): return
	# The shooter has immediate local audio; everyone else hears its world position.
	if source!=1: game.sounds.play_at(kind,point,-8)
	for id in connected_peers():
		if id!=source: send_to(id,"animal_voice",[kind,point,-8,1.0])

func broadcast_voice(kind: String,p: Vector3,volume: float,pitch: float) -> void:
	if active and not client():
		for id in connected_peers(): send_to(id,"animal_voice",[kind,p,volume,pitch])
@rpc("authority","unreliable")
func animal_voice(kind: String,p: Vector3,volume: float,pitch: float) -> void:
	game.sounds.play_at(kind,p,volume,pitch)


func connected_peers() -> Array[int]:
	if local_peer_id>0:
		var peers: Array[int]=[]
		if active and is_instance_valid(local_partner) and local_partner.active: peers.append(local_partner.local_peer_id)
		return peers
	var result: Array[int] = []
	if not active: return result
	var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not transport: return result
	for id in multiplayer.get_peers():
		var peer := transport.get_peer(id)
		if peer and peer.get_state()==ENetPacketPeer.STATE_CONNECTED: result.append(id)
	return result

@rpc("any_peer","reliable")
func take_loot(index: int) -> void:
	if not server(): return
	var id := sender_id()
	if not avatars.has(id) or game.world.houses.nearby(avatars[id].position)!=index: return
	var weapon: int = game.world.houses.drops[index]
	var changed: Array = game.world.houses.drops.duplicate()
	changed[index] = -1
	game.world.houses.apply_drops(changed)
	send_to(id,"grant_loot",[weapon])
@rpc("authority","reliable")
func grant_loot(weapon: int) -> void:
	preload("res://scripts/loot_houses.gd").grant(game,weapon)

func avatar_maximum(avatar: Node3D) -> float:
	var wave: int = avatar.get_meta("infected_wave",-1)
	return 200.0 if wave>=0 and game.level>=wave+5 and game.level%5==0 else 100.0

func any_living() -> bool:
	if game.health>0: return true
	for avatar in avatars.values():
		if avatar.health>0: return true
	return false
func local_down() -> void:
	if is_instance_valid(local_area): local_area.collision_layer = 0
	if client(): send_to(1,"report_down",[generation])
	else: check_team_wipe()
@rpc("any_peer","reliable")
func report_down(epoch: int) -> void:
	if not server() or epoch!=generation: return
	var id := sender_id()
	if avatars.has(id):
		avatars[id].health = 0
		avatars[id].mauling = 0
	check_team_wipe()
func check_team_wipe() -> void:
	if active and not client() and game.mode in ["playing","waiting","paused","shop"] and not any_living(): send_all("team_failed",[],true)
@rpc("authority","call_local","reliable")
func team_failed() -> void:
	game.death_level = game.level
	game.level = 1
	game.end_wolf_struggle(false)
	game.set_mode("dead")

@rpc("authority","call_remote","reliable")
func explosion_effect(point: Vector3,radius: float) -> void:
	var blast:=Node3D.new(); game.add_child(blast); blast.position=point
	blast.name="Explosion"; blast.add_to_group("explosion_effects")
	var lamp:=OmniLight3D.new(); blast.add_child(lamp)
	lamp.light_color=Color("ffb86c"); lamp.omni_range=radius*3; lamp.light_energy=5
	var tween:=blast.create_tween(); tween.tween_property(lamp,"light_energy",0,.35)
	for i in 16:
		var puff:=MeshInstance3D.new(); var sphere:=SphereMesh.new()
		sphere.radius=.55; sphere.height=1.1; sphere.radial_segments=8; sphere.rings=4; puff.mesh=sphere
		var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=Color(1,.42,.06,.9); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material_override=material; blast.add_child(puff)
		var direction:=Vector3(randf_range(-1,1),randf_range(.3,1.3),randf_range(-1,1)).normalized()
		var motion:=puff.create_tween().set_parallel(true)
		motion.tween_property(puff,"position",direction*radius*.75,1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		motion.tween_property(puff,"scale",Vector3.ONE*randf_range(3,6),.65)
		motion.tween_property(material,"albedo_color",Color(.14,.13,.12,0),2.8)
	game.sounds.play_at("explosion",point,0,.9)
	var distance: float=game.player.position.distance_to(point)
	if distance<radius*5: game.player._damage_kick=maxf(game.player._damage_kick,1-distance/(radius*5))
	blast.get_tree().create_timer(3.0).timeout.connect(blast.queue_free)
@rpc("authority","call_remote","unreliable")
func laser_effect(a: Vector3,b: Vector3) -> void: game.beam_effect(a,b)

@rpc("any_peer","reliable")
func mission_interact() -> void:
	if not server(): return
	var id:=sender_id()
	if not avatars.has(id): return
	game.campaign.interact(id)
@rpc("authority","reliable")
func campaign_notice(message: String) -> void:
	game.show_notice(message,9)

func apply_animal_life(node: Node3D, data: Dictionary) -> void:
	if not is_instance_valid(node.reaction):
		node.reaction=preload("res://scripts/animal_reaction.gd").new()
		node.reaction.animal=node; node.add_child(node.reaction)
	node.health=maxf(0,float(data.health))
	if node.get("max_health")!=null: node.max_health=float(data.get("max_health",node.max_health))
	var died: bool=bool(data.get("dead",false)) or node.health<=0
	if died and not node.dead:
		node.dead=true; node.health=0
		node.reaction.die()
		for area in node.find_children("*","Area3D",true,false): area.collision_layer=0
		if node is IslandWolf:
			node.behavior="dead"; node.detection_state="dead"; node._hurt_label.visible=false
			node.remove_from_group("wolves")
	if node.get("limbs")!=null: node.limbs.apply_snapshot(data.get("limbs",{}))
	if node is IslandWolf:
		node.leg_injuries=data.get("injuries",{}).duplicate()
		node.severed_legs.assign(data.get("severed",[]))
		for zone in node.severed_legs:
			var bone_name: String=node.LEG_BONES[zone]
			if node._skeleton and node._joints.has(bone_name): node._skeleton.set_bone_pose_scale(int(node._joints[bone_name][0]),Vector3.ONE*.008)
	if node.dead: return
	node.reaction.down=float(data.get("down",0))
	node.reaction.flinch=float(data.get("flinch",0))
	node.reaction.side=float(data.get("side",1))
	if node is IslandWolf:
		node.behavior=str(data.get("behavior","observe"))
	else:
		if node.get("fear_left")!=null: node.fear_left=float(data.get("fear",0))
		if node.get("alerted")!=null: node.alerted=bool(data.get("alerted",false))

var last_quick_throw: Dictionary={}
@rpc("any_peer","reliable")
func quick_throw_shot(origin: Vector3,direction: Vector3,weapon: int,serial: int) -> void:
	if not server() or weapon not in [18,19,20] or not origin.is_finite() or not direction.is_finite() or direction.length()<.9: return
	var id:=sender_id()
	if not avatars.has(id) or avatars[id].health<=0 or game.world.is_safe_position(avatars[id].position): return
	if avatars[id].get_meta("sprinting",false): return
	if origin.distance_to(avatars[id].position)>3 or clock-float(last_quick_throw.get(id,-100))<.22: return
	last_quick_throw[id]=clock
	var bolt=preload("res://scripts/crossbow_bolt.gd").new(); game.add_child(bolt)
	bolt.launch(game,origin+direction.normalized()*.24,direction.normalized(),preload("res://scripts/weapon_catalog.gd").weapon(weapon))
	bolt.shooter_peer=id; bolt.review_serial=serial

@rpc("authority","call_remote","unreliable")
func ballistic_effect(points: PackedVector3Array,token: String,source: int) -> void:
	if game.combat_fx.ballistic(points,token) and source>=0 and source!=peer_id():
		game.combat_fx.muzzle(points[0],(points[1]-points[0]).normalized())
@rpc("authority","call_remote","unreliable")
func surface_impact(point: Vector3,normal: Vector3,kind: String) -> void:
	game.combat_fx.impact(point,normal,kind)

@rpc("authority","call_remote","unreliable")
func enemy_muzzle(point: Vector3,direction: Vector3) -> void:
	game.combat_fx.muzzle(point,direction)
	game.sounds.play_at("musket",point,-7)
