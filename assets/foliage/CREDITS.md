# Foliage assets

`birch-leaves.png` is an AI-generated RGBA birch-leaf spray image created with the
built-in image-generation tool on 18 September 2026 for this game. It is a
generated botanical illustration with a photographic appearance, not a photograph
of the property or an image sourced from a third-party asset library.

`canopies.json` contains occupied canopy volumes sampled from the existing island
Blender model by `export_island.py --foliage-cards`. The original Blender file is
not modified. `foliage.js` uses those volumes to place nine small leaf cards per
cluster (five in Smooth mode), grouped into shared instanced spatial batches.

Generation tool: built-in `image_gen.imagegen`. Saved asset: `game/assets/foliage/birch-leaves.png`.

Exact generation prompt:

> Use case: photorealistic-natural. Asset type: a production game foliage alpha texture on a genuinely transparent RGBA background. Create ONE dense natural spray of northern European birch foliage seen close-up with realistic photographic detail, approximately 35 to 50 small oval pointed serrated green birch leaves on several very slender branching twigs. Centered irregular roughly rounded leafy cluster occupying 85% of a square 1024x1024 frame, all leaves and twigs entirely inside the frame with transparent margin. Natural mixed orientations of leaves, believable branching, irregular gaps with actual transparency, fresh muted medium olive-green leaves with delicate veins and a few lighter undersides. Neutral diffuse overcast illumination, minimal baked shadows, sharp focus across the entire cluster. Intended to be mapped to crossed foliage cards in a realistic 3D coastal Norwegian woodland. No environment, no ground, no pot, no sun, no text, no border, no logos. No stylization, no chunky polygon look. Background MUST be actually transparent, including the spaces between leaves, not a checkerboard illustration.
