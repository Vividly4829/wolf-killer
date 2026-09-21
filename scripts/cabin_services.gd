extends Node3D
## Supply access in every enterable building, with a separate coffee interaction.
var world: Node3D
var cabins: Array[Dictionary] = []
var store_positions: Array[Vector3] = []
func _ready() -> void:
	store_positions.append(world.shop_position)
	for building in world.world_data.buildings:
		var outline:=PackedVector2Array()
		for point in building.outline: outline.append(Vector2(point[0],point[2]))
		var point:=Vector3.ZERO
		for room in world.world_data.rooms:
			var p:=Vector3(room.navigationPoint[0],room.navigationPoint[1],room.navigationPoint[2])
			if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),outline): point=p; break
		if point==Vector3.ZERO: continue
		var cup:=Vector3(-.58,4.514,2.464) if building.name=="Cabin" else point+Vector3(0,.70,0)
		add_cabin(str(building.name),outline,float(building.floorHeight),cup,building.name=="Cabin",building.name!="Cabin")
	for house in world.exploration_data.houses:
		var outline:=PackedVector2Array()
		for p in house.polygon: outline.append(Vector2(p[0],p[1]))
		# Use the existing interior supply table, beside the weapon pickup.
		add_cabin(str(house.id),outline,float(house.floor),Vector3(house.center[0]+.30,house.floor+.47,house.center[1]),false,false)

func add_cabin(id: String,outline: PackedVector2Array,floor_y: float,cup: Vector3,existing: bool,table: bool) -> void:
	cabins.append({"id":id,"outline":outline,"floor":floor_y,"cup":cup})
	store_positions.append(Vector3(cup.x,floor_y,cup.z))
	if not existing: world.get_node("CabinComfort").add_coffee(cup)
	if table:
		world._bed_box(self,"Coffee shelf",Vector3(.7,.08,.55),cup-Vector3.UP*.10,world._solid_material(Color("765039")))
	var sign:=Label3D.new()
	sign.text="SUPPLIES / COFFEE"
	sign.font_size=28; sign.pixel_size=.004
	sign.position=cup+Vector3.UP*.55
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate=Color("edcf97")
	add_child(sign)

func inside(p: Vector3,cabin: Dictionary) -> bool:
	return absf(p.y-float(cabin.floor))<1.7 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),cabin.outline)
func near_store(p: Vector3) -> bool:
	if p.distance_to(world.shop_position)<=3.2: return true
	for cabin in cabins:
		if inside(p,cabin): return true
	return false
func nearest_store(p: Vector3) -> Vector3:
	var best: Vector3=world.shop_position
	for point in store_positions:
		if p.distance_squared_to(point)<p.distance_squared_to(best): best=point
	return best
func nearby_coffee(p: Vector3) -> int:
	for i in cabins.size():
		var cabin: Dictionary=cabins[i]
		if not inside(p,cabin) or Vector2(p.x-cabin.cup.x,p.z-cabin.cup.z).length()>1.6: continue
		var sight:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.4,cabin.cup+Vector3.UP*.12,1)
		if get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): return i
	return -1
