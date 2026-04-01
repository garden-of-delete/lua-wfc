#!/usr/local/bin/lua
-- Test SimpleTiledModel with Knots Standard subset

package.path = package.path .. ";./wfc/?.lua"

local SimpleTiledModel = require('simple_tiled_model')

print("Testing SimpleTiledModel with Knots Standard subset")
print("=" .. string.rep("=", 50))
print()

-- Create model
local model = SimpleTiledModel.new({
    name = "Knots",
    subset = "Standard",  -- corner, cross, empty, line
    width = 24,
    height = 24,
    periodic = true,
    tileset_path = "tilesets"
})

print(string.format("Model created: %dx%d grid, %d tiles, periodic=%s", 
                   model.MX, model.MY, model.T, tostring(model.periodic)))
print()

-- Run with multiple seeds to test
local seeds = {12345, 67890, 11111}
local success_count = 0

for i, seed in ipairs(seeds) do
    print(string.format("Run %d with seed %d...", i, seed))
    local success = model:run(seed, -1)
    
    if success then
        local output_file = string.format("output/knots_standard_%d.png", seed)
        model:save(output_file)
        print(string.format("  ✓ Success! Saved to %s", output_file))
        success_count = success_count + 1
    else
        print("  ✗ Contradiction occurred")
    end
    print()
end

print("=" .. string.rep("=", 50))
print(string.format("Results: %d/%d successful generations", success_count, #seeds))
print()
print("Check output/ directory for generated images")

