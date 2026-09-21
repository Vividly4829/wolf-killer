extends Node
const Catalog = preload("res://scripts/campaign_catalog.gd")
const Item = preload("res://scripts/mission_item.gd")
const Threat = preload("res://scripts/campaign_threat.gd")
var game: Node3D
var rng := RandomNumberGenerator.new()
var job: Dictionary = {}
var done: Dictionary = {}
var items: Array[Node3D] = []
var next_id := 1
var running := false
var finished := false
var elapsed := 0.0
var event := "none"
var last_event := "none"
var event_at := 90.0
var warned := false
var event_started := false
var event_origin := Vector3.ZERO
var fever := false
var weather_effect := ""
var wind := Vector3.ZERO
var repair_timer := 0.0
var shots := 0
var last_shot := Vector3.ZERO
var last_carcass := Vector3.ZERO
var pack_serial := 0
var round_wolves_spawned:=0
var selected_houses: Array[Vector3] = []
var round_revision := 0
var completion_pending := false
var rain: CPUParticles3D

func _ready() -> void: rng.randomize()
func reset() -> void:
	clear_round(); last_event="none"; finished=false; rng.randomize()
func clear_round() -> void:
	running=false
	for bolt in game.nodes_in_group("enemy_bolts"): bolt.queue_free()
	for item in items:
		if is_instance_valid(item): item.queue_free()
	items.clear(); done.clear(); selected_houses.clear()
	round_revision+=1
	for threat in game.nodes_in_group("campaign_threats"): threat.queue_free()
	for wolf in game.wolves:
		if is_instance_valid(wolf): wolf.queue_free()
	game.wolves.clear()
	for corpse in game.nodes_in_group("wolf_corpses"): corpse.queue_free()
	for animal in game.nodes_in_group("wildlife"): animal.queue_free()
	for clue in game.nodes_in_group("campaign_clues"): clue.queue_free()
	fever=false; weather_effect=""; wind=Vector3.ZERO
	if is_instance_valid(rain): rain.queue_free()
	game.world.get_node("CoastalAtmosphere").environment.fog_density=.006
	completion_pending=false
func preview() -> Dictionary:
	return Catalog.wave(game.level,1+game.coop.avatars.size())
func begin() -> void:
	clear_round()
	job=preview(); running=true; finished=false; elapsed=0; shots=0; round_wolves_spawned=0
	last_carcass=Vector3.ZERO; warned=false; event_started=false
	for key in job.hunt: done["hunt_"+key]=0
	for key in job.kill: done["kill_"+key]=0
	done.sites=0; done.search=0
	game.wave_total=Catalog.total(job); game.wave_kills=0; game.pending_spawns=0
	game._spawn_wildlife()
	if game.level in [6,7,13,17,24,29]:
		for animal in game.nodes_in_group("wildlife"):
			if not animal.is_queued_for_deletion() and animal.species=="goose": place_waterbird(animal)
	var houses: Array = game.world.houses.positions.duplicate()
	# Seeded Fisher-Yates keeps a run reproducible in tests.
	for i in range(houses.size()-1,0,-1):
		var j:=rng.randi_range(0,i); var swap=houses[i]; houses[i]=houses[j]; houses[j]=swap
	for p in houses:
		var candidate:=reachable(p)
		if distant_from_hunters(candidate,25): selected_houses.append(candidate)
	if selected_houses.is_empty(): selected_houses.append(random_point(40))
	for i in int(job.sites):
		var caption := "HUNTER'S PACK" if game.level in [5,8,25] else ("FIREWOOD & FOOD" if game.level==26 else ("FIREWOOD" if game.level==13 else "SUPPLY CACHE"))
		add_item(site(i),"cache","sites",caption)
	for i in int(job.search): add_item(site(i),"search","search","SEARCH CABIN")
	var groups := 3 if game.level==4 or game.level>=20 else 2
	var pack_centers: Array[Vector3]=[]
	for i in groups:
		var count: int = int(job.wolves)/groups + (1 if i<int(job.wolves)%groups else 0)
		var center:=random_point(35)
		if game.level==4:
			# Several small groups offer a choice of hunting grounds, not one mob.
			for attempt in 32:
				if pack_centers.all(func(p): return p.distance_to(center)>=40): break
				center=random_point(35)
		pack_centers.append(center)
		if count>0 and game.level>10: count=maxi(count,Catalog.pack_size(game.level,rng))
		spawn_pack(count,center,job.kill.has("wolf"))
	for i in int(job.bosses):
		spawn_wolf(random_point(45),true,true,100+i)
	for i in int(job.kill.get("bear",0)):
		var bear=spawn_threat("bear",site(0)+Vector3(4,0,4) if game.level==27 else random_point(40),true)
		if game.level==16:
			bear.health=210; bear.wounded=true
			var route=preload("res://scripts/animal_route.gd").plan(game.world.wolf_nav,site(0),bear.position)
			for p in route: game.gore.blood_pool(p,.12)
	for i in int(job.raiders): spawn_threat("raider",site(0)+Vector3((i%3-1)*4,0,(i/3)*4),job.kill.has("raider"))
	if game.level==21:
		for animal in game.nodes_in_group("wildlife"):
			if animal.is_queued_for_deletion(): continue
			if game.level==21: animal.set_meta("skittish",true)
	# Optional threats can appear in any round, including the opening hunts and moons.
	# Population and quota are independent; extra animals remain valid wolf targets.
	if int(job.wolves)==0 and rng.randf()<lerpf(.10,.45,(game.level-1)/29.0):
		spawn_pack(Catalog.pack_size(game.level,rng),encounter_point(),false)
	event="none"
	if rng.randf()<Catalog.encounter_chance(game.level):
		var choices: Array=["wolves","wolves","patrol","bear"]
		if game.level>=6: choices.append("werewolf")
		if game.level>10: choices.append("legionaries")
		choices.erase(last_event)
		event=choices[rng.randi_range(0,choices.size()-1)]
	last_event=event
	event_at=rng.randf_range(12,36)
	repair_timer=10
	game.show_notice("%02d / %s — %s" % [game.level,job.title,objective_text()],9)

