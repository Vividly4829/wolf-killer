# September 30 gameplay update

## Changes

- Rebuilt runtime bridges as 4.2 m timber decks with flush land approaches and rail openings at junctions. Obstacles are cleared from runtime meshes; original GLB files remain unchanged. Nearby shrubs are excluded. Existing approach paths at buildings are preserved instead of adding ramps into walls.
- Original animated four-legged night beast: articulated legs/hocks, moving jaw, pointed mane, emissive red eyes, quadruped organ tracing and matching limb areas. Static detail is batched by material under each animated joint.
- Dynamite is armed on throw and waits for another click; the host detonates the owner's charges after 0.3 s. Armed/countdown labels replicate.
- Emerald Crank Pistol: 975 CR, 30 base damage, 20 shots per crank, 0.16 s firing interval, four-second base crank, unlimited recharges. Green beam, no drop or damage falloff; ray covers 100 km, beyond all playable terrain. Existing rifle remains red.
- Infected were-rabbits can appear among ambient wildlife from wave 6; ordinary rabbits remain for hunting objectives. Emissive red eyes, dark fur and exposed teeth/claws.
- Reduced human ranged accuracy, including musketeers, historical squads, bow/throwing raiders and hostile devil.
- Downed hunters retain owned, stowed and equipped weapons through teammate or paid revival. Starting a new run after defeat still resets inventory.
- Host-owned per-session kill ledger with species icons, counts and kill reward value. Compact summaries; K / controller View opens the complete ledger. Kill feed shows hunter, species, weapon and heart/head icons. Existing shared cash reward rules are preserved. Late joiners receive the ledger.
- Each hunter can leave the starting cabin once per round. Local movement and authoritative remote poses reject re-entry; new-round rest resets the restriction. Fast travel returns outside the cabin.
- Bear and moose coats/sizes vary deterministically and replicate to clients. Extra facial/anatomical detail. Bear surprise encounters may include two from wave 18 and three from wave 24.

## Validation

- `september30-bridges-final.log`: 264 traversals, zero failures; zero collision obstructions across six clearance rays per route.
- `september30-weapons.log`: 739 visual/model/mechanism checks pass, including the new pistol.
- `september30-gameplay.log`: 14 checks pass: 500 m no-drop shot, twenty-shot recharge, remote fuse timing, cabin boundary, rig animation, animal variation and kill attribution.
- `september30-revive.log`: 14 checks pass, including both revival directions, inventory preservation, wall/distance restrictions and stale packet rejection.
- `september30-coop.log`: 13 checks pass, including appearance replication, kill ledger attribution, remote charge trigger and cabin re-entry rejection.
- `september30-limbs.log`: all species limb regression checks pass, including new quadruped limbs and lethal network snapshots.
- Rendered and inspected creature/weapon lineup, bridge junction and four-player full ledger. Bridge render confirmed clear rail gaps at turns. Ledger uses six icon columns to fit all supported species in short split-screen viewports.
- Clean final editor import and Windows export. New output directory used because the prior EXE was running and locked.

No new internet WAN or framerate benchmark was performed for this update; co-op regression tests use the game's local authoritative transport.

Packaged Windows executable smoke test: `VISUAL_QA_COMPLETE`, no script errors. Archive and embedded executable SHA-256 hashes match the build manifest.
