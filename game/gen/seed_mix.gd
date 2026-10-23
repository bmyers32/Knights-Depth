class_name SeedMix
extends RefCounted
## THE ONE SEED-DERIVATION FUNCTION, in a class that depends on nothing (ADR-001 S2).
##
## DepthGenerator.derive_floor_seed has always been this arithmetic; it moved here, unchanged,
## because DepthGenerator reaches the ContentDB autoload and the composer must not -- a `-s`
## tool script (no autoloads) that compiles a floor would otherwise fail to compile at all.
## DepthGenerator still exposes derive_floor_seed and delegates to this, so every caller and
## every golden is untouched.
##
## 64-bit odd constants (PCG's multiplier and increment). Chosen over String.hash() on purpose:
## hash() is stable within an engine version but NOT guaranteed across them, and GAME-RULES §5's
## golden-seed gate has to survive a Godot patch bump. GDScript ints are int64 and multiplication
## overflow wraps two's-complement, which is deterministic.

const MIX_A: int = 6364136223846793005
const MIX_B: int = 1442695040888963407


## Derives a child seed from a parent seed and a salt (a depth, a stream number, an attempt).
static func derive(parent_seed: int, salt: int) -> int:
	var mixed: int = parent_seed * MIX_A + salt * MIX_B
	mixed ^= mixed >> 31
	mixed = mixed * MIX_A
	mixed ^= mixed >> 29
	return mixed
