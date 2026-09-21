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
	flinch = maxf(0,flinch-delta)
	down = maxf(0,down-delta)
	var roll := side*1.3 if falling or down>.65 else side*1.3*smoothstep(0,.65,down)
	animal.model.rotation.z = lerp_angle(animal.model.rotation.z,roll,1-exp(-delta*9))
	animal.model.rotation.x = sin(flinch*25)*flinch*.45
