# SwordSlots (Sootingslot)

Mobile-portrait lane battler + 3x3 slot-machine roguelite, made with Godot 4.7.2 (GDScript).

- **Prepare** (camp): spend gold to spin the 3x3 grid. Paylines summon heroes, powers buff the
  squad, curses hurt. Pick a symbol after each spin, drag heroes onto twins to level up,
  buy Items in the shop, pick Cores at run start and after bosses.
- **Fight**: steer and dodge on the path; kills drop gold for the next prepare phase.
- A run is 3 acts x 5 waves, with a boss closing each act. Judgement waves are optional and harder, and pay more gold.

## Run
Open the folder in Godot 4.7.2 and press Play (main scene `main.tscn`).

## Code map
- `scripts/run.gd` - the whole game: state, combat, camp, UI drawing (tuning constants at the top)
- `scripts/symbols.gd` - reel symbols, curses, grid roll and payline resolve
- `scripts/items.gd` - Items (shop) and Cores
- `scripts/art.gd` - sprite paths (Tiny Swords); `scripts/sfx.gd` - sounds, music, volume settings
- `tools/` - `pack_ui.gd` (packs UI 9-slice art), `make_icon.gd` (builds `icon.png`)

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
