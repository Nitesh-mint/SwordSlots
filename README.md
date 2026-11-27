# SwordSlots (Sootingslot)

Mobile-portrait lane battler + 3x3 slot-machine roguelite, made with Godot 4.7.2 (GDScript).

- **Prepare** (camp): pull the lever (gold per spin) to spin the 3x3 grid. The reels hold hero
  categories (Warriors, Rangers, Mages, Support), not heroes: three of a category in any line
  (rows, columns, diagonals) summons a random unlocked hero of that category, rarer heroes less
  often. Powers buff the squad. FATE shows three trials (grades C/B/A, e.g. "win 3 waves in a
  row, max 2 spins"); finishing one earns a FATE SPIN (free, extra, always a hero line, much rarer heroes; A grade
  also +1 level). Max 6 spins per prepare phase. Every hero has a signature skill (cast on a
  cooldown). Drag any hero onto another to ABSORB it (XP: rarer heroes need more; Lv5 = awakened,
  skill x1.5) and take its imprint (Frenzy, Build Up, Last Stand, Guard, Regen, Focus; 2 slots,
  3 once promoted), or SWAP places. Tap a hero for its skill and imprints.
  Hero levels go to 33 (Lv6 pick a class, Lv14 Class II, Lv24 Class III, Lv33 awakened).
- **Stages**: Greenvale, then Crimson Hell and Doom Spire unlock by winning the one before
  (tougher enemies, more crystals). Rare / epic / legendary heroes unlock by best wave reached. Jesters are wild for hero categories. Faction
  synergies: 2 / 4 heroes of one category in the squad give that category's bonus. Nudge / Hold / Peek
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
