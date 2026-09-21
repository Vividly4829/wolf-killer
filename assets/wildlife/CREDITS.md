# Animal assets

The game loads these optimized GLBs locally. No third-party runtime, account,
external model request or paid asset is required.

| File | Original work and author | License | Adaptation |
| --- | --- | --- | --- |
| `deer.glb` | [Old Deer Male](https://opengameart.org/node/51387), CDmir, with TinyWorlds, created for Kelgar | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Restored legacy diffuse/normal materials, selected idle/run animation clips, JPEG textures, modern glTF skin, game scale |
| `rat.glb` | [Evil Giant Rat](https://opengameart.org/content/evil-giant-rat), CDmir, with TinyWorlds, created for Kelgar | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Removed scene props, reduced small-animal geometry, dark natural eyes, selected idle/run/attack clips, restored materials and normal maps, game scale |
| `wolf.glb` | [Wolf](https://opengameart.org/content/wolf-1), Micket — Eurasian wolf anatomy and skeleton | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Smoothed/optimized anatomy, amber eyes and black nose, original grey coat shading and baked normal map, connected-joint trot/attack animation |
| `mink.glb` | Original procedural model, rig, skin weights and coat shading created for Wild Island | Project asset | Continuous elongated body, tapered tail, short jointed legs, chocolate fur, pale chin patch, wet eyes/nose, bounding gait |

The wolf and mink coat materials sample a small fur-only patch of CDmir's CC0
deer-body diffuse texture. This patch is mirrored, recolored, mapped in 3D and
baked into each model's own UV atlas. The complete deer UV atlas is not tiled
over those animals.

Sources are retained in `game/animal-source` for rebuilding. The initial NewDLC
wolf candidate in that source folder is **not shipped**; its stylized model was
replaced by the Micket Eurasian wolf. Its source license is also CC0, documented
on [3d wolf](https://opengameart.org/content/3d-wolf).

Run Blender 5.2 with `--background --factory-startup --python
game/build_animal_assets.py` to rebuild all four GLBs. The downloaded originals
are read only. `build_wolf_asset.py` and `build_mink_asset.py` can also rebuild
their respective assets individually. No embedded source-blend Python is run.

Runtime geometries, materials and textures are shared between animals of the
same species. Every animal receives its own skeleton and animation state.
`disposeAnimal()` frees instance bone textures and mixer bindings while keeping
those shared assets cached for subsequent waves.
