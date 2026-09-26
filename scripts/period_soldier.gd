extends "res://scripts/musketeer.gd"
func build_raider() -> void:
	var soldier=preload("res://scripts/period_soldier_model.gd").new()
	soldier.faction=species; soldier.coat_color=Color("77736d") if species=="confederate" else Color("4a5146")
	soldier.rotation.y=PI; model.add_child(soldier)
	raider_weapon=0 if species=="confederate" else 29
	var built=preload("res://scripts/weapon_model_builder.gd").new().build(raider_weapon)
	musket=built.root; muzzle=built.muzzle
	musket.position=Vector3(.17,1.24,.25); musket.rotation.y=PI; model.add_child(musket)
func hear(origin:Vector3) -> void:
	var first:=not alerted
	super(origin)
	if first and species=="nazi" and rank_index==0:
		game.sounds.play_at("enemy_nazi_bark",position,-4,1)
		if game.coop.active: game.coop.broadcast_voice("enemy_nazi_bark",position,-4,1)
func shoot() -> void:
	super()
	if species=="nazi": cooldown=maxf(2.8,cooldown*.5)
