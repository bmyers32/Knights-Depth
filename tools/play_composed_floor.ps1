# Launches the ADR-001 debug playground on one composed seed of one recipe (human design gate).
# Usage, from the repo root:
#   .\tools\play_composed_floor.ps1 -Seed 7                               # the column recipe, windowed
#   .\tools\play_composed_floor.ps1 -Seed 7 -Recipe proto_archive_dogleg  # the dogleg experiment
#   .\tools\play_composed_floor.ps1 -Seed 7 -Diagram                      # also opens build/composed/<recipe>/seed_7.svg
#   .\tools\play_composed_floor.ps1 -Seed 7 -Headless                     # boot check only, no window
# Nothing here edits source: seed and recipe are command-line arguments the scene reads.
param(
    [int]$Seed = 1,
    [string]$Recipe = "proto_archive",
    [switch]$Diagram,
    [switch]$Headless
)
$root = Split-Path -Parent $PSScriptRoot
# The console build also opens the game window; it additionally shows the composition summary
# and spatial signature the playground prints, which the windowed-only build would swallow.
$godot = "C:\Godot\Godot_v4.7-stable_win64_console.exe"
$seedArg = "--seed=" + $Seed
$recipeArg = "--recipe=" + $Recipe
if ($Diagram) {
    $svg = Join-Path $root ("build\composed\" + $Recipe + "\seed_" + $Seed + ".svg")
    if (Test-Path $svg) { Start-Process $svg } else { Write-Warning "No diagram at $svg (run tools/draw_composed_floor.gd -- --recipe=$Recipe first)" }
}
if ($Headless) {
    & $godot --headless --path $root tools/composed_floor_playground.tscn --quit-after 300 -- $seedArg $recipeArg
} else {
    & $godot --path $root tools/composed_floor_playground.tscn -- $seedArg $recipeArg
}
