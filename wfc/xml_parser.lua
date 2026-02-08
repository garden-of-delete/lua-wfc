-- wfc/xml_parser.lua
-- Simple XML parser for WFC tileset definitions

local M = {}

-- Parse a simple XML file into a Lua table structure
function M.parse_file(filename)
    local file = io.open(filename, "r")
    if not file then
        error("Cannot open XML file: " .. filename)
    end
    
    local content = file:read("*all")
    file:close()
    
    return M.parse_string(content)
end

-- Parse XML string - improved version
function M.parse_string(xml)
    -- Remove XML declaration and comments
    xml = xml:gsub("<%?xml[^%?>]*%?>", "")
    xml = xml:gsub("<!%-%-.-%%>", "")
    
    local root = nil
    local stack = {}
    local pos = 1
    
    while pos <= #xml do
        -- Find next tag
        local tag_start_pos = string.find(xml, "<", pos, true)
        if not tag_start_pos then break end
        
        local tag_end_pos = string.find(xml, ">", tag_start_pos, true)
        if not tag_end_pos then break end
        
        local tag_content = string.sub(xml, tag_start_pos + 1, tag_end_pos - 1)
        
        -- Check if it's a closing tag
        if string.sub(tag_content, 1, 1) == "/" then
            local tag_name = string.match(tag_content, "/(%w+)")
            if #stack > 0 and stack[#stack].name == tag_name then
                table.remove(stack)
            end
        -- Check if it's a self-closing tag
        elseif string.sub(tag_content, -1) == "/" then
            local tag_name = string.match(tag_content, "(%w+)")
            local element = {
                name = tag_name,
                attributes = {},
                children = {},
                text = ""
            }
            
            -- Parse attributes
            for attr_name, attr_value in string.gmatch(tag_content, '(%w+)%s*=%s*"([^"]*)"') do
                element.attributes[attr_name] = attr_value
            end
            
            if #stack > 0 then
                table.insert(stack[#stack].children, element)
            else
                root = element
            end
        -- Opening tag
        else
            local tag_name = string.match(tag_content, "(%w+)")
            local element = {
                name = tag_name,
                attributes = {},
                children = {},
                text = ""
            }
            
            -- Parse attributes
            for attr_name, attr_value in string.gmatch(tag_content, '(%w+)%s*=%s*"([^"]*)"') do
                element.attributes[attr_name] = attr_value
            end
            
            if #stack > 0 then
                table.insert(stack[#stack].children, element)
            else
                root = element
            end
            table.insert(stack, element)
        end
        
        pos = tag_end_pos + 1
    end
    
    return root
end

-- Get attribute value with default
function M.get_attr(element, name, default)
    if not element or not element.attributes then
        return default
    end
    local value = element.attributes[name]
    if value == nil then
        return default
    end
    return value
end

-- Get typed attribute value
function M.get_attr_typed(element, name, default)
    local value = M.get_attr(element, name, nil)
    if value == nil then
        return default
    end
    
    -- Try to convert to appropriate type
    if value == "true" or value == "True" then
        return true
    elseif value == "false" or value == "False" then
        return false
    elseif tonumber(value) then
        return tonumber(value)
    else
        return value
    end
end

-- Find all children with a given name
function M.find_children(element, name)
    local result = {}
    if not element or not element.children then
        return result
    end
    
    for _, child in ipairs(element.children) do
        if child.name == name then
            table.insert(result, child)
        end
    end
    return result
end

-- Find first child with a given name
function M.find_child(element, name)
    if not element or not element.children then
        return nil
    end
    
    for _, child in ipairs(element.children) do
        if child.name == name then
            return child
        end
    end
    return nil
end

return M
