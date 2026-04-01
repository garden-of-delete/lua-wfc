-- wfc/utils.lua
-- Utility functions for Wave Function Collapse

local M = {}

-- Select a random index based on weighted probabilities
-- weights: array of weights/probabilities
-- r: random number in [0, 1)
-- Returns: index (1-based) of selected item
function M.weighted_random(weights, r)
    local sum = 0
    for i = 1, #weights do
        sum = sum + weights[i]
    end
    
    local threshold = r * sum
    local partial_sum = 0
    
    for i = 1, #weights do
        partial_sum = partial_sum + weights[i]
        if partial_sum >= threshold then
            return i
        end
    end
    
    return 1
end

-- Create a 2D array initialized with a value
-- width, height: dimensions
-- value: initial value (can be nil, a value, or a function that returns a value)
function M.array_2d(width, height, value)
    local arr = {}
    for i = 1, width * height do
        if type(value) == "function" then
            arr[i] = value()
        else
            arr[i] = value
        end
    end
    return arr
end

-- Deep copy a table/array
function M.deep_copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do
        res[M.deep_copy(k, s)] = M.deep_copy(v, s)
    end
    return setmetatable(res, getmetatable(obj))
end

-- Isolated seeded random number generator (xorshift64)
-- Avoids polluting global math.random state
function M.create_random(seed)
    -- Ensure seed is a non-zero integer
    local state = seed
    if state == 0 then state = 1 end

    local function xorshift64()
        -- Lua 5.3 has native 64-bit integers
        state = state ~ (state << 13)
        state = state ~ (state >> 7)
        state = state ~ (state << 17)
        return state
    end

    return {
        next = function()
            -- Return float in [0, 1)
            -- Right-shift by 11 to get 53 bits (double precision mantissa)
            -- Lua 5.3 >> is logical shift, always fills with zeros, so result is non-negative
            local v = xorshift64() >> 11
            return v * (1.0 / (1 << 53))
        end,
        next_int = function(max)
            local v = xorshift64() >> 1  -- logical shift makes it non-negative
            return v % max
        end
    }
end

return M

