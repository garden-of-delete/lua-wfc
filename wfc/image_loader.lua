-- wfc/image_loader.lua
-- PNG/BMP image loading and saving using simple formats

local M = {}

-- Simple BMP loader (for testing)
-- This is a minimal implementation for WFC tilesets
function M.load_png(filename)
    -- First, let's try converting PNG to BMP using sips, then reading BMP
    local bmp_file = os.tmpname() .. ".bmp"
    
    -- Convert PNG to BMP using sips (macOS)
    local cmd = string.format('sips -s format bmp "%s" --out "%s" 2>/dev/null', filename, bmp_file)
    local result = os.execute(cmd)
    
    if not result then
        error("Failed to convert image: " .. filename .. " (is sips available?)")
    end
    
    -- Read BMP file
    local file = io.open(bmp_file, "rb")
    if not file then
        os.remove(bmp_file)
        error("Failed to open converted BMP file")
    end
    
    -- Read BMP header
    local bmp_data = file:read("*all")
    file:close()
    os.remove(bmp_file)
    
    -- Parse BMP header (simplified for 24-bit or 32-bit BMPs)
    local signature = bmp_data:sub(1, 2)
    if signature ~= "BM" then
        error("Invalid BMP file format")
    end
    
    local data_offset = string.unpack("I4", bmp_data, 11)
    local header_size = string.unpack("I4", bmp_data, 15)
    local width = string.unpack("I4", bmp_data, 19)
    local height_raw = string.unpack("i4", bmp_data, 23)  -- Signed integer
    local height = math.abs(height_raw)
    local top_down = height_raw < 0
    local bits_per_pixel = string.unpack("I2", bmp_data, 29)
    
    -- Calculate row padding (BMP rows are padded to 4-byte boundary)
    local bytes_per_pixel = bits_per_pixel / 8
    local row_size = math.floor((bits_per_pixel * width + 31) / 32) * 4
    
    local data = {}
    
    -- BMP can be stored bottom-to-top or top-to-bottom
    local y_start, y_end, y_step
    if top_down then
        y_start, y_end, y_step = 0, height - 1, 1
    else
        y_start, y_end, y_step = height - 1, 0, -1
    end
    
    for y = y_start, y_end, y_step do
        local row_offset = data_offset + y * row_size
        for x = 0, width - 1 do
            local pixel_offset = row_offset + x * bytes_per_pixel + 1
            
            -- BMP stores in BGR(A) format
            local b = string.byte(bmp_data, pixel_offset) or 0
            local g = string.byte(bmp_data, pixel_offset + 1) or 0
            local r = string.byte(bmp_data, pixel_offset + 2) or 0
            local a = 255
            if bytes_per_pixel == 4 and pixel_offset + 3 <= #bmp_data then
                a = string.byte(bmp_data, pixel_offset + 3) or 255
            end
            
            -- Convert to ARGB
            local argb = (a * 0x1000000) + (r * 0x10000) + (g * 0x100) + b
            table.insert(data, argb)
        end
    end
    
    return {
        data = data,
        width = width,
        height = height
    }
end

-- Save pixel data as PNG/BMP image
function M.save_png(data, width, height, filename)
    -- Create BMP file, then convert to PNG using sips
    local bmp_file = os.tmpname() .. ".bmp"
    
    -- Calculate row size (must be multiple of 4)
    local row_size = math.floor((24 * width + 31) / 32) * 4
    local pixel_data_size = row_size * height
    local file_size = 54 + pixel_data_size  -- 54 = BMP header size
    
    local file = io.open(bmp_file, "wb")
    if not file then
        error("Failed to create BMP file")
    end
    
    -- Write BMP header
    file:write("BM")  -- Signature
    file:write(string.pack("I4", file_size))  -- File size
    file:write(string.pack("I4", 0))  -- Reserved
    file:write(string.pack("I4", 54))  -- Data offset
    
    -- Write DIB header (BITMAPINFOHEADER)
    file:write(string.pack("I4", 40))  -- Header size
    file:write(string.pack("I4", width))  -- Width
    file:write(string.pack("I4", height))  -- Height
    file:write(string.pack("I2", 1))  -- Planes
    file:write(string.pack("I2", 24))  -- Bits per pixel
    file:write(string.pack("I4", 0))  -- Compression (none)
    file:write(string.pack("I4", pixel_data_size))  -- Image size
    file:write(string.pack("I4", 2835))  -- X pixels per meter
    file:write(string.pack("I4", 2835))  -- Y pixels per meter
    file:write(string.pack("I4", 0))  -- Colors in palette
    file:write(string.pack("I4", 0))  -- Important colors
    
    -- Write pixel data (bottom-to-top, BGR format)
    for y = height - 1, 0, -1 do
        for x = 0, width - 1 do
            local idx = x + y * width + 1
            local argb = data[idx]
            local r = math.floor(argb / 0x10000) % 0x100
            local g = math.floor(argb / 0x100) % 0x100
            local b = argb % 0x100
            
            file:write(string.char(b, g, r))
        end
        
        -- Add row padding
        local padding = row_size - (width * 3)
        for i = 1, padding do
            file:write(string.char(0))
        end
    end
    
    file:close()
    
    -- Convert BMP to PNG using sips with no interpolation
    -- Use -i flag to prevent interpolation/smoothing
    local cmd = string.format('sips -s format png -s formatOptions best "%s" --out "%s" 2>/dev/null', bmp_file, filename)
    local result = os.execute(cmd)
    os.remove(bmp_file)
    
    if not result then
        error("Failed to convert BMP to PNG: " .. filename)
    end
    
    return true
end

return M
