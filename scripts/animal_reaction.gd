extends Node
var animal: Node3D
var down := 0.0
var flinch := 0.0
var falling := false
var side := 1.0
var pose := Transform3D.IDENTITY
var rest_model := Transform3D.IDENTITY
var initialized := false
var areas: Dictionary = {}
var elapsed := 0.0
var next_voice := 0.0
var head_skeleton: Skeleton3D
var head_bone:=-1
var head_rest:=Quaternion.IDENTITY
var health_label: Label3D
var label_left := 0.0
func anatomy_transform() -> Transform3D:
	return animal.global_transform*pose
func species_name() -> String:
	return "werewolf" if animal is IslandWolf and animal.werewolf else "wolf" if animal is IslandWolf else str(animal.get("species"))
func pain_voice() -> void:
	var species:=species_name()
	var sound:= "wolf_hurt" if species in ["wolf","werewolf"] else "bear_growl" if species=="bear" else "gun_pain_1" if species in ["raider","legionary","musketeer","angel","devil"] else species+"_hurt"
	animal.game.sounds.play_at(sound,animal.position,-7,randf_range(.92,1.08))
	if animal.game.coop.active and not animal.game.coop.client(): animal.game.coop.broadcast_voice(sound,animal.position,-7,1.0)
func show_health() -> void:
	if animal is IslandWolf:
		animal._hurt_label.text="%d / %d HP"%[ceili(animal.health),ceili(animal.max_health)]
		animal._hurt_label.visible=true; animal._hurt_timer=4.0
		return
	if not is_instance_valid(health_label):
		health_label=Label3D.new(); animal.add_child(health_label)
		health_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; health_label.font_size=36
		health_label.outline_size=8; health_label.pixel_size=.005; health_label.modulate=Color("ffddbc")
		health_label.position.y=.95 if species_name() in ["duck","goose","mink"] else 2.1
	health_label.text="%d / %d HP"%[ceili(animal.health),ceili(animal.max_health)]
	label_left=4.0; health_label.visible=true
func hit(fraction: float) -> void:
	if animal.dead: return
	flinch = minf(.45,fraction)
	if Time.get_ticks_msec()/1000.0>=next_voice:
		next_voice=Time.get_ticks_msec()/1000.0+.7; pain_voice()
	call_deferred("show_health")
	if fraction>=.3:
		down = maxf(down,2.0+fraction)
		side = -1.0 if randf()<.5 else 1.0
		var animation = animal.get("animation")
		if animation: animation.pause()
		if animal.get("behavior")=="maul":
			if animal.game.struggle_wolf==animal: animal.game.end_wolf_struggle(true)
			else: animal.end_struggle(true)
func die() -> void:
	falling = true
	down = 3
	var animation = animal.get("animation")
	if animation: animation.pause()
func _process(delta: float) -> void:
	if not animal.game.is_playing(): return
	if animal.dead and not falling: return
	hold_incapacitated()
	flinch = maxf(0,flinch-delta)
	down = 2.0 if incapacitated() else maxf(0,down-delta)
	var roll := side*1.3 if falling or down>.65 else side*1.3*smoothstep(0,.65,down)
	if not initialized:
		rest_model=animal.model.transform; initialized=true
		for skeleton in animal.model.find_children("*","Skeleton3D",true,false):
			for bone in skeleton.get_bone_count():
				if "head" in skeleton.get_bone_name(bone).to_lower():
					head_skeleton=skeleton; head_bone=bone; head_rest=skeleton.get_bone_pose_rotation(bone); break
	elapsed+=delta
	label_left=maxf(0,label_left-delta)
	if is_instance_valid(health_label): health_label.visible=label_left>0
	var angle:=lerp_angle(pose.basis.get_euler().z,roll,1-exp(-delta*9))
	var height:=.85
	var width:=.30
	match species_name():
		"goose","duck","mink": height=.25; width=.17
		"moose": height=1.5; width=.55
		"werewolf": height=1.3; width=.45
	if animal is IslandWolf and not animal.werewolf:
		height*=animal.size_scale; width*=animal.size_scale
	var center:=Vector3(0,height,0)
	pose.basis=Basis.from_euler(Vector3(sin(flinch*25)*flinch*.45,0,angle))
	var grounded_center:=Vector3(0,lerpf(height,width,abs(sin(angle))),0)
	pose.origin=grounded_center-pose.basis*center
	animal.model.transform=pose*rest_model
	# Body collision and organ coordinates share exactly the visible fall pose.
	for child in animal.get_children():
		if child is Area3D and child.get_meta("hit_zone","")=="body":
			if not areas.has(child): areas[child]=child.transform
			child.transform=pose*areas[child]
	if incapacitated():
		if not animal.game.coop.client() and Time.get_ticks_msec()/1000.0>=next_voice:
			next_voice=Time.get_ticks_msec()/1000.0+randf_range(5,10); pain_voice()
		if is_instance_valid(head_skeleton) and head_bone>=0:
			head_skeleton.set_bone_pose_rotation(head_bone,head_rest*Quaternion(Vector3.UP,sin(elapsed*1.8)*.08))
		# Small breathing/head movements keep a wounded animal visibly alive.
		var heads: Array=animal.model.find_children("*head*","Node3D",true,false)
		for head in heads:
			head.rotation.y=sin(elapsed*1.8)*.10
		for child in animal.model.get_children():
			if child.has_meta("wounded_head"):
				if not child.has_meta("rest_x"): child.set_meta("rest_x",child.position.x)
				child.position.x=float(child.get_meta("rest_x"))+sin(elapsed*1.8)*.012

func incapacitated() -> bool:
	return is_instance_valid(animal) and not animal.dead and animal.health > 0 and animal.health <= animal.max_health * .07 + .00001
func hold_incapacitated() -> bool:
	if not incapacitated(): return false
	down = maxf(down,2.0)
	var animation = animal.get("animation")
	if animation: animation.pause()
	if animal.get("behavior") == "maul":
		if animal.game.struggle_wolf == animal: animal.game.end_wolf_struggle(true)
		else: animal.end_struggle(true)
	if animal.get("behavior") != null: animal.behavior="incapacitated"
	if animal.model.has_method("set_motion"): animal.model.set_motion(0,false,false,false)
	for node in animal.model.get_children():
		if node.has_method("set_motion"): node.set_motion(0,false,false,false)
	return true
