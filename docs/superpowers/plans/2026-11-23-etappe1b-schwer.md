# Etappe 1b – „Schwer & mächtig“: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das bestehende Gefecht in ein langsames, taktisches Seegefecht umbauen. Dazu gehören:
- Steuerung mit Telegraf- und Ruderstufen wie in World of Warships
- ein schwerer Schlachtkreuzer
- eine Railgun als Projektil mit Flugzeit und Vorhaltemarke
- wenige, große Gegner auf Distanz
- eine Karte von 1200 m

**Architecture:** Neue reine Logik in `game/core/` (`ShipControl`, `ProjectileSim`, `Aim`, umgebaute `RailgunState`), alles mit GUT getestet. Die Szenen-Schicht (`ships/`, `fx/`, `ui/`, `main/`) wird umgestellt: Projektil statt Strahl, größere Welt mit zweistufigem Ozean, Zoom-Kamera, neue Gegnertypen. Modelle und Sounds bleiben skriptgeneriert.

**Tech Stack:** Godot 4.7.2 (GDScript, Forward+), GUT 9.7.1, Blender 4.0, Python 3 + numpy.

**Spec:** `docs/superpowers/specs/2026-11-23-etappe1b-schwer-design.md` (baut auf `docs/superpowers/specs/2026-11-22-railgun-design.md` auf)

## Global Constraints

- Alle *Global Constraints* aus `docs/superpowers/plans/2026-11-22-etappe1-gefecht.md` gelten weiter: Godot 4.7.2, statisch typisiert, `Tuning` als einzige Quelle für Spielwerte, Koordinaten- und Heading-Konvention, Farben Stil B, deutsche Texte, keine Fremd-Assets.
- **Kein durchgehender Strahl mehr.** Die Railgun verschießt ein Projektil mit Flugzeit.
- Telegraf: 6 Stufen. Index `-1` = Zurück voll, `0` = Stopp, `1..4` = ¼, ½, ¾, Voll. Ruder: 5 Stufen, Index `-2..2` (positiv = Backbord/links, gleicher Sinn wie `rotation.y`).
- Karte 1200 × 1200 m (`MAP_HALF = 600`). Gefechtsdistanz 250–600 m.
- Startwerte in `Tuning` (feintunbar):
  - Schiff: `MAX_SPEED = 12.0`, `MAX_REVERSE = 4.5`, `ACCEL = 0.5`, `BRAKE = 0.8`, `TURN_RATE = 0.08`, `TURN_MIN_FACTOR = 0.1`, `RUDDER_SHIFT_TIME = 3.0`, `TRAVERSE_RATE = 0.45`
  - Railgun: `RELOAD_TIME = 7.0`, `CLICK_GRACE = 0.25`, `OVERCHARGE_TIME = 2.0`, `PROJECTILE_SPEED = 600.0`, `PROJECTILE_RANGE = 900.0`, `PIERCE_FACTOR = 0.6`, `BASE_DAMAGE = 250.0`
  - Rumpf: `PLAYER_HULL = 1500.0`

## Review Focus

1. **W/S/A/D gehalten oder mehrfach gedrückt:** Die Tastenwiederholung des Betriebssystems darf nicht mehrere Stufen auf einmal springen, und an den Enden wird geklemmt. Test in Task 1 (Klemmen) und Task 6 (Echo-Events ignorieren).
2. **Ziel stirbt oder wird freigegeben, während das Projektil fliegt:** kein Absturz und kein Doppeltreffer. Test in Task 3.
3. **Maximaler Zoom am Kartenrand oder über Inseln:** Der Ozean hat keine Löcher bis zum Bildrand. Capture in Task 4 und Task 11.
4. **Maustaste während des Nachladens gedrückt halten:** Nach dem Laden beginnt sofort die Überladung. Ein kurzer Klick während des Nachladens wird ignoriert. Test in Task 2.
5. **Vorhaltemarke ohne Lösung** (Ziel schneller als das Projektil und flieht, oder Ziel steht): kein NaN, Marke versteckt bzw. auf dem Ziel. Test in Task 3.

---

## Dateistruktur (neu / geändert)

