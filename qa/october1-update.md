# October 1 gameplay and HUD update

- Shared compact HUD for solo and 2–4 local seats: icon objectives, health/stamina/wallet strip, compact weapon readout, corner map. Detailed permanent powers appear on X; kill ledger remains on K/controller View.
- Crouch and airborne states travel guest → host → all guests. Articulated crouch/jump poses, visible-model smoothing and crouch collision/anatomy alignment.
- Downed players remain visible on all maps with red rescue crosses; local and replicated downed roots settle to terrain with valid-land fallback.
- Host-authoritative mounted cat jumping (Space/controller A), replicated height, tucked legs and rider attachment.
- Were-rabbits acquire hunters within 110 m, reconsider prey every 0.3 s, run at 7.4 m/s before terrain/limb modifiers, and bite for 28 every 0.8 s with line-of-sight validation.
- Unlimited field bandages; 2.4-second use and bleeding-only treatment retained.
- Store includes price, capacity/reserve, damage/pellets, effective/max range, actual reload, fire interval, accuracy cone, tissue penetration and muzzle speed/blast radius.
- Slow terrain climbing across unlinked sampled slopes, with body-height collision checks. Raised bridges retain their boundary protections.
- Range targets accept the current ballistic call signature, return trajectory/damage reports, score 1–10, use a 0.25 + score × 0.175 simulated damage multiplier, and illuminate the struck ring. Target board appears in replay; feedback synchronizes across peers.
- Wave 30 has exactly 15 required wolves, five required werewolves, and one 1,200 HP melee vampire. Vampire bites deal 42 and recover 20 HP; random wave complications disabled for this finale. Counts do not scale with player count.

## Validation

- tests/test_september_update.gd: 14 preceding-feature regression checks passed.
- tests/test_october_update.gd: 29 checks passed in four local viewports; real ballistic range hits, replicated target feedback, grounded-down recovery, repeated zero-inventory bandaging, cat jump/landing, eight store stat fields, slope traversal and wall rejection, exact finale counts.
- Native four-player screenshot inspected at 3840 × 2160; each seat has clear center and bounded corner panels.
- Internet transport coverage uses a localhost ENet host/client test, not a new WAN relay test. Physical controllers were not manually operated; controller A and keyboard Space share the tested jump handler.
- Climbing validation covers representative slope and wall cases, not an exhaustive walk of every terrain coordinate.

- tests/test_pose_network.gd: actual localhost ENet host/client passed guest and host animation-state exchange, downed state and grounded revival with inventory retention. Clean disconnect verified after guarding inactive ENet peer queries.
- Solo store and all-15-power status screenshots inspected at 4K; no overlapping stat fields.

- Windows export succeeded with no script/export errors. Packaged EXE startup QA exited 0. Executable and ZIP SHA-256 match the release manifest; build/windows-latest refreshed. Current source is explicitly marked dirty in the build manifest (not committed by this task).
