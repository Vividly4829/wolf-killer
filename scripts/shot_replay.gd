extends Control
## Isolated trajectory reconstruction. Never changes game time or live actors.
const LENGTH:=4.0
const FLIGHT_LENGTH:=3.5
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var content: Node3D
var trail: MeshInstance3D
var markers: Array[MeshInstance3D]=[]
var paths: Array[Dictionary]=[]
var elapsed:=0.0
var source_duration:=0.0
var origin:=Vector3.ZERO
var heading:=Vector3.FORWARD
var serial:=-1
var ready_to_play:=false
var outcome:="Recording flight..."
var font:=ThemeDB.fallback_font
var main_length:=0.0
var blood: Array[MeshInstance3D]=[]
var unhit_positions: Array[Vector3]=[]
var missed:=false
func _ready() -> void:
	size=Vector2(320,345); mouse_filter=Control.MOUSE_FILTER_IGNORE
	var container:=SubViewportContainer.new(); container.position=Vector2(8,48); container.size=Vector2(304,236)
	container.stretch=true; container.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(608,472); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; container.add_child(viewport)
	stage=Node3D.new(); viewport.add_child(stage)
	var environment:=WorldEnvironment.new(); var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR; settings.background_color=Color("101e29")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color=Color("9dbbcc"); settings.ambient_light_energy=.8
	environment.environment=settings; stage.add_child(environment)
	camera=Camera3D.new(); camera.fov=55; camera.near=.02; camera.far=1000; stage.add_child(camera); camera.current=true
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-30,0); light.light_energy=1.4; stage.add_child(light)
func mat(color: Color) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new(); material.albedo_color=color
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a<1: material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
func line_mesh(lines: Array, material: Material) -> MeshInstance3D:
	var mesh:=ImmediateMesh.new()
	if not lines.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for line in lines: mesh.surface_add_vertex(line[0]); mesh.surface_add_vertex(line[1])
		mesh.surface_end()
	var node:=MeshInstance3D.new(); node.mesh=mesh; node.material_override=material; content.add_child(node); return node
