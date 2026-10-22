extends RefCounted
## Shared constants: tiles, elements, palettes.

const TILE := 32
const CW := 40
const CH := 20

# Tile codes (ASCII)
const T_EMPTY := 46   # .
const T_SOLID := 35   # #
const T_ONEWAY := 61  # =
const T_WOOD := 66    # B  burnt by fire
const T_FLAME := 70   # F  doused by water
const T_GRATE := 71   # G  dissolved by poison
const T_CRACK := 67   # C  broken by earth
const T_SEAL := 88    # X  opens with 3 seals
const T_LOCK := 68    # D  temporary boss lock
const T_WATER := 126  # ~
const T_LAVA := 76    # L
const T_TOXIC := 84   # T
const T_SPIKE := 94   # ^

const ELEMS := ["fire", "water", "poison", "air", "earth"]
const ELEM_NAMES := {
	"fire": "Огонь", "water": "Вода", "poison": "Яд", "air": "Ветер", "earth": "Земля", "none": "—",
}
const ELEM_COLORS := {
	"fire": Color(1.0, 0.47, 0.16),
	"water": Color(0.25, 0.65, 1.0),
	"poison": Color(0.58, 0.9, 0.28),
	"air": Color(0.82, 0.94, 1.0),
	"earth": Color(0.82, 0.6, 0.34),
	"none": Color(0.82, 0.82, 0.86),
}
const ELEM_DESC := {
	"fire": "Сжигает дерево и паутину. Лава не страшна.",
	"water": "Гасит пламя. Позволяет плавать.",
	"poison": "Разъедает решётки. Отрава не страшна.",
	"air": "Двойной прыжок. Сильная отдача.",
	"earth": "Крушит треснувший камень. Шипы не страшны.",
}
# attacker element -> element it beats
const BEATS := {"water": "fire", "fire": "poison", "poison": "earth", "earth": "air", "air": "water"}

const GATE_ELEM := {66: "fire", 70: "water", 71: "poison", 67: "earth"}
const GATE_HINT := {
	66: "Это сожжёт только огонь",
	70: "Пламя погасит только вода",
	71: "Решётку разъест только яд",
	67: "Треснувший камень разобьёт только земля",
	88: "Печать. Нужны три печати стражей",
}

const BIOME := {
	"castle": {
		"bg_top": Color(0.11, 0.12, 0.21), "bg_bot": Color(0.06, 0.07, 0.13),
		"wall": Color(0.23, 0.26, 0.38), "edge": Color(0.42, 0.47, 0.64), "dark": Color(0.15, 0.17, 0.26),
		"plat": Color(0.55, 0.44, 0.3), "far": Color(0.14, 0.16, 0.27), "accent": Color(1.0, 0.82, 0.45),
	},
	"cave": {
		"bg_top": Color(0.05, 0.12, 0.12), "bg_bot": Color(0.03, 0.06, 0.07),
		"wall": Color(0.17, 0.28, 0.27), "edge": Color(0.32, 0.5, 0.45), "dark": Color(0.1, 0.17, 0.17),
		"plat": Color(0.43, 0.39, 0.29), "far": Color(0.08, 0.17, 0.17), "accent": Color(0.4, 0.95, 0.85),
	},
	"hell": {
		"bg_top": Color(0.17, 0.04, 0.05), "bg_bot": Color(0.07, 0.02, 0.03),
		"wall": Color(0.29, 0.12, 0.12), "edge": Color(0.6, 0.24, 0.17), "dark": Color(0.18, 0.07, 0.07),
		"plat": Color(0.47, 0.29, 0.22), "far": Color(0.22, 0.06, 0.06), "accent": Color(1.0, 0.45, 0.15),
	},
}


static func mult(atk: String, def: String) -> float:
	if def == "none" or def == "":
		return 1.0
	if BEATS.get(atk, "") == def:
		return 2.0
	if atk == def:
		return 0.25
	return 1.0


static func is_solid(code: int) -> bool:
	return code == T_SOLID or code == T_WOOD or code == T_FLAME or code == T_GRATE \
		or code == T_CRACK or code == T_SEAL or code == T_LOCK


static func is_liquid(code: int) -> bool:
	return code == T_WATER or code == T_LAVA or code == T_TOXIC
