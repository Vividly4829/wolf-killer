extends SceneTree

const ProgressStore = preload("res://scripts/progress_store.gd")
const WeaponCatalog = preload("res://scripts/weapon_catalog.gd")

var checks := 0
var failures: Array[String] = []
var test_paths: Array[String] = []

func _initialize() -> void:
	var test_path := "user://test_progress_%s_%s.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	test_paths = [test_path, test_path + ".bak", test_path + ".tmp"]
	var store = ProgressStore.new()
	store.save_path = test_path
	store.load_progress()
	check(store.money == 350 and store.total_kills == 0, "Fresh players start with 350 credits and no kills")
	check(store.owned == [0], "Fresh players always have the starter musket")
	check(store.best_level == 1, "Fresh players start with a level-one record")

	store.money = 0 # Isolate reward arithmetic after checking the starter allowance.
	store.earn(25)
	store.earn(40)
	check(store.last_save_ok, "Multiple writes replace the save file successfully")
	var reloaded = ProgressStore.new()
	reloaded.save_path = test_path
	reloaded.load_progress()
	check(reloaded.money == 65 and reloaded.total_kills == 2, "Kill rewards and kill count survive a fresh store instance")
	check(not reloaded.buy(1, 100), "An unaffordable weapon cannot be purchased")
	check(reloaded.money == 65 and reloaded.owned == [0], "A rejected purchase preserves money and inventory")
	check(not reloaded.buy(WeaponCatalog.WEAPONS.size(), 1) and not reloaded.buy(-1, 1) and not reloaded.buy(0, 1) and not reloaded.buy(1, -1), "Unknown weapons, the free starter and negative prices are rejected")
	check(reloaded.buy(1, 40), "An affordable weapon can be purchased")
	check(reloaded.money == 25 and reloaded.owned == [0, 1], "Buying spends the price and grants the weapon")
	check(not reloaded.buy(1, 10) and reloaded.money == 25, "Buying an owned weapon cannot spend money again")
	store = ProgressStore.new()
	store.save_path = test_path
	store.load_progress()
	check(store.money == 25 and store.owned == [0, 1], "Purchased weapons and remaining money persist")

	store.best_level = 7
	check(store.save_progress(), "Best-level record saves successfully")
	var config := ConfigFile.new()
	check(config.load(test_path) == OK, "The persisted save is readable")
	check(config.get_value("progress", "best_level", 0) == 7, "Best level persists as a record")
	check(config.get_value("progress", "version", 0) == 2, "New writes use save version two")
	check(not config.has_section_key("progress", "level") and not config.has_section_key("progress", "current_level") and not config.has_section_key("progress", "wave"), "The save contains no resumable level checkpoint")

	# The previous successful save is the recovery point if the primary is damaged.
	store.earn(10)
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	corrupt.store_string("[broken section\nnot a valid config file")
	corrupt.close()
	var recovered = ProgressStore.new()
	recovered.save_path = test_path
	recovered.load_progress()
	check(recovered.money == 25 and recovered.owned == [0, 1] and recovered.best_level == 7, "A corrupt primary save recovers the previous valid backup")

	# Older or manually altered saves still retain the free musket and valid bounds.
	config = ConfigFile.new()
	config.set_value("progress", "money", -100)
	config.set_value("progress", "owned", [2, 2, 17, 17, 24, 500, -1, "3", 4.2, true])
	config.set_value("progress", "best_level", -5)
	config.set_value("progress", "total_kills", -7)
	config.save(test_path)
	recovered = ProgressStore.new()
	recovered.save_path = test_path
	recovered.load_progress()
	check(recovered.money == 350 and recovered.best_level == 1 and recovered.total_kills == 0, "Legacy negative wallet receives starter allowance; records are clamped")
	check(recovered.owned == [0, 2, 17, 24], "Loading restores the musket and ignores duplicate, unknown or non-integer weapon IDs")

	# Existing wallets and the three original IDs retain their meaning after upgrade.
	config = ConfigFile.new()
	config.set_value("progress", "version", 1)
	config.set_value("progress", "money", 777)
	config.set_value("progress", "owned", [0, 1, 2])
	config.set_value("progress", "best_level", 9)
	config.set_value("progress", "total_kills", 34)
	config.save(test_path)
	var legacy = ProgressStore.new()
	legacy.save_path = test_path
	legacy.load_progress()
	check(legacy.money == 777 and legacy.owned == [0, 1, 2] and legacy.best_level == 9 and legacy.total_kills == 34, "A version-one save keeps its wallet, original weapon IDs and records")
	legacy.save_progress()
	config.load(test_path)
	check(config.get_value("progress", "version", 0) == 2 and config.get_value("progress", "money", 0) == 777, "Saving legacy progress upgrades the format without charging money")
	check(WeaponCatalog.WEAPONS.size() == 27, "The ownership catalog contains the starter and twenty-six purchasable weapons")
	for index in range(3, WeaponCatalog.WEAPONS.size()):
		check(legacy.buy(index, 1), "Progress accepts new catalog weapon %d" % index)
	var expanded = ProgressStore.new()
	expanded.save_path = test_path
	expanded.load_progress()
	check(expanded.owned.size() == 27 and expanded.money == 753 and expanded.owned.has(26), "All twenty-seven owned weapons round-trip without losing the final ID")
	check(not expanded.buy(26, 1) and expanded.money == 753, "The newest weapon cannot be purchased twice")
	expanded.owned.clear()
	expanded.owned.append(0)
	expanded.save_progress()
	legacy.load_progress()
	check(legacy.owned == [0] and legacy.money == 753 and legacy.best_level == 9 and legacy.total_kills == 34, "A death-style inventory reset removes new weapons while retaining wallet and records")

	for path in test_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("PASS: %s progress-store checks; isolated test saves removed." % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %s of %s progress-store checks failed." % [failures.size(), checks])
		quit(1)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