```
game/core/  ship_control.gd (neu)  projectile_sim.gd (neu)  aim.gd (neu)
            railgun_state.gd (umgebaut)  ship_motion.gd (+step_to)  tuning.gd  wave_director.gd (neue Wellen)
game/world/ ocean.gd / ocean.gdshader (Nah- + Fernfläche, Schneise mit Fortschritt)  storm_environment.gd (Nebelweiten)
game/ships/ player_ship.gd (Telegraf/Ruder, Kreuzer-Modell)  railgun_round.gd (neu)  destroyer.gd (neu)  cruiser.gd (neu)
            frigate.gd / submarine.gd / speedboat.gd / shell.gd / torpedo.gd (Distanzen, Bögen)
game/fx/    railgun_fx.gd (Mündung + Nachladen statt Strahl)  beam.gdshader (entfällt)
game/ui/    hud.gd (+Telegraf/Ruder/Fahrt)  cursor_ring.gd (Nachladering)  edge_markers.gd (+Vorhalteraute)
game/camera/follow_camera.gd (Zoomstufen)
game/main/  battle.gd (Karte 1200 m, Inseln, Projektil-Abwicklung)
tools/blender/build_models.py (+battlecruiser, enemy_destroyer, cruiser)
tools/audio/synth.py (tieferer Schuss, Nachladen, Telegraf)
```

---

### Task 1: ShipControl + ShipMotion.step_to

**Files:** Create `game/core/ship_control.gd`. Modify `game/core/ship_motion.gd` and `game/core/tuning.gd` (Schiffswerte siehe Global Constraints, neu `RUDDER_SHIFT_TIME`). Test `game/tests/test_ship_control.gd`. Bestehende `test_ship_motion.gd`-Erwartungen an die neuen Werte anpassen, die Logik von `step()` bleibt unverändert (Gegner nutzen sie).

**Interfaces:**
- Produces:
  - `class_name ShipControl extends RefCounted`
    - Felder: `telegraph: int` (−1..4), `rudder_setting: int` (−2..2), `rudder: float` (aktueller Ruderwinkel −1..1, läuft nach)
    - `throttle_up() -> void`, `throttle_down() -> void`, `rudder_left() -> void`, `rudder_right() -> void`, alle geklemmt
    - `target_speed(max_speed: float, max_reverse: float) -> float`: Stufe −1 = `-max_reverse`, 0 = 0, k = `max_speed * k / 4`
    - `tick(dt: float) -> void`: bewegt `rudder` mit `1/RUDDER_SHIFT_TIME` pro Sekunde auf `rudder_setting / 2.0`
    - `telegraph_label() -> String`: „ZURÜCK VOLL“, „STOPP“, „¼“, „½“, „¾“, „VOLL“
  - `ShipMotion.step_to(target_speed: float, rudder: float, dt: float) -> void`: Die Geschwindigkeit nähert sich `target_speed` mit `ACCEL` (schneller werden) bzw. `BRAKE` (langsamer werden), Drehung wie in `step()`.

- [ ] **Step 1: Failing tests:**
  - `test_throttle_steps_and_clamps` (5× `throttle_up` → 4, 7× `throttle_down` → −1)
  - `test_target_speed_per_step` (Stufe 2 → 6.0, Stufe −1 → −4.5)
  - `test_rudder_shifts_slowly` (`rudder_left` 2×, `tick(1.5)` → `rudder ≈ 0.5`, `tick(1.5)` → 1.0)
  - `test_rudder_clamps`
  - `test_step_to_reaches_quarter_speed_slowly` (Stufe 1, nach 2 s `speed ≈ 1.0`, nach 60 s `speed ≈ 3.0`)
  - `test_full_speed_turn_circle` (Voll und hart Backbord eingeschwungen, eine Runde dauert `2π/0.08 ≈ 78 s`, Kreisdurchmesser 300 ± 30 m, gemessen über die Ausdehnung der Positionen)
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen (`tools/run_tests.sh`).
- [ ] **Step 5:** Commit `feat: telegraph and rudder steps, heavy ship motion`

### Task 2: RailgunState umbauen (Nachladen, Klick/Halten, Überladung)

