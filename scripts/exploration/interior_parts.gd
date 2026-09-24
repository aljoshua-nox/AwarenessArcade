extends RefCounted

## The parts the office floors and the desk are built from: LimeZu's Modern
## Interiors (free version), by name. Rects are on the pack's 16x16 sheets, and
## the committed sheets under assets/art/maps/modern_interiors/ are those
## sheets with everything but these parts cut away (the free pack is
## non-commercial and the repo is public - see CREDITS.md). Adding a part is a
## row here, then `godot --path . res://tools/cut_modern_interiors.tscn`.
##
## Data only, so the cutting tool can read it without loading a room.

const INTERIORS_SHEET := "res://assets/art/maps/modern_interiors/interiors.png"
const ROOM_BUILDER_SHEET := "res://assets/art/maps/modern_interiors/room_builder.png"

# The rooms draw everything at 2x, like the old office props.
const SCALE := 2.0

# Interiors_free_16x16.png
const PARTS := {
	# A bench of three small desks with papers and a mug; a desk with an open
	# book and a lamp; a monitor to stand on either.
	"desk_bench": Rect2(32.0, 574.0, 48.0, 27.0),
	"desk_ledger": Rect2(82.0, 583.0, 29.0, 26.0),
	"monitor": Rect2(48.0, 58.0, 16.0, 12.0),
	# A chair facing the camera (someone sits behind a desk) and one from
	# behind (someone sits at a desk facing the wall).
	"chair_front": Rect2(2.0, 572.0, 14.0, 23.0),
	"chair_back": Rect2(17.0, 617.0, 14.0, 16.0),
	"cork_board": Rect2(3.0, 656.0, 26.0, 14.0),
	"pin_board": Rect2(208.0, 616.0, 31.0, 21.0),
	"whiteboard": Rect2(162.0, 640.0, 30.0, 25.0),
	"locker": Rect2(192.0, 641.0, 16.0, 31.0),
	"bookcase": Rect2(160.0, 1094.0, 32.0, 36.0),
	"bookcase_pair": Rect2(160.0, 1094.0, 64.0, 36.0),
	"map": Rect2(157.0, 1066.0, 32.0, 21.0),
	"plant_tree": Rect2(167.0, 713.0, 18.0, 31.0),
	"plant_small": Rect2(193.0, 722.0, 14.0, 23.0),
	"palm": Rect2(213.0, 704.0, 23.0, 31.0),
	"sofa": Rect2(16.0, 1157.0, 48.0, 28.0),
	"drawers": Rect2(19.0, 949.0, 27.0, 23.0),
	# A door with a window in it, blinds down; a plain door set in its wall.
	"office_door": Rect2(176.0, 387.0, 32.0, 28.0),
	"wall_door": Rect2(80.0, 416.0, 32.0, 32.0),
	"blinds": Rect2(13.0, 423.0, 38.0, 25.0),
	"window_curtained": Rect2(70.0, 391.0, 36.0, 27.0),
	"stairs": Rect2(144.0, 80.0, 32.0, 48.0),
	"rug": Rect2(48.0, 674.0, 48.0, 28.0),
}

# Room_Builder_free_16x16.png. A wall is a style's two rows: the top one has
# the trim, the bottom one the baseboard. Column 1 of the run repeats cleanly.
const WALL_COLUMN_X := 16.0
const WALL_ROWS := {
	"mint": 9,
	"wood": 11,
	"greyblue": 17,
	"beige": 19,
}

# A floor is one tile, repeated: the centre-bottom tile of each 3x2 swatch.
# The others carry the edge shading a room's border gives the floor, and
# repeating the whole swatch shows every seam.
const FLOORS := {
	"carpet": Rect2(240.0, 160.0, 16.0, 16.0),
	"tile_grey": Rect2(192.0, 192.0, 16.0, 16.0),
	"tile_yellow": Rect2(192.0, 128.0, 16.0, 16.0),
	"parquet": Rect2(192.0, 224.0, 16.0, 16.0),
}
