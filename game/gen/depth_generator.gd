class_name DepthGenerator
extends RefCounted
## DepthGenerator.generate(seed, depth) -> FloorPlan — the pinned Core Interface
## (CLAUDE.md, "do not drift").
##
## SEED HONESTY, stated plainly because it is easy to imply otherwise: for this prototype the
## layout is HAND-AUTHORED, so **different seeds do not currently produce different spatial
## layouts.** The seed remains canonical reproduction metadata (§1.3: a bug report is seed +
## command log) and every plan still records it, but procedural spatial variation is DEFERRED
## until the floor grammar itself is validated. The plan carries `authored_layout = true` so
## the driver can say so on screen rather than advertising variety that does not exist.
##
## The signature is kept intact rather than replaced by a `load_layout()` call so that turning
## procedural assembly back on is a change of body, not a change of contract.

const _SLICE_STRATUM: StringName = &"archive"

const _LAYOUT_PROTOTYPE: String = "res://game/content/layouts/archive_prototype.tres"
const _LAYOUT_ROUNDABOUT: String = "res://game/content/layouts/archive_roundabout.tres"
const _LAYOUT_TERMINAL: String = "res://game/content/layouts/terminal.tres"
## WHERE THE TERMINAL CURRENTLY SITS -- content placement, not a world rule (ruled 2026-10-12).
## The layout itself knows nothing about this number, so inserting Archive floors above it later
## moves this constant and touches no content.
const _TERMINAL_DEPTH: int = 3

## 64-bit odd constants (PCG's multiplier and increment). Chosen over String.hash() on purpose:
## hash() is stable within an engine version but NOT guaranteed across them, and GAME-RULES §5's
## golden-seed gate has to survive a Godot patch bump. GDScript ints are int64 and multiplication
## overflow wraps two's-complement, which is deterministic.
const _SEED_MIX_A: int = 6364136223846793005
const _SEED_MIX_B: int = 1442695040888963407


static func generate(seed: int, depth: int) -> FloorPlan:
	var stratum: StratumConfig = ContentDB.get_resource(&"stratum", _SLICE_STRATUM)
	var plan := FloorPlan.new()
	plan.run_seed = seed
	plan.depth = depth
	plan.floor_seed = derive_floor_seed(seed, depth)
	plan.stratum_id = stratum.stratum_id
	plan.authored_layout = true
	# THREE AUTHORED FLOORS, selected by DEPTH. Still not a layout framework. The third entry would
	# ordinarily be the moment to abstract (§1.4), and it deliberately is not (ruled 2026-10-12):
	# Foundry is the consumer that will show whether selection is by depth or by stratum, and a
	# table built before that would be a guess. When procedural assembly returns it replaces this
	# body, not the signature.
	#
	# THE FLOORS ARE CONTENT NOW (P36 Slice A). They were builder functions; they are .tres. Only
	# the authored VALUES moved, which is what a representation migration means. The compiler
	# copies rather than aliases: a loaded resource is shared by path, and a plan that pointed at
	# it would let one run's state reach the next.
	LayoutCompiler.compile(load(_layout_path_for(depth)), plan)
	# STRUCTURAL VALIDATION RUNS ON EVERY PLAN, whoever produced it. Placed here rather than in
	# each layout so a future procedural producer inherits the guards without being asked to
	# remember them. Detection only -- a plan is never silently repaired.
	plan.validate(_authored_body_radii(plan))
	return plan


## Every depth other than the Terminal's resolves exactly as it did before the Terminal existed.
static func _layout_path_for(depth: int) -> String:
	if depth == _TERMINAL_DEPTH:
		return _LAYOUT_TERMINAL
	return _LAYOUT_ROUNDABOUT if depth >= 2 else _LAYOUT_PROTOTYPE


## The combat radius of every enemy this plan places, so the clearance guard can measure real
## doorways against real bodies. Looked up HERE rather than inside FloorPlan, which must stay a
## plain data class with no autoload reach.
static func _authored_body_radii(plan: FloorPlan) -> Dictionary:
	var radii: Dictionary = {}
	for encounter in plan.encounters:
		for spawn: Dictionary in encounter.roster:
			var key: StringName = spawn.get("enemy_key", &"")
			if key == &"" or radii.has(key):
				continue
			var stats: Resource = ContentDB.get_resource(&"enemy", key)
			if stats != null:
				radii[key] = stats.combat_radius
	return radii


## Derives this floor's seed from the run seed and the depth. Unused by the authored layout but
## kept live and tested: it is the one piece of the procedural path whose determinism must not
## silently rot while assembly is switched off.
static func derive_floor_seed(run_seed: int, depth: int) -> int:
	var mixed: int = run_seed * _SEED_MIX_A + depth * _SEED_MIX_B
	mixed ^= mixed >> 31
	mixed = mixed * _SEED_MIX_A
	mixed ^= mixed >> 29
	return mixed