**Files:** Modify `game/core/railgun_state.gd` und `game/core/tuning.gd` (Railgun-Werte siehe Global Constraints; `CHARGE_TIME` und `COOLDOWN` entfallen). Ersetze `game/tests/test_railgun_state.gd`.

**Interfaces:**
- Produces: `RailgunState` mit `enum State { LOADING, READY, HOLDING, LOCKED }`
  - Felder: `state`, `reload: float` (0..1, Ladefortschritt), `overcharge: float` (0..1), `heat: float`
  - Methoden `press()`, `release() -> RailgunShot`, `cancel()`, `tick(dt) -> bool` (Fehlzündung)
  - Start in LOADING mit `reload = 0`. Nach `RELOAD_TIME` folgt READY.
  - `press()` in READY → HOLDING.
  - `release()` in HOLDING feuert immer: `overcharge = clamp((hold - CLICK_GRACE) / OVERCHARGE_TIME, 0, 1)`, `damage = BASE_DAMAGE * (1 + overcharge)`. Danach LOADING mit `reload = 0`.
  - Die Hitze steigt nur beim Halten über `CLICK_GRACE` hinaus (bestehende Hitze-Konstanten). Fehlzündung bei Hitze ≥ 1 in HOLDING.
  - `cancel()` in HOLDING → READY (es bleibt geladen).
  - `RailgunShot` bekommt das Feld `pierce: int` (= 2 + `round(overcharge * 2)`, so viele Ziele durchschlägt das Geschoss).

- [ ] **Step 1: Failing tests:**
  - `test_starts_loading_then_ready` (tick 6.9 → LOADING, tick 0.2 → READY)
  - `test_click_fires_base_shot` (READY, press, tick 0.1, release → `damage == 250`, `overcharge == 0`, LOADING)
  - `test_hold_overcharges` (press, tick 0.25 + 2.0 → release `damage ≈ 500`, `pierce == 4`)
  - `test_press_while_loading_ignored` (Review Focus 4: LOADING, press, release → `null`, LOADING bleibt)
  - `test_hold_through_reload_starts_holding` (Review Focus 4: Das Halten nimmt `PlayerShip._poll_fire` aus Task 6 auf. Hier wird nur `press()` direkt nach READY geprüft → HOLDING.)
  - `test_overheat_misfire_locks`
  - `test_cancel_keeps_round_loaded`
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5:** Commit `feat: railgun reload, click-or-hold overcharge`

### Task 3: ProjectileSim + Aim

**Files:** Create `game/core/projectile_sim.gd`, `game/core/aim.gd`. Test `game/tests/test_projectile.gd`.

**Interfaces:**
- Consumes: `BeamHit.cast` (Ziel-Duck-Typing, Blocker)
- Produces:
  - `class_name ProjectileSim extends RefCounted`
    - `_init(origin: Vector2, dir: Vector2, speed: float, max_range: float, damage: float, pierce: int)`
    - Felder `position: Vector2`, `travelled: float`, `damage: float`, `done: bool`, `stop_point: Vector2`
    - `advance(dt: float, targets: Array, blockers: Array, half_width: float) -> Array`:
      - liefert die neuen Treffer dieses Frames: `{target, damage, point: Vector2}`
      - prüft das Segment `[position, position + dir*speed*dt]` mit `BeamHit.cast`
      - ignoriert schon getroffene Ziele (per Instanz-ID) und Ziele, die nicht mehr gültig sind
      - Schaden pro weiterem Ziel `× PIERCE_FACTOR`
      - `done`, sobald `pierce` Ziele getroffen sind, ein Blocker im Weg ist oder `max_range` erreicht ist
  - `class_name Aim extends RefCounted`
    - `static func intercept(shooter: Vector2, target: Vector2, target_vel: Vector2, speed: float) -> Variant`: `Vector2` oder `null`, wenn es keine Lösung gibt (quadratische Gleichung, kleinste positive Zeit)

