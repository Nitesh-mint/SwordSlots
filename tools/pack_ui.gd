extends SceneTree
# Packs Tiny Swords UI sheets (9-slice pieces laid out with gaps) into gap-free textures in
# assets/ui/ so StyleBoxTexture / NinePatchRect can stretch them. Prints slice margins.
# Run: godot --headless --path . --script tools/pack_ui.gd

const SRC := "res://assets/tiny_swords/Tiny Swords (Free Pack)/UI Elements/UI Elements/"
const OUT := "res://assets/ui/"
const SHEETS := {
	wood = "Wood Table/WoodTable.png", paper = "Papers/RegularPaper.png", paper_special = "Papers/SpecialPaper.png",
	banner = "Banners/Banner.png", btn_blue = "Buttons/BigBlueButton_Regular.png",
	btn_blue_pressed = "Buttons/BigBlueButton_Pressed.png", btn_red = "Buttons/BigRedButton_Regular.png",
	btn_red_pressed = "Buttons/BigRedButton_Pressed.png", bar = "Bars/BigBar_Base.png",
}
const RIBBONS := ["ribbon_blue", "ribbon_red", "ribbon_yellow", "ribbon_purple", "ribbon_black"]


# [start, length] runs of non-transparent columns (axis 0) or rows (axis 1) inside rect.
func runs(img: Image, rect: Rect2i, axis: int) -> Array:
	var out := []
	var start := -1
	var n := rect.size.x if axis == 0 else rect.size.y
	var m := rect.size.y if axis == 0 else rect.size.x
	for i in n + 1:
		var hit := false
		if i < n:
			for j in m:
				var p := Vector2i(rect.position.x + i, rect.position.y + j) if axis == 0 else Vector2i(rect.position.x + j, rect.position.y + i)
				if img.get_pixelv(p).a > 0:
					hit = true
					break
		if hit and start < 0:
			start = i
		elif not hit and start >= 0:
			out.append([start, i - start])
			start = -1
	return out


func pack(img: Image, rect: Rect2i, name: String) -> void:
	var cols := runs(img, rect, 0)
	var rows := runs(img, rect, 1)
	var w := 0
	var h := 0
	for c in cols: w += c[1]
	for r in rows: h += r[1]
	var dst := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var y := 0
	for r in rows:
		var x := 0
		for c in cols:
			dst.blit_rect(img, Rect2i(rect.position.x + c[0], rect.position.y + r[0], c[1], r[1]), Vector2i(x, y))
			x += c[1]
		y += r[1]
	dst.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("%s %dx%d margins L%d T%d R%d B%d" % [name, w, h, cols[0][1], rows[0][1], cols[-1][1], rows[-1][1]])


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for k in SHEETS:
		var img := Image.load_from_file(SRC + SHEETS[k])
		pack(img, Rect2i(Vector2i.ZERO, img.get_size()), k)
	var rib := Image.load_from_file(SRC + "Ribbons/BigRibbons.png")
	var rows := runs(rib, Rect2i(Vector2i.ZERO, rib.get_size()), 1)
	for i in mini(rows.size(), RIBBONS.size()):
		pack(rib, Rect2i(0, rows[i][0], rib.get_width(), rows[i][1]), RIBBONS[i])
	quit()
