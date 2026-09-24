# Weapon model review — 2026-09-24

Reviewed all 36 catalog weapons in a lit inspection studio and rendered all 36 in first-person hip, aim and mid-reload poses (108 first-person captures). The review targets visible silhouette, grip proportions, materials, connected components and moving sights. This is a stylized procedural-model refinement, not a replacement with scanned assets.

## Findings and changes

| Catalog index / model | Assessment and final change |
| --- | --- |
| 00 Frontier musket | Strong silhouette retained; quieter wood grain, less glossy metal, closed rear breech. |
| 01 Hammer coach gun | Strong silhouette and opening mechanism retained; material refinement. |
| 02 Winchester 1873 | Keep distinctive brass receiver, lever and stock; refine finishes. |
| 03 Hunting crossbow | Keep stock, metal limbs, string and windlass; refine wood. |
| 04 Dueling flintlock | Replace thin grip with contoured palm swell, heel and backstrap. |
| 05 Brass blunderbuss | Retain the long-arm stock and flared barrel; refine finishes and rear closure. |
| 06 Allen pepperbox | Contoured frame and grip replace blocks; preserve rotating barrel cluster. Also inherited by the hostile devil. |
| 07 Colt Navy | Continuous lower frame, recoil shield and fuller grip. |
| 08 Remington 1858 | Continuous lower frame, recoil shield and fuller grip; retain rammer and top strap. |
| 09 LeMat | Same frame/grip refinement; preserve separate lower shotgun barrel, selector and secondary ramrod. |
| 10 Derringer | Sculpted compact frame/grip; sights move with its opening barrel assembly. |
| 11 Colt single action | Sculpted frame/grip and recoil shield; retain loading gate/ejector. |
| 12 Schofield | Sculpted frame and ivory grip; retain top-break mechanism. |
| 13 Snider-Enfield | Keep recognizable rifle profile and hinged action; refine finishes. |
| 14 Martini-Henry | Keep falling-block receiver/stock; refine finishes. |
| 15 Sharps | Keep falling-block action and long barrel; refine finishes. |
| 16 Spencer | Keep carbine/lever profile; refine finishes. |
| 17 Winchester 1887 | Keep lever shotgun silhouette; refine finishes. |
| 18 Throwing knife | Forged blade ridge and thin cutting edge, contoured riveted handle and pommel; hide unsupported second hand. |
| 19 Belt axe | Curved handle, defined cutting edge/beard, poll, eye and handle wrap; one-handed presentation. |
| 20 Hunting spear | Leaf-shaped forged head, socket, binding and metal butt cap. |
| 21 Ash bow | Flattened tapered limbs, wrapped grip, nock tips and feathered removable arrow. |
| 22 Yew longbow | Longer limb geometry than ash bow; same detailed grip/arrow treatment. |
| 23 Horn recurve | Recurved tips and dark horn/wood lamination distinguish it from the two wooden bows. |
| 24 Iron grenade | Rounded body, fuse collar, grooves and bent fuse replace a plain cylinder. |
| 25 Dynamite | Red paper cartridges, pale end caps, leather straps/buckles, label and bent fuse replace wood cylinders. |
| 26 Aether musket | Connected copper coils and capped cell bank on a mechanical cradle; retain crank mechanism. |
| 27 Lancaster | Contoured frame/grip; four-barrel sights follow the break action. |
| 28 Mauser C78 | Inherits sculpted revolver frame/grip; retain distinctive cylinder zigzags. |
| 29 Mauser 1871 | Strong long-rifle silhouette/bolt retained; refine finishes. |
| 30 Gold naval pair | Fuller ivory grips, backstraps and closed breeches; both hands track their gun during reload/recoil. |
| 31 Twin blunderbusses | New purpose-built short pistols replace miniature shoulder-stock guns; correct primary sight and hand tracking. |
| 32 Paired revolvers | Inherit rebuilt revolver frames/grips; independent hand tracking. |
| 33 Drum Luger | Sculpted receiver with rails/fasteners, refined grip and magazine neck; retain toggle and drum. |
| 34 Hand mortar | Fix floating sights by parenting sights/ladder to the opening breech; close see-through rear tube. |
| 35 Fire siphon | Connected horizontal reservoir with domed caps/straps, curved hose, pressure gauge, pump, valve and pilot line. Dedicated pump/valve reload replaces invalid musket-ramrod animation. |

## Verification

- `tests/test_weapon_visuals.gd`: 684 checks passed across all 36 slots, including finite reload poses, triangle preservation, bounded meshes, bow loaded state, dual hand attachment, alternate muzzle/sight and LeMat secondary mechanism.
- `tests/test_weapon_model_cache.gd`: 184 checks passed across all 36 models, including resource sharing, independent mechanisms and no extra orphan templates. Measured cold construction about 301 ms total / warm about 3.14 ms total; this is model construction timing, not a gameplay framerate measurement.
- Batched model mesh count: 4–38 per weapon. Added detail stays grouped by material.
- `tests/test_weapon_balance.gd`: passed. No catalog price, damage, ammunition, accuracy or reload-time changes.
- Native OpenGL renders: no script errors. Inspected studio contact sheets and all hip/aim/reload sheets; repeated after sight-parenting and dual-grip corrections.
- Godot headless editor import and `git diff --check`: clean.

## Repeat the visual review

Run `tests/preview_armory_review.gd` with the native Godot renderer (add `-- --after` for after-sheet filenames), and `tests/preview_armory_first_person.gd` with `-- --capture`. They write ignored PNG contact sheets under `qa/`; the latter uses a transient progress profile. Images from this review remain available locally as `armory-review-before-0..2.png`, `armory-review-after-0..2.png` and `armory-fps-hip/aim/reload-0..2.png`.

Source update only. No executable rebuild or release publication, following the latest release preference.
