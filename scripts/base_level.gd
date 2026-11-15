@tool
extends Node2D

const CELL_SIZE := 64.0
const MAP_COLUMNS := 20
const MAP_ROWS := 14
const ROOM2_LEFT := -5
const ROOM2_RIGHT := 26
const ROOM2_TOP := 14
const ROOM2_BOTTOM := 37
const ROOM3_LEFT := 1
const ROOM3_RIGHT := 20
const ROOM3_TOP := ROOM2_BOTTOM + 1
const ROOM3_BOTTOM := 53
const LOCK_ROOM_LEFT := 20
const LOCK_ROOM_RIGHT := 31
const LOCK_ROOM_TOP := 3
const LOCK_ROOM_BOTTOM := 11
const LOCK_GATE_TOP := 5
const LOCK_GATE_BOTTOM := 7
const ROOM4_LEFT := LOCK_ROOM_RIGHT + 1
const ROOM4_RIGHT := 47
const ROOM4_TOP := LOCK_ROOM_TOP
const ROOM4_BOTTOM := 17
const ROOM4_DOOR_TOP := 7
const ROOM4_DOOR_BOTTOM := 9
const MAZE_ROOM_LEFT := ROOM4_RIGHT + 1
const MAZE_ROOM_RIGHT := 77
const MAZE_ROOM_TOP := ROOM4_TOP
const MAZE_ROOM_BOTTOM := 33
const MAZE_DOOR_TOP := 9
const MAZE_DOOR_BOTTOM := 11
const MAZE_EXIT_TOP := 19
const MAZE_EXIT_BOTTOM := 21
const TREASURE_ROOM_LEFT := MAZE_ROOM_RIGHT + 1
const TREASURE_ROOM_RIGHT := 91
const TREASURE_ROOM_TOP := 14
const TREASURE_ROOM_BOTTOM := 28
const TREASURE_DOOR_TOP := MAZE_EXIT_TOP
const TREASURE_DOOR_BOTTOM := MAZE_EXIT_BOTTOM
const VOID_MARGIN := 12 * CELL_SIZE
const CAVERN_TILE_SET: TileSet = preload("res://scenes/levels/cavern_tileset.tres")
const BARREL_TEXTURE: Texture2D = preload("res://assests/images/tileset/Neko Shadowy Cavern FREE v1.0.0/Neko Shadowy Cavern FREE/sprites/objects/dungeon-barrel.png")
const BOX_TEXTURE: Texture2D = preload("res://assests/images/tileset/Neko Shadowy Cavern FREE v1.0.0/Neko Shadowy Cavern FREE/sprites/objects/dungeon-box.png")
const CHEST_CLOSED_TEXTURE: Texture2D = preload("res://assests/images/tileset/NecromancerDungeon_FreePack/NecromancerDungeon_FreePack/Props/chest_closed.png")
const CHEST_OPEN_TEXTURE: Texture2D = preload("res://assests/images/tileset/NecromancerDungeon_FreePack/NecromancerDungeon_FreePack/Props/chest_open.png")
const TRAP_PLATE_TEXTURE: Texture2D = preload("res://assests/images/tileset/free-pixel-art-dungeon-objects-asset-pack/Tiled_files/trap_plate.png")
const KEY_TEXTURE: Texture2D = preload("res://assests/images/tileset/Pixel Art Key Pack - Animated/Pixel Art Key Pack - Animated/Key 1/Key 1 - GOLD - .png")
const PADLOCK_SHEET: Texture2D = preload("res://assests/images/tileset/Pixel Art Padlock Pack - Animated/Pixel Art Padlock Pack - Animated/Triangle Padlock/GOLD/Triangle Padlock - GOLD - Spritesheet.png")
const FLOOR_ATLAS_CELLS := [
	Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
	Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2),
	Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4),
]
const BORDER_WALL_ATLAS_CELL := Vector2i(1, 0)

@onready var map_geometry: Node2D = $MapGeometry
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var has_key := false
var trap_triggered := false
var trap_plate_frames: SpriteFrames
var checkpoint_position := Vector2(128, 160)
var maze_corner_trap_cells: Array[Vector2i] = []
var treasure_claimed := false

func _ready() -> void:
	_build_map()
	floor_layer = map_geometry.get_node_or_null("Floor") as TileMapLayer
	wall_layer = map_geometry.get_node_or_null("Walls") as TileMapLayer
	var key_pickup := map_geometry.get_node_or_null("KeyPickup") as Area2D
	if key_pickup != null and not key_pickup.body_entered.is_connected(_on_key_body_entered):
		key_pickup.body_entered.connect(_on_key_body_entered)
	var unlock_zone := map_geometry.get_node_or_null("UnlockZone") as Area2D
	if unlock_zone != null and not unlock_zone.body_entered.is_connected(_on_unlock_zone_body_entered):
		unlock_zone.body_entered.connect(_on_unlock_zone_body_entered)
	var checkpoint := map_geometry.get_node_or_null("MazeCheckpoint") as Area2D
	if checkpoint != null and not checkpoint.body_entered.is_connected(_on_maze_checkpoint_body_entered):
		checkpoint.body_entered.connect(_on_maze_checkpoint_body_entered)
	var treasure_chest := map_geometry.get_node_or_null("TreasureChest") as Area2D
	if treasure_chest != null and not treasure_chest.body_entered.is_connected(_on_treasure_chest_body_entered):
		treasure_chest.body_entered.connect(_on_treasure_chest_body_entered)
	for child in map_geometry.get_children():
		if child is Area2D and child.name.begins_with("HiddenTrap"):
			if not child.body_entered.is_connected(_on_trap_body_entered):
				child.body_entered.connect(_on_trap_body_entered)

