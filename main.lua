#!/usr/local/bin/lua
-- Wave Function Collapse - Main Entry Point
-- Lua implementation of the WFC algorithm

package.path = package.path .. ";./wfc/?.lua"

local SimpleTiledModel = require('simple_tiled_model')
local OverlappingModel = require('overlapping_model')

-- Configuration
local TILESET_PATH = "/Users/rstolz/lua/WaveFunctionCollapse/tilesets"
local SAMPLES_PATH = "/Users/rstolz/lua/WaveFunctionCollapse/samples"

print([[
Wave Function Collapse - Lua Implementation
===========================================

This is a Lua implementation of the Wave Function Collapse algorithm,
based on the reference C# implementation by Maxim Gumin.

Two models are available:
1. Simple Tiled Model - Uses predefined tiles with adjacency rules
2. Overlapping Model - Learns patterns from sample images

]])

-- Example 1: Simple Tiled Model with Knots tileset
print("Example 1: Simple Tiled Model (Knots)")
print("-" .. string.rep("-", 40))

local knots_model = SimpleTiledModel.new({
    name = "Knots",
    subset = "Standard",  -- corner, cross, empty, line
    width = 24,
    height = 24,
    periodic = true,
    tileset_path = TILESET_PATH
})

print(string.format("Created %dx%d grid with %d tiles", 
                   knots_model.MX, knots_model.MY, knots_model.T))

local seed = os.time()
print(string.format("Running with seed %d...", seed))
local success = knots_model:run(seed, -1)

if success then
    local filename = string.format("output/knots_demo_%d.png", seed)
    knots_model:save(filename)
    print(string.format("✓ Success! Saved to %s", filename))
else
    print("✗ Contradiction occurred")
end
print()

-- Example 2: Overlapping Model with SimpleMaze sample
print("Example 2: Overlapping Model (SimpleMaze)")
print("-" .. string.rep("-", 40))

local maze_model = OverlappingModel.new({
    name = "SimpleMaze",
    N = 2,  -- Pattern size (2x2 pixels)
    width = 48,
    height = 48,
    periodic = false,
    samples_path = SAMPLES_PATH
})

print(string.format("Created %dx%d grid with %d patterns", 
                   maze_model.MX, maze_model.MY, maze_model.T))

seed = os.time() + 1
print(string.format("Running with seed %d...", seed))
success = maze_model:run(seed, -1)

if success then
    local filename = string.format("output/maze_demo_%d.png", seed)
    maze_model:save(filename)
    print(string.format("✓ Success! Saved to %s", filename))
else
    print("✗ Contradiction occurred")
end
print()

-- Example 3: Generate multiple variations
print("Example 3: Generate Multiple Variations (Rooms)")
print("-" .. string.rep("-", 40))

local rooms_model = SimpleTiledModel.new({
    name = "Rooms",
    width = 20,
    height = 20,
    periodic = false,
    tileset_path = TILESET_PATH
})

print(string.format("Generating 3 variations of %dx%d rooms...", 
                   rooms_model.MX, rooms_model.MY))

for i = 1, 3 do
    seed = os.time() + i
    success = rooms_model:run(seed, -1)
    
    if success then
        local filename = string.format("output/rooms_var%d_%d.png", i, seed)
        rooms_model:save(filename)
        print(string.format("  %d. ✓ Saved to %s", i, filename))
    else
        print(string.format("  %d. ✗ Contradiction", i))
    end
end
print()

print("===========================================")
print("Generation complete!")
print("Check the output/ directory for all generated images.")
print()
print("Available tilesets:")
print("  - Knots (5 tiles, subsets: Standard, Dense, Crossless, etc.)")
print("  - Rooms (9 tiles, dungeon-style layouts)")
print("  - Circles (8 tiles, circular patterns)")
print("  - Circuit (14 tiles, electronic circuit patterns)")
print("  - Castle (11 tiles, castle/map generation)")
print("  - Summer (36 tiles, terrain generation)")
print()
print("Available samples (for Overlapping Model):")
print("  - SimpleMaze, Knot, Rooms, Flowers, Mountains, Platformer, etc.")
print()
print("For more information, see the README or the C# reference at:")
print("  https://github.com/mxgmn/WaveFunctionCollapse")

