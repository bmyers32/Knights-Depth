class_name EncounterSite
extends RefCounted
## ENCOUNTER layer. An ENCOUNTER REGION IS NOT A PHYSICAL ROOM -- that conflation is precisely
## what the multi-room slice falsified. A site is a region plus a roster plus a role, and it
## may sit anywhere in a continuous space.
##
## ACTIVATION IS AUTHORED. There is no "player entered my region, therefore fight" rule
## anywhere in the sim; an encounter starts because an effect said so. That is the
## generalisation of the one thing the last playtest positively liked -- the explicit
## "hit this button, start the encounter" sequence, which Breon reported "was solid."
##
## CONFINEMENT vs OWNERSHIP, kept separate:
##   `region` confines this site's ROSTER always, whatever the state -- an enemy never leaves
##            its authored territory (ruled), and that includes AMBIENT rosters.
##   `confines_player` decides whether ACTIVATION also seals the Envoy in. AMBIENT sites set it
##            false: enemies engage naturally as the player passes through, with no activation
##            ceremony and no arena lock.

var encounter_id: int = -1
var region: Rect2 = Rect2()
var role: StringName = FloorLayers.ROLE_MANDATORY
## [{"enemy_key": StringName, "position": Vector3}] -- room-local in the old model, site-local
## now. Every actor here is owned by this site for its whole life.
var roster: Array[Dictionary] = []
var confines_player: bool = true
## AMBIENT rosters exist from floor load; triggered rosters materialise on activation, which is
## what makes a party button feel like it summoned something.
var spawn_at_floor_load: bool = false
