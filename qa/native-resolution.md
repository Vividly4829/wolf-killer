# Native-resolution rendering

The old startup configuration opened a 1280 × 720 window. Solo fullscreen
already used canvas-item stretching, which renders the 3D world at the window's
resolution, but split-screen always used 1280 × 360 camera textures.

Startup now uses native borderless fullscreen, explicit HiDPI support and a
100% 3D render scale. Split camera textures follow the parent viewport's physical
content dimensions; separate 1280 × 360 UI coordinates keep the HUD and menu
layout readable. Mouse look uses unscaled physical motion, while GUI clicks
continue using UI coordinates. F11 and window resizing remain supported.

Native Godot 4.6.2 / RTX 3080 validation on the connected 3840 × 2160 display:

- Solo window and captured framebuffer: 3840 × 2160; 3D scale 1.0.
- Both split camera image buffers: 3840 × 1080; 3D scale 1.0.
- UI layout stays 1280 × 720 solo / 1280 × 360 per split viewport.
- A mouse click activates the correctly positioned split-screen UI control.
- 1600 × 900 window resizes both camera buffers to 1600 × 450.
- Returning to fullscreen restores 3840 × 1080 per hunter.
- Inspected full-resolution solo and split captures; no upscaled 720p gameplay.

Test: `tests/test_native_resolution.gd` (native renderer required).
Evidence: `native-resolution.log`, `native-resolution-solo.png`,
`native-resolution-split.png`. This is a resolution/UI verification, not a
4K combat frame-rate benchmark.

Implementation references: [Godot multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html),
[SubViewport 2D sizing](https://docs.godotengine.org/en/stable/classes/class_subviewport.html).
