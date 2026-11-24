extends Button
## Drag and drop supplements the click / keyboard controls.
var block_id := ""
var source := ""
var on_drop := Callable()

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = text
	set_drag_preview(preview)
	return {"block_id": block_id, "source": source}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("block_id") and on_drop.is_valid()

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_drop.call(data, block_id)
