extends GutTest
## STATIC GAMEPLAY OBSTACLES (ruled 2026-09-03).
##
## A column, a rock, a machine. Its whole job is to SHAPE SPACE -- cover, sightlines, combat
## spacing, approach angles -- and it is not a combatant, not breakable, and not decoration.
##
## ONE AUTHORED FACT, BOTH CONSUMERS. If it looks solid, actor legality agrees; if it stops a
## shot, projectile geometry agrees; and both read the SAME rect. No presentation-only cover, no
## invisible blocker. That is the failure P34 was fought over -- a wall that exists for one
## consumer and not the other -- and these tests exist so it cannot come back through a prop.
##
## AUTHORED AS AN EXCLUSION, not as an object standing in the room. Walkable space is a union of
## rects, so an obstacle is a hole in it. That keeps obstacles inside the body-aware, union-tested
## legality law that already ships instead of inventing a second notion of impassable.

const DT := 1.0 / 30.0
const PLAYER := 0
const TARGET := 1
const ROOM := Rect2(-20.0, -10.0, 40.0, 20.0)
const COLUMN := Rect2(-2.0, -2.0, 4.0, 4.0)

var sim: SimWorld


func _plan_with_column() -> FloorPlan:
	var plan := FloorPlan.new()
	var patch := WalkablePatch.new()
	patch.patch_id = 0
	patch.rect = ROOM
	patch.boundary_style = &"ledge"
	plan.patches.append(patch)
	var obstacle := ObstaclePlan.new()
	obstacle.obstacle_id = 0
	obstacle.rect = COLUMN
	plan.obstacles.append(obstacle)
	return plan


func before_each() -> void:
	var plan: FloorPlan = _plan_with_column()
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(plan.make_bounds(), Vector3(-15.0, 0.0, 0.0))
	sim.register_patches(plan.patch_rects())
	sim.register_obstacles(plan.obstacle_rects())
	sim.register_solid_segments(plan.solid_segments())
	sim.add_entity(PLAYER, Vector3(-15.0, 0.0, 0.0), 6.0, Vector3(1, 0, 0), 0.45)
	sim.register_combatant(PLAYER, 1000.0, &"envoy", 0, 0.45, &"player")


# --- 1: BODIES ---------------------------------------------------------------------------------

func test_a_body_may_not_stand_inside_an_obstacle() -> void:
	assert_false(sim._bounds.is_inside(Vector3(0.0, 0.0, 0.0)), "the centre of a column is not floor")
	assert_false(sim._bounds.fits(Vector3(0.0, 0.0, 0.0), 0.45), "and no body fits there")


## BODY-AWARE, like every other legality question: standing beside a column means clear of it,
## not merely centred outside it.
func test_a_body_may_not_overlap_an_obstacle_edge() -> void:
	assert_false(sim._bounds.fits(Vector3(COLUMN.end.x + 0.2, 0.0, 0.0), 0.45),
		"a body half inside the column is not legal")
	assert_true(sim._bounds.fits(Vector3(COLUMN.end.x + 0.5, 0.0, 0.0), 0.45),
		"clear of it, it is")


func test_the_floor_around_an_obstacle_is_untouched() -> void:
	for point: Vector3 in [Vector3(-15.0, 0.0, 0.0), Vector3(15.0, 0.0, 0.0), Vector3(0.0, 0.0, -8.0)]:
		assert_true(sim._bounds.fits(point, 0.45), "an obstacle excludes itself and nothing else (%s)" % point)


## WALKING INTO ONE SLIDES, exactly as walking into a wall does -- the clamp is shared, so an
## obstacle cannot become the one solid thing in the game that feels different.
func test_walking_into_an_obstacle_stops_the_body_outside_it() -> void:
	for i in 300:
		sim.tick([Command.new(sim.tick_count, PLAYER, "move", {"direction": Vector3(1, 0, 0)})] as Array[Command], DT)
	var position: Vector3 = sim.entities[PLAYER]
	assert_true(sim._bounds.fits(position, 0.45), "it never ends up somewhere illegal, got %s" % position)
	assert_lt(position.x, COLUMN.position.x, "and it is stopped on the near side, got %s" % position)


