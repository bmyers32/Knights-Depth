extends GutTest
## CARRYING (Floor 4 Stage 2, ruled 2026-10-16), at the sim seam.
##
## The primary attack press carries everything: deliver, drop, lift, or -- only when none of those
## applies -- an ordinary attack. These tests drive the shipped verb the shipped way (pressed /
## held / released Commands) against a bare SimWorld, so every rule below is the sim's, not the
## presentation's.

const DT := 1.0 / 30.0
const PLAYER := 0
const ENEMY := 1
## Ids deliberately unlike the actor ids, so a namespace mix-up cannot pass by accident.
const KEY := 7
const SECOND_KEY := 8
const RECEIVER := 3
const DOOR := 4
const SWORD := &"test_carry_sword"
const SLOW_SWORD := &"test_carry_slow_sword"
const GUN := &"test_carry_gun"
const BITE := &"test_carry_bite"
const HARMLESS := &"test_carry_harmless_burn"
const ROOM := Rect2(-20.0, -10.0, 40.0, 20.0)
const RECEIVER_REGION := Rect2(-12.0, -2.0, 4.0, 4.0)
const REACH := 2.0
const HALF_ANGLE := 60.0
const UNDERFOOT := 0.45
const LIFT_WATCHER := 5
const CHARGE_THRESHOLD := 5

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.seed_combat_rng(1)
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	sim.register_connection(DOOR, Rect2(20.0, -2.0, 4.0, 4.0), false)
	sim.add_entity(PLAYER, Vector3.ZERO, 4.0, Vector3(0, 0, -1), 0.45)
	sim.register_combatant(PLAYER, 100.0, &"envoy", 0, 0.45, &"player")
	sim.register_carrier(PLAYER, REACH, HALF_ANGLE, UNDERFOOT)
	sim.add_entity(ENEMY, Vector3(3.0, 0.0, 0.0), 0.0, Vector3(-1, 0, 0), 0.5)
	sim.register_combatant(ENEMY, 999.0, &"test_target", 0, 0.5)
	var combo: Array[Dictionary] = [_profile(5.0), _profile(5.0), _profile(5.0)]
	sim.register_melee_profiles(SWORD, combo, _profile(20.0), CHARGE_THRESHOLD, 10)
	sim.register_gun(GUN, 5.0, &"force", 40.0, 60, 0.2, 0.0)
	sim.register_weapon(BITE, 6.0, &"force", 4.0, 60.0, 0.0)
	sim.set_weapon_loadout(PLAYER, [SWORD, GUN] as Array[StringName])
	sim.set_equipped_weapon(PLAYER, SWORD)
	sim.set_equipped_weapon(ENEMY, BITE)
	sim.register_carriable(KEY, Vector3(1.0, 0.0, 0.0))
	sim.register_trigger(RECEIVER, FloorLayers.TRIGGER_CARRIABLE_INSERTED, RECEIVER_REGION, -1, true,
		[FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)])


func _profile(damage: float, lunge_ticks: int = 0, hit_ticks: int = 0, fire_interval: int = 0) -> Dictionary:
	return {
		"damage": damage, "damage_type": &"force", "reach": 4.0, "cone_half_angle_degrees": 60.0,
		"knockback_distance": 0.0, "fire_interval_ticks": fire_interval, "status_id": &"",
		"status_proc_chance": 0.0, "lunge_duration_ticks": lunge_ticks, "hit_active_ticks": hit_ticks,
	}


func _tick(commands: Array = []) -> Array[Event]:
	var typed: Array[Command] = []
	typed.assign(commands)
	return sim.tick(typed, DT)


func _attack(phase: String, aim: Vector3) -> Command:
	return Command.new(sim.tick_count, PLAYER, "attack", {"aim": aim, "phase": phase})


func _press(aim: Vector3) -> Array[Event]:
	return _tick([_attack("pressed", aim)])


