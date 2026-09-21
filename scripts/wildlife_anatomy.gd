extends RefCounted
static func organs(species: String) -> Array:
	var heart := Vector3(0,.82,.12)
	var brain := Vector3(0,1.38,.61)
	var heart_size := Vector3(.10,.12,.12)
	var brain_size := Vector3(.055,.06,.075)
	if species=="bear":
		heart=Vector3(0,.92,.48); heart_size=Vector3(.15,.17,.18)
		brain=Vector3(0,1.05,1.02); brain_size=Vector3(.13,.13,.14)
	elif species in ["duck","goose"]:
		heart=Vector3(0,.25,.08); heart_size=Vector3(.055,.065,.065)
		brain=Vector3(0,.72 if species=="goose" else .46,.24); brain_size=Vector3(.065,.065,.07)
	elif species=="mink":
		heart=Vector3(0,.13,.06); heart_size=Vector3(.045,.045,.055)
		brain=Vector3(0,.19,.24); brain_size=Vector3(.045,.04,.05)
	return [{"id":"heart","center":heart,"radii":heart_size},{"id":"brain","center":brain,"radii":brain_size},{"id":"lungs","center":heart+Vector3(0,.045,-heart_size.z*.65),"radii":heart_size*Vector3(1.6,1.2,1.5)}]
static func trace(species: String,entry: Vector3,direction: Vector3, penetration: float = .65) -> Dictionary:
	var definitions:=organs(species)
	var torso:=Vector3(.30,.32,.72) if species=="deer" else Vector3(.52,.55,1.03) if species=="bear" else Vector3(.18,.18,.33) if species in ["duck","goose"] else Vector3(.12,.12,.35)
	var center:=Vector3(0,.82,0) if species=="deer" else Vector3(0,.9,0) if species=="bear" else Vector3(0,.24,0) if species in ["duck","goose"] else Vector3(0,.14,0)
	penetration=preload("res://scripts/wolf_anatomy.gd").tissue_length(entry,direction,penetration,[{"center":center,"radii":torso},{"center":definitions[1].center,"radii":definitions[1].radii*1.6}])
	var hit: Array[String] = []
	for organ in organs(species):
		if preload("res://scripts/wolf_anatomy.gd").intersect_ellipsoid(entry,direction,organ.center,organ.radii,penetration)<INF: hit.append(organ.id)
	return {"entry":entry,"end":entry+direction*penetration,"organs":hit,"zone":"BODY","species":species,"multiplier":3.0 if not hit.is_empty() else 1.0,"instant_fatal":hit.has("heart") or hit.has("brain")}
