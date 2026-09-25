# Angel arrival and named guardians

Every fifth sacrifice now announces the angel group with: “Heaven has reviewed your rituals. Your punishment is out for delivery.” Three angels appear in a small formation at a random bearing, 200 metres horizontally from the marked hunter and 18 metres above that hunter. Their existing pursuit AI brings them in. Their health remains 750 each.

A ten-second recorded Hallelujah choir cue accompanies the notice. It uses a dedicated audio player so combat effects cannot steal its voice; a short shared cooldown prevents duplicate audio across local split-screen viewports. Online clients receive the announcement through the existing reliable authority RPC. Recording provenance and adaptation are documented in assets/audio/ANGEL_CHOIR.md.

The guardians are Tijgertje and Sirius. Sirius has a charcoal-black striped coat, with lighter muzzle/ruff and green eyes. Both have a model scale of 0.60 and fixed 150 HP on every eligible round. Names appear in mount/dismount and fallen messages. Rider offsets follow model scale; movement clearance accommodates the smaller cat and rider. Wave-ten availability, riding, protective behavior and respawn remain in place.

Validation: supernatural regression includes three 200 m spawn-distance checks and choir asset duration. Guardian co-op regression checks names, 150 HP, model scale on host and guest, resized saddle, riding, return home, shared mission rewards and round respawn. Native two-cat studio render reviewed at qa/guardian-cats-models.png. No Windows executable rebuild in this source-only update.