func _release(aim: Vector3) -> Array[Event]:
	return _tick([_attack("released", aim)])


## One click: press then release, plus enough idle ticks for any swing to resolve.
func _click(aim: Vector3, settle: int = 30) -> Array[Event]:
	var events: Array[Event] = _press(aim)
	events.append_array(_release(aim))
	for i in settle:
		events.append_array(_tick())
	return events


func _aim_at(point: Vector3) -> Vector3:
	return point - sim.entities[PLAYER]


func _key_at(carriable_id: int = KEY) -> Vector3:
	return sim._carriables[carriable_id]["position"]


func _kinds(events: Array[Event]) -> Array:
	return events.map(func(event: Event) -> String: return event.kind)


func _swung(events: Array[Event]) -> bool:
	var kinds: Array = _kinds(events)
	return kinds.has("melee_swing") or kinds.has("projectile_fired") or kinds.has("charge_ready")


func _lift() -> void:
	var events: Array[Event] = _click(_aim_at(_key_at()), 0)
	assert_true(_kinds(events).has("carriable_lifted"), "sanity: the key was lifted")
	assert_eq(sim.carried_by(PLAYER), KEY)


## An aim `degrees` off the line from the Envoy to the key (which lies due +x of it), at the given
## length -- the length is where the cursor is, the angle is what focus reads.
func _aim_off_key(degrees: float, length: float = 3.0) -> Vector3:
	var radians: float = deg_to_rad(degrees)
	return Vector3(cos(radians), 0.0, sin(radians)) * length


func _enemy_bite() -> Array[Event]:
	return _tick([Command.new(sim.tick_count, ENEMY, "attack", {"aim": Vector3(-1, 0, 0)})])


# --- 1: FOCUS: the way you aim, not a pixel on the key (revised 2026-10-16) ---------------------
#
# The Envoy stands at the origin, the key 1.0 due east, the enemy 3.0 due east -- the key and the
# enemy are deliberately ALIGNED, so the enemy-priority rule is under test in every case below.

func test_the_cursor_need_not_touch_the_key() -> void:
	# The cursor's point is 4 units past the key and 1.4 off its line: nowhere near it, and not on
	# the enemy either. Pointing generally at the key is enough.
	var aim := Vector3(5.0, 0.0, 1.4)
	assert_gt((sim.entities[PLAYER] + aim).distance_to(_key_at()), 3.0, "sanity: the cursor is far from the key")
	assert_eq(sim.interaction_focus(PLAYER, aim), {"kind": "lift", "carriable_id": KEY})
	assert_true(_kinds(_click(aim)).has("carriable_lifted"))


func test_the_cone_boundary() -> void:
	assert_eq(sim.interaction_focus(PLAYER, _aim_off_key(HALF_ANGLE - 1.0)).get("kind", ""), "lift", "just inside")
	assert_eq(sim.interaction_focus(PLAYER, _aim_off_key(-(HALF_ANGLE - 1.0))).get("kind", ""), "lift", "either side")
	assert_eq(sim.interaction_focus(PLAYER, _aim_off_key(HALF_ANGLE + 1.0)), {}, "just outside")


func test_a_key_behind_you_is_not_focused_and_the_press_attacks() -> void:
	assert_eq(sim.interaction_focus(PLAYER, Vector3(-3, 0, 0)), {})
	var events: Array[Event] = _click(Vector3(-3, 0, 0))
	assert_false(_kinds(events).has("carriable_lifted"))
	assert_true(_kinds(events).has("melee_swing"), "the press is an ordinary attack")


func test_a_key_in_reach_but_aimed_away_from_is_not_focused() -> void:
	assert_eq(sim.interaction_focus(PLAYER, Vector3(0, 0, -3)), {}, "reach alone never focuses")
	assert_true(_kinds(_click(Vector3(0, 0, -3))).has("melee_swing"))