func _build_map() -> void:
	if map_geometry.has_node("GeneratedLockedRoomV28"):
		return
	for child in map_geometry.get_children():
		map_geometry.remove_child(child)
		child.free()

	floor_layer = TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = CAVERN_TILE_SET
	floor_layer.scale = Vector2(4, 4)
	floor_layer.z_index = -1
	_add_owned_child(map_geometry, floor_layer)

	wall_layer = TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = CAVERN_TILE_SET
	wall_layer.scale = Vector2(4, 4)
	wall_layer.z_index = 0
	_add_owned_child(map_geometry, wall_layer)

	_build_out_of_bounds()
	_build_floor()
	_build_boundaries()
	_build_maze()
	_add_maze_checkpoint()
	_build_props()
	_build_trap_plate_frames()
	_build_traps()
	_add_key_pickup()
	_add_locked_room()
	_add_treasure_chest()

	var marker := Node.new()
	marker.name = "GeneratedLockedRoomV28"
	_add_owned_child(map_geometry, marker)

func _add_owned_child(parent: Node, child: Node) -> void:
	parent.add_child(child)
	if Engine.is_editor_hint():
		child.owner = get_tree().edited_scene_root

func _build_out_of_bounds() -> void:
	var void_layer := Node2D.new()
	void_layer.name = "OutOfBounds"
	void_layer.z_index = -2
	_add_owned_child(map_geometry, void_layer)
	var main_width := MAP_COLUMNS * CELL_SIZE
	var level_bottom := (ROOM3_BOTTOM + 1) * CELL_SIZE
	var room2_left := ROOM2_LEFT * CELL_SIZE
	var room2_right := (ROOM2_RIGHT + 1) * CELL_SIZE
	var room3_left := ROOM3_LEFT * CELL_SIZE
	var room3_right := (ROOM3_RIGHT + 1) * CELL_SIZE
	var maze_right := (MAZE_ROOM_RIGHT + 1) * CELL_SIZE
	var treasure_right := (TREASURE_ROOM_RIGHT + 1) * CELL_SIZE
	var full_left := minf(0.0, minf(room2_left, room3_left)) - VOID_MARGIN
	var full_right := maxf(main_width, maxf(room2_right, maxf(room3_right, treasure_right))) + VOID_MARGIN
	_add_void_rect(void_layer, Rect2(full_left, -VOID_MARGIN, full_right - full_left, VOID_MARGIN))
	_add_void_rect(void_layer, Rect2(full_left, level_bottom, full_right - full_left, VOID_MARGIN))
	_add_void_rect(void_layer, Rect2(-VOID_MARGIN, 0, VOID_MARGIN, MAP_ROWS * CELL_SIZE))
	_add_void_rect(void_layer, Rect2(main_width, 0, full_right - main_width, MAP_ROWS * CELL_SIZE))
	_add_void_rect(void_layer, Rect2(maze_right, MAP_ROWS * CELL_SIZE, full_right - maze_right, level_bottom - MAP_ROWS * CELL_SIZE))
	_add_void_rect(void_layer, Rect2(room2_left - VOID_MARGIN, MAP_ROWS * CELL_SIZE, VOID_MARGIN, (ROOM2_BOTTOM + 1 - MAP_ROWS) * CELL_SIZE))
	_add_void_rect(void_layer, Rect2(room2_right, MAP_ROWS * CELL_SIZE, VOID_MARGIN, (ROOM2_BOTTOM + 1 - MAP_ROWS) * CELL_SIZE))
	_add_void_rect(void_layer, Rect2(room3_left - VOID_MARGIN, ROOM3_TOP * CELL_SIZE, VOID_MARGIN, (ROOM3_BOTTOM + 1 - ROOM3_TOP) * CELL_SIZE))
	_add_void_rect(void_layer, Rect2(room3_right, ROOM3_TOP * CELL_SIZE, VOID_MARGIN, (ROOM3_BOTTOM + 1 - ROOM3_TOP) * CELL_SIZE))

func _add_void_rect(parent: Node, rect: Rect2) -> void:
	var patch := Polygon2D.new()
	patch.name = "VoidPatch"
	patch.polygon = PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)])
	patch.position = rect.position
	patch.color = Color(0.035, 0.025, 0.075)
	_add_owned_child(parent, patch)

func _paint_floor_cell(x: int, y: int) -> void:
	var variant: int = (x * 7 + y * 13) % FLOOR_ATLAS_CELLS.size()
	floor_layer.set_cell(Vector2i(x, y), 0, FLOOR_ATLAS_CELLS[variant])

