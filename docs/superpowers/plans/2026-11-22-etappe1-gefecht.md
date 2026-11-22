# Etappe 1 – Ein Gefecht: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein komplett spielbares Seegefecht (3 Wellen) in Godot 4.7.2 mit modernem Stealth-Zerstörer, Railgun inkl. Überladung, Flak, drei Gegnertypen und Stil „Sturmnacht · Neon“, exportiert für Windows ARM64 und Linux x86_64.

**Architecture:** Reine Spiellogik liegt in `game/core/` als typisierte `RefCounted`-Klassen ohne Szenenbezug und ist mit GUT getestet. Szenen und Nodes (`world/`, `ships/`, `fx/`, `ui/`, `main/`) verdrahten diese Logik mit Darstellung, Eingabe und Audio. Modelle entstehen reproduzierbar per Blender-Skript (`tools/blender/`), Sounds per Python-Synthese (`tools/audio/`). Visuelle Prüfung läuft über ein Capture-Harness (Xvfb + lavapipe, Forward+).

**Tech Stack:** Godot 4.7.2-stable (GDScript, statisch typisiert, Forward+), GUT v9.7.1, Blender 4.0 (Python, glTF-Export), Python 3 + numpy (Audio-Synthese), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-22-railgun-design.md`. Visuelle Referenz: `docs/reference/` (Stil B).

## Global Constraints

- Godot **4.7.2-stable** exakt (lokal `/usr/local/bin/godot`, in CI dieselbe Version). Projekt liegt in `game/` (`game/project.godot`).
- GDScript **durchgehend statisch typisiert**. `class_name` für alle Logikklassen. Projekt-Einstellung `debug/gdscript/warnings/untyped_declaration = 2` (Fehler).
- Renderer **Forward+**. `rendering/rendering_device/driver.windows = "d3d12"`. Grafikstufe „Mittel“ = `mobile` über `application/config/project_settings_override = "user://settings_override.cfg"`.
- Koordinaten: Spielebene ist XZ, Y = oben, Meeresspiegel y = 0. 2D-Logik nutzt `Vector2(x, z)`. Heading `h` = `rotation.y`. Vorwärts = `Vector2(-sin(h), -cos(h))`. Turmwinkel relativ zum Rumpf, 0 = vorn, positiv = links (gleicher Sinn wie `rotation.y`).
- Maßstab: 1 Einheit = 1 m (stilisiert). Zerstörer 24 m, Fregatte 16 m, U-Boot 14 m, Schnellboot 6 m. Karte 400 × 400 m.
- Alle Spielwerte stehen in `game/core/tuning.gd` (`class_name Tuning`, nur `const`). Kein Spielwert wird in anderen Dateien hartkodiert.
- Farben Stil B: Spieler/Energie Cyan `#4de8ff`, Gegner-Akzent Rot `#ff3b3b`, Fenster warm `#ffd27a`, Nebel `#0b1220`, Wasser tief `#03070d`, Wasser hell `#14334a`, Schaum `#9fc3d6`.
- Spieltext auf **Deutsch**. Schriften: **Chakra Petch** (Anzeige, OFL, aus `google/fonts` per Sparse-Clone) und **JetBrains Mono** (Daten, OFL, `apt fonts-jetbrains-mono`). Beide unter `game/assets/fonts/` samt `OFL.txt`.
- Assets nur selbst erzeugt (Blender-Skript, Python-Synthese) oder OFL-Fonts. Keine Fremd-Assets.
- Projekt-Einstellungen: Fenster 1920×1080, `display/window/stretch/mode = "canvas_items"`, `aspect = "expand"`, MSAA 3D 2×, Glow an.
- Spielgefühl-Anti-Ziel: Ein vollflächig ausgebleichter Frame darf höchstens während des Hitstops (≤ 0,09 s) stehen.
- Commits: kleine Commits pro Task, Nachricht im Format `feat|test|chore: …` mit den Trailer-Zeilen des Repos.

## Review Focus

1. **Fokusverlust bei gehaltener Maustaste** (Alt-Tab, Fensterwechsel): Die Ladung wird abgebrochen, es gibt keine hängende Ladung und keine Überhitzung. Test in Task 2 (`cancel()`) und Task 9 (Fokus-Notification).
2. **Schiff fährt gegen Insel oder Kartenrand:** Es stoppt bzw. gleitet ab und clippt nicht durch. Test in Task 4 (`resolve_blockers`).
3. **Feuern in COOLDOWN/LOCKED, nach Tod oder auf dem Endbildschirm:** Es passiert nichts, kein Zustand bleibt hängen. Tests in Task 2 und Task 13.
4. **Überladener Schuss durch 6+ Ziele auf einmal:** Explosionen werden über einen Pool gedeckelt, es gibt keinen Einbruch durch unbegrenzte Partikel. Test in Task 10 (`FxPool`).
5. **Andere Fenstergrößen** (1280×720, 2560×1080, 4K): HUD und Cursorring bleiben verankert und lesbar. Capture in Task 14 mit beiden Größen.

---

## Dateistruktur

```
.github/workflows/ci.yml            Tests + Exporte
tools/blender/build_models.py       erzeugt game/assets/models/*.glb
tools/audio/synth.py                erzeugt game/assets/audio/*.wav
tools/capture.sh                    Screenshot-Harness (xvfb + lavapipe)
game/project.godot, export_presets.cfg, default_bus_layout.tres
game/addons/gut/                    GUT v9.7.1 (vendored)
game/core/        tuning.gd railgun_state.gd railgun_shot.gd beam_hit.gd health.gd
                  ship_motion.gd turret_aim.gd wave_director.gd feel_state.gd
                  ocean_effects.gd fx_pool.gd settings.gd
game/world/       ocean.gd ocean.gdshader environment_b.tres weather.gd island.gd
game/ships/       player_ship.gd/.tscn flak_turret.gd enemy.gd speedboat.gd frigate.gd
                  submarine.gd shell.gd torpedo.gd
game/fx/          feel.gd (Autoload „Feel“) railgun_fx.gd explosion_fx.gd beam.gdshader
game/camera/      follow_camera.gd
game/ui/          theme.tres hud.gd/.tscn cursor_ring.gd title.gd/.tscn end_screen.gd pause_menu.gd
game/main/        battle.gd/.tscn game_flow.gd (Autoload „Flow“)
game/audio/       audio_bank.gd (Autoload „Sfx“)
game/debug/       capture.gd (Autoload „Capture“) scenarios/*.gd
game/tests/       test_*.gd
```

---

### Task 1: Projektgerüst, GUT, CI-Testjob, Tuning

