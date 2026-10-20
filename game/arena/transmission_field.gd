class_name TransmissionField
extends Node3D
## The descent, as installed infrastructure transmitting the Envoy (M2 expedition frame, Slice 1,
## revised 2026-10-19 after the sinking lift read as clipping): the pad wakes, a pale field rises
## around the Envoy, thin rings climb it, the Envoy brightens into light and is gone. On arrival
## the light fades off the Envoy where it stands.
##
## IT OWNS NO TIMING THAT MATTERS. During a descent every value is a function of the Expedition's
## descent_progress(), set once per sim-rate tick (show_progress); only the arrival fade runs on
## presentation time, over a floor that is already live. The Envoy MODEL is never scaled or
## deformed (ruled: it must read as transmission, not squashing) -- only shown or hidden, with a
## glow shell over it doing the work.
##
## Primitive meshes and one unshaded additive material each. No shader, no animation framework.

## Field size around the pad's centre.
@export var field_radius: float = 1.4
@export var field_height: float = 3.6
## The field's peak opacity -- restrained on purpose: a veil of light, not a booth.
@export var field_alpha: float = 0.16
@export var ring_count: int = 3
## How many times each ring climbs the field over a whole descent.
@export var ring_climbs: float = 2.0
## Progress at which the Envoy is fully light and disappears.
@export var vanish_progress: float = 0.62
## Seconds the arrival glow takes to fade off the Envoy. Presentation time only.
@export var arrival_seconds: float = 0.6

## Pale and slightly cold: Lattice light, not a neon tube.
const _FIELD_COLOR: Color = Color(0.78, 0.90, 0.92)
const _SHELL_RADIUS: float = 0.55
const _SHELL_HEIGHT: float = 2.0
const _RING_THICKNESS: float = 0.04

var _column: MeshInstance3D
var _base: MeshInstance3D
var _shell: MeshInstance3D
var _rings: Array[MeshInstance3D] = []
var _arrival_remaining: float = 0.0


func _ready() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = field_radius
	cylinder.bottom_radius = field_radius
	cylinder.height = 1.0  # scaled to the field's current height
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	_column = _part(cylinder)
	_base = _part(_ring_mesh(field_radius + 0.15, 0.08))
	for i in ring_count:
		_rings.append(_part(_ring_mesh(field_radius, _RING_THICKNESS)))
	var capsule := CapsuleMesh.new()
	capsule.radius = _SHELL_RADIUS
	capsule.height = _SHELL_HEIGHT
	_shell = _part(capsule)
	reset()


## The pad at `at` (its grounded centre) begins transmitting the Envoy standing on it.
func begin(at: Vector3) -> void:
	_arrival_remaining = 0.0
	position = at
	visible = true
	show_progress(0.0)


## One sim-rate tick's picture of the descent. Returns whether the Envoy is still visible: the
## driver shows or hides it from this, so the two can never disagree about when it left.
func show_progress(progress: float) -> bool:
	var wake: float = smoothstep(0.0, 0.15, progress)
	_set_alpha(_base, 0.25 + 0.6 * wake)
	var rise: float = smoothstep(0.05, 0.45, progress)
	_column.scale = Vector3(1.0, maxf(rise * field_height, 0.001), 1.0)
	_column.position = Vector3(0.0, rise * field_height * 0.5, 0.0)
	_set_alpha(_column, field_alpha * smoothstep(0.08, 0.40, progress))
	var rings_on: float = smoothstep(0.10, 0.35, progress)
	for i in _rings.size():
		var phase: float = fposmod(progress * ring_climbs + float(i) / float(_rings.size()), 1.0)
		_rings[i].position = Vector3(0.0, phase * field_height * rise, 0.0)
		_set_alpha(_rings[i], 0.55 * rings_on * sin(PI * phase))
	# The Envoy brightens into light, the light holds as the Envoy goes, then climbs out of sight.
	var gone: float = smoothstep(vanish_progress, 0.88, progress)
	_set_alpha(_shell, 0.75 * smoothstep(0.40, vanish_progress, progress) * (1.0 - gone))
	_shell.position = Vector3(0.0, _SHELL_HEIGHT * 0.5 + gone * field_height * 0.6, 0.0)
	_shell.scale = Vector3(1.0 - 0.7 * gone, 1.0 + 0.4 * gone, 1.0 - 0.7 * gone)
	return progress < vanish_progress


## The Envoy has arrived at `at`: the light fades off it there. The descent's field is put away.
func arrive(at: Vector3) -> void:
	position = at
	visible = true
	_column.visible = false
	_base.visible = false
	for ring in _rings:
		ring.visible = false
	_shell.visible = true
	_shell.position = Vector3(0.0, _SHELL_HEIGHT * 0.5, 0.0)
	_shell.scale = Vector3.ONE
	_arrival_remaining = arrival_seconds
	_set_alpha(_shell, 0.75)


## Nothing showing, nothing pending. Every boundary that is not an arrival ends here.
func reset() -> void:
	_arrival_remaining = 0.0
	visible = false
	for part: MeshInstance3D in [_column, _base, _shell] + _rings:
		part.visible = true
		_set_alpha(part, 0.0)


func is_showing() -> bool:
	return visible


func _process(delta: float) -> void:
	if _arrival_remaining <= 0.0:
		return
	_arrival_remaining -= delta
	var left: float = clampf(_arrival_remaining / arrival_seconds, 0.0, 1.0)
	_set_alpha(_shell, 0.75 * left)
	if _arrival_remaining <= 0.0:
		reset()


func _ring_mesh(radius: float, thickness: float) -> TorusMesh:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - thickness
	torus.outer_radius = radius
	return torus


func _part(mesh: Mesh) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(_FIELD_COLOR, 0.0)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _set_alpha(part: MeshInstance3D, alpha: float) -> void:
	(part.material_override as StandardMaterial3D).albedo_color.a = alpha
