extends Node3D

@onready var model: Node3D = $Sketchfab_model
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var player: Node3D = get_tree().get_first_node_in_group("player")

var min_distance := 0.0
var max_distance := 10.0

func _ready():
	model.visible = false
	anim_player.play("Armature|ArmatureAction")
	anim_player.pause()

func _process(_delta: float) -> void:
	if not player:
		return
	
	var dist = global_position.distance_to(player.global_position)

	if dist > max_distance:
		model.visible = false
		anim_player.seek(0.0, true)
		return

	var clamped_dist = clamp(dist, min_distance, max_distance)
	var t = 1.0 - ((clamped_dist - min_distance) / (max_distance - min_distance))

	var anim_name = "Armature|ArmatureAction"
	var anim_length = anim_player.get_animation(anim_name).length
	var anim_time = t * anim_length

	# ✅ only visible once the animation has actually advanced
	if anim_time > 0.05:
		model.visible = true
	else:
		model.visible = false

	anim_player.current_animation = anim_name
	anim_player.seek(anim_time, true)
