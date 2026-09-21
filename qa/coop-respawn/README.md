# Co-op spawning, friendly-fire X-ray and round rescue

Validated on Godot 4.6.2, September 20, 2026.

- `tests/test_coop_respawn.gd`: three real ENet processes on localhost. Separate building positions; dead host remains in an active simulation; host plus one client dead with one survivor; objective completion revives both fallen players at their assigned buildings; weapons lost only on death and wallets retained; total team wipe reaches level 1 on all peers.
- `tests/test_coop.gd`: three processes, actual client-fired ray resolved by host, health and reward replication, human X-ray report delivered back to remote shooter.
- `tests/test_human_xray.gd`: brain, heart and leg trajectories and multipliers; correct human renderer and friendly-fire caption. Native OpenGL captures `human-xray.png` and `waiting.png`, inspected at 1280 x 720.
- `tests/test_coop_loot.gd`: two processes, shared pickup, remote werewolf bite and next full-moon health/speed recovery.
- `tests/test_intro_hunts.gd`: 25 checks passed.
- `tests/test_free_play.gd`: 17 checks passed.

All tests use isolated progress saves and remove them afterward. Network coverage is local multi-process testing, not Internet/NAT or packet-loss testing. The round-rescue test triggers the authoritative objective callback directly; the separate co-op test exercises client firing and host hit resolution. The human skeleton and organ volumes are a stylized gameplay model, not medical anatomy.

One co-op regression run logged the existing ENet channel-0 send warning during peer shutdown after successful assertions. No gameplay assertion failed; graceful shutdown remains a known limitation.
