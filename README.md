# SwordSlots (Sootingslot)

Mobile-portrait lane battler + 3x3 slot-machine roguelite, made with Godot 4.7.2 (GDScript).

- **Prepare** (camp): pull the lever (gold per spin) to spin the 3x3 grid. Three of the same hero
  in any line (rows, columns, diagonals) summons it; powers buff the squad. Nudge / Hold / Peek
  help finish lines. Pick a symbol after each spin, drag heroes onto twins to level up (Lv3+
  promotes to a class), place heroes in the FRONT or BACK row, buy Items, pick Cores.
- **Fight**: auto-battle. Your squad and an enemy squad about its size march into formation and fight
  until one side falls; placement decides the outcome. Each act ends with a unique boss. Kills pay gold.
- A run is 3 acts x 5 waves, with a boss closing each act. Judgement waves are optional and harder, and pay more gold.

## Run
Open the folder in Godot 4.7.2 and press Play (main scene `main.tscn`).

## Code map
- `scripts/run.gd` - the whole game: state, combat, camp, UI drawing (tuning constants at the top)
- `scripts/symbols.gd` - reel symbols, hero classes, grid roll and line resolve
- `scripts/items.gd` - Items (shop) and Cores
- `scripts/meta.gd` - crystals and the permanent upgrade tree (saved to `user://meta.cfg`)
- `scripts/art.gd` - sprite paths (Tiny Swords); `scripts/sfx.gd` - sounds, music, volume settings
- `tools/` - `pack_ui.gd` (packs UI 9-slice art), `make_icon.gd` (builds `icon.png`), `make_sfx.gd` (synth bells)

## Tests
```
godot --headless --path . --script scripts/symbols_check.gd
```

## Android
Needs Android export templates for 4.7.2. Preset "Android" exports to `build/sootingslot.apk`:
```
godot --headless --path . --export-debug Android build/sootingslot.apk
adb install -r build/sootingslot.apk
```

See `CREDITS.md` for asset licenses.
