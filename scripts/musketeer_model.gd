extends "res://scripts/field_character.gd"
var reloading:=false
func ranger_details(head: Node3D,leather: Material,dark: Material,trim: Material) -> void:
	var white:=mat("crossbelts",Color("ddd6bd")); var red:=mat("facings",Color("9f352c"))
	var brass:=mat("brass",Color("c49a45")); var blue:=mat("uniform",Color("263b61"))
	segment(head,Vector3(0,.39,.01),Vector3(0,.12,.01),.145,.16,dark)
	panel(head,Vector3(0,.12,-.10),Vector3(.32,.025,.24),dark)
	oval(head,Vector3(0,.24,-.15),Vector3(.043,.065,.008),brass)
	segment(head,Vector3(.07,.52,.01),Vector3(.07,.36,.01),.032,.034,red)
	for side in [-1,1]:
		segment(torso,Vector3(side*.20,.59,-.14),Vector3(-side*.17,.08,-.20),.028,.028,white)
		panel(joints["shoulderL" if side<0 else "shoulderR"],Vector3(0,.07,0),Vector3(.19,.035,.20),red)
		panel(joints["elbowL" if side<0 else "elbowR"],Vector3(0,-.21,0),Vector3(.14,.09,.13),red)
		var tail:=joint(torso,"coat_tail_%d"%side,Vector3(side*.13,.02,.06))
		panel(tail,Vector3(0,-.20,.06),Vector3(.22,.42,.055),blue)
		for limb in [joints["hipL" if side<0 else "hipR"],joints["kneeL" if side<0 else "kneeR"]]:
			for part in limb.get_children():
				if part is MeshInstance3D and part.mesh is CylinderMesh: part.material_override=white
	panel(torso,Vector3(0,.02,-.02),Vector3(.47,.055,.37),white)
	panel(torso,Vector3(0,.02,-.215),Vector3(.085,.065,.018),brass)
	panel(torso,Vector3(0,.33,.25),Vector3(.34,.40,.18),leather)
func _process(delta: float) -> void:
	super(delta)
	if reloading:
		joints.shoulderR.rotation.x=.5+sin(phase*1.8)*.25
		joints.elbowR.rotation.x=.6
		joints.shoulderL.rotation.x=.7
