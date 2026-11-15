extends CharacterBody3D
class_name PlayerController

# ⚙️ Movement variables
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var gravity := -24.8
@export var jump_force := 7.0

# 🏃 State
var is_sprinting := false

# 🎥 Camera
@onready var camera: Camera3D = get_node_or_null("Camera3D")
var mouse_sensitivity := 0.2
var camera_pitch := 0.0

# --- Head bob variables ---
@export var headbob_frequency_walk := 6.0
@export var headbob_frequency_sprint := 10.0
@export var headbob_amplitude_walk := 0.05
@export var headbob_amplitude_sprint := 0.1

var headbob_timer := 0.0
var headbob_offset := 0.0
var base_camera_y := 0.0

# 🔎 Interaction & Inventory
@onready var interact_ray: RayCast3D = find_child("InteractRay", true, false) as RayCast3D
@onready var hover_label: Label = find_child("HoverLabel", true, false) as Label
@onready var inventory_node: Inventory = find_child("Inventory", true, false) as Inventory
@onready var inventory_ui: InventoryUI = find_child("InventoryUI", true, false) as InventoryUI
var _hovered_pickup: PickupItem
var _ui_open := false
var _inventory_forced_pause := false

# 🎵 Footsteps
@onready var footstep_player: AudioStreamPlayer3D = get_node_or_null("FootstepPlayer") as AudioStreamPlayer3D
@onready var ground_ray: RayCast3D = get_node_or_null("GroundRay") as RayCast3D

@export var footsteps_default: Array[AudioStream] = []
@export var footsteps_concrete: Array[AudioStream] = []
@export var footsteps_wood: Array[AudioStream] = []
@export var footsteps_metal: Array[AudioStream] = []
@export var footsteps_grass: Array[AudioStream] = []
@export var footsteps_carpet: Array[AudioStream] = []

@export var footstep_interval_walk := 0.48
@export var footstep_interval_sprint := 0.34
@export var footstep_move_threshold := 0.15

@export var footstep_pitch_min := 0.96
@export var footstep_pitch_max := 1.04
@export var footstep_volume_db := -2.0

var _footstep_timer := 0.0
var _footstep_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_validate_dependencies()
	if inventory_node and inventory_ui:
		inventory_ui.set_inventory(inventory_node)
		inventory_ui.close()
		_ui_open = false
	if inventory_node and not inventory_node.is_connected("item_used", _on_item_used):
		inventory_node.item_used.connect(_on_item_used)
	if camera:
		base_camera_y = camera.position.y
	_footstep_rng.randomize()
	_update_mouse_mode()
	_update_hover_prompt()

func _process(delta: float) -> void:
	if not camera:
		return
	var horizontal_velocity := Vector2(velocity.x, velocity.z).length()
	if horizontal_velocity > 0.1 and is_on_floor():
		var freq := headbob_frequency_sprint if is_sprinting else headbob_frequency_walk
		var amp := headbob_amplitude_sprint if is_sprinting else headbob_amplitude_walk
		headbob_timer += delta * freq
		headbob_offset = sin(headbob_timer) * amp
	else:
		headbob_timer = 0.0
		headbob_offset = 0.0
	camera.position.y = base_camera_y + headbob_offset

func _physics_process(delta: float) -> void:
	if _ui_open:
		velocity = Vector3.ZERO
		return
	is_sprinting = Input.is_action_pressed("sprint")
	handle_movement()
	handle_jump_and_gravity(delta)
	handle_footsteps(delta)
	_update_hover_prompt()
	move_and_slide()

func handle_movement() -> void:
	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	var input_vector := Vector3(input_x, 0.0, input_z)
	if input_vector.length_squared() > 1.0:
		input_vector = input_vector.normalized()

	var move_speed := sprint_speed if is_sprinting else walk_speed
	var basis := global_transform.basis
	var move_direction := (basis.x * input_vector.x) + (basis.z * input_vector.z)

	if move_direction.length_squared() > 0.0:
		move_direction = move_direction.normalized() * move_speed
	else:
		move_direction = Vector3.ZERO

	velocity.x = move_direction.x
	velocity.z = move_direction.z

func handle_jump_and_gravity(delta: float) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force
		else:
			velocity.y = 0.0
	else:
		velocity.y += gravity * delta

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _ui_open and not get_tree().paused:
		_handle_mouse_look(event)
	if event.is_action_pressed("interact"):
		_attempt_collect()
	if event.is_action_pressed("inventory"):
		_toggle_inventory_ui()
	if event.is_action_pressed("pause"):
		_handle_pause_toggle()

func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
	camera_pitch = clamp(camera_pitch - event.relative.y * mouse_sensitivity, -80.0, 80.0)
	if camera:
		camera.rotation_degrees.x = camera_pitch

func _toggle_inventory_ui() -> void:
	if not inventory_ui:
		return
	_ui_open = !_ui_open
	if _ui_open:
		inventory_ui.open()
		if not get_tree().paused:
			get_tree().paused = true
			_inventory_forced_pause = true
	else:
		inventory_ui.close()
		if _inventory_forced_pause:
			get_tree().paused = false
			_inventory_forced_pause = false
	_update_mouse_mode()