func test_aiming_at_a_key_out_of_reach_does_not_focus_it() -> void:
	sim._carriables[KEY]["position"] = Vector3(REACH + 0.1, 0.0, 0.0)
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())), {})
	sim._carriables[KEY]["position"] = Vector3(REACH - 0.1, 0.0, 0.0)
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())).get("kind", ""), "lift", "sanity: just inside reach")


## ENEMY ALIGNED WITH A KEY: the cursor on the enemy is an attack, even though the key lies on the
## very line of the swing; the cursor on the ground short of the enemy is a lift.
func test_an_enemy_under_the_cursor_wins_over_a_key_in_line_with_it() -> void:
	var on_enemy: Vector3 = _aim_at(sim.entities[ENEMY])
	assert_eq(sim.interaction_focus(PLAYER, on_enemy), {})
	var events: Array[Event] = _click(on_enemy)
	assert_true(_kinds(events).has("melee_swing"))
	assert_lt(sim.health_of(ENEMY), 999.0, "and the swing lands")
	assert_eq(sim.carried_by(PLAYER), -1)
	assert_eq(sim.interaction_focus(PLAYER, Vector3(2.0, 0, 0)).get("kind", ""), "lift", "the ground short of it is the key's")


func test_aiming_at_an_enemy_standing_on_a_key_attacks() -> void:
	sim.entities[ENEMY] = _key_at()
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())), {}, "an enemy under the cursor is a target, not a key")


## A KEY UNDER YOUR FEET HAS NO DIRECTION and is never focused; one step off it and aiming back is.
func test_a_key_under_your_feet_is_lifted_by_stepping_off_it_and_aiming_back() -> void:
	sim.entities[PLAYER] = _key_at() + Vector3(0.0, 0.0, UNDERFOOT * 0.5)
	for aim: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		assert_eq(sim.interaction_focus(PLAYER, aim), {}, "underfoot, aim %s" % aim)
	sim.entities[PLAYER] = _key_at() + Vector3(0.0, 0.0, 1.0)
	assert_eq(sim.interaction_focus(PLAYER, Vector3(0, 0, -1)).get("kind", ""), "lift")


func test_several_candidates_the_most_closely_aimed_at_wins() -> void:
	sim.entities[ENEMY] = Vector3(0.0, 0.0, 8.0)  # out of the way: this is about the keys
	sim._carriables[KEY]["position"] = Vector3(1.0, 0.0, 0.5)    # nearer, 26.6 degrees off
	sim.register_carriable(SECOND_KEY, Vector3(1.8, 0.0, -0.2))  # farther, 6.3 degrees off
	assert_eq(sim.interaction_focus(PLAYER, Vector3(3, 0, 0)).get("carriable_id", -1), SECOND_KEY, "alignment beats distance")
	sim._carriables[SECOND_KEY]["position"] = Vector3(1.8, 0.0, 0.9)  # now exactly in line with KEY
	assert_eq(sim.interaction_focus(PLAYER, Vector3(2, 0, 1)).get("carriable_id", -1), KEY, "in line: the nearer")
	sim._carriables[SECOND_KEY]["position"] = Vector3(1.0, 0.0, -0.5)  # mirror image of KEY
	assert_eq(sim.interaction_focus(PLAYER, Vector3(3, 0, 0)).get("carriable_id", -1), KEY, "a perfect tie: the lower id")


## ACTUALLY REACHABLE: a key in reach and in the cone, but across a gap in the floor or behind a
## mass, is not offered.
func test_a_key_across_a_gap_or_behind_a_mass_is_not_focused() -> void:
	var halves: Array[Rect2] = [Rect2(-20.0, -10.0, 20.4, 20.0), Rect2(0.8, -10.0, 19.2, 20.0)]
	sim._bounds = WalkableBounds.new(halves)
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())), {}, "across a void")
	var rects: Array[Rect2] = [ROOM]
	var mass: Array[Rect2] = [Rect2(0.5, -0.5, 0.2, 1.0)]
	sim._bounds = WalkableBounds.new(rects, mass)
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())), {}, "behind a mass")
	sim._bounds = WalkableBounds.new(rects)
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())).get("kind", ""), "lift", "sanity: open floor")