**Files:**
- Create: `game/project.godot`, `game/core/tuning.gd`, `game/tests/test_tuning.gd`, `game/addons/gut/` (Kopie aus Tag v9.7.1), `.github/workflows/ci.yml`, `.gitignore` (`game/.godot/`, `build/`, `*.import` NICHT ignorieren), `tools/run_tests.sh`

**Interfaces:**
- Produces: `Tuning` mit diesen Konstanten (Startwerte, später feintunbar):
  - Railgun: `CHARGE_TIME=1.2`, `OVERCHARGE_TIME=1.3`, `COOLDOWN=1.0`, `BASE_DAMAGE=100.0`, `BEAM_RANGE=260.0`, `BEAM_HALF_WIDTH=1.2`, `BEAM_HALF_WIDTH_OVER=1.2` (zusätzlich bei voller Überladung), `HEAT_PER_SHOT=0.2`, `HEAT_PER_SHOT_OVER=0.5`, `HEAT_OVERCHARGE_PER_SEC=0.5`, `HEAT_DECAY_PER_SEC=0.2`, `MISFIRE_SELF_DAMAGE=40.0`, `LOCK_TIME=4.0`, `HEAT_AFTER_MISFIRE=0.6`, `HITSTOP=0.08`
  - Schiff: `PLAYER_HULL=300.0`, `MAX_SPEED=14.0`, `MAX_REVERSE=5.0`, `ACCEL=3.0`, `BRAKE=5.0`, `WATER_DRAG=0.6`, `TURN_RATE=0.45`, `TURN_MIN_FACTOR=0.15`
  - Turm: `TRAVERSE_RATE=1.4`, `TURRET_ARC=deg_to_rad(150.0)`
  - Flak: `FLAK_RANGE=60.0`, `FLAK_RATE=8.0`, `FLAK_DAMAGE=6.0`
  - Gegner: `SPEEDBOAT_HP=40.0`, `SPEEDBOAT_SPEED=22.0`, `SPEEDBOAT_GUN_DMG=4.0`, `SPEEDBOAT_GUN_INTERVAL=0.5`, `SPEEDBOAT_RANGE=45.0`, `FRIGATE_HP=180.0`, `FRIGATE_SPEED=7.0`, `FRIGATE_SALVO=3`, `FRIGATE_SHELL_DMG=20.0`, `FRIGATE_SALVO_INTERVAL=5.0`, `FRIGATE_RANGE=140.0`, `SHELL_FLIGHT_TIME=1.8`, `SUB_HP=90.0`, `SUB_SPEED=9.0`, `SUB_SUBMERGED_TIME=7.0`, `SUB_SURFACED_TIME=5.0`, `TORPEDO_DMG=45.0`, `TORPEDO_SPEED=18.0`, `SUB_RANGE=120.0`
  - Ablauf: `WAVE_DELAY=3.0`, `MAP_HALF=200.0`
- `tools/run_tests.sh`: `godot --headless --path game --import && godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` mit Exit-Code ≠ 0 bei Fehlschlag.

- [ ] **Step 1:** `project.godot` mit allen Projekt-Einstellungen aus *Global Constraints* anlegen (Name „Modern Ships“, Forward+, d3d12, Override-Datei, Stretch, Warnungen). GUT v9.7.1 nach `game/addons/gut` kopieren und das Plugin aktivieren.
- [ ] **Step 2: Failing test** `test_tuning.gd::test_overcharge_window_and_damage_sane`: `assert_gt(Tuning.OVERCHARGE_TIME, 0.0)`, `assert_eq(Tuning.BASE_DAMAGE, 100.0)`, `assert_true(Tuning.TURRET_ARC < PI)`
- [ ] **Step 3:** `tools/run_tests.sh` ausführen. Erwartet: FAIL (Tuning fehlt).
- [ ] **Step 4:** `tuning.gd` mit allen Konstanten anlegen.
- [ ] **Step 5:** Tests ausführen. Erwartet: „All tests passed“.
- [ ] **Step 6:** CI-Job `test` in `ci.yml` (ubuntu-24.04): Godot 4.7.2 Linux von `github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip` laden und `tools/run_tests.sh` ausführen. Auslöser: push, pull_request.
- [ ] **Step 7:** Commit `chore: scaffold Godot project, GUT, CI test job`. Push auf Branch `etappe-1`, Draft-PR öffnen, CI-Lauf grün prüfen (`gh pr checks`).

### Task 2: RailgunState (Laden, Überladung, Hitze, Fehlzündung)

**Files:** Create `game/core/railgun_state.gd`, `game/core/railgun_shot.gd`. Test `game/tests/test_railgun_state.gd`

**Interfaces:**
- Produces:
  - `class_name RailgunShot extends RefCounted`: `damage: float`, `overcharge: float` (0..1), `half_width: float`
  - `class_name RailgunState extends RefCounted`:
    - `enum State { READY, CHARGING, COOLDOWN, LOCKED }`
    - `var state: State`, `var charge: float` (0..1, voll nach `CHARGE_TIME`), `var overcharge: float` (0..1, linear über `OVERCHARGE_TIME` nach voller Ladung), `var heat: float` (0..1)
    - `func press() -> void`: nur in READY → CHARGING
    - `func release() -> RailgunShot`: bei `charge < 1` Abbruch, gibt `null` zurück und geht nach READY. Sonst Schuss mit `damage = BASE_DAMAGE * (1 + overcharge)`, `half_width = BEAM_HALF_WIDTH + BEAM_HALF_WIDTH_OVER * overcharge`. Die Hitze steigt um `HEAT_PER_SHOT + HEAT_PER_SHOT_OVER * overcharge`, danach folgt COOLDOWN.
    - `func cancel() -> void`: CHARGING → READY, kein Schuss
    - `func tick(dt: float) -> bool`: gibt `true` genau im Tick einer Fehlzündung zurück. Beim Halten in der Überladung steigt die Hitze um `HEAT_OVERCHARGE_PER_SEC*dt`. Außerhalb von CHARGING sinkt sie um `HEAT_DECAY_PER_SEC*dt`. Erreicht die Hitze 1,0, folgt die Fehlzündung: LOCKED für `LOCK_TIME`, Hitze danach `HEAT_AFTER_MISFIRE`, die Ladung ist weg.

