extends "res://scripts/campaign_threat.gd"
var marked_peer:=1
var dealt: Array[int]=[]
var wings: Array[Node3D]=[]
func _ready() -> void:
	super._ready()
	max_health=1000 if species=="devil" else 750; health=max_health
	alerted=species=="angel"
func build_raider() -> void:
	var character=preload("res://scripts/field_character.gd").new()
	character.costume=species
	character.coat_color=Color("655342") if species=="devil" else Color("eee6ce")
	character.rotation.y=PI; model.add_child(character)
	if species=="devil":
		character.materials.skin.albedo_color=Color("bc2425")
		var shirt:=character.mat("shirt",Color("ede4cf"))
		character.panel(character.torso,Vector3(0,.50,-.177),Vector3(.115,.25,.025),shirt)
		character.panel(character.torso,Vector3(0,.49,-.196),Vector3(.034,.21,.015),character.materials.dark)
		for side in [-1,1]:
			character.panel(character.torso,Vector3(side*.095,.46,-.185),Vector3(.085,.29,.03),character.materials.shadow)
		var head: Node3D=character.joints.head
		for side in [-1,1]:
			character.segment(head,Vector3(side*.1,.12,0),Vector3(side*.16,.40,.02),.06,0,character.materials.dark)
		# Fine woven checks, lapels and brass buttons distinguish the tweed suit.
		for i in 9:
			character.segment(character.torso,Vector3(-.23,.08+i*.055,-.15),Vector3(.23,.08+i*.055,-.15),.002,.002,character.materials.trim)
		for i in 7:
			character.segment(character.torso,Vector3(-.2+i*.065,.05,-.151),Vector3(-.2+i*.065,.55,-.151),.002,.002,character.materials.trim)
	else:
		var ivory: Material=character.materials.coat
		character.segment(character.torso,Vector3(0,.20,0),Vector3(0,-.45,0),.23,.34,ivory)
		character.panel(character.torso,Vector3(0,.09,-.21),Vector3(.48,.05,.035),character.materials.trim)
		for side in [-1,1]:
			var wing:=Node3D.new(); wing.position=Vector3(side*.20,1.35,-.12); model.add_child(wing); wings.append(wing)
			for feather in 10:
				var end:=Vector3(side*(.5+feather*.095),.45-feather*.11,-.08)
				var feather_mesh:=character.oval(wing,end*.60,Vector3(.10,end.length()*.56,.035),ivory)
				feather_mesh.quaternion=Quaternion(Vector3.UP,end.normalized())
		var gold:=character.mat("gold",Color("ecbe54"))
		for i in 24:
			character.segment(model,Vector3(cos(i*TAU/24)*.23,2.08,sin(i*TAU/24)*.23),Vector3(cos((i+1)*TAU/24)*.23,2.08,sin((i+1)*TAU/24)*.23),.016,.016,gold)
		var sword:=BoxMesh.new(); sword.size=Vector3(.07,.8,.025)
		var blade:=MeshInstance3D.new(); blade.mesh=sword; blade.material_override=character.mat("steel",Color("c8dce1"))
		character.joints.elbowR.add_child(blade); blade.position.y=-.70
func hear(origin: Vector3) -> void:
	if species=="devil" and not alerted: return
	memory=origin; memory_left=30
func _physics_process(delta: float) -> void:
	if dead or game.coop.client() or not game.is_playing(): return
	if reaction.hold_incapacitated(): return
	cooldown=maxf(0,cooldown-delta)
	if not alerted: return
	target=game.player if marked_peer==1 else game.coop.avatars.get(marked_peer)
	if not is_instance_valid(target) or (game.health if target==game.player else target.health)<=0: target=choose_target()
	if not is_instance_valid(target): return
	var destination: Vector3=target.position+Vector3.UP*(.3 if position.distance_to(target.position)<4 else 3.5)
	if game.world.is_safe_position(target.position): destination=home
	var offset: Vector3=destination-position
	var step: Vector3=offset.normalized()*minf(offset.length(),delta*(5.2 if species=="angel" else 3.2))
	var ray:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.9,position+Vector3.UP*.9+step*2,1)
	if species=="devil": position=game.world.wolf_nav.move_position(position,step.x,step.z)
	elif get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): position+=step
	else: position.y+=delta*1.8
	if offset.length()>.1: rotation.y=lerp_angle(rotation.y,atan2(offset.x,offset.z),delta*5)
	model.get_child(0).set_motion(1.0,false,true,cooldown>1)
	if position.distance_to(target.position)<2.2 and cooldown<=0 and visible_to(target.position) and not game.world.is_safe_position(target.position):
		strike(target,30 if species=="angel" else 45); cooldown=1.6
func damage(amount: float,reward_hunter: bool=false) -> void:
	if dead or game.coop.client(): return
	var was_dead:=dead
	if amount>0 and reward_hunter: alerted=true; marked_peer=game.coop.shooter
	super.damage(amount,reward_hunter)
	if dead and not was_dead and paid:
		if species=="angel": game.rituals.give(maxi(1,marked_peer),"angel")
		else: game.coop.award(500)

func _process(delta: float) -> void:
	if dead or not game.is_playing(): return
	phase+=delta
	for i in wings.size(): wings[i].rotation.z=sin(phase*3)*(.30 if i==0 else -.30)
