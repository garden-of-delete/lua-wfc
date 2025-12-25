#!/bin/bash
# Environment setup for Lua 5.3 + losc project

# Add Lua 5.3 to PATH (prioritize over Homebrew's Lua 5.4)
export PATH="/usr/local/bin:$PATH"

# Set up LuaRocks paths for local packages
eval "$(/usr/local/bin/luarocks path)"

echo "✓ Lua environment configured:"
echo "  Lua version: $(/usr/local/bin/lua -v)"
echo "  LuaRocks: $(/usr/local/bin/luarocks --version | head -1)"
echo "  Packages: losc (OSC library for Lua)"
echo ""
echo "You can now run Lua scripts with: lua your_script.lua"