- [ ] **Step 1: Failing tests** (je ein `func test_…`):
  - `test_release_before_full_cancels`: press, tick(0.6), release → `null`, `state == READY`
  - `test_full_charge_fires_base_damage`: press, tick(1.2), release → `damage == 100.0`, `overcharge == 0.0`, `state == COOLDOWN`
  - `test_overcharge_doubles_damage`: press, tick(1.2 + 1.3), release → `damage ≈ 200.0`, `half_width ≈ 2.4`
  - `test_cooldown_blocks_press`: nach Schuss press → `state == COOLDOWN`. Nach tick(1.0) und press → `CHARGING`
  - `test_holding_overcharge_overheats_and_locks`: press, wiederholt tick(0.1) bis `tick()` `true` liefert (spätestens nach 6 s) → `state == LOCKED`, `heat ≈ 0.6`. press während LOCKED bleibt LOCKED. Nach tick(4.0) → READY
  - `test_spamming_overcharged_shots_overheats`: drei Schüsse mit je voller Überladung hintereinander führen spätestens beim dritten Laden zur Fehlzündung
  - `test_cancel_while_charging` (Review Focus 1): press, tick(0.8), cancel → READY, `charge == 0`. Danach release → `null`
  - `test_heat_decays_when_idle`: heat 0.5 setzen, tick(1.0) → `heat ≈ 0.3`
- [ ] **Step 2:** Tests ausführen. Erwartet: FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** Tests ausführen. Erwartet: PASS.
- [ ] **Step 5:** Commit `feat: railgun charge/overcharge/heat state machine`

### Task 3: BeamHit + Health

**Files:** Create `game/core/beam_hit.gd`, `game/core/health.gd`. Test `game/tests/test_beam_hit.gd`, `game/tests/test_health.gd`

**Interfaces:**
- Produces:
  - `class_name Health extends RefCounted`: `_init(max_hp: float)`, `var hp: float`, `var max_hp: float`, `func damage(amount: float) -> bool` (true nur bei dem Treffer, der tötet), `func is_dead() -> bool`, `func fraction() -> float`
  - `class_name BeamHit extends RefCounted`:
    - Zieltyp per Duck-Typing: Objekte mit `get_hit_center() -> Vector2`, `get_hit_radius() -> float`, `can_be_hit() -> bool`
    - `static func cast(origin: Vector2, dir: Vector2, max_range: float, half_width: float, targets: Array, blockers: Array) -> Dictionary`. Rückgabe: `{ "end_distance": float, "hits": Array }`. `hits` sind Dictionaries `{ "target": Object, "distance": float }`, aufsteigend sortiert. `blockers` sind Dictionaries `{ "center": Vector2, "radius": float }` (Inseln). Der erste geschnittene Blocker kürzt `end_distance`. Ziele dahinter werden nicht getroffen. `dir` wird intern normalisiert.

- [ ] **Step 1: Failing tests** mit einer Testklasse `FakeTarget` im Testfile:
  - `test_pierces_all_targets_in_line`: Ziele bei (10,0), (30,0), (50,0), r=2, Strahl von (0,0) Richtung (1,0) → 3 Treffer in Reihenfolge 10, 30, 50
  - `test_misses_target_outside_width`: Ziel (20, 5), r=2, half_width 1.2 → 0 Treffer. Mit half_width 3.1 → 1 Treffer
  - `test_ignores_targets_behind_and_beyond_range`: Ziel (-10,0) und (300,0) → 0 Treffer
  - `test_island_blocks_beam`: Blocker center (40,0) r 8, Ziele bei 20 und 60 → nur 20 getroffen, `end_distance ≈ 32`
  - `test_skips_targets_that_cannot_be_hit` (abgetauchtes U-Boot): `can_be_hit()` false → kein Treffer
  - Health: `test_damage_kills_once` (100 HP: damage 60 → false, damage 60 → true, damage 10 → false), `test_fraction`
- [ ] **Step 2:** Tests ausführen. Erwartet: FAIL.
- [ ] **Step 3:** Implementieren. Strahl-Kreis-Schnitt per Projektion auf `dir`: Abstand senkrecht zur Linie ≤ `radius + half_width`, Projektion in `[0, end_distance]`.
- [ ] **Step 4:** Tests ausführen. Erwartet: PASS.
- [ ] **Step 5:** Commit `feat: piercing beam hit test and health`

### Task 4: ShipMotion + TurretAim

**Files:** Create `game/core/ship_motion.gd`, `game/core/turret_aim.gd`. Test `game/tests/test_ship_motion.gd`, `game/tests/test_turret_aim.gd`

**Interfaces:**
- Produces:
  - `class_name ShipMotion extends RefCounted`: `_init(max_speed: float, max_reverse: float, accel: float, turn_rate: float)`. Felder `position: Vector2`, `heading: float`, `speed: float`. Methoden:
    - `step(throttle: float, rudder: float, dt: float) -> void`: throttle und rudder jeweils −1..1. Bei throttle 0 bremst `WATER_DRAG*speed` langsam ab, S bei Vorwärtsfahrt bremst mit `BRAKE`. Drehrate = `turn_rate * rudder * lerp(TURN_MIN_FACTOR, 1, clamp(|speed|/max_speed, 0, 1))`, bei Rückwärtsfahrt invertiert. Position bewegt sich entlang Vorwärts.
    - `resolve_blockers(blockers: Array, ship_radius: float) -> void`: drückt aus Kreisen heraus, entfernt die Geschwindigkeitskomponente in die Wand und klemmt auf `±MAP_HALF`
  - `class_name TurretAim extends RefCounted`: `var angle: float` (relativ zum Rumpf), `func step(target_world_yaw: float, hull_heading: float, dt: float) -> void`, `func world_yaw(hull_heading: float) -> float`. Die Drehung ist begrenzt auf `TRAVERSE_RATE*dt`, der Winkel auf `±TURRET_ARC`. Der Turm dreht niemals durch den toten Winkel am Heck (bei ±180°), sondern immer über die Front.

- [ ] **Step 1: Failing tests:**
  - `test_accelerates_to_max_speed_not_beyond`: throttle 1 für 20 s → `speed ≈ 14.0`
  - `test_turns_slowly_at_standstill`: speed 0, rudder 1, 1 s → `|heading| ≈ 0.45*0.15`
  - `test_turns_full_rate_at_max_speed`
  - `test_coasts_to_stop`: von 14 ohne throttle nach 15 s → `speed < 1`
  - `test_reverse_capped`: throttle −1, 20 s → `speed ≈ -5.0`
  - `test_island_pushes_ship_out_and_kills_inward_speed` (Review Focus 2): Schiff fährt auf Kreis zu, nach `resolve_blockers` liegt es außerhalb von `radius + ship_radius` und die Geschwindigkeit ist nicht mehr positiv in Richtung Zentrum
  - `test_map_edge_clamps`
  - Turm: `test_traverse_rate_limited` (Ziel 90° links, 0.5 s → `angle ≈ 0.7`), `test_clamps_at_arc` (Ziel genau achtern → `angle` bleibt bei ±150°), `test_never_crosses_dead_zone` (von +140° auf −140° wird `angle` kleiner und passiert 0), `test_world_yaw_includes_hull`
