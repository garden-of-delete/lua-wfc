-- wfc/overlapping_model.lua
-- Overlapping Model for Wave Function Collapse

local Model = require('wfc.model')
local image_loader = require('wfc.image_loader')
local utils = require('wfc.utils')

local OverlappingModel = setmetatable({}, {__index = Model})
OverlappingModel.__index = OverlappingModel

function OverlappingModel.new(config)
    local name = config.name
    local n = config.N or 3
    local width = config.width or 48
    local height = config.height or 48
    local periodic_input = config.periodic_input ~= false  -- Default true
    local periodic = config.periodic or false
    local symmetry = config.symmetry or 8
    local ground = config.ground or false
    local heuristic = config.heuristic or Model.HEURISTIC_ENTROPY
    local samples_path = config.samples_path or "samples"
    
    local self = setmetatable(Model.new(width, height, n, periodic, heuristic), OverlappingModel)
    
    self.ground = ground
    self.patterns = {}
    self.colors = {}
    
    -- Load sample image
    local sample_file = string.format("%s/%s.png", samples_path, name)
    local img = image_loader.load_png(sample_file)
    local bitmap = img.data
    local SX = img.width
    local SY = img.height
    
    -- Build color palette
    local sample = {}
    for i = 1, #bitmap do
        local color = bitmap[i]
        local k = nil
        for j = 1, #self.colors do
            if self.colors[j] == color then
                k = j
                break
            end
        end
        if not k then
            table.insert(self.colors, color)
            k = #self.colors
        end
        sample[i] = k - 1  -- 0-based for easier math
    end
    
    local C = #self.colors
    
    -- Helper functions for pattern manipulation
    local function pattern(f, N)
        local result = {}
        for y = 0, N - 1 do
            for x = 0, N - 1 do
                result[x + y * N + 1] = f(x, y)
            end
        end
        return result
    end
    
    local function rotate(p, N)
        return pattern(function(x, y) return p[N - 1 - y + x * N + 1] end, N)
    end
    
    local function reflect(p, N)
        return pattern(function(x, y) return p[N - 1 - x + y * N + 1] end, N)
    end
    
    local function hash(p, C)
        local result = 0
        local power = 1
        for i = #p, 1, -1 do
            result = result + p[i] * power
            power = power * C
        end
        return result
    end
    
    -- Extract patterns from sample
    local pattern_indices = {}
    local weight_list = {}
    
    local xmax = periodic_input and SX or SX - n + 1
    local ymax = periodic_input and SY or SY - n + 1
    
    for y = 0, ymax - 1 do
        for x = 0, xmax - 1 do
            local ps = {}
            
            -- Extract base pattern
            ps[1] = pattern(function(dx, dy) 
                return sample[((x + dx) % SX) + ((y + dy) % SY) * SX + 1]
            end, n)
            
            -- Generate symmetric versions
            ps[2] = reflect(ps[1], n)
            ps[3] = rotate(ps[1], n)
            ps[4] = reflect(ps[3], n)
            ps[5] = rotate(ps[3], n)
            ps[6] = reflect(ps[5], n)
            ps[7] = rotate(ps[5], n)
            ps[8] = reflect(ps[7], n)
            
            -- Add patterns up to symmetry count
            for k = 1, symmetry do
                local p = ps[k]
                local h = hash(p, C)
                
                if pattern_indices[h] then
                    weight_list[pattern_indices[h]] = weight_list[pattern_indices[h]] + 1
                else
                    pattern_indices[h] = #weight_list + 1
                    table.insert(weight_list, 1.0)
                    table.insert(self.patterns, p)
                end
            end
        end
    end
    
    self.weights = weight_list
    self.T = #self.weights
    
    -- Build propagator (adjacency rules)
    local function agrees(p1, p2, dx, dy, N)
        local xmin = dx < 0 and 0 or dx
        local xmax = dx < 0 and dx + N or N
        local ymin = dy < 0 and 0 or dy
        local ymax = dy < 0 and dy + N or N
        
        for y = ymin, ymax - 1 do
            for x = xmin, xmax - 1 do
                if p1[x + N * y + 1] ~= p2[x - dx + N * (y - dy) + 1] then
                    return false
                end
            end
        end
        return true
    end
    
    self.propagator = {{}, {}, {}, {}}
    for d = 1, 4 do
        for t = 1, self.T do
            self.propagator[d][t] = {}
            for t2 = 1, self.T do
                if agrees(self.patterns[t], self.patterns[t2], Model.DX[d], Model.DY[d], n) then
                    table.insert(self.propagator[d][t], t2)
                end
            end
        end
    end
    
    return self
end

function OverlappingModel:save(filename)
    local bitmap = {}
    
    if self.observed[1] >= 0 then
        -- Fully collapsed - extract final image
        for y = 0, self.MY - 1 do
            local dy = y < self.MY - self.N + 1 and 0 or self.N - 1
            for x = 0, self.MX - 1 do
                local dx = x < self.MX - self.N + 1 and 0 or self.N - 1
                local pattern_idx = self.observed[x - dx + (y - dy) * self.MX + 1]
                local color_idx = self.patterns[pattern_idx][dx + dy * self.N + 1]
                bitmap[x + y * self.MX + 1] = self.colors[color_idx + 1]
            end
        end
    else
        -- Partially collapsed - average colors
        for i = 1, #self.wave do
            local contributors = 0
            local r, g, b = 0, 0, 0
            local x = (i - 1) % self.MX
            local y = math.floor((i - 1) / self.MX)
            
            for dy = 0, self.N - 1 do
                for dx = 0, self.N - 1 do
                    local sx = x - dx
                    if sx < 0 then sx = sx + self.MX end
                    
                    local sy = y - dy
                    if sy < 0 then sy = sy + self.MY end
                    
                    local s = sx + sy * self.MX + 1
                    if not self.periodic and (sx + self.N > self.MX or sy + self.N > self.MY) then
                        -- Skip
                    else
                        for t = 1, self.T do
                            if self.wave[s][t] then
                                contributors = contributors + 1
                                local color_idx = self.patterns[t][dx + dy * self.N + 1]
                                local argb = self.colors[color_idx + 1]
                                r = r + math.floor(argb / 0x10000) % 0x100
                                g = g + math.floor(argb / 0x100) % 0x100
                                b = b + argb % 0x100
                            end
                        end
                    end
                end
            end
            
            if contributors > 0 then
                bitmap[i] = 0xFF000000 + 
                           math.floor(r / contributors) * 0x10000 + 
                           math.floor(g / contributors) * 0x100 + 
                           math.floor(b / contributors)
            else
                bitmap[i] = 0xFF000000
            end
        end
    end
    
    image_loader.save_png(bitmap, self.MX, self.MY, filename)
end

function OverlappingModel:apply_ground()
    -- Apply ground constraint: bottom row should be ground patterns
    for x = 0, self.MX - 1 do
        -- Ban all but the last pattern on bottom row (assumes last pattern is "ground")
        for t = 1, self.T - 1 do
            self:ban(x + (self.MY - 1) * self.MX + 1, t)
        end
        
        -- Ban last pattern (ground) from all other rows
        for y = 0, self.MY - 2 do
            self:ban(x + y * self.MX + 1, self.T)
        end
    end
    self:propagate()
end

return OverlappingModel

