class_name TelegraphIndicator
extends MeshInstance3D
## Minimum-viable ground telegraph (GAME-RULES §3 telegraph law) — a flat colored
## disc, no shader polish (playtest-before-polish law). One shared component across
## all three M1 enemy families (rule of two: Fang/Ooze/Watcher are 3 concrete uses).
##
## THREE-PHASE CUE (P29 second iteration, 2026-08-17). The first attempt marked the
## authored VULNERABLE window with a one-shot size+brightness bump and it FAILED playtest:
## "I still can't intentionally identify the vulnerable window." Diagnosis of the failure,
## rather than more of the same: the disc was already at full size and full brightness for
## the entire windup, so the window opening was a *change of degree* inside an unchanging
## presentation. A player watching for a moment cannot find one in a continuum.
##
## The fix is a change of KIND, in three parts:
##   PREPARING  — deliberately UNDERSTATED: smaller, dimmer, and perfectly still. This
##                phase now has somewhere to go, which is what makes the next one legible.
##   OPEN       — a hard POP to oversize, then a continuous PULSE. Motion is the channel
##                doing the work: a still disc becoming a beating one is categorical, and
##                unlike size or brightness it cannot be mistaken for perspective or
##                distance. This is the "open now" moment.
##   (fire)     — the flash's own duration ends the cue.
##
## CHANNEL LAW (GAME-RULES §3): colour belongs to the damage TYPE, so none of this touches
## hue. Scale, luminance and MOTION are presentation's own channels.
##
## An action with NO authored window (Fang, Ooze) keeps exactly the old flat presentation —
## it has no phase transition to communicate, and dimming its telegraph would be a pure
## regression with no payoff.

## PREPARING: understated on purpose. The gap between these and the OPEN values IS the cue.
const PREPARE_SCALE: float = 0.72
const PREPARE_BRIGHTNESS: float = 0.5
## OPEN: the pop overshoots, then settles into the pulse band.
const OPEN_POP_SCALE: float = 2.15
const OPEN_POP_SECONDS: float = 0.09
const OPEN_PULSE_MIN: float = 1.45
const OPEN_PULSE_MAX: float = 1.95
const OPEN_PULSE_HZ: float = 5.5
const OPEN_BRIGHTNESS: float = 1.0
## The pulse drives luminance alongside scale — two channels moving together read as one
## unmistakable event rather than two subtle ones.
const OPEN_PULSE_BRIGHTNESS_GAIN: float = 0.55

enum Phase { IDLE, PLAIN, PREPARING, OPEN }

var _material := StandardMaterial3D.new()
var _base_color: Color = Color.WHITE
var _phase: int = Phase.IDLE
var _open_elapsed: float = 0.0
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
##
## has_vulnerable_window selects the three-phase presentation. False keeps the original
## flat telegraph, unchanged, for actions that author no window.
func flash(color: Color, duration_seconds: float, has_vulnerable_window: bool = false) -> void:
	_generation += 1
	var generation: int = _generation
	_base_color = color
	_phase = Phase.PREPARING if has_vulnerable_window else Phase.PLAIN
	_open_elapsed = 0.0
	_apply_phase_visuals()
	visible = true
	get_tree().create_timer(duration_seconds).timeout.connect(func():
		if generation == _generation:
			visible = false
			_phase = Phase.IDLE)


## The authored vulnerable window is OPEN as of this sim tick — driven by the arena from
## telegraph tick + action content, never computed here (Prime Directive 1).
func mark_vulnerable() -> void:
	if not visible:
		return  # the windup already ended or was interrupted; never resurrect a cue
	_phase = Phase.OPEN
	_open_elapsed = 0.0


## Immediate hide — used when a windup is cancelled, so an interrupted enemy never keeps
## advertising a window that no longer exists.
func clear() -> void:
	_generation += 1
	_phase = Phase.IDLE
	scale = Vector3.ONE
	visible = false


## Presentation animation only (GAME-RULES §1.8 permits exactly this in _process).
## Gameplay never reads this transform, and nothing here feeds back into the sim.
func _process(delta: float) -> void:
	if _phase != Phase.OPEN:
		return
	_open_elapsed += delta
	_apply_phase_visuals()


func _apply_phase_visuals() -> void:
	match _phase:
		Phase.PLAIN:
			scale = Vector3.ONE
			_material.albedo_color = _base_color
		Phase.PREPARING:
			scale = Vector3.ONE * PREPARE_SCALE
			_material.albedo_color = _base_color * PREPARE_BRIGHTNESS
		Phase.OPEN:
			var size: float
			var brightness: float = OPEN_BRIGHTNESS
			if _open_elapsed < OPEN_POP_SECONDS:
				# The pop: land at full oversize immediately and ease back, so the ONSET is
				# the loudest instant. A ramp-up would bury the moment being communicated.
				size = OPEN_POP_SCALE
				brightness += OPEN_PULSE_BRIGHTNESS_GAIN
			else:
				var wave: float = 0.5 + 0.5 * sin((_open_elapsed - OPEN_POP_SECONDS) * TAU * OPEN_PULSE_HZ)
				size = lerp(OPEN_PULSE_MIN, OPEN_PULSE_MAX, wave)
				brightness += OPEN_PULSE_BRIGHTNESS_GAIN * wave
			scale = Vector3.ONE * size
			_material.albedo_color = _base_color * brightness
