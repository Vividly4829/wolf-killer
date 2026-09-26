extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world=load("res://scripts/island_world.gd").new(); root.add_child(world)
	var nav=world.nav
	var checks:=0; var failures:=0
	# Exercise connected sloping terrain, distributed across the coastal graph.
	for i in range(nav.base_size,nav.size,41):
		var a:Vector3=nav.point(i)
		if nav.deck_at(a.x,a.z)>=0: continue
		for j in nav.adjacent(i):
			var b:Vector3=nav.point(j)
			if absf(a.y-b.y)<.10 or absf(a.y-b.y)>.6 or a.distance_to(b)>1.8: continue
			if not nav.line_clear(a.x,a.z,b.x,b.z): continue
			var pos:=a
			for step in 30:
				var d:=b-pos; d.y=0; d=d.limit_length(.08)
				pos=nav.move_position(pos,d.x,d.z)
			checks+=1
			if Vector2(pos.x-b.x,pos.z-b.z).length()>.15 or not pos.is_finite(): failures+=1
			break
	print("HILLS_RESULT checks=",checks," failures=",failures)
	quit(1 if failures>0 or checks<100 else 0)