func encounter_point() -> Vector3:
	var nav=game.world.wolf_nav
	var best:=random_point(35)
	var score:=INF
	for attempt in 90:
		var p: Vector3=nav.point(nav.reachable[rng.randi_range(0,nav.reachable.size()-1)])
		var distance:=p.distance_to(game.player.position)
		if distance<30 or distance>85 or not distant_from_hunters(p,30) or game.world.is_safe_position(p): continue
		var sight:=PhysicsRayQueryParameters3D.create(game.player.camera.global_position,p+Vector3.UP,1)
		var visible: bool=game.get_world_3d().direct_space_state.intersect_ray(sight).is_empty() and -game.player.camera.global_basis.z.dot((p-game.player.camera.global_position).normalized())>.4
		var cost:=absf(distance-48)+(100 if visible else 0)
		if cost<score: best=p; score=cost
	return best
func site(index: int) -> Vector3:
	return selected_houses[index%selected_houses.size()] if not selected_houses.is_empty() else random_point(30)
func place_waterbird(animal: Node3D) -> void:
	for attempt in 100:
		var shore:=random_point(70 if game.level==24 else 30)
		if shore.y>2: continue
		for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			var p: Vector3=shore+direction*3.0; p.y=-.1
			animal.water_home=p
			if animal.water_clear(p):
				animal.aquatic=true; animal.position=p; animal.goal=p
				return
	# The known southern cove remains a reachable fallback.
	animal.aquatic=true; animal.position=Vector3(11,-.1,35+rng.randf_range(-3,3)); animal.water_home=animal.position
func reachable(p: Vector3) -> Vector3:
	var nav=game.world.wolf_nav
	var cell: int=nav.nearest(p.x,p.z,8)
	return nav.point(cell) if cell>=0 and nav.reachable.has(cell) else random_point(25)
func random_point(minimum: float = 30) -> Vector3:
	var nav=game.world.wolf_nav
	var fallback: Vector3=game.world.exterior_rally_point
	var best := -1.0
	for i in 180:
		var p: Vector3=nav.point(nav.reachable[rng.randi_range(0,nav.reachable.size()-1)])
		if game.world.is_safe_position(p): continue
		var distance:=p.distance_to(game.player.position)
		for avatar in game.coop.avatars.values(): distance=minf(distance,p.distance_to(avatar.position))
		if distance>best: best=distance; fallback=p
		if distance>=minimum: return p
	return fallback
