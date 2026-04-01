-- wfc/model.lua
-- Base Model class for Wave Function Collapse algorithm

local utils = require('wfc.utils')

local Model = {}
Model.__index = Model

-- Direction vectors: left, down, right, up (adjusted for 1-based indexing)
Model.DX = {-1, 0, 1, 0}
Model.DY = {0, 1, 0, -1}
Model.OPPOSITE = {3, 4, 1, 2}  -- Opposite directions (1-based)

-- Heuristic types
Model.HEURISTIC_ENTROPY = "entropy"
Model.HEURISTIC_MRV = "mrv"
Model.HEURISTIC_SCANLINE = "scanline"

function Model.new(width, height, n, periodic, heuristic)
    local self = setmetatable({}, Model)
    
    self.MX = width
    self.MY = height
    self.N = n or 3
    self.periodic = periodic or false
    self.heuristic = heuristic or Model.HEURISTIC_ENTROPY
    
    -- These will be set by subclasses
    self.T = 0  -- Number of patterns/tiles
    self.weights = nil
    self.propagator = nil
    
    -- Wave state
    self.wave = nil
    self.compatible = nil
    self.observed = nil
    
    -- Entropy tracking
    self.sumsOfOnes = nil
    self.sumsOfWeights = nil
    self.sumsOfWeightLogWeights = nil
    self.entropies = nil
    
    -- Stack for propagation (parallel arrays)
    self.stack_i = nil
    self.stack_t = nil
    self.stacksize = 0
    
    -- For scanline heuristic
    self.observedSoFar = 0
    
    return self
end

function Model:init()
    local wave_length = self.MX * self.MY
    
    -- Initialize wave (each cell has boolean array for each pattern)
    self.wave = {}
    self.compatible = {}
    
    for i = 1, wave_length do
        self.wave[i] = {}
        self.compatible[i] = {}
        for t = 1, self.T do
            self.wave[i][t] = true
            self.compatible[i][t] = {0, 0, 0, 0}  -- Counters for 4 directions
        end
    end
    
    self.observed = utils.array_2d(self.MX, self.MY, -1)
    
    -- Pre-calculate weight log weights
    self.weightLogWeights = {}
    self.sumOfWeights = 0
    self.sumOfWeightLogWeights = 0
    
    for t = 1, self.T do
        self.weightLogWeights[t] = self.weights[t] * math.log(self.weights[t])
        self.sumOfWeights = self.sumOfWeights + self.weights[t]
        self.sumOfWeightLogWeights = self.sumOfWeightLogWeights + self.weightLogWeights[t]
    end
    
    self.startingEntropy = math.log(self.sumOfWeights) - 
                          self.sumOfWeightLogWeights / self.sumOfWeights
    
    -- Initialize entropy arrays
    self.sumsOfOnes = {}
    self.sumsOfWeights = {}
    self.sumsOfWeightLogWeights = {}
    self.entropies = {}
    
    for i = 1, wave_length do
        self.sumsOfOnes[i] = 0
        self.sumsOfWeights[i] = 0
        self.sumsOfWeightLogWeights[i] = 0
        self.entropies[i] = 0
    end
    
    -- Initialize stack (parallel arrays to avoid per-ban table allocation)
    self.stack_i = {}
    self.stack_t = {}
    self.stacksize = 0

    self.distribution = {}
    for t = 1, self.T do
        self.distribution[t] = 0
    end
end

function Model:run(seed, limit)
    if not self.wave then
        self:init()
    end
    
    self:clear()
    local random = utils.create_random(seed)
    
    limit = limit or -1
    local iterations = 0
    
    while limit < 0 or iterations < limit do
        iterations = iterations + 1
        
        local node = self:next_unobserved_node(random)
        
        if node >= 0 then
            self:observe(node, random)
            local success = self:propagate()
            if not success then
                return false
            end
        else
            -- All nodes observed - extract final state
            for i = 1, #self.wave do
                for t = 1, self.T do
                    if self.wave[i][t] then
                        self.observed[i] = t
                        break
                    end
                end
            end
            return true
        end
    end
    
    return true
end

