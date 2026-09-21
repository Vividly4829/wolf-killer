extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func walk(nav, a: Vector3, b: Vector3) -> bool:
	var p := a
	for step in ceili(a.distance_to(b)/.08)+100:
		var delta := Vector2(b.x-p.x,b.z-p.z).limit_length(.08)
		if delta.length()<.03: return true
		p = nav.move_position(p,delta.x,delta.y)
	print("  Stopped at ",p," heading to ",b)
	return false
func run() -> void:
	var world := IslandWorld.new()
	root.add_child(world)
	await process_frame
	for nav in [world.nav,world.wolf_nav]:
		var label := "player" if nav==world.nav else "wolf"
		for route in world.exploration_data.bridges:
			var a := Vector3(route.a[0],route.a[1],route.a[2])
			var b := Vector3(route.b[0],route.b[1],route.b[2])
			check(nav.distances[nav.at(a.x,a.z)]>=0 and nav.distances[nav.at(b.x,b.z)]>=0,label+" reachable: "+route.name)
			check(walk(nav,a,b) and walk(nav,b,a),label+" two-way crossing: "+route.name)
			var side := (b-a).cross(Vector3.UP).normalized()*.6
			for offset in [side,-side]:
				check(walk(nav,a+offset,b+offset) and walk(nav,b+offset,a+offset),label+" off-center crossing: "+route.name)
			# Step off each landing onto dry ground, rather than only proving
			# that the graph connects two points on the deck.
			var direction := Vector3(b.x-a.x,0,b.z-a.z).normalized()
			if "footbridge" in route.name:
				check(walk(nav,a-direction*2,a) and walk(nav,b,b+direction*2),label+" shore approaches: "+route.name)
		for house in world.exploration_data.houses:
			var i: int = nav.at(house.center[0],house.center[1])
			check(nav.valid(i) and nav.distances[i]>=0,label+" house: "+str(house.id))
	var nav = world.nav
	var visited := {}
	var components := []
	for i in nav.size:
		if not nav.valid(i) or nav.distances[i]>=0 or visited.has(i): continue
		var queue: Array[int] = [i]
		visited[i] = true
		var head := 0
		var coords := []
		while head<queue.size():
			var p: Vector3 = nav.point(queue[head])
			coords.append([p.x,p.y,p.z])
			for j in nav.adjacent(queue[head]):
				if not visited.has(j):
					visited[j] = true
					queue.append(j)
			head += 1
		components.append(coords)
		if queue.size()>=8: print("UNREACHABLE nodes=",queue.size()," sample=",nav.point(i))
	check(components.all(func(c): return c.size()<8),"No disconnected walkable land patches")
	FileAccess.open("res://qa/map-components.json",FileAccess.WRITE).store_string(JSON.stringify(components))
	if "--capture" in OS.get_cmdline_user_args():
		world.weather.hour = 12
		world.weather.apply()
		root.size = Vector2i(1280,720)
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.current = true
		for route in world.exploration_data.bridges:
			if not "footbridge" in route.name: continue
			var a := Vector3(route.a[0],route.a[1],route.a[2])
			var b := Vector3(route.b[0],route.b[1],route.b[2])
			var side := (b-a).cross(Vector3.UP).normalized()
			camera.position = (a+b)*.5+side*30+Vector3.UP*22
			camera.look_at((a+b)*.5)
			await create_timer(.3).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/"+route.name.to_lower().replace(" ","-")+".png")
		camera.queue_free()
	print("MAP_CONNECTIONS failures=",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
