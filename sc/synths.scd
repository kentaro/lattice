// synths.scd — SynthDef定義

// ─── 鍵盤用: \piano (ローファイ エレピ / Rhodes風) ────────────────────────
SynthDef(\piano, { |freq=440, amp=0.5, detune=0.0, attack=0.01, release=1.0,
                    cutoff=8000, resonance=0.3, reverb=0.3, pan=0.0|
    var sig, env, filtered, verb;

    env = EnvGen.kr(
        Env.perc(attack, release, 1, -4),
        doneAction: Done.freeSelf
    );

    // Rhodes風: SinOsc FM合成 (モジュレーター→キャリア)
    sig = SinOsc.ar(freq, SinOsc.ar(freq * 2, 0, 1.5 * EnvGen.kr(Env.perc(0.001, 0.15))));
    // デチューンでテープ風の揺らぎ
    sig = sig + SinOsc.ar(freq * (1 + (detune * 0.008)), 0, 0.2);
    sig = sig * env * amp;

    // フィルター (こもった暖かさ)
    filtered = RLPF.ar(sig, cutoff.clip(80, 18000), resonance.clip(0.01, 1.0));

    // テープサチュレーション
    filtered = (filtered * 1.3).softclip;

    // リバーブ
    verb = FreeVerb.ar(filtered, reverb, 0.8, 0.5);
    sig = (filtered * (1 - reverb)) + (verb * reverb);

    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ─── パッド用: ローファイヒップホップ ドラムキット ──────────────────────────
// 共通キャラクター: テープサチュレーション + LPF + ヴァイナルテクスチャ

SynthDef(\kick, { |amp=0.8, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.01, 0.5, 1, -3), doneAction: Done.freeSelf);
    var sig = SinOsc.ar(XLine.kr(100, 38, 0.1)) * env * amp;
    sig = sig + (WhiteNoise.ar(0.06) * EnvGen.kr(Env.perc(0.001, 0.03)) * amp);
    sig = (sig * 1.5).softclip;
    sig = LPF.ar(sig, 400);
    sig = sig + (PinkNoise.ar(0.006) * env);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

SynthDef(\snare, { |amp=0.7, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.005, 0.25, 1, -4), doneAction: Done.freeSelf);
    var tone = SinOsc.ar(170) * env * amp * 0.4;
    var noise = BPF.ar(WhiteNoise.ar, 900, 0.9) * env * amp * 0.7;
    var sig = tone + noise;
    sig = (sig * 1.4).softclip;
    sig = LPF.ar(sig, 3000);
    sig = sig + (PinkNoise.ar(0.005) * env);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

SynthDef(\hihat, { |amp=0.5, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.002, 0.06, 1, -8), doneAction: Done.freeSelf);
    var sig = HPF.ar(WhiteNoise.ar, 6000) * env * amp;
    sig = LPF.ar(sig, 9000);  // 高域も落としてこもらせる
    sig = (sig * 1.3).softclip;
    sig = sig + (PinkNoise.ar(0.004) * env);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

SynthDef(\openhat, { |amp=0.5, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.002, 0.35, 1, -4), doneAction: Done.freeSelf);
    var sig = HPF.ar(WhiteNoise.ar, 5000) * env * amp;
    sig = LPF.ar(sig, 8000);
    sig = (sig * 1.3).softclip;
    sig = sig + (PinkNoise.ar(0.005) * env);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ローファイヒップホップ風バスドラ (パッド上段左)
SynthDef(\lofikick, { |freq=50, amp=0.8, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.01, 0.6, 1, -3), doneAction: Done.freeSelf);
    var sig = SinOsc.ar(XLine.kr(freq * 2.5, freq * 0.8, 0.15)) * env * amp;
    sig = (sig * 1.5).softclip;
    sig = LPF.ar(sig, 200);
    sig = sig + (PinkNoise.ar(0.008) * env);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

SynthDef(\clap, { |amp=0.6, pan=0.0|
    var env = EnvGen.kr(
        Env([0, 1, 0, 0.5, 0], [0.001, 0.01, 0.005, 0.18], -4),
        doneAction: Done.freeSelf
    );
    var sig = BPF.ar(WhiteNoise.ar, 900, 0.8) * env * amp;
    sig = (sig * 1.4).softclip;
    sig = LPF.ar(sig, 2500);
    sig = sig + (PinkNoise.ar(0.005) * env);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ローファイ パーカッション (パッド上段右寄り, note 44-47)
// くぐもった金属打楽器風
SynthDef(\perc, { |freq=440, amp=0.6, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.002, 0.25, 1, -5), doneAction: Done.freeSelf);
    var sig = SinOsc.ar(freq) * 0.6 + (SinOsc.ar(freq * 2.3, 0, 0.2));
    sig = sig * env * amp;
    sig = (sig * 1.5).softclip;
    sig = LPF.ar(sig, 2000);
    sig = sig + (PinkNoise.ar(0.006) * env);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ローファイ FX/スタブ (パッド最上段, note 48-51)
// フィルタードコード風の一撃
SynthDef(\fx, { |freq=440, amp=0.6, attack=0.02, release=0.4, pan=0.0|
    var env = EnvGen.kr(Env.perc(attack, release, 1, -4), doneAction: Done.freeSelf);
    var sig = SinOsc.ar(freq, 0, 0.4) + SinOsc.ar(freq * 1.5, 0, 0.25) + SinOsc.ar(freq * 2, 0, 0.15);
    sig = sig * env * amp;
    sig = (sig * 1.4).softclip;
    sig = LPF.ar(sig, 1800);
    sig = FreeVerb.ar(sig, 0.5, 0.8, 0.3);
    sig = sig + (PinkNoise.ar(0.005) * env);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ─── 汎用: \tone (gol-synth・傀儡師 など外部MIDI用) ─────────────────────
// ソフトパッド系: ふわっと立ち上がるフィルタードパッド (鍵盤のRhodesと棲み分け)
SynthDef(\tone, { |freq=440, amp=0.3, attack=0.08, release=0.8,
                   cutoff=8000, reverb=0.2, pan=0.0|
    var env = EnvGen.kr(
        Env.perc(attack, release, 1, -3),
        doneAction: Done.freeSelf
    );
    // 三角波風 (奇数倍音のみ) + わずかなデチューン
    var sig = LFTri.ar(freq * 0.999, 0, 0.5) + LFTri.ar(freq * 1.001, 0, 0.5);
    // 深いローパスでこもらせる (Rhodesのアタック感と差別化)
    sig = LPF.ar(sig, (cutoff * 0.3).clip(80, 4000));
    sig = sig * env * amp;
    sig = (sig * 1.2).softclip;
    sig = FreeVerb.ar(sig, reverb.max(0.4), 0.85, 0.4);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

// ─── ch16用: \kalimba (カリンバ / 親指ピアノ) ────────────────────────────
// ch1のエレピやch汎用のパッドと被らないコロコロした金属音
SynthDef(\kalimba, { |freq=440, amp=0.4, release=1.2, reverb=0.3, pan=0.0|
    var env = EnvGen.kr(Env.perc(0.001, release, 1, -8), doneAction: Done.freeSelf);
    // 基音 + 非整数倍音 (金属的なキャラクター)
    var sig = SinOsc.ar(freq, 0, 0.5)
        + SinOsc.ar(freq * 3.01, 0, 0.15)
        + SinOsc.ar(freq * 5.98, 0, 0.06);
    // 短いアタックのクリック
    var click = WhiteNoise.ar(0.2) * EnvGen.kr(Env.perc(0.0005, 0.008));
    sig = (sig * env * amp) + (click * amp);
    sig = LPF.ar(sig, 5000);
    sig = (sig * 1.2).softclip;
    sig = FreeVerb.ar(sig, reverb.max(0.3), 0.7, 0.4);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;

"synths.scd loaded.".postln;
