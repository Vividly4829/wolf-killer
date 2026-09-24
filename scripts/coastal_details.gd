extends Node3D
## Photo-informed detailing, separate from the preserved original island asset.
const Reference=preload("res://scripts/coastal_reference.gd")
var world: Node3D
var batch: SurfaceTool
var box_mesh:=BoxMesh.new()
var detail_count:=0
const WALLS=[Color("303b37"),Color("303b3a"),Color("253332"),Color("344039"),Color("555e57"),Color("703c32")]
const EAVES=[2.7,4.2,2.45,2.45,2.5,2.45]
func _ready() -> void:
	name="PhotoCoastalDetails"
	batch=SurfaceTool.new(); batch.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in world.exploration_data.houses.size(): facade(world.exploration_data.houses[index],index)
	for dock in Reference.DOCKS: wharf(dock)
	var node:=MeshInstance3D.new(); node.name="BatchedCladdingWindowsWharves"; node.mesh=batch.commit()
	var material:=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.roughness=.88; material.cull_mode=BaseMaterial3D.CULL_DISABLED; node.material_override=material; add_child(node)

func box(p: Vector3,size: Vector3,color: Color,yaw: float=0) -> void:
	var arrays:=box_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	# Default BoxMesh is 1x1x1. Bake details into one vertex-coloured mesh.
	for id in arrays[Mesh.ARRAY_INDEX]:
		batch.set_color(color); batch.set_normal(normals[id].rotated(Vector3.UP,yaw))
		batch.add_vertex(p+(vertices[id]*size).rotated(Vector3.UP,yaw))
	detail_count+=1

func facade(house: Dictionary,index: int) -> void:
	var points:=PackedVector2Array()
	for p in house.polygon: points.append(Vector2(p[0],p[1]))
	var center:=Vector2(house.center[0],house.center[1])
	var door:=Vector2(house.door[0],house.door[2])
	var floor_y: float=house.floor
	var height: float=EAVES[index]
	var paint: Color=WALLS[index]
	for i in points.size():
		var a:=points[i]; var b:=points[(i+1)%points.size()]; var tangent: Vector2=(b-a).normalized()
		var normal:=Vector2(tangent.y,-tangent.x)
		if normal.dot((a+b)*.5-center)<0: normal=-normal
		var length:=a.distance_to(b); var yaw: float=-atan2(tangent.y,tangent.x)
		var door_on_edge: bool=Geometry2D.get_closest_point_to_segment(door,a,b).distance_to(door)<.2
		# Horizontal weatherboard rows with visible lap edges and a clear doorway.
		for row in ceili(height/.18):
			var y: float=floor_y+.09+row*.18
			var pieces: Array=[Vector2(0,length)]
			if door_on_edge and y<floor_y+2.35:
				var along: float=(door-a).dot(tangent)
				pieces=[Vector2(0,maxf(0,along-.88)),Vector2(minf(length,along+.88),length)]
			for span: Vector2 in pieces:
				if span.y-span.x<.05: continue
				var mid:=a+tangent*(span.x+span.y)*.5+normal*.06
				box(Vector3(mid.x,y,mid.y),Vector3(span.y-span.x,.167,.085),paint.lightened(.035 if row%3==0 else 0),yaw)
		var corner:=a+normal*.10
		box(Vector3(corner.x,floor_y+height*.5,corner.y),Vector3(.11,height,.12),Color("adae9e"),yaw)
		var mid: Vector2=(a+b)*.5+normal*.13
		box(Vector3(mid.x,floor_y+height,mid.y),Vector3(length+.15,.15,.16),Color("aaad9c"),yaw)
		if length<2.8: continue
		for fraction in ([.25,.72] if length>6 else [.5]):
			var p: Vector2=a.lerp(b,fraction)+normal*.14
			if door_on_edge and p.distance_to(door)<1.45: continue
			window(Vector3(p.x,floor_y+1.42,p.y),yaw,index==4)
			if index==1: window(Vector3(p.x,floor_y+3.18,p.y),yaw,false)
	# Door surround, canopy and lintel follow the existing traversable portal.
	var n:=Vector2(house.normal[0],house.normal[1]); var t:=Vector2(n.y,-n.x)
	var angle: float=-atan2(t.y,t.x)
	for side in [-1,1]:
		var p: Vector2=door+t*side*.91+n*.15
		box(Vector3(p.x,floor_y+1.15,p.y),Vector3(.10,2.3,.16),Color("b6b7a6"),angle)
	box(Vector3(door.x+n.x*.3,floor_y+2.35,door.y+n.y*.3),Vector3(2.05,.13,.75),Color("535b54"),angle)
	if index==0:
		# Slender pale deck rails and blue-grey glazed panels on the rocky cabin.
		for side in [-1,1]:
			for depth in [.6,1.8]:
				var p: Vector2=door+t*side*1.7+n*depth
				box(Vector3(p.x,floor_y+.5,p.y),Vector3(.065,1,.065),Color("9caaa6"),angle)
			var rail: Vector2=door+t*side*1.7+n*1.2
			box(Vector3(rail.x,floor_y+1,rail.y),Vector3(.07,.07,1.3),Color("b9c5ba"),angle)
			box(Vector3(rail.x,floor_y+.52,rail.y),Vector3(.025,.78,1.08),Color("6f9298"),angle)
	if index==1:
		# The southern photo's tall, open gable porch, with weathered pale posts.
		for side in [-1,1]:
			var p: Vector2=door+t*side*1.7+n*1.6
			box(Vector3(p.x,floor_y+2.05,p.y),Vector3(.17,4.1,.17),Color("adae98"),angle)
		box(Vector3(door.x+n.x*1.1,floor_y+2.65,door.y+n.y*1.1),Vector3(3.55,.16,1.3),Color("6f6754"),angle)
	if index==4: life_ring(Vector3(door.x+n.x*.23,floor_y+1.2,door.y+n.y*.23)+Vector3(t.x,0,t.y)*1.35,angle)