- [ ] **Step 2:** Tests ausführen. Erwartet: FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** Tests ausführen. Erwartet: PASS.
- [ ] **Step 5:** Commit `feat: ship inertia motion and turret aim with dead zone`

### Task 5: WaveDirector

**Files:** Create `game/core/wave_director.gd`. Test `game/tests/test_wave_director.gd`

**Interfaces:**
- Produces: `class_name WaveDirector extends RefCounted`
  - `const DEFAULT_WAVES: Array` = Welle 1: 4× `&"speedboat"`, 1× `&"frigate"`. Welle 2: 2× frigate, 4× speedboat, 1× `&"submarine"`. Welle 3: 2× frigate, 2× submarine, 6× speedboat. Jeder Eintrag ist `{ "type": StringName, "count": int }`.
  - `_init(waves: Array = DEFAULT_WAVES)`, `var current_wave: int` (1-basiert, 0 vor Start), `var alive: int`
  - `func tick(dt: float) -> Array[StringName]`: liefert die Typen, die jetzt spawnen sollen. Welle 1 kommt nach `WAVE_DELAY` ab Start, jede weitere `WAVE_DELAY` nachdem `alive` 0 erreicht hat.
  - `func enemy_died() -> void`, `func is_complete() -> bool`, `func total_waves() -> int`

- [ ] **Step 1: Failing tests:** `test_first_wave_after_delay` (tick 2.9 → leer, tick 0.2 → 5 Einträge, `current_wave == 1`), `test_next_wave_only_after_all_dead`, `test_complete_after_last_wave_cleared`, `test_enemy_died_never_negative`
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5:** Commit `feat: wave director`

### Task 6: Pure Hilfsklassen für FX und Gefühl (FeelState, OceanEffects, FxPool, Settings)

**Files:** Create `game/core/feel_state.gd`, `game/core/ocean_effects.gd`, `game/core/fx_pool.gd`, `game/core/settings.gd`. Tests `game/tests/test_feel_state.gd`, `test_ocean_effects.gd`, `test_fx_pool.gd`, `test_settings.gd`

**Interfaces:**
- Produces:
  - `class_name FeelState extends RefCounted`: Felder `trauma`, `kick`, `flash`, `hitstop_left`, `pulse` (alle 0..1 bzw. Sekunden). `add_shot(overcharge: float)` setzt trauma 0.8+0.2·o, kick 1, flash 1, pulse 1, hitstop `HITSTOP*(1+0.5·o)`. `add_impact(strength: float)` setzt trauma `min(1, trauma+0.5·s)`. `tick(real_dt: float) -> float` gibt den Zeitfaktor zurück (0.0 während Hitstop, sonst 1.0) und lässt die Werte abklingen: trauma −1.5/s, kick und flash und pulse exponentiell mit 5/11/2.6 pro s. `shake_offset(time: float) -> Vector3` liefert ein deterministisches Rauschen mal trauma².
  - `class_name OceanEffects extends RefCounted`: Ringpuffer mit 8 Ring-Slots und 2 Schneisen-Slots. `add_ring(pos: Vector2, strength: float)`, `add_trench(from: Vector2, to: Vector2, width: float)`, `set_charge(pos: Vector2, amount: float)`, `tick(dt)`. `ring_data() -> PackedVector4Array` (x, z, Alter, Stärke; 8 Einträge, ungenutzte haben Alter 99), `trench_data() -> PackedVector4Array` (2× from/to) und `trench_meta() -> PackedVector2Array` (Alter, Breite)
  - `class_name FxPool extends RefCounted`: `_init(capacity: int)`, `acquire() -> int` (Slot-Index; bei Vollbelegung wird der älteste recycelt), `release(i: int)`, `active_count() -> int`
  - `class_name Settings extends RefCounted`: `static func set_quality(high: bool) -> void` schreibt `user://settings_override.cfg` mit `[rendering] renderer/rendering_method="forward_plus"|"mobile"`. `static func is_high() -> bool` liest die Datei, Standard ist true. Pfad über `static var override_path` überschreibbar (für Tests).

- [ ] **Step 1: Failing tests:** `test_hitstop_returns_zero_scale_then_one`, `test_overcharge_lengthens_hitstop`, `test_trauma_decays_to_zero`, `test_ring_buffer_recycles_oldest` (9 Ringe → Slot 0 enthält Ring 9), `test_rings_age`, `test_pool_caps_and_recycles` (Review Focus 4: capacity 8, 12× acquire → `active_count() == 8`), `test_quality_roundtrip` (temp-Pfad, set_quality(false) → `is_high() == false`, Dateiinhalt enthält `"mobile"`)
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5:** Commit `feat: feel state, ocean effect slots, fx pool, quality settings`

### Task 7: Ozean, Umgebung Stil B, Wetter, Capture-Harness

**Files:** Create `game/world/ocean.gdshader`, `game/world/ocean.gd`, `game/world/environment_b.tres`, `game/world/weather.gd`, `game/debug/capture.gd` (Autoload `Capture`), `game/debug/scenarios/ocean_only.gd`, `game/debug/sandbox.tscn`, `tools/capture.sh`. Test `game/tests/test_ocean.gd`

