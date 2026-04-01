# lua-wfc

Lua 5.3 implementation of the [Wave Function Collapse](https://github.com/mxgmn/WaveFunctionCollapse) algorithm by Maxim Gumin. Generates procedural patterns from tile sets or sample images.

## Requirements

- Lua 5.3 (uses native 64-bit integers and `string.pack`)
- macOS (`sips` is used for PNG I/O)

## Setup

The tilesets and sample images live in the [reference C# repo](https://github.com/mxgmn/WaveFunctionCollapse). Symlink them into the project root:

```bash
ln -s /path/to/WaveFunctionCollapse/tilesets tilesets
ln -s /path/to/WaveFunctionCollapse/samples samples
```

## Usage

```bash
lua main.lua              # Demo: Knots, SimpleMaze, and Rooms
lua test_knots.lua        # SimpleTiledModel with Knots tileset
lua test_overlapping.lua  # OverlappingModel with sample images
lua demo_summer.lua       # Summer terrain generation
```

Output images are written to `output/`.

### SimpleTiledModel

Generates from predefined tiles with adjacency rules defined in XML.

```lua
local SimpleTiledModel = require('simple_tiled_model')

local model = SimpleTiledModel.new({
    name = "Knots",           -- tileset name (matches tilesets/Knots.xml)
    subset = "Standard",      -- optional tile subset
    width = 24, height = 24,
    periodic = true,
    tileset_path = "tilesets"
})

if model:run(seed, -1) then   -- seed, iteration limit (-1 = unlimited)
    model:save("output.png")
end
```

Available tilesets: Knots, Rooms, Circles, Circuit, Castle, Summer, FloorPlan.

### OverlappingModel

Learns NxN patterns from a sample image and generates new output respecting those patterns.

```lua
local OverlappingModel = require('overlapping_model')

local model = OverlappingModel.new({
    name = "SimpleMaze",      -- sample name (matches samples/SimpleMaze.png)
    N = 2,                    -- pattern size (2x2 or 3x3)
    width = 48, height = 48,
    periodic = false,
    symmetry = 8,             -- 1, 2, 4, or 8 symmetry variants
    samples_path = "samples"
})

if model:run(seed, -1) then
    model:save("output.png")
end
```

### OSC Integration

`send_to_sc.lua` sends OSC messages to SuperCollider (port 57120). Requires the `losc` package (`luarocks install --local losc`).

## Reference

Based on https://github.com/mxgmn/WaveFunctionCollapse (MIT License).
