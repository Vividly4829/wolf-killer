# Combat world effects verification

- Focused combat effects test: zero failures, headless and native rendered run.
- Native screenshots inspected: blast radius in the bottom-right X-ray and replay, navy/white musketeer model with shako and musket.
- Covers foliage indexing/sway, per-volley trail deduplication, impact scars, barrel flames, fast grenade collision on an inclined surface, retained fuse, blast metadata, deer blast damage, beyond-range grenade travel, wave-11 encounter gating, human anatomy, staggered warning/reload, musket wall collision and effect count cap.
- Hunting combat polish regression: zero failures.
- Split-screen integration: all assertions passed, including replicated musketeer/reload state, trails and surface impacts.
- Screenshots use elevated isolated test fixtures; this does not change the playable island.
- These are functional/render checks, not a new frame-rate benchmark.
- Campaign regression: 371 checks, zero failures across all 30 waves, including explosive objective credit.
