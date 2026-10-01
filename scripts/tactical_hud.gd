extends Control
## Shared layout for solo and every split-screen viewport; icons are drawn, not font glyphs.
const PAPER=Color("e8eee8")
const GOLD=Color("e9bf83")
const RED=Color("ff7665")
var game: Node
var font=ThemeDB.fallback_font
var tick:=0.0
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	tick-=delta
	if tick<=0: tick=.05; queue_redraw()
func text(at: Vector2,value: String,color: Color=PAPER,size: int=14,width: float=300) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)
func panel(rect: Rect2) -> void:
	draw_rect(rect,Color(.025,.04,.05,.82))
	draw_line(rect.position,rect.position+Vector2(rect.size.x,0),Color(.4,.55,.56,.5),1)
func icon(kind: String,p: Vector2,color: Color=PAPER) -> void:
	match kind:
		"health":
			draw_line(p-Vector2(5,0),p+Vector2(5,0),color,3)
			draw_line(p-Vector2(0,5),p+Vector2(0,5),color,3)
		"stamina": draw_polyline(PackedVector2Array([p+Vector2(3,-6),p+Vector2(-3,0),p+Vector2(3,0),p+Vector2(-3,6)]),color,2,true)
		"money": draw_circle(p,5,color,false,2); draw_line(p-Vector2(0,3),p+Vector2(0,3),color,1)
		"ammo": draw_rect(Rect2(p-Vector2(3,4),Vector2(6,9)),color,false,1); draw_line(p+Vector2(-3,-4),p+Vector2(0,-7),color,2); draw_line(p+Vector2(0,-7),p+Vector2(3,-4),color,2)
		"eye": draw_arc(p,5,0,TAU,14,color,1); draw_circle(p,2,color)
		"power": draw_colored_polygon(PackedVector2Array([p+Vector2(0,-6),p+Vector2(5,0),p+Vector2(0,6),p+Vector2(-5,0)]),color)
func map_point(p: Vector3,rect: Rect2) -> Vector2:
	return (rect.position+Vector2((p.x+230)/460,(p.z+210)/440)*rect.size).clamp(rect.position+Vector2.ONE*5,rect.end-Vector2.ONE*5)
func map_draw(rect: Rect2) -> void:
	panel(rect)
	for coast in game.world.exploration_data.outlines:
		var poly:=PackedVector2Array()
		for v in coast: poly.append(map_point(Vector3(v[0],0,-v[1]),rect))
		if poly.size()>2: draw_colored_polygon(poly,Color("3e5152"))
	for bridge in game.world.exploration_data.bridges:
		draw_line(map_point(Vector3(bridge.a[0],0,bridge.a[2]),rect),map_point(Vector3(bridge.b[0],0,bridge.b[2]),rect),GOLD,1)
	for point in game.world.services.store_positions: draw_rect(Rect2(map_point(point,rect)-Vector2.ONE*2,Vector2.ONE*4),GOLD)
	for animal in game.radar_animals():
		if game.rituals.all_radar() and game.radar_dangerous(animal): preload("res://scripts/radar_icons.gd").skull(self,map_point(animal.position,rect),game.radar_color(animal))
		else: draw_circle(map_point(animal.position,rect),2.5,game.radar_color(animal))
	for animal in game.objective_targets(): draw_arc(map_point(animal.position,rect),5,0,TAU,12,GOLD,1)
	for avatar in game.coop.avatars.values():
		var p:=map_point(avatar.position,rect)
		if avatar.health<=0:
			draw_circle(p,7,Color(.15,.01,.01,.95)); icon("health",p,RED)
			text(p+Vector2(8,4),"P%d"%int(game.coop.slots.get(avatar.peer_id,avatar.peer_id-1)+1),RED,11,30)
		else: draw_circle(p,3,Color("7ee2db"))
	var own:=map_point(game.player.position,rect)
	if game.health<=0: icon("health",own,RED)
	else:
		draw_circle(own,3,PAPER)
		var forward: Vector3=-game.player.camera.global_basis.z
		draw_line(own,own+Vector2(forward.x,forward.z)*8,PAPER,2)