func _build_floor() -> void:
	for x in range(1, MAP_COLUMNS - 1):
		for y in range(1, MAP_ROWS - 1):
			_paint_floor_cell(x, y)
	for x in range(9, 12):
		_paint_floor_cell(x, MAP_ROWS - 1)
		_paint_floor_cell(x, ROOM2_TOP)
		_paint_floor_cell(x, ROOM2_BOTTOM)
		_paint_floor_cell(x, ROOM3_TOP)
	for x in range(ROOM2_LEFT + 1, ROOM2_RIGHT):
		for y in range(ROOM2_TOP + 1, ROOM2_BOTTOM):
			_paint_floor_cell(x, y)
	for x in range(ROOM3_LEFT + 1, ROOM3_RIGHT):
		for y in range(ROOM3_TOP + 1, ROOM3_BOTTOM):
			_paint_floor_cell(x, y)
	for x in range(LOCK_ROOM_LEFT + 1, LOCK_ROOM_RIGHT):
		for y in range(LOCK_ROOM_TOP + 1, LOCK_ROOM_BOTTOM):
			_paint_floor_cell(x, y)
	for y in range(LOCK_GATE_TOP, LOCK_GATE_BOTTOM + 1):
		_paint_floor_cell(MAP_COLUMNS - 1, y)
		_paint_floor_cell(LOCK_ROOM_LEFT, y)
	for x in range(ROOM4_LEFT + 1, ROOM4_RIGHT):
		for y in range(ROOM4_TOP + 1, ROOM4_BOTTOM):
			_paint_floor_cell(x, y)
	for y in range(ROOM4_DOOR_TOP, ROOM4_DOOR_BOTTOM + 1):
		_paint_floor_cell(LOCK_ROOM_RIGHT, y)
		_paint_floor_cell(ROOM4_LEFT, y)
	for x in range(MAZE_ROOM_LEFT + 1, MAZE_ROOM_RIGHT):
		for y in range(MAZE_ROOM_TOP + 1, MAZE_ROOM_BOTTOM):
			_paint_floor_cell(x, y)
	for x in range(TREASURE_ROOM_LEFT + 1, TREASURE_ROOM_RIGHT):
		for y in range(TREASURE_ROOM_TOP + 1, TREASURE_ROOM_BOTTOM):
			_paint_floor_cell(x, y)
	for y in range(MAZE_DOOR_TOP, MAZE_DOOR_BOTTOM + 1):
		_paint_floor_cell(ROOM4_RIGHT, y)
		_paint_floor_cell(MAZE_ROOM_LEFT, y)
	for y in range(MAZE_EXIT_TOP, MAZE_EXIT_BOTTOM + 1):
		_paint_floor_cell(MAZE_ROOM_RIGHT, y)
		_paint_floor_cell(TREASURE_ROOM_LEFT, y)
func _set_wall_cell(x: int, y: int) -> void:
	wall_layer.set_cell(Vector2i(x, y), 1, BORDER_WALL_ATLAS_CELL)

