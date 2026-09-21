# Wolf Island native playtest — 19 September 2026

The native game has ample rendering headroom on this PC. This pass found and fixed recurring weapon-preview stalls and a wave-spawning hitch. A first-opening store pause and one isolated stress-test stall were also observed; the measurements do not justify promising completely stutter-free play.

## Machine and method

- NVIDIA GeForce RTX 3080; Intel Core i9-10900K; approximately 32 GB RAM; Windows 10.
- Portable Godot 4.6.2, GL Compatibility renderer, existing model detail, effects and quality settings.
- Native window/output sizes of 1280 × 720 and 1920 × 1080. The display reports **29.970 Hz**, so the game's default VSync caps presentation near 30 FPS. Uncapped benchmark runs change VSync only in their own process.
- These are **automated native playthroughs**, using production movement/input, game logic and rendering. The Windows computer-use screenshot helper failed with `SetIsBorderRequired: No such interface supported`, so this is not a hands-on mouse-and-keyboard playtest. Native Godot viewport screenshots were inspected instead.
- Consecutive wall-clock frame intervals; eight-second steady samples, with separate loading, warm-up and transition samples. No `--fixed-fps`, headless rendering or built-in `--qa` scene used for performance measurements.
- Normal exploration walks out of the actual cabin and triggers the natural three-wolf wave. Combat keeps the player alive with extra health, while retaining damage, injuries, struggles, escape input and AI. Larger authored fixtures maintain nine or 24 active wolves; the heaviest also includes 12 corpses and continuously generated blood/limbs. Fixture creation is excluded from steady FPS.
- The store cycles all 18 models; all 18 held weapons are selected and begin reloading. A full musket reload, wave completion, bed recovery, leaving shelter again, death, money retention and retry are checked. Every run uses and removes its own test save.

## Steady performance after changes

These are measured averages, not guaranteed minimums. The 1% low is `1000 / mean of the slowest 1% of frame times`. Higher resolution happened to run faster in these separate desktop runs; this is not a controlled GPU scaling comparison.

| Scenario | 720p mean FPS | 720p 1% low | 1080p mean FPS | 1080p 1% low |
| --- | ---: | ---: | ---: | ---: |
| Safe cabin | 380 | 64 | 476 | 85 |
| Walking outdoors | 343 | 59 | 431 | 81 |
| Three-wolf combat | 327 | 63 | 398 | 82 |
| Nine-wolf combat | 286 | 55 | 362 | 80 |
| 24 wolves, corpses and gore | 194 | 38 | 241 | 53 |
| Cycling store previews | 387 | 61 | 491 | 85 |
| Musket reload | 375 | 64 | 458 | 83 |

All seven 1080p steady scenarios had **zero frames over 33 ms**. The 720p stress sample included one **159.9 ms** stall, which affects its 1% low; it is included rather than removed from the results. The other 720p combat samples had no frames over 33 ms. Outdoor walking had one 33.0 ms interval; scripted waypoint planning is included in walking samples and adds overhead that ordinary player input does not have.

The completed shorter 1080p run with default VSync averaged approximately **30 FPS in every steady scenario**. The 24-wolf stress sample peaked at 35.8 ms; store browsing peaked at 39.9 ms. Neither steady sample contained a frame over 50 ms. The default refresh/VSync setting was left unchanged for normal play.

## Changes verified by measurement

| Measurement at 720p, uncapped | Before | After |
| --- | ---: | ---: |
| Largest frame while first leaving the cabin | 154.7 ms | 24.8 ms |
| Largest frame during repeated store browsing | 56.2 ms | 17.1 ms |
| Store browsing frames over 33 ms, eight seconds | 22 | 0 |
| Store browsing frames over 50 ms, eight seconds | 5 | 0 |
| Largest frame while cycling/reloading all 18 held weapons | 43.8 ms | 20.5 ms |

The fixes retain the existing geometry, materials, animations and spawn rules:

1. Cache each weapon's merged geometry and materials in a bounded set of 18 serialized models. Independent instances retain their own mechanisms, transforms and visibility. Prewarm these resources during loading; startup increased from about 1.78 to 2.06 seconds in the comparable 720p runs.
2. Reuse shop controls and the inspection viewport, world, lighting, camera and model wrapper. Purchases update the current controls; filters rebuild only catalog rows. Hide and stop rendering the retained preview outside the shop.
3. Use bounded random candidate selection for distant wolf spawns, with an exhaustive fallback when needed. Preserve the preferred 28–42 m band, farther-only fallback, safe-house exclusion, reachability and 2.5 m pack spacing.
4. Share a one-second succession retry after an unseen alpha death instead of repeatedly searching for a replacement in every surviving wolf's physics frame.

## Remaining observations

- **First store opening:** the 1080p run had three approximately 88–99 ms intervals shortly after opening, despite smooth repeated browsing afterward. The synchronous open call took 24 ms. The cause of those initial rendered-frame stalls is not established by this capture.
- **Isolated stress stall:** the 159.9 ms 720p frame occurred mid-combat, near a new maul. It was not a screenshot boundary. The corresponding 1080p stress phase peaked at 32.5 ms. A planned longer focused repeat was stopped at the user's request to begin manual testing; it is not treated as a completed result. The cause of the isolated stall remains unresolved.
- The 1080p measurement separates test-fixture preparation from opening the store and from killing the last wolf. Its actual wave-clear/bed transition peaked at 15.5 ms. The earlier 720p `armory_open` and `wave_clear_bed_wake` transition figures include fixture preparation and should not be interpreted as pure player-action latency.
- Native screenshots confirm a 1920 × 1080 output for the 1080p run. The initial `ViewportTexture.get_size()` metadata reports 2880 × 1620 under stretching; that descriptor differs from the actual saved image dimensions. The raw metadata is retained.
- This is a short functional/performance pass on one machine, not a long-session memory soak, a subjective audio review or a guarantee for other hardware. Audio was muted for the benchmark, with the audio systems still active.

## Functional verification

Passing checks cover game progression and saves, wolf variation and leadership, natural aggressive encounters, pack attack timing, survival/injury mechanics, the armory, native weapon input, weapon visuals, model-cache independence and spawn safety. The store regression also checks actual purchase/refill/first-aid actions, all 18 previews, scrolling, filters, drag inspection, close/reopen behavior and resource reuse. The project import check passes.

Native controller verification passed **103 checks**, including the captured-mouse trigger checks that are skipped in headless mode. Both full post-change native playthroughs and the shorter default-VSync playthrough passed all **17 scenario checks** with empty error logs. Automated runs were stopped before launching the normal game for the user's manual test.

## Evidence

- [Baseline 720p uncapped](performance-baseline-720-uncapped.json)
- [Final 720p uncapped](performance-final-720-uncapped.json)
- [Final 1080p uncapped](performance-final-1080-uncapped.json)
- [Final 1080p default VSync](performance-final-1080-vsync.json)
- [720p native screenshots](performance-final-720-uncapped-images/)
- [1080p native screenshots](performance-final-1080-uncapped-images/)

The earlier short 720p VSync run exposed a benchmark focus-pause bug in its exploration phases. Those phases were excluded from the conclusions above, and the benchmark was corrected before the full baseline and post-change runs. See the project README for reproducible commands.
