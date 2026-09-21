# Windows export validation

Built with official Godot 4.6.2 Windows x64 release templates. All game data is embedded in `WolfIsland.exe`; the ZIP also includes engine and asset notices. The package includes the current animal-limb changes requested for this build.

Validation:

- `test_all_animal_limbs.gd` passes on the source tree.
- Exported EXE completes the headless `--qa` gameplay run, reporting `VISUAL_QA_COMPLETE` without script errors. This uses a QA progress file, not the normal player profile.
- The ZIP is extracted to a fresh directory outside the project; its EXE checksum matches the build manifest.
- Native startup is checked from that extracted directory with a short movie-frame capture and QA profile. The compiled game loads its own embedded resources without a source checkout or Godot installation.

The native startup capture exits after four frames and reports resource-cleanup warnings at that forced early exit. The complete headless gameplay run finishes cleanly. The captured native main menu was visually inspected.

Build sizes, hashes and the source commit are in `releases/windows/build.json`. Engine/export-template binaries and unpacked build output remain excluded from Git. The compressed Windows package is committed in `releases/windows/`.
