extends Node3D

const Builder = preload("res://scripts/weapon_model_builder.gd")
var muzzle_position := Vector3.ZERO
var model_meta: Dictionary = {}
var _parts: Node3D
var _hands: Node3D
var _effects: Node3D
var _actions: Dictionary = {}
var _index: int = 0
var _action: String = "muzzle"
var _loaded: bool = true
var _secondary: bool = false
var _inspection: bool = false
var _reload_active: bool = false
var _flash_mesh: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_time: float = 0.0
var _cycle_left: float = 0.0
var _primary_muzzle := Vector3.ZERO
var _secondary_muzzle := Vector3.ZERO
var dual_hand:=0
var _fired_hand:=0
var _offhand: Node3D
var _offhand_rest := Vector3.ZERO

func build(index: int) -> void:
	_index=clampi(index,0,preload("res://scripts/weapon_catalog.gd").WEAPONS.size()-1)
	for old: Node3D in [_parts,_hands,_effects]:
		if is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	var builder:=Builder.new()
	model_meta=builder.build(_index)
	_parts=model_meta.root
	_actions=model_meta.actions
	_action=str(model_meta.action)
	_primary_muzzle=model_meta.muzzle
	_secondary_muzzle=model_meta.secondary_muzzle
	add_child(_parts)
	_secondary=false
	muzzle_position=_primary_muzzle
	_flash_time=0.0
	_cycle_left=0.0
	_reload_active=false
	_create_hands()
	_create_flash()
	set_inspection_mode(_inspection)
	set_loaded(_loaded)

func set_inspection_mode(enabled: bool) -> void:
	_inspection=enabled
	if _hands: _hands.visible=not enabled
	if _effects: _effects.visible=not enabled
	if _flash_light and enabled: _flash_light.light_energy=0.0

func set_loaded(loaded: bool) -> void:
	_loaded=loaded
	if _index==3 and _actions.has("bolt"):
		_actions.bolt.visible=loaded and not _reload_active
		if not _reload_active and _cycle_left<=0.0: _set_string(1.0 if loaded else .05)

func set_secondary(enabled: bool) -> void:
	if _index in [30,31,32]: return
	_secondary=enabled and _index==9
	muzzle_position=_secondary_muzzle if _secondary else _primary_muzzle
	if _flash_mesh: _flash_mesh.position=muzzle_position+Vector3.FORWARD*.035
	if _flash_light: _flash_light.position=muzzle_position
	_set_rotation("selector",0,-.55 if _secondary else 0.)

func set_dual_ammo(loaded: int) -> void:
	if _index not in [30,31,32]: return
	dual_hand=(int(preload("res://scripts/weapon_catalog.gd").WEAPONS[_index].magazine)-loaded)%2
	muzzle_position=_secondary_muzzle if dual_hand==1 else _primary_muzzle
	model_meta.sight.x=-.24 if dual_hand==1 else .16

func get_model_bounds() -> AABB:
	return _bounds(_parts,Transform3D.IDENTITY)

func _bounds(parent: Node3D, transform: Transform3D) -> AABB:
	var bounds:=AABB()
	var found:=false
	for child: Node in parent.get_children():
		if not child is Node3D: continue
		var node:=child as Node3D
		if not node.visible: continue
		var combined:=transform*node.transform
		var box:=combined*(node as MeshInstance3D).get_aabb() if node is MeshInstance3D else _bounds(node,combined)
		if box.size.length_squared()>0.0:
			bounds=bounds.merge(box) if found else box
			found=true
	return bounds

func _skin(color: String) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(color)
	material.roughness=.90
	return material

func _hand_piece(parent: Node3D,a: Vector3,b: Vector3,radius: float,material: Material,base_radius: float=-1.0) -> void:
	var mesh:=MeshInstance3D.new()
	var shape:=CylinderMesh.new()
	shape.top_radius=radius
	shape.bottom_radius=radius if base_radius<0 else base_radius
	shape.height=a.distance_to(b)
	shape.radial_segments=16
	mesh.mesh=shape
	mesh.material_override=material
	mesh.position=(a+b)*.5
	mesh.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)

