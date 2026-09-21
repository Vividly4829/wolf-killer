extends "res://scripts/campaign_threat.gd"
var squad:=0
var rank_index:=0
func build_raider() -> void:
	var soldier=preload("res://scripts/legionary_model.gd").new()
	soldier.coat_color=Color("8d302c"); soldier.rotation.y=PI; model.add_child(soldier)
func formation_goal(destination: Vector3) -> Vector3:
	var members: Array=[]
	for actor in game.nodes_in_group("campaign_threats"):
		if actor.get("squad")==squad and actor.species=="legionary" and not actor.dead and not actor.is_queued_for_deletion(): members.append(actor)
	members.sort_custom(func(a,b): return a.rank_index<b.rank_index)
	if members.is_empty(): return destination
	var index: int=members.find(self)
	var front: Vector3=(destination-members[0].position); front.y=0; front=front.normalized()
	var side:=Vector3(front.z,0,-front.x)
	# Three abreast at range, spreading to encircle at sword distance.
	if position.distance_to(destination)<4:
		return destination+Vector3(sin(index*TAU/members.size()),0,cos(index*TAU/members.size()))*1.15
	var anchor: Vector3=destination if index==0 else members[0].position
	return anchor+side*((index%3)-1)*1.2-front*(index/3)*1.5
func receive_ballistic_hit(amount: float,point: Vector3,direction: Vector3,zone: String,force: float,vital_bonus: float=1,penetration: float=.65) -> Dictionary:
	var local:=to_local(point)
	var facing:=global_basis.z.normalized()
	# Only front torso hits intersect the raised shield; head, legs and flanks stay exposed.
	var blocked: bool=not dead and reaction.down<=0 and direction.dot(facing)<-.55 and local.y>.45 and local.y<1.43 and local.x>-.18 and local.x<.48
	if blocked and penetration<.8:
		hear(point-direction*8)
		return {"species":"raider","zone":"SHIELD BLOCK","entry":local,"end":local+global_basis.inverse()*direction*.001,"organs":[],"damage":0.0,"calculated_damage":0.0,"multiplier":0.0,"fatal":false,"instant_fatal":false,"bleed":0.0,"tissue":0.0}
	return super(amount*.65 if blocked else amount,point,direction,zone,force,vital_bonus,maxf(.05,penetration-.25) if blocked else penetration)