func _build_boundaries() -> void:
	for x in range(MAP_COLUMNS):
		_set_wall_cell(x, 0)
		if x < 9 or x > 11:
			_set_wall_cell(x, MAP_ROWS - 1)
	for y in range(1, MAP_ROWS - 1):
		_set_wall_cell(0, y)
		if y < LOCK_GATE_TOP or y > LOCK_GATE_BOTTOM:
			_set_wall_cell(MAP_COLUMNS - 1, y)

	for x in range(ROOM2_LEFT, ROOM2_RIGHT + 1):
		if x < 9 or x > 11:
			_set_wall_cell(x, ROOM2_TOP)
			_set_wall_cell(x, ROOM2_BOTTOM)
	for y in range(ROOM2_TOP + 1, ROOM2_BOTTOM):
		_set_wall_cell(ROOM2_LEFT, y)
		_set_wall_cell(ROOM2_RIGHT, y)

	for x in range(ROOM3_LEFT, ROOM3_RIGHT + 1):
		if x < 9 or x > 11:
			_set_wall_cell(x, ROOM3_TOP)
		_set_wall_cell(x, ROOM3_BOTTOM)
	for y in range(ROOM3_TOP + 1, ROOM3_BOTTOM):
		_set_wall_cell(ROOM3_LEFT, y)
		_set_wall_cell(ROOM3_RIGHT, y)

	for x in range(LOCK_ROOM_LEFT, LOCK_ROOM_RIGHT + 1):
		_set_wall_cell(x, LOCK_ROOM_TOP)
		_set_wall_cell(x, LOCK_ROOM_BOTTOM)
	for y in range(LOCK_ROOM_TOP + 1, LOCK_ROOM_BOTTOM):
		if y < LOCK_GATE_TOP or y > LOCK_GATE_BOTTOM:
			_set_wall_cell(LOCK_ROOM_LEFT, y)
		if y < ROOM4_DOOR_TOP or y > ROOM4_DOOR_BOTTOM:
			_set_wall_cell(LOCK_ROOM_RIGHT, y)

	for x in range(ROOM4_LEFT, ROOM4_RIGHT + 1):
		_set_wall_cell(x, ROOM4_TOP)
		_set_wall_cell(x, ROOM4_BOTTOM)
	for y in range(ROOM4_TOP + 1, ROOM4_BOTTOM):
		if y < ROOM4_DOOR_TOP or y > ROOM4_DOOR_BOTTOM:
			_set_wall_cell(ROOM4_LEFT, y)
		if y < MAZE_DOOR_TOP or y > MAZE_DOOR_BOTTOM:
			_set_wall_cell(ROOM4_RIGHT, y)

	for x in range(MAZE_ROOM_LEFT, MAZE_ROOM_RIGHT + 1):
		_set_wall_cell(x, MAZE_ROOM_TOP)
		_set_wall_cell(x, MAZE_ROOM_BOTTOM)
	for y in range(MAZE_ROOM_TOP + 1, MAZE_ROOM_BOTTOM):
		if y < MAZE_DOOR_TOP or y > MAZE_DOOR_BOTTOM:
			_set_wall_cell(MAZE_ROOM_LEFT, y)
		if y < MAZE_EXIT_TOP or y > MAZE_EXIT_BOTTOM:
			_set_wall_cell(MAZE_ROOM_RIGHT, y)

	for x in range(TREASURE_ROOM_LEFT, TREASURE_ROOM_RIGHT + 1):
		_set_wall_cell(x, TREASURE_ROOM_TOP)
		_set_wall_cell(x, TREASURE_ROOM_BOTTOM)
	for y in range(TREASURE_ROOM_TOP + 1, TREASURE_ROOM_BOTTOM):
		if y < TREASURE_DOOR_TOP or y > TREASURE_DOOR_BOTTOM:
			_set_wall_cell(TREASURE_ROOM_LEFT, y)
		_set_wall_cell(TREASURE_ROOM_RIGHT, y)

	_add_collision("TopBoundary", Rect2(0, 0, MAP_COLUMNS * CELL_SIZE, CELL_SIZE))
	_add_collision("LeftBoundary", Rect2(0, CELL_SIZE, CELL_SIZE, (MAP_ROWS - 2) * CELL_SIZE))
	_add_collision("RightBoundaryTop", Rect2((MAP_COLUMNS - 1) * CELL_SIZE, CELL_SIZE, CELL_SIZE, (LOCK_GATE_TOP - 1) * CELL_SIZE))
	_add_collision("RightBoundaryBottom", Rect2((MAP_COLUMNS - 1) * CELL_SIZE, (LOCK_GATE_BOTTOM + 1) * CELL_SIZE, CELL_SIZE, (MAP_ROWS - LOCK_GATE_BOTTOM - 2) * CELL_SIZE))
	_add_collision("BottomBoundaryLeft", Rect2(0, (MAP_ROWS - 1) * CELL_SIZE, 9 * CELL_SIZE, CELL_SIZE))
	_add_collision("BottomBoundaryRight", Rect2(12 * CELL_SIZE, (MAP_ROWS - 1) * CELL_SIZE, 8 * CELL_SIZE, CELL_SIZE))

	_add_collision("Room2TopLeft", Rect2(ROOM2_LEFT * CELL_SIZE, ROOM2_TOP * CELL_SIZE, (9 - ROOM2_LEFT) * CELL_SIZE, CELL_SIZE))
	_add_collision("Room2TopRight", Rect2(12 * CELL_SIZE, ROOM2_TOP * CELL_SIZE, (ROOM2_RIGHT - 11) * CELL_SIZE, CELL_SIZE))
	_add_collision("Room2Left", Rect2(ROOM2_LEFT * CELL_SIZE, (ROOM2_TOP + 1) * CELL_SIZE, CELL_SIZE, (ROOM2_BOTTOM - ROOM2_TOP - 1) * CELL_SIZE))
	_add_collision("Room2Right", Rect2(ROOM2_RIGHT * CELL_SIZE, (ROOM2_TOP + 1) * CELL_SIZE, CELL_SIZE, (ROOM2_BOTTOM - ROOM2_TOP - 1) * CELL_SIZE))
	_add_collision("Room2BottomLeft", Rect2(ROOM2_LEFT * CELL_SIZE, ROOM2_BOTTOM * CELL_SIZE, (9 - ROOM2_LEFT) * CELL_SIZE, CELL_SIZE))
	_add_collision("Room2BottomRight", Rect2(12 * CELL_SIZE, ROOM2_BOTTOM * CELL_SIZE, (ROOM2_RIGHT - 11) * CELL_SIZE, CELL_SIZE))

	_add_collision("Room3TopLeft", Rect2(ROOM3_LEFT * CELL_SIZE, ROOM3_TOP * CELL_SIZE, (9 - ROOM3_LEFT) * CELL_SIZE, CELL_SIZE))
	_add_collision("Room3TopRight", Rect2(12 * CELL_SIZE, ROOM3_TOP * CELL_SIZE, (ROOM3_RIGHT - 11) * CELL_SIZE, CELL_SIZE))
	_add_collision("Room3Left", Rect2(ROOM3_LEFT * CELL_SIZE, (ROOM3_TOP + 1) * CELL_SIZE, CELL_SIZE, (ROOM3_BOTTOM - ROOM3_TOP - 1) * CELL_SIZE))
	_add_collision("Room3Right", Rect2(ROOM3_RIGHT * CELL_SIZE, (ROOM3_TOP + 1) * CELL_SIZE, CELL_SIZE, (ROOM3_BOTTOM - ROOM3_TOP - 1) * CELL_SIZE))
	_add_collision("Room3Bottom", Rect2(ROOM3_LEFT * CELL_SIZE, ROOM3_BOTTOM * CELL_SIZE, (ROOM3_RIGHT - ROOM3_LEFT + 1) * CELL_SIZE, CELL_SIZE))

	_add_collision("LockedRoomTop", Rect2(LOCK_ROOM_LEFT * CELL_SIZE, LOCK_ROOM_TOP * CELL_SIZE, (LOCK_ROOM_RIGHT - LOCK_ROOM_LEFT + 1) * CELL_SIZE, CELL_SIZE))
	_add_collision("LockedRoomBottom", Rect2(LOCK_ROOM_LEFT * CELL_SIZE, LOCK_ROOM_BOTTOM * CELL_SIZE, (LOCK_ROOM_RIGHT - LOCK_ROOM_LEFT + 1) * CELL_SIZE, CELL_SIZE))
	_add_collision("LockedRoomLeftTop", Rect2(LOCK_ROOM_LEFT * CELL_SIZE, (LOCK_ROOM_TOP + 1) * CELL_SIZE, CELL_SIZE, (LOCK_GATE_TOP - LOCK_ROOM_TOP - 1) * CELL_SIZE))
	_add_collision("LockedRoomLeftBottom", Rect2(LOCK_ROOM_LEFT * CELL_SIZE, (LOCK_GATE_BOTTOM + 1) * CELL_SIZE, CELL_SIZE, (LOCK_ROOM_BOTTOM - LOCK_GATE_BOTTOM - 1) * CELL_SIZE))
	_add_collision("LockedRoomRightTop", Rect2(LOCK_ROOM_RIGHT * CELL_SIZE, (LOCK_ROOM_TOP + 1) * CELL_SIZE, CELL_SIZE, (ROOM4_DOOR_TOP - LOCK_ROOM_TOP - 1) * CELL_SIZE))
	_add_collision("LockedRoomRightBottom", Rect2(LOCK_ROOM_RIGHT * CELL_SIZE, (ROOM4_DOOR_BOTTOM + 1) * CELL_SIZE, CELL_SIZE, (LOCK_ROOM_BOTTOM - ROOM4_DOOR_BOTTOM - 1) * CELL_SIZE))

	_add_collision("Room4Top", Rect2(ROOM4_LEFT * CELL_SIZE, ROOM4_TOP * CELL_SIZE, (ROOM4_RIGHT - ROOM4_LEFT + 1) * CELL_SIZE, CELL_SIZE))
	_add_collision("Room4Bottom", Rect2(ROOM4_LEFT * CELL_SIZE, ROOM4_BOTTOM * CELL_SIZE, (ROOM4_RIGHT - ROOM4_LEFT + 1) * CELL_SIZE, CELL_SIZE))
	_add_collision("Room4LeftTop", Rect2(ROOM4_LEFT * CELL_SIZE, (ROOM4_TOP + 1) * CELL_SIZE, CELL_SIZE, (ROOM4_DOOR_TOP - ROOM4_TOP - 1) * CELL_SIZE))
	_add_collision("Room4LeftBottom", Rect2(ROOM4_LEFT * CELL_SIZE, (ROOM4_DOOR_BOTTOM + 1) * CELL_SIZE, CELL_SIZE, (ROOM4_BOTTOM - ROOM4_DOOR_BOTTOM - 1) * CELL_SIZE))
	_add_collision("Room4RightTop", Rect2(ROOM4_RIGHT * CELL_SIZE, (ROOM4_TOP + 1) * CELL_SIZE, CELL_SIZE, (MAZE_DOOR_TOP - ROOM4_TOP - 1) * CELL_SIZE))
	_add_collision("Room4RightBottom", Rect2(ROOM4_RIGHT * CELL_SIZE, (MAZE_DOOR_BOTTOM + 1) * CELL_SIZE, CELL_SIZE, (ROOM4_BOTTOM - MAZE_DOOR_BOTTOM - 1) * CELL_SIZE))

	_add_collision("MazeRoomTop", Rect2(MAZE_ROOM_LEFT * CELL_SIZE, MAZE_ROOM_TOP * CELL_SIZE, (MAZE_ROOM_RIGHT - MAZE_ROOM_LEFT + 1) * CELL_SIZE, CELL_SIZE))
	_add_collision("MazeRoomBottom", Rect2(MAZE_ROOM_LEFT * CELL_SIZE, MAZE_ROOM_BOTTOM * CELL_SIZE, (MAZE_ROOM_RIGHT - MAZE_ROOM_LEFT + 1) * CELL_SIZE, CELL_SIZE))
	_add_collision("MazeRoomLeftTop", Rect2(MAZE_ROOM_LEFT * CELL_SIZE, (MAZE_ROOM_TOP + 1) * CELL_SIZE, CELL_SIZE, (MAZE_DOOR_TOP - MAZE_ROOM_TOP - 1) * CELL_SIZE))
	_add_collision("MazeRoomLeftBottom", Rect2(MAZE_ROOM_LEFT * CELL_SIZE, (MAZE_DOOR_BOTTOM + 1) * CELL_SIZE, CELL_SIZE, (MAZE_ROOM_BOTTOM - MAZE_DOOR_BOTTOM - 1) * CELL_SIZE))
	_add_collision("MazeRoomRightTop", Rect2(MAZE_ROOM_RIGHT * CELL_SIZE, (MAZE_ROOM_TOP + 1) * CELL_SIZE, CELL_SIZE, (MAZE_EXIT_TOP - MAZE_ROOM_TOP - 1) * CELL_SIZE))
	_add_collision("MazeRoomRightBottom", Rect2(MAZE_ROOM_RIGHT * CELL_SIZE, (MAZE_EXIT_BOTTOM + 1) * CELL_SIZE, CELL_SIZE, (MAZE_ROOM_BOTTOM - MAZE_EXIT_BOTTOM - 1) * CELL_SIZE))

	_add_collision("TreasureRoomTop", Rect2(TREASURE_ROOM_LEFT * CELL_SIZE, TREASURE_ROOM_TOP * CELL_SIZE, (TREASURE_ROOM_RIGHT - TREASURE_ROOM_LEFT + 1) * CELL_SIZE, CELL_SIZE))
	_add_collision("TreasureRoomBottom", Rect2(TREASURE_ROOM_LEFT * CELL_SIZE, TREASURE_ROOM_BOTTOM * CELL_SIZE, (TREASURE_ROOM_RIGHT - TREASURE_ROOM_LEFT + 1) * CELL_SIZE, CELL_SIZE))
	_add_collision("TreasureRoomLeftTop", Rect2(TREASURE_ROOM_LEFT * CELL_SIZE, (TREASURE_ROOM_TOP + 1) * CELL_SIZE, CELL_SIZE, (TREASURE_DOOR_TOP - TREASURE_ROOM_TOP - 1) * CELL_SIZE))
	_add_collision("TreasureRoomLeftBottom", Rect2(TREASURE_ROOM_LEFT * CELL_SIZE, (TREASURE_DOOR_BOTTOM + 1) * CELL_SIZE, CELL_SIZE, (TREASURE_ROOM_BOTTOM - TREASURE_DOOR_BOTTOM - 1) * CELL_SIZE))
	_add_collision("TreasureRoomRight", Rect2(TREASURE_ROOM_RIGHT * CELL_SIZE, (TREASURE_ROOM_TOP + 1) * CELL_SIZE, CELL_SIZE, (TREASURE_ROOM_BOTTOM - TREASURE_ROOM_TOP - 1) * CELL_SIZE))

