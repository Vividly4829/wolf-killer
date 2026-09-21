extends Node3D
var item_id := 0
var kind := "cache"
var key := "sites"
var caption := "SUPPLIES"
var taken := false
var game: Node
var label: Label3D
func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.65,.42,.45)
	mesh.mesh=box; mesh.position.y=.24
	var mat:=StandardMaterial3D.new(); mat.albedo_color=Color("74503b")
	mesh.material_override=mat; add_child(mesh)
	label=Label3D.new(); label.text=caption; label.position.y=.95; label.font_size=28
	label.pixel_size=.007; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; add_child(label)
func _process(_delta: float) -> void:
	visible=not taken and game.is_playing()
	label.visible=visible and position.distance_to(game.player.position)<16