- [ ] **Step 1: Failing tests:**
  - `test_projectile_needs_flight_time` (Ziel bei 300 m, `advance(0.25)` → keine Treffer, weiteres `advance(0.3)` → Treffer)
  - `test_pierces_two_and_loses_damage` (3 Ziele in Linie, pierce 2 → genau 2 Treffer mit 250 und 150, dann `done`)
  - `test_stops_at_island` (Blocker vor dem Ziel → kein Treffer, `done`, `stop_point` am Inselrand)
  - `test_no_double_hit_across_frames`
  - `test_freed_target_ignored` (Review Focus 2: Ziel per `free()` freigegeben bzw. `can_be_hit() == false` → kein Fehler, kein Treffer)
  - `test_range_limit`
  - Aim:
    - `test_intercept_static_target_is_target`
    - `test_intercept_crossing_target` (Ziel bei (0, −300) fährt mit (10, 0), speed 600 → Punkt x ≈ 5.0)
    - `test_intercept_impossible_returns_null` (Review Focus 5: Ziel flieht mit 700 m/s → `null`)
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5:** Commit `feat: projectile simulation with pierce and intercept aim`

### Task 4: Große Welt: Ozean in zwei Stufen, Nebel, Zoom-Kamera

**Files:** Modify `game/world/ocean.gd`, `game/world/ocean.gdshader`, `game/world/storm_environment.gd`, `game/camera/follow_camera.gd`, `game/core/tuning.gd` (`MAP_HALF = 600`). Tests `game/tests/test_ocean.gd` und `game/tests/test_review_fixes.gd` (Kamera-Rahmen) anpassen und ergänzen.

**Interfaces:**
- Produces:
  - `Ocean`:
    - **Nahfläche:** 520 m, 300 Unterteilungen, mit Effekten
    - **Fernfläche:** 2400 m, 160 Unterteilungen, gleicher Shader mit `uniform float cut_inner`. Sie verwirft Fragmente innerhalb von 255 m um ihr Zentrum, und ihre Effekt-Schleifen sind abgeschaltet (`uniform bool far_lod`).
    - Beide folgen `follow`.
  - Schneise mit Fortschritt: `add_trench(from: Vector3, to: Vector3, width: float, speed: float)`. Der Shader zeigt nur den Teil, der seit dem Schuss schon durchlaufen ist: `t_along * len <= age * speed`. `OceanEffects.add_trench` bekommt `speed`, gespeichert in `trench_meta` als `Vector3(age, width, speed)`.
  - `FollowCamera`:
    - `const ZOOM_LEVELS: Array[float] = [140.0, 210.0, 300.0, 420.0]`, `zoom_index: int = 1`, `zoom_in()`, `zoom_out()`, Mausrad im `_unhandled_input`
    - Entfernung weich nachgeführt (`lerp` mit 2.5/s), Fokus träge (1.8/s)
  - Nebel: `fog_density 0.0022`, volumetrischer Nebel `length 520`, Dichte 0.006
- [ ] **Step 1: Failing tests:**
  - `test_zoom_clamps` (5× `zoom_out` → Index 3)
  - `test_camera_frames_engagement_ranges` auf Zoomstufe 2: 300 m voraus und 200 m seitlich im Frustum
  - `test_trench_meta_has_speed`
  - `test_far_ocean_follows`
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5: Visuelle Prüfung** (Review Focus 3): Neues Szenario `zoom` (Sandbox mit FollowCamera auf einem Dummy-Ziel, Shots auf allen 4 Zoomstufen, eins davon bei (580, 580)). Erwartet: Wasser bis zum Bildrand, keine sichtbare Naht und kein schwarzer Rand.
- [ ] **Step 6:** Commit `feat: 1.2 km sea with two-level ocean and zoom camera`

### Task 5: Modelle: Schlachtkreuzer, gegnerischer Zerstörer, Kreuzer

**Files:** Modify `tools/blender/build_models.py`, `game/tests/test_models.gd`. Erzeugt `game/assets/models/{battlecruiser,enemy_destroyer,cruiser}.glb`.

