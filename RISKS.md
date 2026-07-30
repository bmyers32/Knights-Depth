# RISKS.md — Ranked Register
On-demand file. Reviewed at every milestone completion (/closeout step). Rank = probability × impact
against the actual goal: a game that keeps getting built because building it stays enjoyable.

| # | Risk | P | Impact | Mitigation | Status |
|---|---|---|---|---|---|
| 1 | Motivation collapse / silent abandonment — the #1 killer of solo hobby projects; not a technical risk, so no technical gate catches it | High | Fatal | Momentum Protocol (AGENTS.md): minimum-session rule, /resume command, Treat Rule, fun-part-first ordering · Always-Playable Exit (§1.11) so there's always a real game to show friends | MITIGATED in workflow |
| 2 | Process fatigue — ceremony designed for a money-losing bot is heavy for a hobby; abandoning the workflow precedes abandoning the project | Med-High | Leads to #1 | Ceremony budget ≤20% of a session · lightweight path for presentation-only sessions · /resume skips ceremony entirely | MITIGATED in workflow |
| 3 | Milestone 3 netcode wall — hardest milestone; hitting it at full scale with no fallback strands the project | Med-High | Project-fatal without fallback | Always-Playable Exit: M2 ships as a COMPLETE single-player game · netcode spike inside M2's gate (replicate one moving entity between 2 clients) so the wall is met early and small | MITIGATED in workflow |
| 4 | Total work loss — solo dev, one machine | Med | Catastrophic, trivially cheap to prevent | §1.12: work not pushed doesn't exist · push step in /closeout · private remote in bootstrap | MITIGATED in workflow |
| 5 | Fun blindness — sample size of one, builder's bias; tuning that feels right only to the person who built it | High | Medium (an un-fun game is its own motivation risk) | Friend playtests in M2+ gates (framed as sharing, not QA) · /playtest gate before art/juice budget | MITIGATED in workflow |
| 6 | Server security at M4+ — accounts on a public VPS = real auth/abuse surface | Low now / High at M4 | Credential leak, VPS abuse | §4.7: no plaintext credentials, prefer federated auth, dedicated security design session at M4 kickoff | SEEDED (revisit at M4) |
| 7 | Art wall — asset creation stalls momentum | Med | Medium | Playtest gate forbids art before fun · timebox: art ≤20% of any milestone until its mechanics gate passes | ACCEPTED (§1.5 covers worst case) |
| 8 | Estimate slippage → demoralization (M3 realistically 2–3× its estimate) | High | Feeds #1 | Estimates are ranges; milestone NOT-lists; Always-Playable Exit makes slippage non-fatal | ACCEPTED |
| 9 | Understanding gap — Claude builds systems the user can't reason about, making future debugging sessions frustrating | Med | Medium (friction, not failure — deprioritized with portfolio goal) | Concept explanations on first use (always) · opt-in "you drive" when curiosity strikes · concepts ledger in HANDOFF for lookup | ACCEPTED (opt-in tools exist) |
| 10 | Doc/code drift — law says one thing, repo does another | Med | Erodes the system | /gate spot-checks, Change Log discipline, dangling-reference rule, verify enforcement hooks by triggering them (not just reading config — see BRAIN.md) | ACCEPTED (existing controls) |
| 11 | Godot version/addon churn mid-project | Low | Medium | Version pinned; no upgrades mid-milestone | ACCEPTED (existing controls) |

Wind-down criteria (graceful pause, not failure): if two consecutive months pass with
zero sessions despite two /resume attempts, run one final close-out: make sure the last
milestone's build is uploaded and playable, HANDOFF is cold-resumable, and everything is
pushed. Then let it rest guilt-free — a hobby that's parked in a playable, resumable
state isn't dead, and the /resume command will still be there.