func _handle_pause_toggle() -> void:
	if _ui_open and inventory_ui:
		inventory_ui.close()
		_ui_open = false
		_inventory_forced_pause = false
	get_tree().paused = !get_tree().paused
	_update_mouse_mode()

func _attempt_collect() -> void:
	if _hovered_pickup:
		_hovered_pickup.collect(self)
		_hovered_pickup = null

func handle_footsteps(delta: float) -> void:
	if not footstep_player or not ground_ray:
		return
	if not is_on_floor():
		_footstep_timer = 0.0
		return
	var speed_h := Vector2(velocity.x, velocity.z).length()
	if speed_h < footstep_move_threshold:
		_footstep_timer = 0.0
		return
	var interval := footstep_interval_sprint if is_sprinting else footstep_interval_walk
	_footstep_timer += delta
	if _footstep_timer >= interval:
		_footstep_timer = 0.0
		_play_footstep()

func _play_footstep() -> void:
	if not footstep_player:
		return
	var surface_type := _get_surface_type_underfoot()
	var clip := _pick_footstep_clip(surface_type)
	if clip:
		footstep_player.stop()
		footstep_player.stream = clip
		footstep_player.pitch_scale = _footstep_rng.randf_range(footstep_pitch_min, footstep_pitch_max)
		footstep_player.volume_db = footstep_volume_db
		footstep_player.play()


func _get_surface_type_underfoot() -> StringName:
	if ground_ray and ground_ray.is_colliding():
		var collider := ground_ray.get_collider()
		var tag := _find_surface_tag(collider)
		if tag:
			return tag.surface_type
		if collider is Object:
			var property: Variant = collider.get("surface_type")
			if typeof(property) in [TYPE_STRING, TYPE_STRING_NAME]:
				return StringName(property)
		if collider is Node and collider.has_meta("surface_type"):
			return StringName(collider.get_meta("surface_type"))
		if collider is Object and collider.has_method("get_surface_type"):
			return collider.get_surface_type()
	return &"default"

func _find_surface_tag(collider: Object) -> SurfaceTag:
	if collider is SurfaceTag:
		return collider
	if collider is Node:
		var node := collider as Node
		if node.get_parent() is SurfaceTag:
			return node.get_parent()
		for child in node.get_children():
			if child is SurfaceTag:
				return child
	return null

func _pick_footstep_clip(surface_type: StringName) -> AudioStream:
	var pool: Array[AudioStream] = []
	match surface_type:
		&"concrete": pool = footsteps_concrete
		&"wood": pool = footsteps_wood
		&"metal": pool = footsteps_metal
		&"grass": pool = footsteps_grass
		&"carpet": pool = footsteps_carpet
		_: pool = footsteps_default
	if pool.is_empty():
		pool = footsteps_default
	if pool.is_empty():
		return null
	return pool[_footstep_rng.randi_range(0, pool.size() - 1)]

func pickup_item(item_id: String, amount: int = 1) -> void:
	if inventory_node:
		inventory_node.add_item(item_id, amount)
		var count := inventory_node.get_item_count(item_id)
		_debug_log("Picked up %s x%d (now have %d)" % [item_id, amount, count])
	else:
		push_error("[Player] Cannot add item; 'Inventory' node missing or script not attached.")

func _on_item_used(item_id: String) -> void:
	match item_id:
		"medkit": _heal_player(25)
		"key": _debug_log("Key used - hook this to door logic.")
		_: _debug_log("Used item: %s" % item_id)

func _heal_player(amount: int) -> void:
	_debug_log("Healed for %d HP (stub)." % amount)

func _update_hover_prompt() -> void:
	var prompt := ""
	_hovered_pickup = null
	if interact_ray and interact_ray.is_colliding():
		var hit := interact_ray.get_collider()
		var pickup := _resolve_pickup(hit)
		if pickup:
			_hovered_pickup = pickup
			prompt = "Press [E] to pick up %s" % pickup.get_display_name()
	if hover_label:
		hover_label.visible = prompt != ""
		hover_label.text = prompt

func _resolve_pickup(target: Object) -> PickupItem:
	if target is PickupItem:
		return target
	if target is Node:
		var node := target as Node
		if node.get_parent() is PickupItem:
			return node.get_parent()
	if target and target.has_method("collect") and target.has_method("get_display_name"):
		return target as PickupItem
	return null

func _update_mouse_mode() -> void:
	var should_capture := not _ui_open and not get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if should_capture else Input.MOUSE_MODE_VISIBLE

func _validate_dependencies() -> void:
	if not camera:
		push_error("[Player] Camera3D child not found.")
	if not interact_ray:
		push_warning("[Player] 'InteractRay' not found. Pickup prompt disabled.")
	if not hover_label:
		push_warning("[Player] 'HoverLabel' not found. Pickup prompt disabled.")
	if not inventory_node:
		push_warning("[Player] 'Inventory' not found. Inventory disabled.")
	if not inventory_ui:
		push_warning("[Player] 'InventoryUI' not found. UI disabled.")
	if not footstep_player:
		push_warning("[Player] 'FootstepPlayer' not found. Footstep audio disabled.")
	if not ground_ray:
		push_warning("[Player] 'GroundRay' not found. Surface detection disabled.")

func _debug_log(message: String) -> void:
	if OS.is_debug_build():
		print("[Player] %s" % message)
