extends Label
class_name FloatingCombatText
## Lightweight floating combat text & feedback indicator for BioSphere-X.
## Renders floating damage numbers, healing ticks, and tactical status alerts
## with smooth upward drift, scale pop, and alpha fade.

static func spawn(
	tree_node: Node,
	pos: Vector2,
	text_content: String,
	text_color: Color = Color(1.0, 0.35, 0.35),
	duration: float = 0.85
) -> Label:
	if not tree_node or not is_instance_valid(tree_node):
		return null
		
	var lbl := Label.new()
	lbl.text = text_content
	lbl.global_position = pos + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
	lbl.z_index = 50
	lbl.top_level = true
	
	# High-tech styling
	lbl.add_theme_color_override("font_color", text_color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_font_size_override("font_size", 12)
	
	tree_node.add_child(lbl)
	
	# Upward float and fade tween
	var tween := lbl.create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(lbl, "global_position:y", lbl.global_position.y - 28.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(lbl, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_LINEAR).set_delay(duration * 0.35)
		tween.chain().tween_callback(lbl.queue_free)
	else:
		lbl.queue_free()
		
	return lbl
