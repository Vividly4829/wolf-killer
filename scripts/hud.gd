extends Control

const INK := Color("17232d")
const PAPER := Color("eee9dc")
const MUTED := Color("a8b8c2")
const ACCENT := Color("d9aa6b")
const GOLD := Color("d7a462")
var game: Node
var weather_label: Label
var overlay: Control
var gameplay: Control
var level_label: Label
var status_label: Label
var round_money_label: Label
var compact_layout: Dictionary = {}
var money_label: Label
var health_label: Label
var ammo_label: Label
var ammo_detail_label: Label
var weapon_label: Label
var prompt_label: Label
var notice_label: Label
var save_label: Label
var subtitle_label: Label
var stealth_label: Label
var injury_label: Label
var struggle_label: Label
var wolf_focus_label: Label
var rest_shade: ColorRect
var body_font: SystemFont
var title_font: SystemFont
var stats_page := 0
var shop_selection: int = -1
var shop_filter: String = "All"
var shop_scroll: ScrollContainer
var shop_scroll_offset: int = 0
var preview_pivot: Node3D
var preview_camera: Camera3D
var preview_bounds := AABB()
var preview_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_model: Node3D
var _preview_index: int = -1
var _shop_list: VBoxContainer
var _shop_labels: Dictionary = {}
var _shop_buttons: Dictionary = {}
var _shop_rows: Dictionary = {}
var _shop_filter_buttons: Dictionary = {}
var _shop_stat_labels: Array[Label] = []
var _last_panel_mode: String = ""
const WeaponPreview = preload("res://scripts/weapon_visual.gd")

var weapon_controls: Label
var movement_controls: Label
var campaign_title: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Bahnschrift", "Arial"])
	title_font.font_weight = 700
	var theme_new := Theme.new()
	theme_new.default_font = body_font
	theme_new.default_font_size = 16
	theme = theme_new
	gameplay = Control.new()
	gameplay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gameplay)
	var condition:=preload("res://scripts/injury_avatar.gd").new(); condition.game=game
	condition.position=Vector2(18,423); gameplay.add_child(condition)
	weather_label = _label(gameplay, "", Vector2(34, 26), 12, PAPER)
	level_label = _label(gameplay, "", Vector2(34, 47), 42)
	status_label = _label(gameplay, "", Vector2(176, 56), 16)
	status_label.position=Vector2(110,52)
	status_label.size=Vector2(202,94)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	campaign_title=_label(gameplay,"",Vector2(34,113),14,PAPER)
	campaign_title.size.x=276; campaign_title.clip_text=true
	money_label = _label(gameplay, "", Vector2(34, 145), 16, ACCENT)
	round_money_label = _label(gameplay, "", Vector2(34, 169), 13, ACCENT)
	health_label = _label(gameplay, "", Vector2(34, 606), 30)
	_label(gameplay, "HEALTH", Vector2(106, 620), 12, MUTED)
	_label(gameplay, "STAMINA", Vector2(34, 675), 10, MUTED)
	weapon_label = _label(gameplay, "", Vector2(973, 588), 17, ACCENT)
	weapon_label.size.x = 270
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label = _label(gameplay, "", Vector2(970, 610), 38)
	ammo_label.size.x = 274
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_detail_label = _label(gameplay, "LOADED  /  RESERVE", Vector2(970, 660), 10, MUTED)
	ammo_detail_label.size.x = 274
	ammo_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_controls = _label(gameplay, "1–9 QUICK SLOTS  ·  Q / WHEEL CYCLE", Vector2(968, 680), 11, MUTED)
	prompt_label = _label(gameplay, "", Vector2(320, 626), 16, PAPER)
	prompt_label.size.x = 640
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	movement_controls = _label(gameplay, "WASD Move   CTRL Sneak   SHIFT Sprint   F Quick throw   R Reload   B Bandage   E Store", Vector2(327, 684), 11, MUTED)
	notice_label = _label(gameplay, "", Vector2(310, 132), 18, ACCENT)
	notice_label.size.x = 660
	notice_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_label = _label(gameplay, "", Vector2(34, 143), 12, GOLD)
	subtitle_label = _label(gameplay, "", Vector2(310, 553), 19, PAPER)
	subtitle_label.size.x = 660
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stealth_label = _label(gameplay, "", Vector2(34, 204), 12, PAPER)
	injury_label = _label(gameplay, "", Vector2(34, 536), 12, Color("ee9b91"))
	struggle_label = _label(gameplay, "", Vector2(330, 36), 20, PAPER)
	struggle_label.size.x = 620
	struggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wolf_focus_label = _label(gameplay, "", Vector2(330, 394), 13, PAPER)
	wolf_focus_label.size.x = 620
	wolf_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	refresh_panel()
	for child in gameplay.get_children():
		if child is Control: compact_layout[child] = {"position":child.position,"scale":child.scale}

func hud_factor() -> float:
	return 1.0 if game.hud_detail_left>0.0 else .72

func hud_anchor(point: Vector2) -> Vector2:
	return Vector2(20 if point.x<310 else 1257 if point.x>900 else 640,18 if point.y<300 else 360 if point.y<450 and point.x>=310 else 704)

func draw_group(anchor: Vector2) -> void:
	var factor := hud_factor()
	draw_set_transform(anchor*(1.0-factor),0,Vector2.ONE*factor)

