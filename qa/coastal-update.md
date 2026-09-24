# Coastal photographs, boats and roaming predators — 24 September 2026

## Changes

- Photo-informed dark timber cladding, framed windows, taller southern cabin, terracotta roof, waterside shelter, slender deck rails, quay boarding, lifebuoys and blue barrels. Approximate details follow mapped footprints; original red cabin, island GLB, world terrain JSON and surrounding source GLB are preserved.
- Four four-seat motorboats, 9.1125 m/s maximum speed. Host validates shore proximity, stationary boarding/exit, unobstructed boarding path, capacity and driver-only input. Land, quays, other boats and low obstacles stop motion. Releasing controls brakes; disconnected/dead drivers release their seat. Wake/reset clears occupancy and returns boats to their moorings.
- Keyboard E / controller Y board and exit; W/S+A/D or left stick drive; Space / A brake. Blue minimap triangles locate boats. Local and internet passengers follow authoritative boat transforms, bypassing land navigation while aboard.
- Shared roaming destinations, spaced pack travel and occasional shared wildlife pursuits. Stable angular flank slots before staggered charges. Werewolves search near hunters at a calm walking pace before ordinary detection/warnings engage.

## Validation

- Godot 4.6.2 headless import: no script errors.
- Coastal boat tests: berth placement, stationary/near-shore restrictions, open-sea refusal, navigable exits, speed specification, land/bounds rejection and accessible house portals.
- Local co-op tests: keyboard movement and controller Y mapping, host-authoritative boarding, separate seats, maximum speed and actual movement, replication, no land-navigation snap, braking, driver handover, four-seat capacity and round reset.
- Pack roaming: roughly 23 metres travelled in the terrain test; shared destination and at least three encirclement quadrants. Unalerted werewolf travelled through terrain, with about 2 m/s peak horizontal search speed, without bypassing perception.
- Wolf building exits: both ordinary and larger wolves exited all six neighbouring buildings (12 cases), with asynchronous route searches advancing on physics frames.
- Existing 70-check split-session regression, 82-check surroundings preservation suite and werewolf warning/charge test passed.
- Four separate game processes connected through a real public TLS invite: shared boat occupancy, travel, passenger positions, ritual stacks and actor health/death replicated. These processes ran on one PC; this is not a test across four independent household networks.
- Native renderer captured and reviewed southern cabin, waterfront, western cabin and boat views. No gameplay frame-rate claim is made by these captures.

The Windows build and its hash are recorded in releases/windows/build.json. Screenshots and raw test logs remain local under qa/.
