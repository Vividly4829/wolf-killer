# Campaign verification — September 20, 2026

The native Godot game now uses `scripts/campaign_catalog.gd` and
`scripts/campaign_director.gd` for the authored 30-wave expedition. The playable
rules and mission list are in `../../CAMPAIGN.md`.

Verified with isolated test wallets:

- **394 assertions, zero failures** across all 30 jobs, cargo pickup/drop/stowing,
  delivery destinations, safe introduction, moon schedule, enemy quotas, all surprise
  dispatches, spoiled-meat recovery, vital shots, death persistence and final victory.
- Introductory hunting regression: frightened/injured deer escape and leave blood;
  deer and water geese must now be retrieved before resting. Passed.
- Live bear/raider navigation, warning, charging, damage, reload and safe-cabin checks.
  Passed both headless and native rendering; captures show the new original models,
  bear X-ray and rain.
- Three real ENet processes: remote cargo pickup, carrier death, dropped-cargo
  recovery, extraction by the last survivor, revival, new enemy replication and
  mission-state synchronization. All host/client assertions passed.
- Two independent local viewports, separate spawn buildings/physics, keyboard and
  injected controller movement/jump. Passed.
- Free Play's isolated inventory/save, passive animals, target scoring and ammunition.
  Passed. Range rays exclude wandering practice animals to test fixed lane geometry.

## Native frame-time sample

1280 × 720, OpenGL compatibility, NVIDIA RTX 3080. Default VSync is enabled on a
display previously measured at 29.970 Hz. Each scenario has a 2-second warm-up and
approximately 8 seconds sampled. This is a short stationary active-AI smoke test,
not a complete expedition, GPU comparison or minimum-FPS guarantee.

| Scenario | Mean FPS | 95th percentile frame | Longest frame |
|---|---:|---:|---:|
| Wave 27: bear and four raiders | 29.98 | 38.09 ms | 64.38 ms |
| Wave 30: three werewolves and six wolves | 29.97 | 34.63 ms | 60.80 ms |

Earlier runs exposed large synchronous pathfinding spikes. `route_search.gd` now
retains A* state across frames and gives wildlife, new enemies and campaign wolves
a combined 3 ms physics-frame budget. Local path smoothing is also bounded.
The older synchronous helper remains for offline/one-off route queries.

Raw output is in `performance.json`, with the first comparison in
`performance-before.json`; logs are in the parent `qa` directory. Snapshots were
captured by the native renderer and inspected. The performance fixture directly
jumped waves; its original screenshots retained the starting weather. The fixture
now also calls the normal weather wake function for each scenario. Normal campaign
progression's midnight blood moons are separately asserted for every fifth wave.

The bear and raider models are stylized procedural originals. This is an initial
balance pass: no claim is made that a human has completed and balanced all 30 rounds.
Public-internet latency and a physical controller require a hardware playtest.
