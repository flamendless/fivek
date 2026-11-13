COZY UI KIT LITE  (v1.2)
========================================
28 pixel art UI elements for cozy games, drawn at a small base size (1x) and exported at 1x, 2x and 3x.
Free sample of Cozy UI Kit (139 elements and 133 modular tiles).
- Panels & windows: 2
- Buttons: 4
- Bars: 3
- Slots & frames: 2
- Tabs: 2
- Checkboxes, toggles & sliders: 2
- Dialog boxes: 3
- Cursors: 2
- Small UI icons: 8

14 elements are 9-slice ready (panels, windows, buttons, bars, slots, frames, tabs, slider, dialogs).

MODULAR TILES: 16 separate 8x8 tiles (1 sets: panel_wood) to build panels and windows of any size:
corners, tileable edges, a tileable center, horizontal and vertical dividers with junction pieces.

CONTENTS
- 1x/ 2x/ 3x/<category>/<name>.png   transparent PNGs (2x and 3x are exact nearest-neighbour upscales)
- ui_kit.json   for every element: size, category, and where relevant
                nine_slice margins (left/top/right/bottom at 1x),
                godot_patch_margin per scale (NinePatchRect patch_margin_* values),
                unity_sprite_border_LBRT per scale (Sprite Editor border, order Left, Bottom, Right, Top),
                cursor hotspot per scale, and short notes
- ui_kit.csv    the same data as a flat table
- 1x/ 2x/ 3x/tiles/<set>/<tile>.png   the modular 8x8 tiles (16, 24 or 32 px at 2x/3x)
- tiles/tilesheet_1x.png, tilesheet_2x.png, tilesheet_3x.png   all tiles on one sheet, one set per row
- tiles/tiles.json   for every tile: index, set, role, col, row, pixel x/y per scale, file paths and tile_axis
- previews/all_elements_x3.png
- palette.png / palette.hex   the 28-colour palette shared with Cozy Life Icons, Cozy Spooky Icons and Cozy Pixel VFX

USING THE 9-SLICE MARGINS
Godot 4: add a NinePatchRect, set its texture, and copy the four patch_margin values for the scale you use.
Unity: set Sprite Mode to Single, open the Sprite Editor and enter the border values (L, B, R, T),
then use an Image with Image Type "Sliced". Set the texture Filter Mode to Point and Compression to None.
Buttons have no text so you can add your own labels.
Each 9-slice entry in ui_kit.json also has recommended_mode ("tile" or "stretch"), godot_axis_stretch
(axis_stretch_horizontal / axis_stretch_vertical: 0 = STRETCH, 1 = TILE) and unity_image_type ("Tiled" or "Sliced").
tile_safe is true when the stretched parts are uniform, so tile and stretch give the same result.

USING THE MODULAR TILES
Place corner tiles once, repeat edge tiles along their side (tile_axis h or v) and fill the inside with the center tile.
For a divider, use divider_h_left, divider_h_mid (repeat) and divider_h_right across a row, or divider_v_top,
divider_v_mid (repeat) and divider_v_bottom down a column; use divider_cross where the two meet.
Windows: use the window top row and title row pieces for the top two tile rows (title_mid repeats, title_divider_v
starts a vertical divider under the title), then the panel tiles of the same colour for the body.
In Godot or Tiled, load tilesheet_Nx.png with a tile size of 8, 16 or 24 px and no spacing.

HOW THEY WERE MADE
Every element was drawn in code (Python + Pillow) pixel by pixel from hand-chosen shapes and palette colours.
No AI image generation was used.

LICENSE (summary - see LICENSE.txt)
Use in personal and commercial projects (games, apps, videos, prototypes), modified or not;
no attribution required (credit appreciated).
Do NOT resell, redistribute or re-upload the assets themselves (as-is or lightly modified),
standalone or inside another asset pack, and do not use them to train AI / machine-learning models.
