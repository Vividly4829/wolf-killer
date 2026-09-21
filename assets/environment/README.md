# Environment photographs

The Godot autumn revision uses original procedural painted-surface, sky and sea shaders instead of these photographic maps. These earlier CC0 source assets are retained with their attribution. The rendering notes below describe the earlier browser-game treatment.

These images are derived from CC0 Poly Haven assets. The original download URLs,
source checksums, and delivered sizes are recorded in `sources.json`.

- Forest Ground 01, Rob Tuytel: https://polyhaven.com/a/forrest_ground_01
- Rocky Terrain: https://polyhaven.com/a/rocky_terrain
- Brown Planks 03: https://polyhaven.com/a/brown_planks_03
- Kloofendal 48d Partly Cloudy (Pure Sky), Greg Zaal: https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky
- License: https://polyhaven.com/license

Run `python game/build_environment_assets.py` to reproduce the seven JPGs. Ground,
stone, and timber color/normal maps are 1024-square, recompressed from the original
1K downloads. The sky is resized to 2048 × 1024 from the tonemapped photograph.
Together they add 2,070,193 bytes to the game's download.

The renderer projects scans in world space and classifies surfaces using the
island's retained vertex palette. It does not change buildings, collision, or
navigation. A small PMREM environment texture is generated once on load. Ocean
waves perturb the normals of a two-triangle plane rather than adding dense
geometry or a second reflected-world render. The sun uses one 1024-square shadow
map covering 46 metres around the camera, updated at most about eight times per
second. Smooth quality disables that shadow pass while retaining the photographic
materials and sky.
