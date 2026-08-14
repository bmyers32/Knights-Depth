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

## ===========================================================================
## PROJECTILE PRESENTATION LAW (durable, ruled 2026-08-14 — this is its home)
## ===========================================================================
## "Projectile presentation represents the projectile's OWN volume: visual width ≈
##  projectile.hit_radius, at VISUAL_SCALE = 1.0. The collision threshold is
##  projectile.hit_radius + target.combat_radius; that Minkowski sum exists ONLY in
##  collision space and is NEVER drawn."
##
## Why the sum is never drawn: the summed radius is not a property of any object on
## screen. It is the distance at which two volumes touch. Drawing it would depict a
## projectile the size of the shot PLUS its target's body — an object that does not
## exist, and one that would grow or shrink depending on who it happened to be flying at.
##
## CAUTIONARY CASE, recorded because it happened here: the diagnostic that FOUND the
## geometry defect (tools/diagnose_projectile_geometry.gd) then made this very mistake in
## reverse — it compared the tracer's width against the SUMMED radius and reported a
## "TRACER-LIE" that was not one, i.e. it demanded the sum be drawn. The instrument that
## discovers a rule is not exempt from it.
##
## READABILITY DISCIPLINE (binding): if a projectile reads poorly, fix it with NON-WIDTH
## levers — trail, persistence, brightness/contrast, departure and impact cues. Never
## widen collision to buy visibility, and never widen the drawn width past the collision
## radius: lateral radius is gameplay geometry, not a display setting.
##
## HISTORY: the tracer originally drew a fixed 0.18 against an authoritative 0.40/0.50 —
## under half — which is what "apparent hits that miss" partly was. VISUAL_SCALE is the
## one named knob; 1.0 draws exactly the projectile's own volume, and values below 1.0
## reintroduce the lie.
const VISUAL_SCALE: float = 1.0
## Used only if a caller supplies no authoritative radius; keeps a tracer visible rather
## than degenerate. Not a tuning value.
const FALLBACK_RADIUS: float = 0.18

var _velocity: Vector3 = Vector3.ZERO
var _material := StandardMaterial3D.new()
var _radius: float = FALLBACK_RADIUS


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = _radius
	sphere.height = _radius * 2.0
	mesh = sphere
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _material


## Called once, immediately after instantiation, with the spawn state from the
## `projectile_fired` payload plus the speed/colour the driver resolved from CONTENT
## (never from the Event — a tunable does not belong in an Event payload).
## hit_radius is the AUTHORITATIVE volume this shot resolves with; the tracer draws that,
## scaled by VISUAL_SCALE, so what the player sees is what the sim tests.
func launch(start_position: Vector3, direction: Vector3, speed: float, color: Color, hit_radius: float = 0.0) -> void:
	position = start_position
	_velocity = direction.normalized() * speed
	_material.albedo_color = color
	_radius = (hit_radius * VISUAL_SCALE) if hit_radius > 0.0 else FALLBACK_RADIUS
	# _ready() may already have built the mesh at the fallback size (launch is called
	# right after add_child), so rebuild rather than assume ordering.
	var sphere := SphereMesh.new()
	sphere.radius = _radius
	sphere.height = _radius * 2.0
	mesh = sphere


## _process, not _physics_process, and deliberately so: this is presentation
## interpolation, the ONE thing GAME-RULES §1.8 permits outside the fixed sim tick.
## Gameplay never reads this transform.
func _process(delta: float) -> void:
	position += _velocity * delta