# --- 2: SHOTS ----------------------------------------------------------------------------------

## THE POINT OF THE WHOLE THING. The same rect that stops a body stops a shot, so cover is real.
func test_an_obstacle_stops_a_shot() -> void:
	sim.add_entity(TARGET, Vector3(15.0, 0.0, 0.0), 0.0)
	sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.5, &"enemy")
	sim.register_gun(&"wand", 10.0, &"force", 40.0, 600, 0.2, 0.0, 1)
	sim.set_equipped_weapon(PLAYER, &"wand")
	var hit: bool = false
	for event in sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT):
		hit = hit or event.kind == "hit"
	for i in 90:
		for event in sim.tick([] as Array[Command], DT):
			hit = hit or event.kind == "hit"
	assert_false(hit, "a shot through a column must not arrive")


## AND IT IS COVER, NOT A CEILING: the same shot around the column lands.
func test_a_shot_past_an_obstacle_still_lands() -> void:
	sim.add_entity(TARGET, Vector3(15.0, 0.0, -6.0), 0.0)
	sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.5, &"enemy")
	sim.register_gun(&"wand", 10.0, &"force", 40.0, 600, 0.2, 0.0, 1)
	sim.set_equipped_weapon(PLAYER, &"wand")
	sim.entities[PLAYER] = Vector3(-15.0, 0.0, -6.0)
	var hit: bool = false
	for event in sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT):
		hit = hit or event.kind == "hit"
	for i in 90:
		for event in sim.tick([] as Array[Command], DT):
			hit = hit or event.kind == "hit"
	assert_true(hit, "clear of the column, the shot arrives -- otherwise it is not cover but a wall")


# --- 3: ONE FACT, NOT TWO ----------------------------------------------------------------------

## THE ANTI-DIVERGENCE ASSERTION. Presentation, projectiles and legality must all descend from
## the authored rect; this pins the two DERIVED views to it so neither can drift alone.
func test_the_same_rect_feeds_legality_and_projectile_geometry() -> void:
	var plan: FloorPlan = _plan_with_column()
	var faces: int = 0
	for segment in plan.solid_segments():
		var at: float = float(segment["at"])
		var on_column: bool = (segment["axis"] == &"x" and (absf(at - COLUMN.position.x) < 0.01 or absf(at - COLUMN.end.x) < 0.01)) \
			or (segment["axis"] == &"z" and (absf(at - COLUMN.position.y) < 0.01 or absf(at - COLUMN.end.y) < 0.01))
		if on_column:
			faces += 1
	assert_eq(faces, 4, "an obstacle contributes exactly its four faces to the canonical segments")
	assert_eq(plan.obstacle_rects(), [COLUMN] as Array[Rect2],
		"and legality reads the same rect the faces were derived from")


## A patch with no obstacles derives exactly what it did before obstacles existed.
func test_a_floor_without_obstacles_is_unchanged() -> void:
	var plan := FloorPlan.new()
	var patch := WalkablePatch.new()
	patch.patch_id = 0
	patch.rect = ROOM
	patch.boundary_style = &"ledge"
	plan.patches.append(patch)
	assert_eq(plan.solid_segments().size(), 0, "a wholly open patch still has no walls")
	assert_eq(plan.obstacle_rects().size(), 0)
	assert_true(plan.make_bounds().fits(Vector3.ZERO, 0.45), "and its middle is still walkable")


# --- 4: TERRITORIES SEE THEM TOO ----------------------------------------------------------------

## A home that ignored obstacles would send a disengaged actor walking back into a column.
func test_an_encounter_territory_excludes_obstacles() -> void:
	sim.register_encounter(0, [ROOM] as Array[Rect2], FloorLayers.ROLE_AMBIENT, false, true)
	var territory: WalkableBounds = sim._encounter_bounds[0]
	assert_false(territory.fits(Vector3(0.0, 0.0, 0.0), 0.45),
		"the column is solid inside a territory as much as outside one")
	assert_true(territory.fits(Vector3(-10.0, 0.0, 0.0), 0.45), "the rest of the home is unaffected")
