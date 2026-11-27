# Sprite paths for "Tiny Swords (Free Pack)" by Pixel Frog (assets/tiny_swords).
# Sprite sheets are horizontal strips of square frames (frame size = image height).
const BASE := "res://assets/tiny_swords/Tiny Swords (Free Pack)/"

const UNITS := {
	swordsman = "Units/Blue Units/Warrior/Warrior_Run.png",
	archer = "Units/Blue Units/Archer/Archer_Run.png",
	spearman = "Units/Blue Units/Lancer/Lancer_Run.png",
	healer = "Units/Blue Units/Monk/Run.png",
	mage = "Units/Purple Units/Monk/Run.png",
	bomber = "Units/Yellow Units/Pawn/Pawn_Run Hammer.png",
	knight = "Units/Black Units/Warrior/Warrior_Run.png",
	assassin = "Units/Purple Units/Archer/Archer_Run.png",
	champion = "Units/Yellow Units/Lancer/Lancer_Run.png",
	shieldmaiden = "Units/Yellow Units/Warrior/Warrior_Run.png",
	frostmage = "Units/Black Units/Monk/Run.png",
	hunter = "Units/Black Units/Archer/Archer_Run.png",
	bard = "Units/Yellow Units/Monk/Run.png",
	skylancer = "Units/Black Units/Lancer/Lancer_Run.png",
}
const ENEMIES := {
	grunt = "Units/Red Units/Pawn/Pawn_Run Hammer.png",
	runner = "Units/Red Units/Pawn/Pawn_Run Knife.png",
	shooter = "Units/Red Units/Archer/Archer_Run.png",
	brute = "Units/Red Units/Warrior/Warrior_Run.png",
	shaman = "Units/Red Units/Monk/Run.png",
	mortar = "Units/Red Units/Pawn/Pawn_Run Pickaxe.png",
	warlord = "Units/Red Units/Lancer/Lancer_Run.png",
	witch = "Units/Red Units/Monk/Run.png",
	bloodknight = "Units/Red Units/Warrior/Warrior_Run.png",
}
# Standing around in the camp (prepare phase).
const UNIT_IDLE := {
	swordsman = "Units/Blue Units/Warrior/Warrior_Idle.png",
	archer = "Units/Blue Units/Archer/Archer_Idle.png",
	spearman = "Units/Blue Units/Lancer/Lancer_Idle.png",
	healer = "Units/Blue Units/Monk/Idle.png",
	mage = "Units/Purple Units/Monk/Idle.png",
	bomber = "Units/Yellow Units/Pawn/Pawn_Idle Hammer.png",
	knight = "Units/Black Units/Warrior/Warrior_Idle.png",
	assassin = "Units/Purple Units/Archer/Archer_Idle.png",
	champion = "Units/Yellow Units/Lancer/Lancer_Idle.png",
	shieldmaiden = "Units/Yellow Units/Warrior/Warrior_Idle.png",
	frostmage = "Units/Black Units/Monk/Idle.png",
	hunter = "Units/Black Units/Archer/Archer_Idle.png",
	bard = "Units/Yellow Units/Monk/Idle.png",
	skylancer = "Units/Black Units/Lancer/Lancer_Idle.png",
}
# Camp (prepare phase) buildings: [path, center, scale]
const CAMP_BUILDINGS := [
	["Buildings/Blue Buildings/Castle.png", Vector2(360, 190), 0.7],
	["Buildings/Blue Buildings/Barracks.png", Vector2(75, 355), 0.5],
	["Buildings/Blue Buildings/Archery.png", Vector2(645, 355), 0.5],
	["Buildings/Blue Buildings/Monastery.png", Vector2(90, 640), 0.4],
	["Buildings/Blue Buildings/House1.png", Vector2(640, 650), 0.5],
]
# Played once when the unit attacks / casts / shoots.
const UNIT_ATTACK := {
	swordsman = "Units/Blue Units/Warrior/Warrior_Attack1.png",
	archer = "Units/Blue Units/Archer/Archer_Shoot.png",
	spearman = "Units/Blue Units/Lancer/Lancer_Up_Attack.png",
	healer = "Units/Blue Units/Monk/Heal.png",
	mage = "Units/Purple Units/Monk/Heal.png",
	bomber = "Units/Yellow Units/Pawn/Pawn_Interact Hammer.png",
	knight = "Units/Black Units/Warrior/Warrior_Attack1.png",
	assassin = "Units/Purple Units/Archer/Archer_Shoot.png",
	champion = "Units/Yellow Units/Lancer/Lancer_Up_Attack.png",
	shieldmaiden = "Units/Yellow Units/Warrior/Warrior_Attack1.png",
	frostmage = "Units/Black Units/Monk/Heal.png",
	hunter = "Units/Black Units/Archer/Archer_Shoot.png",
	bard = "Units/Yellow Units/Monk/Heal.png",
	skylancer = "Units/Black Units/Lancer/Lancer_Up_Attack.png",
}
const ENEMY_ATTACK := {
	grunt = "Units/Red Units/Pawn/Pawn_Interact Hammer.png",
	runner = "Units/Red Units/Pawn/Pawn_Interact Knife.png",
	shooter = "Units/Red Units/Archer/Archer_Shoot.png",
	brute = "Units/Red Units/Warrior/Warrior_Attack1.png",
	shaman = "Units/Red Units/Monk/Heal.png",
	mortar = "Units/Red Units/Pawn/Pawn_Interact Pickaxe.png",
	warlord = "Units/Red Units/Lancer/Lancer_Down_Attack.png",
	witch = "Units/Red Units/Monk/Heal.png",
	bloodknight = "Units/Red Units/Warrior/Warrior_Attack2.png",
}
const GRASS :="Terrain/Tileset/Tilemap_color1.png"   # 64px tiles; middle row y=64: left edge, fill, right edge
const WATER := "Terrain/Tileset/Water Background color.png"
const TREES := ["Terrain/Resources/Wood/Trees/Tree1.png", "Terrain/Resources/Wood/Trees/Tree2.png",
	"Terrain/Resources/Wood/Trees/Tree3.png", "Terrain/Resources/Wood/Trees/Tree4.png"]