**Interfaces:**
- Consumes: `OceanEffects` (Task 6)
- Produces:
  - `Ocean` (Node3D, `class_name Ocean`): Gitter-Mesh 420×420 m, Unterteilung ≥ 300 pro Seite. Öffentlich:
    - `static func wave_height(x: float, z: float, t: float, amp: float) -> float`: dieselbe Summe aus 5 Sinuswellen wie im Shader. Wellenvektoren, Amplituden und Frequenzen stammen aus dem Mockup `docs/reference/railgun-stilproben.html` (`waves()`), Amplitude Stil B `1.55`.
    - `effects: OceanEffects`. Dazu `add_ring(pos: Vector3, strength: float)`, `add_trench(from: Vector3, to: Vector3, width: float)` und `set_charge(pos: Vector3, amount: float)`: Sie leiten auf XZ projiziert weiter und schreiben jeden Frame die Uniforms.
    - `set_beam_glow(from: Vector3, to: Vector3, amount: float)`
  - Der Shader portiert das Wasser aus dem Mockup (`waterVS`/`waterFS`): Wellen, Schneise, Ringe, Ladekreise, Schaum mit Value-Noise, Fresnel, Mond-Spec, Strahl-Licht. Er läuft als `spatial`-Shader mit `render_mode` Standard, Nebel über Godot.
  - `environment_b.tres`: Hintergrund `#0b1220`, ACES, Glow (Threshold so, dass nur Emissives > 1 glühen; Lehre aus dem Mockup: heller Schaum darf nicht glühen), volumetrischer Nebel (Dichte ~0.015, Albedo dunkelblau), DirectionalLight als Mond (`#9fb8ff`, 0.5), schwaches Ambient.
  - `Weather` (Node3D): Regen als `GPUParticles3D` (Streaks, Wind), Blitze alle 5–11 s (Umgebungs-Energie-Flash plus Flackern), Signal `lightning(strength: float)` für den Donner-Sound (Task 11).
  - `Capture`-Autoload: liest `OS.get_cmdline_user_args()`: `--capture-scenario=<name>`, `--capture-dir=<abs>`. Lädt `res://debug/scenarios/<name>.gd` (Methode `func run(capture: Node) -> void` als Coroutine). Stellt `await capture.shot("name")` bereit (speichert PNG) und `await capture.wait(sec)`. Beendet am Ende das Spiel. Ohne Argumente ist es inaktiv.
  - `tools/capture.sh <scenario> [WxH]`: `xvfb-run -a -s "-screen 0 ${WxH}x24" godot --path game --rendering-driver vulkan --resolution WxH --fixed-fps 30 --disable-vsync <scene> -- --capture-scenario=… --capture-dir=$PWD/build/captures/<scenario>`
- [ ] **Step 1: Failing tests:** `test_wave_height_bounded` (|h| ≤ 1.55·0.75 über ein 50×50-Raster), `test_wave_height_continuous` (benachbarte Punkte im Abstand 0.1 m unterscheiden sich um < 0.1), `test_ocean_forwards_ring_to_effects` (Ocean instanziieren, `add_ring` → `effects.ring_data()[0].w == strength`)
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5: Visuelle Prüfung:** `tools/capture.sh ocean_only` (Szenario: 2 s warten, Shot „calm“, Ring und Schneise auslösen, 0.3 s, Shot „fx“). Screenshots ansehen und mit `docs/reference/stil-b-*.png` vergleichen. Erwartet: dunkle, bewegte See mit Schaum auf Kämmen, sichtbarer Regen, Ring und Schneise mit Schaum. Kein flächiger Glow-Schleier.
- [ ] **Step 6:** Commit `feat: ocean shader, storm environment, weather, capture harness`

### Task 8: Modelle per Blender-Skript (moderne Stealth-Schiffe, Inseln)

**Files:** Create `tools/blender/build_models.py`, `tools/blender/README.md` (Aufruf). Erzeugt `game/assets/models/{destroyer,frigate,speedboat,submarine,island_a,island_b,island_c}.glb`. Test `game/tests/test_models.gd`

**Interfaces:**
- Produces (Vertrag für alle späteren Tasks):
  - Alle Schiffe zeigen nach −Z (Bug), Wasserlinie bei y=0. Material-Namen: `HullDark`, `Deck`, `Superstructure`, `Accent`, `Window` (emissiv warm), `NavRed`, `NavGreen`, `EnemyAccent` (emissiv rot, nur Gegner), `Energy` (emissiv cyan, nur Railgun)
  - `destroyer.glb` (L 24 m, B 4.6 m): Tumblehome-Rumpf mit Knick und Fasen, facettierter Brückenaufbau mit integriertem Mast und 4 flachen Radar-Paneelen, VLS-Felder (Raster-Deckel) vorn und mittschiffs, Hubschrauberdeck mit Markierung achtern. Empties: `TurretPivot` (Vorschiff, ca. z=−6), darunter Objekt `Railgun` (langer flacher Turm, zwei offene Schienen, Spulenringe, mittiges `Energy`-Band) mit Empty `Muzzle` an der Rohrspitze; `FlakPivot` (achtern auf dem Aufbau), `Bridge`
  - `frigate.glb` (16 m): Stealth-Fregatte, kompakter facettierter Aufbau, Empties `Gun_0..2` (Breitseiten-/Bugposition), `Bridge`
  - `speedboat.glb` (6 m): Gleiter/Katamaran mit flacher Kabine, Empty `Gun`
  - `submarine.glb` (14 m): Jagd-U-Boot, Turm mit Tiefenrudern, X-Heckruder, Empty `Tube`. Ursprung so gewählt, dass bei y=0 der Turm über Wasser liegt
  - Gegner-Schiffe haben eine teilbare Struktur: Wurzelkinder `Bow` und `Stern` (Teilung mittschiffs) für das Zerbrechen
  - Inseln: felsige Low-Poly-Inseln (Felskante, Klippe, etwas Vegetation in dunklen Tönen). Radius ≈ 18, 12 bzw. 8 m. Ursprung in der Mitte auf Meereshöhe
  - Stil: Low-Poly-facettiert, Fasen an allen Kanten, kein sichtbarer Grundkörper ohne Bearbeitung (Anti-Ziel)
- [ ] **Step 1: Failing test** `test_models.gd`:
  - `test_destroyer_contract`: lädt die glb, findet `TurretPivot/Railgun/Muzzle`, `FlakPivot`, AABB-Länge (Z) 24 ± 2,4
  - analog für `frigate` (`Gun_0`, `Bow`, `Stern`), `speedboat` (`Gun`, `Bow`, `Stern`), `submarine` (`Tube`, `Bow`, `Stern`)
  - `test_islands_load`
- [ ] **Step 2:** Tests ausführen. Erwartet: FAIL (Dateien fehlen).
- [ ] **Step 3:** `build_models.py` schreiben: bmesh-Konstruktion pro Modell, Bevel-Modifier angewendet, Materialien zugewiesen, Export als GLB (`export_apply=True`). Aufruf: `blender -b --factory-startup --python tools/blender/build_models.py -- game/assets/models`
- [ ] **Step 4:** Skript ausführen, Godot-Import, Tests. Erwartet: PASS.
- [ ] **Step 5: Visuelle Prüfung:** Szenario `model_lineup` (alle Modelle nebeneinander auf dem Ozean, Kamera 3/4 von oben, Shots „lineup“ und „close_destroyer“). Erwartet: klar moderne Silhouetten, erkennbare Stealth-Facetten. Kein Weltkriegs-Look, kein Quader-Look. Bei Quader-Eindruck nachbessern, bevor committet wird.
- [ ] **Step 6:** Commit `feat: procedural modern ship and island models`

### Task 9: Spielerschiff, Steuerung, Kamera

**Files:** Create `game/ships/player_ship.gd`, `game/ships/player_ship.tscn`, `game/camera/follow_camera.gd`, `game/debug/scenarios/drive.gd`. Modify `game/project.godot` (Input Map). Test `game/tests/test_player_ship.gd`