func _build_maze() -> void:
	# Start with a solid grid and carve one winding, dead-end-filled route through it.
	var maze_walls: Dictionary = {}
	var first_x := MAZE_ROOM_LEFT + 1
	var last_x := MAZE_ROOM_RIGHT - 1
	var first_y := MAZE_ROOM_TOP + 1
	var last_y := MAZE_ROOM_BOTTOM - 1
	for x in range(first_x, last_x + 1):
		for y in range(first_y, last_y + 1):
			var tile := Vector2i(x, y)
			maze_walls[tile] = true
			_set_wall_cell(x, y)

	var maze_columns := 7
	var maze_rows := 6
	var start_cell := Vector2i(0, 1)
	var visited: Dictionary = {}
	visited[start_cell] = true
	var stack: Array[Vector2i] = [start_cell]
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var rng := RandomNumberGenerator.new()
	rng.seed = 478392
	var start_tile := Vector2i(first_x + start_cell.x * 4, first_y + start_cell.y * 5)
	_carve_maze_region(maze_walls, start_tile, Vector2i(2, 3))

	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var choices: Array[Vector2i] = []
		for direction in directions:
			var neighbor: Vector2i = current + direction
			if neighbor.x >= 0 and neighbor.x < maze_columns and neighbor.y >= 0 and neighbor.y < maze_rows and not _is_maze_corner(neighbor) and not visited.has(neighbor):
				choices.append(neighbor)
		if choices.is_empty():
			stack.pop_back()
			continue

		var next_cell: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
		var current_tile := Vector2i(first_x + current.x * 4, first_y + current.y * 5)
		var next_tile := Vector2i(first_x + next_cell.x * 4, first_y + next_cell.y * 5)
		if current.x != next_cell.x:
			var connector_x := mini(current_tile.x, next_tile.x) + 2
			_carve_maze_region(maze_walls, Vector2i(connector_x, current_tile.y), Vector2i(2, 3))
		else:
			var connector_y := mini(current_tile.y, next_tile.y) + 3
			_carve_maze_region(maze_walls, Vector2i(current_tile.x, connector_y), Vector2i(2, 2))
		_carve_maze_region(maze_walls, next_tile, Vector2i(2, 3))
		visited[next_cell] = true
		stack.append(next_cell)

	# Attach each corner as a terminal dead-end spur, so its trap cannot block the route back to the exit.
	var corner_nodes: Array[Vector2i] = [Vector2i(0, 0), Vector2i(6, 0), Vector2i(0, 5), Vector2i(6, 5)]
	var inward_nodes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(5, 0), Vector2i(1, 5), Vector2i(5, 5)]
	maze_corner_trap_cells.clear()
	for index in range(corner_nodes.size()):
		var corner_node: Vector2i = corner_nodes[index]
		var inward_node: Vector2i = inward_nodes[index]
		var corner_tile := Vector2i(first_x + corner_node.x * 4, first_y + corner_node.y * 5)
		var inward_tile := Vector2i(first_x + inward_node.x * 4, first_y + inward_node.y * 5)
		var connector_x := mini(corner_tile.x, inward_tile.x) + 2
		_carve_maze_region(maze_walls, Vector2i(connector_x, corner_tile.y), Vector2i(2, 3))
		_carve_maze_region(maze_walls, corner_tile, Vector2i(2, 3))
		maze_corner_trap_cells.append(Vector2i(corner_tile.x, corner_tile.y + 1))

	# Join a non-corner maze cell to the doorway into the treasure room.
	var exit_tile := Vector2i(first_x + 6 * 4, first_y + 3 * 5)
	_carve_maze_region(maze_walls, Vector2i(exit_tile.x + 2, exit_tile.y), Vector2i(2, 3))
	# Add an independent passage between the upper and lower maze, away from the exit.
	var lower_bypass := Vector2i(first_x + 1 * 4, first_y + 2 * 5 + 3)
	_carve_maze_region(maze_walls, lower_bypass, Vector2i(2, 2))

	var maze_body := StaticBody2D.new()
	maze_body.name = "MazeInternalWallCollisions"
	maze_body.collision_layer = 1
	maze_body.collision_mask = 1
	_add_owned_child(map_geometry, maze_body)
	for y in range(first_y, last_y + 1):
		var run_start := -1
		for x in range(first_x, last_x + 2):
			var is_wall := x <= last_x and maze_walls.has(Vector2i(x, y))
			if is_wall and run_start < 0:
				run_start = x
			elif not is_wall and run_start >= 0:
				_add_maze_wall_collision(maze_body, run_start, x - run_start, y)
				run_start = -1