const BUSHES := ["Terrain/Decorations/Bushes/Bushe1.png", "Terrain/Decorations/Bushes/Bushe2.png",
	"Terrain/Decorations/Bushes/Bushe3.png", "Terrain/Decorations/Bushes/Bushe4.png"]
const WATER_ROCKS := ["Terrain/Decorations/Rocks in the Water/Water Rocks_01.png",
	"Terrain/Decorations/Rocks in the Water/Water Rocks_02.png",
	"Terrain/Decorations/Rocks in the Water/Water Rocks_03.png",
	"Terrain/Decorations/Rocks in the Water/Water Rocks_04.png"]
const ROCKS := ["Terrain/Decorations/Rocks/Rock1.png", "Terrain/Decorations/Rocks/Rock2.png",
	"Terrain/Decorations/Rocks/Rock3.png", "Terrain/Decorations/Rocks/Rock4.png"]
const GOLD_STONES := ["Terrain/Resources/Gold/Gold Stones/Gold Stone 1.png", "Terrain/Resources/Gold/Gold Stones/Gold Stone 3.png",
	"Terrain/Resources/Gold/Gold Stones/Gold Stone 5.png"]
const HOUSES := ["Buildings/Yellow Buildings/House1.png", "Buildings/Yellow Buildings/House2.png",
	"Buildings/Yellow Buildings/House3.png", "Buildings/Yellow Buildings/Tower.png"]
const RED_BUILDINGS := ["Buildings/Red Buildings/House1.png", "Buildings/Red Buildings/House2.png",
	"Buildings/Red Buildings/Tower.png", "Buildings/Red Buildings/Barracks.png", "Buildings/Red Buildings/Archery.png"]
