extends Node
class_name Inventory

## Lightweight inventory container for the horror template.
## Keeps track of item stacks and emits signals when they change.
var items: Dictionary = {} # { "item_id": count }

signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal item_used(item_id: String)

func add_item(item_id: String, amount: int = 1) -> void:
	items[item_id] = items.get(item_id, 0) + amount
	emit_signal("item_added", item_id, items[item_id])

func remove_item(item_id: String, amount: int = 1) -> void:
	if not items.has(item_id):
		return
	items[item_id] -= amount
	if items[item_id] <= 0:
		items.erase(item_id)
	emit_signal("item_removed", item_id, items.get(item_id, 0))

func use_item(item_id: String) -> void:
	if not items.has(item_id):
		return
	remove_item(item_id, 1)
	emit_signal("item_used", item_id)

func get_item_count(item_id: String) -> int:
	return items.get(item_id, 0)

func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount

func get_items() -> Dictionary:
	return items.duplicate()