func _carve_maze_region(maze_walls: Dictionary, origin: Vector2i, size: Vector2i) -> void:
	for x in range(origin.x, origin.x + size.x):
		for y in range(origin.y, origin.y + size.y):
			var cell := Vector2i(x, y)
			maze_walls.erase(cell)
			wall_layer.erase_cell(cell)

func _is_maze_corner(cell: Vector2i) -> bool:
	return (cell.x == 0 or cell.x == 6) and (cell.y == 0 or cell.y == 5)

func _add_maze_wall_collision(parent: StaticBody2D, start_x: int, width: int, row: int) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width * CELL_SIZE, CELL_SIZE)
	collision.shape = shape
	collision.position = Vector2((start_x * CELL_SIZE) + shape.size.x / 2.0, row * CELL_SIZE + CELL_SIZE / 2.0)
	_add_owned_child(parent, collision)

func _add_maze_checkpoint() -> void:
	var checkpoint := Area2D.new()
	checkpoint.name = "MazeCheckpoint"
	checkpoint.position = Vector2((MAZE_ROOM_LEFT + 2.0) * CELL_SIZE, (MAZE_DOOR_TOP + 1.5) * CELL_SIZE)
	checkpoint.collision_layer = 0
	checkpoint.collision_mask = 1
	_add_owned_child(map_geometry, checkpoint)
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	shape_node.shape = shape
	_add_owned_child(checkpoint, shape_node)
	var marker := Polygon2D.new()
	marker.name = "CheckpointMarker"
	marker.polygon = PackedVector2Array([Vector2(0, -18), Vector2(18, 0), Vector2(0, 18), Vector2(-18, 0)])
	marker.color = Color(0.35, 0.75, 1.0, 1.0)
	marker.z_index = 2
	_add_owned_child(checkpoint, marker)

