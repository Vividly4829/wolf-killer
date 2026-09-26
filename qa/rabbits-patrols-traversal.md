# Rabbits, late patrols and traversal — 26 September 2026

## Gameplay

- Existing local wallets and recovery copies reset to zero. Save migration
  revision 1 resets older profiles once; subsequent earnings remain persistent.
  Inventory and continue checkpoints are retained.
- Shooting is blocked inside the main cabin and within 3 horizontal metres of
  its footprint. Both the local firing path and host validation enforce this.
- Three fat rabbits join the ambient population. Food objectives on waves
  7, 13, 19 and 26 include rabbits; the director replenishes huntable targets.
- Ordinary rabbits have 45 HP and reward 8 credits. The cursed were-rabbit has
  320 HP, rewards 85 credits, pursues players, bites through clear sight only,
  and transmits lycanthropy. It enters the random encounter pool from wave 6.
- Were-rabbit sacrifice: Bloodmoon Bound, +50% jump height per stack. Rabbit
  sacrifice: Lightfoot, +20% airborne movement speed per stack. Both appear in
  the existing player status panel and retain the established ritual lifetime.
- Confederate and Nazi patrols enter the random encounter pool at wave 20.
  Each contains exactly four soldiers, independent of player count. Uniforms,
  physical projectiles, host-side damage, human anatomy, rewards and replica
  creation use the existing hostile NPC systems. The Nazi leader has a locally
  synthesized alert bark; provenance is in the audio asset notice.

## Navigation and performance changes

- Bridge movement and height follow continuous, spatially indexed deck planes,
  including endpoint overlap. Rails prevent sideways departures onto lower
  terrain. One west-islet approach now matches the cabin's 6 m landing.
- Coarse coastal links are mirrored onto overlapping fine-grid cells, removing
  disconnects at terrain-grid boundaries.
- Nearest-node searches stop once a closer sample cannot exist. Wolf direct
  path checks and wildlife sensing/spacing checks are cached briefly; movement
  still checks navigation each step. A* work shares a render-frame budget so
  physics catch-up cannot multiply it.
- Actors beyond 75 m from every player use accumulated 0.12 s simulation steps.
  Nearby actors retain normal updates. Distant actors still move and bleed.
- Client replicas retain body targeting and visual limb damage; authoritative
  limb hitboxes remain on the host. Unchanged fall transforms and capsule
  dimensions no longer trigger redundant physics updates.
- Split screen retains native framebuffer resolution. Local views use two
  shadow cascades to 40 m; three/four-player views disable MSAA. Hidden full-size
  HUDs stop rebuilding during split-screen play, and compact HUDs redraw at 20 Hz.

## Validation

- Bridge sweep: 150 forward/reverse walks across 25 bridges at centre and both
  side offsets; 0 failures (42 failures before changes).
- Sloping terrain: 1,797 connected routes; 0 failures.
- Woodland player movement: 48 walks through 24 brush corridors; no failures;
  maximum camera height change 3.1 cm per simulated frame.
- New-content checks cover wallet migration, cabin buffer, rabbit anatomy,
  mission inclusion, four-soldier gating at wave 20 and stacking rituals.
- Co-op checks cover all three new enemy types, were-rabbit infection and damage,
  synchronized deaths, replica limb handling and host-side shooting restrictions.

Native stress results are recorded separately in the completion report. Runs use
3840×2160 on an RTX 3080, a late-game wave, and ten seconds of measurement after
warm-up. Early exploratory runs had variable surviving enemy counts and should
not be treated as a controlled before/after ratio. No internet latency or remote
controller hardware is simulated by the local transport checks.


Final native stress samples (same seeded late wave; 23 wolves + 24 wildlife):

| Local players | Render resolution | Mean FPS | 95th-percentile frame | Slowest frame |
|---|---|---:|---:|---:|
| 2 | 3840 × 2160 | 29.91 | 47.41 ms | 59.85 ms |
| 4 | 3840 × 2160 | 30.00 | 45.11 ms | 57.41 ms |

This is approximately 30 FPS, not a locked 30 or 60 FPS guarantee. Exploratory
four-player samples before the final optimizations were around 15–21 FPS.
Native GPU: NVIDIA GeForce RTX 3080; Godot 4.6.2 OpenGL compatibility renderer.
Disabling VSync did not improve the heavy four-player case, so the game's VSync
setting was retained. Pack AI, anatomy and mission mechanics remain active.

Final regression results: new gameplay checks passed; all nine new-enemy local
co-op checks passed; all-animal limb checks passed; all eleven wallet/continue
checks passed; four-player input ownership and native 4K HUD tests passed.