**Interfaces:**
- Consumes: `ShipMotion`, `TurretAim`, `RailgunState`, `Health`, `Ocean.wave_height`, `destroyer.glb`-Vertrag
- Produces:
  - Input-Aktionen: `move_forward` (W), `move_back` (S), `rudder_left` (A), `rudder_right` (D), `fire` (linke Maustaste), `pause` (Esc)
  - `class_name PlayerShip extends Node3D`:
    - Signale `fired(shot: RailgunShot, origin: Vector3, dir: Vector3)`, `misfired()`, `damaged(amount: float)`, `died()`, `charge_started()`
    - Felder `motion: ShipMotion`, `turret: TurretAim`, `railgun: RailgunState`, `health: Health`, `aim_point: Vector3` (Mausposition auf y=0, von der Kamera gesetzt), `input_enabled: bool`, `blockers: Array`
    - `func apply_damage(amount: float) -> void`
    - `func get_hit_center() -> Vector2`, `get_hit_radius() -> float` (4.0), `can_be_hit() -> bool`
    - `func muzzle_transform() -> Transform3D`
    - Auftrieb: Position y und Neigung (pitch/roll) folgen `Ocean.wave_height` an Bug, Heck, Backbord und Steuerbord (gedämpft). Rückstoß: Schiff um 0,7 m entgegen der Schussrichtung versetzen, Rohr um 0,9 m zurück, beides federt zurück
    - `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` → `railgun.cancel()` (Review Focus 1)
  - `class_name FollowCamera extends Camera3D`: `target: Node3D`, Neigung 50°, Abstand 55 m, Vorausblick 12 m in Zielrichtung, weiche Nachführung. `func set_feel(offset: Vector3, kick: float, fov_add: float, charge_zoom: float) -> void`. Setzt jeden Frame `target.aim_point` per Strahl Maus → Ebene y=0.
- [ ] **Step 1: Failing tests:**
  - `test_focus_out_cancels_charge`: PlayerShip instanziieren, `railgun.press()`, `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` → READY
  - `test_dead_ship_ignores_fire` (Review Focus 3): health auf 0, `_handle_fire_input(true)` und dann `false` → kein `fired`-Signal (über `watch_signals`). `_handle_fire_input(pressed: bool)` ist die interne Methode, die die Eingabe an `railgun` weitergibt
  - `test_fire_emits_signal_with_muzzle_origin`: press, `railgun.tick(1.2)`, Loslassen → `fired` mit `origin == muzzle_transform().origin`
  - `test_misfire_damages_self`: Hitze 0.99 setzen, in der Überladung halten → `misfired` und `health.hp == 300 - 40`
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5: Visuelle Prüfung:** Szenario `drive` mit simulierter Eingabe über `Input.action_press` (vorwärts 4 s, Ruder links 3 s, Turm schwenken). Shots alle 1,5 s. Erwartet: Kielwelle sichtbar (über `OceanEffects`-Ring-Spur oder Schaumspur), Schiff rollt in den Wellen, Turm folgt.
- [ ] **Step 6:** Commit `feat: player destroyer with inertia, turret, follow camera`

### Task 10: Railgun-Effekte und Feel-Autoload

**Files:** Create `game/fx/feel.gd` (Autoload `Feel`), `game/fx/railgun_fx.gd`, `game/fx/beam.gdshader`, `game/fx/explosion_fx.gd`, `game/debug/scenarios/railgun.gd`. Modify `player_ship.tscn` (RailgunFx-Kind). Test `game/tests/test_feel.gd`

**Interfaces:**
- Consumes: `FeelState`, `FxPool`, `Ocean`, `PlayerShip`-Signale, `FollowCamera.set_feel`
- Produces:
  - `Feel` (Node, `process_mode = ALWAYS`): `func shot(overcharge: float)`, `func impact(strength: float, at: Vector3)`, `func _advance(real_dt: float) -> void` (wird aus `_process` mit Echtzeit-Delta aufgerufen, Tests rufen es direkt). Setzt `Engine.time_scale` während des Hitstops auf 0.0 und danach auf 1.0. Die eigene Echtzeit misst es über `Time.get_ticks_usec()`. Pro Frame treibt es Kamera (Shake, Kick, FOV), Glow-Intensität, Exposure, chromatische Aberration und Vignette (Fullscreen-`ColorRect` mit Shader in einem `CanvasLayer`) sowie Flash.
  - `RailgunFx` (Node3D unter PlayerShip): Lade-Visuals abhängig von `railgun.charge` und `railgun.overcharge`: emissive Energie im Material `Energy`, Lichtbögen (`ImmediateMesh`-Zickzack, neu alle 0,045 s), Einsaug-Funken (GPUParticles3D, Attraktor), OmniLight an der Mündung, `ocean.set_charge`. Bei der Überladung pulsiert das Glühen weiß und Hitzeflimmern am Rohr setzt ein.
  - `func play_shot(origin: Vector3, dir: Vector3, length: float, overcharge: float)`:
    - Strahl aus Kern, Hülle und Außenglühen (Zylinder mit `beam.gdshader`, Fresnel-Alpha, Endfade). Zeiten aus dem Mockup: Kern 0,4 s, Hülle 1,25 s, Außen 0,55 s
    - eine Spirale aus Partikeln entlang der Bahn
    - Kette aus 6 OmniLights entlang des Strahls mit `light_volumetric_fog_energy`, die den Nebel ausleuchten
    - Mündungs-Feuerball, zwei Luft-Druckringe, Rauch
    - Gischt- und Dampfspur entlang der Bahn
    - `ocean.add_trench` und `ocean.add_ring`, `ocean.set_beam_glow`
    - Alle Größen skalieren mit `1 + overcharge`
  - Nachglühen: Schienen und `Energy`-Band glühen nach dem Schuss 1 s nach und klingen ab. Am Ende des Cooldowns spielt `recharge`.
  - `ExplosionFx`: `func play(at: Vector3, strength: float)`: Blitz, Feuerbälle, Rauch, Funken, Wasserfontäne, Trümmer (RigidBody-lose Kinematik wie im Mockup), `ocean.add_ring`. Über `FxPool(8)` gedeckelt.
