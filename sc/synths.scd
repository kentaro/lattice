// synths.scd — SynthDef定義

// ─── 鍵盤用: \piano (Karplus-Strong ベース) ───────────────────────────────
SynthDef(\piano, { |freq=440, amp=0.5, detune=0.0, attack=0.01, release=1.0,
                    cutoff=8000, resonance=0.3, reverb=0.3, pan=0.0|
    var sig, env, excite, string, filtered, verb;

    // エンベロープはピーク1.0、ampは別途乗算
    env = EnvGen.kr(
        Env.perc(attack, release, 1, -4),
        doneAction: Done.freeSelf
    );

    // Karplus-Strong: ノイズバーストで弦を励起
    excite = WhiteNoise.ar(0.5) * EnvGen.kr(Env.perc(0.001, 0.03));
    string = CombL.ar(excite, 0.05, 1/freq, release);

    // デチューンによるコーラス感 / vibrato
    sig = Mix([
        SinOsc.ar(freq * (1 + (detune * 0.01)), 0, 0.5),
        SinOsc.ar(freq * (1 - (detune * 0.01)) * 2, 0, 0.15),
        string
    ]) * env * amp;

    // フィルター
    filtered = RLPF.ar(sig, cutoff.clip(80, 18000), resonance.clip(0.01, 1.0));

    // リバーブ
    verb = FreeVerb.ar(filtered, reverb, 0.8, 0.5);
    sig = (filtered * (1 - reverb)) + (verb * reverb);

    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ─── パッド用: ドラム・パーカッション ─────────────────────────────────────

SynthDef(\kick, { |amp=0.8, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.005, 0.5, 1, -4), doneAction: Done.freeSelf);
    var sig = SinOsc.ar(XLine.kr(120, 40, 0.08)) * env * amp;
    sig = sig + (WhiteNoise.ar(0.1) * EnvGen.kr(Env.perc(0.001, 0.05)) * amp);
    Out.ar(0, Pan2.ar(sig.clip2(0.9), pan));
}).add;

SynthDef(\snare, { |amp=0.7, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.005, 0.2, 1, -4), doneAction: Done.freeSelf);
    var tone = SinOsc.ar(180) * env * amp * 0.4;
    var noise = BPF.ar(WhiteNoise.ar, 1200, 0.8) * env * amp * 0.8;
    Out.ar(0, Pan2.ar((tone + noise).clip2(0.9), pan));
}).add;

SynthDef(\hihat, { |amp=0.5, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.001, 0.08, 1, -6), doneAction: Done.freeSelf);
    var sig = HPF.ar(WhiteNoise.ar, 8000) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

SynthDef(\openhat, { |amp=0.5, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.001, 0.4, 1, -4), doneAction: Done.freeSelf);
    var sig = HPF.ar(WhiteNoise.ar, 6000) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

SynthDef(\tom, { |freq=150, amp=0.7, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.005, 0.35, 1, -4), doneAction: Done.freeSelf);
    var body = SinOsc.ar(XLine.kr(freq * 2, freq, 0.12));
    var click = WhiteNoise.ar(0.3) * EnvGen.kr(Env.perc(0.001, 0.02));
    var overtone = SinOsc.ar(freq * 2.4, 0, 0.15) * EnvGen.kr(Env.perc(0.003, 0.1));
    var sig = (body + click + overtone) * env * amp;
    Out.ar(0, Pan2.ar(sig.clip2(0.9), pan));
}).add;

SynthDef(\clap, { |amp=0.6, pan=0.0|
    var env = EnvGen.kr(
        Env([0, 1, 0, 0.5, 0], [0.001, 0.01, 0.005, 0.15], -4),
        doneAction: Done.freeSelf
    );
    var sig = BPF.ar(WhiteNoise.ar, 1100, 0.7) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

SynthDef(\perc, { |freq=440, amp=0.6, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.001, 0.3, 1, -5), doneAction: Done.freeSelf);
    var sig = Mix([
        SinOsc.ar(freq),
        SinOsc.ar(freq * 2.76, 0, 0.3),
        SinOsc.ar(freq * 5.4, 0, 0.1)
    ]) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

SynthDef(\fx, { |freq=440, amp=0.6, attack=0.05, release=0.5, pan=0.0|
    var env = EnvGen.kr(Env.perc(attack, release, 1, -3), doneAction: Done.freeSelf);
    var sig = Mix([
        Saw.ar(freq, 0.4),
        Saw.ar(freq * 1.003, 0.3),
        SinOsc.ar(freq * 0.5, 0, 0.3)
    ]);
    sig = RLPF.ar(sig, freq * 4, 0.5) * env * amp;
    sig = FreeVerb.ar(sig, 0.4, 0.7);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ─── 汎用: \tone (gol-synth など外部MIDI用) ────────────────────────────────
// 温かみのあるアナログ風パッドサウンド
SynthDef(\tone, { |freq=440, amp=0.3, attack=0.01, release=0.5,
                   cutoff=8000, reverb=0.2, pan=0.0|
    var env = EnvGen.kr(
        Env.perc(attack, release, 1, -4),
        doneAction: Done.freeSelf
    );
    // デチューンした複数オシレーターで厚みを出す
    var sig = Mix([
        Saw.ar(freq * 0.998, 0.3),
        Pulse.ar(freq * 1.002, 0.4, 0.25),
        SinOsc.ar(freq * 0.5, 0, 0.2)  // サブオクターブ
    ]);
    // フィルターエンベロープ (アタック時にブライト→暗くなる)
    var filtEnv = EnvGen.kr(Env.perc(attack, release * 0.6, 1, -3));
    var filtFreq = cutoff * (0.3 + (filtEnv * 0.7));
    sig = RLPF.ar(sig, filtFreq.clip(80, 18000), 0.4);
    sig = sig * env * amp;
    sig = FreeVerb.ar(sig, reverb, 0.8, 0.4);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

"synths.scd loaded.".postln;
