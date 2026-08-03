class_name StatusPriorityTable
extends Resource
## Cross-status replacement priority (GAME-RULES §3: statuses are exclusive, never
## stacked — a new status replaces the current one per a priority table in data).
## Ships as real data from day one even with only Burn registered, mirroring how
## DamageMatrix ships all six families before enemy content catches up — a second
## status (ROADMAP P2) is a data change here, not a code change. Higher replaces lower.

@export var priority: Dictionary = {
	"burn": 0,
}
