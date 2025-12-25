// SuperCollider OSC Receiver Test
// Run this ENTIRE code block in SuperCollider to receive OSC from Lua

// Boot server if not already running
s.waitForBoot({
    "Server booted and ready!".postln;
});

// Define a simple synth to test with
(
SynthDef(\testNote, {
    arg freq = 440, amp = 0.3, dur = 0.25;
    var sig, env;
    env = EnvGen.kr(Env.perc(0.01, dur), doneAction: 2);
    sig = SinOsc.ar(freq) * env * amp;
    Out.ar(0, sig ! 2);  // stereo output
}).add;
)

// Set up OSC responders to listen for messages from Lua
(
// Responder for /note messages
OSCdef(\noteListener, {
    arg msg, time, addr, recvPort;
    var midiNote, duration, velocity;
    
    midiNote = msg[1];
    duration = msg[2];
    velocity = msg[3];
    
    "Received /note: midi=%, dur=%, vel=%".format(midiNote, duration, velocity).postln;
    
    // Play the note
    Synth(\testNote, [
        \freq, midiNote.midicps,
        \dur, duration,
        \amp, velocity
    ]);
}, '/note');

// Responder for /status messages (just report)
OSCdef(\statusListener, {
    arg msg, time, addr, recvPort;
    "Received /status request".postln;
    "Server is running on port %".format(NetAddr.langPort).postln;
}, '/status');

"✓ OSC receivers ready!".postln;
"  Listening for /note and /status messages".postln;
"  Server listening on port: %".format(NetAddr.langPort).postln;
"".postln;
"Run your Lua script: lua send_to_sc.lua".postln;
)

// To stop all sounds:
// s.freeAll;

// To stop receiving:
// OSCdef(\noteListener).free;
// OSCdef(\statusListener).free;

// To see what port SC is listening on:
// NetAddr.langPort;