func load_shot(entry: Dictionary,restart: bool=false) -> void:
	var was_ready:=ready_to_play
	var changed: bool=serial!=int(entry.serial)
	serial=int(entry.serial); paths.assign(entry.trajectories)
	ready_to_play=not paths.is_empty() and paths.all(func(p): return bool(p.get("complete",true)))
	if changed or restart or (ready_to_play and not was_ready): elapsed=0
	if is_instance_valid(content): content.free()
	content=Node3D.new(); stage.add_child(content); markers.clear(); blood.clear(); unhit_positions.clear()
	missed=entry.reports.is_empty()
	source_duration=0; main_length=0
	if paths.is_empty(): outcome="Recording flight..."; queue_redraw(); return
	origin=paths[0].points[0]; heading=paths[0].direction.normalized()
	var full_lines: Array=[]
	for path in paths:
		source_duration=maxf(source_duration,float(path.get("duration",0)))
		main_length=maxf(main_length,float(path.travelled))
		for i in range(1,path.points.size()): full_lines.append([path.points[i-1]-origin,path.points[i]-origin])
		var marker:=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=.065; sphere.height=.13; sphere.radial_segments=12; sphere.rings=6
		marker.mesh=sphere; marker.material_override=mat(Color("ffdc91")); content.add_child(marker); markers.append(marker)
	line_mesh(full_lines,mat(Color("425664")))
	trail=line_mesh([],mat(Color("ffbf69")))
	var endpoint: Vector3=paths[0].points[-1]-origin
	var side:=heading.cross(Vector3.UP).normalized()
	if side.length_squared()<.1: side=Vector3.RIGHT
	var grid: Array=[]
	var ground:=Vector3(0,minf(0,endpoint.y)-1,0)
	var horizontal:=Vector3(heading.x,0,heading.z).normalized()
	if horizontal.length_squared()<.1: horizontal=Vector3.FORWARD
	for i in 21:
		var at:=ground+horizontal*(main_length*i/20)
		grid.append([at-side*3,at+side*3])
	for i in 7: grid.append([ground+side*(i-3),ground+side*(i-3)+horizontal*main_length])
	line_mesh(grid,mat(Color("233b4b")))
	# Rebuild only the struck anatomy at its recorded pose, not a moving live actor.
	var targets: Dictionary={}
	for report in entry.reports:
		if not report.has("target_transform"): continue
		var id: int=int(report.get("target_uid",0))
		if not targets.has(id): targets[id]=[]
		targets[id].append(report)
	for record in entry.get("nearby",[]):
		if targets.has(record.target_uid): continue
		var near_path:=false
		for path in paths:
			for i in range(1,path.points.size()):
				if Geometry3D.get_closest_point_to_segment(record.target_transform.origin,path.points[i-1],path.points[i]).distance_to(record.target_transform.origin)<10: near_path=true; break
		if near_path: targets[record.target_uid]=[record]
	for hits in targets.values():
		var report: Dictionary=hits[0]; var species: String=report.get("species","wolf")
		var script: String="human_xray" if species in ["hunter","raider","werewolf","angel","devil"] else "wolf_xray" if species=="wolf" else "wildlife_xray"
		var helper=load("res://scripts/"+script+".gd").new(); helper.visible=false; add_child(helper)
		var typed_hits: Array[Dictionary]=[]; typed_hits.assign(hits); helper.review(typed_hits)
		var body: Node3D=helper.scene; body.reparent(content)
		for child in body.get_children():
			if child is Camera3D: child.queue_free()
		body.transform=report.target_transform; body.position-=origin
		if report.get("unhit",false):
			unhit_positions.append(body.position+Vector3.UP*.65)
			var label:=Label3D.new(); label.text=report.species.to_upper()+" / UNHIT"
			label.font_size=24; label.pixel_size=.007; label.position=body.position+Vector3.UP*1.9
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.modulate=Color("8ec9e1"); content.add_child(label)
		elif species!="target":
			var damage := 0.0
			for hit in hits: damage+=float(hit.get("damage",0))
			var label:=Label3D.new(); label.text="%s / %.1f DAMAGE"%[species.to_upper(),damage]
			label.font_size=28; label.pixel_size=.007; label.position=body.position+Vector3.UP*1.9
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.modulate=Color("ff4545")
			label.no_depth_test=true; content.add_child(label)
		helper.queue_free()
	add_context()
	for path in paths:
		if not path.has("blast"): continue
		var blast_center: Vector3=path.blast.center-origin
		var blast_radius: float=path.blast.radius
		var rings: Array=[]
		for plane in 3:
			for i in 64:
				var tips: Array=[]
				for angle in [i*TAU/64,(i+1)*TAU/64]:
					var p:=Vector3(cos(angle),0,sin(angle)) if plane==0 else Vector3(cos(angle),sin(angle),0) if plane==1 else Vector3(0,cos(angle),sin(angle))
					tips.append(blast_center+p*blast_radius)
				rings.append(tips)
		var shell:=line_mesh(rings,mat(Color(1,.38,.12,.65))); shell.name="BlastRadius"

	for report in entry.reports:
		if not report.has("target_transform") or float(report.get("damage",0))<=0: continue
		var impact: Vector3=report.target_transform*report.entry-origin
		for i in 12:
			var drop:=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=.015; sphere.height=.03; sphere.radial_segments=6; sphere.rings=3
			drop.mesh=sphere; drop.material_override=mat(Color("bc344c")); content.add_child(drop)
			drop.position=impact; drop.set_meta("impact",impact); drop.set_meta("drift",Vector3(sin(i*2.4),.2+cos(i*1.7)*.7,cos(i*2.4))*.4); blood.append(drop)
	camera.make_current()
	outcome=str(paths.back().get("outcome","SHOT COMPLETE")) if entry.reports.is_empty() else str(entry.caption)
	update_frame(); queue_redraw()
static func sample(path: Dictionary,fraction: float,total_time: float) -> Vector3:
	var points: PackedVector3Array=path.points
	var times: PackedFloat32Array=path.get("times",PackedFloat32Array())
	if points.size()==1: return points[0]
	if times.size()==points.size() and times[-1]>.000001:
		var at:=fraction*total_time
		for i in range(1,times.size()):
			if times[i]>=at: return points[i-1].lerp(points[i],clampf((at-times[i-1])/maxf(.000001,times[i]-times[i-1]),0,1))
		return points[-1]
	var cursor:=clampf(fraction,0,1)*(points.size()-1)
	var index:=mini(points.size()-2,int(cursor))
	return points[index].lerp(points[index+1],cursor-index)
func tick(delta: float,active: bool) -> void:
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active: return
	if ready_to_play: elapsed=minf(LENGTH,elapsed+delta)
	update_frame(); queue_redraw()
