# Floor 2 — Split, Eastern Chapter, Arena, Status (§31 revision)

**No coordinates moved.** Base: working tree, 816/816 green. Rects are indicative; separation,
connectivity and camera readability get verified during authoring, as every prior pass has.

---

## G. MASS MAPPING — done first, because two rulings depend on it

Guessing from mass ranking was rejected as a method, so the floor was scanned by **signature**
(`tools/map_screenshot_location.gd`). The image's discriminating feature is that the Envoy stands
in a **slot** — a large mass close on *both* sides of the walking line.

**Exactly one such slot exists on the entire floor:**

```
CANDIDATE -- ARENA (patch 15)
   slot runs [P: (19.0, -137.0), S: (4.0, 0.0)]   (3 standing points)
   flanked by mass 11 (west) and mass 12 (east)
      mass 11 [P: (6.0, -146.0), S: (10.0, 8.0)]  area 80
      mass 12 [P: (26.0, -136.0), S: (10.0, 8.0)]  area 80
   crates within 18: 22 at (16,-134), 23 at (20,-136), 24 at (30,-146), 25 at (38,-142)
   hazard pads within 40: pad 2 (32,-168) 5x14, pad 3 (37,-168) 5x14
   plates within 60: trigger 6 (-2,-116), trigger 11 (58,-182)
   raised ground within 60: patch 17 SHELF elev 1.0
```

Every secondary feature agrees: two crates immediately ahead, hazard pads and coloured plates
beyond them up-frame, raised/stepped ground past those.

> **The pictured blocks are masses 11 and 12 — the Arena's two filler masses.** §7 already rules
> them for removal, so §29 resolves cleanly: **remove 11 and 12**, and masses 2/9 are *not* the
> pictured offenders.

**Masses 2 and 9 — ruled by consequence, not by preference.** §29 says retain them only if their
spike-approach reveal role still matters under the new topology. It no longer does — **it
inverts.** They exist to hide the South Lane from the Court. Under this ruling the South Lane
becomes the *optional left content*, and §2 wants exactly that content **visible from the split**
so the detour can tempt. Masses 2 and 9 would now conceal the thing the split is supposed to
advertise. **Remove both.**

---

## A. SPLIT LOCATION

**Honest first, because it changes what follows:** `screenshots from human/` contains **one**
file, and the mapping above shows it is the **Arena** — i.e. it is the *Arena reference* the
addendum announced, not the split-location screenshot §1 refers to. **That second image is not in
the repo.**

So the split location is derived from the ruling's own words rather than from a picture I do not
have. §1: *"the point where the existing route previously continues LEFT toward the spike/other-room
sequence."*

On this floor there is exactly one such point. From the **Court**, the route drops through its
south-east descent and then turns **west across the spike lane** into the Hall and everything
beyond. That is the only place the route "continues left toward the spike sequence".

> ### THE SPLIT IS THE COURT.

And this reading explains your complaint precisely. §2 says the mistake was *"adding another
optional limb to the left instead of reclassifying the existing left route as optional"* — which
is exactly what I did: I kept South Lane → Hall on the critical path and hung a new west loop
beside it. Under the correct reading, **the whole existing westward sequence becomes optional.**

| | |
|---|---|
| **LEFT (optional)** | South Lane (spikes) · Hall · Pocket · Puzzle Bay · doors · Cache · Return Run — **the entire route the player has already seen**, now optional, returning to the Court the way it came |
| **RIGHT (critical)** | a genuinely new eastern chapter: **Arena → Reward Hall → Shelf → exit** |

Both ways out of the Court are **open**. Nothing is locked at the split; the commitment happens
later, on the Arena's plate. Choosing is the beat.

**If the Court is not the room you meant, name it and I will move the topology there** — but this
is the only point on the floor matching §1's description, and it is the reading that makes §2's
diagnosis true.

---

## B. EASTERN CHAPTER — genuinely east

**Court → Arena directly.** No approach room: §5 forbids replacing the deleted commit corridor
with another short mechanical hallway, so the Court opens onto the Arena through **one wide
diagonal aperture**, not a room.

```
   WEST — optional, already built            CENTRE            EAST — new, critical
 Cache · Puzzle rooms · Pocket · Hall  <—  SOUTH LANE  <—  COURT  —>  ARENA  —>  REWARD HALL  —>  SHELF —> exit
                                            (spikes)         ^
                                                          THE SPLIT
```