func spawn_wolf(p: Vector3,boss: bool,mission: bool,pack_id: int) -> Node3D:
	var wolf=game.WolfScript.new()
	wolf.set_meta("campaign_pack",pack_id)
	# Any ordinary wolf can satisfy the introductory cull, including a surprise
	# arrival. Eligibility never increases the number of kills required.
	wolf.set_meta("mission",mission or (not boss and job.kill.has("wolf")))
	wolf.configure(game,game.world.wolf_nav,mini(game.level,12),rng.randi())
	game.add_child(wolf); wolf.position=reachable(p)
	if boss: wolf.make_werewolf()
	game.wolves.append(wolf)
	return wolf
func spawn_pack(count: int,center: Vector3,mission: bool) -> void:
	pack_serial+=1
	var remaining:=maxi(0,Catalog.wolf_budget(game.level,1+game.coop.avatars.size())-round_wolves_spawned)
	for i in mini(count,remaining):
		spawn_wolf(center+Vector3(rng.randf_range(-6,6),0,rng.randf_range(-6,6)),false,mission,pack_serial)
		round_wolves_spawned+=1
func spawn_threat(species: String,p: Vector3,mission: bool) -> Node3D:
	var actor=Threat.new(); actor.game=game; actor.species=species; actor.set_meta("mission",mission)
	game.add_child(actor); actor.position=reachable(p); actor.home=actor.position
	return actor
func add_item(p: Vector3,kind: String,key: String,caption: String,id: int = -1) -> Node3D:
	var item=Item.new(); item.game=game; item.item_id=next_id if id<0 else id; next_id+=1
	item.kind=kind; item.key=key; item.caption=caption
	game.add_child(item); item.position=p; items.append(item)
	return item
func species_key(species: String) -> String:
	return "waterbird" if species in ["duck","goose"] and job.hunt.has("waterbird") else species
func needs_hunt(key: String) -> bool:
	return int(done.get("hunt_"+key,0))<int(job.get("hunt",{}).get(key,0))
func animal_killed(animal: Node3D,paid: bool = true) -> void:
	if not running or game.coop.client() or not paid or not animal.dead or animal.get_meta("mission_counted",false): return
	animal.set_meta("mission_counted",true)
	var species: String=animal.get("species") if animal.get("species")!=null else ("werewolf" if animal.werewolf else "wolf")
	last_carcass=animal.position
	if job.kill.has(species) and animal.get_meta("mission",false):
		done["kill_"+species]=mini(int(job.kill[species]),int(done.get("kill_"+species,0))+1)
	var key:=species_key(species)
	if needs_hunt(key) and not animal.get_meta("ruined_meat",false):
		done["hunt_"+key]=int(done.get("hunt_"+key,0))+1
	refresh_progress()
func refresh_progress() -> void:
	game.wave_kills=0
	for n in done.values(): game.wave_kills+=int(n)
	if job_ready() and not completion_pending:
		completion_pending=true
		_complete_if_ready.call_deferred(round_revision)
func _complete_if_ready(revision: int) -> void:
	# Finish after the hit/interaction has resolved; never reward a same-frame wipe
	# or a stale callback from a restarted expedition.
	if revision!=round_revision: return
	completion_pending=false
	if job_ready() and game.is_playing(): game.complete_wave()
func job_ready() -> bool:
	return running and game.wave_kills>=game.wave_total
func objective_text() -> String:
	var data: Dictionary=job if running else preview()
	var parts: Array[String]=[]
	for key in data.hunt: parts.append("Hunt %s %d/%d" %[key,int(done.get("hunt_"+key,0)),data.hunt[key]])
	for key in data.kill:
		var label: String="Any wolves" if int(data.number)==4 and key=="wolf" else "Kill "+key
		parts.append("%s %d/%d" %[label,int(done.get("kill_"+key,0)),data.kill[key]])
	for key in ["sites","search"]:
		if int(data[key])>0: parts.append("%s %d/%d" %[{"sites":"Find supplies","search":"Search cabins"}[key],int(done.get(key,0)),data[key]])
	return " / ".join(parts)
func target_nodes() -> Array[Node3D]:
	var targets: Array[Node3D]=[]
	if not running: return targets
	for actor in game.wolves+game.nodes_in_group("campaign_threats"):
		if is_instance_valid(actor) and not actor.is_queued_for_deletion() and not actor.dead and actor.get_meta("mission",false): targets.append(actor)
	for animal in game.nodes_in_group("wildlife"):
		if not animal.dead and not animal.is_queued_for_deletion() and needs_hunt(species_key(animal.species)): targets.append(animal)
	for item in items:
		if not item.taken: targets.append(item)
	return targets
func hunter(id: int) -> Node3D:
	if game.coop.client(): return game.player if id==peer() else game.coop.avatars.get(id)
	return game.player if id==1 else game.coop.avatars.get(id)
