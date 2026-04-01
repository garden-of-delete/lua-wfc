#!/usr/local/bin/lua
-- Test OverlappingModel with simple sample images

package.path = package.path .. ";./wfc/?.lua"

local OverlappingModel = require('overlapping_model')

print("Testing OverlappingModel with sample images")
print("=" .. string.rep("=", 50))
print()

-- Test with SimpleMaze sample
local samples = {
    {name = "SimpleMaze", N = 2, size = 48},
    {name = "Knot", N = 3, size = 48, periodic = true},
}

for _, config in ipairs(samples) do
    print(string.format("Testing: %s (N=%d, size=%d)", config.name, config.N, config.size))
    
    local model = OverlappingModel.new({
        name = config.name,
        N = config.N,
        width = config.size,
        height = config.size,
        periodic = config.periodic or false,
        samples_path = "samples"
    })
    
    print(string.format("  Model created: %dx%d grid, %d patterns", 
                       model.MX, model.MY, model.T))
    
    -- Run generation
    local seed = 12345
    print(string.format("  Running with seed %d...", seed))
    local success = model:run(seed, -1)
    
    if success then
        local output_file = string.format("output/%s_overlapping_%d.png", 
                                         config.name:lower(), seed)
        model:save(output_file)
        print(string.format("  ✓ Success! Saved to %s", output_file))
    else
        print("  ✗ Contradiction occurred")
    end
    print()
end

print("=" .. string.rep("=", 50))
print("Check output/ directory for generated images")

