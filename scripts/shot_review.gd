extends Control
## Bone-rendered shot review. The calculation is the same one used by combat.
var game: Node
var reports: Array[Dictionary] = []
var trajectories: Array[Dictionary] = []
var remaining := 0.0
const DOUBLE_TAP_MS := 320
var last_x_press := -1
var dismissed := false
var serial := 0
const HISTORY_LIMIT := 32
var history: Array[Dictionary] = []
var selected := 0
var caption := "MISS — NO ANIMAL HIT"
var font := ThemeDB.fallback_font
var wildlife: Control
var human: Control
var xray: Control
var front_views: Array[Control]=[]
var replay: Control
var replay_dirty:=false
var replay_restart:=false
const DISPLAY_SECONDS:=4.0
func _ready() -> void:
	position = Vector2(845,365)
	size = Vector2(410,345)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay=preload("res://scripts/shot_replay.gd").new()
	replay.position=Vector2(-332,0); add_child(replay)
	xray = preload("res://scripts/wolf_xray.gd").new()
	xray.position = Vector2(5,51)
	xray.size = Vector2(400,132)
	add_child(xray)
	human = preload("res://scripts/human_xray.gd").new()
	human.position = xray.position
	human.size = xray.size
	add_child(human)
	wildlife = preload("res://scripts/wildlife_xray.gd").new()
	wildlife.position=xray.position; wildlife.size=xray.size
	add_child(wildlife)
	for pair in [[xray,"wolf_xray"],[human,"human_xray"],[wildlife,"wildlife_xray"]]:
		pair[0].size=Vector2(244,132)
		var front: Control=load("res://scripts/"+pair[1]+".gd").new()
		front.front_view=true; front.position=Vector2(253,51); front.size=Vector2(151,132)
		add_child(front); front_views.append(front)

func reset_history() -> void:
	dismissed=false; last_x_press=-1
	history.clear(); selected=0; serial=0; remaining=0
	reports=[]; trajectories=[]
	replay_restart=true
	_refresh_models()
func begin_shot(flying: bool = false) -> void:
	dismissed=false; last_x_press=-1
	serial += 1
	reports=[]; trajectories=[]
	caption = "PROJECTILE IN FLIGHT" if flying else "MISS — NO ANIMAL HIT"
	history.push_front({"serial":serial,"reports":reports,"trajectories":trajectories,"caption":caption,"nearby":capture_nearby()})
	if history.size()>HISTORY_LIMIT: history.pop_back()
	selected=0; remaining=DISPLAY_SECONDS; replay_restart=true
	_refresh_models()
func entry_for(shot_serial: int) -> Dictionary:
	for entry in history:
		if entry.serial==shot_serial: return entry
	return {}

func capture_nearby() -> Array[Dictionary]:
	var records: Array[Dictionary]=[]
	var start: Vector3=game.player.camera.global_position
	var end: Vector3=start-game.player.camera.global_basis.z*180
	var candidates: Array=game.wolves+game.nodes_in_group("wildlife")+game.nodes_in_group("campaign_threats")
	if game.coop.client(): candidates.append_array(game.coop.replicas.values())
	var seen: Dictionary={}
	for animal in candidates:
		if not is_instance_valid(animal) or animal.dead or animal.is_queued_for_deletion() or seen.has(animal.get_instance_id()): continue
		seen[animal.get_instance_id()]=true
		var target_id: int=animal.get_instance_id()
		if game.coop.client():
			for host_id in game.coop.replicas:
				if game.coop.replicas[host_id]==animal: target_id=int(host_id); break
		var distance: float=Geometry3D.get_closest_point_to_segment(animal.position,start,end).distance_to(animal.position)
		if distance>12: continue
		var pose: Transform3D=animal.global_transform
		var species: String=str(animal.get("species")) if animal.get("species")!=null else "wolf"
		if animal is IslandWolf:
			pose.basis=pose.basis.scaled_local(Vector3.ONE*animal.size_scale)
			if animal.werewolf: species="werewolf"
		if species=="legionary": species="raider"
		records.append({"target_uid":target_id,"target_transform":pose,"species":species,"distance_to_line":distance,"organs":[],"entry":Vector3.ZERO,"end":Vector3.UP*.001,"unhit":true})
	records.sort_custom(func(a,b): return a.distance_to_line<b.distance_to_line)
	return records.slice(0,8)
