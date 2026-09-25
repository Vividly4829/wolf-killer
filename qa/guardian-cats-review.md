# Rideable tabby guardians

Two original procedural long-haired tabbies appear outdoors at the main cabin from wave 10 onward. Their warm/silver striped coats, pale muzzle/ruff, green eyes, ear tufts, whiskers and ringed tails follow the supplied fantasy-cat reference. Both have saddles, moving legs/head/tail, swipe animation and a fallen pose. Other players see a seated riding pose.

Each round both respawn at full health. Each has 2.15 times the average ordinary wolf's health at that wave (307.45 HP at wave 10), and a 32-damage swipe every 1.1 seconds. Stronger than two baseline wolves, but vulnerable to packs/bosses. Health scales with ordinary wolf progression, capped at 387 HP.

Guard radius: 32 metres around each outdoor home point; 42-metre pursuit limit. They intercept wolves, hostile humans/supernatural enemies, alerted bears and actively attacking deer/moose. Peaceful wildlife and the neutral devil are ignored. Enemies retaliate; incapacitated/dead enemies cannot keep attacking. Their kills use ordinary player reward and mission paths, including shared co-op money. They do not create extra objective animals.

E / controller Y mounts or dismounts. One rider per cat, two riders total. WASD / left stick controls riding relative to camera direction (8.5 m/s maximum). Boarding faces forward. Dismounting preserves health/stamina/ammunition; cats return home via navigation, including obstacle steering. Boats and fast travel cannot simultaneously carry a mounted player. Death/mauling releases the rider. Mounted cats still swipe at nearby threats inside the guard area.

Host owns health/combat/movement/saddles. Local split-screen and online co-op share the same request/snapshot paths; guests cannot award their own kills or reserve an occupied saddle.

Validation: Godot import, native model and mounted split-screen captures, automated wave gating, two cats, power budget, outdoor homes, host/guest mounting, exclusive saddles, movement, dismount, return home, mission/reward credit, peaceful/hostile selection, retaliation, rider death release and round respawn replication. Existing revive regression passed. Internet latency was not tested on external machines. Source only; no new executable/release.