func _hand(point: Vector3, left: bool) -> Node3D:
	var hand := Node3D.new()
	hand.position=point
	_hands.add_child(hand)
	var sculpt: Node3D=load("res://assets/adult_hand.glb").instantiate()
	hand.add_child(sculpt)
	for mesh in sculpt.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=mesh.get_active_material(0)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mirror := -1.0 if left else 1.0
	sculpt.scale.x=mirror
	if left: hand.rotation.z=PI/2
	var sleeve:=_skin("525a42")
	var cuff:=_skin("333c2e")
	_hand_piece(hand,Vector3(.032*mirror,-.082,.115),Vector3(.075*mirror,-.24,.29),.031,sleeve,.055)
	_hand_piece(hand,Vector3(.032*mirror,-.082,.105),Vector3(.038*mirror,-.100,.13),.034,cuff)
	return hand

func _create_hands() -> void:
	_hands=Node3D.new()
	_hands.name="Hands"
	add_child(_hands)
	var handgun:=_index in [4,6,7,8,9,10,11,12,27,28,30,31,32,33]
	var primary:=_hand(Vector3(0,-.01,-.1) if _index in [24,25] else Vector3(.016,-.050,.037),false)
	_offhand_rest=Vector3(-.035,-.057,-.38) if not handgun else Vector3(-.047,-.075,-.035)
	_offhand=_hand(_offhand_rest,true)
	if _index in [21,22,23]:
		# Grip the riser with the left hand; the drawing hand stays near the cheek.
		primary.position=Vector3(.05,-.06,.43)
		_offhand_rest=Vector3(-.01,-.055,.015)
		_offhand.position=_offhand_rest; _offhand.rotation.z=0
	if _index in [24,25]: _offhand.visible=false
	if _index in [30,31,32]:
		primary.position.x+=.16
		_offhand_rest=Vector3(-.256,-.050,.037)
		_offhand.position=_offhand_rest; _offhand.rotation.z=0
	if _index==10: _hands.scale=Vector3.ONE
	Builder.new()._merge_group(_hands)

func _reset_mechanisms() -> void:
	for key: String in _actions:
		var node: Node3D=_actions[key]
		node.transform=node.get_meta("rest",Transform3D.IDENTITY)
	if _actions.has("powder"): _actions.powder.visible=false
	if _actions.has("windlass"): _actions.windlass.visible=false
	if _actions.has("secondary_ramrod"): _actions.secondary_ramrod.visible=false
	_set_rotation("selector",0,-.55 if _secondary else 0.)

func _set_rotation(key: String,axis: int,angle: float) -> void:
	if _actions.has(key):
		var node: Node3D=_actions[key]
		var rotation: Vector3=node.rotation
		rotation[axis]=angle
		node.rotation=rotation

func _set_string(draw: float) -> void:
	if not _actions.has("string"): return
	var string_node: Node3D=_actions.string
	string_node.scale.z=draw
	string_node.position.z=-.5+.5*draw
	_actions.limbs.scale.z=.84+draw*.16