func displayed() -> Dictionary:
	return history[selected] if not history.is_empty() else {"serial":serial,"reports":reports,"trajectories":trajectories,"caption":caption}
func target_reports(all_hits: Array[Dictionary]) -> Array[Dictionary]:
	if all_hits.is_empty(): return all_hits
	var target_id: int=int(all_hits.back().get("target_uid",0))
	return all_hits.filter(func(hit): return int(hit.get("target_uid",0))==target_id)
func _refresh_models() -> void:
	replay_dirty=true
	if not is_instance_valid(xray): return
	var shown: Array[Dictionary]=target_reports(displayed().reports)
	xray.review(shown); human.review(shown); wildlife.review(shown)
	for front in front_views: front.review(shown)
	queue_redraw()
func cycle_review() -> void:
	if not game.mode in ["playing","resting"]: return
	dismissed=false
	game.hud_detail_left = 8.0
	if history.is_empty(): return
	selected=0 if remaining<=0 else (selected+1)%history.size()
	remaining=DISPLAY_SECONDS; replay_restart=true
	_refresh_models()
func record_path(path: Dictionary, shot_serial: int) -> void:
	var entry:=entry_for(shot_serial)
	if entry.is_empty(): return
	var paths: Array[Dictionary]=entry.trajectories
	# Update a flying projectile; firearm pellets retain separate sampled arcs.
	if path.get("projectile",false) and not paths.is_empty(): paths[0]=path.duplicate(true)
	elif paths.size()<18: paths.append(path.duplicate(true))
	if entry.reports.is_empty(): entry.caption=str(path.outcome)
	if shot_serial==serial: caption=entry.caption
	if displayed().serial==shot_serial:
		if not dismissed: remaining=DISPLAY_SECONDS
		replay_dirty=true; queue_redraw()
func record(report: Dictionary, shot_serial: int = -1) -> void:
	if history.is_empty() and shot_serial<0: begin_shot()
	if shot_serial<0: shot_serial=serial
	var entry:=entry_for(shot_serial)
	if entry.is_empty(): return
	var hits: Array[Dictionary]=entry.reports
	if hits.size()<18: hits.append(report.duplicate(true))
	var labels: Array[String]=[]
	for hit in target_reports(hits):
		for organ: String in hit.organs:
			if not labels.has(organ): labels.append(organ)
	entry.caption=" + ".join(labels).to_upper() if not labels.is_empty() else str(report.zone).to_upper()
	if report.get("species","")=="hunter" and not labels.is_empty(): entry.caption="FRIENDLY FIRE / "+entry.caption
	if hits.size()>1: entry.caption+=" / %d HIT TRACES"%target_reports(hits).size()
	if shot_serial==serial: caption=entry.caption
	if displayed().serial==shot_serial:
		if not dismissed: remaining=DISPLAY_SECONDS
		_refresh_models()
func _process(delta: float) -> void:
	var expanded: bool = game.hud_detail_left > 0.0
	var split: bool = is_instance_valid(game.split_session)
	var factor: float = (.65 if expanded else .45) if split else (1.0 if expanded else .65)
	scale = Vector2.ONE*factor
	position = Vector2(1271-410*factor,354-345*factor) if split else Vector2(1255-410*factor,710-345*factor)
	# Misses retain their arc/range and nearby silhouettes without obscuring play.
	modulate.a = 1.0 if expanded or not displayed().reports.is_empty() else .38
	if replay_dirty:
		replay.load_shot(displayed(),replay_restart)
		replay_dirty=false; replay_restart=false
	if game.mode in ["playing","resting"]: remaining=maxf(0,remaining-delta)
	visible=remaining>0 and game.mode in ["playing","resting"]
	replay.tick(delta,visible)
	var shown: Array[Dictionary]=target_reports(displayed().reports)
	wildlife.visible=not shown.is_empty() and str(shown.back().get("species","")) in ["deer","duck","goose","mink","bear"]
	human.visible=not shown.is_empty() and str(shown.back().get("species","")) in ["hunter","raider","werewolf"]
	xray.visible=not shown.is_empty() and str(shown.back().get("species","wolf"))=="wolf"
	front_views[0].visible=xray.visible; front_views[1].visible=human.visible; front_views[2].visible=wildlife.visible
func close_review() -> void:
	dismissed=true
	remaining=0.0
	game.hud_detail_left=0.0
	hide()
	replay.tick(0,false)
