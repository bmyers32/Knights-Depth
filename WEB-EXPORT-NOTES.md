# WEB-EXPORT-NOTES.md — Web pipeline smoke validation
On-demand file. Records what the Web/itch export pipeline was proven to do, and —
more importantly — what it was NOT proven to do.

## Scope fence (read this first)
**Web/itch validation proves packaging and browser compatibility ONLY. It does not
substitute for later Windows desktop/Steam pipeline validation.** Desktop export is a
different template, a different renderer path, different input/window handling, and a
different distribution story. Treat the two as independent pipelines that happen to
share a project file.

This smoke test also does **not** satisfy the M1 itch criterion (GAME-RULES §5). That
criterion is met only by the public build produced after the post-batch RE-GATE passes.
The draft/private page exists to debug HTML5 quirks against a small frozen build.

## What was validated (2026-08-12)
Source: current `main`, gameplay-identical to the frozen gate build `d1dbab0` —
verified by `git diff d1dbab0..HEAD -- game/ project.godot`, which contains **only**
comment changes (calibration notes). Zero executable or tunable differences.

Godot 4.7.stable · preset "Web" at defaults · `variant/thread_support=false`
(**nothreads** template variant) · exported headless to a disposable `build/` dir.

| Check | Result |
|---|---|
| Headless export completes | clean, exit 0 |
| Artifacts | `index.html/.js/.wasm/.pck/.audio.worklet.js` + icons all present (wasm ~38 MB, pck ~5.3 MB) |
| Served over local HTTP (never `file://`) | all 200; `index.wasm` served as `application/wasm` |
| Boot | engine starts, sets window title, arena renders (Envoy + all three enemies) |
| Console | clean — one informational WebGL line, zero errors/warnings |
| Content pipeline in WASM | `combat RNG seed: 0` prints, so `_ready()` completed ContentDB lookups and the whole `ContentRegistrar` registration path |
| Input | keyboard movement and mouse attack both reach the sim |
| Combat loop | combo 1→2→3 landing 8.0/8.0/10.0; enemy AI telegraphs and hits (Fang 4.0, Watcher 5.0); player poise cancels the Envoy's swing; hit 3's `interrupt_strength` fires `windup_interrupted`; seeded Burn proc rolls both fail and success at 0.15 |

Notable: the browser run is independent live confirmation that `d1dbab0`'s i-frame
cadence fix holds outside the test harness — all three combo hits land in the shipped
build, not just in GUT.

## The nothreads trade (record explicitly)
This smoke test validated the **nothreads** template variant only
(`web_nothreads_debug.zip` / `web_nothreads_release.zip`).

Single-threaded Web export **sidesteps the SharedArrayBuffer / COOP-COEP header
requirement**. That is why the itch "embed headers / SharedArrayBuffer support"
question may report no issues — the build genuinely does not need cross-origin
isolation. Confirmed two ways: the local server sent **no** COOP/COEP headers and the
build still booted and played; and the `SharedArrayBuffer` / `crossOriginIsolated`
strings present in `index.js` are only the feature-detection helpers
`Engine.isSharedArrayBufferAvailable()` / `Engine.isCrossOriginIsolated()`, not a
hard dependency.

**Switching to a threaded Web export later reopens this entire question** — it would
require SharedArrayBuffer, therefore cross-origin isolation, therefore itch's
SharedArrayBuffer-support setting, and this validation would no longer apply. If
threading is ever enabled for performance, re-run this smoke test from scratch.

## Repo policy applied
- `export_presets.cfg` is authored config → **tracked**.
- Export templates are machine tooling → never in the repo.
- Generated `index.*` output → disposable `build/`, **gitignored**, never committed.
  This repo tracks no release artifacts.

## Open / not covered
- Draft/private itch upload and in-browser play **on itch** — the only place
  COOP/COEP, embed sizing, and fullscreen behavior are truly answered.
- Audio was not exercised (no gameplay audio exists yet).
- Mobile/touch input: untested and out of scope.
- Load time on a cold remote fetch: untested (local HTTP only). A ~38 MB wasm plus
  ~5.3 MB pck is the number to watch on a real itch page.
- **Windows desktop export: not attempted.** Captured as the more relevant precursor
  to any eventual Steam distribution. No Steamworks/integration work now.
