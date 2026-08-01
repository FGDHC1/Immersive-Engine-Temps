# Immersive Engine Temps

A Cyberpunk 2077 mod (Cyber Engine Tweaks / Redscript) that simulates realistic engine oil and coolant temperature including warm-up phase, engine readiness, and cooldown behavior when the vehicle is parked.

Built from scratch, no assets or codebase reused from existing mods.

> **Status:** Early development / hobby project. Working on it whenever I have time no fixed deadline, no guarantee of completeness.

## Idea

Realistic warm-up instead of an instantly "ready" engine:
- Coolant reacts directly to RPM/speed
- Oil follows coolant with a delay (plus its own heating under sustained load)
- A derived "engine readiness" value (0–100%) shows whether the engine is warmed up
- Vehicles also cool down while parked/not mounted including time skips (sleeping/fast-forward)

## Planned roadmap

**Phase 1 – Logic & debug output** *(currently here)*
- Pure logic in CET/Lua: temperature formulas, per-vehicle persistence, cooldown timer
- Values shown as plain text in the CET overlay first, to check the behavior feels right
- No Redscript, no UI polish needed yet

**Phase 2 – 2D gauge**
- Persistent in-game HUD (not tied to the CET overlay), drawn with ImGui
- Circular gauges for coolant and oil temperature
- Still no Redscript

**Phase 3 – 3D gauge**
- In-game 3D display via Redscript
- Engine readiness value affects the vehicle itself (less power until up to operating temperature)

## License

This project is licensed under the [MIT License](LICENSE).