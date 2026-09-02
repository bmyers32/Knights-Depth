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
	# TWO AUTHORED FLOORS, selected by DEPTH. Not a layout framework -- a two-entry decision, per
	# §1.4: copy twice before abstracting. When procedural assembly returns it replaces this body,
	# not the signature.
	if depth >= 2:
		ArchiveRoundaboutLayout.build(plan)
	else:
		ArchivePrototypeLayout.build(plan)
	# STRUCTURAL VALIDATION RUNS ON EVERY PLAN, whoever produced it. Placed here rather than in
	# each layout so a future procedural producer inherits the guards without being asked to
	# remember them. Detection only -- a plan is never silently repaired.
	plan.validate()
	return plan


## Derives this floor's seed from the run seed and the depth. Unused by the authored layout but
## kept live and tested: it is the one piece of the procedural path whose determinism must not
## silently rot while assembly is switched off.
static func derive_floor_seed(run_seed: int, depth: int) -> int:
	var mixed: int = run_seed * _SEED_MIX_A + depth * _SEED_MIX_B
	mixed ^= mixed >> 31
	mixed = mixed * _SEED_MIX_A
	mixed ^= mixed >> 29
	return mixed
