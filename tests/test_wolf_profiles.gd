extends SceneTree

const Profiles = preload("res://scripts/wolf_profile.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var first: Dictionary = Profiles.generate(3, 481)
	check(first == Profiles.generate(3, 481), "The same level and seed reproduce the complete birth profile")
	check(first != Profiles.generate(3, 482), "Different seeds produce different individuals")
	var unseeded: Dictionary = Profiles.generate(2)
	check(unseeded == Profiles.generate(2, int(unseeded.profile_seed)), "A randomized profile reports a seed that exactly reproduces it")
	var another: Dictionary = Profiles.generate(2)
	check(unseeded.profile_seed != another.profile_seed, "Default generation creates fresh randomized individuals")
	var leader: Dictionary = Profiles.generate(3, 481, true)
	leader.leader_at_birth = false
	check(leader == first, "Leadership does not change physical traits, senses, temperament or coat")
	first.size_scale = 9.0
	check(float(Profiles.generate(3, 481).size_scale) < 1.21, "Profiles are independent values rather than a shared mutable template")
	seed(24601)
	var expected_first := randi()
	var expected_second := randi()
	seed(24601)
	var observed_first := randi()
	Profiles.generate(9, 110)
	Profiles.generate(9)
	check(observed_first == expected_first and randi() == expected_second, "Profile generation never consumes the global gameplay random stream")
	check(Profiles.generate(-100, 44) == Profiles.generate(1, 44), "Invalid low levels use level-one progression")
	var high: Dictionary = Profiles.generate(100, 44)
	check(high == Profiles.generate(10000, 44), "Level progression caps instead of growing without bound")
	var low: Dictionary = Profiles.generate(1, 44)
	check(high.max_health > low.max_health and high.walk_speed > low.walk_speed and high.charge_speed > low.charge_speed, "Higher levels preserve existing capped health and speed progression")
	for property in ["size_scale", "mass_kg", "sex", "coat_name", "coat_dark", "coat_light", "boldness", "hearing_multiplier", "sight_multiplier", "bite_damage", "experience"]:
		check(low[property] == high[property], "Level scaling leaves the birth trait %s unchanged" % property)

	var count := 5000
	var exceptional := 0
	var males := 0
	var females := 0
	var male_mass := 0.0
	var female_mass := 0.0
	var size_min := INF
	var size_max := -INF
	var coats: Dictionary = {}
	var coat_tones: Dictionary = {}
	var all_adult := true
	var dimensions_valid := true
	var stats_valid := true
	var senses_valid := true
	var colors_valid := true
	var larger_count := 0
	var smaller_count := 0
	var larger_health := 0.0
	var smaller_health := 0.0
	var larger_damage := 0.0
	var smaller_damage := 0.0
	var larger_speed := 0.0
	var smaller_speed := 0.0
	var larger_turn := 0.0
	var smaller_turn := 0.0
	var larger_experience := 0.0
	var smaller_experience := 0.0
	var experience_valid := true
	var fastest_large := 0.0
	var slowest_small := INF
	for sample in count:
		var profile: Dictionary = Profiles.generate(1, sample + 30000)
		all_adult = all_adult and profile.life_stage == "adult" and profile.sex in ["male", "female"]
		dimensions_valid = dimensions_valid and float(profile.size_scale) >= 0.80 and float(profile.size_scale) <= 1.20 and float(profile.mass_kg) >= 30.0 and float(profile.mass_kg) <= 65.0
		stats_valid = stats_valid and float(profile.max_health) >= 55.0 and float(profile.max_health) < 115.0 and float(profile.walk_speed) >= 2.2 and float(profile.walk_speed) <= 3.0 and float(profile.charge_speed) >= 6.5 and float(profile.charge_speed) <= 7.9 and float(profile.bite_damage) >= 10.0 and float(profile.bite_damage) <= 21.0 and float(profile.attack_interval) >= 5.0 and float(profile.attack_interval) <= 7.2 and float(profile.turn_rate) > 5.0
		senses_valid = senses_valid and float(profile.hearing_multiplier) >= 0.8 and float(profile.hearing_multiplier) <= 1.21 and float(profile.sight_multiplier) >= 0.8 and float(profile.sight_multiplier) <= 1.2 and float(profile.boldness) > 0.2 and float(profile.boldness) < 0.85 and float(profile.voice_pitch) >= 0.8 and float(profile.voice_pitch) <= 1.2
		experience_valid = experience_valid and float(profile.experience) >= 0.35 and float(profile.experience) <= 1.0
		for color_key in ["coat_dark", "coat_light"]:
			var color: Color = profile[color_key]
			colors_valid = colors_valid and color.a == 1.0 and color.r >= 0.0 and color.r <= 1.0 and color.g >= 0.0 and color.g <= 1.0 and color.b >= 0.0 and color.b <= 1.0
		colors_valid = colors_valid and (profile.coat_light as Color).get_luminance() > (profile.coat_dark as Color).get_luminance()
		size_min = minf(size_min, float(profile.size_scale))
		size_max = maxf(size_max, float(profile.size_scale))
		coats[profile.coat_name] = true
		coat_tones[(profile.coat_dark as Color).to_html()] = true
		if profile.exceptional_size:
			exceptional += 1
		if profile.sex == "male":
			males += 1
			male_mass += float(profile.mass_kg)
		else:
			females += 1
			female_mass += float(profile.mass_kg)
		if float(profile.mass_kg) >= 58.0:
			larger_count += 1
			larger_health += float(profile.max_health)
			larger_damage += float(profile.bite_damage)
			larger_speed += float(profile.charge_speed)
			larger_turn += float(profile.turn_rate)
			larger_experience += float(profile.experience)
			fastest_large = maxf(fastest_large, float(profile.charge_speed))
		elif float(profile.mass_kg) <= 37.0:
			smaller_count += 1
			smaller_health += float(profile.max_health)
			smaller_damage += float(profile.bite_damage)
			smaller_speed += float(profile.charge_speed)
			smaller_turn += float(profile.turn_rate)
			smaller_experience += float(profile.experience)
			slowest_small = minf(slowest_small, float(profile.charge_speed))
	check(all_adult, "Every generated wolf is an adult of either sex")
	check(dimensions_valid and size_max - size_min > 0.30, "Five thousand profiles visibly vary within restrained adult size and mass limits")
	check(exceptional > count * 0.02 and exceptional < count * 0.06, "Upper-size outliers are rare rather than most of the pack")
	check(males > count * 0.4 and females > count * 0.4 and male_mass / males > female_mass / females + 2.0, "Both adult sexes occur with overlapping but different average build")
	check(stats_valid, "All level-one profiles keep playable health, movement, bite and recovery bounds")
	check(senses_valid, "Hearing, sight, boldness and pitch vary within modest limits")
	check(coats.size() == 6 and coat_tones.size() > 100 and colors_valid, "Six natural coat palettes include individual tones with valid opaque colors")
	check(larger_count > 100 and smaller_count > 100, "The sample includes enough large and small adults to compare their behavior")
	check(larger_health / larger_count > smaller_health / smaller_count * 1.4 and larger_damage / larger_count > smaller_damage / smaller_count * 1.4, "Heavier adults are meaningfully tougher and bite harder")
	check(larger_speed / larger_count < smaller_speed / smaller_count and larger_turn / larger_count < smaller_turn / smaller_count, "Heavier adults trade some average speed and agility for strength")
	check(fastest_large > slowest_small, "Size does not dictate an individual's speed: large and small speed ranges overlap")
	check(experience_valid and absf(larger_experience / larger_count - smaller_experience / smaller_count) < 0.04, "Experience is bounded and independent of body size for leadership succession")
	var largest_leaders := 0
	for pack_seed in 128:
		var lead: Dictionary = Profiles.generate(1, pack_seed * 8, true)
		var largest := true
		for member in range(1, 8):
			if float(Profiles.generate(1, pack_seed * 8 + member).mass_kg) > float(lead.mass_kg):
				largest = false
		if largest:
			largest_leaders += 1
	check(largest_leaders < 40, "Pack leaders are usually not the largest members and never receive a hidden bulk bonus")
	print("PROFILE_SAMPLE adults=%d exceptional=%d male=%d female=%d sizes=%.3f..%.3f coats=%d largest_leaders=%d/128" % [count, exceptional, males, females, size_min, size_max, coats.size(), largest_leaders])
	for failure in failures:
		push_error(failure)
	print("%s: %d wolf profile checks; %d failed. No saves touched." % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
