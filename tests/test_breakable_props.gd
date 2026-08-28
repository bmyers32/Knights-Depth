extends GutTest
## THE BREAKABLE INHERITANCE AUDIT, MADE EXECUTABLE.
##
## The pre-code audit (ROADMAP) found that registering a prop as an ordinary combatant would
## drag in six scans and ten reactions it has no business in, and would make scenery a valid
## attack target for enemies. The verdict was a dedicated prop seam sharing DETECTION only.
##
## This file is that verdict as assertions. Every "must NOT" below names something a combatant
## would have inherited -- if a future change quietly routes props back through
## _resolve_hit_on_target, these go red rather than the defect surfacing as an Ooze attacking
## a crate during a playtest.
##
## v1 semantics, exactly: weapon hit -> direct durability loss -> destroyed -> optionally
## reveal a contained interactable. Nothing else.

const PLAYER := 0
const ENEMY := 1
const CRATE := 100
const DT := 1.0 / 30.0
const ARENA := Rect2(-20.0, -20.0, 40.0, 40.0)

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(PLAYER, Vector3.ZERO, 4.0)
	sim.register_combatant(PLAYER, 500.0, &"envoy", 0, 0.4, &"player")
	sim.mark_run_persistent(PLAYER)
	sim.load_floor(WalkableBounds.new([ARENA] as Array[Rect2]), Vector3.ZERO)
	sim.register_patches([ARENA] as Array[Rect2])


func _sword(damage: float = 5.0, knockback: float = 0.0, status_id: StringName = &"") -> void:
	sim.register_weapon(&"test_sword", damage, &"force", 3.0, 80.0, knockback, 0, status_id, 1.0)
	sim.set_equipped_weapon(PLAYER, &"test_sword")


func _swing(aim: Vector3 = Vector3(0, 0, -1)) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": aim})] as Array[Command], DT)


func _kinds(events: Array[Event]) -> Array:
	var kinds: Array = []
	for event in events:
		kinds.append(event.kind)
	return kinds


# --- WHAT A PROP MUST DO ---------------------------------------------------------------

func test_a_melee_swing_damages_and_destroys_a_breakable() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -2.0), 0.8, 10.0)
	_sword(4.0)
	var kinds: Array = _kinds(_swing())
	assert_true(kinds.has("breakable_hit"), "a swing in reach must register on a prop")
	assert_almost_eq(float(sim._breakables[CRATE]["durability"]), 6.0, 0.001, "direct durability loss, no matrix")
	assert_false(kinds.has("breakable_destroyed"), "not yet")

	_swing(); _swing()
	assert_false(sim._breakables.has(CRATE), "and it is gone once durability runs out")


func test_destroying_a_breakable_reveals_what_it_concealed() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -2.0), 0.8, 1.0)
	sim.register_interactable(0, Vector3(0.0, 0.0, -2.0), 2.0, true)
	sim.register_trigger(0, FloorLayers.TRIGGER_BREAKABLE_DESTROYED, Rect2(), CRATE, true,
		[{"kind": FloorLayers.EFFECT_REVEAL_INTERACTABLE, "target_id": 0}])
	_sword(5.0)
	var kinds: Array = _kinds(_swing())
	assert_true(kinds.has("breakable_destroyed"))
	assert_true(kinds.has("interactable_revealed"), "search the environment -> discover progression control")
	assert_eq(sim._interactables[0]["state"], &"available")


func test_a_swing_out_of_reach_or_out_of_cone_leaves_a_prop_alone() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -8.0), 0.8, 10.0)
	_sword()
	assert_false(_kinds(_swing()).has("breakable_hit"), "out of reach")
	sim.register_breakable(101, Vector3(0.0, 0.0, 2.0), 0.8, 10.0)
	assert_false(_kinds(_swing(Vector3(0, 0, -1))).has("breakable_hit"), "behind the swing")


# --- WHAT A PROP MUST NOT INHERIT ------------------------------------------------------
# Each of these is a scan or reaction register_combatant would have conferred.

