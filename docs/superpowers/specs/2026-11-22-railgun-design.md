# Modern Ships – Design (Gesamtbild + Etappe 1)

Arbeitstitel des Spiels: **Railgun**. Repo: `modern-ships`.

Stand: 2026-11-22 · Status: Entwurf zur Freigabe

## 1. Absicht und Warum

Ein 2.5D-Seegefecht-Spiel, das **sehr schick** aussieht, einen **einfachen, klaren Vibe** hat und **vielfältig** ist. Im Zentrum steht eine **Railgun auf einem Kriegsschiff**, deren Schuss sich mächtig anfühlt und visuell überwältigend aussieht.

Das wichtigste Warum des Auftraggebers: **Es darf kein „0815-AI-Slop-Game“ werden.** Jede Entscheidung wird daran gemessen, ob sie das Spiel eigenständig, handwerklich sauber und spürbar gemacht wirken lässt.

## 2. Gesamtbild (alle Etappen)

- **Genre:** Roguelite-Feldzug auf See. Eine Karte mit Seegebieten, der Spieler wählt seine Route. Stationen sind Kampf, Werft (Upgrades), Ereignis und Elite-Kampf, am Ende wartet ein Boss-Schlachtschiff. Ein Lauf dauert ca. 20–30 Minuten mit 8–12 Stationen. Stirbt das Schiff, ist der Lauf vorbei.
- **Steuerung (Hybrid):** Das eigene Flaggschiff wird direkt gesteuert (WASD fahren, Maus zielen). 2–4 Begleitschiffe bekommen einfache Befehle („greif an“, „folge mir“, „halt Position“).
- **Bewaffnung:** Die Railgun ist die Hauptwaffe und immer an Bord, dazu kommen 2 Plätze für Nebenwaffen (Flak, Torpedos, Wasserbomben, Störsender, Minen).
- **Upgrades:**
  - Railgun: Kettenblitz, Doppelschuss/Fächer, Überladung, Ladezeit, Brand/Unterwasserschockwelle
  - Nebenwaffen
  - Schiff: Panzerung, Antrieb, Reparaturdrohne, Begleiter-Plätze
- **Look:** Stil **B „Sturmnacht · Neon“**: dunkle See, Regen, Blitze. Cyan steht für Energie und den Spieler, Rot für Gegner. Der Railgun-Strahl ist die hellste Lichtquelle im Bild. Andere Wetterlagen (Nebel, Tag, ruhige See) kommen später als Varianten auf der Karte dazu, der Grundlook bleibt B.
- **Etappen:**
  1. **Ein Gefecht.** Wird in diesem Dokument im Detail beschrieben und zuerst gebaut.
  2. Feldzug: Karte, Werft/Upgrades, Ereignisse, Begleiter mit Befehlen, Boss.
  3. Vielfalt: weitere Gegner und Wetter, alle Nebenwaffen, Feinschliff.

  Nach jeder Etappe testet der Auftraggeber, erst danach geht es weiter.

## 3. Ziele, Nicht-Ziele, Anti-Ziele (Etappe 1)

**Ziele**
- Ein einzelnes, komplett spielbares Gefecht, an dem sich zeigt, ob Fahren und Schießen Spaß machen.
- Der Railgun-Schuss ist der Höhepunkt und muss mindestens die Wirkung des Mockups erreichen (siehe Referenzen), im echten Renderer gern mehr.
- Läuft nativ auf **Windows on ARM (Snapdragon-Laptop)** und **Omarchy Linux**.

**Nicht-Ziele (Etappe 1)**
- Feldzugskarte, Werft, Upgrades, Ereignisse, Boss
- Begleitschiffe und Befehle
- mehrere Wetterlagen, Tag/Nacht-Wechsel
- Speicherstände, Optionsmenü über die Grafikstufe hinaus, Controller-Support
- Web-Export, Mobile

**Anti-Ziele** (wenn eines davon eintritt, ist die Etappe gescheitert, auch wenn technisch alles funktioniert)
- Schiffe oder Inseln aus sichtbaren Grundkörpern (Quader, Zylinder) und generische Platzhalter-Optik
- schwammige, schwerelose Steuerung, Schüsse ohne Gewicht
- Effekte, die das Spielgeschehen unlesbar machen. Ein voll ausgebleichter Bildschirm darf höchstens im Hitstop-Moment des Schusses stehen bleiben (ca. 80 ms).
- bunt zusammengewürfelte Stock-Assets mit uneinheitlichem Stil
- Standard-UI, die nach Engine-Default aussieht

