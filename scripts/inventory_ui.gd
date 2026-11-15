extends CanvasLayer
class_name InventoryUI

var title: Label
var item_grid: GridContainer
var inventory_ref: Inventory
var _refresh_callable: Callable = Callable()

func _ready() -> void:
	# auto-find UI children
	title = find_child("Title", true, false) as Label
	item_grid = find_child("ItemGrid", true, false) as GridContainer
	_refresh_callable = Callable(self, "_refresh")

	if item_grid == null:
		push_error("[InventoryUI] 'ItemGrid' not found. Create a GridContainer named 'ItemGrid'.")
	if title == null:
		push_warning("[InventoryUI] 'Title' not found. UI will still work without it.")

# -----------------------------
# Public API
# -----------------------------
func set_inventory(inv: Inventory) -> void:
	inventory_ref = inv
	if not is_node_ready():
		await ready

	if inventory_ref == null:
		push_error("[InventoryUI] set_inventory called with null inventory.")
		return

	if _refresh_callable == Callable():
		_refresh_callable = Callable(self, "_refresh")

	if not inventory_ref.is_connected("item_added", _refresh_callable):
		inventory_ref.item_added.connect(_refresh_callable)
	if not inventory_ref.is_connected("item_removed", _refresh_callable):
		inventory_ref.item_removed.connect(_refresh_callable)
	if not inventory_ref.is_connected("item_used", _refresh_callable):
		inventory_ref.item_used.connect(_refresh_callable)

	_refresh()

func open() -> void:
	visible = true
	_refresh()

func close() -> void:
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

# -----------------------------
# Internal refresh
# -----------------------------
func _refresh(_item_id := "", _count := 0) -> void:
	if inventory_ref == null or item_grid == null:
		return

	for child in item_grid.get_children():
		child.queue_free()

	var inventory_items := inventory_ref.get_items()
	var ids := inventory_items.keys()
	ids.sort()

	for item_id in ids:
		var count: int = inventory_items[item_id]
		var button := Button.new()
		button.text = "%s x%d" % [item_id, count]
		button.tooltip_text = "Use %s" % item_id
		var id_to_use: String = item_id
		button.pressed.connect(func():
			if inventory_ref:
				inventory_ref.use_item(id_to_use)
				_refresh()
		)
		item_grid.add_child(button)