func test_zero_aim_focuses_nothing() -> void:
	sim.entities[PLAYER] = Vector3(-1.0, 0.0, 0.0)
	assert_eq(sim.interaction_focus(PLAYER, Vector3.ZERO), {})


func test_a_hidden_key_cannot_be_focused_until_revealed() -> void:
	sim.register_carriable(KEY, Vector3(1.0, 0.0, 0.0), true)
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())), {})
	var events: Array[Event] = sim._apply_floor_effect(FloorLayers.effect(FloorLayers.EFFECT_REVEAL_CARRIABLE, KEY))
	assert_eq(_kinds(events), ["carriable_revealed"])
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())).get("kind", ""), "lift")


func test_an_actor_without_carry_reach_never_lifts() -> void:
	sim.entities[ENEMY] = Vector3(2.0, 0.0, 0.0)
	assert_eq(sim.interaction_focus(ENEMY, Vector3(-1, 0, 0)), {}, "enemies stay out of the carrying rules")


## THE INDICATOR CANNOT LIE: for every aim tried, the focus query names exactly what the press does.
func test_the_focus_query_predicts_the_press() -> void:
	var aims: Array[Vector3] = [Vector3(0, 0, -3), _aim_at(_key_at()), Vector3(3, 0, 0), Vector3(5, 0, 1.4),
		_aim_off_key(HALF_ANGLE - 1.0), _aim_off_key(HALF_ANGLE + 1.0), Vector3(-3, 0, 0), Vector3(2, 0, 0)]
	for aim: Vector3 in aims:
		before_each()
		var predicted: Dictionary = sim.interaction_focus(PLAYER, aim)
		var events: Array[Event] = _press(aim)
		assert_eq(_kinds(events).has("carriable_lifted"), predicted.get("kind", "") == "lift", "aim %s" % aim)


# --- 2: ONE PRESS, ONE ACTION -------------------------------------------------------------------

func test_a_lift_press_produces_no_attack() -> void:
	var events: Array[Event] = _click(_aim_at(_key_at()))
	assert_true(_kinds(events).has("carriable_lifted"))
	assert_false(_swung(events), "the press was spent on the key")
	assert_eq(sim.health_of(ENEMY), 999.0)


func test_a_lift_press_held_past_the_charge_threshold_never_charges() -> void:
	var aim: Vector3 = _aim_at(_key_at())
	var events: Array[Event] = _press(aim)
	for i in CHARGE_THRESHOLD * 3:
		events.append_array(_tick([_attack("held", aim)]))
	events.append_array(_release(aim))
	for i in 30:
		events.append_array(_tick())
	assert_true(_kinds(events).has("carriable_lifted"))
	assert_false(_swung(events), "no phantom charge, tap or swing from the lifting press")


func test_the_gun_lifts_exactly_as_the_sword_does() -> void:
	sim.set_equipped_weapon(PLAYER, GUN)
	var events: Array[Event] = _click(_aim_at(_key_at()))
	assert_true(_kinds(events).has("carriable_lifted"))
	assert_false(_kinds(events).has("projectile_fired"))


func test_an_empty_handed_unfocused_gun_press_fires() -> void:
	sim.set_equipped_weapon(PLAYER, GUN)
	assert_true(_kinds(_click(Vector3(0, 0, -3))).has("projectile_fired"))


