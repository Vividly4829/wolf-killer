# Hunting and combat polish verification

Implemented and checked in Godot 4.6.2 using isolated save files:

- Raiders carry bows, knives, axes or spears. Enemy arrows/throws use swept movement and solid-world collision, with an additional wall visibility check at damage time. Melee requires close range and line of sight. Co-op sends the selected weapon and projectile visuals.
- Original island GLB/source model remains unchanged. Runtime bullet collision respects the source's non-solid scenery tags; solid geometry still blocks shots. Added undergrowth remains visual cover with movement slowdown.
- Sprint speed 5.4 → 8.1 m/s; stamina 300 → 450. Shooting and quick throws are disabled while sprinting, including host validation for remote inputs.
- Explosions have larger expanding fire/smoke puffs lasting three seconds. Grenades/dynamite show their remaining fuse above the live projectile in both player views. Launcher shells detonate on the first impact; the old 0.2-second arming delay is removed.
- Cached paired gun meshes retain their surface materials when batched. All four latest weapon models have multiple materials and no missing material surfaces. Native paired-blunderbuss screenshot inspected.
- Close deer encounters roll a 22% defensive reaction, with a 25-second recheck cooldown. A brief charge can deal 14 damage, then the animal flees. Free Play bypasses this behavior.
- Shot history stores up to eight nearby animals along the firing corridor. Miss replays reconstruct their firing-time poses, label them UNHIT, and frame the nearest animal/closest approach. Host IDs prevent duplicated hit/unhit copies in co-op.
- Existing severing remains specific to ordinary wolf leg zones; this update does not add detachable deer/bear/human limbs.

`test_hunting_combat_polish.gd` covers these rules, wall-blocked and unobstructed projectile damage, impact detonation, countdowns, material preservation, foliage/solid collision distinction, deer defense and recovery, missed-animal reconstruction, co-op loadouts/countdowns and remote sprint rejection. Split-session, four-second replay and previous combat-feedback suites also pass. Native screenshots: `polish-miss.png` and `combat-weapon-31.png`.

These are scripted integration tests and native visual checks, not a new internet multiplayer soak test or frame-rate benchmark.
