extends SceneTree
## Native armory layout/inspection smoke test. Add -- --capture for GPU screenshots.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)

func _run() -> void:
	var game := preload("res://scripts/main.gd").new()
	var test_path := "user://armory_preview_%s.cfg" % Time.get_ticks_usec()
	game.progress.save_path = test_path
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.progress.money = 2400
	game.set_mode("shop")
	await process_frame
	var hud: Control = game.hud
	var viewport_id: int = hud.preview_viewport.get_instance_id()
	var preview_world_id: int = hud.preview_viewport.find_world_3d().get_instance_id()
	var camera_id: int = hud.preview_camera.get_instance_id()
	var model_id: int = hud.preview_model.get_instance_id()
	var purchase_id: int = hud.overlay.get_node("PurchaseSelected").get_instance_id()
	var list_id: int = hud.shop_scroll.get_instance_id()
	_check(game.WEAPONS.size() == 24, "Armory must expose all twenty-four designs.")
	_check(hud.shop_scroll.get_child(0).get_child_count() == 24, "All designs must be present in the scrollable catalog.")
	var captures := [0, 3, 9, 12, 17]
	for index in game.WEAPONS.size():
		hud._select_shop_weapon(index)
		await process_frame
		_check(hud.preview_bounds.size.length() > .15, "Weapon inspection model must have visible geometry: %s" % index)
		_check(is_finite(hud.preview_camera.size) and hud.preview_camera.size > 0, "Weapon inspection camera must have finite framing.")
		_check(hud.preview_viewport.get_instance_id() == viewport_id and hud.preview_viewport.find_world_3d().get_instance_id() == preview_world_id and hud.preview_camera.get_instance_id() == camera_id and hud.preview_model.get_instance_id() == model_id, "Changing weapons must retain the preview scene and its rendering resources.")
		_check(hud.overlay.get_node("PurchaseSelected").get_instance_id() == purchase_id and hud.shop_scroll.get_instance_id() == list_id, "Changing weapons must retain shop controls and scrolling state.")
		var button: Button = hud.overlay.get_node("PurchaseSelected")
		_check(button.disabled == (index == game.current_weapon), "Affordable unowned designs must be purchasable.")
		if "--capture" in OS.get_cmdline_user_args() and index in captures:
			hud.shop_scroll.scroll_vertical = maxi(0, (index - 3) * 69)
			await create_timer(.18).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/armory_%02d.png" % (index + 1))
	for category in ["Sidearms", "Longarms", "Special"]:
		hud._filter_shop(category)
		await process_frame
		var expected := 0
		for data: Dictionary in game.WEAPONS:
			expected += int(hud._weapon_category(data) == category)
		_check(hud.shop_scroll.get_child(0).get_child_count() == expected, "Category filtering must keep the matching designs.")
		_check(hud.preview_viewport.get_instance_id() == viewport_id, "Filtering must not recreate the 3D preview.")
	hud._filter_shop("All")
	hud._select_shop_weapon(3)
	var same_parts_id: int = hud.preview_model.get_child(0).get_instance_id()
	hud._select_shop_weapon(3)
	_check(hud.preview_model.get_child(0).get_instance_id() == same_parts_id, "Selecting the same weapon must avoid rebuilding its parts.")
	var money_before: int = game.progress.money
	hud.overlay.get_node("PurchaseSelected").pressed.emit()
	_check(game.current_weapon == 3 and game.progress.owned.has(3) and game.progress.money == money_before - int(game.WEAPONS[3].price), "The persistent purchase button must buy its currently selected design.")
	_check(hud.overlay.get_node("PurchaseSelected").disabled and "KEY 2" in hud.shop_scroll.get_child(0).get_node("WeaponRow03").text, "Purchase must immediately refresh equipped status and the owned quick key.")
	game.reserve_ammo[3] -= 3
	var loaded_before: int = game.ammo[3]
	var refill_cost: int = game.ammo_refill_cost()
	money_before = game.progress.money
	hud.refresh_panel()
	hud.overlay.get_node("RefillAmmunition").pressed.emit()
	_check(game.reserve_ammo[3] == int(game.WEAPONS[3].reserve) and game.ammo[3] == loaded_before and game.progress.money == money_before - refill_cost and hud.overlay.get_node("RefillAmmunition").disabled, "Refill must update money and reserves without loading ammunition or replacing controls.")
	game.health = 55.0
	money_before = game.progress.money
	hud.refresh_panel()
	hud._shop_buttons.first_aid.pressed.emit()
	_check(game.health == 100.0 and game.progress.money == money_before - 40 and hud._shop_buttons.first_aid.disabled, "First aid must immediately refresh health, price availability and button state.")
	_check(hud.preview_model.get_child(0).get_instance_id() == same_parts_id and hud.overlay.get_node("PurchaseSelected").get_instance_id() == purchase_id, "Purchases and refills must retain selected preview geometry and controls.")
	game.progress.money = 0
	hud._select_shop_weapon(17)
	await process_frame
	_check(hud.overlay.get_node("PurchaseSelected").disabled, "An unaffordable design must disable purchase.")
	game.progress.owned.append(17)
	hud.refresh_panel()
	await process_frame
	_check(not hud.overlay.get_node("PurchaseSelected").disabled, "An owned design must be equippable without credits.")
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(75, 20)
	var before: Vector3 = hud.preview_pivot.rotation
	hud._inspect_input(drag)
	_check(hud.preview_pivot.rotation != before, "Dragging must rotate the selected inspection model.")
	game.progress.owned.assign([0, 3])
	game.current_weapon = 3
	hud._process(0.0)
	_check(hud.weapon_label.text.begins_with("[2]"), "A purchased crossbow must display its actual second owned quick slot, not design number four.")
	hud._select_shop_weapon(3)
	await process_frame
	_check("KEY 2" in hud.shop_scroll.get_child(0).get_node("WeaponRow03").text, "Owned store rows must show the actual numeric quick key.")
	if "--capture" in OS.get_cmdline_user_args():
		hud.shop_scroll.scroll_vertical = 0
		await create_timer(.18).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/armory_owned_04.png")
	game.progress.owned.assign(range(24))
	game.current_weapon = 17
	hud._process(0.0)
	_check(hud.weapon_label.text.begins_with("[Q/WHEEL]"), "Weapons beyond the ninth owned slot must display cycling controls.")
	game.set_mode("menu")
	await process_frame
	_check(not hud.preview_container.visible and hud.preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not hud.preview_model.is_processing(), "The retained preview must remain hidden and inactive outside the shop.")
	game.set_mode("shop")
	await process_frame
	_check(hud.preview_viewport.get_instance_id() == viewport_id and hud.preview_viewport.find_world_3d().get_instance_id() == preview_world_id and hud.preview_camera.get_instance_id() == camera_id and hud.preview_model.get_instance_id() == model_id, "Reopening the shop must reuse its preview scene and rendering resources.")
	_check(hud.preview_container.visible and hud.preview_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS and hud.shop_selection == game.current_weapon and hud.overlay.get_node("PurchaseSelected").disabled, "Reopening must restore the preview and select the currently equipped weapon.")
	game.queue_free()
	await process_frame
	await process_frame
	for path in [test_path, test_path + ".bak", test_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("ARMORY_STORE: 24 models, persistent preview/controls, reopen, transactions, filters, owned quick keys and drag; failures=%d" % failures)
	quit(failures)
