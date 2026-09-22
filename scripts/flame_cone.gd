extends RefCounted
## One authoritative pulse per trigger interval, once per victim, with wall occlusion.
static func fire(game: Node3D,origin: Vector3,direction: Vector3,spec: Dictionary,serial: int,peer: int,excluded: Array[RID]) -> void:
	if game.coop.client(): return
	direction=direction.normalized()
	var space:=game.get_world_3d().direct_space_state
	var trace: Dictionary=preload("res://scripts/ballistic_trace.gd").cast(space,origin,direction,spec,excluded)
	game.coop.deliver_path(peer,serial,trace.path)
	var nozzle: Vector3=game.player.weapon.to_global(game.player.weapon.muzzle_position) if peer==1 else origin
	if peer!=1 and game.coop.avatars.has(peer): nozzle=game.coop.avatars[peer].weapon.to_global(game.coop.avatars[peer].muzzle)
	game.coop.flame_effect(nozzle,trace.path.points[-1])
	if game.coop.active: game.coop.send_all("flame_effect",[nozzle,trace.path.points[-1]])
	var candidates: Array=game.wolves.duplicate()+game.nodes_in_group("wildlife")+game.nodes_in_group("campaign_threats")
	if game.coop.active: candidates.append(game.player); candidates.append_array(game.coop.avatars.values())
	var seen: Dictionary={}
	for victim in candidates:
		if not is_instance_valid(victim) or victim.is_queued_for_deletion() or seen.has(victim.get_instance_id()): continue
		seen[victim.get_instance_id()]=true
		var hunter: bool=victim==game.player or victim.get("peer_id")!=null
		var id: int=1 if victim==game.player else int(victim.peer_id) if hunter else -1
		if (hunter and id==peer) or (not hunter and victim.dead): continue
		var height:=1.1 if hunter else 1.55 if victim.get("species")=="moose" else .7 if victim is IslandWolf else .82 if victim.get("species") in ["deer","bear"] else .3
		var point: Vector3=victim.global_position+Vector3.UP*height
		var offset:=point-origin; var distance:=offset.length()
		if distance>float(spec.range) or distance<.01 or offset.normalized().dot(direction)<cos(deg_to_rad(28)): continue
		var ray:=PhysicsRayQueryParameters3D.create(origin,point,1); ray.exclude=excluded
		if not space.intersect_ray(ray).is_empty(): continue
		var amount: float=game.damage_at_distance(spec,distance)
		var before: float=game.health if victim==game.player else victim.health
		var actual:=0.0
		if hunter: actual=game.coop.friendly_hit(id,amount)
		else:
			if victim is IslandWolf: victim.damage(amount)
			else: victim.damage(amount,true)
			actual=before-victim.health
		var entry: Vector3=victim.to_local(point)
		var species: String="hunter" if hunter else ("werewolf" if victim.werewolf else "wolf") if victim is IslandWolf else str(victim.species)
		var report: Dictionary={"species":species,"zone":"BURN","entry":entry,"end":entry+Vector3.UP*.04,"organs":[],"multiplier":1.0,"damage":actual,"calculated_damage":amount,"base_damage":spec.damage,"distance":distance,"range_factor":amount/float(spec.damage),"weapon":spec.name,"target_uid":victim.get_instance_id(),"target_transform":victim.global_transform,"body_depth_m":0.0,"fatal":actual>=before,"bleed":0.0}
		if peer==1: game.shot_review.record(report,serial)
		else: game.coop.deliver_report(report,serial)
