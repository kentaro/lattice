// midi.scd — 汎用MIDI受信 + Launchkey ノブマッピング
(
    // ─── グローバルパラメーター (ノブで更新) ───────────────────────────────
    ~params = (
        cutoff:    8000,
        resonance: 0.3,
        attack:    0.01,
        release:   1.0,
        reverb:    0.3,
        detune:    0.0,
        lfoRate:   1.0,
        lfoDepth:  0.0
    );

    // 現在演奏中の \piano シンス (ピッチベンド・CC1で操作)
    ~activePianos = Dictionary.new;
    ~pitchBend = 0.0;  // -1.0 〜 +1.0 (±2半音)
    ~modValue  = 0.0;  // 0.0 〜 1.0

    // ─── CC値 → 実パラメーター変換 ────────────────────────────────────────
    ~ccToParam = { |ccVal|  ccVal / 127.0 };

    // ─── Launchkey のソースUID検出 ──────────────────────────────────────────
    ~launchkeyUID = nil;
    MIDIClient.sources.do { |src|
        if (src.device.containsi("Launchkey") && src.name.containsi("MIDI In")) {
            ~launchkeyUID = src.uid;
            ("Launchkey detected: uid=" ++ src.uid).postln;
        };
    };

    // ─── Launchkey ch1 NoteOn → \piano ──────────────────────────────────────
    MIDIdef.noteOn(\keyboardOn, { |vel, note, chan, srcID|
        var freq, amp, synth;
        if (srcID == ~launchkeyUID) {
            freq = note.midicps * (1 + (~pitchBend * 2/12));
            amp  = vel / 127.0 * 0.4;
            synth = Synth(\piano, [
                \freq,      freq,
                \amp,       amp,
                \detune,    ~params[\detune],
                \attack,    ~params[\attack],
                \release,   ~params[\release],
                \cutoff,    ~params[\cutoff],
                \resonance, ~params[\resonance],
                \reverb,    ~params[\reverb],
                \pan,       ((note - 60) / 36.0).clip(-1, 1)
            ]);
            ~activePianos[note] = synth;
        };
    });

    // ─── Launchkey ch1 NoteOff → \piano 解放 ────────────────────────────────
    MIDIdef.noteOff(\keyboardOff, { |vel, note, chan, srcID|
        if (srcID == ~launchkeyUID) {
            ~activePianos[note].free;
            ~activePianos.removeAt(note);
        };
    });

    // ─── ch10 NoteOn → ドラム/パーカッション ──────────────────────────────
    MIDIdef.noteOn(\padOn, { |vel, note, chan|
        var amp = vel / 127.0 * 0.5;
        if (chan == 9) {  // ch10 = index 9
            ("PAD: note=" ++ note ++ " vel=" ++ vel ++ " amp=" ++ amp).postln;
            case
            { note == 36 } { Synth(\kick,    [\amp, amp]) }
            { note == 37 } { Synth(\snare,   [\amp, amp]) }
            { note == 38 } { Synth(\hihat,   [\amp, amp]) }
            { note == 39 } { Synth(\openhat, [\amp, amp]) }
            { note == 40 } { Synth(\lofikick, [\freq, 55, \amp, amp]) }
            { note == 41 } { Synth(\lofikick, [\freq, 45, \amp, amp]) }
            { note == 42 } { Synth(\lofikick, [\freq, 65, \amp, amp]) }
            { note == 43 } { Synth(\clap,    [\amp, amp]) }
            { (note >= 44) && (note <= 47) } {
                Synth(\perc, [\freq, (note - 44 * 5 + 48).midicps, \amp, amp])
            }
            { (note >= 48) && (note <= 51) } {
                Synth(\fx, [
                    \freq,    note.midicps,
                    \amp,     amp,
                    \attack,  ~params[\attack],
                    \release, ~params[\release]
                ])
            };
        };
    });

    // ─── ch16 NoteOn → \kalimba (代替音色チャンネル) ────────────────────────
    MIDIdef.noteOn(\altOn, { |vel, note, chan, srcID|
        if (chan == 15) {
            Synth(\kalimba, [
                \freq,    note.midicps,
                \amp,     vel / 127.0 * 0.5,
                \release, ~params[\release],
                \reverb,  ~params[\reverb],
                \pan,     ((note - 60) / 36.0).clip(-1, 1)
            ]);
        };
    });

    // ─── 汎用 NoteOn → \tone (その他全チャンネル) ─────────────────────────
    MIDIdef.noteOn(\genericOn, { |vel, note, chan, srcID|
        if ((chan != 9) && (chan != 15) && (srcID != ~launchkeyUID)) {
            Synth(\tone, [
                \freq,    note.midicps,
                \amp,     vel / 127.0 * 0.5,
                \attack,  ~params[\attack],
                \release, ~params[\release],
                \cutoff,  ~params[\cutoff],
                \reverb,  ~params[\reverb],
                \pan,     ((note - 60) / 36.0).clip(-1, 1)
            ]);
        };
    });

    // ─── ch1 CC1 (Mod タッチストリップ) → detune/vibrato ─────────────────
    MIDIdef.cc(\modStrip, { |val, num, chan|
        if ((chan == 0) && (num == 1)) {
            ~modValue = val / 127.0;
            ~activePianos.do { |synth|
                synth.set(\detune, ~modValue * 20);
            };
        };
    });

    // ─── ch1 PitchBend → 音程変化 (±2半音) ──────────────────────────────
    MIDIdef.bend(\pitchBend, { |val, chan|
        if (chan == 0) {
            // val: 0-16383, center=8192
            ~pitchBend = (val - 8192) / 8192.0;
            ~activePianos.keysValuesDo { |note, synth|
                var newFreq = note.midicps * (1 + (~pitchBend * 2/12));
                synth.set(\freq, newFreq);
            };
        };
    });

    // ─── CC21-28 → グローバルパラメーター ──────────────────────────────────
    // Launchkey MK4: ノブのチャンネルはデバイス設定により変動するため
    // CC番号のみでマッチ (全チャンネル受付)
    MIDIdef.cc(\knobs, { |val, num, chan|
        var norm = val / 127.0;
        case
        { num == 21 } {
            ~params[\cutoff] = (norm * 18000).clip(80, 18000);
            ~activePianos.do { |s| s.set(\cutoff, ~params[\cutoff]) };
        }
        { num == 22 } {
            ~params[\resonance] = norm.clip(0.01, 0.99);
            ~activePianos.do { |s| s.set(\resonance, ~params[\resonance]) };
        }
        { num == 23 } {
            ~params[\attack] = norm.linexp(0, 1, 0.001, 2.0);
        }
        { num == 24 } {
            ~params[\release] = norm.linexp(0, 1, 0.05, 5.0);
        }
        { num == 25 } {
            ~params[\reverb] = norm;
            ~activePianos.do { |s| s.set(\reverb, norm) };
        }
        { num == 26 } {
            ~params[\detune] = norm * 30;
            ~activePianos.do { |s| s.set(\detune, ~params[\detune]) };
        }
        { num == 27 } {
            ~params[\lfoRate] = norm.linexp(0, 1, 0.1, 20.0);
        }
        { num == 28 } {
            // ノブ8 → マスターボリューム
            var db = norm.linlin(0, 1, -40, 6);
            Server.default.volume.volume = db;
        };
    });

    "midi.scd loaded. Listening on all MIDI channels.".postln;
)