function Model:next_unobserved_node(random)
    if self.heuristic == Model.HEURISTIC_SCANLINE then
        for i = self.observedSoFar + 1, #self.wave do
            local x = (i - 1) % self.MX
            local y = math.floor((i - 1) / self.MX)
            
            if not self.periodic and (x + self.N > self.MX or y + self.N > self.MY) then
                -- Skip
            elseif self.sumsOfOnes[i] > 1 then
                self.observedSoFar = i
                return i
            end
        end
        return -1
    end
    
    -- Entropy or MRV heuristic
    local min = 1e10
    local argmin = -1
    
    for i = 1, #self.wave do
        local x = (i - 1) % self.MX
        local y = math.floor((i - 1) / self.MX)
        
        if not self.periodic and (x + self.N > self.MX or y + self.N > self.MY) then
            -- Skip boundary cells for non-periodic
        else
            local remaining_values = self.sumsOfOnes[i]
            local entropy = self.heuristic == Model.HEURISTIC_ENTROPY 
                           and self.entropies[i] 
                           or remaining_values
            
            if remaining_values > 1 and entropy <= min then
                local noise = 1e-6 * random.next()
                if entropy + noise < min then
                    min = entropy + noise
                    argmin = i
                end
            end
        end
    end
    
    return argmin
end

function Model:observe(node, random)
    local w = self.wave[node]
    local distribution = self.distribution

    -- Build distribution from current wave state
    for t = 1, self.T do
        distribution[t] = w[t] and self.weights[t] or 0.0
    end

    -- Select random pattern based on weights
    local r = utils.weighted_random(distribution, random.next())

    -- Ban all patterns except the selected one
    for t = 1, self.T do
        if w[t] and t ~= r then
            self:ban(node, t)
        end
    end
end

function Model:propagate()
    while self.stacksize > 0 do
        local i1 = self.stack_i[self.stacksize]
        local t1 = self.stack_t[self.stacksize]
        self.stacksize = self.stacksize - 1
        
        local x1 = (i1 - 1) % self.MX
        local y1 = math.floor((i1 - 1) / self.MX)
        
        -- Check all 4 directions
        for d = 1, 4 do
            local x2 = x1 + Model.DX[d]
            local y2 = y1 + Model.DY[d]
            
            -- Handle boundaries
            if not self.periodic then
                if x2 < 0 or y2 < 0 or x2 + self.N > self.MX or y2 + self.N > self.MY then
                    goto continue
                end
            end
            
            -- Wrap for periodic
            if x2 < 0 then
                x2 = x2 + self.MX
            elseif x2 >= self.MX then
                x2 = x2 - self.MX
            end
            
            if y2 < 0 then
                y2 = y2 + self.MY
            elseif y2 >= self.MY then
                y2 = y2 - self.MY
            end
            
            local i2 = x2 + y2 * self.MX + 1  -- Convert to 1-based index
            local p = self.propagator[d][t1]
            local compat = self.compatible[i2]
            
            -- Propagate constraints
            for l = 1, #p do
                local t2 = p[l]
                local comp = compat[t2]
                
                comp[d] = comp[d] - 1
                if comp[d] == 0 then
                    self:ban(i2, t2)
                end
            end
            
            ::continue::
        end
    end
    
    -- Check if we have a contradiction (all patterns banned at some cell)
    return self.sumsOfOnes[1] > 0
end

function Model:ban(i, t)
    self.wave[i][t] = false
    
    local comp = self.compatible[i][t]
    for d = 1, 4 do
        comp[d] = 0
    end
    
    -- Add to propagation stack
    self.stacksize = self.stacksize + 1
    self.stack_i[self.stacksize] = i
    self.stack_t[self.stacksize] = t
    
    -- Update entropy tracking
    self.sumsOfOnes[i] = self.sumsOfOnes[i] - 1
    self.sumsOfWeights[i] = self.sumsOfWeights[i] - self.weights[t]
    self.sumsOfWeightLogWeights[i] = self.sumsOfWeightLogWeights[i] - self.weightLogWeights[t]
    
    local sum = self.sumsOfWeights[i]
    if sum > 0 then
        self.entropies[i] = math.log(sum) - self.sumsOfWeightLogWeights[i] / sum
    else
        self.entropies[i] = 0
    end
end

function Model:clear()
    local wave_length = self.MX * self.MY
    
    for i = 1, wave_length do
        for t = 1, self.T do
            self.wave[i][t] = true
            
            -- Initialize compatible counts from propagator
            for d = 1, 4 do
                self.compatible[i][t][d] = #self.propagator[Model.OPPOSITE[d]][t]
            end
        end
        
        self.sumsOfOnes[i] = self.T
        self.sumsOfWeights[i] = self.sumOfWeights
        self.sumsOfWeightLogWeights[i] = self.sumOfWeightLogWeights
        self.entropies[i] = self.startingEntropy
        self.observed[i] = -1
    end
    
    self.observedSoFar = 0
    
    -- Handle ground constraint if needed (subclass can override)
    if self.ground then
        self:apply_ground()
    end
end

function Model:apply_ground()
    -- Override in subclass if ground support is needed
end

-- Save method - must be implemented by subclasses
function Model:save(filename)
    error("save() must be implemented by subclass")
end

return Model