func _build_props() -> void:
	_add_prop("Barrel_A", Vector2i(6, 5), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Crate_A", Vector2i(9, 7), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Barrel_B", Vector2i(14, 9), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Crate_B", Vector2i(16, 5), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Crate_C", Vector2i(6, 17), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Barrel_C", Vector2i(8, 19), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Barrel_D", Vector2i(13, 16), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Crate_D", Vector2i(14, 19), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Barrel_E", Vector2i(-2, 17), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Crate_E", Vector2i(2, 24), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Barrel_F", Vector2i(21, 18), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Crate_F", Vector2i(23, 28), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Barrel_G", Vector2i(5, 33), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Crate_G", Vector2i(19, 34), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Crate_H", Vector2i(4, 41), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Barrel_H", Vector2i(17, 48), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Barrel_LockedRoom", Vector2i(23, 6), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Crate_LockedRoom", Vector2i(28, 8), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Barrel_Room4", Vector2i(37, 8), BARREL_TEXTURE, Vector2(2, 2), Vector2(44, 44))
	_add_prop("Crate_Room4_A", Vector2i(43, 6), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))
	_add_prop("Crate_Room4_B", Vector2i(40, 14), BOX_TEXTURE, Vector2(4, 4), Vector2(48, 48))

func _build_trap_plate_frames() -> void:
	trap_plate_frames = SpriteFrames.new()
	trap_plate_frames.add_animation("pressure")
	trap_plate_frames.set_animation_speed("pressure", 3.3)
	trap_plate_frames.set_animation_loop("pressure", true)
	# Use the square pressure-plate artwork shown in the referenced image, alternating its two color variants.
	var plate_regions: Array[Rect2] = [Rect2(16, 144, 16, 16), Rect2(48, 144, 16, 16)]
	for region in plate_regions:
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = TRAP_PLATE_TEXTURE
		atlas_frame.region = region
		trap_plate_frames.add_frame("pressure", atlas_frame, 0.3)
func _build_traps() -> void:
	# Room-two traps plus optional corner dead ends in the maze.
	var trap_cells: Array[Vector2i] = [
		# One 3-by-2 center trap, with four small side clumps.
		Vector2i(9, 24), Vector2i(10, 24), Vector2i(11, 24),
		Vector2i(9, 25), Vector2i(10, 25), Vector2i(11, 25),
		Vector2i(2, 18), Vector2i(2, 19),
		Vector2i(19, 21), Vector2i(20, 21),
		Vector2i(2, 30), Vector2i(3, 30),
		Vector2i(17, 32), Vector2i(18, 32),
	]
	trap_cells.append_array(maze_corner_trap_cells)
	for index in range(trap_cells.size()):
		_add_hidden_trap(index, trap_cells[index])

func _add_hidden_trap(index: int, cell: Vector2i) -> void:
	# Leave these cells empty so only the animated pressure plate is drawn there.
	floor_layer.erase_cell(cell)
	var hazard := Area2D.new()
	hazard.name = "HiddenTrap_%02d" % index
	hazard.position = Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)
	hazard.collision_layer = 0
	hazard.collision_mask = 1
	_add_owned_child(map_geometry, hazard)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL_SIZE, CELL_SIZE)
	collision.shape = shape
	collision.position = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	_add_owned_child(hazard, collision)

	var marker := AnimatedSprite2D.new()
	marker.name = "PressurePlate"
	marker.sprite_frames = trap_plate_frames
	marker.animation = &"pressure"
	marker.scale = Vector2(4, 4)
	marker.position = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	marker.z_index = 2
	marker.visible = true
	marker.play()
	_add_owned_child(hazard, marker)
func _add_key_pickup() -> void:
	var area := Area2D.new()
	area.name = "KeyPickup"
	area.position = Vector2(10.5 * CELL_SIZE, 46 * CELL_SIZE)
	area.collision_layer = 0
	area.collision_mask = 1
	_add_owned_child(map_geometry, area)
	var sprite := Sprite2D.new()
	sprite.name = "KeySprite"
	sprite.texture = KEY_TEXTURE
	sprite.scale = Vector2(2, 2)
	sprite.z_index = 2
	_add_owned_child(area, sprite)
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	collision.shape = circle
	_add_owned_child(area, collision)

func _add_treasure_chest() -> void:
	var chest := Area2D.new()
	chest.name = "TreasureChest"
	chest.position = Vector2((TREASURE_ROOM_LEFT + TREASURE_ROOM_RIGHT + 1) * CELL_SIZE / 2.0, (TREASURE_ROOM_TOP + TREASURE_ROOM_BOTTOM + 1) * CELL_SIZE / 2.0)
	chest.collision_layer = 0
	chest.collision_mask = 1
	_add_owned_child(map_geometry, chest)
	var sprite := Sprite2D.new()
	sprite.name = "TreasureChestSprite"
	sprite.texture = CHEST_CLOSED_TEXTURE
	sprite.scale = Vector2(4, 4)
	sprite.z_index = 2
	_add_owned_child(chest, sprite)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	collision.shape = shape
	_add_owned_child(chest, collision)