func animate_reload(progress: float, active: bool) -> void:
	_reload_active=active
	if _actions.is_empty(): return
	_reset_mechanisms()
	_offhand.position=_offhand_rest
	if not active:
		if _loaded:
			_set_rotation("hammer",0,1.05)
			_set_rotation("hammer_left",0,1.05)
		if _index==3:
			_actions.bolt.visible=_loaded
			_set_string(1.0 if _loaded else .05)
		return
	if _index==26: _set_rotation("crank",0,progress*TAU*16)
	var p:=clampf(progress,0.0,1.0)
	var open:=smoothstep(.02,.18,p)*(1.-smoothstep(.82,.98,p))
	var work:=sin(p*TAU*6.)*.5+.5
	if _index==9 and _secondary:
		# LeMat's central smoothbore is muzzle-loaded separately. The nine-shot
		# cylinder stays locked while the wad and shot charge are rammed home.
		var loading_rod: Node3D=_actions.secondary_ramrod
		loading_rod.visible=p>.30 and p<.88
		loading_rod.position=Vector3(0,_secondary_muzzle.y,_secondary_muzzle.z-.11-work*.13)
		_offhand.position=_offhand_rest.lerp(Vector3(.026,.030,_secondary_muzzle.z-.08-work*.13),open)
		_set_rotation("hammer",0,-.5*smoothstep(.85,.98,p))
		return
	match _action:
		"toggle":
			_set_rotation("toggle",0,-open*1.1)
			_actions.drum.position.y-=open*.12
		"bolt":
			_set_rotation("bolt",2,-open*1.1)
			_actions.bolt.position.z+=open*.14
			_offhand.position=_offhand_rest.lerp(Vector3(.09,.08,.04),open)
		"naval":
			for hand in 2:
				_set_rotation("naval_right" if hand==0 else "naval_left",0,-open*.45)
				_set_rotation("naval_hammer_%d"%hand,0,-.7*open)
		"muzzle":
			_actions.powder.visible=p<.27
			if p>=.40 and p<.82:
				_actions.ramrod.position=Vector3(0,_primary_muzzle.y,_primary_muzzle.z-.17-work*.22)
				_offhand.position=_actions.ramrod.position+Vector3(.025,.018,-.08)
			else:
				_offhand.position=_offhand_rest.lerp(Vector3(.02,.09,_primary_muzzle.z),open)
			_set_rotation("hammer",0,-.52*smoothstep(.84,.96,p))
			_set_rotation("frizzen",0,-.8*open)
		"break","topbreak","derringer":
			_set_rotation("break",0,-open*(1.25 if _action=="derringer" else .72))
			_set_rotation("latch",1,open*.6)
			_set_rotation("cylinder",2,floor(p*6.)*TAU/6. if _action=="topbreak" else 0.)
			_offhand.position=Vector3(-.065,-.035,-.11).lerp(Vector3(.020,.045,-.15),work*.45)*open+_offhand_rest*(1.-open)
		"capball","pepperbox","gate":
			var chamber_count:=9.0 if _index==9 else 6.0
			_set_rotation("cylinder",2,floor(p*chamber_count)*TAU/chamber_count)
			_set_rotation("gate",2,open*1.25)
			_set_rotation("rammer",0,-sin(p*chamber_count*PI)*.75*open)
			if _actions.has("ejector"): _actions.ejector.position.z-=work*.08*open
			_set_rotation("hammer",0,-.5*open)
			_offhand.position=_offhand_rest.lerp(Vector3(.065,.008,-.08-work*.025),open)
		"snider":
			_set_rotation("breech",2,-open*1.6)
			_actions.breech.position.x+=open*.035
			_offhand.position=_offhand_rest.lerp(Vector3(.09,.095,-.14),open)
		"falling":
			_set_rotation("lever",0,-open*.9)
			_actions.breech.position.y-=open*.06
			_offhand.position=_offhand_rest.lerp(Vector3(.065,.080,-.13),open)
		"lever":
			_set_rotation("lever",0,-sin(p*PI)*.8)
			_actions.breech.position.z+=open*.055
			_set_rotation("gate",2,work*.35*open)
			_offhand.position=_offhand_rest.lerp(Vector3(.065,.005,-.1),open)
		"crossbow":
			_actions.windlass.visible=p<.82
			_set_rotation("windlass",0,p*TAU*5.)
			_set_string(lerpf(.05,1.0,smoothstep(.12,.70,p)))
			_actions.bolt.visible=p>.80
			_offhand.position=_offhand_rest.lerp(Vector3(-.11,.08,-.03),open)

func animate_cycle(progress: float) -> void:
	if _index in [30,31,32]:
		_set_rotation("naval_right" if _fired_hand==0 else "naval_left",0,sin(progress*PI)*.22)
	var stroke:=sin(clampf(progress,0.,1.)*PI)
	_set_rotation("hammer",0,-.58*(1.-progress))
	_set_rotation("hammer_left",0,-.58*(1.-progress))
	if _action=="toggle": _set_rotation("toggle",0,-stroke*1.1)
	elif _action=="lever":
		_set_rotation("lever",0,-stroke*.75)
		if _actions.has("breech"): _actions.breech.position.z+=stroke*.055
	elif _action in ["gate","capball","topbreak","pepperbox"]:
		if not (_index==9 and _secondary):
			_set_rotation("cylinder",2,smoothstep(.05,.7,progress)*TAU/(9. if _index==9 else 6.))
	elif _action=="crossbow":
		_set_string(.05+absf(sin(progress*TAU*3.))*.08*(1.-progress))

