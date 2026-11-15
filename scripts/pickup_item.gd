extends Area3D
class_name PickupItem

@export var item_id: String = "medkit"
@export var display_name: String = "Medkit"
@export var amount: int = 1

func get_item_id() -> String:
	return item_id

func get_display_name() -> String:
	return display_name

func collect(collector: Node) -> void:
	if collector and collector.has_method("pickup_item"):
		collector.pickup_item(item_id, amount)
		queue_free()
