# Psychedelic, lycanthropy and flame verification

- Focused test: AFFLICTION_FLAME failures=0 in headless and native rendered runs. Native error log empty.
- Tests cover immediate infected speed, no blur, delayed permanent 200 HP, 140 HP when stacked with psychedelic, no repeated mushroom penalty, rest recovery, collectible consumption/distance/repeat validation, extended radar, werewolf-like co-op model, weapon stats, wall blocking, actual animal damage, sustained keyboard firing and release.
- Split-session test passed, including player-specific mushroom consumption, server-side remote health maximum, replicated werewolf-like appearance and flame effects, and restoration to 200 HP on the next rest.
- Weapon balance regression passed after the catalogue expanded to 36 designs.
- Rendered screenshots inspected: combined vivid/red effects and condition avatar, flame stream and fire-siphon model, updated stat guide and spotted mushroom clusters on terrain.
- Mushroom geometry is batched by material per cluster; transient flame visuals share the 64-group combat effect cap.
- Zero-length grazing trajectories no longer attempt to construct an invalid X-ray beam rotation.
- These are functional and render checks, not a new framerate benchmark.
