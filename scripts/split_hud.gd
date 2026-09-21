extends Control
var game: Node
var font := ThemeDB.fallback_font
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var condition:=preload("res://scripts/injury_avatar.gd").new(); condition.game=game
	condition.position=Vector2(10,153); condition.scale=Vector2.ONE*.8; add_child(condition)
func _process(_delta: float) -> void: queue_redraw()
func label(p: Vector2,value: String,color: Color=Color.WHITE,size: int=15) -> void:
	draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func _draw() -> void:
	if game.mode!="playing": return
	draw_rect(Rect2(8,8,365,74),Color(0,0,0,.7))
	label(Vector2(17,28),"P%d  /  LEVEL %02d  /  %s"%[1 if game.controller_device<0 else 2,game.level,game.objective_species().to_upper()])
	label(Vector2(17,49),game.campaign.objective_text() if not game.free_play else "FREE PLAY",Color("e9bb7f"))
	label(Vector2(17,70),"%d CR / YOUR CREDITS"%game.progress.money,Color("e9bb7f"),14)
	draw_rect(Rect2(8,288,390,65),Color(0,0,0,.7))
	label(Vector2(17,308),"HP %d  /  STAMINA %d%%  /  %d + %d"%[game.health,100*game.player.stamina/game.player.MAX_STAMINA,game.current_ammo(),game.current_reserve()])
	label(Vector2(17,329),game.weapon_display_name(),Color("e9bb7f"),13)
	label(Vector2(17,347),game.player.get_reload_stage() if game.reload_left>0 else ("Space jump • Shift sprint • E store" if game.controller_device<0 else "Y interact • LB/RB weapon • X reload • A jump"),Color("aabbbf"),12)
	if game.notice_left>0: label(Vector2(410,40),game.notice,Color("ffe3ae"),13)
	label(Vector2(410,320),game.interaction_prompt(),Color("ffe3ae"),13)
	if game.is_struggling():
		label(Vector2(450,170),"BREAK FREE: %d%%"%roundi(game.struggle_progress*100),Color("ff7755"),22)
		label(Vector2(450,192),"HOLD RT" if game.controller_device>=0 else "HOLD F OR LEFT MOUSE",Color("ffe3ae"),14)
		draw_rect(Rect2(450,202,350,12),Color(.05,.02,.02,.9))
		draw_rect(Rect2(450,202,350*game.struggle_progress,12),Color("ffad78"))
	if game.controller_device>=0 and Input.get_connected_joypads().is_empty(): label(Vector2(410,210),"CONNECT A CONTROLLER FOR PLAYER 2",Color("ffe3ae"),20)
	draw_rect(Rect2(1100,8,170,106),Color(0,0,0,.75))
	for coast in game.world.exploration_data.outlines:
		var outline:=PackedVector2Array()
		for vertex in coast: outline.append(Vector2(1105+(vertex[0]+230)*.35,12+(-vertex[1]+210)*.24))
		if outline.size()>2: draw_colored_polygon(outline,Color("364647"))
	for animal in game.radar_animals():
		var marker:=Vector2(1105+(animal.position.x+230)*.35,12+(animal.position.z+210)*.24).clamp(Vector2(1104,12),Vector2(1266,110))
		draw_circle(marker,3,game.radar_color(animal))
	for target in game.objective_targets():
		var p:=Vector2(1105+(target.position.x+230)*.35,12+(target.position.z+210)*.24).clamp(Vector2(1104,12),Vector2(1266,110))
		draw_arc(p,4.5,0,TAU,12,Color("ffe1a4"),1)
	for point in game.world.services.store_positions:
		var shop:=Vector2(1105+(point.x+230)*.35,12+(point.z+210)*.24)
		draw_rect(Rect2(shop-Vector2.ONE*2,Vector2.ONE*4),Color("e9bb7f"))
	if game.campaign.running:
		var bed: Vector3=game.world.bed_wake_position
		draw_circle(Vector2(1105+(bed.x+230)*.35,12+(bed.z+210)*.24),4,Color("9be5ca"))
	var p:=Vector2(1105+(game.player.position.x+230)*.35,12+(game.player.position.z+210)*.24).clamp(Vector2(1104,12),Vector2(1266,110))
	draw_circle(p,3,Color.WHITE)
