extends Node
var animal: Node3D
var down := 0.0
var flinch := 0.0
var falling := false
var side := 1.0
func hit(fraction: float) -> void:
	if animal.dead: return
	flinch = minf(.45,fraction)
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
	animal.model.rotation.z = lerp_angle(animal.model.rotation.z,roll,1-exp(-delta*9))
	animal.model.rotation.x = sin(flinch*25)*flinch*.45

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
