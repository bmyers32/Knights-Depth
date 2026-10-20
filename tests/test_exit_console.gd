extends GutTest
## THE EXIT CONSOLE, at the sim seam (M2 expedition frame, Slice 1, ruled 2026-10-19).
##
## The console is read with the PRIMARY ATTACK PRESS, arbitrated by the same rule that lifts a key:
## enemy under the aim -> attack; carrying -> drop/deliver; a loose key focused -> lift; the console
## focused -> inspect; otherwise -> attack. These tests drive that press against a bare SimWorld, so
## every rule below is the sim's. What the console SHOWS is presentation's (test_expedition_flow).

const DT := 1.0 / 30.0
const PLAYER := 0
const ENEMY := 1
const CONSOLE := 0
const KEY := 7
const SWORD := &"test_console_sword"
const GUN := &"test_console_gun"
const ROOM := Rect2(-20.0, -10.0, 40.0, 20.0)
const REACH := 2.0
const HALF_ANGLE := 60.0
const UNDERFOOT := 0.45
const CHARGE_THRESHOLD := 5
## West of the Envoy, within reach; the enemy stands east, so the two never share a cone.
const CONSOLE_AT := Vector3(-1.5, 0.0, 0.0)
const TOWARD_CONSOLE := Vector3(-1.5, 0.0, 0.0)

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.seed_combat_rng(1)
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	sim.add_entity(PLAYER, Vector3.ZERO, 4.0, Vector3(0, 0, -1), 0.45)
	sim.register_combatant(PLAYER, 100.0, &"envoy", 0, 0.45, &"player")
	sim.register_carrier(PLAYER, REACH, HALF_ANGLE, UNDERFOOT)
	sim.add_entity(ENEMY, Vector3(3.0, 0.0, 0.0), 0.0, Vector3(-1, 0, 0), 0.5)
	sim.register_combatant(ENEMY, 999.0, &"test_target", 0, 0.5)
	var combo: Array[Dictionary] = [_profile(), _profile(), _profile()]
	sim.register_melee_profiles(SWORD, combo, _profile(), CHARGE_THRESHOLD, 10)
	sim.register_gun(GUN, 5.0, &"force", 40.0, 60, 0.2, 0.0)
	sim.set_weapon_loadout(PLAYER, [SWORD, GUN] as Array[StringName])
	sim.set_equipped_weapon(PLAYER, SWORD)
	sim.register_exit_console(CONSOLE, CONSOLE_AT)


func _profile() -> Dictionary:
	return {
		"damage": 5.0, "damage_type": &"force", "reach": 4.0, "cone_half_angle_degrees": 60.0,
		"knockback_distance": 0.0, "fire_interval_ticks": 0, "status_id": &"",
		"status_proc_chance": 0.0, "lunge_duration_ticks": 0, "hit_active_ticks": 0,
	}


func _tick(commands: Array = []) -> Array[Event]:
	var typed: Array[Command] = []
	typed.assign(commands)
	return sim.tick(typed, DT)


func _attack(phase: String, aim: Vector3) -> Command:
	return Command.new(sim.tick_count, PLAYER, "attack", {"aim": aim, "phase": phase})


func _kinds(events: Array[Event]) -> Array[String]:
	var kinds: Array[String] = []
	for event in events:
		kinds.append(event.kind)
	return kinds


## A whole press -> held... -> release, the way envoy.gd sends it.
func _click(aim: Vector3, held_ticks: int = 0) -> Array[Event]:
	var events: Array[Event] = _tick([_attack("pressed", aim)])
	for i in held_ticks:
		events.append_array(_tick([_attack("held", aim)]))
	events.append_array(_tick([_attack("released", aim)]))
	return events


# --- ARBITRATION ---------------------------------------------------------------------------

func test_aiming_generally_at_the_console_focuses_it() -> void:
	# Not on it: 40 degrees off the line to it, inside the 60-degree cone.
	var aim := Vector3(-1.0, 0.0, tan(deg_to_rad(40.0)))
	assert_eq(sim.interaction_focus(PLAYER, aim), {"kind": "inspect", "console_id": CONSOLE})


func test_the_console_is_not_focused_out_of_reach_behind_or_underfoot() -> void:
	assert_eq(sim.interaction_focus(PLAYER, Vector3(1, 0, 0)), {}, "behind the aim: the press is a swing")
	sim.entities[PLAYER] = CONSOLE_AT + Vector3(REACH + 0.1, 0.0, 0.0)
	assert_eq(sim.interaction_focus(PLAYER, Vector3(-1, 0, 0)), {}, "out of reach")
	sim.entities[PLAYER] = CONSOLE_AT
	assert_eq(sim.interaction_focus(PLAYER, Vector3(-1, 0, 0)), {}, "standing in it: no direction, no focus")


func test_aiming_at_an_enemy_is_always_an_attack() -> void:
	sim.entities[ENEMY] = Vector3(-1.2, 0.0, 0.0)  # in front of the console, on the same line
	assert_eq(sim.interaction_focus(PLAYER, Vector3(-1.2, 0.0, 0.0)), {}, "the cursor is on the enemy")


func test_a_loose_key_outranks_the_console() -> void:
	sim.register_carriable(KEY, Vector3(-1.0, 0.0, 0.4))
	assert_eq(sim.interaction_focus(PLAYER, TOWARD_CONSOLE), {"kind": "lift", "carriable_id": KEY},
		"progression before an optional read")