func peer() -> int: return game.coop.peer_id() if game.coop.active else 1
func nearby(id: int) -> Node3D:
	var actor=hunter(id)
	if not is_instance_valid(actor): return null
	var result: Node3D
	var distance:=2.8
	for item in items:
		if item.taken: continue
		var d: float=actor.position.distance_to(item.position)
		if d>=distance: continue
		var ray=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP,item.position+Vector3.UP*.4,1)
		if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		distance=d; result=item
	return result
func prompt() -> String:
	if not running: return ""
	var item=nearby(peer())
	return "[ E / Y ] SEARCH "+item.caption if item else ""
func interact(id: int) -> bool:
	if not running or game.coop.client(): return false
	var actor=hunter(id)
	if not is_instance_valid(actor) or (game.health if id==1 else actor.health)<=0: return false
	var item=nearby(id)
	if not item: return false
	item.taken=true
	item.visible=false
	done[item.key]=mini(int(job.get(item.key,0)),int(done.get(item.key,0))+1)
	game.show_notice("FOUND / "+item.caption,3)
	refresh_progress()
	return true
func shot_fired(origin: Vector3) -> void:
	if not running: return
	shots+=1; last_shot=origin
	for threat in game.nodes_in_group("campaign_threats"):
		if not threat.dead and threat.position.distance_to(origin)<100: threat.hear(origin)
func _process(delta: float) -> void:
	if is_instance_valid(rain): rain.emitting=running and not game.is_player_safe()
	if not running or game.coop.client() or not game.is_playing(): return
	elapsed+=delta
	if event!="none" and not event_started:
		var armed := elapsed>=event_at or (shots>=2 and elapsed>8)
		if event in ["carcass_pack","bear_claim","scent_pack"]: armed=armed and (last_carcass!=Vector3.ZERO or elapsed>180)
		if armed and not warned: warn_event()
		elif warned and elapsed>=event_at+6: launch_event()
	repair_timer-=delta
	if repair_timer<=0: repair_timer=12; ensure_huntable()
func warn_event() -> void:
	warned=true; event_at=elapsed; event_origin=encounter_point()
	var cues={"legionaries":"Metal rattles beyond the trees. A line of red shields approaches.","werewolf":"A harsh, unnatural roar echoes through the trees.","wolves":"A distant howl. Something is moving beyond the trees.","carcass_pack":"Wolves are calling near the hunting grounds.","scent_pack":"Howls drift along your trail. Wolves are following the hunt.","migration":"Answering howls: the packs are moving.","crossfire":"Gunfire has drawn distant howls.","patrol":"Bootsteps and voices carry from another shore.","scout":"A returning scout whistles in the distance.","pursuit":"Shouts behind you. The camp has noticed the theft.","bear":"Heavy tracks and disturbed brush near the cabins.","bear_claim":"A low bellow carries from the carcass trail.","fog":"Mist is rolling in from the water.","rain":"Dark clouds gather. Rain is coming.","wind":"The wind is rising across the water.","fever":"A chill and a cough. You may be developing a fever."}
	announce(cues.get(event,"Something moves in the distance."))
	if event in ["wolves","carcass_pack","scent_pack","migration","crossfire"]:
		game.sounds.play_at("howl",event_origin,-8)
		if game.coop.active: game.coop.broadcast_voice("howl",event_origin,-8,1.0)
	# A visible clue remains at the approach; no enemy materialises beside a hunter.
	var clue:=Label3D.new(); clue.text="FRESH TRACKS" if event in ["bear","bear_claim"] else "DISTURBED GROUND"
	game.add_child(clue); clue.position=event_origin+Vector3.UP*.25; clue.font_size=24; clue.pixel_size=.006
	clue.billboard=BaseMaterial3D.BILLBOARD_ENABLED; clue.add_to_group("campaign_clues")
func announce(text: String) -> void:
	game.show_notice(text,9)
	if game.coop.active: game.coop.send_all("campaign_notice",[text])