func _unhandled_key_input(event: InputEvent) -> void:
	if game.controller_device>=0: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_X:
		if not game.mode in ["playing","resting"]: return
		var now := Time.get_ticks_msec()
		if last_x_press>=0 and now-last_x_press<=DOUBLE_TAP_MS:
			last_x_press=-1
			close_review()
		else:
			last_x_press=now
			cycle_review()
func label_at(y: float,text: String,color: Color=Color("cbd9e0"),font_size: int=12) -> void:
	draw_string(font,Vector2(13,y),text,HORIZONTAL_ALIGNMENT_LEFT,385,font_size,color)
func _draw() -> void:
	var shown:=displayed()
	var hits: Array[Dictionary]=target_reports(shown.reports)
	var box:=StyleBoxFlat.new()
	box.bg_color=Color(.015,.028,.047,.95)
	box.border_color=Color("4c7e91")
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	var target_review: bool = not hits.is_empty() and hits.back().get("species","")=="target"
	label_at(24,("SHOT %03d / FLIGHT REVIEW" if hits.is_empty() else "SHOT %03d / RANGE REVIEW" if target_review else "SHOT %03d / BONE X-RAY") % int(shown.serial),Color("eac28b"),16)
	label_at(45,str(shown.caption),Color("e9e5dd"),12)
	if hits.is_empty():
		label_at(86,"No animal hit to inspect.")
		label_at(286,"Damage: 0")
	else:
		var total:=0.0
		var calculated:=0.0
		for hit: Dictionary in hits: total+=float(hit.get("damage",0))
		for hit: Dictionary in hits: calculated+=float(hit.get("calculated_damage",hit.get("damage",0)))
		var shot: Dictionary=hits.back()
		label_at(272,"%s  /  %.1f m to hit" % [shot.get("weapon","SHOT"),shot.get("distance",0.0)])
		label_at(292,"%.1f base × %.2f range × %.2f placement" % [shot.get("base_damage",0.0),shot.get("range_factor",1.0),shot.multiplier])
		label_at(314,("%.1f estimated weapon damage" % calculated) if target_review else ("%.1f damage / %.1f lost / %.0f cm tissue" % [calculated,total,float(shot.get("body_depth_m",shot.entry.distance_to(shot.end)))*100]),Color("ffcc8a"),12)
	label_at(335,"%s older / %d of %d / %s" % ["D-pad down" if game.controller_device>=0 else "X browse / double X close",selected+1,history.size(),"FATAL VITAL HIT" if not hits.is_empty() and hits.back().get("instant_fatal",false) else "combat continues"],Color("91acb9"),10)
	if not hits.is_empty():
		draw_string(font,Vector2(14,66),"SIDE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("91acb9"))
		draw_string(font,Vector2(260,66),"FRONT",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("91acb9"))
	_draw_trajectory(shown.trajectories,hits.is_empty())

static func plot_samples(path: Dictionary) -> PackedVector2Array:
	var samples: PackedVector3Array=path.points
	var direction: Vector3=path.direction
	var horizontal:=Vector2(direction.x,direction.z)
	var curve:=PackedVector2Array()
	for point in samples:
		var offset:=point-samples[0]
		var run:=Vector2(offset.x,offset.z).dot(horizontal.normalized())
		# Remove the launch angle so aiming down doesn't hide gravity's curve.
		var drop:=offset.y-run*direction.y/horizontal.length() if horizontal.length()>.01 else 0.0
		curve.append(Vector2(run,drop))
	return curve
func _draw_trajectory(paths: Array[Dictionary],miss: bool) -> void:
	if paths.is_empty(): return
	var shot: Dictionary = paths.back()
	var graph := Rect2(18,121,342,121) if miss else Rect2(18,198,342,44)
	var max_x := .1
	var low := 0.0
	var high := 0.0
	var curves: Array[PackedVector2Array] = []
	var aims: Array[Vector2] = []
	for path in paths:
		var curve:=plot_samples(path)
		for p in curve:
			max_x=maxf(max_x,p.x)
			low=minf(low,p.y); high=maxf(high,p.y)
		curves.append(curve); aims.append(Vector2(curve[-1].x,0))

	var bones: Array[Vector2]=[]
	var bone_lines: Array[PackedVector2Array]=[]
	var hit_list: Array[Dictionary]=target_reports(displayed().reports)
	if not hit_list.is_empty():
		var hit: Dictionary=hit_list[0]
		var helper: Control=human if hit.get("species","wolf") in ["hunter","raider","werewolf"] else xray if hit.get("species","wolf")=="wolf" else wildlife
		var pose: Transform3D=hit.get("target_transform",Transform3D.IDENTITY)
		var start: Vector3=shot.points[0]
		var direction: Vector3=shot.direction
		var horizontal:=Vector2(direction.x,direction.z)
		if horizontal.length()>.01:
			for batch in helper.scene.find_children("*","MultiMeshInstance3D",true,false):
				if batch.multimesh==null: continue
				for index in batch.multimesh.instance_count:
					var transform: Transform3D=helper.scene.global_transform.affine_inverse()*batch.global_transform*batch.multimesh.get_instance_transform(index)
					var segment:=PackedVector2Array()
					for tip in [-.5,.5]:
						var local: Vector3=transform*Vector3(0,tip,0)
						var offset: Vector3=pose*local-start
						var run:=Vector2(offset.x,offset.z).dot(horizontal.normalized())
						var height:=offset.y-run*direction.y/horizontal.length()
						segment.append(Vector2(local.z-hit.entry.z,height)); low=minf(low,height); high=maxf(high,height)
					bone_lines.append(segment)
			for node in helper.scene.find_children("*","MeshInstance3D",true,false):
				if node.mesh is CylinderMesh:
					var segment:=PackedVector2Array()
					for tip in [-.5,.5]:
						var vertex: Vector3=helper.scene.global_transform.affine_inverse()*node.global_transform*Vector3(0,tip*node.mesh.height,0)
						var offset: Vector3=pose*vertex-start
						var run:=Vector2(offset.x,offset.z).dot(horizontal.normalized())
						var height:=offset.y-run*direction.y/horizontal.length()
						segment.append(Vector2(vertex.z-hit.entry.z,height)); low=minf(low,height); high=maxf(high,height)
					bone_lines.append(segment)
				var local: Vector3=helper.scene.global_transform.affine_inverse()*node.global_position
				var offset: Vector3=pose*local-start
				var run:=Vector2(offset.x,offset.z).dot(horizontal.normalized())
				var height:=offset.y-run*direction.y/horizontal.length()
				bones.append(Vector2(local.z-hit.entry.z,height)); low=minf(low,height); high=maxf(high,height)
	low -= .05; high += .05
	var scale_point := func(p: Vector2) -> Vector2:
		return graph.position+Vector2(p.x/max_x*graph.size.x,(high-p.y)/(high-low)*graph.size.y)
	draw_rect(graph,Color(.06,.11,.15))

	# Side anatomy inset at the endpoint, aligned vertically in metres with the shot.
	for point in bones:
		var y: float=scale_point.call(Vector2(0,point.y)).y
		draw_circle(Vector2(graph.end.x+point.x*18,y),1,Color(.35,.72,.9,.7))
	for segment in bone_lines:
		var a: Vector2=Vector2(graph.end.x+segment[0].x*18,scale_point.call(Vector2(0,segment[0].y)).y)
		var b: Vector2=Vector2(graph.end.x+segment[1].x*18,scale_point.call(Vector2(0,segment[1].y)).y)
		draw_line(a,b,Color(.35,.72,.9,.65),1,true)
	for i in curves.size():
		var curve := PackedVector2Array()
		for p in curves[i]: curve.append(scale_point.call(p))
		draw_dashed_line(scale_point.call(Vector2.ZERO),scale_point.call(aims[i]),Color("71848c"),1,4)
		if curve.size()>1: draw_polyline(curve,Color("edbd75"),1.5,true)
		draw_circle(curve[-1],2.5,Color("ff886e"))
	label_at(graph.position.y-5,"DROP BELOW AIM / "+("GRAVITY ARC" if shot.curved else "LASER")+(" / target width enlarged" if not miss else " / vertical magnified"),Color("91acb9"),10)
	label_at(255,"Travel %.1f m  /  ground %.1f m  /  drop %.2f m" % [shot.travelled,shot.ground_range,shot.drop],Color("edbd75"),11)
	if miss:
		label_at(272,"%s / %.1f m from muzzle" % [shot.weapon,shot.distance])
		label_at(309,"Weapon limit %.0f m / %s" % [shot.limit,"arc: gold / aim: dashed" if shot.curved else "straight beam"],Color("91acb9"),11)
