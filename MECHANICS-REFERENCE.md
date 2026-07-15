# MECHANICS-REFERENCE.md — What the Reference Game Actually Does
On-demand design reference. "RG" = the reference game whose mechanics inspire this
project. Everything here is mechanical analysis in our own words, mapped to OUR
original names — no RG names, assets, or text enter the repo (Prime Directive 5).
Loaded when designing content for M1–M2 and when writing ROADMAP proposals.

## 1. The damage/family matrix (the heart of RG combat)
RG has 4 damage types and 6 monster families. Every family is WEAK to exactly one
type, RESISTANT to exactly one, neutral to the rest — and the baseline type (their
"normal") is resisted equally by everyone: universally usable, never optimal. That
asymmetry is the whole loadout game: you can't cover everything, so party composition
and weapon slots become meaningful choices. Dual-type weapons resolve as two
simultaneous half-attacks, each checked against the matrix independently.

Our mapping (types: **Force** = baseline, **Pierce**, **Arc** = energy, **Umbral** = dark):
| Our family (RG analogue) | Weak to | Resists |
|---|---|---|
| Fang — beasts | Pierce | Arc |
| Dread — demons/fiends | Pierce | Umbral |
| Tinker — mischief-machinists | Umbral | Arc |
| Ooze — slimes | Umbral | Pierce |
| Hollow — undead | Arc | Umbral |
| Automaton — constructs | Arc | Pierce |

Load-bearing properties to preserve: each non-Force type is the weakness of exactly
TWO families; Force is nobody's weakness; every family resists exactly one non-Force
type. Content lint (tools/) should assert these invariants on the matrix resource.

## 2. Tier-based onboarding (steal this)
In RG's first tier, ALL enemy damage is dealt as the baseline type regardless of the
attack's visual telegraph; typed enemy damage phases in at deeper tiers. New players
learn dodge/block timing before armor-matrix decisions matter. Enemies also gain
additional attacks/behaviors per tier — depth scales *movesets*, not just stats.
→ Our M2 knob: `typed_damage_ramp` per depth-tier in config.

## 3. Telegraph language
Every enemy attack telegraphs with a colored ground indicator whose color encodes the
incoming damage type; hit feedback color encodes effectiveness (resisted / neutral /
weak, the last with celebratory emphasis). Players read the matrix through color long
before reading any table. → Our combat pipeline already emits Events; presentation
maps damage type → telegraph/impact palette from one config table.

## 4. Status effects (roster + the architectural gift)
RG statuses and their mechanical identities, translated:
- **Burn** — strong DoT; certain oily enemies HEAL from it (built-in counterplay). [M1 ✓]
- **Frost** — immobilizes; ANY damage breaks it; if it expires unbroken, bonus damage.
  Tension: freezing a mob protects it from your AoE.
- **Jolt** — periodic spasm damage (Arc-typed) that also damages the victim's adjacent
  ALLIES; interrupts only during the telegraph window, not mid-attack. Crowd tool.
- **Venom** — no DoT: reduces target's attack and defense and blocks ALL healing.
  Identity = anti-heal/debuff, deliberately not a second Burn.
- **Daze** — slows movement and attack speed (not damage); very short. Setup tool.
- **Hex** — damages the victim whenever it uses any ability, including healing.
  Punishes action; the anti-turtle status. RG's scariest weapons can Hex their OWN
  user on charge attacks — risk/reward baked into the weapon.
- **Slumber** — full disable but target regenerates; any damage wakes. Rare/utility.
Interactions: Burn thaws Frost; damage-dealing statuses break disable statuses —
statuses are effectively EXCLUSIVE. → Architectural gift: **one status slot per
entity**, replacement governed by a priority table in data. Massively simpler sim
than stacking, and it's what RG's interactions imply anyway. (GAME-RULES §3 law now.)
Statuses are inherent to weapons (often charge-attack-only), never generic add-ons;
consumable vials let any player apply any status — a loadout-free tactical layer.

## 5. Run structure (M2's actual shape)
RG's dungeon: ~30 depths per descent, organized as 3 tiers × 2 strata, each stratum
being 3–5 themed floors; between strata sits a SAFE FLOOR (rest stop: heal, change
gear, shop) whose elevator auto-descends. A stratum's theme fixes its status hazards
and enemy-family mix, and the next floor is telegraphed by an icon (layout family),
icon color (enemy families → expected damage types), and background (status theme) —
so descent is a sequence of informed loadout decisions, not a slot machine. Some
floors are fixed hand-made layouts; most assemble from pre-designed room segments.
Enemy defenses scale with depth from per-stratum base values.
→ M2 target translated: runs = [stratum(theme, 3–5 floors), rest floor] × 2; theme
drives segment pool + hazard set + family weights; next-floor preview on the elevator.

## 6. Weapon triangle + shield
RG has THREE weapon classes: sword (melee combos + charge), handgun (ranged), and
BOMB (placed AoE/status specialist — the support/control class). All weapons have
charge attacks; status infliction and charge behavior define a weapon's identity more
than raw numbers. Shield is a first-class verb: hold-to-block with its own HP that
regenerates, universal across builds. M1 ships sword+gun+shield; bombs are the
designed third leg (ROADMAP) — the content pipeline should assume a third class
exists (weapon resources carry a `class` field from day one).

## 7. Health & pickups
Health is displayed as discrete bars/pips; damage feedback is quantized to fractions
of a pip — chunky, readable, consistent with a low-HP-numbers economy. Enemies drop
hearts; consumables (vials, capsules) apply statuses or cures. Some enemies HEAL
other enemies (mender-type) — the single cheapest way RG makes encounters tactical:
kill-priority becomes a decision. One mender-type enemy is a strong M2 addition.

## 8. Progression skeleton (M4+ reference, not now)
Gear rarity runs 0–5 stars; items level up through use ("heat") and are crafted via
recipes from materials; armor sets define playstyles instead of character classes;
tier access is gated by gear rating. Noted for M4's crafting loop — do not front-load.
