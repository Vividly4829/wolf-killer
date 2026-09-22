extends Node
const BOONS := {
	"deer":{"name":"HART'S VIGOUR","effect":"stamina","factor":.65,"description":"35% less sprint stamina use"},
	"duck":{"name":"MARSH VEIL","effect":"noise","factor":.6,"description":"40% quieter movement"},
	"goose":{"name":"WATCHFUL OMEN","effect":"radar","factor":1.0,"description":"All-animal radar and species icons"},
	"mink":{"name":"SHADOW STEP","effect":"sneak","factor":1.5,"description":"50% faster crouched movement"},
	"wolf":{"name":"PACK HUNGER","effect":"damage","factor":1.2,"description":"20% more weapon damage"},
	"werewolf":{"name":"MOON BLOOD","effect":"health","factor":1.25,"description":"25% more maximum health"},
	"bear":{"name":"IRON HIDE","effect":"resistance","factor":.8,"description":"20% less incoming damage"},
	"raider":{"name":"SLEIGHT OF HAND","effect":"reload","factor":.75,"description":"25% shorter reloads"},
	"legionary":{"name":"UNBROKEN WILL","effect":"struggle","factor":1.35,"description":"35% faster struggle escape"},
	"musketeer":{"name":"DEAD EYE","effect":"accuracy","factor":.7,"description":"30% less weapon spread"}
}
const DURATION := 4.0
var game: Node3D
var boons: Dictionary = {}
var tasks: Dictionary = {}
var visuals: Dictionary = {}
var channel_left := 0.0
var channel_type := ""
var ui: Label
var veil: ColorRect
func _ready() -> void:
	var layer:=CanvasLayer.new(); layer.layer=3; add_child(layer)
	veil=ColorRect.new(); veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); veil.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(veil)
	ui=Label.new(); ui.position=Vector2(345,650); ui.add_theme_font_size_override("font_size",13); ui.add_theme_color_override("font_color",Color("ffa1a1")); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
func kind(animal: Node3D) -> String:
	return ("werewolf" if animal.werewolf else "wolf") if animal is IslandWolf else str(animal.get("species"))
func eligible(animal: Node3D) -> bool:
	return is_instance_valid(animal) and not animal.is_queued_for_deletion() and animal.get("reaction") != null and animal.reaction.incapacitated() and BOONS.has(kind(animal))
func has_boon(species: String,peer: int=0) -> bool:
	var entries: Dictionary=boons
	if peer>0 and peer!=game.coop.peer_id():
		if not game.coop.avatars.has(peer): return false
		entries=game.coop.avatars[peer].get_meta("ritual_boons",{})
	return int(entries.get(species,-1))>game.level
func factor(effect: String,peer: int=0) -> float:
	for species in BOONS:
		if BOONS[species].effect==effect and has_boon(species,peer): return float(BOONS[species].factor)
	return 1.0
func all_radar() -> bool: return game.affliction.psychedelic or has_boon("goose")
func channeling() -> bool: return not channel_type.is_empty()
func clear() -> void:
	for peer in tasks.keys(): cancel(peer)
	boons.clear(); channel_left=0; channel_type=""
func visible_to(animal: Node3D,origin: Vector3,exclude: Array[RID]) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(origin+Vector3.UP,animal.position+Vector3.UP*.45,3)
	query.collide_with_areas=true; query.exclude=exclude
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider==animal or animal.is_ancestor_of(hit.collider)
func nearest() -> Node3D:
	if channeling(): return null
	var best: Node3D=null; var distance:=3.0
	var candidates: Array=game.wolves+game.nodes_in_group("wildlife")+game.nodes_in_group("campaign_threats")
	if game.coop.client(): candidates.append_array(game.coop.replicas.values())
	var exclude: Array[RID]=[]
	if is_instance_valid(game.coop.local_area): exclude.append(game.coop.local_area.get_rid())
	for animal in candidates:
		if not is_instance_valid(animal) or not eligible(animal): continue
		var d: float=game.player.position.distance_to(animal.position)
		if d<distance and visible_to(animal,game.player.position,exclude): best=animal; distance=d
	return best
func target_id(animal: Node3D) -> int:
	if game.coop.client():
		for id in game.coop.replicas:
			if game.coop.replicas[id]==animal: return id
	return animal.get_instance_id()
func start(peer: int,id: int) -> bool:
	if game.coop.client() or tasks.has(peer) or not game.is_playing(): return false
	var target=instance_from_id(id) if is_instance_id_valid(id) else null
	if not eligible(target) or not game.is_ancestor_of(target) or target.has_meta("ritual_owner"): return false
	var hunter: Node3D=game.player if peer==1 else game.coop.avatars.get(peer)
	if not is_instance_valid(hunter): return false
	var hp: float=game.health if peer==1 else hunter.health
	var exclude: Array[RID]=[]
	if peer!=1: exclude.append(hunter.area.get_rid())
	elif is_instance_valid(game.coop.local_area): exclude.append(game.coop.local_area.get_rid())
	if hp<=0 or hunter.position.distance_to(target.position)>3 or not visible_to(target,hunter.position,exclude): return false
	if peer==1 and game.is_struggling(): return false
	if peer!=1 and hunter.mauling!=0: return false
	target.set_meta("ritual_owner",peer)
	tasks[peer]={"target":target,"origin":hunter.position,"health":hp,"left":DURATION,"kind":kind(target),"wave":game.level}
	if peer==1: started(kind(target))
	else: game.coop.send_to(peer,"ritual_started",[kind(target)])
	game.coop.ritual_visual(target.position,peer)
	if game.coop.active: game.coop.send_all("ritual_visual",[target.position,peer])
	return true