**Interfaces:**
- Produces:
  - `battlecruiser.glb` (L 40 m, B 7 m): gleicher Vertrag wie `destroyer.glb` (`TurretPivot/Railgun/Muzzle`, `FlakPivot`, `Bridge`), Materialien inkl. `PlayerAccent`. Der Railgun-Turm ist groß (Schienenlänge ~12 m) und sitzt auf dem Vorschiff bei z ≈ −11 m.
  - `enemy_destroyer.glb` (L 22 m): `Bow`/`Stern`, Empties `Gun_0`, `Gun_1`, `Torp_L`, `Torp_R`
  - `cruiser.glb` (L 34 m): `Bow`/`Stern`, Empties `Gun_0..Gun_3`
  - Alle Gegner tragen `EnemyAccent`-Streifen.
- [ ] **Step 1: Failing tests:** `test_battlecruiser_contract` (Länge 40 ± 6 inkl. Überhang), `test_enemy_destroyer_contract`, `test_cruiser_contract`
- [ ] **Step 2–4:** Fehlschlag sehen, Skript erweitern und ausführen, PASS sehen.
- [ ] **Step 5: Visuelle Prüfung:** Szenario `model_lineup` um die neuen Modelle erweitern. Erwartet: klar massiver als der alte Zerstörer, gleiche Formensprache.
- [ ] **Step 6:** Commit `feat: battlecruiser, enemy destroyer and cruiser models`

### Task 6: Spielerschiff: Telegraf/Ruder, Kreuzer, neue Railgun-Logik

**Files:** Modify `game/ships/player_ship.gd`, `game/main/input_setup.gd`, `game/tests/test_player_ship.gd`, `game/tests/test_review_fixes.gd`.

**Interfaces:**
- Consumes: `ShipControl`, `ShipMotion.step_to`, `RailgunState` (neu), `battlecruiser.glb`
- Produces:
  - `PlayerShip.control: ShipControl`. Die Aktionen `move_forward`/`move_back`/`rudder_left`/`rudder_right` lösen bei `is_action_pressed` ohne Echo (`event.is_echo() == false`) einen Stufenwechsel aus. `throttle_input`/`rudder_input` entfallen.
  - Für Tests und Szenarien: `use_device_input = false` plus direkter Zugriff auf `control`.
  - `HULL_RADIUS = 3.6`, `HALF_LENGTH = 20.0`. Das Wellenreiten nutzt Abtastpunkte bei ±18 m und ±3.5 m.
  - `fired(shot, origin, dir)` bleibt. `charge_started` heißt jetzt „Halten beginnt“.
  - `_poll_fire` bleibt: Halten in READY → `press()`, nicht mehr gehalten in HOLDING → Release.
- [ ] **Step 1: Failing tests:**
  - `test_w_steps_telegraph_once_per_press` (Review Focus 1: Ein gedrücktes Event erhöht um 1, ein Echo-Event nicht)
  - `test_ship_reaches_half_speed_slowly` (Telegraf 2, 10 s → `speed < 6`, 40 s → `speed ≈ 6.0`)
  - `test_click_fires_after_reload` (tick 7.1, Klick → `fired` mit `damage 250`)
  - `test_hold_during_reload_then_overcharge` (Review Focus 4: Fire halten ab t = 5, bei 7.0 READY → HOLDING, Loslassen bei 9.5 → `overcharge ≈ 1`)
  - `test_beam_goes_through_the_cursor` auf das neue Modell anpassen
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5:** Commit `feat: battlecruiser with telegraph, rudder steps and reload railgun`

### Task 7: Railgun-Projektil im Spiel: Mündung, Geschoss, Druckwelle, Einschlag

**Files:** Create `game/ships/railgun_round.gd`. Modify `game/fx/railgun_fx.gd` (Strahl entfernen; Mündung, Nachlade- und Halte-Visuals), `game/main/battle.gd` (`_on_fired` erzeugt `RailgunRound`), `game/fx/explosion_fx.gd` (Durchschuss-Austritt). Delete `game/fx/beam.gdshader`. Test `game/tests/test_battle.gd` anpassen und ergänzen.

