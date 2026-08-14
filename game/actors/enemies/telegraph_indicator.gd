class_name TelegraphIndicator
extends MeshInstance3D
## Minimum-viable ground telegraph (GAME-RULES §3 telegraph law) — a flat colored
## disc, no shader polish (playtest-before-polish law). One shared component across
## all three M1 enemy families (rule of two: Fang/Ooze/Watcher are 3 concrete uses).

## VULNERABLE-WINDOW CUE (P29 iteration item 2). Playtest finding: "the vulnerable
## interval ... could not be identified during play."
##
## CONTENT TRUTH IS UNCHANGED and drives this, never the reverse: Watcher's actions author
## NORMAL early -> VULNERABLE late -> fire. NORMAL needs no cue (it is ordinary
## susceptibility, not a promise of anything), so the preparing phase keeps the plain
## telegraph and exactly ONE distinct cue marks the window opening.
##
## The cue is SCALE + BRIGHTNESS, deliberately not hue: GAME-RULES §3's channel law gives
## colour to the damage TYPE, so a second hue here would steal a channel presentation does
## not own. Same colour, unmistakably bigger and brighter.
const VULNERABLE_SCALE: float = 1.6
const VULNERABLE_BRIGHTNESS: float = 2.2

var _material := StandardMaterial3D.new()
## Guards the auto-hide timer against a stale callback: an interrupt can clear() a flash
## early, and without this the PREVIOUS flash's timer would later hide a NEWER one that
## had legitimately started in the meantime.
var _generation: int = 0


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _material
	visible = false


## duration_seconds is the caller's job to convert from sim ticks (Engine.
## physics_ticks_per_second, GAME-RULES §1.8's 30 Hz sim tick) — presentation never
## hardcodes a tick rate of its own.
func flash(color: Color, duration_seconds: float) -> void:
	_generation += 1
	var generation: int = _generation
	_material.albedo_color = color
	scale = Vector3.ONE
	visible = true
	get_tree().create_timer(duration_seconds).timeout.connect(func():
		if generation == _generation:
			visible = false)


## The one distinct cue: the authored vulnerable window is OPEN as of this sim tick.
func mark_vulnerable() -> void:
	if not visible:
		return  # the windup already ended or was interrupted; never resurrect a cue
	scale = Vector3.ONE * VULNERABLE_SCALE
	_material.albedo_color = _material.albedo_color * VULNERABLE_BRIGHTNESS


## Immediate hide — used when a windup is cancelled, so an interrupted enemy never keeps
## advertising a window that no longer exists.
func clear() -> void:
	_generation += 1
	scale = Vector3.ONE
	visible = false


## Persistent on/off variant (Slice B charge-ready cue, manual-pass) -- unlike
## flash(), never self-hides on a timer. The charge-ready state has no fixed
## duration (the player may hold indefinitely once saturated), so ONLY an explicit
## active=false call may turn this off -- driven by Events (charge_ready/
## melee_swing/melee_hold_canceled), never presentation-side polling of sim state.
func set_active(color: Color, active: bool) -> void:
	if active:
		_material.albedo_color = color
		visible = true
	else:
		visible = false
