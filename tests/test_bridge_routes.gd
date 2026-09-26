extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world=load("res://scripts/island_world.gd").new(); root.add_child(world)
	var failures:=0; var checks:=0
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
	print("BRIDGE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