**Interfaces:**
- Consumes: `ProjectileSim`, `Ocean.add_trench(..., speed)`, `ExplosionFx`, `Feel`
- Produces:
  - `class_name RailgunRound extends Node3D`: `setup(origin: Vector3, dir: Vector3, shot: RailgunShot, targets_provider: Callable, blockers: Array) -> void`. `targets_provider` liefert die aktuellen treffbaren Gegner.
  - Geschoss: weiß-heiß mit Cyan-Saum, `OmniLight3D`, Plasma-Schweif aus GPU-Partikeln
  - Pro Treffer: `apply_damage`, `ExplosionFx.play` und ein Austritts-Spray in Flugrichtung, `Feel.impact`
  - Bei `done`: Einschlag bzw. Wasserfontäne am `stop_point`
  - `RailgunFx.play_muzzle(origin: Vector3, dir: Vector3, overcharge: float)`:
    - orange-weißer Plasma-Feuerball (Rampe `#ffffff` → `#ffb46b` → Rauch)
    - Funkenregen, cyanfarbene Bögen, zwei Luft-Druckringe, Rauchsäule
    - `ocean.add_trench(origin, end, width, PROJECTILE_SPEED)`
    - `Feel.shot(overcharge)`
  - Nachlade-Visual: Das `Energy`-Band füllt sich mit `reload`. Halte-Visual wie die bisherige Überladung (Bögen, Einsaug-Funken).
- [ ] **Step 1: Failing tests:**
  - `test_round_hits_after_flight_time` (Battle mit Fregatte 300 m voraus, Schuss → nach 0.2 s noch nicht getroffen, nach 0.6 s getroffen)
  - `test_round_pierces_two_in_line`
  - `test_round_stopped_by_island`
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5: Visuelle Prüfung:** Szenario `railgun` umbauen:
  - Shots: geladen, Halten 50 % und 100 %, Mündung im Hitstop, Geschoss in der Mitte des Flugs, Einschlag, 1 s danach
  - Kriterien: Es sieht wie ein Geschoss aus, nicht wie ein Strahl. Der Feuerball ist der hellste Moment. Ab 0,15 s ist das Bild wieder lesbar.
- [ ] **Step 6:** Commit `feat: railgun projectile with plasma muzzle, sonic trench and piercing impacts`

### Task 8: Gegner auf Distanz: Fregatte, Zerstörer, Kreuzer, U-Boot, Schnellboot

**Files:** Create `game/ships/destroyer.gd`, `game/ships/cruiser.gd`. Modify `enemy.gd` (`Enemy.create` um `&"destroyer"`/`&"cruiser"`), `frigate.gd`, `submarine.gd`, `speedboat.gd`, `shell.gd`, `torpedo.gd`, `game/core/tuning.gd`, `game/core/wave_director.gd` (`DEFAULT_WAVES` laut Spec 3.4). Tests `game/tests/test_enemies.gd`, `game/tests/test_wave_director.gd` anpassen und ergänzen.

**Interfaces:**
- Produces:
  - Tuning (Startwerte):
    - Fregatte: `FRIGATE_HP 400`, `FRIGATE_STANDOFF 300..450`, `FRIGATE_RANGE 600`, Salve 3 alle 7 s, `SHELL_DMG 60`
    - Zerstörer: `DESTROYER_HP 450`, Geschwindigkeit 15, Geschütze Salve 2 alle 6 s, Torpedofächer 3 alle 18 s auf ≤ 400 m
    - Kreuzer: `CRUISER_HP 900`, Geschwindigkeit 8, Salve 6 alle 9 s, `CRUISER_SHELL_DMG 90`, Reichweite 700
    - U-Boot: `SUB_HP 250`, Angriffsdistanz 250, Torpedo-Reichweite 450, `TORPEDO_SPEED 25`, `TORPEDO_DMG 180`
    - Schnellboot: `SPEEDBOAT_HP 80`, Reichweite 120
  - `Shell`: Flugzeit = Distanz / 120 m/s (mindestens 2 s), Scheitelhöhe = 0.25 × Distanz, Marker-Radius 8 m
  - `Destroyer.launch_fan(count: int, spread_deg: float)` (testbar)
