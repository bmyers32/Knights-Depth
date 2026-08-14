class_name ProjectileTracer
extends MeshInstance3D
## Minimum-viable projectile visual (no shader polish — playtest-before-polish law).
## Shared by the Watcher's ranged action and the player's guns; two real consumers on day
## one, so it is a shared component rather than speculative generality (§1.4 rule of two).
##
## COSMETIC PREDICTION, and the doctrine matters more than the code: this node
## EXTRAPOLATES (dead-reckons) from the spawn state SimWorld published in
## `projectile_fired`. It is NOT interpolating between sim states — the sim publishes no
## per-tick projectile position, and does not need to, because travel is a straight line
## at constant speed from a fixed origin. SimWorld remains authoritative for position,
## collision, hit and expiry; this node never writes sim state and never reports back
## (Prime Directive 1).
##
## A TRACER/SIM DISAGREEMENT IS ALWAYS A TRACER BUG. If a shot visually misses but the
## sim resolves a hit, the fix belongs here (or in the values fed to launch()), never in
## the sim's travel or sweep math.
##
## Lifetime is owned entirely by the driver: arena.gd frees this node on ANY event
## carrying its projectile_id — hit, blocked, shield_broken, attack_absorbed, or
## projectile_expired. This node never decides it is finished, which is what keeps a
## blocked shot from sailing on and reading as a hit-detection bug.

## Presentation-only geometry. Sized against the authored hit radii it stands in for
## (wand 0.40, watcher_survey 0.50) — close enough to read honestly without implying a
## precision the flat sphere does not have.
const RADIUS: float = 0.18

var _velocity: Vector3 = Vector3.ZERO
var _material := StandardMaterial3D.new()


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	mesh = sphere
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _material


## Called once, immediately after instantiation, with the spawn state from the
## `projectile_fired` payload plus the speed/colour the driver resolved from CONTENT
## (never from the Event — a tunable does not belong in an Event payload).
func launch(start_position: Vector3, direction: Vector3, speed: float, color: Color) -> void:
	position = start_position
	_velocity = direction.normalized() * speed
	_material.albedo_color = color


## _process, not _physics_process, and deliberately so: this is presentation
## interpolation, the ONE thing GAME-RULES §1.8 permits outside the fixed sim tick.
## Gameplay never reads this transform.
func _process(delta: float) -> void:
	position += _velocity * delta
