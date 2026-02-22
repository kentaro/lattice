// midi.scd — MIDI受信 + Launchkey MK4 ノブ/パッド/鍵盤マッピング
// gate-based voice management / sustain pedal / preset switching
(
    // ═══════════════════════════════════════════════════════════════════════════
    // グローバルパラメーター (Global parameters — updated by knobs)
    // ═══════════════════════════════════════════════════════════════════════════
    ~params = (
        cutoff:     8000,
        resonance:  0.3,
        attack:     0.01,
        release:    0.5,
        reverbSend: 0.3,
        delaySend:  0.0,
        chorus:     0.3,
        volume:     1.0,
        lfoRate:    1.0,
        lfoDepth:   0.0
    );

    // ═══════════════════════════════════════════════════════════════════════════
    // Voice tracking (ボイス管理)
    // ═══════════════════════════════════════════════════════════════════════════
    ~activeVoices   = Dictionary.new;   // note -> Synth (keyboard voices)
    ~heldNotes      = Set.new;          // 物理的に押されている鍵盤
    ~sustainedNotes = Dictionary.new;   // note -> Synth (ペダルで延長中)
    ~sustainOn      = false;            // sustain pedal state

    // ═══════════════════════════════════════════════════════════════════════════
    // Preset / mode state (プリセット/モード状態)
    // ═══════════════════════════════════════════════════════════════════════════
    ~currentPreset = \rhodes;           // default keyboard preset
    ~knobMode      = \sound;            // \sound or \fx
    ~pitchBend     = 0.0;              // -1.0 ~ +1.0 (±2 semitones)
    ~modValue      = 0.0;              // 0.0 ~ 1.0

    // ═══════════════════════════════════════════════════════════════════════════
    // Launchkey UID detection (Launchkey ソースUID検出)
    // ═══════════════════════════════════════════════════════════════════════════
    ~launchkeyUID = nil;
    MIDIClient.sources.do { |src|
        if (src.device.containsi("Launchkey") && src.name.containsi("MIDI In")) {
            ~launchkeyUID = src.uid;
            ("Launchkey detected: uid=" ++ src.uid).postln;
        };
    };

    // ═══════════════════════════════════════════════════════════════════════════
    // Helper: ~spawnVoice — キーボードボイス生成
    // Creates a synth for the current preset with all params
    // ═══════════════════════════════════════════════════════════════════════════
    ~spawnVoice = { |note, vel, chan|
        var freq = note.midicps * (1 + (~pitchBend * 2/12));
        var amp  = vel / 127.0 * 0.4;
        var pan  = ((note - 60) / 36.0).clip(-1, 1);
        var args = [
            \freq,       freq,
            \gate,       1,
            \vel,        vel / 127.0,
            \amp,        amp,
            \attack,     ~params[\attack],
            \release,    ~params[\release],
            \cutoff,     ~params[\cutoff],
            \resonance,  ~params[\resonance],
            \reverbSend, ~params[\reverbSend],
            \delaySend,  ~params[\delaySend],
            \pan,        pan,
            \vibRate,    ~params[\lfoRate],
            \vibDepth,   ~modValue * ~params[\lfoDepth],
            \outBus,     ~kbBus,
            \reverbBus,  ~reverbSend,
            \delayBus,   ~delaySend
        ];
        var synth;

        // Preset-specific extra args
        switch(~currentPreset,
            \wurlitzer, { args = args ++ [\tremRate, ~params[\lfoRate], \tremDepth, ~params[\lfoDepth]] },
            \analogPad, { args = args ++ [\subLevel, 0.4] },
            \lead,      { args = args ++ [\portTime, 0.05, \pulseWidth, 0.5] }
        );

        synth = Synth(~currentPreset, args, ~kbGroup);
        ~activeVoices[note] = synth;
        synth;
    };

    // ═══════════════════════════════════════════════════════════════════════════
    // Helper: ~releaseVoice — ボイス解放 (sustain pedal aware)
    // NEVER uses .free — always .set(\gate, 0) for proper ADSR release
    // ═══════════════════════════════════════════════════════════════════════════
    ~releaseVoice = { |note|
        var synth = ~activeVoices[note];
        if (synth.notNil) {
            if (~sustainOn) {
                // Pedal is held: move to sustainedNotes (keep sounding)
                ~sustainedNotes[note] = synth;
                ~activeVoices.removeAt(note);
            } {
                // No pedal: release immediately via gate
                synth.set(\gate, 0);
                ~activeVoices.removeAt(note);
            };
        };
    };

    // ═══════════════════════════════════════════════════════════════════════════
    // Helper: ~releaseAllVoices — 全ボイス解放 (preset switch時など)
    // ═══════════════════════════════════════════════════════════════════════════
    ~releaseAllVoices = {
        ~activeVoices.do { |synth| synth.set(\gate, 0) };
        ~activeVoices = Dictionary.new;
        ~sustainedNotes.do { |synth| synth.set(\gate, 0) };
        ~sustainedNotes = Dictionary.new;
        ~heldNotes = Set.new;
    };

    // ═══════════════════════════════════════════════════════════════════════════
    // Keyboard NoteOn (Launchkey → current preset)
    // srcIDのみでフィルタ (ch制限なし — Launchkeyはch1固定)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.noteOn(\keyboardOn, { |vel, note, chan, srcID|
        if (srcID == ~launchkeyUID) {
            // 同じノートが既に鳴っていたら先にリリース
            if (~activeVoices[note].notNil) {
                ~activeVoices[note].set(\gate, 0);
                ~activeVoices.removeAt(note);
            };
            if (~sustainedNotes[note].notNil) {
                ~sustainedNotes[note].set(\gate, 0);
                ~sustainedNotes.removeAt(note);
            };
            ~heldNotes.add(note);
            ~spawnVoice.(note, vel, chan);
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // Keyboard NoteOff (Launchkey)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.noteOff(\keyboardOff, { |vel, note, chan, srcID|
        if (srcID == ~launchkeyUID) {
            ~heldNotes.remove(note);
            ~releaseVoice.(note);
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // Sustain Pedal (CC64 from Launchkey)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.cc(\sustainPedal, { |val, num, chan, srcID|
        if ((num == 64) && (srcID == ~launchkeyUID)) {
            if (val >= 64) {
                // Pedal down
                ~sustainOn = true;
            } {
                // Pedal up: release all sustained notes
                ~sustainOn = false;
                ~sustainedNotes.do { |synth|
                    synth.set(\gate, 0);
                };
                ~sustainedNotes = Dictionary.new;
            };
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // Aftertouch (channel pressure → cutoff modulation)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.touch(\aftertouch, { |val, chan, srcID|
        if (srcID == ~launchkeyUID) {
            var cutoffOffset = val / 127.0 * 4000;
            var newCutoff = (~params[\cutoff] + cutoffOffset).clip(80, 18000);
            ~activeVoices.do { |synth|
                synth.set(\cutoff, newCutoff);
            };
            ~sustainedNotes.do { |synth|
                synth.set(\cutoff, newCutoff);
            };
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // Mod Strip (CC1 → vibrato depth)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.cc(\modStrip, { |val, num, chan, srcID|
        if ((num == 1) && (srcID == ~launchkeyUID)) {
            ~modValue = val / 127.0;
            ~activeVoices.do { |synth|
                synth.set(\vibDepth, ~modValue * ~params[\lfoDepth].max(0.5));
            };
            ~sustainedNotes.do { |synth|
                synth.set(\vibDepth, ~modValue * ~params[\lfoDepth].max(0.5));
            };
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // Pitch Bend (±2 semitones)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.bend(\pitchBend, { |val, chan, srcID|
        if (srcID == ~launchkeyUID) {
            ~pitchBend = (val - 8192) / 8192.0;
            ~activeVoices.keysValuesDo { |note, synth|
                var newFreq = note.midicps * (1 + (~pitchBend * 2/12));
                synth.set(\freq, newFreq);
            };
            ~sustainedNotes.keysValuesDo { |note, synth|
                var newFreq = note.midicps * (1 + (~pitchBend * 2/12));
                synth.set(\freq, newFreq);
            };
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // Preset Selection (ch10, pads 48-51)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.noteOn(\presetSelect, { |vel, note, chan, srcID|
        if ((chan == 9) && (srcID == ~launchkeyUID)) {
            var presets = Dictionary[
                48 -> \rhodes,
                49 -> \wurlitzer,
                50 -> \analogPad,
                51 -> \lead
            ];
            var newPreset = presets[note];
            if (newPreset.notNil && (newPreset != ~currentPreset)) {
                ~releaseAllVoices.();
                ~currentPreset = newPreset;
                ("Preset: " ++ newPreset).postln;
            };
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // Drum Pads (ch10, notes 36-47)
    // Fire-and-forget percussion — uses ~drumGroup / ~drumBus
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.noteOn(\drumPadOn, { |vel, note, chan, srcID|
        var normVel = vel / 127.0;
        if ((chan == 9) && (note >= 36) && (note <= 47)) {
            case
            { note == 36 } {
                Synth(\kick, [\vel, normVel, \outBus, ~drumBus,
                    \reverbBus, ~reverbSend], ~drumGroup)
            }
            { note == 37 } {
                Synth(\snare, [\vel, normVel, \outBus, ~drumBus,
                    \reverbBus, ~reverbSend], ~drumGroup)
            }
            { note == 38 } {
                Synth(\hihat, [\vel, normVel, \outBus, ~drumBus,
                    \reverbBus, ~reverbSend], ~drumGroup)
            }
            { note == 39 } {
                Synth(\openhat, [\vel, normVel, \outBus, ~drumBus,
                    \reverbBus, ~reverbSend], ~drumGroup)
            }
            { note == 40 } {
                Synth(\lofikick, [\freq, 55, \vel, normVel, \outBus, ~drumBus,
                    \reverbBus, ~reverbSend], ~drumGroup)
            }
            { note == 41 } {
                Synth(\rimshot, [\vel, normVel, \outBus, ~drumBus,
                    \reverbBus, ~reverbSend], ~drumGroup)
            }
            { note == 42 } {
                Synth(\lofikick, [\freq, 65, \vel, normVel, \outBus, ~drumBus,
                    \reverbBus, ~reverbSend], ~drumGroup)
            }
            { note == 43 } {
                Synth(\snap, [\vel, normVel, \outBus, ~drumBus,
                    \reverbBus, ~reverbSend], ~drumGroup)
            }
            { (note >= 44) && (note <= 47) } {
                Synth(\perc, [
                    \freq, (note - 44 * 5 + 48).midicps,
                    \vel, normVel, \outBus, ~drumBus,
                    \reverbBus, ~reverbSend
                ], ~drumGroup)
            };
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // Knob Mode Toggle (CC29 — toggle between \sound and \fx)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.cc(\knobModeToggle, { |val, num, chan, srcID|
        if ((num == 29) && (srcID == ~launchkeyUID)) {
            if (val >= 64) {
                ~knobMode = if (~knobMode == \sound) { \fx } { \sound };
                ("Knob mode: " ++ ~knobMode).postln;
            };
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // Knobs CC21-28 — Mode A (\sound) / Mode B (\fx)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.cc(\knobs, { |val, num, chan, srcID|
        var norm = val / 127.0;

        if ((num >= 21) && (num <= 28) && (srcID == ~launchkeyUID)) {
            if (~knobMode == \sound) {
                // ─── Mode A: Sound parameters ──────────────────────────────
                case
                { num == 21 } {
                    // Cutoff (80-18000, exponential)
                    ~params[\cutoff] = norm.linexp(0, 1, 80, 18000);
                    ~activeVoices.do { |s| s.set(\cutoff, ~params[\cutoff]) };
                    ~sustainedNotes.do { |s| s.set(\cutoff, ~params[\cutoff]) };
                }
                { num == 22 } {
                    // Resonance (0.01-0.99, linear)
                    ~params[\resonance] = norm.linlin(0, 1, 0.01, 0.99);
                    ~activeVoices.do { |s| s.set(\resonance, ~params[\resonance]) };
                    ~sustainedNotes.do { |s| s.set(\resonance, ~params[\resonance]) };
                }
                { num == 23 } {
                    // Attack (0.001-2.0, exponential)
                    ~params[\attack] = norm.linexp(0, 1, 0.001, 2.0);
                }
                { num == 24 } {
                    // Release (0.05-5.0, exponential)
                    ~params[\release] = norm.linexp(0, 1, 0.05, 5.0);
                }
                { num == 25 } {
                    // Reverb Send (0-1, linear)
                    ~params[\reverbSend] = norm;
                    ~activeVoices.do { |s| s.set(\reverbSend, norm) };
                    ~sustainedNotes.do { |s| s.set(\reverbSend, norm) };
                }
                { num == 26 } {
                    // Delay Send (0-1, linear)
                    ~params[\delaySend] = norm;
                    ~activeVoices.do { |s| s.set(\delaySend, norm) };
                    ~sustainedNotes.do { |s| s.set(\delaySend, norm) };
                }
                { num == 27 } {
                    // Tape Drive → masterFX
                    ~fxParams[\tapeDrive] = norm;
                    ~masterFXSynth.set(\tapeDrive, norm);
                }
                { num == 28 } {
                    // Master volume → masterFX
                    ~params[\volume] = norm;
                    ~masterFXSynth.set(\masterVol, norm);
                };
            } {
                // ─── Mode B: FX parameters ─────────────────────────────────
                case
                { num == 21 } {
                    // Reverb Size
                    ~fxParams[\reverbSize] = norm.linlin(0, 1, 0.1, 1.0);
                    ~reverbFXSynth.set(\size, ~fxParams[\reverbSize]);
                }
                { num == 22 } {
                    // Reverb Damp
                    ~fxParams[\reverbDamp] = norm;
                    ~reverbFXSynth.set(\damp, ~fxParams[\reverbDamp]);
                }
                { num == 23 } {
                    // Delay Time
                    ~fxParams[\delayTime] = norm.linexp(0, 1, 0.05, 1.0);
                    ~delayFXSynth.set(\delayTime, ~fxParams[\delayTime]);
                }
                { num == 24 } {
                    // Delay Feedback
                    ~fxParams[\delayFB] = norm.linlin(0, 1, 0.0, 0.9);
                    ~delayFXSynth.set(\feedback, ~fxParams[\delayFB]);
                }
                { num == 25 } {
                    // Tape Drive
                    ~fxParams[\tapeDrive] = norm.linlin(0, 1, 0.0, 1.0);
                    ~masterFXSynth.set(\tapeDrive, ~fxParams[\tapeDrive]);
                }
                { num == 26 } {
                    // (reserved)
                }
                { num == 27 } {
                    // LFO Rate (stored for synth use)
                    ~fxParams[\lfoRate] = norm.linexp(0, 1, 0.1, 20.0);
                    ~params[\lfoRate] = ~fxParams[\lfoRate];
                    ~activeVoices.do { |s| s.set(\vibRate, ~params[\lfoRate]) };
                    ~sustainedNotes.do { |s| s.set(\vibRate, ~params[\lfoRate]) };
                }
                { num == 28 } {
                    // LFO Depth (stored for synth use)
                    ~fxParams[\lfoDepth] = norm;
                    ~params[\lfoDepth] = norm;
                    ~activeVoices.do { |s| s.set(\vibDepth, ~modValue * norm) };
                    ~sustainedNotes.do { |s| s.set(\vibDepth, ~modValue * norm) };
                };
            };
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // External MIDI: \tone (fire-and-forget, all channels except ch1/ch10/ch16)
    // 外部デバイスは物理切断でNoteOffが来ないため percussive envelope で安全に
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.noteOn(\toneOn, { |vel, note, chan, srcID|
        if ((chan != 0) && (chan != 9) && (chan != 15) && (srcID != ~launchkeyUID)) {
            Synth(\tone, [
                \freq,       note.midicps,
                \amp,        vel / 127.0 * 0.5,
                \attack,     ~params[\attack],
                \release,    ~params[\release],
                \cutoff,     ~params[\cutoff],
                \reverbSend, ~params[\reverbSend],
                \pan,        ((note - 60) / 36.0).clip(-1, 1),
                \outBus,     ~toneBus,
                \reverbBus,  ~reverbSend
            ], ~toneGroup);
        };
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // ch16 NoteOn → \kalimba (percussive, fire-and-forget)
    // ═══════════════════════════════════════════════════════════════════════════
    MIDIdef.noteOn(\kalimbaOn, { |vel, note, chan, srcID|
        if (chan == 15) {
            Synth(\kalimba, [
                \freq,    note.midicps,
                \amp,     vel / 127.0 * 0.5,
                \release, ~params[\release],
                \pan,     ((note - 60) / 36.0).clip(-1, 1),
                \outBus,  ~toneBus,
                \reverbBus, ~reverbSend
            ], ~toneGroup);
        };
    });

    "midi.scd loaded. Listening on all MIDI channels.".postln;
)