func test_pickup_is_refused_during_an_executing_swing() -> void:
	var slow: Array[Dictionary] = [_profile(5.0, 12, 4), _profile(5.0, 12, 4), _profile(5.0, 12, 4)]
	sim.register_melee_profiles(SLOW_SWORD, slow, _profile(20.0, 12, 4), CHARGE_THRESHOLD, 10)
	sim.set_equipped_weapon(PLAYER, SLOW_SWORD)
	_press(Vector3(0, 0, -3))
	_release(Vector3(0, 0, -3))
	assert_eq(String(sim.debug_describe_melee_state(PLAYER).get("state", "")), "executing", "sanity: mid-swing")
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())), {})
	var events: Array[Event] = _press(_aim_at(_key_at()))
	assert_false(_kinds(events).has("carriable_lifted"), "a swing in motion owns the press")
	assert_eq(sim.carried_by(PLAYER), -1)


func test_a_buffered_press_never_fires_after_a_lift() -> void:
	var cooled: Array[Dictionary] = [_profile(5.0, 0, 0, 20), _profile(5.0, 0, 0, 20), _profile(5.0, 0, 0, 20)]
	sim.register_melee_profiles(SLOW_SWORD, cooled, _profile(20.0, 0, 0, 20), CHARGE_THRESHOLD, 10, 30)
	sim.set_equipped_weapon(PLAYER, SLOW_SWORD)
	_click(Vector3(0, 0, -3), 2)
	_click(Vector3(0, 0, -3), 0)
	assert_true(sim.debug_describe_melee_state(PLAYER).has("buffered_weapon_id"), "sanity: a press is queued")
	_lift()
	var events: Array[Event] = []
	for i in 40:
		events.append_array(_tick())
	assert_false(_swung(events), "lifting discarded the queued press")


# --- 3: CARRYING ----------------------------------------------------------------------------------

func test_a_carrier_press_drops_the_key_at_their_feet_and_does_not_attack() -> void:
	_lift()
	sim.entities[PLAYER] = Vector3(-3.0, 0.0, 2.0)
	var events: Array[Event] = _click(Vector3(3, 0, 0))
	assert_true(_kinds(events).has("carriable_dropped"))
	assert_false(_swung(events), "the dropping press does not also attack")
	assert_eq(_key_at(), Vector3(-3.0, 0.0, 2.0))
	for event in events:
		if event.kind == "carriable_dropped":
			assert_eq(event.payload["reason"], "voluntary")


func test_a_held_button_after_a_drop_never_re_lifts() -> void:
	_lift()
	var aim: Vector3 = Vector3(0.05, 0, 0)  # straight down at the key that is about to land
	var events: Array[Event] = _press(aim)
	for i in 30:
		events.append_array(_tick([_attack("held", aim)]))
	events.append_array(_release(aim))
	assert_true(_kinds(events).has("carriable_dropped"))
	assert_false(_kinds(events).has("carriable_lifted"), "only a fresh press can lift")
	assert_false(_swung(events))
	assert_eq(sim.carried_by(PLAYER), -1)


## THE DROPPED-KEY FIGHT: the key lies at your feet, in reach, and the next press aimed at the
## enemy beside it is an attack -- the key does not hijack combat.
func test_fighting_beside_a_dropped_key_attacks() -> void:
	_lift()
	_click(Vector3(0, 0, -3), 0)
	assert_eq(sim.carried_by(PLAYER), -1, "sanity: dropped")
	var events: Array[Event] = _click(_aim_at(sim.entities[ENEMY]))
	assert_true(_kinds(events).has("melee_swing"), "the next press attacks")
	assert_lt(sim.health_of(ENEMY), 999.0, "and lands")
	assert_eq(sim.carried_by(PLAYER), -1, "the key stays where it fell")