## 4. Rahmenbedingungen

- **Zielgeräte:** Windows 11 on ARM (Snapdragon X, Adreno-GPU) und Omarchy Linux (Arch-basiert, Hyprland/Wayland) auf einem **eigenen AMD-PC (x86_64, Vulkan/RADV)**. Die Performance auf Snapdragon kann während der Entwicklung nicht getestet werden. Das Testen übernimmt der Auftraggeber.
- **Repository:** öffentliches GitHub-Repo `SilasSch/modern-ships`. Es ist öffentlich, damit GitHub Actions kostenlos genutzt werden kann. Es gibt keine Lizenzdatei, alle Rechte bleiben beim Auftraggeber (dem ist die Lizenz egal, das ist der sichere Standard).
- **Entwicklungsumgebung:** Die Entwicklung läuft in einem Cloud-Container ohne GPU und ohne Bildschirm. Screenshots entstehen mit Software-Rendering. Was dort nicht zu prüfen ist (Framerate, D3D12 auf ARM), testet der Auftraggeber auf seinen Geräten.

## 5. Ansätze

| | Ansatz | Abwägung |
|---|---|---|
| A | Three.js, reines JS, ohne Build-Schritt, Browser | am schnellsten gebaut, wird aber bei wachsendem Umfang unübersichtlich, und ohne starkes Art Direction ist die Slop-Gefahr hoch |
| B | Three.js + TypeScript + Vite, Browser | sauber skalierbar, aber Licht (volumetrischer Nebel, Schatten) müsste aufwendig selbst gebaut werden |
| **C** | **Godot 4, Desktop, Forward+-Renderer** | **gewählt.** Volumetrischer Nebel, den der Strahl ausleuchtet, GPU-Partikel, echte Schatten und Glow sind schon da. Der Auftraggeber kann im Editor selbst mitarbeiten. Dafür entfallen der Browser und das schnelle Iterieren. |

Der Auftraggeber hat C gewählt, Ziel ist „nicht 0815“. Die Festlegung auf **nur Desktop mit vollem Renderer** kommt vom Entwickler, auf Wunsch des Auftraggebers („musst du entscheiden“). Der Grund: Im Browser liefe Godot nur mit dem abgespeckten Compatibility-Renderer, und der Lichtvorteil wäre weg.

## 6. Entschiedene Teile

### 6.1 Technik
- **Engine:** Godot 4, aktuelle Stable-Version zum Projektstart. Die Version wird exakt festgehalten (Projekt und CI).
- **Sprache:** GDScript mit durchgehender statischer Typisierung.
- **Renderer:** Forward+. Treiber unter Windows: Direct3D 12 (Godot-Standard seit 4.6), unter Linux Vulkan.
- **Grafikstufen:** „Hoch“ (Forward+, volumetrischer Nebel, volle Partikel) und „Mittel“ (Mobile-Renderer, ohne volumetrischen Nebel, weniger Partikel), als Rückfallebene für Snapdragon. Ein Wechsel des Renderers braucht einen Neustart, das ist in Ordnung.
- **Exporte:** Windows ARM64 (nativ), Linux x86_64. Linux ARM64 wird nicht gebraucht.
- **Modelle:** Blender, per Python-Skript erzeugt und als glTF ins Projekt übernommen. Die Skripte liegen im Repo, damit Modelle reproduzierbar und änderbar bleiben. Der Stil ist Low-Poly mit klaren Silhouetten, Fasen und genug Details (Aufbauten, Masten, Radar, Geländer-Andeutung), damit kein Quader-Look entsteht.
- **CI:** GitHub Actions. Pro Push laufen die Logik-Tests, Exporte werden als Build-Artefakte bereitgestellt (Windows ARM64, Linux). Getaggte Versionen landen als Release.
- **Tests:** Die Spiellogik ist getestet: Lade- und Überladungs-Zustandsmaschine, Treffer auf der Linie inklusive Durchschlag, Schaden und Tod, Wellenablauf, Sieg und Niederlage. Visuelles und Spielgefühl prüft der Auftraggeber.

