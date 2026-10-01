extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world=load("res://scripts/island_world.gd").new(); root.add_child(world)
	await physics_frame; await physics_frame
	var failures:=0; var checks:=0; var obstacles:=0
	for bridge in world.exploration_data.bridges:
		var a:=Vector3(bridge.a[0],bridge.a[1],bridge.a[2])
		var b:=Vector3(bridge.b[0],bridge.b[1],bridge.b[2])
		var side:Vector3=(b-a).cross(Vector3.UP).normalized()
		for offset in [-1.15,0.0,1.15]:
			for reverse in [false,true]:
				var start:Vector3=(b if reverse else a)+side*offset
				var end:Vector3=(a if reverse else b)+side*offset
				var p:=start; var max_error:=0.0
				var steps:=ceili(a.distance_to(b)/.10)
				for i in steps:
					var target:=start.lerp(end,float(i+1)/steps)
					var step:=target-p; step.y=0; step=step.limit_length(.15)
					p=world.nav.move_position(p,step.x,step.z)
					max_error=maxf(max_error,absf(p.y-target.y))
				checks+=1
				if p.distance_to(end)>.55 or max_error>.45:
					failures+=1; print("BRIDGE_FAIL ",bridge.name," offset ",offset," reverse ",reverse," remaining ",p.distance_to(end)," height_error ",max_error)
		for offset in [-1.15,0.0,1.15]:
			for height in [.8,1.6]:
				var ray:=PhysicsRayQueryParameters3D.create(a+side*offset+Vector3.UP*height,b+side*offset+Vector3.UP*height,1)
				var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty():
					obstacles+=1; print("BRIDGE_OBSTACLE ",bridge.name," ",hit.position," ",hit.collider.get_path()," parent=",hit.collider.get_parent().get_class()," children=",hit.collider.get_children())
	print("BRIDGE_OBSTACLES ",obstacles)
	failures+=obstacles
	print("BRIDGE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
