# Roadmap

## The line

Tiny Audio Unit Host is one strip with one serial chain. A feature belongs here when it works out of the box or behind a single toggle. A feature that needs the user to wire A to B in a routing or mapping editor belongs in MainStage.

The chain exists for the amp-sim case: many amp sims are bare amps, so players put an overdrive in front and a reverb after. That's serial, and it's where the scope ends.

## Next

1. **MIDI fan-out.** MIDI reaches only the first plug-in in the chain (`MidiManager.setupMIDI(for:)`). An effect that reacts to MIDI — tempo sync, its own preset switching, CC-controlled parameters — gets nothing when it sits behind the source. Forward every event list to every plug-in in the chain.
2. **Output section: master volume, output meter, mute.** The last plug-in in the chain is often a reverb or delay with no output level of its own, so the strip needs a master fader. The meter shows what actually leaves the host. Mute doubles as the panic button for when a plug-in feeds back on stage. The section also finishes the strip visually, since a channel strip ends in a fader.
3. **Reorder slots by drag.** Once there's a chain, "put the drive before the amp" is the obvious next move. It fits the model and needs no new concepts.
4. **Switch presets with MIDI Program Change.** A footswitch sends PC *n* and the host loads preset *n*. It's a fixed mapping, so there's no learn UI. A preset is a whole chain, which makes this the core live feature. Switching reloads the plug-ins, so it's a gap between songs, not a gapless change mid-song. Gapless switching means keeping every preset loaded at once, and that's MainStage.
5. **Bypass slots over MIDI.** Use a fixed scheme, e.g. one CC per slot index that toggles on value. A per-control "MIDI learn" is where the slope starts.

### Open question: who owns a MIDI message

Items 1, 4 and 5 collide. Many amp sims switch their own internal presets on Program Change and map CCs to parameters. If the host consumes PC and bypass CCs, those plug-ins lose them. If it forwards them too, one footswitch press both changes the host preset and changes the amp sim's preset. Settle this before building 4 and 5. One option is to have the host listen on a dedicated MIDI channel and forward everything else.

## Pro

Footswitch control (4 and 5) is the "use it live" case people pay for, so it pairs naturally with the plug-in count as a Pro feature. Fan-out, the output section and reordering make the free version work properly, so they stay free.

## Out of scope

- **Input gain.** The audio interface and the amp sim already have input gain, so a third knob adds nothing.
- **Sends and returns.** They pay off when several sources share one reverb. With a single chain, an insert reverb with a mix knob sounds the same.
- **Parallel or split routing, multiple strips, layers.** Each needs a routing editor.
- **MIDI learn for plug-in parameters.** It needs a mapping editor, and plug-ins usually ship their own.
- **Set lists and song sections.** Presets plus Program Change cover switching between songs.
- **Recording, looping, mixer views.** They're different apps.