### 6.2 Spieler-Schiff und Steuerung
- **Fahren:** W gibt Gas vorwärts, S bremst bzw. fährt rückwärts (langsamer), A/D legen das Ruder. Das Schiff hat Trägheit und Schwung, die Wendigkeit hängt von der Geschwindigkeit ab (im Stand dreht es kaum). Es soll sich wie ein Schiff anfühlen, nicht wie ein Auto.
- **Zielen:** Der Railgun-Turm folgt der Maus mit begrenzter Schwenkgeschwindigkeit. Diese Trägheit ist gewollt und Teil des Gewichts. **Schwenkbereich ca. ±150°** (Entscheidung des Auftraggebers): Der Turm sitzt auf dem Vorschiff, und nur nach hinten verdecken die Aufbauten die Schusslinie. Ziele im toten Winkel am Heck erreicht man, indem man das Schiff dreht. Die Flak deckt den Bereich achtern mit ab.
- **Railgun:** Linke Maustaste halten lädt (ca. 1,2 s auf 100 %), loslassen feuert. Wer vor 100 % loslässt, bricht ab und es passiert nichts (Entscheidung des Entwicklers, siehe 7).
- **Überladung:** Hält man über 100 % hinaus, steigt die Stärke bis maximal ca. +100 % (breiterer Strahl, mehr Schaden, größere Effekte). Gleichzeitig steigt die Hitze. Bei Überhitzung entlädt sich die Waffe unkontrolliert: Das eigene Schiff nimmt Schaden und die Railgun ist einige Sekunden gesperrt. Die Hitze ist im HUD klar sichtbar.
- **Treffer:** Der Schuss geht gerade durch und trifft **alle** Ziele auf der Linie bis zur Maximalreichweite. Er kommt praktisch sofort an (Hitscan), mit minimaler Verzögerung pro Entfernung für das Gefühl.
- **Nebenwaffe (Etappe 1): Flak.** Ein automatischer Geschützturm, der kleine, schnelle Ziele in kurzer Reichweite bekämpft (vor allem Schnellboote). Er braucht keine eigene Taste. So bleibt die Aufmerksamkeit auf Fahren und Railgun.

### 6.3 Gegner (Etappe 1)
1. **Schnellboot:** schnell, kommt im Schwarm (3–5), umkreist das Schiff und beschießt es mit leichten Waffen. Wenig Leben. Typisches Ziel der Flak, aber auch lohnend für einen Durchschlag-Schuss durch eine Reihe.
2. **Fregatte:** mittelgroß, feuert Breitseiten mit **sichtbaren Granatbögen**, denen man ausweichen kann. Braucht zwei normale Railgun-Treffer oder einen überladenen.
3. **U-Boot:** taucht ab (dann unverwundbar, nur an der Kielwelle erkennbar) und auf, um Torpedos abzufeuern (Spuren im Wasser, ausweichbar). Treffbar ist es nur aufgetaucht, die Railgun ist also eine Timing-Frage.

Alle gegnerischen Angriffe sind **angekündigt und lesbar** (Mündungsblitz, Bögen, Torpedospuren). Gegner sind rot akzentuiert, der Spieler cyan.

### 6.4 Ablauf des Gefechts
- Kleine Seekarte mit Inseln als Deckung und Hindernis, Kollision mit Inseln.
- **3 Wellen** mit steigender Schwierigkeit, gemischt aus den drei Gegnertypen. Die letzte Welle bringt eine Kombination aus allen dreien.
- **Sieg:** Alle Wellen sind besiegt. **Niederlage:** Das Schiff sinkt. In beiden Fällen gibt es einen kurzen Abschlussbildschirm mit „Nochmal“.
- Start über einen schlichten Titelbildschirm im Stil des Spiels (Titel, Start, Grafikstufe, Beenden).

### 6.5 Look (Stil B), verbindlich
- **Referenz:** `docs/reference/railgun-stilproben.html` (Stil B) und die Screenshots in `docs/reference/`. Spielbar unter https://claude.ai/artifact/QjnYD4xRRMzmam8qTrniTJ (privat, gehört dem Auftraggeber).
- **Wasser:** eigener Ozean-Shader mit Wellen, Schaum auf Kämmen, Fresnel-Effekt und Mondspiegelung. Dazu Effekte, die der Schuss ins Wasser schreibt: die Schneise unter dem Strahl, eine Ringwelle von der Mündung, Ringwellen beim Einschlag, Ladekreise ums Schiff und Kielwellen.
- **Atmosphäre:** Regen, Blitze mit verzögertem Donner, volumetrischer Nebel. Der Strahl beleuchtet Nebel und Wasser.
- **Schiffe: modern** (Wunsch des Auftraggebers). Kein Weltkriegs-Look, sondern heutige und nahe-zukünftige Marine:
  - Stealth-Formen: schräge, facettierte Flächen, eingezogener Rumpf (Tumblehome), integrierter Mast mit flachen Radar-Paneelen.
  - Senkrechtstarter-Felder (VLS) im Deck, Hubschrauberdeck am Heck, wenig Kleinkram an Deck.
  - Spieler-Schiff: ein großer Stealth-Zerstörer. Die Railgun ist ein langer, flacher Turm mit offenen Schienen.
  - Gegner: moderne Schnellboote (Katamaran/Gleiter), Stealth-Fregatten, moderne Jagd-U-Boote.

  Die Schiffe sind nur von echten Klassen inspiriert, keine Nachbauten. Die Rümpfe sind dunkel, warme Fenster- und Positionslichter setzen Akzente, die Energieteile der Railgun leuchten cyan. Die facettierte Stealth-Form passt gut zum Low-Poly-Stil.

