extends GutTest
## PROJECTILES MUST FLY ABOVE THE FLOOR THEY WERE FIRED FROM (ruled 2026-09-04).
##
## THE HUMAN'S FINDING: on the final raised platform, a shot was fired and the tracer was not
## visible -- it appeared to travel underneath the platform.
##
## THE DIAGNOSIS, and the reason this is a presentation file rather than a sim one: THE SIM IS
## FLAT. Every actor position carries y = 0, and elevation is a PRESENTATION property of the
## patch you are standing on -- `arena._grounded()` lifts actor nodes to it on the way out. The
## tracer was the one thing that never got lifted, so a shot fired on a platform at elevation 1
## launched at y = 0 and flew under it.
##
## AUTHORITY WAS NEVER WRONG. The shot resolved correctly the whole time; only the picture was
## below the floor. That is why the fix is a lift in presentation and NOT a depth-test change,
## a render-through-geometry flag, or any other way of making a wrong position look right.

const DT := 1.0 / 30.0
const L = preload("res://game/gen/layouts/archive_roundabout.gd")

var arena: Node3D


func _boot() -> Node3D:
	var instance: Node3D = load("res://game/arena/arena.tscn").instantiate()
	instance.depth = 2
	add_child_autofree(instance)
	instance.sim.debug_override_health(instance.envoy.actor_id, 100000.0)
	return instance


## Cycles the shipped loadout to a projectile weapon and fires, driving the events through the
## arena's OWN reporting path.
##
## THAT DETAIL IS THE TEST. Ticking the sim directly produces the Event but never the tracer --
## presentation only reacts inside `_report_events`, which `_physics_process` normally calls. A
## first version of this file drove the sim alone and read an empty tracer list as "no shot was
## fired", which would have been a bug report about the wrong thing entirely.
func _equip_a_gun(instance: Node3D) -> bool:
	var envoy_id: int = instance.envoy.actor_id
	for attempt in 4:
		var probe: Array[Event] = instance.sim.tick(
			[Command.new(instance.sim.tick_count, envoy_id, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
		instance._report_events(probe)
		for event in probe:
			if event.kind == "projectile_fired":
				return true
		instance._report_events(instance.sim.tick(
			[Command.new(instance.sim.tick_count, envoy_id, "switch_weapon", {})] as Array[Command], DT))
		for i in 20:
			instance._report_events(instance.sim.tick([] as Array[Command], DT))
	return false


func before_each() -> void:
	arena = _boot()


## THE EXACT REPRODUCTION: stand on the raised terrace, fire, and look at where the tracer is.
func test_a_shot_fired_on_the_raised_terrace_flies_above_it() -> void:
	var terrace: Rect2 = DepthGenerator.generate(arena.run_seed, 2).patch_by_id(L.P_TERRACE).rect
	var stand := Vector3(terrace.get_center().x, 0.0, terrace.get_center().y)
	arena.sim.entities[arena.envoy.actor_id] = stand
	var surface: float = arena._floor_builder.elevation_at(stand)
	assert_gt(surface, 0.0, "sanity: the terrace must actually be raised, or this proves nothing")

	assert_true(_equip_a_gun(arena), "sanity: a projectile weapon must be equipped to fire one")
	assert_gt(arena._projectile_tracers.size(), 0, "a shot must have produced a tracer")
	for projectile_id in arena._projectile_tracers:
		var tracer: Node3D = arena._projectile_tracers[projectile_id]
		assert_gt(tracer.position.y, surface,
			"the tracer is at y=%.2f on a floor at %.2f -- it is under the platform" % [tracer.position.y, surface])


## AND ON FLAT GROUND IT IS STILL ABOVE THE FLOOR, so the fix is a consistent muzzle height
## rather than a special case that only rescues raised platforms.
func test_a_shot_fired_on_flat_ground_also_flies_above_it() -> void:
	var landing: Rect2 = DepthGenerator.generate(arena.run_seed, 2).patch_by_id(L.P_LANDING).rect
	var stand := Vector3(landing.get_center().x, 0.0, landing.get_center().y)
	arena.sim.entities[arena.envoy.actor_id] = stand
	assert_eq(arena._floor_builder.elevation_at(stand), 0.0, "sanity: the landing is flat")

	assert_true(_equip_a_gun(arena))
	for projectile_id in arena._projectile_tracers:
		assert_gt(arena._projectile_tracers[projectile_id].position.y, 0.0,
			"a tracer must never sit in the floor plane, even where the floor is at zero")


## THE SIM IS UNTOUCHED BY ANY OF THIS. Its projectile stays on the flat plane, because giving
## shots a real height would be a combat-law change wearing a presentation fix's clothes.
func test_the_authoritative_projectile_stays_on_the_flat_plane() -> void:
	var terrace: Rect2 = DepthGenerator.generate(arena.run_seed, 2).patch_by_id(L.P_TERRACE).rect
	arena.sim.entities[arena.envoy.actor_id] = Vector3(terrace.get_center().x, 0.0, terrace.get_center().y)
	assert_true(_equip_a_gun(arena))
	for projectile_id in arena.sim._projectiles:
		assert_eq(arena.sim._projectiles[projectile_id]["position"].y, 0.0,
			"the sim resolves shots on one plane; only the picture is lifted")


## AND IT STILL HIDES BEHIND REAL GEOMETRY. Lifting the tracer must not have turned it into
## something that renders through the world -- the fix was a position correction, and a position
## correction leaves occlusion exactly where it was.
##
## Asserted on the AUTHORITATIVE fact rather than on pixels: a shot fired into a fold wall
## terminates at the world, so there is no tracer left to see through it.
func test_a_shot_into_a_fold_wall_still_terminates_at_the_world() -> void:
	var floor_plan: FloorPlan = DepthGenerator.generate(arena.run_seed, 2)
	# THE LARGEST MASS ON THE FLOOR, whatever its height. An earlier version looked for a wall
	# taller than 6 -- which was true of the fold slabs and is true of nothing now that the floor
	# conceals by placement instead of scale. A test that hunts for a retired authoring style
	# fails for a reason that has nothing to do with what it is checking.
	var wall: Rect2 = Rect2()
	for obstacle: ObstaclePlan in floor_plan.obstacles:
		if obstacle.rect.get_area() > wall.get_area():
			wall = obstacle.rect
	assert_gt(wall.get_area(), 0.0, "sanity: the floor has a solid mass to shoot at")

	# Stand just north of the wall and fire south into it.
	arena.sim.entities[arena.envoy.actor_id] = Vector3(wall.get_center().x, 0.0, wall.end.y + 3.0)
	assert_true(_equip_a_gun(arena))
	var terminated: bool = false
	for i in 120:
		var events: Array[Event] = arena.sim.tick(
			[Command.new(arena.sim.tick_count, arena.envoy.actor_id, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
		arena._report_events(events)
		for event in events:
			if event.kind == "projectile_expired" and String(event.payload.get("reason", "")) == "world":
				terminated = true
		if terminated:
			break
	assert_true(terminated, "a shot into a solid mass must stop at it, lifted tracer or not")
