class_name ImpactEffect
extends Node2D
## Procedural visual impact sparks for BioSphere-X combat.
## Spawns on projectile or melee strike and dissipates cleanly without external assets.

@export var color: Color = Color(0.2, 0.95, 1.0)
@export var spark_count: int = 6
@export var duration: float = 0.16

var _time: float = 0.0
var _spark_dirs: Array[Vector2] = []
var _spark_speeds: Array[float] = []


func _ready() -> void:
	z_index = 10 # Render above obstacles and ground
	for i in spark_count:
		var angle := randf_range(0, TAU)
		_spark_dirs.append(Vector2.from_angle(angle))
		_spark_speeds.append(randf_range(40.0, 110.0))


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := _time / duration
	var alpha := 1.0 - progress
	
	# Expanding impact shock ring
	var ring_radius := progress * 16.0
	draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 16, Color(color.r, color.g, color.b, alpha * 0.8), 1.5)
	
	# Center flash dot
	if progress < 0.4:
		var flash_alpha := (1.0 - progress / 0.4)
		draw_circle(Vector2.ZERO, 4.0 * (1.0 - progress), Color(1.0, 1.0, 1.0, flash_alpha))
	
	# Flying sparks
	for i in _spark_dirs.size():
		var dir: Vector2 = _spark_dirs[i]
		var spd: float = _spark_speeds[i]
		var spark_pos := dir * spd * progress
		var spark_col := Color(color.r, color.g, color.b, alpha)
		draw_circle(spark_pos, 1.8 * (1.0 - progress), spark_col)
