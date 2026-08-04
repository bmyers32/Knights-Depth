class_name TelegraphIndicator
extends MeshInstance3D
## Minimum-viable ground telegraph (GAME-RULES §3 telegraph law) — a flat colored
## disc, no shader polish (playtest-before-polish law). One shared component across
## all three M1 enemy families (rule of two: Fang/Ooze/Watcher are 3 concrete uses).

var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _material
	visible = false


## duration_seconds is the caller's job to convert from sim ticks (Engine.
## physics_ticks_per_second, GAME-RULES §1.8's 30 Hz sim tick) — presentation never
## hardcodes a tick rate of its own.
func flash(color: Color, duration_seconds: float) -> void:
	_material.albedo_color = color
	visible = true
	get_tree().create_timer(duration_seconds).timeout.connect(func(): visible = false)
