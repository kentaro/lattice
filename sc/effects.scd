// effects.scd — エフェクト SynthDef定義 + パラメーター
// ※ インスタンス起動は boot.scd 内の Routine で行う（s.sync が必要なため）

// ─── エフェクトパラメーター管理 ─────────────────────────────────────────
~fxParams = (
    reverbSize: 0.8,
    reverbDamp: 0.5,
    delayTime:  0.375,   // 8分音符 @BPM=80
    delayFB:    0.4,
    chorusRate: 0.3,
    tapeDrive:  0.3,
    lfoRate:    1.0,
    lfoDepth:   0.0
);

// ─── \reverbFX: FreeVerb2 (ステレオ) ────────────────────────────────────
SynthDef(\reverbFX, { |inBus, outBus, size=0.8, damp=0.5|
    var in = In.ar(inBus, 2);
    var sig = FreeVerb2.ar(in[0], in[1], mix: 1, room: size, damp: damp);
    Out.ar(outBus, sig);
}).add;

// ─── \delayFX: CombL + LPF ─────────────────────────────────────────────
SynthDef(\delayFX, { |inBus, outBus, delayTime=0.375, feedback=0.4|
    var in = In.ar(inBus, 2);
    var sig = CombL.ar(in, 1.0, delayTime.clip(0.01, 1.0), feedback * 4);
    sig = LPF.ar(sig, 3000);
    Out.ar(outBus, sig);
}).add;

// ─── \masterFX: Chorus → Tape Saturation → Limiter → Out ───────────────
SynthDef(\masterFX, { |kbBus, drumBus, toneBus, fxBus,
                       chorusRate=0.3, tapeDrive=0.3, masterVol=1.0|
    var kb   = In.ar(kbBus, 2);
    var drum = In.ar(drumBus, 2);
    var tone = In.ar(toneBus, 2);
    var fx   = In.ar(fxBus, 2);
    var sig  = kb + drum + tone + fx;

    // Chorus (DelayC LFO)
    var lfo = SinOsc.kr(chorusRate, [0, pi/2]);
    var chorusL = DelayC.ar(sig[0], 0.02, lfo[0].range(0.005, 0.015));
    var chorusR = DelayC.ar(sig[1], 0.02, lfo[1].range(0.005, 0.015));
    var chorus = [sig[0] + (chorusL * 0.3), sig[1] + (chorusR * 0.3)];

    // Tape Saturation
    var tape = (chorus * (1 + tapeDrive)).tanh;

    // Limiter
    sig = Limiter.ar(tape * masterVol, 0.95);
    Out.ar(0, sig);
}).add;

"effects.scd loaded (SynthDefs).".postln;