| Space | Indicative rect | Role |
|---|---|---|
| **Arena** | `(46,-104) 46 × 28` | plate, hazard clusters, three waves |
| **Reward Hall** | `(98,-100) 26 × 20` | the retired Spillway's purpose (§16) |
| **Shelf** | `(130,-98) 20 × 18` | final approach and exit |

The chapter **stays at one latitude and marches right** — roughly 140 units of eastward travel
from the split, with no northward return to the spine (§4). The Vault is untouched; the new
aperture and the Arena both clear it.

**Scale consequence, flagged rather than shipped quietly:** the floor becomes roughly
**`208 wide × 138 deep`** — broader than long, inverting today's `126 × 186`. That is the §3
principle satisfied, and it is also a materially bigger floor. **If that is more than you want,
say so and the eastern rooms tighten; I would rather you see the number than discover it.**

---

## C. ARENA

**Masses 11 and 12 removed and not replaced** (§7, and now confirmed as the pictured offenders).
The room's identity is **plate + spike clusters + waves + open ground**.

### Sequence

```
enter freely from the Court   ->  the west chapter is still reachable; nothing has closed
        |
   cross to the CENTRAL PLATE  ->  whole active party
        |
   rear seals · WAVE 1 activates · the open room becomes a positioning problem
        |
   waves 2 and 3 on clear      ->  forward opens to the Reward Hall
```

### Candidate pattern — three clusters

Arena `x[46,92] z[-104,-76]`, **entered on its WEST edge** (from the Court), so the west strip is
the region that must stay clear.

| Element | Indicative rect | Why |
|---|---|---|
| **Party plate** | `(67,-92) 4 × 4` | centre, plainly visible on entry; **no pad under or touching it** |
| Cluster A | `(60,-84) 7 × 5` | north-centre — shapes the approach without blocking it |
| Cluster B | `(77,-96) 7 × 5` | east — the flank you cross to answer a ranged threat |
| Cluster C | `(62,-101) 7 × 5` | south — makes retreat a decision |

**Persistent safe ground by construction:** the **west entrance strip** (~14 wide, full depth)
completely clear; an **east perimeter** (~8 wide, full depth); a **central lane** containing the
plate; every cluster walkable on both sides, giving **more than two ways through** the pattern;
every cluster ≥4 clear of the plate.

Three clusters rather than the reference's four because this Arena is wider than deep and entered
on a **face rather than a corner** — a cardinal four would put one cluster in the doorway.
Principle taken, geometry not copied.

**Verified before it ships:** camera pass on pad-phase readability, Envoy silhouette, enemy
trackability, and a check for trapping pockets; plus the existing law that any committed crossing
stays comfortable at 150 ticks.

### Waves (§10, §11, §14)

**Unchanged in structure** — the same three authored encounters chained by `encounter_cleared` →
`ACTIVATE_ENCOUNTER`. No wave manager, no new effect kind, no retuning of count or dependency.
Rosters are **re-placed for the new room**: flanks, ranged sightlines, the cluster pattern, spawn
fairness, and enough proximity that **every member of a wave visibly responds when it activates**.
Later disengagement under ordinary law is fine.

### §13 — pursuit persistence retired

The exception added last round (*an active encounter's roster keeps pursuit while the player is
inside its region*) is **removed**, per your ruling. Activation still engages immediately —
that half is untouched and stays pinned. The two are separated into two regressions, as §13
requires:

- **A. activation responsiveness** — an actor beyond ordinary acquisition range engages the moment
  its encounter activates.
- **B. ordinary disengagement afterwards** — once the normal predicate genuinely becomes true, it
  may disengage, and reacquires normally when the player returns.

---

## D. OPTIONAL WEST — the whole existing sequence

South Lane · Hall · Pocket · Puzzle Bay · toggle and its two doors · Cache · Return Run. Nothing
is added and nothing new is invented (§16): the chapter is **reclassified, not rebuilt**. It
already contains spikes, a fight, a switch puzzle, a search cluster and an internal loop — which
is exactly §2's *"puzzle / battle / exploration / reward"*, and it is content the player has
already seen from above, which is why the detour can tempt.

