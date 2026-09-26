extends RefCounted
## Distant actors still roam, bleed and hunt, but need fewer decision updates.
## Every nearby human keeps full-rate simulation, including remote teammates.
static func step(actor:Node3D,delta:float) -> float:
	var game:Node=actor.game
	var nearby:=actor.position.distance_squared_to(game.player.position)<5625.0
	if not nearby:
		for hunter in game.coop.avatars.values():
			if actor.position.distance_squared_to(hunter.position)<5625.0: nearby=true; break
	var accumulated:float=float(actor.get_meta("simulation_delta",0.0))+delta
	if not nearby and accumulated<.12:
		actor.set_meta("simulation_delta",accumulated)
		return 0.0
	actor.set_meta("simulation_delta",0.0)
	return accumulated