func started(species: String) -> void:
	channel_left=DURATION; channel_type=species
	game.player.is_sprinting=false
	game.show_notice("DARK SACRIFICE / Stay still. Taking damage breaks the ritual.",DURATION)
func cancel(peer: int) -> void:
	stop_visual(peer)
	if game.coop.active: game.coop.send_all("ritual_visual_end",[peer])
	if tasks.has(peer):
		var target=tasks[peer].target
		if is_instance_valid(target): target.remove_meta("ritual_owner")
		tasks.erase(peer)
	if peer==1: ended(false)
	elif game.coop.active: game.coop.send_to(peer,"ritual_ended",[false])
func ended(success: bool) -> void:
	channel_left=0; channel_type=""
	if not success: game.show_notice("The ritual was broken.",2.5)
func grant(species: String,expiry: int) -> void:
	if not BOONS.has(species): return
	boons[species]=expiry; channel_left=0; channel_type=""
	game.show_notice("%s / %s / through round %d"%[BOONS[species].name,BOONS[species].description,expiry-1],7)
func _process(delta: float) -> void:
	channel_left=maxf(0,channel_left-delta)
	veil.visible=channeling() and game.mode=="playing"
	veil.color=Color(.24,0,.015,.16+.06*sin(channel_left*9))
	ui.visible=game.mode=="playing"
	var rows: PackedStringArray=[]
	if channeling(): rows.append("DARK SACRIFICE  %d%%"%roundi((1-channel_left/DURATION)*100))
	for species in boons:
		if has_boon(species): rows.append("%s (%d rounds)"%[BOONS[species].name,int(boons[species])-game.level])
	ui.text=" · ".join(rows); ui.size.x=590; ui.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.health=minf(game.health,game.maximum_health())
	if game.coop.client(): return
	for peer in tasks.keys():
		var task: Dictionary=tasks[peer]; var target=task.target
		var hunter: Node3D=game.player if peer==1 else game.coop.avatars.get(peer)
		if not is_instance_valid(hunter) or not is_instance_valid(target) or not eligible(target): cancel(peer); continue
		var hp: float=game.health if peer==1 else hunter.health
		if not game.is_playing() or task.wave!=game.level or hp<task.health or hunter.position.distance_to(task.origin)>.65: cancel(peer); continue
		task.left-=delta
		if task.left>0: continue
		tasks.erase(peer); target.remove_meta("ritual_owner")
		var species: String=task.kind; var expiry: int=game.level+3
		if peer==1: grant(species,expiry)
		else:
			var entries: Dictionary=hunter.get_meta("ritual_boons",{}); entries[species]=expiry; hunter.set_meta("ritual_boons",entries)
			game.coop.send_to(peer,"ritual_boon",[species,expiry])
		game.gore.blood_pool(target.position,.7)
		if target is IslandWolf: target.damage(target.health+1)
		else: target.damage(target.health+1,true)

func stop_visual(peer: int) -> void:
	if is_instance_valid(visuals.get(peer)): visuals[peer].queue_free()
	visuals.erase(peer)
func visual(point: Vector3,peer: int) -> void:
	stop_visual(peer)
	var root:=Node3D.new(); game.add_child(root); root.position=point+Vector3.UP*.10; visuals[peer]=root
	var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(1,.015,.035); material.emission_enabled=true; material.emission=Color(1,0,.02); material.emission_energy_multiplier=4
	var pentagram:=Node3D.new(); root.add_child(pentagram)
	for i in 64:
		var a:=Vector3(cos(i*TAU/64),0,sin(i*TAU/64))*1.5
		var b:=Vector3(cos((i+1)*TAU/64),0,sin((i+1)*TAU/64))*1.5
		ribbon(pentagram,a,b,material,.018)
	for i in 5:
		var a:=Vector3(cos(i*TAU/5-PI/2),0,sin(i*TAU/5-PI/2))*1.4
		var b:=Vector3(cos((i+2)*TAU/5-PI/2),0,sin((i+2)*TAU/5-PI/2))*1.4
		ribbon(pentagram,a,b,material,.025)
	var light:=OmniLight3D.new(); root.add_child(light); light.position.y=1; light.light_color=Color(1,.015,.03); light.light_energy=4; light.omni_range=5
	for i in 12:
		var spark:=MeshInstance3D.new(); var mesh:=SphereMesh.new(); mesh.radius=.05; mesh.height=.1; mesh.radial_segments=6; mesh.rings=3
		spark.mesh=mesh; spark.material_override=material; root.add_child(spark)
		spark.position=Vector3(cos(i*TAU/12),.05,sin(i*TAU/12))*1.2
		var rise:=root.create_tween().set_loops(3); rise.tween_property(spark,"position:y",2.2,1.2); rise.tween_property(spark,"position:y",.05,0)
	var spin:=root.create_tween(); spin.tween_property(pentagram,"rotation:y",TAU,4)
	var pulse:=root.create_tween().set_loops(4); pulse.tween_property(light,"light_energy",1, .5); pulse.tween_property(light,"light_energy",5,.5)
	var music:=AudioStreamPlayer3D.new(); root.add_child(music); music.stream=preload("res://assets/audio/dark_ritual.wav"); music.volume_db=-8; music.max_distance=40; music.play()
	var cleanup:=root.create_tween(); cleanup.tween_interval(4.4); cleanup.tween_callback(root.queue_free)
func ribbon(parent: Node3D,a: Vector3,b: Vector3,material: Material,width: float) -> void:
	var line:=MeshInstance3D.new(); var mesh:=CylinderMesh.new(); mesh.top_radius=width; mesh.bottom_radius=width; mesh.height=a.distance_to(b); mesh.radial_segments=5
	line.mesh=mesh; line.material_override=material; line.position=(a+b)*.5; line.quaternion=Quaternion(Vector3.UP,(b-a).normalized()); parent.add_child(line)