func test_a_breakable_is_not_a_combatant_in_any_registry() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -2.0), 0.8, 10.0)
	assert_false(sim._families.has(CRATE), "_families drives SIX scans -- a prop must never enter it")
	assert_false(sim._health.has(CRATE), "props have durability, not health")
	assert_false(sim._combat_radius.has(CRATE), "nor a combat footprint")
	assert_false(sim.entities.has(CRATE), "nor a position in the actor table")
	assert_false(sim._allegiance.has(CRATE), "nor a side")


## THE WORST CONSEQUENCE the audit predicted: _is_valid_target only compares allegiance, so a
## world-allegiance prop would have been a legitimate target for every enemy on the floor.
func test_enemies_never_target_scenery() -> void:
	sim.register_breakable(CRATE, Vector3(2.0, 0.0, 0.0), 0.8, 10.0)
	sim.add_entity(ENEMY, Vector3(4.0, 0.0, 0.0), 3.0)
	sim.register_combatant(ENEMY, 100.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"enemy_bite", 5.0, &"force", 2.0, 90.0, 0.0, 0)
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"enemy_bite", 2.0, 4),
		Vector3(4.0, 0.0, 0.0), 1.5, 0.0, 60.0, 500.0)
	sim.debug_set_ai_active(ENEMY)
	for i in 200:
		sim.tick([] as Array[Command], DT)
	assert_eq(float(sim._breakables[CRATE]["durability"]), 10.0,
		"an enemy attacked the scenery -- allegiance-only targeting is exactly the trap the audit found")


func test_a_breakable_grants_no_iframes_and_absorbs_no_hit() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -2.0), 0.8, 100.0)
	_sword(4.0)
	# Combatant i-frames would swallow the second and third swings entirely.
	_swing(); _swing(); _swing()
	assert_almost_eq(float(sim._breakables[CRATE]["durability"]), 88.0, 0.001,
		"every swing must land -- a prop has no invulnerability window")


func test_a_breakable_is_never_knocked_back() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -2.0), 0.8, 100.0)
	_sword(4.0, 8.0)
	_swing()
	assert_eq(sim._breakables[CRATE]["position"], Vector3(0.0, 0.0, -2.0), "scenery does not move")


func test_a_breakable_takes_no_status_and_joins_no_spread() -> void:
	sim.register_status(&"burn", 1.0, 5, 300)
	sim.set_status_priority({"burn": 1})
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -2.0), 0.8, 100.0)
	_sword(4.0, 0.0, &"burn")
	_swing()
	assert_false(sim._status_instances.has(CRATE), "a prop cannot burn")
	for i in 60:
		sim.tick([] as Array[Command], DT)
	assert_almost_eq(float(sim._breakables[CRATE]["durability"]), 96.0, 0.001, "and takes no damage over time")


func test_a_breakable_never_contributes_pressure_or_flinch() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -2.0), 0.8, 100.0)
	_sword(4.0)
	_swing()
	assert_false(sim._pressure_contributions.has(CRATE), "no pressure ledger")
	assert_false(sim._flinched_until_tick.has(CRATE), "nothing to flinch")
	assert_false(sim._flinch_thresholds.has(CRATE), "and no reaction profile")


func test_a_breakable_does_not_block_a_lunge_or_a_bump() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -2.0), 0.8, 1000.0)
	# Lunge clamp: _find_earliest_lunge_contact scans _families, which props are absent from.
	var profile: Dictionary = {
		"damage": 5.0, "damage_type": &"force", "reach": 3.0, "cone_half_angle_degrees": 80.0,
		"knockback_distance": 0.0, "fire_interval_ticks": 0, "status_id": &"",
		"status_proc_chance": 0.0, "interrupt_strength": 0, "lunge_distance": 6.0,
		"lunge_duration_ticks": 6, "hit_active_ticks": 4, "windup_ticks": 0,
	}
	var profiles: Array[Dictionary] = [profile, profile, profile]
	sim.register_melee_profiles(&"test_lunge", profiles, profile, 999, 50)
	sim.set_equipped_weapon(PLAYER, &"test_lunge")
	sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})] as Array[Command], DT)
	sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})] as Array[Command], DT)
	for i in 10:
		sim.tick([] as Array[Command], DT)
	assert_lt(sim.entities[PLAYER].z, -5.0,
		"the lunge stopped at the crate -- props must not be in the movement-blocking scan (P20 owns body collision)")


