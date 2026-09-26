extends "res://scripts/wildlife.gd"
var hunt_think:=0.0
var bite_left:=0.0
var voice_left:=0.0
var prey:Node3D
func _physics_process(delta:float) -> void:
	if dead or network_replica or game.coop.client() or not game.is_playing(): return
	if reaction.hold_incapacitated(): return
	if game.free_play: super(delta); return
	delta=preload("res://scripts/animal_simulation.gd").step(self,delta)
	if delta<=0: return
	phase+=delta; bite_left=maxf(0,bite_left-delta); voice_left-=delta
	if bleeding_rate>0:
		trail_left-=delta
		if trail_left<=0:
			game.gore.blood_pool(position,.14); trail_left=.7
		set_meta("bleed_tick",true); damage(bleeding_rate*delta,wounded_by_hunter); remove_meta("bleed_tick")
	if dead or reaction.down>0: return
	if game.guardians and game.guardians.defend_against(self,delta): return
	hunt_think-=delta
	if hunt_think<=0:
		hunt_think=.65; prey=null
		var best:=65.0
		for hunter in [game.player]+game.coop.avatars.values():
			var hp:float=game.health if hunter==game.player else hunter.health
			var distance:=position.distance_to(hunter.position)
			if hp>0 and distance<best and not game.world.is_safe_position(hunter.position):
				prey=hunter; best=distance
		alerted=is_instance_valid(prey)
		if alerted and not search:
			search=preload("res://scripts/route_search.gd").new()
			search.start(game.world.wolf_nav,position,prey.position)
	if not is_instance_valid(prey): velocity=Vector3.ZERO; update_animation(0); return
	if game.world.is_safe_position(prey.position): prey=null; route.clear(); return
	if voice_left<=0:
		voice_left=randf_range(3,5); game.sounds.play_at("snarl_0",position,-8,1.35)
		if game.coop.active: game.coop.broadcast_voice("snarl_0",position,-8,1.35)
	if search:
		search.advance()
		if search.finished: route=search.result; search=null
	while not route.is_empty() and Vector2(position.x-route[0].x,position.z-route[0].z).length()<.15: route.remove_at(0)
	velocity=Vector3.ZERO
	if not route.is_empty():
		var offset:=route[0]-position; offset.y=0
		var step:=offset.normalized()*minf(offset.length(),delta*5.5*limbs.speed_factor()*game.world.wolf_nav.vegetation_factor(position))
		var before:=position; position=game.world.wolf_nav.move_position(position,step.x,step.z)
		velocity=(position-before)/maxf(delta,.001)
		rotation.y=lerp_angle(rotation.y,atan2(offset.x,offset.z),delta*8)
	update_animation(velocity.length())
	if bite_left<=0 and position.distance_to(prey.position)<1.8:
		var ray:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.8,prey.position+Vector3.UP,1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			bite_left=1.2
			if prey==game.player: game.receive_wolf_bite(22,position,true)
			else:
				var old:int=game.coop.shooter; game.coop.shooter=0
				game.coop.friendly_hit(prey.peer_id,22); game.coop.shooter=old
				if not prey.has_meta("infected_wave"):
					prey.set_meta("infected_wave",game.level); prey.set_beast(true)
					game.coop.send_to(prey.peer_id,"beast_infection",[])
