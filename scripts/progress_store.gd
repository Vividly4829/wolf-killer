extends RefCounted
class_name IslandProgress
const WeaponCatalog = preload("res://scripts/weapon_catalog.gd")

var transient := false
const STARTING_CREDITS := 0
var money: int = STARTING_CREDITS
var owned: Array[int] = [0]
var stowed: Array[int] = []
var best_level: int = 1
var total_kills: int = 0
var save_path: String = "user://progress.cfg"
var last_save_ok: bool = true
var resume_level := 0
var resume_players := 1

func load_progress() -> void:
	var config := ConfigFile.new()
	var result := config.load(save_path)
	if result != OK:
		result = config.load(save_path + ".bak")
	if result != OK:
		return
	resume_level=clampi(int(config.get_value("progress","resume_level",0)),0,30)
	resume_players=clampi(int(config.get_value("progress","resume_players",1)),1,4)
	money = clampi(int(config.get_value("progress", "money", STARTING_CREDITS)), 0, 2000000000)
	best_level = maxi(1, int(config.get_value("progress", "best_level", 1)))
	total_kills = maxi(0, int(config.get_value("progress", "total_kills", 0)))
	owned = [0]
	var loaded: Variant = config.get_value("progress", "owned", [0])
	var starter_seen:=false
	if loaded is Array:
		for value in loaded:
			if not value is int:
				continue
			var index := int(value)
			if index==0 and not starter_seen:
				starter_seen=true; continue
			if index >= 0 and index < WeaponCatalog.WEAPONS.size() and (not owned.has(index) or WeaponCatalog.is_gun(index)):
				owned.append(index)
	stowed.clear()
	for value in config.get_value("progress","stowed",[]):
		if value is int and owned.has(value) and not stowed.has(value): stowed.append(value)
	if owned.all(func(index): return stowed.has(index)): stowed.erase(0)

func save_progress() -> bool:
	if transient: return true
	var config := ConfigFile.new()
	config.set_value("progress", "version", 3)
	config.set_value("progress","resume_level",resume_level)
	config.set_value("progress","resume_players",resume_players)
	config.set_value("progress", "money", money)
	config.set_value("progress", "starter_allowance", true)
	config.set_value("progress", "owned", owned)
	config.set_value("progress", "stowed", stowed)
	config.set_value("progress", "best_level", best_level)
	config.set_value("progress", "total_kills", total_kills)
	var temporary := save_path + ".tmp"
	if config.save(temporary) != OK:
		last_save_ok = false
		return false
	var absolute := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(absolute, absolute + ".bak")
	last_save_ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute) == OK
	return last_save_ok

func earn(amount: int) -> void:
	money = mini(2000000000, money + maxi(0, amount))
	total_kills += 1
	save_progress()

func buy(index: int, cost: int) -> bool:
	if index < 0 or index >= WeaponCatalog.WEAPONS.size() or (owned.has(index) and not WeaponCatalog.is_gun(index)) or cost < 0 or money < cost:
		return false
	money -= cost
	owned.append(index)
	save_progress()
	return true