**Return relationship:** the Cache's far-side door back to the Hall stays; the chapter as a whole
returns to the Court by the lane it entered.

**One retirement:** `S_HALL` opened the old commit gate, which no longer exists. The Hall becomes
an optional battle room and keeps its partitions and its fight. *(Alternative if you'd rather keep
the beat: point that control at the Cache instead. Say which.)*

Reward payoff stays honestly deferred to real reward vocabulary; the Cache and the Reward Hall are
both reserved as its homes.

---

## E. STATUS FIX

**Defect reproduced** (`tools/diagnose_self_burn.gd`): player ignites an enemy, stands at melee
distance — radii `0.85 + 0.85`, bodies `1.2` apart — and catches their own Burn **on tick 2**.

**Representation defect confirmed.** The control run is the proof: an enemy ignited **by nobody**
and one ignited **by the player** behave identically, because `_status_instances` stores only
`{id, ticks_remaining, next_tick, applied_tick}`. After application, nothing in the sim can tell
them apart, so §21's law is *unrepresentable*, not merely unenforced.

**Fix, three narrow parts:**

1. **Owner on the instance** — record the original `source_actor_id` at application. One field on
   an existing `SCOPE_FLOOR` row.
2. **Spread inherits the ORIGINAL owner**, never the carrier (§22): *A burns E1 → E1 spreads to E2
   → E2's Burn is still owned by A → it can never return to A.*
3. **Reject transmission back to the owner** — one condition beside the existing player↔player
   line in `_advance_contact_spread`.
4. **`status_resolved` gains an optional original-source field** — omitted entirely when there is
   no actor source, following the existing payload-stability convention (no fabricated actor id,
   no moved baselines).

Not a provenance framework. Not general Burn immunity: enemy-origin Burn, environmental fire and
future authored sources all still reach the player.

**Regressions pinned** per §24: player-origin Burn does not return at contact · enemy-origin Burn
still reaches the player where the law says so · original source survives a two-step chain ·
return-to-owner rejected · provenance survives to resolution · `status_resolved` reports it
truthfully · identical state and commands produce identical spread and provenance.

---

## F. DAMAGE LEDGER

Narrow debug instrumentation on the existing overlay/log path. **No gameplay UI, no new system.**

| Field | Available today |
|---|---|
| tick | ✅ `Event.tick` |
| source kind | ✅ `SOURCE_ACTOR` default, `source` key when environment |
| source actor | ✅ `attacker_id` |
| attack profile | ✅ when the attack has one |
| damage type | ✅ |
| accepted damage | ✅ |
| status kind | ✅ `status_resolved.status_id` |
| status damage | ✅ `status_resolved.damage` |
| **status owner** | ❌ **arrives with the §20 fix** |
| **shield vs health split** | ⚠️ **to be confirmed against the pipeline** — if the two are not separable from existing events, the column is reported **unavailable rather than invented** (§26) |

**§27 liveness plan.** Before any number from this is trusted, two pins: **one direct hit** and
**one status tick** driven through the real path, asserted to arrive in the ledger. This project
has repeatedly been bitten by *silent observer ≠ no event* — a dormant roster read as "cannot use
the door", a windup-locked actor read as a stall, a melee command that never resolved read as a
dead switch. The ledger gets the same treatment: **it must be proven to consume the events the
game actually emits**, not a parallel path that happens to look right.

**§25 respected: no lethality tuning is proposed.** Self-Burn is fixed, then the ledger attributes
real play, then the concrete cause is tuned — in that order.

---

## Ruling wanted

1. **Split = the Court** (§A) — or name the room, since the image it refers to is not in the repo.
2. **The whole westward sequence becomes optional**; the new eastern chapter is critical.
3. **Court → Arena directly**, no approach room; floor becomes ~`208 × 138` — **accept or trim**.
4. **Arena:** plate centre, three clusters, masses 11/12 gone, waves structurally unchanged.
5. **Masses 2 and 9 removed** — their reveal job inverts once the lane is the optional content.
6. **Pursuit persistence retired**, activation responsiveness kept, the two split into two tests.
7. **The status fix and the ledger**, in that order, before any lethality judgement.
8. `S_HALL` retired — or repointed at the Cache.
