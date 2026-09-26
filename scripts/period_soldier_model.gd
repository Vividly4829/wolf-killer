extends "res://scripts/musketeer_model.gd"
var faction:="confederate"
func ranger_details(head:Node3D,leather:Material,dark:Material,trim:Material) -> void:
	var uniform:=mat("uniform",coat_color)
	var brass:=mat("buttons",Color("b39c68"))
	if faction=="confederate":
		segment(head,Vector3(0,.22,.02),Vector3(0,.12,.02),.15,.17,uniform)
		panel(head,Vector3(0,.12,-.12),Vector3(.29,.025,.24),dark)
	else:
		oval(head,Vector3(0,.17,.015),Vector3(.19,.15,.20),uniform)
		panel(head,Vector3(0,.095,.025),Vector3(.40,.03,.40),uniform)
		panel(joints.shoulderL,Vector3(-.072,-.16,0),Vector3(.025,.09,.16),mat("armband",Color("802e2b")))
	panel(torso,Vector3(0,.04,-.01),Vector3(.47,.05,.37),leather)
	panel(torso,Vector3(0,.04,-.21),Vector3(.065,.055,.018),brass)
	for i in 5: oval(torso,Vector3(0,.15+i*.075,-.205),Vector3(.015,.015,.009),brass)
	for side in [-1,1]:
		var tail:=joint(torso,"coat_tail_%d"%side,Vector3(side*.13,.02,.06))
		panel(tail,Vector3(0,-.12,.05),Vector3(.22,.25,.05),uniform)
		panel(torso,Vector3(side*.13,.38,-.19),Vector3(.12,.13,.025),uniform)
		panel(torso,Vector3(side*.17,.03,-.23),Vector3(.10,.10,.07),leather)
