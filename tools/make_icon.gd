extends SceneTree
# Builds res://icon.png (512x512 app icon) from Tiny Swords sprites.
# Run: godot --headless --path . --script tools/make_icon.gd

const BASE := "res://assets/tiny_swords/Tiny Swords (Free Pack)/"
const SIZE := 512


func _crop_scaled(path: String, src: Rect2i, scale: int) -> Image:
	var img: Image = load(BASE + path).get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var part := img.get_region(src)
	part.resize(src.size.x * scale, src.size.y * scale, Image.INTERPOLATE_NEAREST)
	return part


func _initialize() -> void:
	var icon := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:  # warm gold-to-red casino gradient
		var c := Color("ffcf4a").lerp(Color("c2362f"), y / float(SIZE))
		for x in SIZE:
			icon.set_pixel(x, y, c)
	var coin := _crop_scaled("UI Elements/UI Elements/Icons/Icon_03.png", Rect2i(0, 0, 64, 64), 2)
	icon.blend_rect(coin, Rect2i(Vector2i.ZERO, coin.get_size()), Vector2i(286, 96))
	var hero := _crop_scaled("Units/Blue Units/Warrior/Warrior_Idle.png", Rect2i(48, 44, 96, 96), 3)
	icon.blend_rect(hero, Rect2i(Vector2i.ZERO, hero.get_size()), Vector2i((SIZE - hero.get_width()) / 2, SIZE - hero.get_height() - 80))
	icon.save_png("res://icon.png")
	print("icon.png written")
	quit()