const FIRES := ["Particle FX/Fire_01.png", "Particle FX/Fire_02.png", "Particle FX/Fire_03.png"]
const CLOUDS := ["Terrain/Decorations/Clouds/Clouds_01.png", "Terrain/Decorations/Clouds/Clouds_03.png",
	"Terrain/Decorations/Clouds/Clouds_05.png"]
const ARROW := "Units/Blue Units/Archer/Arrow.png"
const ENEMY_ARROW := "Units/Red Units/Archer/Arrow.png"
const EXPLOSION := "Particle FX/Explosion_01.png"
const GOLD := "Terrain/Resources/Gold/Gold Resource/Gold_Resource.png"
const CHEST := "Terrain/Resources/Gold/Gold Stones/Gold Stone 4.png"

const LAMB := "Terrain/Resources/Meat/Sheep/Sheep_Idle.png"

# UI: packed 9-slice textures from tools/pack_ui.gd, margins [left, top, right, bottom] in source px.
const UI_DIR := "res://assets/ui/"
const NINE := {
	wood = [84, 85, 84, 103], paper = [52, 44, 52, 45], paper_special = [55, 44, 55, 43],
	banner = [100, 68, 84, 111], btn_blue = [45, 47, 45, 47], btn_blue_pressed = [50, 36, 50, 49],
	btn_red = [45, 47, 45, 47], btn_red_pressed = [50, 36, 50, 49], bar = [24, 0, 24, 0],
	ribbon_blue = [98, 0, 97, 0], ribbon_red = [98, 0, 97, 0], ribbon_yellow = [98, 0, 97, 0],
	ribbon_purple = [98, 0, 97, 0], ribbon_black = [98, 0, 97, 0],
}
const RARITY_RIBBON := {common = "ribbon_black", rare = "ribbon_blue", epic = "ribbon_purple", legendary = "ribbon_yellow"}
const SLOT := "UI Elements/UI Elements/Wood Table/WoodTable_Slots.png"
const BAR_FILL := "UI Elements/UI Elements/Bars/BigBar_Fill.png"
const ICON_COIN := "UI Elements/UI Elements/Icons/Icon_03.png"
const ICON_GEAR := "UI Elements/UI Elements/Icons/Icon_10.png"
const ICON_SWORD :="UI Elements/UI Elements/Icons/Icon_05.png"
const POWER_ICONS := {
	might = "UI Elements/UI Elements/Icons/Icon_05.png",
	haste = "UI Elements/UI Elements/Icons/Icon_07.png",
	vigor = "UI Elements/UI Elements/Icons/Icon_04.png",
	magnet = "UI Elements/UI Elements/Icons/Icon_03.png",
	skull = "UI Elements/UI Elements/Icons/Icon_09.png",
}

# Reel art for hero categories (see Symbols.DATA type "category").
const CATEGORY_ICONS := {
	warrior = "Buildings/Blue Buildings/Barracks.png",
	ranger = "Buildings/Blue Buildings/Archery.png",
	mystic = "Buildings/Purple Buildings/Tower.png",
	support = "Buildings/Yellow Buildings/Monastery.png",
}

# Sheets whose frames are not square (default frame width = image height).
const FRAME_W := {
	"Terrain/Resources/Wood/Trees/Tree1.png": 192,
	"Terrain/Resources/Wood/Trees/Tree2.png": 192,
}

static var _cache := {}


static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(BASE + path)
	return _cache[path]


static func ui(name: String) -> Texture2D:
	var key := "ui:" + name
	if not _cache.has(key):
		_cache[key] = load(UI_DIR + name + ".png")
	return _cache[key]


static func frame_w(path: String) -> float:
	return FRAME_W.get(path, tex(path).get_height())


static func frames(path: String) -> int:
	return maxi(1, int(tex(path).get_width() / frame_w(path)))