func test_carrying_drops_rather_than_inspects() -> void:
	sim.register_carriable(KEY, Vector3(-1.0, 0.0, 0.4))
	_click(TOWARD_CONSOLE)
	assert_eq(sim.carried_by(PLAYER), KEY, "sanity: carrying")
	assert_eq(sim.interaction_focus(PLAYER, TOWARD_CONSOLE)["kind"], "drop")


func test_a_swing_in_motion_owns_the_press() -> void:
	sim.register_melee_profiles(SWORD, [_lunging(), _lunging(), _lunging()] as Array[Dictionary], _lunging(), CHARGE_THRESHOLD, 10)
	_click(Vector3(1, 0, 0))
	assert_eq(String(sim._melee_hold.get(PLAYER, {}).get("state", "")), "executing", "sanity: mid-swing")
	assert_eq(sim.interaction_focus(PLAYER, TOWARD_CONSOLE), {}, "buffered as a swing, as with a key")


func _lunging() -> Dictionary:
	var profile: Dictionary = _profile()
	profile["lunge_duration_ticks"] = 6
	return profile


# --- THE PRESS IS SPENT ON READING ---------------------------------------------------------

func test_inspecting_emits_one_event_and_changes_no_floor_state() -> void:
	var entities: Dictionary = sim.entities.duplicate(true)
	var health: Dictionary = sim._health.duplicate(true)
	var triggers_fired: Dictionary = sim._triggers_fired.duplicate(true)
	var events: Array[Event] = _tick([_attack("pressed", TOWARD_CONSOLE)])
	assert_eq(_kinds(events), ["exit_console_inspected"] as Array[String])
	assert_eq(events[0].payload, {"console_id": CONSOLE, "actor_id": PLAYER})
	assert_eq(sim.entities, entities)
	assert_eq(sim._health, health)
	assert_eq(sim._triggers_fired, triggers_fired)
	assert_false(sim._floor_complete)


## One press never both reads and swings -- not as a tap, not as a charge held to full.
func test_a_sword_press_on_the_console_never_swings_or_charges() -> void:
	for held_ticks: int in [0, CHARGE_THRESHOLD + 3]:
		var kinds: Array[String] = _kinds(_click(TOWARD_CONSOLE, held_ticks))
		assert_has(kinds, "exit_console_inspected")
		assert_does_not_have(kinds, "melee_swing", "held %d" % held_ticks)
		assert_does_not_have(kinds, "charge_ready", "held %d" % held_ticks)
		assert_false(sim._melee_hold.has(PLAYER), "held %d: no hold opened" % held_ticks)
		assert_false(sim._melee_buffered_press.has(PLAYER))


func test_a_gun_press_on_the_console_never_fires() -> void:
	sim.set_equipped_weapon(PLAYER, GUN)
	var kinds: Array[String] = _kinds(_click(TOWARD_CONSOLE, 4))
	assert_has(kinds, "exit_console_inspected")
	assert_does_not_have(kinds, "projectile_fired")
	assert_eq(sim._projectiles.size(), 0)


## A combo step left open before the read does not resume after it.
func test_reading_clears_a_pending_combo_step() -> void:
	_click(Vector3(1, 0, 0))
	assert_true(sim._combo_index.has(PLAYER), "sanity: mid-combo")
	_click(TOWARD_CONSOLE)
	assert_false(sim._combo_index.has(PLAYER))


## THE FOCUS PREDICTS THE PRESS: across a sweep of aims, "inspect" is focused exactly when the
## press reads the console.
func test_the_focus_predicts_the_press_exactly() -> void:
	var reads: int = 0
	var swings: int = 0
	for degrees: int in range(0, 360, 15):
		var aim := Vector3(cos(deg_to_rad(degrees)), 0.0, sin(deg_to_rad(degrees))) * 1.5
		var predicted: bool = sim.interaction_focus(PLAYER, aim).get("kind", "") == "inspect"
		var kinds: Array[String] = _kinds(_click(aim))
		assert_eq(kinds.has("exit_console_inspected"), predicted, "aim %d degrees" % degrees)
		reads += 1 if predicted else 0
		swings += 1 if kinds.has("melee_swing") else 0
		_tick()
		for i in 12:  # let any swing finish before the next aim
			_tick()
	assert_gt(reads, 0, "sanity: some aims read the console")
	assert_gt(swings, 0, "sanity: and the rest swung")


func test_within_reach_ignores_the_aim_and_ends_at_the_reach() -> void:
	assert_true(sim.exit_console_within_reach(PLAYER, CONSOLE))
	sim.entities[PLAYER] = CONSOLE_AT + Vector3(REACH, 0.0, 0.0)
	assert_true(sim.exit_console_within_reach(PLAYER, CONSOLE), "inclusive at the edge")
	sim.entities[PLAYER] = CONSOLE_AT + Vector3(REACH + 0.01, 0.0, 0.0)
	assert_false(sim.exit_console_within_reach(PLAYER, CONSOLE))
	assert_false(sim.exit_console_within_reach(PLAYER, CONSOLE + 1), "no such console")


func test_the_console_belongs_to_its_floor() -> void:
	sim.mark_run_persistent(PLAYER)
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	assert_eq(sim.interaction_focus(PLAYER, TOWARD_CONSOLE), {}, "a new floor has only the console it registers")
