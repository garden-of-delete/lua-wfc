-- wfc/simple_tiled_model.lua
-- Simple Tiled Model for Wave Function Collapse

local Model = require('wfc.model')
local xml_parser = require('wfc.xml_parser')
local image_loader = require('wfc.image_loader')
local utils = require('wfc.utils')

local SimpleTiledModel = setmetatable({}, {__index = Model})
SimpleTiledModel.__index = SimpleTiledModel

function SimpleTiledModel.new(config)
    local name = config.name
    local subset_name = config.subset
    local width = config.width or 24
    local height = config.height or 24
    local periodic = config.periodic or false
    local black_background = config.black_background or false
    local heuristic = config.heuristic or Model.HEURISTIC_ENTROPY
    local tileset_path = config.tileset_path or "tilesets"
    
    local self = setmetatable(Model.new(width, height, 1, periodic, heuristic), SimpleTiledModel)
    
    self.black_background = black_background
    self.tiles = {}
    self.tilenames = {}
    self.tilesize = 0
    
    -- Load tileset XML
    local xml_file = tileset_path .. "/" .. name .. ".xml"
    local xroot = xml_parser.parse_file(xml_file)
    
    local unique = xml_parser.get_attr_typed(xroot, "unique", false)
    
    -- Load subset if specified
    local subset = nil
    if subset_name then
        local subsets_elem = xml_parser.find_child(xroot, "subsets")
        if subsets_elem then
            local subset_elems = xml_parser.find_children(subsets_elem, "subset")
            for _, sub in ipairs(subset_elems) do
                if xml_parser.get_attr(sub, "name") == subset_name then
                    subset = {}
                    local tile_elems = xml_parser.find_children(sub, "tile")
                    for _, t in ipairs(tile_elems) do
                        subset[xml_parser.get_attr(t, "name")] = true
                    end
                    break
                end
            end
        end
    end
    
    -- Helper functions for tile rotations/reflections
    local function rotate_tile(tile_data, size)
        local result = {}
        for y = 0, size - 1 do
            for x = 0, size - 1 do
                local src_idx = (size - 1 - y) + x * size + 1
                local dst_idx = x + y * size + 1
                result[dst_idx] = tile_data[src_idx]
            end
        end
        return result
    end
    
    local function reflect_tile(tile_data, size)
        local result = {}
        for y = 0, size - 1 do
            for x = 0, size - 1 do
                local src_idx = (size - 1 - x) + y * size + 1
                local dst_idx = x + y * size + 1
                result[dst_idx] = tile_data[src_idx]
            end
        end
        return result
    end
    
    local weight_list = {}
    local action = {}
    local first_occurrence = {}
    
    -- Load tiles
    local tiles_elem = xml_parser.find_child(xroot, "tiles")
    local tile_elems = xml_parser.find_children(tiles_elem, "tile")
    
    for _, xtile in ipairs(tile_elems) do
        local tilename = xml_parser.get_attr(xtile, "name")
        
        if not subset or subset[tilename] then
            local sym = xml_parser.get_attr(xtile, "symmetry", "X")
            local cardinality, a, b
            
            -- Define symmetry operations
            if sym == "L" then
                cardinality = 4
                a = function(i) return (i % 4) + 1 end
                b = function(i) return (i % 2 == 1) and i + 1 or i - 1 end
            elseif sym == "T" then
                cardinality = 4
                a = function(i) return (i % 4) + 1 end
                b = function(i) return (i % 2 == 1) and i or (4 - i + 2) end
            elseif sym == "I" then
                cardinality = 2
                a = function(i) return 3 - i end
                b = function(i) return i end
            elseif sym == "\\" then
                cardinality = 2
                a = function(i) return 3 - i end
                b = function(i) return 3 - i end
            elseif sym == "F" then
                cardinality = 8
                a = function(i) 
                    if i <= 4 then
                        return (i % 4) + 1
                    else
                        return ((i - 4 - 1) % 4) + 1 + 4
                    end
                end
                b = function(i) return (i <= 4) and i + 4 or i - 4 end
            else  -- X
                cardinality = 1
                a = function(i) return i end
                b = function(i) return i end
            end
            
            local T = #action + 1
            first_occurrence[tilename] = T
            
            -- Build action map for symmetries
            local map = {}
            for t = 1, cardinality do
                map[t] = {}
                map[t][1] = t
                map[t][2] = a(t)
                map[t][3] = a(a(t))
                map[t][4] = a(a(a(t)))
                map[t][5] = b(t)
                map[t][6] = b(a(t))
                map[t][7] = b(a(a(t)))
                map[t][8] = b(a(a(a(t))))
                
                for s = 1, 8 do
                    map[t][s] = map[t][s] + T - 1
                end
                
                table.insert(action, map[t])
            end
            
            -- Load tile images
            if unique then
                for t = 1, cardinality do
                    local tile_file = string.format("%s/%s/%s %d.png", 
                                                   tileset_path, name, tilename, t - 1)
                    local img = image_loader.load_png(tile_file)
                    table.insert(self.tiles, img.data)
                    table.insert(self.tilenames, string.format("%s %d", tilename, t - 1))
                    self.tilesize = img.width
                end
            else
                local tile_file = string.format("%s/%s/%s.png", tileset_path, name, tilename)
                local img = image_loader.load_png(tile_file)
                local base_tile_idx = #self.tiles + 1
                table.insert(self.tiles, img.data)
                table.insert(self.tilenames, tilename .. " 0")
                self.tilesize = img.width
                
                for t = 2, cardinality do
                    if t <= 4 then
                        table.insert(self.tiles, rotate_tile(self.tiles[base_tile_idx + t - 2], self.tilesize))
                    else
                        table.insert(self.tiles, reflect_tile(self.tiles[base_tile_idx + t - 5], self.tilesize))
                    end
                    table.insert(self.tilenames, string.format("%s %d", tilename, t - 1))
                end
            end
            
            -- Add weights
            local weight = xml_parser.get_attr_typed(xtile, "weight", 1.0)
            for t = 1, cardinality do
                table.insert(weight_list, weight)
            end
        end
    end
    
    self.T = #action
    self.weights = weight_list
    
    -- Build propagator from neighbor rules
    self.propagator = {{}, {}, {}, {}}
    local dense_propagator = {{}, {}, {}, {}}
    
    for d = 1, 4 do
        for t = 1, self.T do
            dense_propagator[d][t] = {}
            for t2 = 1, self.T do
                dense_propagator[d][t][t2] = false
            end
        end
    end
    
    -- Parse neighbor rules
    local neighbors_elem = xml_parser.find_child(xroot, "neighbors")
    local neighbor_elems = xml_parser.find_children(neighbors_elem, "neighbor")
    
    for _, xneighbor in ipairs(neighbor_elems) do
        local left_str = xml_parser.get_attr(xneighbor, "left")
        local right_str = xml_parser.get_attr(xneighbor, "right")
        
        local left_parts = {}
        for part in left_str:gmatch("%S+") do
            table.insert(left_parts, part)
        end
        local right_parts = {}
        for part in right_str:gmatch("%S+") do
            table.insert(right_parts, part)
        end
        
        -- Skip if subset filters out these tiles
        if subset and (not subset[left_parts[1]] or not subset[right_parts[1]]) then
            goto continue_neighbor
        end
        
        -- Check that both tiles exist in first_occurrence
        if not first_occurrence[left_parts[1]] or not first_occurrence[right_parts[1]] then
            goto continue_neighbor
        end
        
        local left_idx = #left_parts == 1 and 1 or (tonumber(left_parts[2]) + 1)
        local right_idx = #right_parts == 1 and 1 or (tonumber(right_parts[2]) + 1)
        
        local L = action[first_occurrence[left_parts[1]]][left_idx]
        local D = action[L][2]  -- 90° rotation (index 2 in 1-based = index 1 in C# 0-based)
        local R = action[first_occurrence[right_parts[1]]][right_idx]
        local U = action[R][2]
        
        -- Set adjacency rules (accounting for all symmetries)
        -- C# uses: densePropagator[0][R][L], action[R][6], action[L][6], etc.
        -- In 1-based: action[R][7] = C# action[R][6]
        dense_propagator[1][R][L] = true
        dense_propagator[1][action[R][7]][action[L][7]] = true
        dense_propagator[1][action[L][5]][action[R][5]] = true
        dense_propagator[1][action[L][3]][action[R][3]] = true
        
        dense_propagator[2][U][D] = true
        dense_propagator[2][action[D][7]][action[U][7]] = true
        dense_propagator[2][action[U][5]][action[D][5]] = true
        dense_propagator[2][action[D][3]][action[U][3]] = true
        
        ::continue_neighbor::
    end
    
    -- Fill opposite directions
    for t2 = 1, self.T do
        for t1 = 1, self.T do
            dense_propagator[3][t2][t1] = dense_propagator[1][t1][t2]
            dense_propagator[4][t2][t1] = dense_propagator[2][t1][t2]
        end
    end
    
    -- Convert dense to sparse propagator
    for d = 1, 4 do
        for t = 1, self.T do
            self.propagator[d][t] = {}
            for t2 = 1, self.T do
                if dense_propagator[d][t][t2] then
                    table.insert(self.propagator[d][t], t2)
                end
            end
        end
    end
    
    return self
end

function SimpleTiledModel:save(filename)
    local bitmap_data = {}
    local output_width = self.MX * self.tilesize
    local output_height = self.MY * self.tilesize
    
    -- Initialize bitmap
    for i = 1, output_width * output_height do
        bitmap_data[i] = 0xFF000000  -- Black with full alpha
    end
    
    if self.observed[1] >= 0 then
        -- Fully collapsed - render tiles
        for y = 0, self.MY - 1 do
            for x = 0, self.MX - 1 do
                local tile_idx = self.observed[x + y * self.MX + 1]
                local tile = self.tiles[tile_idx]
                
                for dy = 0, self.tilesize - 1 do
                    for dx = 0, self.tilesize - 1 do
                        local out_x = x * self.tilesize + dx
                        local out_y = y * self.tilesize + dy
                        local out_idx = out_x + out_y * output_width + 1
                        local tile_idx_sub = dx + dy * self.tilesize + 1
                        bitmap_data[out_idx] = tile[tile_idx_sub]
                    end
                end
            end
        end
    else
        -- Partially collapsed - show superposition (average colors)
        for i = 1, #self.wave do
            local x = (i - 1) % self.MX
            local y = math.floor((i - 1) / self.MX)
            
            if self.black_background and self.sumsOfOnes[i] == self.T then
                -- Fully uncollapsed - show black
                for yt = 0, self.tilesize - 1 do
                    for xt = 0, self.tilesize - 1 do
                        local out_idx = (x * self.tilesize + xt) + 
                                       (y * self.tilesize + yt) * output_width + 1
                        bitmap_data[out_idx] = 0xFF000000
                    end
                end
            else
                local w = self.wave[i]
                local normalization = 1.0 / self.sumsOfWeights[i]
                
                for yt = 0, self.tilesize - 1 do
                    for xt = 0, self.tilesize - 1 do
                        local idi = (x * self.tilesize + xt) + 
                                   (y * self.tilesize + yt) * output_width + 1
                        local r, g, b = 0, 0, 0
                        
                        for t = 1, self.T do
                            if w[t] then
                                local argb = self.tiles[t][xt + yt * self.tilesize + 1]
                                r = r + (math.floor(argb / 0x10000) % 0x100) * self.weights[t] * normalization
                                g = g + (math.floor(argb / 0x100) % 0x100) * self.weights[t] * normalization
                                b = b + (argb % 0x100) * self.weights[t] * normalization
                            end
                        end
                        
                        bitmap_data[idi] = 0xFF000000 + 
                                          math.floor(r) * 0x10000 + 
                                          math.floor(g) * 0x100 + 
                                          math.floor(b)
                    end
                end
            end
        end
    end
    
    image_loader.save_png(bitmap_data, output_width, output_height, filename)
end

function SimpleTiledModel:text_output()
    local result = {}
    for y = 0, self.MY - 1 do
        local line = {}
        for x = 0, self.MX - 1 do
            table.insert(line, self.tilenames[self.observed[x + y * self.MX + 1]])
        end
        table.insert(result, table.concat(line, ", "))
    end
    return table.concat(result, "\n")
end

return SimpleTiledModel

