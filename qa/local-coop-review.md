# Local co-op: two to four players

Choose 2 PLAYERS, 3 PLAYERS, or 4 PLAYERS from the main menu. Player 1 always uses keyboard/mouse; each additional player needs a separate controller. No online join/handshake is involved. Each local hunter has a separate persistent wallet/profile. Missing controllers display their player number and can be connected after starting.

Two players use horizontal halves. Three use a full-width upper view and two lower views. Four use equal quadrants. Native framebuffer resolution is divided among the cameras (on 3840 × 2160: halves 3840 × 1080; quadrants 1920 × 1080). 3D scaling remains 100%; UI uses aspect-appropriate logical dimensions. Existing fullscreen/HiDPI settings remain enabled.

Health/status/powers, minimap, interaction text and X-ray/replay stay inside each view. Menus fit the available view height. Expanded HUD still uses the normal X/controller detail control.

Validation: native OpenGL 3840 × 2160 captures for three/four players; automated immediate start, peer identities/avatars, starting credits/shared rewards, distinct save paths, controller isolation, native camera pixel allocation and X-ray bounds. Existing two-player session regression also runs. Additional controller events are synthetic: this workstation does not have three physical controllers connected. This is not a sustained four-player framerate benchmark.

Source update only; no executable export or release.
