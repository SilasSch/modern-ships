# Etappe 1b – „Schwer & mächtig“ (Überarbeitung von Etappe 1)

Stand: 2026-11-23 · Status: freigegeben (Auftraggeber: „ja und ja“)
Baut auf: `2026-11-22-railgun-design.md`. Was dort steht und hier nicht geändert wird, gilt weiter.

## 1. Warum

Der Auftraggeber hat Etappe 1 gespielt: **„Zu schnell, zu arcadig.“** Er wollte ein langsameres, mächtigeres Schiff. Die Waffe fühlte sich an wie eine **schnelle Lasergun**, nicht wie eine Railgun. Die Referenz für Tempo und Steuerung ist **World of Warships**, die Kamera bleibt aber **2.5D von schräg oben**.

**Erfolg:** Jedes Manöver fühlt sich nach Masse an, jeder Schuss ist ein Ereignis, und ein Gefecht ist taktisch statt hektisch.

## 2. Ziele / Nicht-Ziele / Anti-Ziele

**Ziele**
- Steuerung wie in World of Warships: Telegraf- und Ruderstufen, die stehen bleiben, und träges Ansprechen.
- Die Railgun als echtes Geschoss: langes Nachladen, sichtbares Projektil mit Flugzeit, Vorhalten nötig, Wucht wie bei den echten Navy-Tests.
- Wenige, große Gegner, die auf Distanz kämpfen. Ausweichen über Telegraf und Ruder ist die Kernfertigkeit.

**Nicht-Ziele (weiterhin):** Feldzug, Werft, Upgrades, Begleiter, mehrere Wetterlagen. Dazu kommt neu: keine Kamera hinter dem Schiff wie in World of Warships.

**Anti-Ziele** (zusätzlich zu Etappe 1)
- Ein Strahl, der wie ein Laser aussieht oder sofort trifft.
- Hektik: Dauerfeuer, Schwärme kleiner Gegner, Schiffe, die auf der Stelle drehen.
- Gegner, die man nicht sieht und nicht findet. Dagegen helfen Randmarker und Zoom.

## 3. Entschieden

### 3.1 Steuerung (Auftraggeber: W/S wie World of Warships, A/D-Stufen als Vorschlag akzeptiert)
- **W / S:** Maschinentelegraf in **6 Stufen**: Zurück voll · Stopp · ¼ · ½ · ¾ · Voll. Ein Tastendruck verstellt um eine Stufe, die Einstellung bleibt stehen. Die Rückwärts-Höchstfahrt beträgt etwa ein Viertel der Vorwärtsfahrt plus einen kleinen Rest (wie in World of Warships).
- **A / D:** Ruder in **5 Stufen**: Hart Backbord · Halb Backbord · Mitte · Halb Steuerbord · Hart Steuerbord. Ein Tastendruck verstellt um eine Stufe, die Einstellung bleibt stehen. Das Ruderblatt läuft **langsam** auf die eingestellte Stufe, von Mitte bis Hart in etwa 3 s.
- **Trägheit:** Bis zur Höchstfahrt vergehen etwa 20–30 s. Die Wendekreise sind groß, etwa 250–350 m Durchmesser bei voller Fahrt. Im Stand dreht das Schiff kaum.
- **HUD:** Telegraf- und Ruderanzeige unten in der Mitte (eingestellte Stufe und tatsächlicher Wert), dazu die Fahrt in Knoten.

### 3.2 Kamera (Auftraggeber: A, 2.5D bleibt)
- Schräg von oben, deutlich weiter heraus als in Etappe 1. **Zoom mit dem Mausrad** in Stufen, von einer Nahansicht bis zur Übersicht. Die Kamera folgt weich und mit spürbarer Verzögerung.
- Randmarker mit Entfernung für Gegner außerhalb des Bildes bleiben.

### 3.3 Railgun (Auftraggeber: ja)
- **Nachladen ~7 s.** Ist die Railgun geladen, feuert **ein Klick sofort**. **Halten = Überladung** (bis ~2 s): mehr Schaden, mehr Durchschlag, größere Effekte. Die Hitze steigt, und die Fehlzündung bleibt wie gehabt. Das HUD zeigt die Nachladezeit am Zielring.
- **Projektil statt Strahl:** ein weiß glühendes Geschoss mit Leuchtspur und Plasma-Schweif. Es fliegt stilisiert mit **~600 m/s** (Flugzeit 0,5–1,5 s auf Gefechtsdistanz), Reichweite ~900 m.
- **Treffer:** Die Prüfung läuft entlang der Flugbahn, Bild für Bild. Das Geschoss **durchschlägt** Ziele, verliert dabei Schaden und fliegt weiter. Inseln stoppen es.
- **Vorhaltemarkierung (Auftraggeber: ja):** Eine dezente Raute an jedem sichtbaren Gegner zeigt, wohin man zielen muss, damit Geschoss und Ziel sich treffen.
- **Optik und Wucht** (Vorbild: echte Navy-Tests):
  - Plasma-Feuerball an der Mündung (orange-weiß, Funkenregen, cyanfarbene Lichtbögen als Energie-Akzent).
  - Überschall-Druckwelle, die unter der Flugbahn das Wasser aufreißt.
  - Rückstoß, Hitstop, Shake.
  - Einschlag: Splitter, Fontäne, Durchschuss-Austritt auf der anderen Seite, das Schiff bricht.
- Kein durchgehender Strahl mehr.

### 3.4 Schiffe und Gegner
- **Spielerschiff:** ein größerer, massiverer **Schlachtkreuzer** (ca. 40 m im Spielmaßstab). Moderner Stealth-Stil wie bisher, mit großem Railgun-Turm. Die Flak bleibt automatisch.
- **Gegner:** wenige, große, auf Distanz (~250–600 m). Sie feuern langsame Salven mit klar sichtbaren Granatbögen und Einschlagmarkern, denen man über Telegraf und Ruder ausweichen kann.
  - Fregatte: Artillerie.
  - **Zerstörer (neu):** schneller, Torpedofächer und Geschütze.
  - **Kreuzer (neu):** große Salven, braucht mehrere Treffer.
  - U-Boot: bleibt.
  - Schnellboote: nur vereinzelt.
- **Wellen** (Startwerte):
  1. 2 Fregatten
  2. 2 Fregatten, 1 Zerstörer, 1 U-Boot
  3. 1 Kreuzer, 2 Zerstörer, 1 U-Boot, 2 Schnellboote
- **Karte:** ~1200 × 1200 m mit mehr und größeren Inseln als Deckung.

### 3.5 Bleibt
Stil B (Sturmnacht), Ozean-Shader, die Arbeitsweise mit Modellen und Sound per Skript, Feel-System, HUD-Sprache, Tests, CI und die Exporte für Windows ARM64 und Linux.

## 4. Dem Builder überlassen
- alle Zahlenwerte (die genannten sind Startwerte)
- Zoomstufen
- Ozean-Abdeckung und Detailstufen für die größere Sicht
- die konkrete Kreuzer- und Zerstörer-Modellierung
- die Audio-Anpassung (tiefer und schwerer)
- die Aufteilung in Aufgaben