func test_a_breakable_never_blocks_burrow_emergence() -> void:
	sim.register_breakable(CRATE, Vector3(2.0, 0.0, 0.0), 2.0, 1000.0)
	assert_false(sim._families.has(CRATE),
		"_burrow_point_is_occupied scans _families; a prop outside it cannot become an unauthored burrow blocker")


# --- PROJECTILE RULING -------------------------------------------------------------------

func _gun(damage: float = 4.0) -> void:
	sim.register_gun(&"test_gun", damage, &"force", 12.0, 200, 0.2, 0.0, 0)
	sim.set_equipped_weapon(PLAYER, &"test_gun")


## RULED for v1: a shot registers, damages, and TERMINATES on a breakable. Props are therefore
## lightweight physical cover. Penetration is never the default.
func test_a_projectile_stops_on_a_breakable() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -6.0), 0.8, 100.0)
	_gun(4.0)
	sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
	var kinds: Array = []
	for i in 30:
		kinds.append_array(_kinds(sim.tick([] as Array[Command], DT)))
	assert_true(kinds.has("breakable_hit"), "the shot must register on the prop")
	assert_almost_eq(float(sim._breakables[CRATE]["durability"]), 96.0, 0.001, "and damage it")
	assert_true(sim._projectiles.is_empty(), "and terminate there -- props are cover, not pass-through")


## Cover means COVER: an enemy directly behind a prop is protected by it.
func test_a_breakable_shields_whatever_stands_behind_it() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -4.0), 1.0, 100.0)
	sim.add_entity(ENEMY, Vector3(0.0, 0.0, -8.0), 0.0)
	sim.register_combatant(ENEMY, 100.0, &"fang", 0, 0.6, &"enemy")
	_gun(4.0)
	sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
	for i in 30:
		sim.tick([] as Array[Command], DT)
	assert_eq(sim._health[ENEMY], 100.0, "the prop was between them -- the Fang must be untouched")


## And once the cover is gone, the same shot connects. Proves the previous test measured cover
## rather than a broken projectile path.
func test_the_same_shot_connects_once_the_cover_is_destroyed() -> void:
	sim.add_entity(ENEMY, Vector3(0.0, 0.0, -8.0), 0.0)
	sim.register_combatant(ENEMY, 100.0, &"fang", 0, 0.6, &"enemy")
	_gun(4.0)
	sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
	for i in 30:
		sim.tick([] as Array[Command], DT)
	assert_lt(sim._health[ENEMY], 100.0, "with no cover in the way the shot must land")


## Whichever is met FIRST stops the shot -- a prop behind the target does not steal the hit.
func test_a_prop_beyond_the_target_does_not_steal_the_hit() -> void:
	sim.add_entity(ENEMY, Vector3(0.0, 0.0, -4.0), 0.0)
	sim.register_combatant(ENEMY, 100.0, &"fang", 0, 0.6, &"enemy")
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -9.0), 0.8, 100.0)
	_gun(4.0)
	sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
	for i in 30:
		sim.tick([] as Array[Command], DT)
	assert_lt(sim._health[ENEMY], 100.0, "the nearer combatant takes the hit")
	assert_eq(float(sim._breakables[CRATE]["durability"]), 100.0, "and the prop behind it is untouched")


# --- SCOPE --------------------------------------------------------------------------------

func test_breakable_state_dies_with_the_floor() -> void:
	sim.register_breakable(CRATE, Vector3(0.0, 0.0, -2.0), 0.8, 10.0)
	sim.load_floor(WalkableBounds.new([ARENA] as Array[Rect2]), Vector3.ZERO)
	assert_eq(sim._breakables.size(), 0, "props belong to the floor that authored them")