func _create_flash() -> void:
	_effects=Node3D.new()
	_effects.name="MuzzleEffects"
	add_child(_effects)
	_flash_mesh=MeshInstance3D.new()
	var shape:=SphereMesh.new()
	shape.radius=.064
	shape.height=.128
	shape.radial_segments=12
	shape.rings=6
	_flash_mesh.mesh=shape
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("ffd98a")
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled=true
	material.emission=Color("ffbd64")
	material.emission_energy_multiplier=4.0
	_flash_mesh.material_override=material
	_flash_mesh.scale=Vector3(.65,.65,2.2)
	_flash_mesh.position=muzzle_position+Vector3.FORWARD*.035
	_flash_mesh.visible=false
	_flash_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effects.add_child(_flash_mesh)
	_flash_light=OmniLight3D.new()
	_flash_light.position=muzzle_position
	_flash_light.light_color=Color("ffd499")
	_flash_light.light_energy=0.0
	_flash_light.omni_range=4.5
	_effects.add_child(_flash_light)

func flash() -> void:
	_fired_hand=dual_hand
	_flash_mesh.position=muzzle_position+Vector3.FORWARD*.035
	_flash_light.position=muzzle_position
	if _index >= 18 and _index <= 26:
		_cycle_left = .4
		return
	_cycle_left=.60 if _action in ["lever","crossbow"] else .35
	if _index==3:
		_actions.bolt.visible=false
		_loaded=false
		_set_string(.05)
		return
	_flash_time=.075 if _action=="muzzle" else .05
	_flash_mesh.visible=not _inspection
	_flash_mesh.rotation.z=randf()*TAU
	_flash_light.light_energy=0.0 if _inspection else 3.0
	if not _inspection: _spawn_smoke()

func _spawn_smoke() -> void:
	var cloud:=Node3D.new()
	add_child(cloud)
	cloud.top_level=true
	cloud.global_transform=global_transform
	cloud.global_position=to_global(muzzle_position)
	# Three tapered tongues project forward from the actual firing barrel.
	for i in 3:
		var flame:=MeshInstance3D.new(); var shape:=CylinderMesh.new()
		shape.top_radius=.003; shape.bottom_radius=.07-i*.018; shape.height=.44-i*.10; shape.radial_segments=7
		flame.mesh=shape; flame.rotation.x=-PI/2; flame.position.z=-shape.height*.5
		var mat:=preload("res://scripts/combat_fx.gd").material(Color(1,.3+i*.24,.03+i*.23,.9),true)
		flame.material_override=mat; flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; cloud.add_child(flame)
		var fade:=flame.create_tween(); fade.tween_property(mat,"albedo_color:a",0,.16); fade.tween_callback(flame.queue_free)
	var puffs:=10 if _action=="muzzle" else 5
	for i: int in puffs:
		var puff:=MeshInstance3D.new()
		var sphere:=SphereMesh.new()
		sphere.radius=.075
		sphere.height=.15
		sphere.radial_segments=10
		sphere.rings=5
		puff.mesh=sphere
		var material:=StandardMaterial3D.new()
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color=Color(.74,.75,.69,.25)
		material.roughness=1.
		puff.material_override=material
		puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.add_child(puff)
		var tween:=puff.create_tween().set_parallel(true)
		tween.tween_property(puff,"position",Vector3(randf_range(-.2,.2),randf_range(.15,.65),-randf_range(.2,1.0)),1.3)
		tween.tween_property(puff,"scale",Vector3.ONE*randf_range(2.,4.),1.3)
		tween.tween_property(material,"albedo_color:a",0.,1.3)
	var cleanup:=cloud.create_tween()
	cleanup.tween_interval(1.4)
	cleanup.tween_callback(cloud.queue_free)

func _process(delta: float) -> void:
	if _flash_time>0.0:
		_flash_time-=delta
		if _flash_time<=0.0:
			_flash_mesh.visible=false
			_flash_light.light_energy=0.0
	if _cycle_left>0.0 and not _reload_active:
		_cycle_left=maxf(0.,_cycle_left-delta)
		var duration:=.60 if _action in ["lever","crossbow"] else .35
		animate_cycle(1.-_cycle_left/duration)
