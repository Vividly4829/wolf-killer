extends RefCounted
class_name WolfProfile

## A birth profile is generated once and kept unchanged for the wolf's lifetime.
## These are restrained game-balance ranges for adults, not biological estimates.
## Leadership is a social role: it never supplies size, damage or speed bonuses.
const COATS: Array[Dictionary] = [
	{"name": "silver-gray", "dark": Color("343e40"), "light": Color("81867d")},
	{"name": "charcoal", "dark": Color("202726"), "light": Color("4f5751")},
	{"name": "brown-gray", "dark": Color("413d35"), "light": Color("8b8371")},
	{"name": "tawny", "dark": Color("514334"), "light": Color("a99a7d")},
	{"name": "pale-gray", "dark": Color("686b64"), "light": Color("b5b4a4")},
	{"name": "dark-sable", "dark": Color("302e29"), "light": Color("766f5c")}
]
const EXCEPTIONAL_CHANCE := 0.04

static func generate(level: int, seed: int = -1, leader: bool = false) -> Dictionary:
	var random := RandomNumberGenerator.new()
	var actual_seed := seed
	if actual_seed < 0:
		random.randomize()
		actual_seed = int(random.randi())
	random.seed = actual_seed
	var sex := "male" if random.randf() < 0.5 else "female"
	var exceptional := random.randf() < EXCEPTIONAL_CHANCE
	var size := clampf(random.randfn(1.015 if sex == "male" else 0.945, 0.070), 0.80, 1.13)
	if exceptional:
		size = random.randf_range(1.145, 1.20)
	var mass := clampf(45.0 * pow(size, 3.0) * random.randf_range(0.93, 1.07), 30.0, 65.0)
	var mass_fraction := (mass - 30.0) / 35.0
	var progression := float(maxi(1, level) - 1)
	var base_health := 80.0 + minf(progression * 7.0, 100.0)
	var base_walk := 2.6 + minf(progression * 0.13, 1.5)
	var base_charge := 7.3 + minf(progression * 0.08, 1.2)
	# Bulk increases resilience and bite strength, with a small agility cost.
	# Independent condition draws allow overlapping speeds among different sizes.
	var resilience := lerpf(0.76, 1.35, mass_fraction) * random.randf_range(0.95, 1.05)
	var bite_strength := lerpf(0.78, 1.35, mass_fraction) * random.randf_range(0.94, 1.06)
	var walk_condition := random.randf_range(0.91, 1.10) * lerpf(1.02, 0.96, mass_fraction)
	var charge_condition := random.randf_range(0.94, 1.045) * lerpf(1.025, 0.96, mass_fraction)
	var coat: Dictionary = COATS[random.randi_range(0, COATS.size() - 1)]
	var tone := random.randf_range(0.92, 1.06)
	var dark: Color = coat.dark
	var light: Color = coat.light
	return {
		"profile_seed": actual_seed,
		"life_stage": "adult",
		"leader_at_birth": leader,
		"exceptional_size": exceptional,
		"sex": sex,
		"size_scale": size,
		"mass_kg": mass,
		"coat_name": str(coat.name),
		"coat_dark": Color(dark.r * tone, dark.g * tone, dark.b * tone),
		"coat_light": Color(light.r * tone, light.g * tone, light.b * tone),
		"coat_patch": random.randf_range(0.18, 0.72),
		"coat_phase": random.randf_range(0.0, TAU),
		"max_health": base_health * resilience,
		"walk_speed": base_walk * walk_condition,
		"charge_speed": base_charge * charge_condition,
		"bite_damage": 14.0 * bite_strength,
		"boldness": random.randf_range(0.22, 0.82),
		"hearing_multiplier": random.randf_range(0.82, 1.20),
		"sight_multiplier": random.randf_range(0.85, 1.16),
		"attack_interval": 5.4 + mass_fraction * 1.4 + random.randf_range(-0.4, 0.4),
		"voice_pitch": lerpf(1.16, 0.87, mass_fraction) + random.randf_range(-0.035, 0.035),
		"turn_rate": 7.0 * lerpf(1.12, 0.92, mass_fraction) * random.randf_range(0.91, 1.09),
		"experience": random.randf_range(0.35, 1.0)
	}
