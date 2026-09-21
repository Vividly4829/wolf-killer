# Missions without return trips — 2026-09-20

Native Godot 4.6.2, automated headless checks:

- `tests/test_campaign.gd`: 367 checks, zero failures, all 30 waves. Includes onsite discoveries, immediate hunt credit, mixed quotas, duplicate prevention, wave 26 supply sites, every surprise dispatch, spoiled-meat replacement, victory, stale callbacks and same-frame death.
- `tests/test_intro_hunts.gd`: passed; first three hunts finish without collection, while wildlife detection, fleeing, bleeding and water movement remain checked.
- `tools/run_campaign_network.py`: host and both clients exited 0 using isolated saves and a separate UDP port. Remote discoveries share progress; a last survivor completes the job while the host and another hunter are dead; all revive automatically. Hunt kills also complete the shared round, and raiders still replicate.
- `main.gd --check-only`: passed.

Logs: `campaign-no-retrieval.log`, `intro-no-retrieval.log`, `campaign-net-host.log`, `campaign-net-a.log`, `campaign-net-b.log`.

No user save was changed. These are automated progression checks, not a new manual balance or frame-rate playtest. Older campaign QA describes the earlier carrying rules.
