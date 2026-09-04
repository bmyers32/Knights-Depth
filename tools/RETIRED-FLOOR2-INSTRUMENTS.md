# Retired Floor 2 instruments — 2026-09-04

Removed when Floor 2 was re-authored as three folded legs. All of them were pinned to space
names and coordinates that no longer exist, so they could not run; a tool that cannot run is a
trap for whoever opens it next, and git holds them if they are ever wanted.

**Every finding they produced is preserved as a test or a guard** — that is the condition for
retiring an instrument, not merely that it stopped compiling.

| Retired | What it found | Where that lives now |
|---|---|---|
| `reproduce_gate_bypass.gd` | Both closed gates separated nothing; the Envoy walked into the "gated" route on tick 333 | `FloorPlan._reject_bypassable_gates` + `tests/test_gate_integrity.gd` |
| `reproduce_doorway_defects.gd` | An open door was legal for the player and illegal for the Watcher; the same walls killed a burrowing Fang | `tests/test_doorway_pursuit.gd` |
| `measure_floor2_sightline.gd` | The Junction read at 19% down the screen from the Concourse edge | superseded by `measure_floor_reveal.gd` |
| `measure_floor2_legibility.gd` | The fork's two mouths could never share a screen | superseded by `measure_floor_reveal.gd` |
| `measure_floor2_fork_proposal.gd` | Pre-build costing of the narrowed fork | superseded |
| `measure_floor2_switchback.gd` | A lateral switchback bought 10 spaces down to 8 — not enough | recorded in `FLOOR2-REVEAL-PAPER.md` |
| `probe_floor2_pursuit.gd` | Accepted v1 Ooze locomotion transits a fork without stalling | `tests/test_doorway_pursuit.gd` |

**Still live:** `measure_floor_reveal.gd` (reads the plan and its constants, so it survives
re-authoring), `diagnose_*`, `record_*`, `compare_wall_migration.gd`, `cost_navigation_models.gd`.