## NO DROP -> LIFT -> DROP CYCLE: the key lands under your feet, so the next press -- aimed at
## nothing in particular, without moving -- is an ordinary attack, never a re-lift.
func test_the_press_after_a_voluntary_drop_is_an_attack_not_a_re_lift() -> void:
	_lift()
	_click(Vector3(0, 0, -3), 0)
	assert_eq(sim.carried_by(PLAYER), -1, "sanity: dropped")
	for aim: Vector3 in [Vector3(0, 0, -3), Vector3(0.3, 0, 0), Vector3(-2, 0, 1)]:
		var events: Array[Event] = _click(aim)
		assert_false(_kinds(events).has("carriable_lifted"), "aim %s" % aim)
		assert_true(_kinds(events).has("melee_swing"), "aim %s attacks" % aim)


func test_a_carrier_cannot_raise_the_shield_or_bump() -> void:
	sim.register_shield(PLAYER, 50.0, 1.0, 10, 0.5, 0.0, 1.0, 2, 0)
	_lift()
	var events: Array[Event] = _tick([Command.new(sim.tick_count, PLAYER, "block", {"held": true})])
	assert_true(_kinds(events).has("block_rejected"))
	assert_false(_kinds(events).has("shield_bumped"))
	assert_eq(String(sim._shield_state.get(PLAYER, "ready")), "ready")


func test_lifting_lowers_a_raised_shield_and_a_held_block_stays_down_after_the_drop() -> void:
	sim.register_shield(PLAYER, 50.0, 1.0, 10, 0.5)
	_tick([Command.new(sim.tick_count, PLAYER, "block", {"held": true})])
	assert_eq(String(sim._shield_state[PLAYER]), "held", "sanity: shield raised")
	_tick([_attack("pressed", _aim_at(_key_at())), Command.new(sim.tick_count, PLAYER, "block", {"held": true})])
	assert_eq(sim.carried_by(PLAYER), KEY)
	assert_eq(String(sim._shield_state[PLAYER]), "ready", "lifting lowered the shield")
	_tick([_attack("released", Vector3(0, 0, -3)), Command.new(sim.tick_count, PLAYER, "block", {"held": true})])
	_tick([_attack("pressed", Vector3(0, 0, -3)), Command.new(sim.tick_count, PLAYER, "block", {"held": true})])
	assert_eq(sim.carried_by(PLAYER), -1, "sanity: dropped")
	_tick([Command.new(sim.tick_count, PLAYER, "block", {"held": true})])
	assert_eq(String(sim._shield_state[PLAYER]), "ready", "a block held through the drop does not raise the shield")
	_tick([Command.new(sim.tick_count, PLAYER, "block", {"held": false})])
	_tick([Command.new(sim.tick_count, PLAYER, "block", {"held": true})])
	assert_eq(String(sim._shield_state[PLAYER]), "held", "a fresh block press does")


func test_switching_weapons_while_carrying_never_unlocks_an_attack() -> void:
	_lift()
	var events: Array[Event] = _tick([Command.new(sim.tick_count, PLAYER, "switch_weapon")])
	assert_true(_kinds(events).has("weapon_switched"), "switching is allowed")
	assert_eq(sim.carried_by(PLAYER), KEY)
	events = _click(Vector3(0, 0, -3))
	assert_false(_kinds(events).has("projectile_fired"), "the gun's press drops the key instead")
	assert_true(_kinds(events).has("carriable_dropped"))


func test_a_stray_held_or_released_while_carrying_is_refused() -> void:
	_lift()
	var events: Array[Event] = _release(Vector3(0, 0, -3))  # closes the lifting press
	events = _tick([_attack("held", Vector3(0, 0, -3))])
	assert_eq(_kinds(events), ["attack_rejected"])
	assert_false(_swung(events))


# --- 4: DROPS -------------------------------------------------------------------------------------

func test_a_damaging_hit_drops_the_key_where_the_carrier_stood() -> void:
	_lift()
	var standing: Vector3 = sim.entities[PLAYER]
	var events: Array[Event] = _enemy_bite()
	assert_true(_kinds(events).has("hit"))
	assert_eq(sim.carried_by(PLAYER), -1)
	assert_eq(_key_at(), standing)
	for event in events:
		if event.kind == "carriable_dropped":
			assert_eq(event.payload["reason"], "hit")


