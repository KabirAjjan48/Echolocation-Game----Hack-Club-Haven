NECROMANCER DUNGEON - FREE PACK
by Kaktora Games
===============================

Thank you for downloading! This pack is the first part of the
Necromancer Dungeon series. All packs share the same 32-color
palette and grid, so they fit together seamlessly.


SPECS
-----
- Tile size: 16x16 px
- Characters: 32x32 px frames
- Perspective: top-down (3/4 view)
- Format: PNG, transparent background
- Animation speed: 100-150 ms per frame (see below)
- Palette: 32 colors (Palette folder: .gpl / .hex / .png)


CONTENTS
--------
Tileset/
  dungeon_tileset.png   80x112, 16x16 grid
                        - Room walls (corners, wall top, wall face,
                          side walls, bottom wall)
                        - Wall junctions (T pieces), vertical walls,
                          wall ends
                        - Doors (closed / open, 16x32)
                        - Stairs down
                        - Floor + 3 variations (moss, bones, cracks)
  stairs_down.png       16x16

Props/
  door_closed.png       16x32
  door_open.png         16x32
  chest_closed.png      16x16
  chest_open.png        16x16
  barrel.png            16x16
  skull.png             16x16
  wall_chains.png       16x16
  bone_pile.png         32x32
  Animated/
    torch_wall_anim.png 4 frames, 16x16 each, 120 ms
    candle_anim.png     3 frames, 16x16 each, 120 ms

Characters/Skeleton/    32x32 frames, horizontal strips, facing right
  skeleton_idle.png     4 frames, 150 ms
  skeleton_walk.png     6 frames, 100 ms
  skeleton_attack.png   6 frames, 100 ms (hold frame 2 for 150 ms;
                        the hit lands on frame 4)
  skeleton_hurt.png     2 frames, 100 ms
  skeleton_death.png    6 frames, 120 ms


TIPS
----
- Walls are built from a wall top row + a wall face row. Stack more
  wall face rows for taller walls.
- Use floor variations on about 10-15% of floor tiles.
- Doors and stairs are included both in the tileset (for painting)
  and as separate files (for interactive objects).
- Flip the skeleton horizontally to face left.
- Start animated props on different frames so they do not flicker
  in sync.


LICENSE
-------
See LICENSE.txt.