- [ ] **Step 1: Failing test:** `test_feel_restores_time_scale` (`Feel.shot(0)` → `Engine.time_scale == 0.0`. Nach Simulation von > 0,12 s Echtzeit über `Feel._advance(real_dt)` → 1.0), `test_feel_overcharge_hitstop_longer`
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5: Visuelle Prüfung:** Szenario `railgun`: Shots bei 50 % und 100 % Ladung, bei 60 % Überladung, im Hitstop-Frame, 0,15 s, 0,5 s und 1,2 s nach dem Schuss. Danach ein voll überladener Schuss mit denselben Shots. Mit Mockup-Screenshots vergleichen. Kriterien:
  - Der Strahl beleuchtet sichtbar Nebel und Wasser.
  - Nur der Hitstop-Frame darf großflächig hell sein. Ab 0,15 s sind Schiffe und Wasser wieder lesbar (Anti-Ziel).
  - Die Überladung ist deutlich größer und heller.
  
  Nachjustieren, bis alles erfüllt ist.
- [ ] **Step 6:** Commit `feat: railgun charge/beam/impact fx and game-feel autoload`

### Task 11: Audio

**Files:** Create `tools/audio/synth.py`, `game/audio/audio_bank.gd` (Autoload `Sfx`), `game/default_bus_layout.tres`. Erzeugt `game/assets/audio/*.wav`. Test `game/tests/test_audio.gd`

**Interfaces:**
- Produces:
  - WAVs, 44,1 kHz, 16 bit, mono, deterministisch per Seed:
    - Railgun: `charge` (1,2 s steigendes Sägezahn-Whine durch Tiefpass, wie Mockup `A.charge`), `overcharge_loop` (1 s, nahtlos), `fire` (Rauschen 7 kHz→110 Hz mit Sub-Sinus 140→26 Hz und Hochpass-Crack, 2 s), `misfire`, `recharge`
    - Treffer und Waffen: `impact`, `explosion`, `flak`, `enemy_gun`, `shell_whistle`, `torpedo`, `splash`
    - Umgebung und UI: `thunder_0..2`, `rain_loop` (4 s, nahtlos), `ui_click`
  - Busse: `Master` (Limiter), `SFX`, `Ambience`
  - `Sfx`: `func play(name: StringName, at: Vector3 = Vector3.INF, volume_db: float = 0.0, pitch: float = 1.0) -> void`. Mit `INF` wird 2D abgespielt, sonst über `AudioStreamPlayer3D` aus einem Pool von 24. Dazu `func loop(name: StringName, on: bool) -> void`.
  - Verdrahtung:
    - `PlayerShip.charge_started` → `charge`, Überladung → `overcharge_loop`
    - `fired` → `fire` (Pitch −10 % bei voller Überladung)
    - `Weather.lightning` → `thunder_*`, verzögert um 0,4–1,0 s
- [ ] **Step 1: Failing test:** `test_all_sounds_present_and_long_enough`: Jede Datei der Liste lädt als `AudioStreamWAV`, `get_length() >= 0.05`, `charge` liegt bei 1,2 ± 0,05 s, die Loops haben `loop_mode == LOOP_FORWARD`.
- [ ] **Step 2–4:** Fehlschlag sehen, `synth.py` schreiben und ausführen (`python3 tools/audio/synth.py game/assets/audio`). Loop-Flags über `.import`-Optionen setzen. PASS sehen.
- [ ] **Step 5:** Commit `feat: synthesized sfx and audio bank`

### Task 12: Gegner, Projektile, Flak

**Files:** Create `game/ships/enemy.gd`, `speedboat.gd`, `frigate.gd`, `submarine.gd`, `shell.gd`, `torpedo.gd`, `flak_turret.gd` (jeweils mit `.tscn`), `game/debug/scenarios/enemies.gd`. Test `game/tests/test_enemies.gd`

**Interfaces:**
- Consumes: `Health`, `ShipMotion`, `ExplosionFx`, `Sfx`, `Ocean`, die Modellverträge, Ziel-Duck-Typing aus `BeamHit`
- Produces:
  - `class_name Enemy extends Node3D` (Basis):
    - Felder `health: Health`, `target: Node3D` (Spieler), `motion: ShipMotion`, `is_small: bool`
    - Signal `died(enemy: Enemy)`
    - Methoden `apply_damage(amount: float, from_dir: Vector3) -> void`, `get_hit_center()`, `get_hit_radius()`, `can_be_hit()`
    - Tod: `ExplosionFx`, dann trennen sich `Bow` und `Stern` (kippen auseinander, 3,5 s Brand mit Rauch) und sinken. Nach 6 s `queue_free`. Rote Akzentlichter gehen aus.
  - `Speedboat`: `is_small = true`, umkreist das Ziel auf 25–40 m mit Seitwärtsversatz, feuert `SPEEDBOAT_GUN_DMG` alle `SPEEDBOAT_GUN_INTERVAL` bei Distanz < `SPEEDBOAT_RANGE` (Leuchtspur-Linien, `enemy_gun`).
  - `Frigate`:
    - hält 80–130 m Abstand und dreht sich breitseits zum Ziel
    - feuert alle `FRIGATE_SALVO_INTERVAL` eine Salve aus `FRIGATE_SALVO` `Shell`s auf die vorausberechnete Zielposition, mit Streuung 6 m
    - Ankündigung: 0,6 s vorher Mündungsglühen an `Gun_*`
  - `Shell` (Node3D): ballistischer Bogen über `SHELL_FLIGHT_TIME` (Scheitel 25 m), Leuchtkugel mit Spur und `shell_whistle`. Ein Bodenmarker (roter Ring auf dem Wasser) zeigt den Einschlagort während des ganzen Flugs. Beim Einschlag gibt es Schaden im Radius 5 m und `splash`.
  - `Submarine`:
    - Zustände SUBMERGED (`can_be_hit` false, nur Kielwelle und Periskop-Schaum, Positionswechsel) und SURFACING (1 s Ankündigung: Blasen, Ring)
    - SURFACED (`SUB_SURFACED_TIME`): feuert nach 1 s einen `Torpedo` auf das Ziel
    - DIVING (1 s)
  - `Torpedo`: fährt geradeaus mit `TORPEDO_SPEED`, zieht eine helle Spur im Wasser, Treffer bei Abstand < 4 m zum Spieler → `TORPEDO_DMG` und Explosion, Lebensdauer 9 s.
  - `FlakTurret` (unter `FlakPivot`): wählt das nächste Ziel mit `is_small` in `FLAK_RANGE` innerhalb von 300° (nicht nach vorn durch den Railgun-Turm), Leuchtspur-Strahlen mit `FLAK_RATE`, `FLAK_DAMAGE` pro Treffer (Hitscan mit 85 % Trefferchance, deterministisch über seed), `flak`-Sound.