func test_an_absorbed_hit_does_not_drop_the_key() -> void:
	_lift()
	sim._iframe_ticks_remaining[PLAYER] = 10
	var events: Array[Event] = _enemy_bite()
	assert_true(_kinds(events).has("attack_absorbed"), "sanity: the hit was absorbed")
	assert_eq(sim.carried_by(PLAYER), KEY)


## P44: with the SHIPPED window, a carrier standing in spikes drops the key on the first damaging
## contact only -- the absorbed contacts after it are not hits, so they release nothing.
func test_spikes_drop_a_carried_key_once_not_every_contact() -> void:
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	sim.register_combatant(PLAYER, 100.0, &"envoy", envoy.iframe_ticks_on_hit, 0.45, &"player")
	_lift()
	sim.register_spike_pad(9, Rect2(-2.0, -2.0, 4.0, 4.0), 1, 10000, 0, 10.0, &"force")
	var events: Array[Event] = []
	for i in 30:
		events.append_array(_tick())
	var releases: Array = _kinds(events).filter(func(kind: String) -> bool: return kind.begins_with("carriable_"))
	assert_eq(releases, ["carriable_dropped"], "one release transition across the whole contact")
	assert_gt(_kinds(events).count("attack_absorbed"), 0, "sanity: later contacts were absorbed")
	assert_eq(sim.carried_by(PLAYER), -1)


func test_a_zero_damage_hit_does_not_drop_the_key() -> void:
	sim.register_weapon(BITE, 0.0, &"force", 4.0, 60.0, 0.0)
	_lift()
	assert_true(_kinds(_enemy_bite()).has("hit"), "sanity: it landed")
	assert_eq(sim.carried_by(PLAYER), KEY)


func test_burn_ticks_never_drop_the_key_but_burn_death_does() -> void:
	sim.register_status(&"burn", 1.0, 5, 200)
	sim.register_weapon(HARMLESS, 0.0, &"force", 4.0, 60.0, 0.0, 0, &"burn", 1.0)
	sim.set_equipped_weapon(ENEMY, HARMLESS)
	_lift()
	_enemy_bite()
	assert_true(sim._status_instances.has(PLAYER), "sanity: burning")
	var events: Array[Event] = []
	for i in 40:
		events.append_array(_tick())
	assert_true(_kinds(events).has("status_resolved"), "sanity: Burn ticked")
	assert_eq(sim.carried_by(PLAYER), KEY, "Burn ticks do not knock a key loose")
	sim.debug_override_health(PLAYER, 0.5)
	events = []
	for i in 10:
		events.append_array(_tick())
	assert_true(_kinds(events).has("died"))
	assert_eq(sim.carried_by(PLAYER), -1, "dying of Burn releases it")
	for event in events:
		if event.kind == "carriable_dropped":
			assert_eq(event.payload["reason"], "death")


func test_a_killing_hit_releases_the_key() -> void:
	_lift()
	sim.debug_override_health(PLAYER, 1.0)
	var events: Array[Event] = _enemy_bite()
	assert_true(_kinds(events).has("died"))
	assert_eq(sim.carried_by(PLAYER), -1)


func test_after_a_forced_drop_a_fresh_press_attacks_normally() -> void:
	_lift()
	_enemy_bite()
	assert_eq(sim.carried_by(PLAYER), -1, "sanity: knocked loose")
	assert_true(_kinds(_click(_aim_at(sim.entities[ENEMY]))).has("melee_swing"))


# --- 5: DELIVERY ----------------------------------------------------------------------------------