func _label(parent: Node, value: String, point: Vector2, font_size: int, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.035, 0.055, 0.07, 0.85))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_override("font", title_font if font_size >= 28 else body_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _block(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var block := ColorRect.new()
	block.position = rect.position
	block.size = rect.size
	block.color = color
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(block)
	return block

func _button(parent: Node, value: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK if primary else PAPER)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("697977"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = ACCENT if primary or state == "hover" or state == "pressed" else Color(0.065, 0.09, 0.13, 0.94)
		if state == "disabled":
			style.bg_color = Color("1e3032")
		style.border_color = ACCENT if state == "focus" else Color("63727b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func refresh_input_hints() -> void:
	var pad: bool=game.controller_device>=0
	weapon_controls.text="LB / RB  CYCLE WEAPONS" if pad else "1–9 QUICK SLOTS  ·  Q / WHEEL CYCLE"
	movement_controls.text="LS Move · RS Look · LT Aim · RT Fire · Y Interact · X Reload" if pad else "WASD Move   CTRL Sneak   SHIFT Sprint   F Quick throw   R Reload   B Bandage   E Interact"
	if game.mode=="shop" and _shop_labels.has("controls"):
		_shop_labels.controls.text=shop_controls()
	if game.mode=="menu" and pad:
		for child in overlay.get_children():
			if child is Button and not child.disabled:
				child.grab_focus(); break

func shop_controls() -> String:
	return "D-pad ↑/↓ Select · A Buy/equip · X Ammo · D-pad → First aid · B/Y Leave\nLB/RB Category · RS Inspect · R3 Buy another · L3 Unequip/re-equip" if game.controller_device>=0 else "Ammo refills carried reserves. First aid heals health and wounds."

func step_shop_selection(direction: int) -> void:
	var choices: Array=_shop_rows.keys()
	if choices.is_empty(): return
	var slot: int=choices.find(shop_selection)
	_select_shop_weapon(choices[posmod(slot+direction,choices.size())])
	shop_scroll.ensure_control_visible.call_deferred(_shop_rows[shop_selection])

func step_shop_filter(direction: int) -> void:
	var categories := ["All","Sidearms","Longarms","Special"]
	_filter_shop(categories[posmod(categories.find(shop_filter)+direction,categories.size())])
	if not _shop_rows.has(shop_selection) and not _shop_rows.is_empty(): _select_shop_weapon(_shop_rows.keys()[0])
	if _shop_rows.has(shop_selection): shop_scroll.ensure_control_visible.call_deferred(_shop_rows[shop_selection])

func refresh_panel() -> void:
	if not is_instance_valid(overlay):
		return
	if game.mode == "shop" and _last_panel_mode == "shop" and is_instance_valid(_shop_list) and _shop_list.is_inside_tree():
		_refresh_shop_details()
		return
	if game.mode == "shop" and _last_panel_mode != "shop":
		shop_selection = game.current_weapon
		shop_filter = "All"
		shop_scroll_offset = 0
	_last_panel_mode = game.mode
	# Retain the preview's rendering resources across closing and reopening.
	if is_instance_valid(preview_container):
		preview_container.hide()
		preview_container.process_mode = Node.PROCESS_MODE_DISABLED
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if preview_container.get_parent() == overlay:
			preview_container.reparent(self, false)
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	_shop_labels.clear()
	_shop_buttons.clear()
	_shop_rows.clear()
	_shop_filter_buttons.clear()
	_shop_stat_labels.clear()
	gameplay.visible = game.mode == "playing"
	overlay.visible = game.mode != "playing"
	if game.mode == "menu":
		_menu()
	elif game.mode == "weapon_stats":
		_weapon_stats()
	elif game.mode in ["connecting","connection_error"]:
		_connection()
	elif game.mode == "shop":
		_shop()
	elif game.mode == "paused":
		_pause()
	elif game.mode == "waiting":
		_block(overlay,Rect2(320,220,640,260),Color(.03,.04,.06,.85))
		_label(overlay,"WAITING FOR YOUR TEAM",Vector2(370,250),30)
		_label(overlay,"A surviving hunter can finish the objective.\nYou will respawn next round in your own building.\nMoney is kept; lost weapons can be replaced.",Vector2(370,310),18,PAPER)
		_button(overlay,"LEAVE SESSION",Rect2(460,410,360,45),game.return_to_menu)
	elif game.mode == "victory":
		_victory()
	elif game.mode == "dead":
		_defeat()
	elif game.mode == "resting":
		_rest()
	refresh_input_hints()

func _menu() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.025, 0.065, 0.075, 0.98))
	gradient.set_color(1, Color(0.025, 0.065, 0.075, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1024
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.size = Vector2(1040, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	_block(overlay, Rect2(48, 54, 32, 3), PAPER)
	_label(overlay, "HESTAVIKHOLMEN  /  THE AUTUMN HUNT", Vector2(96, 44), 12, PAPER)
	_label(overlay, "WOLF", Vector2(43, 104), 94)
	_label(overlay, "ISLAND", Vector2(43, 191), 94)
	_label(overlay, "ONE SHOT. THEN THE LONG RELOAD.", Vector2(50, 311), 13, ACCENT)
	_label(overlay, "The woods are empty. The pack is hungry.\nLeave the cabin to begin the hunt.\nOne shot. Stand your ground to reload.", Vector2(50, 354), 17, PAPER)
	_block(overlay,Rect2(470,208,430,220),Color(.035,.075,.09,.94))
	_label(overlay,"NEW EXPEDITION",Vector2(490,222),20,ACCENT)
	_label(overlay,"STARTING LEVEL",Vector2(490,263),12,MUTED)
	_label(overlay,"STARTING CREDITS",Vector2(664,263),12,MUTED)
	var start_level:=SpinBox.new()
	start_level.name="StartingLevel"; start_level.min_value=1; start_level.max_value=30; start_level.step=1
	start_level.value=game.menu_start_level; start_level.position=Vector2(490,286); start_level.size=Vector2(148,42)
	start_level.add_theme_font_size_override("font_size",20); overlay.add_child(start_level)
	start_level.value_changed.connect(func(value): game.menu_start_level=int(value))
	start_level.get_line_edit().text_changed.connect(func(_text): start_level.set_meta("typed",true))
	var start_money:=SpinBox.new()
	start_money.name="StartingMoney"; start_money.min_value=0; start_money.max_value=2000000000; start_money.step=1
	start_money.value=game.progress.money if game.menu_start_money<0 else game.menu_start_money
	start_money.position=Vector2(664,286); start_money.size=Vector2(216,42)
	start_money.add_theme_font_size_override("font_size",20); overlay.add_child(start_money)
	start_money.value_changed.connect(func(value): game.menu_start_money=int(value))
	start_money.get_line_edit().text_changed.connect(func(_text): start_money.set_meta("typed",true))
	_label(overlay,"Type a value or use the arrows.\nCustom credits apply to both split-screen players.\nDeath restarts at level 1; money stays.\nJoining online uses the host's level.",Vector2(490,340),13,MUTED)
	_button(overlay, "WAKE IN THE CABIN    →", Rect2(50, 453, 390, 55), game.start_from_menu, true)
	_button(overlay, "FREE PLAY / ALL WEAPONS", Rect2(50, 518, 390, 48), game.start_free_play)
	_button(overlay, "WEAPON STATS & PRICES", Rect2(935, 453, 300, 48), open_weapon_stats)
	_button(overlay, "QUIT", Rect2(800, 511, 100, 42), game.quit_game)
	_button(overlay,"HOST 3-PLAYER CO-OP",Rect2(470,453,295,48),game.coop.host_session)
	var address := LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "Host IP address"
	address.position = Vector2(470,511)
	address.size = Vector2(185,42)
	overlay.add_child(address)
	_button(overlay,"JOIN",Rect2(665,511,100,42),func(): game.coop.join_session(address.text))
	_button(overlay,"LOCAL SPLIT SCREEN / 2 PLAYERS",Rect2(470,612,390,40),func(): game.start_split())
	_label(overlay,"P1 keyboard + mouse · P2 Xbox controller",Vector2(470,661),13,MUTED)
	_label(overlay,"Up to 3 hunters · friendly fire\nInternet host: forward UDP 27896\n"+game.coop.status,Vector2(470,565),13,MUTED)
	_label(overlay, "BANKED  %d CR     /     BEST  LEVEL %02d" % [game.progress.money, game.progress.best_level], Vector2(50, 596), 14, ACCENT)
	_label(overlay, "Death costs your weapons. Your money stays.\nMouse to aim  ·  WASD to move  ·  Left click to shoot", Vector2(50, 630), 13, MUTED)
	_block(overlay, Rect2(966, 595, 265, 83), Color(0.04, 0.10, 0.12, 0.86))
	_label(overlay, "SHELTER BEFORE THE STORM", Vector2(985, 614), 12, ACCENT)
	_label(overlay, "Bremnesvegen 96  /  Autumn survival", Vector2(985, 639), 12, PAPER)

func _shop() -> void:
	_block(overlay, Rect2(0, 0, 1280, 720), Color("101b24"))
	_label(overlay, "HESTAVIK SUPPLY CO.  /  ARMS BEFORE 1890", Vector2(46, 27), 12, GOLD)
	_label(overlay, "THE ARMORY", Vector2(43, 46), 43)
	_label(overlay, "Choose carefully. Death costs your weapons.", Vector2(47, 101), 14, MUTED)
	var wallet := _label(overlay, "", Vector2(898, 46), 30, ACCENT)
	wallet.size.x = 335
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shop_labels.wallet = wallet
	var inventory := _label(overlay, "", Vector2(905, 91), 12, MUTED)
	inventory.size.x = 329
	inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shop_labels.inventory = inventory
	for i in 4:
		var category: String = ["All", "Sidearms", "Longarms", "Special"][i]
		var filter_button := _button(overlay, category.to_upper(), Rect2(46 + i * 81, 143, 76, 31), _filter_shop.bind(category), shop_filter == category)
		filter_button.add_theme_font_size_override("font_size", 11)
		_shop_filter_buttons[category] = filter_button
	shop_scroll = ScrollContainer.new()
	shop_scroll.name = "ArmoryScroll"
	shop_scroll.position = Vector2(46, 186)
	shop_scroll.size = Vector2(319, 430)
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(shop_scroll)
	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.add_theme_constant_override("separation", 5)
	shop_scroll.add_child(_shop_list)
	_shop_labels.count = _label(overlay, "", Vector2(47, 626), 12, MUTED)
	_shop_labels.header = _label(overlay, "", Vector2(407, 135), 12, ACCENT)
	var title := _label(overlay, "", Vector2(405, 155), 27)
	title.size.x = 826
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_shop_labels.title = title
	_create_weapon_preview(shop_selection)
	_label(overlay, "DRAG TO INSPECT  /  ORIGINAL STYLIZED MODEL", Vector2(422, 407), 10, MUTED)
	var description := _label(overlay, "", Vector2(410, 441), 15, PAPER)
	description.size = Vector2(813, 46)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_labels.description = description
	var stat_names := ["CAPACITY", "DAMAGE", "RELOAD", "CARRIED AMMO"]
	for i in 4:
		_label(overlay, stat_names[i], Vector2(410 + i * 203, 501), 10, MUTED)
		_shop_stat_labels.append(_label(overlay, "", Vector2(410 + i * 203, 521), 17, PAPER))
	_shop_labels.ammo_note = _label(overlay, "", Vector2(410, 550), 10, MUTED)
	var purchase := _button(overlay, "", Rect2(409, 573, 362, 47), _purchase_selected_weapon, true)
	purchase.name = "PurchaseSelected"
	_shop_buttons.purchase = purchase
	var another:=_button(overlay,"",Rect2(409,659,362,36),_purchase_another)
	another.name="PurchaseAnother"; another.add_theme_font_size_override("font_size",14)
	_shop_buttons.another=another
	var stow:=_button(overlay,"",Rect2(787,659,173,36),func(): game.toggle_store_weapon(shop_selection))
	stow.add_theme_font_size_override("font_size",12); _shop_buttons.stow=stow
	stow.tooltip_text="Store or carry every copy of this design. Ownership and loaded ammunition are preserved."
	var refill := _button(overlay, "", Rect2(787, 573, 215, 47), _purchase_ammo)
	refill.name = "RefillAmmunition"
	refill.add_theme_font_size_override("font_size", 14)
	_shop_buttons.refill = refill
	var first_aid := _button(overlay, "FIRST AID  /  40 CR", Rect2(1018, 573, 215, 47), game.purchase_health)
	first_aid.add_theme_font_size_override("font_size", 14)
	_shop_buttons.first_aid = first_aid
	_shop_labels.controls = _label(overlay, shop_controls(), Vector2(410, 627), 12, MUTED)
	_label(overlay, "25 credits per wolf  ·  Purchases saved immediately\nTime stands still while you browse.", Vector2(47, 661), 12, MUTED)
	_button(overlay, "RETURN TO ISLAND  →", Rect2(972, 660, 261, 40), game.close_shop, true).add_theme_font_size_override("font_size", 14)
	_rebuild_shop_rows()
	_refresh_shop_details()

func _rebuild_shop_rows() -> void:
	for row in _shop_list.get_children():
		_shop_list.remove_child(row)
		row.queue_free()
	_shop_rows.clear()
	for index in game.WEAPONS.size():
		if shop_filter != "All" and _weapon_category(game.WEAPONS[index]) != shop_filter:
			continue
		var row := _button(_shop_list, "", Rect2(0, 0, 298, 64), _select_shop_weapon.bind(index), index == shop_selection)
		row.name = "WeaponRow%02d" % index
		row.custom_minimum_size = Vector2(0, 64)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_constant_override("outline_size", 0)
		_shop_rows[index] = row
	shop_scroll.set_deferred("scroll_vertical", shop_scroll_offset)

func _set_shop_emphasis(button: Button, primary: bool) -> void:
	if button.get_meta("shop_primary", not primary) == primary:
		return
	button.set_meta("shop_primary", primary)
	button.add_theme_color_override("font_color", INK if primary else PAPER)
	# Every button owns these style resources; changing state needs no new ones.
	for state in ["normal", "focus"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		style.bg_color = ACCENT if primary else Color(0.065, 0.09, 0.13, 0.94)

func _refresh_shop_details() -> void:
	shop_selection = clampi(shop_selection, 0, game.WEAPONS.size() - 1)
	var data: Dictionary = game.WeaponCatalog.weapon(shop_selection)
	_shop_labels.wallet.text = "%d  CREDITS" % game.progress.money
	_shop_labels.inventory.text = "%d OWNED  /  %d DESIGNS" % [game.progress.owned.size(), game.WEAPONS.size()]
	_shop_labels.count.text = "%d designs  ·  Scroll to browse" % _shop_rows.size()
	for category: String in _shop_filter_buttons:
		_set_shop_emphasis(_shop_filter_buttons[category], category == shop_filter)
	for index: int in _shop_rows:
		var item: Dictionary = game.WEAPONS[index]
		var owned: bool = game.progress.owned.has(index)
		var ownership := "STORED" if game.progress.stowed.has(index) else ("EQUIPPED" if index == game.current_weapon else ("OWNED" if owned else "%d CR" % int(item.price)))
		if owned:
			ownership+=" ×%d"%game.progress.owned.count(index)
			var slot: int = game.progress.owned.find(index)
			if not game.progress.stowed.has(index): ownership += " · LB/RB" if game.controller_device>=0 else (" · KEY %d" % (slot + 1) if slot < 9 else " · Q/WHEEL")
		var row: Button = _shop_rows[index]
		row.text = "%02d  %s\n%s  ·  %s" % [index + 1, item.name, item.get("year", ""), ownership]
		_set_shop_emphasis(row, index == shop_selection)
	var selected_header := "%s  /  %s" % [data.get("year", ""), str(data.get("tag", _weapon_category(data))).to_upper()]
	if game.progress.owned.has(shop_selection) and not game.progress.stowed.has(shop_selection):
		var slot: int = game.progress.owned.find(shop_selection)
		selected_header += "  /  LB/RB TO SWITCH" if game.controller_device>=0 else ("  /  QUICK KEY %d" % (slot + 1) if slot < 9 else "  /  CYCLE WITH Q OR WHEEL")
	_shop_labels.header.text = selected_header
	_shop_labels.title.text = str(data.name)
	_shop_labels.description.text = str(data.description).replace("\n", " ")
	var damage_text := ("%.1f" % float(data.damage)).trim_suffix(".0")
	if int(data.get("pellets", 1)) > 1:
		damage_text = "%d × %s" % [int(data.pellets), damage_text]
	var carried := "%d + %d reserve" % [game.ammo[shop_selection], _reserve_count(shop_selection)]
	if not game.progress.owned.has(shop_selection):
		carried = "%d reserve on purchase" % int(data.get("reserve", data.get("reserve_max", 0)))
	var stat_values := [str(data.magazine), damage_text, "%.1f seconds" % float(data.reload), carried]
	if shop_selection == 9:
		stat_values[0] = "9 + 1 shot barrel"
	for i in 4:
		_shop_stat_labels[i].text = stat_values[i]
	var ammo_note := "%s  ·  %d CR PER RESERVE ROUND" % [data.get("ammo_type", "AMMUNITION"), int(data.get("ammo_cost", 3))]
	if shop_selection == 9:
		ammo_note += "  /  SHOT BARREL: %d + %d RESERVE  ·  %.1fs RELOAD  ·  4 CR" % [int(game.lemat_shot_ammo), int(game.lemat_shot_reserve),float(game.WeaponCatalog.secondary_weapon().reload)]
	_shop_labels.ammo_note.text = ammo_note
	var owned: bool = game.progress.owned.has(shop_selection)
	_shop_buttons.purchase.text = "EQUIPPED" if game.current_weapon == shop_selection else ("EQUIP OWNED WEAPON" if owned else "BUY  /  %d CREDITS" % int(data.price))
	_shop_buttons.purchase.disabled = game.current_weapon == shop_selection or (not owned and game.progress.money < int(data.price))
	_shop_buttons.stow.visible=owned
	_shop_buttons.stow.text=("RE-EQUIP" if game.progress.stowed.has(shop_selection) else "UNEQUIP")+(" / L3" if game.controller_device>=0 else "")
	_shop_buttons.another.visible=owned and game.WeaponCatalog.is_gun(shop_selection)
	_shop_buttons.another.text="BUY ANOTHER / %d CR%s"%[int(data.price)," / R3" if game.controller_device>=0 else ""]
	_shop_buttons.another.disabled=game.progress.money<int(data.price)
	var refill_cost: int = game.ammo_refill_cost() if game.has_method("ammo_refill_cost") else 0
	_shop_buttons.refill.text = "AMMO  /  %d CR" % refill_cost
	_shop_buttons.refill.disabled = game.progress.money < refill_cost or refill_cost <= 0
	_shop_buttons.first_aid.text = "FIRST AID / AFTER MISSION" if game.campaign.running else "FIRST AID / 40 CR"
	_shop_buttons.first_aid.disabled = game.campaign.running or (game.health >= game.maximum_health() and game.player.get_injury_summary().is_empty()) or game.progress.money < 40
	_set_preview_weapon(shop_selection)

func _weapon_category(data: Dictionary) -> String:
	var category := str(data.get("family", data.get("category", ""))).to_lower()
	if category in ["sidearm", "sidearms", "pistol", "revolver"]:
		return "Sidearms"
	if category in ["special", "crossbow", "scattergun", "shotgun"]:
		return "Special"
	return "Longarms"

func _filter_shop(category: String) -> void:
	if shop_filter == category:
		return
	shop_filter = category
	shop_scroll_offset = 0
	_rebuild_shop_rows()
	_refresh_shop_details()

func _select_shop_weapon(index: int) -> void:
	shop_scroll_offset = shop_scroll.scroll_vertical if is_instance_valid(shop_scroll) else 0
	shop_selection = index
	_refresh_shop_details()

func commit_start_options() -> void:
	if game.mode!="menu": return
	var money=overlay.get_node_or_null("StartingMoney")
	var level=overlay.get_node_or_null("StartingLevel")
	if money:
		if money.get_meta("typed",false): money.apply()
		if game.menu_start_money<0: game.menu_start_money=int(money.value)
	if level:
		if level.get_meta("typed",false): level.apply()

func _purchase_selected_weapon() -> void:
	game.purchase_weapon(shop_selection)
func _purchase_another() -> void:
	game.purchase_weapon(shop_selection,true)
func _reserve_count(index: int) -> int:
	var reserves: Variant = game.get("reserve_ammo")
	return int(reserves[index]) if reserves is Array and index < reserves.size() else 0

func _needs_ammo() -> bool:
	for index in game.progress.owned:
		var data: Dictionary = game.WEAPONS[index]
		if _reserve_count(index) < int(data.get("reserve", data.get("reserve_max", 0))):
			return true
	return false

func _purchase_ammo() -> void:
	if game.has_method("purchase_ammo"):
		game.purchase_ammo()

func _create_weapon_preview(index: int) -> void:
	if not is_instance_valid(preview_container):
		_build_preview_scene()
	elif preview_container.get_parent() != overlay:
		preview_container.reparent(overlay, false)
	preview_container.show()
	preview_container.process_mode = Node.PROCESS_MODE_INHERIT
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_set_preview_weapon(index)

func _build_preview_scene() -> void:
	preview_container = SubViewportContainer.new()
	preview_container.name = "WeaponInspection"
	preview_container.position = Vector2(407, 194)
	preview_container.size = Vector2(826, 235)
	preview_container.stretch = true
	preview_container.mouse_default_cursor_shape = Control.CURSOR_DRAG
	preview_container.gui_input.connect(_inspect_input)
	overlay.add_child(preview_container)
	preview_viewport = SubViewport.new()
	preview_viewport.name = "InspectionViewport"
	preview_viewport.size = Vector2i(826, 235)
	preview_viewport.own_world_3d = true
	preview_viewport.msaa_3d = Viewport.MSAA_4X
	preview_container.add_child(preview_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1c2d38")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bfcdd1")
	environment.environment.ambient_light_energy = .75
	preview_viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -28, 0)
	light.light_color = Color("ffe3b9")
	light.light_energy = 1.6
	preview_viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(25, 140, 0)
	fill.light_color = Color("9bc7e3")
	fill.light_energy = .75
	preview_viewport.add_child(fill)
	preview_pivot = Node3D.new()
	preview_viewport.add_child(preview_pivot)
	preview_model = WeaponPreview.new()
	preview_model.call("set_inspection_mode", true)
	preview_pivot.add_child(preview_model)
	# Inspection is static; only the UI changes its transform during dragging.
	preview_model.set_process(false)
	preview_camera = Camera3D.new()
	preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	preview_viewport.add_child(preview_camera)
	preview_camera.current = true

func _set_preview_weapon(index: int) -> void:
	if _preview_index == index:
		return
	preview_model.position = Vector3.ZERO
	preview_model.call("build", index)
	preview_bounds = preview_model.call("get_model_bounds")
	preview_model.position = -preview_bounds.get_center()
	preview_pivot.rotation_degrees = Vector3(-38, 35, -8) if index == 3 else Vector3(-8, 74, -3)
	preview_camera.position = Vector3(0, 0, maxf(3.0, preview_bounds.size.length() * 2.0))
	_fit_preview_camera()
	_preview_index = index
func _fit_preview_camera() -> void:
	var rotated: AABB = preview_pivot.transform * preview_bounds
	preview_camera.size = maxf(.20, maxf(rotated.size.y * 1.18, rotated.size.x / (826.0 / 235.0) * 1.16))

func _inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and is_instance_valid(preview_pivot):
		preview_pivot.rotation.y += event.relative.x * .009
		preview_pivot.rotation.x = clampf(preview_pivot.rotation.x + event.relative.y * .008, -.75, .75)
		_fit_preview_camera()

func _pause() -> void:
	_block(overlay, Rect2(0, 0, 1280, 720), Color(0.025, 0.065, 0.075, 0.82))
	_label(overlay, "TAKE A BREATH", Vector2(442, 171), 42)
	_label(overlay, "Your teammate keeps playing." if is_instance_valid(game.split_session) else ("Online world keeps running." if game.coop.active else "The island can wait."), Vector2(470, 237), 17, MUTED)
	_button(overlay, "RESUME", Rect2(450, 302, 380, 54), game.set_mode.bind("playing"), true)
	_button(overlay, "MAIN MENU", Rect2(450, 376, 380, 48), game.return_to_menu)
	_button(overlay, "SAVE & QUIT", Rect2(450, 441, 380, 48), game.quit_game)
	_label(overlay, "LS move · RS look · LT aim · RT fire/fight · X reload\nY pick up / interact / store · LB/RB switch weapon\nA jump · B sneak · L3 sprint · D-pad up bandage\nD-pad left fire mode · D-pad down X-ray\nMenu / A / B resume · Y main menu" if game.controller_device>=0 else "WASD move · Mouse aim · Click fire · R reload\nCtrl sneak · B bandage · E interact · V fire mode\n1–9 quick slots · Q / wheel cycle weapons\nHold F or left mouse to fight off a wolf\nShift sprint · Space jump · F11 fullscreen", Vector2(414, 534), 15, MUTED)

func _rest() -> void:
	rest_shade = _block(overlay, Rect2(0, 0, 1280, 720), Color(0.015, 0.022, 0.04, 0.88))
	_label(overlay, "THE NIGHT GROWS QUIET", Vector2(356, 213), 40)
	_label(overlay, "You return to bed. Your wounds heal while you rest.", Vector2(403, 277), 18, PAPER)
	_label(overlay, "LEVEL %02d CLEARED" % (game.level - 1), Vector2(504, 347), 25, ACCENT)
	_label(overlay, "Health and stamina restored  ·  Ammunition and bandages replenished\nYour money and surviving weapons are kept.", Vector2(375, 401), 16, PAPER)
	_label(overlay, "Wake in the cabin. Leave when you are ready.", Vector2(448, 493), 16, MUTED)

func _defeat() -> void:
	_block(overlay, Rect2(0, 0, 1280, 720), Color(0.055, 0.055, 0.065, 0.9))
	_label(overlay, "THE PACK CAUGHT UP", Vector2(392, 161), 42)
	_label(overlay, "You reached level %02d and defeated %d wolves." % [game.death_level, game.run_kills], Vector2(442, 240), 17, MUTED)
	_label(overlay, "%d  CREDITS KEPT" % game.progress.money, Vector2(440, 309), 35, ACCENT)
	_label(overlay, "Purchased weapons lost. Money kept.\nRestart at level 1 with the musket.", Vector2(488, 367), 16, PAPER)
	_button(overlay, "TRY AGAIN  /  LEVEL 01", Rect2(450, 453, 380, 56), game.start_run, true)
	_button(overlay, "MAIN MENU", Rect2(450, 530, 380, 45), game.return_to_menu)

func _process(_delta: float) -> void:
	for child in compact_layout:
		child.position = compact_layout[child].position
		child.scale = compact_layout[child].scale
	weather_label.text = "HESTAVIKHOLMEN / " + game.world.weather.description()
	weather_label.add_theme_font_size_override("font_size",10)
	campaign_title.text="SHOOTING RANGE" if game.free_play else str((game.campaign.job if game.campaign.running else game.campaign.preview()).get("title",""))
	var review_open: bool = is_instance_valid(game.shot_review) and game.shot_review.remaining > 0
	if review_open:
		for item in [weapon_label,ammo_label,ammo_detail_label]: item.position.y -= 328
	if not is_instance_valid(gameplay):
		return
	if game.mode == "resting" and is_instance_valid(rest_shade):
		rest_shade.color.a = clampf(game.rest_left / 3.5, 0.12, 0.88)
	level_label.text = "%02d" % game.level
	if game.is_player_safe():
		if game.intermission:
			status_label.text = "SHELTER\nPreparation paused" if game.wave_countdown > 0 else "SHELTER\nLeave to begin"
		else:
			status_label.text = "SHELTER\n%d wolves outside" % (game.wolves.size() + game.pending_spawns)
	else:
		status_label.text = ("LEVEL  /  PREPARE\nNext hunt in %ds" % ceili(game.wave_countdown)) if game.intermission else ("HUNT %s\n%d / %d remaining" % [game.objective_species().to_upper(),maxi(0,game.wave_total-game.wave_kills),game.wave_total])
	if game.campaign and not game.free_play:
		status_label.text = ("LEAVE TO BEGIN" if game.intermission else "MISSION")+"\n"+game.campaign.objective_text()
		status_label.add_theme_font_size_override("font_size",12)
	if game.free_play:
		level_label.text = "FP"
		status_label.text = "FREE PLAY\nNon-hostile animals"
	money_label.text = "PRACTICE / NOT SAVED" if game.free_play else "%d  CR  /  BANKED" % game.progress.money
	round_money_label.text = game.coop.earnings_text()
	health_label.text = "%03d" % ceili(game.health)
	var owned_slot: int = game.current_slot
	var shortcut := "LB/RB" if game.controller_device>=0 else (str(owned_slot + 1) if owned_slot >= 0 and owned_slot < 9 else "Q/WHEEL")
	weapon_label.text = "[%s]  %s" % [shortcut, game.weapon_display_name()]
	weapon_label.add_theme_font_size_override("font_size", 15)
	if game.reload_left > 0:
		ammo_label.text = "%s  %.1fs" % [game.player.get_reload_stage(), game.reload_left]
	else:
		var loaded: int = game.current_ammo() if game.has_method("current_ammo") else game.ammo[game.current_weapon]
		var reserve: int = game.current_reserve() if game.has_method("current_reserve") else _reserve_count(game.current_weapon)
		ammo_label.text = "%02d  /  %02d" % [loaded, reserve]
	ammo_label.add_theme_font_size_override("font_size", 18 if game.reload_left > 0 else 38)
	if game.is_struggling():
		prompt_label.text = "KEEP FIGHTING  /  Hold the button until the bar fills"
	elif game.bandage_left > 0:
		prompt_label.text = "BANDAGING  /  %.1f s" % game.bandage_left
	elif game.reload_left > 0 and game.current_weapon == 0:
		prompt_label.text = "RELOADING  /  Movement locked until loading finishes"
	elif game.is_player_safe() and game.intermission:
		prompt_label.text = "LEAVE THE CABIN  /  Begin level %02d outside" % game.level
	elif game.is_player_safe():
		prompt_label.text = "SHELTERED  /  The pack cannot enter the cabin"
	elif game.near_shop():
		prompt_label.text = "[ E ]  OPEN SUPPLY STORE"
	elif game.intermission:
		prompt_label.text = "[ ENTER ]  START LEVEL %02d   ·   STORE %.0f m" % [game.level, game.nearest_store_distance()]
	else:
		prompt_label.text = "STORE  %.0f m  /  Gold marker on map" % game.nearest_store_distance()
	var interaction: String=game.interaction_prompt()
	if not interaction.is_empty(): prompt_label.text=interaction
	ammo_detail_label.visible = game.reload_left <= 0
	ammo_detail_label.text = "LOADED  /  RESERVE"
	if game.weapon_spec().get("laser",false): ammo_detail_label.text = "CHARGES / R: CRANK FOR %.1fs"%float(game.weapon_spec().reload)
	if game.current_weapon == 9:
		ammo_detail_label.text = "[ V ] %s  /  RESERVE" % ("SHOT BARREL" if game.get("lemat_secondary") else "CYLINDER")
	notice_label.text = game.notice if game.notice_left > 0 and not game.is_struggling() else ""
	save_label.text = "Save unavailable — keep the game open" if not game.progress.last_save_ok else ""
	subtitle_label.text = "“%s”" % game.OPENING_LINE if game.dialogue_left > 0 else ""
	var nearest_awareness := 0.0
	var cue := "NO PACK ALERT"
	for wolf in game.wolves:
		if is_instance_valid(wolf) and wolf.awareness > nearest_awareness:
			nearest_awareness = wolf.awareness
			cue = "PACK ALERTED" if wolf.alerted else ("SUSPICIOUS" if wolf.awareness > 0.1 else "NO PACK ALERT")
	if game.free_play: cue = "NON-HOSTILE ANIMALS"
	prompt_label.visible = not review_open
	stealth_label.text = "%s  /  NOISE %02d%%\n%s" % ["CROUCHED" if game.player.is_crouching else "STANDING", roundi(game.player.get_noise_level() * 100), cue]
	if game.free_play and interaction.is_empty(): prompt_label.text = "LB/RB: all weapons · X: reload · Animals refresh every 60s" if game.controller_device>=0 else "Q / WHEEL: all weapons · R: reload · Animals refresh every 60s"
	var injury: String = game.player.get_injury_summary()
	injury_label.text="[ %s ] BANDAGES %d"%["D-pad up" if game.controller_device>=0 else "B",game.bandages]
	injury_label.position.y=579
	struggle_label.text = ("BREAK FREE: %d%%\n%s" % [roundi(game.struggle_progress*100),"HOLD RT TO FIGHT BACK" if game.controller_device>=0 else "HOLD F OR LEFT MOUSE TO FIGHT BACK"]) if game.is_struggling() else ""
	wolf_focus_label.text = game.get_focused_wolf_text()
	weapon_controls.visible = not review_open
	movement_controls.visible = not review_open
	subtitle_label.visible = not review_open
	for child in compact_layout:
		var anchor := Vector2(1257,704) if child in [weapon_label,ammo_label,ammo_detail_label] else hud_anchor(child.position)
		child.position = anchor+(child.position-anchor)*hud_factor()
		child.scale = compact_layout[child].scale*hud_factor()
	queue_redraw()

func _draw() -> void:
	if not game or game.mode != "playing":
		return
	# Dark transparent backing keeps white text clear against sea and sky.
	draw_group(Vector2(20,18))
	draw_style_box(_panel_style(), Rect2(20, 18, 302, 180))
	draw_group(Vector2(20,704))
	draw_style_box(_panel_style(), Rect2(20, 594, 240, 110))
	var ammo_x := 958.0
	var ammo_y := 249.0 if is_instance_valid(game.shot_review) and game.shot_review.remaining>0 else 577.0
	draw_group(Vector2(640 if ammo_x<900 else 1257,704))
	draw_style_box(_panel_style(), Rect2(ammo_x, ammo_y, 299, 104 if ammo_y<577 else 127))
	if game.dialogue_left > 0:
		draw_group(Vector2(640,704))
		draw_style_box(_panel_style(), Rect2(304, 546, 672, 41))
	if game.reload_left > 0:
		draw_group(Vector2(640 if ammo_x<900 else 1257,704))
		var reload_fraction: float = 1.0 - game.reload_left / game.reload_duration
		draw_rect(Rect2(ammo_x+24, ammo_y+84, 250, 3), Color("485968"))
		draw_rect(Rect2(ammo_x+24, ammo_y+84, 250 * reload_fraction, 3), ACCENT)
	draw_group(Vector2(20,704))
	draw_rect(Rect2(34, 654, 210, 5), Color("52665f"))
	draw_rect(Rect2(34, 654, 210 * game.health / game.maximum_health(), 5), ACCENT if game.health > 30 else Color("e98973"))
	draw_rect(Rect2(102, 680, 142, 3), Color("52665f"))
	var stamina: float = game.player.stamina
	draw_rect(Rect2(102, 680, 142 * stamina / game.player.MAX_STAMINA, 3), MUTED)
	draw_set_transform(Vector2.ZERO)
	if game.mode == "playing":
		# Aim through the physical sights; no crosshair or centre-screen hit marker.
		if game.damage_flash > 0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.08, 0.025, game.damage_flash * 0.2))
	if game.player.bleeding_rate > 0.0 or game.is_struggling():
		var strength: float = 0.035 + game.player.bleeding_rate * 0.018 + (0.07 if game.is_struggling() else 0.0)
		for edge in range(7):
			var inset := float(edge * 12)
			draw_rect(Rect2(Vector2(inset, inset), size - Vector2.ONE * inset * 2), Color(0.45, 0.025, 0.03, strength), false, 15)
	if game.is_struggling():
		draw_group(Vector2(640,18))
		draw_style_box(_panel_style(), Rect2(322, 29, 636, 67))
		draw_rect(Rect2(415, 104, 450, 6), Color(0.12, 0.12, 0.16, 0.9))
		draw_rect(Rect2(415, 104, 450 * game.struggle_progress, 6), Color("e4aa92"))
	draw_group(Vector2(1257,18))
	_draw_map()
	draw_set_transform(Vector2.ZERO)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.085, 0.79)
	style.set_corner_radius_all(3)
	return style

func _map_point(point: Vector3) -> Vector2:
	return Vector2(1065 + (point.x + 230) * .42, 30 + (point.z + 210) * .42)

func _draw_map() -> void:
	draw_rect(Rect2(1060, 23, 190, 182), Color(0.025, 0.08, 0.10, 0.92))
	draw_rect(Rect2(1060, 23, 190, 182), Color("799087"), false, 1)
	for coast: Array in game.world.exploration_data.outlines:
		var shore := PackedVector2Array()
		for p: Array in coast: shore.append(_map_point(Vector3(p[0],0,-p[1])))
		if shore.size() > 2: draw_colored_polygon(shore,Color("46575e"))
	for bridge: Dictionary in game.world.exploration_data.bridges:
		draw_line(_map_point(Vector3(bridge.a[0],0,bridge.a[2])),_map_point(Vector3(bridge.b[0],0,bridge.b[2])),GOLD,2)
	var outline := PackedVector2Array()
	for point in game.world.world_data.get("islandOutline", []):
		outline.append(_map_point(Vector3(float(point[0]), 0, float(point[1]))))
	if outline.size() > 2:
		draw_colored_polygon(outline, Color("6b7c83"))
	var range_point := _map_point(game.world.shooting_range.firing_point)
	draw_circle(range_point,4,Color("76d3eb"))
	for point in game.world.services.store_positions:
		var shop: Vector2 = _map_point(point)
		draw_rect(Rect2(shop - Vector2(3, 3), Vector2(6, 6)), GOLD)
	for animal in game.radar_animals():
		var point: Vector2 = _map_point(animal.position).clamp(Vector2(1068,31),Vector2(1242,197))
		if game.affliction.psychedelic: preload("res://scripts/radar_icons.gd").icon(self,animal,point,game.radar_color(animal))
		else: draw_circle(point,3.2,game.radar_color(animal))
	for target in game.objective_targets():
		var marker := _map_point(target.position).clamp(Vector2(1064,27),Vector2(1246,201))
		if target.position.distance_to(game.player.position)>75: draw_circle(marker,3.2,game.radar_color(target))
		draw_arc(marker,6.0,0,TAU,16,Color("ffe1a4"),1)
	if game.campaign and game.campaign.running:
		var bed: Vector2=_map_point(game.world.bed_wake_position)
		draw_circle(bed,5,Color("9be5ca"))
		if game.coop.active: draw_circle(_map_point(game.coop.local_spawn),4,Color("9be5ca"))
	var pos := _map_point(game.player.position)
	draw_circle(pos, 3.2, PAPER)
	var forward: Vector3 = -game.player.camera.global_basis.z
	draw_line(pos, pos + Vector2(forward.x, forward.z).normalized() * 10, PAPER, 2, true)
	draw_rect(Rect2(1060,208,190,33),Color(.025,.045,.06,.85))
	draw_string(body_font, Vector2(1067, 220), "ALL ANIMALS / species icons" if game.affliction.psychedelic else "75 m: RED hostile / BLUE panic", HORIZONTAL_ALIGNMENT_LEFT, 182, 10, Color("d4e0e5"))
	draw_string(body_font, Vector2(1067, 234), "PINK calm / rings: mission targets", HORIZONTAL_ALIGNMENT_LEFT, 182, 10, Color("d4e0e5"))

func _victory() -> void:
	_block(overlay,Rect2(0,0,1280,720),Color(.025,.055,.065,.95))
	_label(overlay,"YOU MADE IT UNTIL MORNING",Vector2(245,195),40)
	_label(overlay,"30 WAVES SURVIVED",Vector2(455,280),30,ACCENT)
	_label(overlay,"Your money is banked. Every new expedition tells a different story.",Vector2(330,345),18)
	_button(overlay,"NEW EXPEDITION",Rect2(440,440,400,55),game.start_run,true)
	_button(overlay,"MAIN MENU",Rect2(440,515,400,48),game.return_to_menu)

func _connection() -> void:
	var failed: bool=game.mode=="connection_error"
	_block(overlay,Rect2(0,0,1280,720),Color(.025,.055,.065,.96))
	_label(overlay,"COULD NOT JOIN THE SESSION" if failed else "JOINING THE ACTIVE SESSION",Vector2(285,210),32)
	var message: String=game.coop.connection_error if failed else "Connecting to the online host.\nWaiting for the host to assign your cabin."
	var detail:=_label(overlay,message,Vector2(300,285),20,PAPER)
	detail.size=Vector2(680,130); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if failed: _button(overlay,"RETRY / CONTROLLER A",Rect2(430,440,420,55),game.coop.retry_connection,true)
	_button(overlay,"MAIN MENU / CONTROLLER Y",Rect2(430,515,420,48),game.return_to_menu)

func open_weapon_stats() -> void:
	commit_start_options()
	stats_page = 0
	game.set_mode("weapon_stats")

func step_stats_page(direction: int) -> void:
	stats_page = posmod(stats_page + direction, ceili(game.WEAPONS.size() / 7.0))
	refresh_panel()

func _weapon_stats() -> void:
	_block(overlay, Rect2(0, 0, 1280, 720), Color("101b24"))
	_label(overlay, "FIELD GUIDE / WEAPONS & PRICES", Vector2(38, 24), 32, PAPER)
	_label(overlay, "Sorted by price · Base damage before distance, armour and shot placement · Healthy reload times", Vector2(40, 70), 14, MUTED)
	var indices: Array = range(game.WEAPONS.size())
	indices.sort_custom(func(a, b): return int(game.WEAPONS[a].price) < int(game.WEAPONS[b].price))
	var columns := [40, 360, 440, 555, 705, 815, 915, 1015]
	var headings := ["WEAPON", "CREDITS", "DAMAGE", "EFF. / MAX m", "LOAD + SPARE", "RELOAD s", "SHOT GAP s", "SPREAD °"]
	for c in columns.size():
		_label(overlay, headings[c], Vector2(columns[c], 111), 12, ACCENT)
	for row in 7:
		var slot: int = stats_page * 7 + row
		if slot >= indices.size(): break
		var index: int = indices[slot]
		var data: Dictionary = game.WeaponCatalog.weapon(index)
		var y: float = 140 + row * 65
		var stripe := _block(overlay, Rect2(30, y, 1220, 61), Color(.065, .10, .13) if row % 2 == 0 else Color(.045, .075, .10))
		stripe.name = "WeaponStatsRow%d" % index
		var explosive: bool = data.get("explosive", false)
		var per_round: bool = explosive and not data.get("launcher", false)
		var damage := "%.0f" % float(data.damage)
		if int(data.pellets) > 1: damage = "%d × %.0f" % [int(data.pellets), float(data.damage)]
		if explosive: damage += " blast"
		var ranges := "%.0f / %.0f" % [data.effective_range, data.range]
		if explosive: ranges = "— / %.0f" % data.range
		var reload_text := "Next round" if per_round else ("%.2f" % float(data.reload))
		var values := [data.name, str(data.price), damage, ranges, "%d + %d" % [data.magazine, data.reserve], reload_text, "%.2f" % float(data.interval), "%.2f" % rad_to_deg(float(data.spread))]
		for c in columns.size():
			var cell := _label(overlay, values[c], Vector2(columns[c], y + 7), 11 if c == 0 else 13, PAPER)
			cell.name = "Stat%d_%d" % [index, c]
			cell.size.x = (columns[c + 1] - columns[c] - 8) if c < columns.size() - 1 else 210
			cell.clip_text = true
		var note := "%s · Penetration %.2f m · Noise %.0f m" % [data.ammo_type, data.penetration, data.noise_radius]
		if explosive: note = "Blast radius %.0f m · %s · Friendly fire" % [data.blast_radius, "Impact fuse" if data.get("impact_fuse", false) else ("Fuse %.1f s" % data.fuse)]
		if per_round: note += " · One per round, replenished free; kept after throwing"
		elif data.get("flame",false): note = "Hold fire · Short flame cone · Walls block fire · Fuel refills at rest · Friendly fire"
		elif data.get("laser", false): note += " · Crank to recharge; no spare ammunition needed"
		elif index == 9:
			var secondary: Dictionary = game.WeaponCatalog.secondary_weapon()
			note += " · Secondary: %d × %.0f damage / %.0f m effective / %.2f s reload" % [secondary.pellets, secondary.damage, secondary.effective_range, secondary.reload]
		elif index == 0: note += " · Starting weapon granted free; stand still to reload"
		_label(overlay, note, Vector2(40, y + 34), 12, MUTED)
	_label(overlay, "Shotgun damage is pellet count × damage per pellet. Effective range marks falloff; maximum is the flight limit (explosive reach is nominal).", Vector2(40, 608), 13, MUTED)
	_label(overlay, "Spread is base cone deviation (lower is better); movement and aiming affect accuracy. Vital hits can be fatal.", Vector2(40, 630), 13, MUTED)
	_button(overlay, "← PREVIOUS", Rect2(40, 665, 180, 38), func(): step_stats_page(-1))
	_label(overlay, "PAGE %d / %d · D-pad ← / →" % [stats_page + 1, ceili(indices.size() / 7.0)], Vector2(250, 674), 14, ACCENT)
	_button(overlay, "NEXT →", Rect2(560, 665, 160, 38), func(): step_stats_page(1))
	_button(overlay, "BACK / ESC / CONTROLLER B", Rect2(880, 665, 355, 38), func(): game.set_mode("menu"))
