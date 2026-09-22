extends Node3D
var game: Node3D
static var foliage_cells: Dictionary={}
var points: Array[Vector3]=[]
const TITLES: Array[String]=["MAIN RED CABIN","NORTH WATCHTOWER","EAST WATCHTOWER","SOUTH WATCHTOWER","WEST WATCHTOWER"]
var opened:=false
var selected:=0
var panel: Label
func _ready() -> void:
	points.append(game.world.spawn_position)
	index_foliage()
	var nav=game.world.nav
	for direction in [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]:
		var best:=-INF; var chosen: Vector3=game.world.exterior_rally_point
		for cell in nav.reachable:
			var p: Vector3=nav.point(cell)
			var score: float=p.dot(direction)-absf(p.dot(direction.rotated(Vector3.UP,PI/2)))*.10
			if score<=best or p.y<.4 or game.world.is_safe_position(p): continue
			var tower_center:=p+Vector3(3,0,0)
			var covered:=false
			for x in [-2.0,0.0,2.0]:
				for z in [-2.0,0.0,2.0]:
					if foliage_cells.has(Vector2i(floori((tower_center.x+x)/2),floori((tower_center.z+z)/2))): covered=true
			if covered: continue
			var roomy:=true
			for offset in [Vector3(-2,0,0),Vector3(0,0,-2),Vector3(0,0,2),Vector3(5,0,-2),Vector3(5,0,2),Vector3(3,0,0)]:
				var n: int=nav.at(p.x+offset.x,p.z+offset.z)
				if not nav.valid(n) or absf(nav.point(n).y-p.y)>1: roomy=false; break
			if not roomy: continue
			if score>best: best=score; chosen=p
		points.append(chosen); tower(chosen,TITLES[points.size()-1])
	var sign:=Label3D.new(); sign.text="FAST TRAVEL / E or Y"; sign.font_size=28; sign.pixel_size=.003; sign.position=points[0]+Vector3(0,1.4,0); sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED; add_child(sign)
	var layer:=CanvasLayer.new(); layer.layer=12; add_child(layer)
	panel=Label.new(); panel.position=Vector2(425,60); panel.size=Vector2(430,235); panel.add_theme_font_size_override("font_size",19)
	var style:=StyleBoxFlat.new(); style.bg_color=Color(.035,.045,.05,.96); style.content_margin_left=20; style.content_margin_top=15; style.content_margin_bottom=15; style.content_margin_right=20
	panel.add_theme_stylebox_override("normal",style); layer.add_child(panel); panel.hide()
func piece(parent: Node3D,p: Vector3,size: Vector3,color: Color) -> void:
	var node:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; node.mesh=mesh; node.position=p
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=.95; node.material_override=mat; parent.add_child(node)
func tower(p: Vector3,title: String) -> void:
	var root:=Node3D.new(); root.name=title; root.position=p+Vector3(3,0,0); add_child(root)
	for x in [-1.3,1.3]:
		for z in [-1.3,1.3]: piece(root,Vector3(x,3.2,z),Vector3(.25,6.4,.25),Color("51483c"))
	piece(root,Vector3(0,6,0),Vector3(3.2,.22,3.2),Color("63513c"))
	piece(root,Vector3(0,8,0),Vector3(3.6,.24,3.6),Color("3d413b"))
	for side in [-1,1]:
		piece(root,Vector3(side*1.45,6.65,0),Vector3(.16,.85,3),Color("6c5944"))
		piece(root,Vector3(0,6.65,side*1.45),Vector3(3,.85,.16),Color("6c5944"))
		var brace:=Node3D.new(); brace.rotation.z=side*.36; root.add_child(brace); piece(brace,Vector3(0,2.8,0),Vector3(.2,5.8,.2),Color("51483c"))
	var label:=Label3D.new(); label.text=title+"\nFAST TRAVEL / E or Y"; label.font_size=36; label.pixel_size=.005; label.position=p+Vector3.UP*1.7; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; add_child(label)
	# No ladder, walkable deck samples or climb interaction is created.
func nearby(p: Vector3) -> int:
	for i in points.size():
		if p.distance_to(points[i])<2.1: return i
	return -1
func open_menu() -> void:
	if nearby(game.player.position)<0 or game.is_struggling() or game.rituals.channeling(): return
	selected=(nearby(game.player.position)+1)%points.size(); opened=true; refresh()
func close_menu() -> void: opened=false; panel.hide()
func refresh() -> void:
	var lines: PackedStringArray=["FAST TRAVEL"]
	for i in points.size(): lines.append(("> " if i==selected else "   ")+TITLES[i])
	lines.append("↑ ↓ / D-pad   Enter / A   Esc / B")
	panel.text="\n".join(lines); panel.show()
func input_event(event: InputEvent) -> void:
	var step:=0; var accept:=false; var cancel:=false
	if event is InputEventKey and event.pressed and not event.echo and game.controller_device<0:
		step=int(event.physical_keycode==KEY_DOWN)-int(event.physical_keycode==KEY_UP); accept=event.physical_keycode==KEY_ENTER; cancel=event.physical_keycode in [KEY_ESCAPE,KEY_E]
	if event is InputEventJoypadButton and event.pressed and event.device==game.controller_device:
		step=int(event.button_index==JOY_BUTTON_DPAD_DOWN)-int(event.button_index==JOY_BUTTON_DPAD_UP); accept=event.button_index==JOY_BUTTON_A; cancel=event.button_index in [JOY_BUTTON_B,JOY_BUTTON_Y]
	if cancel: close_menu(); return
	selected=posmod(selected+step,points.size()); refresh()
	if accept:
		if game.coop.client(): game.coop.send_to(1,"travel_request",[selected])
		else: travel(1,selected)
		close_menu()
func travel(peer: int,destination: int) -> bool:
	if game.coop.client() or destination<0 or destination>=points.size() or not game.is_playing(): return false
	var hunter: Node3D=game.player if peer==1 else game.coop.avatars.get(peer)
	if not is_instance_valid(hunter) or nearby(hunter.position)<0: return false
	if (game.health<=0 or game.is_struggling()) if peer==1 else (hunter.health<=0 or hunter.mauling!=0): return false
	if game.rituals.tasks.has(peer): return false
	if peer==1: arrived(destination)
	else:
		hunter.position=points[destination]; game.coop.send_to(peer,"travel_arrived",[destination])
	return true
func arrived(destination: int) -> void:
	if destination<0 or destination>=points.size(): return
	var stamina: float=game.player.stamina
	game.player.reset_at(points[destination]); game.player.stamina=stamina; game.fire_cooldown=.5; close_menu()
	game.show_notice("Arrived at "+TITLES[destination],3)
func _process(_delta: float) -> void:
	if opened and (not game.is_playing() or game.health<=0 or game.is_struggling() or nearby(game.player.position)<0): close_menu()

func index_foliage() -> void:
	if not foliage_cells.is_empty() or not is_instance_valid(game.world.surroundings): return
	for node in game.world.surroundings.find_children("*","MeshInstance3D",true,false):
		if not str(node.name).begins_with("context_foliage"): continue
		var faces: PackedVector3Array=node.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a: Vector3=node.global_transform*faces[i]; var b: Vector3=node.global_transform*faces[i+1]; var c: Vector3=node.global_transform*faces[i+2]
			for x in range(floori(minf(a.x,minf(b.x,c.x))/2),floori(maxf(a.x,maxf(b.x,c.x))/2)+1):
				for z in range(floori(minf(a.z,minf(b.z,c.z))/2),floori(maxf(a.z,maxf(b.z,c.z))/2)+1): foliage_cells[Vector2i(x,z)]=true