func launch_event() -> void:
	event_started=true
	# Recheck distance after the warning in case a player approached the clue.
	if not distant_from_hunters(event_origin,30): event_origin=encounter_point()
	match event:
		"legionaries":
			if game.level<=10: return
			pack_serial+=1
			for i in mini(12,6+(game.level-11)/5+game.coop.avatars.size()):
				var soldier=preload("res://scripts/legionary.gd").new()
				soldier.game=game; soldier.species="legionary"; soldier.squad=pack_serial; soldier.rank_index=i
				game.add_child(soldier); soldier.position=reachable(event_origin+Vector3((i%3)*1.3,0,(i/3)*1.6))
				soldier.home=soldier.position; soldier.hear(game.player.position)
		"werewolf":
			var beast=spawn_wolf(event_origin,true,false,200+pack_serial)
			beast.hear_gunshot(game.player.position)
		"migration":
			for wolf in game.wolves: wolf.hear_pack_warning(last_shot if last_shot!=Vector3.ZERO else event_origin)
		"wolves","carcass_pack","scent_pack","crossfire":
			var before: int=game.wolves.size()
			spawn_pack(Catalog.pack_size(game.level,rng),event_origin,false)
			for wolf in game.wolves.slice(before): wolf.hear_gunshot(game.player.position)
		"patrol","scout","pursuit":
			for i in mini(6,1+game.level/7+game.coop.avatars.size()):
				var actor=spawn_threat("raider",event_origin+Vector3(i*3,0,0),false)
				actor.home=site(0) if event in ["scout","pursuit"] else random_point(45)
				actor.hear(game.player.position)
		"bear","bear_claim":
			var bear=spawn_threat("bear",event_origin,false)
			bear.hear(game.player.position)
			if game.level>=18 and rng.randf()<.35: spawn_threat("bear",event_origin+Vector3(5,0,3),false).hear(game.player.position)
		"fog","rain","wind":
			weather_effect=event
			if event=="wind": wind=Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))*2
			apply_weather()
		"fever": fever=true; announce("FEVER / Stamina recovery reduced until the next completed round.")
func distant_from_hunters(p: Vector3,minimum: float) -> bool:
	for id in [1]+game.coop.avatars.keys():
		var actor=hunter(id)
		if is_instance_valid(actor) and actor.position.distance_to(p)<minimum: return false
	return true
func apply_weather() -> void:
	var env: Environment=game.world.get_node("CoastalAtmosphere").environment
	env.fog_density=.033 if weather_effect=="fog" else (.013 if weather_effect=="rain" else .006)
	if is_instance_valid(rain): rain.queue_free()
	if weather_effect=="rain":
		rain=CPUParticles3D.new(); game.player.add_child(rain); rain.position.y=8
		rain.amount=260; rain.lifetime=1.1; rain.local_coords=false
		rain.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents=Vector3(9,.2,9)
		rain.direction=Vector3(.12,-1,.05); rain.spread=5; rain.initial_velocity_min=13; rain.initial_velocity_max=17
		var drop:=BoxMesh.new(); drop.size=Vector3(.009,.24,.009)
		var material:=StandardMaterial3D.new(); material.albedo_color=Color(.65,.76,.83,.5)
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; drop.material=material; rain.mesh=drop
func ensure_huntable() -> void:
	# Predation or spoiled meat must never make an objective impossible.
	for key in job.hunt:
		if not needs_hunt(key): continue
		var count:=0
		for a in game.nodes_in_group("wildlife"):
			if not a.dead and not a.is_queued_for_deletion() and species_key(a.species)==key: count+=1
		if count<int(job.hunt[key])-int(done.get("hunt_"+key,0))+2:
			var a=preload("res://scripts/wildlife.gd").new(); a.game=game; a.species="goose" if key=="waterbird" else key
			game.add_child(a); a.position=random_point(45)
func snapshot() -> Dictionary:
	var records: Array=[]
	for item in items: records.append({"id":item.item_id,"p":item.position,"kind":item.kind,"key":item.key,"caption":item.caption,"taken":item.taken})
	return {"job":job,"done":done,"items":records,"running":running,"finished":finished,"fever":fever,"weather":weather_effect,"wind":wind}
func apply_snapshot(data: Dictionary) -> void:
	if data.is_empty(): return
	job=data.job; done=data.done; running=data.running; finished=data.finished; fever=data.fever
	wind=data.wind
	if weather_effect!=data.weather: weather_effect=data.weather; apply_weather()
	var seen: Array=[]
	for record in data.items:
		seen.append(record.id)
		var item: Node3D
		for existing in items:
			if existing.item_id==record.id: item=existing; break
		if not item: item=add_item(record.p,record.kind,record.key,record.caption,record.id)
		item.position=record.p; item.taken=record.taken
	for item in items.duplicate():
		if not seen.has(item.item_id): items.erase(item); item.queue_free()