### 6.6 Der Railgun-Schuss (Herzstück), verbindlich
Die Abfolge entspricht dem Mockup und darf darüber hinausgehen:
1. **Laden:** Schienen und Energieband glühen immer stärker, Lichtbögen springen zwischen den Schienen, Funken werden in die Mündung gesogen, um das Schiff bilden sich Ringwellen im Wasser. Die Kamera fährt leicht heran, eine Vignette zieht sich zu, der Ladeton steigt an.
2. **Feuer:** Hitstop von ca. 80 ms, Weißblitz, Rückstoß an Rohr und Schiff, Kamera-Kick, Screenshake und ein kurzer FOV-Ruck. Aus der Mündung kommen ein Plasma-Feuerball, eine Druckwelle in der Luft (Ringe) und Rauch.
3. **Strahl:** weißer Kern mit cyanfarbener Hülle und Spirale aus Partikeln. Er leuchtet Nebel und Wasser aus, reißt eine Gischt-Schneise und Dampf entlang der Bahn auf und schickt eine Ringwelle über die Oberfläche.
4. **Einschlag:** Explosion, Wasserfontäne, Trümmer, Funken, Rauch. Das Schiff bricht und sinkt, ein Brand folgt.
5. **Nachglühen:** Ionisierter Kanal und Rohr glühen nach, die Kondensatoren laden nach (auch hörbar).

Die Überladung verstärkt alle Stufen sichtbar. Effekte dürfen das Spielgeschehen höchstens im Hitstop überdecken (siehe Anti-Ziele).

### 6.7 Audio
Sound ist Pflicht für das Gefühl: Laden, Schuss (Knall, Sub-Wumms, Crack), Einschlag, Flak, gegnerische Waffen, Regen und Donner, UI. Quelle sind CC0-Sounds (Lizenzen werden im Repo dokumentiert) und/oder selbst synthetisierte Sounds.

### 6.8 Kamera und HUD
- 2.5D-Perspektive schräg von oben (ca. 30–50° Neigung), die dem Schiff folgt. Sie schaut leicht in Zielrichtung voraus und liegt weich in der Bewegung.
- Das HUD ist reduziert und eigenständig gestaltet: Lade- und Hitzeanzeige am Mauszeiger (Ring), Rumpfzustand, Wellenanzeige. Schrift und Formensprache passen zu Stil B, kein Engine-Default.

## 7. Entscheidungen des Entwicklers (zum Gegenlesen)
- Desktop-only mit Forward+, Grafikstufe „Mittel“ als Rückfallebene
- GDScript statt C#
- Ladung unter 100 % loslassen = Abbruch, kein schwacher Schuss
- Flak automatisch und ohne Taste
- 3 Wellen, Gegner-Mix wie in 6.3
- Modelle per Blender-Skript statt gekaufter Assets
- Leistungsziel: 60 fps bei 1080p auf „Hoch“, 30 fps als Untergrenze. Beim ersten Start ist „Hoch“ eingestellt, „Mittel“ lässt sich im Titelbildschirm wählen. Die Budgets für Nebel, Partikel und Wasser werden so gewählt, dass „Mittel“ auch auf schwacher Grafik sicher läuft.
- UI-Sprache: Deutsch

## 8. Dem Builder überlassen
- alle Zahlenwerte (Geschwindigkeiten, Schaden, Leben, Reichweiten, Zeiten). Die genannten Werte sind Startpunkte zum Feintuning
- Code-Architektur, Szenenaufbau, Shader-Umsetzung im Detail
- Größe und Layout der Karte, Platzierung der Inseln
- konkrete Sound-Auswahl innerhalb der CC0-Vorgabe
- Aufbau der CI im Detail
