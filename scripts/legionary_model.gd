extends "res://scripts/field_character.gd"
func ranger_details(head: Node3D,leather: Material,_dark: Material,trim: Material) -> void:
	var steel:=mat("roman_steel",Color("929a9b"))
	var red:=mat("roman_red",Color("812b27"))
	oval(head,Vector3(0,.09,.01),Vector3(.16,.13,.15),steel)
	panel(head,Vector3(0,.025,.13),Vector3(.30,.055,.12),steel)
	for side in [-1,1]: panel(head,Vector3(side*.13,-.05,-.035),Vector3(.035,.14,.10),steel)
	for i in 6: panel(torso,Vector3(0,.14+i*.072,-.01),Vector3(.43,.057,.37),steel)
	for side in [-1,1]:
		panel(joints["shoulderL" if side<0 else "shoulderR"],Vector3(0,.045,0),Vector3(.23,.085,.28),steel)
		var tail:=joint(torso,"coat_tail_%d"%side,Vector3(side*.12,0,0))
		panel(tail,Vector3(0,-.13,0),Vector3(.22,.28,.30),red)
	for i in 8: panel(torso,Vector3(-.19+i*.054,-.095,-.19),Vector3(.037,.22,.025),leather)
	var shield:=Node3D.new(); joints.elbowL.add_child(shield); shield.position=Vector3(-.06,-.21,-.20)
	panel(shield,Vector3.ZERO,Vector3(.64,1.02,.085),red)
	for side in [-1,1]:
		panel(shield,Vector3(side*.31,0,-.05),Vector3(.025,1.04,.025),trim)
		panel(shield,Vector3(0,side*.50,-.05),Vector3(.65,.025,.025),trim)
	panel(shield,Vector3(0,0,-.055),Vector3(.025,.83,.025),trim)
	panel(shield,Vector3(0,0,-.055),Vector3(.50,.025,.025),trim)
	oval(shield,Vector3(0,0,-.08),Vector3(.11,.11,.075),steel)
	var sword:=Node3D.new(); joints.elbowR.add_child(sword); sword.position=Vector3(0,-.33,-.02)
	panel(sword,Vector3(0,0,-.035),Vector3(.055,.055,.16),leather)
	panel(sword,Vector3(0,0,-.12),Vector3(.15,.045,.035),trim)
	panel(sword,Vector3(0,0,-.37),Vector3(.06,.018,.48),steel)
	segment(sword,Vector3(0,0,-.61),Vector3(0,0,-.72),.03,0,steel)
func _process(delta: float) -> void:
	super(delta)
	joints.shoulderL.rotation.x=.22; joints.elbowL.rotation.x=.38
	if attacking:
		joints.shoulderR.rotation.x=1.1+sin(phase*2)*.45
		joints.elbowR.rotation.x=.4