- [ ] **Step 1: Failing tests:**
  - `test_cruiser_survives_three_base_hits_dies_on_fourth`
  - `test_destroyer_fan_spawns_three_torpedoes`
  - `test_shell_flight_time_scales_with_distance` (400 m → `≈ 3.33 s`)
  - `test_default_waves_composition` (Welle 3 enthält 1 `cruiser`, 2 `destroyer`, 1 `submarine`, 2 `speedboat`)
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5:** Commit `feat: long-range enemies, destroyer and cruiser, new waves`

### Task 9: HUD: Telegraf, Ruder, Fahrt, Nachladering, Vorhalteraute

**Files:** Modify `game/ui/hud.gd`, `game/ui/cursor_ring.gd`, `game/ui/edge_markers.gd`. Test `game/tests/test_hud.gd` (neu).

**Interfaces:**
- Consumes: `ShipControl`, `RailgunState` (neu), `Aim.intercept`
- Produces:
  - Unten Mitte: Telegraf-Leiste mit 6 Feldern (eingestellte Stufe hervorgehoben, Ist-Fahrt als Marker), Ruderleiste mit 5 Feldern (eingestellte Stufe und laufender Ist-Winkel), Fahrt in Knoten (`speed * 1.944`, Anzeige „12 KN“)
  - Zielring: Nachladebogen (Grau, füllt sich), bei READY Cyan, Halten = Überladung wie bisher, Hitze außen
  - Vorhalteraute: für jeden sichtbaren, treffbaren Gegner eine kleine rote Raute an `Aim.intercept(...)` (Mündungsposition, Projektilgeschwindigkeit), mit einer dünnen Linie zum Gegner. Bei `null` keine Raute.
  - `static func knots(mps: float) -> int`
- [ ] **Step 1: Failing tests:** `test_knots_conversion` (6.0 → 12), `test_hud_builds_with_battle` (Battle instanziieren, HUD hat Telegraf- und Ruder-Controls, kein Fehler)
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5:** Commit `feat: telegraph/rudder HUD, reload ring and lead markers`

### Task 10: Klang: schwerer Schuss, Nachladen, Telegraf

**Files:** Modify `tools/audio/synth.py`, `game/audio/audio_bank.gd` (`NAMES`), `game/tests/test_audio.gd`. Neue Sounds: `reload_done`, `telegraph`, `projectile_whoosh`. `fire` bekommt mehr Sub-Bass und einen längeren Nachhall (3 s).
- [ ] **Step 1: Failing test:** `test_new_sounds_present` (die 3 neuen Dateien; `fire` ist ≥ 2.8 s lang)
- [ ] **Step 2–4:** Fehlschlag sehen, Synthese und Verdrahtung umsetzen (Telegraf-Klick bei jedem Stufenwechsel, `reload_done` bei LOADING → READY), PASS sehen.
- [ ] **Step 5:** Commit `feat: heavier railgun audio, reload and telegraph sounds`

### Task 11: Gefecht zusammenführen, Captures, README

**Files:** Modify `game/main/battle.gd` (12 Inseln über die 1200-m-Karte verteilt mit Radius 18–45 m, Spawns 450–600 m vom Spieler entfernt), `game/debug/scenarios/battle.gd` (Bot nutzt Telegraf und Ruder und zielt mit `Aim`), `README.md` (Steuerung).
- [ ] **Step 1: Failing test:** `test_islands_inside_map_and_clear_of_start` (alle Inseln innerhalb `MAP_HALF − 50`, ≥ 120 m vom Start)
- [ ] **Step 2–4:** Fehlschlag sehen, implementieren, PASS sehen.
- [ ] **Step 5: Visuelle Prüfung:** `tools/capture.sh battle 1280x720 res://main/battle.tscn` und `2560x1080`. Kriterien:
  - Das Gefecht wirkt langsam und mächtig.
  - Gegner sind auf Distanz sichtbar oder per Marker zu finden.
  - Das HUD ist lesbar.
  - Das Projektil ist klar ein Geschoss.
- [ ] **Step 6:** README-Steuerungstabelle aktualisieren (W/S Telegraf, A/D Ruder, Mausrad Zoom, Klick/Halten), Commit `feat: stage 1b battle, captures, README`
