extends Node
var game: Node3D
var sacrifices: Dictionary={}
var soul_cost:=0
var checked_wave:=-1
func reset_run() -> void:
	sacrifices.clear(); soul_cost=0; checked_wave=-1
func sacrifice_completed(peer: int) -> void:
	sacrifices[peer]=int(sacrifices.get(peer,0))+1
	if int(sacrifices[peer])%5!=0: return
	var hunter: Node3D=game.player if peer==1 else game.coop.avatars.get(peer)
	if not is_instance_valid(hunter): return
	var message:="You have provoked the forces of good"
	game.show_notice(message,8)
	if game.coop.active: game.coop.send_all("supernatural_notice",[message])
	for i in 3:
		var angel=spawn("angel",hunter.position+Vector3(cos(i*TAU/3)*14,5,sin(i*TAU/3)*14))
		angel.marked_peer=peer
func spawn(species: String,point: Vector3) -> Node3D:
	var actor=preload("res://scripts/supernatural_actor.gd").new()
	actor.game=game; actor.species=species; game.add_child(actor); actor.position=point; actor.home=point
	return actor
func _process(_delta: float) -> void:
	if game.coop.client() or not game.is_playing() or game.intermission or checked_wave==game.level: return
	checked_wave=game.level
	if randf()>.22 or game.free_play: return
	var nav=game.world.wolf_nav
	var point: Vector3=game.player.position+Vector3(randf_range(-40,40),0,randf_range(-40,40))
	var cell: int=nav.nearest(point.x,point.z,30)
	if cell>=0 and not game.world.is_safe_position(nav.point(cell)) and nav.point(cell).distance_to(game.player.position)>12: spawn("devil",nav.point(cell))
func nearby() -> Node3D:
	var actors: Array=game.nodes_in_group("campaign_threats")
	if game.coop.client(): actors.append_array(game.coop.replicas.values())
	for actor in actors:
		if actor.get("species")=="devil" and not actor.dead and not actor.alerted and actor.position.distance_to(game.player.position)<3:
			return actor
	return null
func deal(peer: int) -> bool:
	if game.coop.client() or not game.is_playing(): return false
	var hunter: Node3D=game.player if peer==1 else game.coop.avatars.get(peer)
	if not is_instance_valid(hunter) or (game.health if peer==1 else hunter.health)<=0: return false
	for devil in game.nodes_in_group("campaign_threats"):
		if devil.species!="devil" or devil.dead or devil.alerted or devil.position.distance_to(hunter.position)>3 or devil.dealt.has(peer): continue
		if not devil.visible_to(hunter.position): continue
		devil.dealt.append(peer)
		if peer==1:
			soul_cost+=1; game.health=minf(game.health,game.maximum_health())
		else:
			var cost:=int(hunter.get_meta("soul_cost",0))+1
			hunter.set_meta("soul_cost",cost); hunter.health=minf(hunter.health,game.coop.avatar_maximum(hunter))
			game.coop.send_to(peer,"soul_changed",[cost])
		var choices: Array=game.rituals.BOONS.keys(); choices.erase("angel")
		for i in 3: game.rituals.give(peer,choices.pick_random())
		game.rituals.visual(devil.position,-peer)
		return true
	return false
