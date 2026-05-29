# Stack Sprite Demo

A small Godot demo that renders a pixel-art vehicle with the sprite stacking technique. The scene places a stacked "Optimus" sprite in a snowy tile map, adds keyboard and touch movement, and leaves particle-based snow tracks and smoke behind the vehicle while it moves.

## Overview

This project is built around a simple idea: instead of using a 3D mesh, the vehicle is drawn as a set of 2D pixel slices. At runtime, Godot loads those slices, offsets them vertically, and rotates them together. The result reads like a chunky voxel-style object while staying in a 2D workflow.

Key files:

- `project.godot` - Godot project configuration and input actions.
- `main.tscn` - Main scene with the snowy map, touch controls, particles, and the Optimus instance.
- `optimus.tscn` - Character scene containing the stack root, collision shape, camera, and movement script.
- `optimus.gd` - Builds the sprite stack, handles movement, rotates the slices, and configures the trail particles.
- `Texture/Optimus/Optimus*.png` - The ordered sprite-stack slices used by the vehicle.

## Requirements

- Godot 4.x. The project is currently configured with a Godot 4.6 feature tag.
- Aseprite, if you want to edit or generate new sprite-stack assets.
- Optional: [DarkDes/AsepriteSpriteStackEd](https://github.com/DarkDes/AsepriteSpriteStackEd) for previewing and slicing sprite-stack artwork inside Aseprite.

## Running the Demo

Open the project folder in Godot and run `main.tscn`.

Controls:

- `WASD` or arrow keys to move.
- Mouse drag or touch drag to use the on-screen joystick.

## How Sprite Stacking Works Here

Sprite stacking represents depth by layering many flat sprites. Each slice is usually one pixel or a few pixels apart in height. When all slices are drawn with a small offset, the object gets a visible vertical volume. When the whole stack rotates, the viewer perceives the object as a 3D form.

In this project, `optimus.gd` defines an ordered list of slice images:

```gdscript
const SLICE_PATHS := [
	"res://Texture/Optimus/Optimus1.png",
	"res://Texture/Optimus/Optimus2.png",
	...
	"res://Texture/Optimus/Optimus16.png",
]
```

During `_ready()`, `_build_pixel_stack()` creates one `Sprite2D` per slice and adds it under the `Stack` node. Each slice is positioned slightly higher than the previous one:

```gdscript
sprite.position = Vector2(0, -index * slice_height_px)
```

Movement updates the facing angle, then `_set_stack_angle()` applies the same rotation to every slice. Keyboard movement snaps rotation to eight directions for a crisp pixel-art feel, while touch movement uses smoother analog rotation.

## Creating Assets with AsepriteSpriteStackEd

[AsepriteSpriteStackEd](https://github.com/DarkDes/AsepriteSpriteStackEd) is a pair of Lua scripts for Aseprite. According to its repository, it requires Aseprite `v1.3-rc2` or newer and installs by copying `SpriteStack_Previewer.lua` and `SpriteStack_Slicer.lua` into Aseprite's scripts folder, then rescanning scripts from `File > Scripts > Rescan Scripts Folder`.

The plugin helps with two parts of a sprite-stack workflow:

- `SpriteStack Previewer` previews a stack where each frame is treated as one slice. It supports 360-degree preview, changing the distance between slices, viewing individual slices, and exporting a rotation animation preview.
- `SpriteStack Slicer` creates a new sprite from a flat source image by slicing it along vertical lines.

A typical workflow for this project is:

1. Draw or import the object in Aseprite.
2. Use the slicer or manually prepare one frame per height slice.
3. Use the previewer to check the volume, slice spacing, and rotation.
4. Export each slice as a separate PNG in bottom-to-top order.
5. Place the files in `Texture/Optimus/` and list them in `SLICE_PATHS`.
6. Adjust `slice_height_px` in `optimus.gd` or on the `Optimus` scene instance if the stack feels too flat or too tall.

## Notes for Extending

- Keep the slice order consistent. `Optimus1.png` is the bottom slice and later files are stacked upward.
- Use nearest-neighbor texture filtering for sharp pixels. This project sets `textures/canvas_textures/default_texture_filter=0`.
- If you add a new stacked object, reuse the same pattern: a parent `Node2D`, one `Sprite2D` per slice, and a shared rotation angle.
- Particle trails are configured in code, so the scene only needs the `GroundMarks/OptimusSnowTracks` nodes as stable attachment points.

## Credits

- Sprite-stack editing workflow: [DarkDes/AsepriteSpriteStackEd](https://github.com/DarkDes/AsepriteSpriteStackEd).
- Built with Godot.
