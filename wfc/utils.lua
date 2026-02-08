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

-- Seeded random number generator
function M.create_random(seed)
    math.randomseed(seed)
    return {
        next = function()
            return math.random()
        end,
        next_int = function(max)
            return math.random(0, max - 1)
        end
    }
end

return M