func window(p: Vector3,yaw: float,large: bool) -> void:
	var w:=1.28 if large else .9; var h:=1.35 if large else 1.02
	box(p,Vector3(w,.0+h,.04),Color("405961"),yaw)
	for x in [-w*.5,0,w*.5]: box(p+Vector3(x,0,.045).rotated(Vector3.UP,yaw),Vector3(.055,h+.10,.07),Color("c3c5b5"),yaw)
	for y in [-h*.5,0,h*.5]: box(p+Vector3(0,y,.045).rotated(Vector3.UP,yaw),Vector3(w+.1,.055,.07),Color("c3c5b5"),yaw)

func life_ring(p: Vector3,yaw: float) -> void:
	for i in 20:
		var a:=i*TAU/20
		box(p+Vector3(cos(a)*.27,sin(a)*.27,0).rotated(Vector3.UP,yaw),Vector3(.12,.12,.10),Color("c45541") if i%5<2 else Color("e0ded0"),yaw)

func wharf(dock: Dictionary) -> void:
	var polygon:=PackedVector2Array()
	for p in dock.polygon: polygon.append(Vector2(p[0],p[1]))
	var ymin:=INF; var ymax:=-INF; var xmin:=INF; var xmax:=-INF
	for p in polygon: xmin=minf(xmin,p.x); xmax=maxf(xmax,p.x); ymin=minf(ymin,p.y); ymax=maxf(ymax,p.y)
	# Individual planks clipped to the mapped quay footprint.
	for z in range(floori(ymin/.22),ceili(ymax/.22)):
		for x in range(floori(xmin/.6),ceili(xmax/.6)):
			var p:=Vector2(x*.6+.3,z*.22+.11)
			if Geometry2D.is_point_in_polygon(p,polygon): box(Vector3(p.x,dock.height+.025,p.y),Vector3(.59,.06,.205),Color("93866b").darkened(.05*posmod(x+z,3)))
	for i in polygon.size()-1:
		var a:=polygon[i]; var b:=polygon[i+1]; var length:=a.distance_to(b)
		for j in maxi(1,ceili(length/.21)):
			var p:=a.lerp(b,float(j)/maxi(1,ceili(length/.21)))
			box(Vector3(p.x,dock.height-.5,p.y),Vector3(.13,.95,.13),Color("8b9282"))
	if dock.floating:
		for z in [ymin+.6,ymax-.6]:
			for x in [xmin+.35,xmax-.35]: barrel(Vector3(x,.0,z),true)
	else:
		barrel(Vector3(xmax-.8,dock.height+.42,(ymin+ymax)*.5),false)
		life_ring(Vector3(xmax-.2,dock.height+.8,(ymin+ymax)*.5),PI/2)
func barrel(p: Vector3,floating: bool) -> void:
	var cylinder:=MeshInstance3D.new(); var shape:=CylinderMesh.new(); shape.top_radius=.3; shape.bottom_radius=.3; shape.height=.86; shape.radial_segments=12; cylinder.mesh=shape
	cylinder.position=p; if floating: cylinder.rotation.z=PI/2
	var mat:=StandardMaterial3D.new(); mat.albedo_color=Color("245faa"); mat.roughness=.65; cylinder.material_override=mat; add_child(cylinder)

static func refine_mesh(mesh: ArrayMesh,node_name: String,houses: Array) -> ArrayMesh:
	# Raise only the southern neighbour's upper storey; flatten the photographed
	# waterside shelter roof. The original island is never passed to this method.
	if node_name not in ["context_timber","context_rock"]: return mesh
	var result:=ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		for index in houses.size():
			var house: Dictionary=houses[index]; var polygon:=PackedVector2Array()
			for p in house.polygon: polygon.append(Vector2(p[0],p[1]))
			var expanded:=Geometry2D.offset_polygon(polygon,.45)
			if expanded.is_empty(): continue
			for v in vertices.size():
				var point:=vertices[v]
				if point.y<house.floor+.3 or not Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),expanded[0]): continue
				if v<colors.size():
					colors[v]=WALLS[index] if node_name=="context_timber" else (Color("80513b") if index in [1,5] else Color("4a5150"))
					colors[v].a=.75
				if index==1:
					point.y+=1.9*clampf((point.y-house.floor)/2.3,0,1)
				elif index==3: point.y+=.30*clampf((point.y-house.floor)/2.15,0,1)
				elif index==4: point.y=house.floor+minf(2.55,(point.y-house.floor)*2.5/2.1)
				elif index==5: point.y+=.85*clampf((point.y-house.floor)/1.6,0,1)
				vertices[v]=point
		arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_COLOR]=colors
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(surface,mesh.surface_get_material(surface))
	return result

