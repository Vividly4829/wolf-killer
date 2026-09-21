# Cabin and wildlife feedback — 20 September 2026

Implemented smoother deer steering and shore exits, corrected the imported deer's doubled ground offset and idle clip, added client pose interpolation, extended close wolf warnings to 4–6 seconds with repeated growling/circling, and reduced the musket reload from 6.5 to 3.25 seconds.

Every one of the nine enterable buildings now provides store access and reachable steaming coffee. C / D-pad right restores 30 HP with a 20-second per-player/per-building cooldown; injuries still require their normal treatment. Coffee proximity and healing are validated on the host. Invalid building requests are rejected. Other buildings retain their existing wolf access.

New profiles start with 350 credits. Legacy profiles below 350 receive one top-up; higher balances are preserved and the allowance marker prevents repeated grants. Both local HUDs show their own wallet and struggle percentage/bar.

## Verification

- `test_cabin_feedback.gd`: 60 focused checks passed in the final headless run. Also rendered natively: all nine stores, reachable cups and steam; repeated coffee; starter migration; full-cycle deer ankle clearance; actual idle clip; warning/snarl/circle/attack sequence; reload time. Isolated test saves only.
- `test_deer_shore.gd`: 24 checks passed, including 12 frightened deer across four shoreline fixtures for 720 ticks. No deer stalled over four seconds, no overlapping shoreline crowd. Movement update median 1.484 ms / p95 6.936 ms for this synthetic 12-deer workload, not a whole-game framerate benchmark.
- `test_split_session.gd`: 37 checks passed in native Godot. Controller coffee heals P2 only, remains synchronized, enforces cooldown, and cabin Y opens only P2's shop. Existing separate input, pickups, shots, death, recovery and restart checks also passed.
- `test_progress.gd`: 50 checks passed. Its deliberate corrupt-save fixture prints one expected ConfigFile parse error before successfully recovering the backup.
- `test_campaign_runtime.gd`: six current bear/raider/cabin checks passed.
- Visually inspected `deer-ground-corrected.png`, `cabin-coffee.png`, and `split-credits-struggle.png`. The last uses staged 65%/30% struggle progress to inspect both HUDs; it is not evidence of a live dual attack.

## Legacy test limitations

`test_game.gd` passes its reload stages, gun behavior and other checks but has 14 failures out of 72 concerning old wave counts, kill rewards including mission bonuses, and obsolete advance/rest expectations. `test_wolf_pack_game.gd` passes 24 of 26 checks, including actual variable-strength mauling; its final two checks still expect completing all manually inserted wolves in the introductory deer mission to advance the wave and then spawn a five-wolf pack. These fixtures predate the authored campaign and were not rewritten in this change. Their logs are retained alongside the passing focused tests. This is not a claim that the entire legacy suite is green.