func test_delivery_consumes_the_key_opens_the_gate_and_does_not_attack() -> void:
	_lift()
	sim.entities[PLAYER] = Vector3(-10.0, 0.0, 0.0)
	assert_eq(sim.interaction_focus(PLAYER, Vector3(0, 0, -3)),
		{"kind": "insert", "trigger_id": RECEIVER, "carriable_id": KEY})
	var events: Array[Event] = _click(Vector3(0, 0, -3))
	assert_true(_kinds(events).has("carriable_inserted"))
	assert_false(_kinds(events).has("carriable_dropped"), "never set down first")
	assert_false(_swung(events))
	assert_true(bool(sim._connection_open[DOOR]), "the receiver's gate opened")
	assert_true(bool(sim._carriables[KEY]["inserted"]))
	assert_eq(sim.interaction_focus(PLAYER, _aim_at(_key_at())), {}, "a delivered key can never be lifted again")


func test_either_key_fits_and_a_filled_receiver_takes_no_second_key() -> void:
	sim.register_carriable(SECOND_KEY, Vector3(-1.0, 0.0, 0.0))
	sim.entities[PLAYER] = Vector3(-0.5, 0.0, 0.0)
	assert_true(_kinds(_click(_aim_at(_key_at(SECOND_KEY)), 0)).has("carriable_lifted"))
	assert_eq(sim.carried_by(PLAYER), SECOND_KEY)
	sim.entities[PLAYER] = Vector3(-10.0, 0.0, 0.0)
	assert_true(_kinds(_click(Vector3(0, 0, -3), 0)).has("carriable_inserted"), "the receiver never asks which key")
	sim.entities[PLAYER] = Vector3(0.0, 0.0, 0.0)
	_lift()
	sim.entities[PLAYER] = Vector3(-10.0, 0.0, 0.0)
	var events: Array[Event] = _click(Vector3(0, 0, -3), 0)
	assert_true(_kinds(events).has("carriable_dropped"), "a filled receiver swallows nothing; the press drops")
	assert_false(_kinds(events).has("carriable_inserted"))


func test_carrying_state_dies_with_the_floor() -> void:
	_lift()
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	assert_eq(sim.carried_by(PLAYER), -1)
	assert_true(sim._carriables.is_empty())


# --- 6: THE FIRST LIFT (the west return ambush's trigger, 2026-10-16) ------------------------------

func _watch_first_lift() -> void:
	sim.register_trigger(LIFT_WATCHER, FloorLayers.TRIGGER_CARRIABLE_LIFTED, Rect2(), KEY, true,
		[FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)])


func _fired(events: Array[Event], trigger_id: int) -> int:
	return events.filter(func(event: Event) -> bool:
		return event.kind == "floor_trigger_fired" and int(event.payload["trigger_id"]) == trigger_id).size()


func test_the_first_lift_fires_its_watcher_and_no_later_lift_does() -> void:
	_watch_first_lift()
	var events: Array[Event] = _click(_aim_at(_key_at()), 0)
	assert_eq(_fired(events, LIFT_WATCHER), 1, "the first lift fires it")
	assert_true(bool(sim._connection_open[DOOR]))
	for i in 3:
		_click(Vector3(0, 0, -3), 0)
		assert_eq(sim.carried_by(PLAYER), -1, "sanity: dropped")
		sim.entities[PLAYER] = _key_at() + Vector3(-1.0, 0.0, 0.0)
		events = _click(Vector3(1, 0, 0), 0)
		assert_eq(sim.carried_by(PLAYER), KEY, "sanity: lifted again")
		assert_eq(_fired(events, LIFT_WATCHER), 0, "re-lift %d re-arms nothing" % i)


func test_lifting_a_different_key_does_not_fire_the_watcher() -> void:
	_watch_first_lift()
	sim.register_carriable(SECOND_KEY, Vector3(-1.0, 0.0, 0.0))
	var events: Array[Event] = _click(_aim_at(_key_at(SECOND_KEY)), 0)
	assert_eq(sim.carried_by(PLAYER), SECOND_KEY)
	assert_eq(_fired(events, LIFT_WATCHER), 0, "the watcher names one key")