func _add_locked_room() -> void:
	for y in range(LOCK_GATE_TOP, LOCK_GATE_BOTTOM + 1):
		wall_layer.set_cell(Vector2i(MAP_COLUMNS - 1, y), 1, BORDER_WALL_ATLAS_CELL)
		wall_layer.set_cell(Vector2i(LOCK_ROOM_LEFT, y), 1, BORDER_WALL_ATLAS_CELL)
	var gate := StaticBody2D.new()
	gate.name = "LockedGate"
	gate.position = Vector2((MAP_COLUMNS - 1) * CELL_SIZE, LOCK_GATE_TOP * CELL_SIZE)
	gate.collision_layer = 1
	gate.collision_mask = 1
	_add_owned_child(map_geometry, gate)
	var gate_collision := CollisionShape2D.new()
	var gate_shape := RectangleShape2D.new()
	gate_shape.size = Vector2(2 * CELL_SIZE, (LOCK_GATE_BOTTOM - LOCK_GATE_TOP + 1) * CELL_SIZE)
	gate_collision.shape = gate_shape
	gate_collision.position = gate_shape.size / 2.0
	_add_owned_child(gate, gate_collision)
	var padlock := Sprite2D.new()
	padlock.name = "PadlockSprite"
	padlock.texture = PADLOCK_SHEET
	padlock.region_enabled = true
	padlock.region_rect = Rect2(0, 0, 32, 33)
	padlock.scale = Vector2(1.25, 1.25)
	padlock.position = gate_shape.size / 2.0
	padlock.z_index = 2
	_add_owned_child(gate, padlock)

	var unlock_zone := Area2D.new()
	unlock_zone.name = "UnlockZone"
	unlock_zone.position = Vector2((MAP_COLUMNS - 1.5) * CELL_SIZE, (LOCK_GATE_TOP + LOCK_GATE_BOTTOM + 1) * CELL_SIZE / 2.0)
	unlock_zone.collision_layer = 0
	unlock_zone.collision_mask = 1
	_add_owned_child(map_geometry, unlock_zone)
	var zone_collision := CollisionShape2D.new()
	var zone_shape := RectangleShape2D.new()
	zone_shape.size = Vector2(128, (LOCK_GATE_BOTTOM - LOCK_GATE_TOP + 1) * CELL_SIZE)
	zone_collision.shape = zone_shape
	_add_owned_child(unlock_zone, zone_collision)

func _on_key_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		has_key = true
		var key_pickup := map_geometry.get_node_or_null("KeyPickup")
		if key_pickup:
			key_pickup.queue_free()

func _on_trap_body_entered(body: Node2D) -> void:
	if body.name != "Player" or trap_triggered:
		return
	trap_triggered = true
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.has_method("flash_red_screen"):
		current_scene.call("flash_red_screen")
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(body):
		body.global_position = checkpoint_position
		if body is CharacterBody2D:
			body.velocity = Vector2.ZERO
		if current_scene and current_scene.has_method("trigger_respawn_echo"):
			current_scene.call("trigger_respawn_echo")
	trap_triggered = false

func _on_maze_checkpoint_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	checkpoint_position = Vector2((MAZE_ROOM_LEFT + 2.0) * CELL_SIZE, (MAZE_DOOR_TOP + 1.5) * CELL_SIZE)
	var marker := map_geometry.get_node_or_null("MazeCheckpoint/CheckpointMarker") as Polygon2D
	if marker:
		marker.color = Color(0.4, 1.0, 0.65, 1.0)

func _on_treasure_chest_body_entered(body: Node2D) -> void:
	if body.name != "Player" or treasure_claimed:
		return
	treasure_claimed = true
	var sprite := map_geometry.get_node_or_null("TreasureChest/TreasureChestSprite") as Sprite2D
	if sprite:
		sprite.texture = CHEST_OPEN_TEXTURE
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.has_method("show_win_screen"):
		current_scene.call("show_win_screen")

func _on_unlock_zone_body_entered(body: Node2D) -> void:
	if body.name != "Player" or not has_key:
		return
	has_key = false
	var gate := map_geometry.get_node_or_null("LockedGate")
	if gate:
		gate.queue_free()
	if wall_layer:
		for y in range(LOCK_GATE_TOP, LOCK_GATE_BOTTOM + 1):
			wall_layer.erase_cell(Vector2i(MAP_COLUMNS - 1, y))
			wall_layer.erase_cell(Vector2i(LOCK_ROOM_LEFT, y))
	var unlock_zone := map_geometry.get_node_or_null("UnlockZone") as Area2D
	if unlock_zone:
		unlock_zone.monitoring = false

func _add_collision(node_name: String, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = rect.position
	body.collision_layer = 1
	body.collision_mask = 1
	_add_owned_child(map_geometry, body)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.size / 2.0
	_add_owned_child(body, collision)

func _add_prop(node_name: String, cell: Vector2i, texture: Texture2D, sprite_scale: Vector2, collider_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)
	body.collision_layer = 1
	body.collision_mask = 1
	_add_owned_child(map_geometry, body)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = texture
	sprite.scale = sprite_scale
	sprite.z_index = 1
	_add_owned_child(body, sprite)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = collider_size
	collision.shape = shape
	_add_owned_child(body, collision)