- [ ] **Step 1: Failing tests:**
  - `test_submerged_sub_cannot_be_hit` (Zustand SUBMERGED → `can_be_hit() == false`. SURFACED → true)
  - `test_enemy_died_signal_once` (zweimal tödlicher Schaden → Signal einmal)
  - `test_shell_damages_player_in_radius` (Shell mit Flugzeit 0, Spieler 3 m daneben → Schaden 20. 7 m daneben → 0)
  - `test_torpedo_hits_player`
  - `test_flak_ignores_large_targets` (Fregatte in Reichweite → kein Ziel, Schnellboot → Ziel)
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5: Visuelle Prüfung:** Szenario `enemies`: Je ein Gegner wird gespawnt und greift an. Shots von Granatbögen mit Einschlagmarker, Torpedospur, U-Boot beim Auftauchen, Flak-Feuer und einem zerbrechenden Gegner. Erwartet: Alle Angriffe sind vorab lesbar.
- [ ] **Step 6:** Commit `feat: speedboats, frigates, submarines, projectiles, flak`

### Task 13: Gefecht, HUD, Titel, Ende, Pause

**Files:** Create `game/main/battle.tscn/.gd`, `game/main/game_flow.gd` (Autoload `Flow`), `game/ui/theme.tres`, `game/ui/hud.tscn/.gd`, `game/ui/cursor_ring.gd`, `game/ui/title.tscn/.gd`, `game/ui/end_screen.gd`, `game/ui/pause_menu.gd`, `game/assets/fonts/*`, `game/debug/scenarios/battle.gd`. Test `game/tests/test_battle.gd`

**Interfaces:**
- Consumes: alles Vorherige
- Produces:
  - `Battle` (Node3D):
    - Kartenaufbau: Ocean, Weather, 5 Inseln (Positionen fest im Skript, mindestens 60 m Abstand zum Spielerstart in der Mitte), die Inseln werden als `blockers` an Spieler, `BeamHit` und die KI gegeben
    - Gegner-Spawns am Kartenrand in einem Sektor gegenüber dem Spieler
    - Verdrahtung:
      - `PlayerShip.fired` → `BeamHit.cast` mit allen Gegnern und Inseln, Schaden je Treffer verzögert um `distance/600 s`, dann `RailgunFx.play_shot` mit `end_distance`, `Feel.shot`, Treffer → `Feel.impact`
      - `WaveDirector` → Spawns
      - Sieg und Niederlage → `EndScreen`
    - Methode `func outcome() -> StringName`: `&"running"`, `&"victory"` oder `&"defeat"`
  - `Flow`-Autoload: `goto_title()`, `start_battle()`, `quit()`
  - HUD (Theme mit Chakra Petch und JetBrains Mono, keine Default-Optik):
    - `CursorRing` am Mauszeiger: innerer Bogen = Ladung (Cyan), äußerer Bogen = Überladung (Weiß → Cyan), dünner Außenring = Hitze (Orange → Rot, blinkt ab 0,8), Text „GESPERRT“ bei LOCKED
    - Rumpfbalken oben links („RUMPF 300/300“)
    - Wellenanzeige oben Mitte („WELLE 2/3 · 5 FEINDE“)
    - Hinweis „ÜBERHITZT“ bei Fehlzündung
  - Titelbildschirm: Spielname „MODERN SHIPS“, darunter „Railgun“, Hintergrund ist eine laufende Ozeanszene mit Regen. Knöpfe „Gefecht starten“, „Grafik: Hoch/Mittel“ (via `Settings.set_quality` und Neustart über `OS.set_restart_on_exit`) und „Beenden“.
  - Endbildschirm: „SIEG“ bzw. „VERSENKT“, Zeit, Anzahl versenkter Gegner, Knöpfe „Nochmal“ und „Zum Titel“. Das Spielerschiff wird bei Ende auf `input_enabled = false` gesetzt.
  - Pause mit Esc: Overlay „Weiter“ / „Zum Titel“, `get_tree().paused`, die Ladung wird abgebrochen.
- [ ] **Step 1: Failing tests:**
  - `test_victory_after_all_waves` (Battle mit Test-Wellen `[[{type: speedboat, count: 1}]]` instanziieren, Gegner per `apply_damage` töten, ticken → `outcome() == &"victory"`)
  - `test_defeat_when_player_dies`
  - `test_input_disabled_after_end` (Review Focus 3)
  - `test_pause_cancels_charge`
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5: Visuelle Prüfung:** Szenario `battle` (spielt per simulierter Eingabe 40 s: fahren, Schnellboote abschießen, ein überladener Schuss durch eine Reihe). Shots von Titel, HUD beim Laden und in der Überladung, Kampf und Endbildschirm. Danach dasselbe mit `tools/capture.sh battle 1280x720` und `2560x1080` (Review Focus 5). Erwartet: HUD ist verankert und lesbar, nirgends Engine-Default-Optik.
- [ ] **Step 6:** Commit `feat: battle loop, HUD, title, end and pause screens`

### Task 14: Exporte, CI-Export-Job, README

**Files:** Create `game/export_presets.cfg`. Modify `.github/workflows/ci.yml`, `README.md`

**Interfaces:**
- Produces:
  - Presets „Windows ARM64“ (`binary_format/architecture="arm64"`, Ausgabe `build/windows-arm64/ModernShips.exe`, eingebettetes PCK) und „Linux x86_64“ (Ausgabe `build/linux-x86_64/ModernShips.x86_64`)
  - CI-Job `export` (needs: test):
    - lädt `Godot_v4.7.2-stable_export_templates.tpz` von der Release-Seite und entpackt nach `~/.local/share/godot/export_templates/4.7.2.stable/`
    - `godot --headless --path game --export-release "<Preset>" …`
    - lädt beide Ordner als Artefakte `modern-ships-windows-arm64` und `modern-ships-linux-x86_64` hoch
    - bei Tag `v*` zusätzlich `gh release create` mit beiden Zips
  - README: Start auf beiden Systemen (Windows: SmartScreen-Hinweis bei unsigniertem exe. Linux: `chmod +x`), Steuerung, Grafikstufe, Entwicklung (Tests, Capture, Modelle und Sounds neu erzeugen)
- [ ] **Step 1:** Presets anlegen, lokal Export-Templates laden und beide Exporte bauen. Erwartet: Beide Dateien existieren. Das Linux-Binary startet mit `--headless --quit` ohne Fehler.
- [ ] **Step 2:** CI-Export-Job ergänzen, pushen, `gh pr checks` grün. Beide Artefakte sind im Lauf vorhanden.
- [ ] **Step 3:** README schreiben.
- [ ] **Step 4:** Commit `chore: export presets, CI export job, README`. Danach wird die PR als bereit markiert und der Auftraggeber testet auf Windows on ARM und Omarchy.
