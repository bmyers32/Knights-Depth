extends GutTest
## ATTACK-BAND LOCOMOTION — bounded lateral matching (ruled 2026-09-01).
##
## THE DEFECT: the band law held position ABSOLUTELY, and a distance band is blind to lateral
## motion. Measured on an open plain: a player circling at band distance produced 0.00 units of
## translation over 600 ticks while the Ooze faced and attacked -- "following me but stuck".
##
## THE SEMANTIC SPLIT under test: the RADIAL component governs distance (approach/retreat, already
## law); only the TANGENTIAL component gives an actor at valid attack range a reason to move.
## Only the DIRECTION of that component is taken -- the actor keeps its own speed, legality and
## character. This is NOT velocity copying.
##
## SYNTHETIC FIXTURE GEOMETRY -- an open plain, so nothing here can be blamed on obstacles.

const PLAYER := 0
const OOZE := 1
const DT := 1.0 / 30.0
const BAND := 2.05          # inside minimum 1.90 .. preferred 2.20
const PLAIN := Rect2(-40.0, -40.0, 80.0, 80.0)

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [PLAIN]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)


## The SHIPPED Ooze, through the ordinary registrar -- a hand-tuned stand-in would not prove
## anything about the band values that actually ship.
func _engage(player_at: Vector3, walls: Array[Rect2] = [] as Array[Rect2]) -> void:
	if not walls.is_empty():
		sim = SimWorld.new()
		sim.set_damage_matrix({}, 1.5, 0.5)
		sim.load_floor(WalkableBounds.new(walls), Vector3.ZERO)
		sim.register_patches(walls)
	var envoy: Resource = ContentDB.get_resource(&"envoy", &"default")
	sim.add_entity(PLAYER, player_at, envoy.move_speed, Vector3(-1, 0, 0), envoy.combat_radius)
	sim.register_combatant(PLAYER, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	sim.mark_run_persistent(PLAYER)
	ContentRegistrar.register_enemy_body(sim, OOZE, &"ooze", Vector3.ZERO)
	ContentRegistrar.register_enemy_ai(sim, OOZE, &"ooze", Vector3.ZERO)
	sim.debug_set_ai_active(OOZE)


## Runs the world, keeping the player alive every tick and ABORTING if the mechanism stops being
## live -- the banked lesson from four diagnostics that measured idle or dead actors.
func _run(ticks: int, mover: Callable) -> Dictionary:
	var moved: int = 0
	var telegraphs: int = 0
	var start: Vector3 = sim.entities[OOZE]
	for tick in ticks:
		sim.debug_override_health(PLAYER, 5000.0)
		assert_eq(sim._ai_state.get(OOZE, ""), "active", "precondition: the AI must stay engaged")
		var before: Vector3 = sim.entities[OOZE]
		for event in sim.tick([] as Array[Command], DT):
			if event.kind == "attack_telegraph":
				telegraphs += 1
		if before.distance_to(sim.entities[OOZE]) > 0.0001:
			moved += 1
		mover.call(tick)
	return {
		"moved": moved, "telegraphs": telegraphs,
		"translated": start.distance_to(sim.entities[OOZE]),
		"gap": sim.entities[OOZE].distance_to(sim.entities[PLAYER]),
	}


func _orbit(tick: int) -> void:
	var angle: float = float(tick) * 0.012
	sim.entities[PLAYER] = sim.entities[OOZE] + Vector3(cos(angle), 0.0, sin(angle)) * BAND


## GENUINELY stationary: the player is pinned each tick. Without this, the Ooze's own slam
## knocks the player back out of the band, the ordinary APPROACH law responds, and the resulting
## drift gets misread as lateral tracking inventing motion.
func _still(_tick: int) -> void:
	sim.entities[PLAYER] = Vector3(BAND, 0.0, 0.0)


# --- 1: a stationary target must not make it wander ----------------------------------------

func test_a_stationary_player_in_band_does_not_make_the_ooze_wander() -> void:
	_engage(Vector3(BAND, 0.0, 0.0))
	var result: Dictionary = _run(300, _still)
	assert_lt(float(result["translated"]), 0.6,
		"lateral matching must not invent motion against a still target; drifted %.2f" % result["translated"])


# --- 2: THE REPORTED CASE ------------------------------------------------------------------

## 0/600 movement ticks was the measured defect. This is the regression for it.
func test_a_circling_player_makes_the_ooze_track_laterally() -> void:
	_engage(Vector3(BAND, 0.0, 0.0))
	var result: Dictionary = _run(600, _orbit)
	assert_gt(int(result["moved"]), 100,
		"the Ooze must reposition with a circling player; moved on %d/600 ticks" % result["moved"])


## And it must stay at fighting distance while doing it -- tracking is not a chase.
func test_lateral_tracking_holds_attack_spacing() -> void:
	_engage(Vector3(BAND, 0.0, 0.0))
	var result: Dictionary = _run(600, _orbit)
	assert_lt(float(result["gap"]), 3.2, "it must not drift out of fighting range while tracking")
	assert_gt(float(result["gap"]), 1.2, "nor collapse onto the player")


# --- 3 & 4: the radial laws are untouched --------------------------------------------------

func test_a_retreating_player_is_still_chased() -> void:
	_engage(Vector3(BAND, 0.0, 0.0))
	var result: Dictionary = _run(600, func(_t): sim.entities[PLAYER] += Vector3(0.02, 0.0, 0.0))
	assert_gt(float(result["translated"]), 6.0,
		"approach must survive: it only translated %.2f chasing a retreat" % result["translated"])


func test_a_player_too_close_still_triggers_backoff() -> void:
	_engage(Vector3(1.0, 0.0, 0.0))
	var before: float = sim.entities[OOZE].distance_to(sim.entities[PLAYER])
	_run(120, func(_t): sim.entities[PLAYER] = Vector3(1.0, 0.0, 0.0))
	assert_gt(sim.entities[OOZE].distance_to(sim.entities[PLAYER]), before,
		"minimum-distance backoff must still apply inside the band's lower edge")


# --- 5: physical legality wins --------------------------------------------------------------

## RECORDED AS EXPECTED BEHAVIOUR, not a defect: a player who strafes the Ooze into a wall's
## shadow will see it stop tracking -- planted again, legitimately, with a visible wall
## explaining it. P33 avoidance is deliberately NOT blended into band tracking, so the actor does
## not route around the obstruction merely because lateral tracking wanted to continue.
func test_a_blocked_lateral_track_obeys_the_wall() -> void:
	var pen: Array[Rect2] = [Rect2(-4.0, -4.0, 8.0, 8.0)]
	_engage(Vector3(BAND, 0.0, 0.0), pen)
	for tick in 400:
		sim.debug_override_health(PLAYER, 5000.0)
		sim.tick([] as Array[Command], DT)
		_orbit(tick)
		assert_true(sim._bounds.fits(sim.entities[OOZE], 1.45),
			"lateral tracking carried the body outside legal ground to %s" % sim.entities[OOZE])


# --- 6: attacks are not suppressed by moving ------------------------------------------------

func test_lateral_tracking_does_not_suppress_attacks() -> void:
	_engage(Vector3(BAND, 0.0, 0.0))
	var result: Dictionary = _run(600, _orbit)
	assert_gt(int(result["telegraphs"]), 0,
		"an actor that repositions must still attack on its authored cadence")


# --- 7: determinism --------------------------------------------------------------------------

func test_identical_target_motion_produces_identical_movement() -> void:
	var outcomes: Array = []
	for attempt in 2:
		before_each()
		_engage(Vector3(BAND, 0.0, 0.0))
		_run(200, _orbit)
		outcomes.append(sim.entities[OOZE])
	assert_eq(outcomes[0], outcomes[1], "identical authoritative motion must move the actor identically")


# --- the split itself, asserted directly ----------------------------------------------------

## Motion straight AT the actor is purely radial, so it must produce no tangential tracking --
## that case belongs to the approach/retreat law, not to this one.
func test_purely_radial_target_motion_produces_no_lateral_tracking() -> void:
	_engage(Vector3(BAND, 0.0, 0.0))
	sim.tick([] as Array[Command], DT)
	var straight_in: Vector3 = sim.entities[PLAYER] + (sim.entities[OOZE] - sim.entities[PLAYER]).normalized() * 0.2
	assert_eq(sim._band_tracking_direction(OOZE, straight_in), Vector3.ZERO,
		"radial motion is the distance law's business, not the tracking law's")