func update_frame() -> void:
	if paths.is_empty(): return
	var fraction:=clampf(elapsed/FLIGHT_LENGTH,0,1) if ready_to_play else 0.0
	var mesh:=ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in paths.size():
		var path: Dictionary=paths[i]; var point:=sample(path,fraction,source_duration)-origin
		markers[i].position=point
		var past:=PackedVector3Array([path.points[0]-origin])
		var times: PackedFloat32Array=path.get("times",PackedFloat32Array())
		for j in range(1,path.points.size()):
			var passed: bool=times[j]<=fraction*source_duration if times.size()==path.points.size() and source_duration>0 else float(j)/(path.points.size()-1)<=fraction
			if passed: past.append(path.points[j]-origin)
		past.append(point)
		for j in range(1,past.size()): mesh.surface_add_vertex(past[j-1]); mesh.surface_add_vertex(past[j])
	trail.mesh=mesh; mesh.surface_end()
	for drop in blood:
		var impact: Vector3=drop.get_meta("impact")
		var age:=maxf(0,elapsed-FLIGHT_LENGTH*clampf(impact.length()/maxf(main_length,.01),0,1))
		drop.visible=age>0; drop.position=impact+Vector3(drop.get_meta("drift"))*age+Vector3.DOWN*age*age*.3
	var focus: Vector3=markers[0].position
	var side:=heading.cross(Vector3.UP).normalized()
	if side.length_squared()<.1: side=Vector3.RIGHT
	var distance:=lerpf(clampf(main_length*.10,3,9),2.5,smoothstep(.72,1,fraction))
	if missed and not unhit_positions.is_empty():
		# Hold the nearest missed animal and its closest approach in frame.
		# Following a bullet all the way to range limit otherwise loses that context.
		var animal: Vector3=unhit_positions[0]
		var nearest:=Vector3.ZERO; var best:=INF
		for i in range(1,paths[0].points.size()):
			var point:=Geometry3D.get_closest_point_to_segment(animal,paths[0].points[i-1]-origin,paths[0].points[i]-origin)
			if point.distance_squared_to(animal)<best: nearest=point; best=point.distance_squared_to(animal)
		focus=animal.lerp(nearest,.5); distance=clampf(sqrt(best)*1.5+4,5,16)
	if paths[0].has("blast"):
		focus=paths[0].blast.center-origin
		distance=maxf(4,float(paths[0].blast.radius)*2.7)
	camera.position=focus+side*distance+Vector3.UP*distance*.48-heading*distance*.38
	camera.look_at(focus+heading*.4,Vector3.UP)
	if fraction>=1:
		for marker in markers: marker.scale=Vector3.ONE*(1.0+sin(elapsed*12)*.3)
func _draw() -> void:
	var box:=StyleBoxFlat.new(); box.bg_color=Color(.015,.028,.047,.96); box.border_color=Color("4c7e91"); box.set_border_width_all(1); box.set_corner_radius_all(5)
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(12,24),"SHOT %03d / SLOW MOTION"%maxi(serial,0),HORIZONTAL_ALIGNMENT_LEFT,296,15,Color("eac28b"))
	draw_string(font,Vector2(12,41),"Recorded trajectory / 4-second replay",HORIZONTAL_ALIGNMENT_LEFT,296,11,Color("91acb9"))
	draw_rect(Rect2(12,293,296,3),Color("324754"))
	draw_rect(Rect2(12,293,296*elapsed/LENGTH,3),Color("ffbf69"))
	var progress: String="%.1f / 4.0 s  |  %.1f m  |  %d projectile%s"%[elapsed,main_length,paths.size(),"s" if paths.size()!=1 else ""] if ready_to_play else "Recording flight..."
	draw_string(font,Vector2(12,315),progress,HORIZONTAL_ALIGNMENT_LEFT,296,11,Color("edbd75"))
	draw_string(font,Vector2(12,334),outcome,HORIZONTAL_ALIGNMENT_LEFT,296,10,Color("cbd9e0"))

func add_context() -> void:
	var game=get_parent().get("game")
	if not is_instance_valid(game) or not is_instance_valid(game.world): return
	var ghost:=mat(Color(.12,.55,.68,.10))
	var count:=0
	for source in game.world.find_children("*","MeshInstance3D",true,false):
		if source.mesh==null or not source.is_visible_in_tree(): continue
		var bounds: AABB=source.global_transform*source.get_aabb()
		var end: Vector3=paths[0].points[-1]
		if bounds.get_center().distance_to(end)>bounds.size.length()*.5+18: continue
		var copy:=MeshInstance3D.new(); copy.mesh=source.mesh; copy.material_override=ghost
		copy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		content.add_child(copy); copy.transform=source.global_transform; copy.position-=origin
		count+=1
		if count>=32: break
