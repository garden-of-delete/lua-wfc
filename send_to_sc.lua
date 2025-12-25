#!/usr/local/bin/lua
-- Send OSC messages to SuperCollider server
-- Make sure SC server is running on port 57110

local losc = require('losc')
local plugin = require('losc.plugins.udp-socket')

-- Create OSC instance with UDP plugin
local osc_client = losc.new()
osc_client:use(plugin.new())

-- SuperCollider language (sclang) settings
-- Use 57120 for sclang OSC responders
-- Use 57110 for direct scsynth commands
local host = "127.0.0.1"
local port = 57120  -- Changed from 57110 to 57120 for OSCdef handlers

print("Sending OSC to SuperCollider at " .. host .. ":" .. port)
print("")

-- Example 1: Send a simple /notify message (SC status request)
print("1. Sending /status request...")
local status_msg = losc.new_message("/status")
local ok, err = osc_client:send(status_msg, host, port)
if ok then
    print("   ✓ Status request sent")
else
    print("   ✗ Error: " .. tostring(err))
end

-- Example 2: Send a note message with parameters
print("2. Sending /note message [60, 0.25, 0.3]...")
local note_msg = losc.new_message{
    address = "/note",
    types = "fff",  -- 3 floats
    60.0,           -- MIDI note number
    0.25,           -- duration
    0.3             -- velocity/amplitude
}
ok, err = osc_client:send(note_msg, host, port)
if ok then
    print("   ✓ Note message sent")
else
    print("   ✗ Error: " .. tostring(err))
end

-- Example 3: Send to a synth (typical SC pattern)
print("3. Sending /s_new (create synth)...")
local synth_msg = losc.new_message{
    address = "/s_new",
    types = "sifif",    -- string, int, float, int, float
    "default",          -- synth name
    -1,                 -- node ID (-1 = auto assign)
    0.0,                -- add action (0 = head)
    1,                  -- target (1 = default group)
    440.0               -- freq parameter
}
ok, err = osc_client:send(synth_msg, host, port)
if ok then
    print("   ✓ Synth creation message sent")
else
    print("   ✗ Error: " .. tostring(err))
end

-- Example 4: Send multiple notes in sequence
print("4. Sending sequence of notes...")
local notes = {60, 62, 64, 65, 67}
for i, note in ipairs(notes) do
    local msg = losc.new_message{
        address = "/note",
        types = "fff",
        note,
        0.15,  -- duration
        0.5    -- velocity
    }
    ok, err = osc_client:send(msg, host, port)
    if ok then
        print(string.format("   ✓ Note %d sent (MIDI %d)", i, note))
    else
        print(string.format("   ✗ Note %d error: %s", i, tostring(err)))
    end
    -- Small delay between notes (using busy wait - not ideal but simple)
    local delay = os.clock() + 0.2
    while os.clock() < delay do end
end

print("")
print("✓ All messages sent!")
print("")
print("Note: If you don't hear anything, make sure:")
print("  - SC server is running (Server.default.boot)")
print("  - You have a synth that responds to these messages")
print("  - Server is listening on port 57110")

