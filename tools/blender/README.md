# Modelle

Alle Schiffs- und Inselmodelle werden per Skript erzeugt (keine Fremd-Assets):

```bash
blender -b --factory-startup --python tools/blender/build_models.py -- game/assets/models
```

Konventionen: Bug zeigt nach −Z (Godot), Wasserlinie bei y = 0. Material- und Node-Namen sind ein Vertrag mit dem Spielcode (siehe `game/tests/test_models.gd`).
