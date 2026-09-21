# X-ray hit feedback

- Actual damage lost by the displayed animal is shown in large red text. The calculated damage breakdown and tissue distance remain available. The replay labels each hit animal in red, including blast victims with individual target IDs.
- All miss panels are fully opaque again. Expanded review scale is 0.78 in solo and 0.55 in split screen, anchored at the lower right so the paired panels leave the screen center unobstructed. Double-X dismissal still works.
- Three original, non-tonal flesh impacts replace the old hit beep. Confirmed reports trigger sound for the shooter in solo and co-op. Multiple pellets hitting one animal produce one impact voice per shot; another struck animal gets its own sound. History browsing and range targets stay silent.

Validation: compact HUD and shot replay tests passed, including damage values, per-animal labels, full-opacity misses, screen-center clearance, co-op report audio and deduplication. Native replay tests passed and an expanded hit screenshot was visually inspected. Local split-screen integration passed. Original audio can be regenerated with tools/build_flesh_impacts.py.