func _draw() -> void:
	if not game or game.mode not in ["playing","waiting"]: return
	var screen:=get_viewport_rect().size
	var small:=screen.y<500
	var margin:=10.0
	var top_width:=minf(360,screen.x*.38)
	panel(Rect2(margin,margin,top_width,57))
	var slot: int=1 if game.coop.peer_id()==1 else int(game.coop.earning_slots.get(game.coop.peer_id(),game.coop.peer_id()))
	text(Vector2(20,29),"P%d  ·  %s"%[slot,"FREE PLAY" if game.free_play else "WAVE %02d"%game.level],GOLD,14,top_width-20)
	if game.free_play: text(Vector2(20,51),"Practice · all weapons",PAPER,13,top_width-20)
	else:
		var job: Dictionary=game.campaign.job if game.campaign.running else game.campaign.preview()
		var x:=25.0
		for kind in ["hunt","kill"]:
			for species in job.get(kind,{}):
				preload("res://scripts/radar_icons.gd").species_icon(self,species,Vector2(x,46),GOLD)
				text(Vector2(x+13,51),"%d/%d"%[game.campaign.done.get(kind+"_"+species,0),job[kind][species]],PAPER,13,65)
				x+=82
		if game.intermission: text(Vector2(x,51),"Leave to begin",PAPER,11,maxf(70,top_width-x))
	var y:=screen.y-63
	panel(Rect2(10,y,300,53))
	icon("health",Vector2(24,y+18),RED if game.health<30 else PAPER)
	text(Vector2(36,y+23),"%d"%ceili(game.health),PAPER,18,48)
	icon("stamina",Vector2(99,y+18)); text(Vector2(111,y+23),"%d%%"%roundi(game.player.stamina/game.player.MAX_STAMINA*100),PAPER,14,58)
	icon("money",Vector2(177,y+18),GOLD); text(Vector2(189,y+23),str(game.progress.money),GOLD,16,110)
	draw_rect(Rect2(20,y+32,125,3),Color("384846")); draw_rect(Rect2(20,y+32,125*clampf(game.health/game.maximum_health(),0,1),3),RED)
	draw_rect(Rect2(155,y+32,143,3),Color("384846")); draw_rect(Rect2(155,y+32,143*game.player.stamina/game.player.MAX_STAMINA,3),GOLD)
	text(Vector2(20,y+47),"B / D-pad ↑  dressings ∞",PAPER,10,180)
	icon("eye",Vector2(224,y+44)); text(Vector2(235,y+48),"%d%%"%roundi(game.player.get_noise_level()*100),PAPER,10, 60.0)
	# Weapon info shares the left corner so replay never pushes it into the view.
	icon("ammo",Vector2(21,y-14),GOLD)
	text(Vector2(34,y-9),"%d / %s  %s"%[game.current_ammo(),"∞" if game.weapon_spec().get("laser",false) else str(game.current_reserve()),game.weapon_display_name()],PAPER,13,380)
	if game.reload_left>0: text(Vector2(20,y-31),"%s  %.1fs"%[game.player.get_reload_stage(),game.reload_left],GOLD,12,380)
	var powers: Array=game.rituals.status_entries()
	var injury: String=game.player.get_injury_summary()
	if game.affliction.infected_wave>=0: injury+=(" · " if not injury.is_empty() else "")+"LYCANTHROPY"
	if game.affliction.psychedelic: injury+=(" · " if not injury.is_empty() else "")+"PSYCHEDELIC"
	if not injury.is_empty(): text(Vector2(20,y-49),injury,RED,12,360)
	if not powers.is_empty():
		icon("power",Vector2(22,y-66),GOLD); text(Vector2(34,y-62),"%d powers · X: details"%powers.size(),GOLD,12,300)
	if game.hud_detail_left>0:
		var columns:=3 if small else 2
		var height:=24.0+ceilf(float(powers.size())/columns)*28
		var base:=Vector2(10,maxf(75,y-80-height))
		panel(Rect2(base,Vector2(columns*300+10,height)))
		text(base+Vector2(10,17),"STATUS / PERMANENT POWERS",GOLD,12,590)
		for i in powers.size():
			var p:=base+Vector2(10+(i%columns)*300,34+floori(float(i)/columns)*28)
			text(p,"%s ×%d"%[powers[i].name,powers[i].count],GOLD,11,290)
			text(p+Vector2(0,12),powers[i].description,PAPER,10,290)
	map_draw(Rect2(screen.x-158,10,148,112 if small else 140))
	if game.coop.active: text(Vector2(20,81),game.coop.earnings_text(),GOLD,11,top_width)
	var prompt: String=game.interaction_prompt()
	if game.bandage_left>0: prompt="Dressing wound · %.1fs"%game.bandage_left
	if not prompt.is_empty(): text(Vector2(screen.x*.5-220,screen.y-18),prompt,GOLD,12,440)
	if game.notice_left>0: text(Vector2(screen.x*.5-210,84 if small else 98),game.notice,GOLD,12,420)
	if game.dialogue_left>0: text(Vector2(screen.x*.5-220,screen.y-43),game.OPENING_LINE,PAPER,14,440)
	if game.is_struggling():
		var p:=Vector2(screen.x*.5-130,screen.y*.32)
		panel(Rect2(p,Vector2(260,43))); text(p+Vector2(10,17),"HOLD RT / F · BREAK FREE %d%%"%roundi(game.struggle_progress*100),RED,12,245)
		draw_rect(Rect2(p+Vector2(10,28),Vector2(240*game.struggle_progress,5)),RED)
	if game.damage_flash>0: draw_rect(Rect2(Vector2.ZERO,screen),Color(.7,.03,.015,game.damage_flash*.18))
