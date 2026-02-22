// synths.scd — SynthDef定義
// バス構成: outBus(メイン出力), reverbBus(リバーブセンド), delayBus(ディレイセンド)

// ═══════════════════════════════════════════════════════════════════════════
// 鍵盤シンセ (gate-based ADSR, NoteOff で解放)
// ═══════════════════════════════════════════════════════════════════════════

// ─── \rhodes: FM エレクトリックピアノ ─────────────────────────────────────
// FM合成: SinOscキャリア + SinOscモジュレーター(2倍音), ベロシティでFMインデックス変化
SynthDef(\rhodes, { |freq=440, gate=1, vel=0.8, amp=0.5,
                     attack=0.01, release=0.5, cutoff=8000, resonance=0.3,
                     reverbSend=0.3, delaySend=0.0, pan=0.0,
                     vibRate=5, vibDepth=0,
                     outBus=0, reverbBus=0, delayBus=0|
    var env, vibrato, modIndex, modulator, sig, filtered;

    env = EnvGen.kr(
        Env.adsr(attack, 0.3, 0.8, release),
        gate, doneAction: Done.freeSelf
    );

    // ビブラート (vibDepth > 0 で有効)
    vibrato = SinOsc.kr(vibRate, 0, vibDepth * freq * 0.01);

    // FM合成 — ベロシティでモジュレーションインデックスを制御
    modIndex = vel.linlin(0, 1, 0.5, 3.0);
    modulator = SinOsc.ar((freq + vibrato) * 2, 0, modIndex);
    sig = SinOsc.ar(freq + vibrato, modulator);

    // デチューンでテープ風の揺らぎ
    sig = sig + SinOsc.ar((freq + vibrato) * 1.003, 0, 0.15);

    // ベロシティ連動フィルター (高vel = ブライト)
    filtered = RLPF.ar(sig, (cutoff * vel.linlin(0, 1, 0.4, 1.0)).clip(80, 18000),
        resonance.clip(0.01, 1.0));

    // テープサチュレーション
    filtered = (filtered * 1.0).softclip;

    sig = filtered * env * amp;
    sig = Pan2.ar(sig, pan);

    // 出力: メイン + センド
    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
    Out.ar(delayBus, sig * delaySend);
}).add;

// ─── \wurlitzer: グリッティなエレピ + トレモロ ────────────────────────────
// FM合成に非対称クリッピング, 内蔵トレモロ
SynthDef(\wurlitzer, { |freq=440, gate=1, vel=0.8, amp=0.5,
                        attack=0.01, release=0.5, cutoff=8000, resonance=0.3,
                        reverbSend=0.3, delaySend=0.0, pan=0.0,
                        vibRate=5, vibDepth=0,
                        tremRate=5, tremDepth=0.3,
                        outBus=0, reverbBus=0, delayBus=0|
    var env, vibrato, modIndex, sig, filtered, trem;

    env = EnvGen.kr(
        Env.adsr(attack, 0.3, 0.7, release),
        gate, doneAction: Done.freeSelf
    );

    vibrato = SinOsc.kr(vibRate, 0, vibDepth * freq * 0.01);

    // FM合成 — Wurlitzer風のやや歪んだFM
    modIndex = vel.linlin(0, 1, 0.8, 4.0);
    sig = SinOsc.ar(freq + vibrato, SinOsc.ar((freq + vibrato) * 2, 0, modIndex));

    // 非対称クリッピング (Wurlitzer特有のグリッティさ)
    sig = (sig + 0.3).softclip - 0.1;

    // フィルター
    filtered = RLPF.ar(sig, (cutoff * vel.linlin(0, 1, 0.5, 1.0)).clip(80, 18000),
        resonance.clip(0.01, 1.0));

    // トレモロ (amp LFO)
    trem = 1 - (SinOsc.kr(tremRate).range(0, tremDepth));
    filtered = filtered * trem;

    sig = filtered * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
    Out.ar(delayBus, sig * delaySend);
}).add;

// ─── \analogPad: デチューンSaw/Triパッド ──────────────────────────────────
// 4オシレーター + サブオシレーター, ゆっくりしたフィルタースイープ
SynthDef(\analogPad, { |freq=440, gate=1, vel=0.8, amp=0.5,
                        attack=0.3, release=1.5, cutoff=8000, resonance=0.3,
                        reverbSend=0.4, delaySend=0.1, pan=0.0,
                        vibRate=5, vibDepth=0, subLevel=0.3,
                        outBus=0, reverbBus=0, delayBus=0|
    var env, sig, sub, filterLFO, filtered;

    env = EnvGen.kr(
        Env.adsr(attack, 0.5, 0.7, release),
        gate, doneAction: Done.freeSelf
    );

    // 4オシレーター: デチューンしたSaw/Tri
    sig = Saw.ar(freq * 0.997, 0.25)
        + Saw.ar(freq * 1.003, 0.25)
        + LFTri.ar(freq * 0.998, 0, 0.2)
        + LFTri.ar(freq * 1.002, 0, 0.2);

    // サブオシレーター (1オクターブ下)
    sub = SinOsc.ar(freq * 0.5, 0, subLevel);
    sig = sig + sub;

    // フィルタースイープ LFO
    filterLFO = SinOsc.kr(0.15).range(0.6, 1.0);
    filtered = RLPF.ar(sig, (cutoff * filterLFO * vel.linlin(0, 1, 0.5, 1.0)).clip(80, 18000),
        resonance.clip(0.01, 1.0));

    filtered = (filtered * 1.2).softclip;

    sig = filtered * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
    Out.ar(delayBus, sig * delaySend);
}).add;

// ─── \lead: モノフォニックリードシンセ ────────────────────────────────────
// Saw + Pulse, ポルタメント, ブライトフィルター
SynthDef(\lead, { |freq=440, gate=1, vel=0.8, amp=0.5,
                   attack=0.01, release=0.3, cutoff=12000, resonance=0.3,
                   reverbSend=0.2, delaySend=0.2, pan=0.0,
                   vibRate=5, vibDepth=0,
                   portTime=0.1, pulseWidth=0.5,
                   outBus=0, reverbBus=0, delayBus=0|
    var env, lagFreq, vibrato, sig, filtered;

    env = EnvGen.kr(
        Env.adsr(attack, 0.2, 0.9, release),
        gate, doneAction: Done.freeSelf
    );

    // ポルタメント
    lagFreq = Lag.kr(freq, portTime);
    vibrato = SinOsc.kr(vibRate, 0, vibDepth * lagFreq * 0.01);

    // Saw + Pulse ミックス
    sig = Saw.ar(lagFreq + vibrato, 0.5)
        + Pulse.ar(lagFreq + vibrato, pulseWidth, 0.4);

    // ブライトフィルター (高いデフォルトcutoff)
    filtered = RLPF.ar(sig, (cutoff * vel.linlin(0, 1, 0.6, 1.0)).clip(80, 18000),
        resonance.clip(0.01, 1.0));

    filtered = (filtered * 1.3).softclip;

    sig = filtered * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
    Out.ar(delayBus, sig * delaySend);
}).add;

// ─── \grandPiano: グランドピアノ (FM + ハンマーノイズ) ─────────────────────
// FM合成3オペレーター + ハンマーアタック + レジスター別音色変化
// 低音域: 倍音多め・長いディケイ, 高音域: 明るく短いディケイ
SynthDef(\grandPiano, { |freq=440, gate=1, vel=0.8, amp=0.5,
                         attack=0.01, release=0.5, cutoff=8000, resonance=0.3,
                         reverbSend=0.3, delaySend=0.0, pan=0.0,
                         vibRate=5, vibDepth=0,
                         outBus=0, reverbBus=0, delayBus=0|
    var env, decayEnv, vibrato, sig, hammer, filtered;
    var mod1, mod2, mod3, fmIndex, brightness, decayTime;

    // ピアノ的エンベロープ: 速いアタック, レジスター依存のディケイ, 低サステイン
    decayTime = freq.explin(50, 4000, 3.0, 0.5);
    env = EnvGen.kr(
        Env.adsr(attack.min(0.005), decayTime, 0.08, release),
        gate, doneAction: Done.freeSelf
    );

    // 倍音ディケイ（基音より速く減衰 → 自然なピアノの減衰感）
    decayEnv = EnvGen.kr(Env.perc(0.005, decayTime * 0.5, 1.0, -4));

    vibrato = SinOsc.kr(vibRate, 0, vibDepth * freq * 0.01);

    // FMインデックス: ベロシティ × レジスター（低音ほど倍音リッチ）
    brightness = freq.explin(50, 4000, 1.5, 0.5);
    fmIndex = vel.linlin(0, 1, 0.5, 3.0) * brightness;

    // モジュレーター1: 2倍音（オクターブ）
    mod1 = SinOsc.ar((freq + vibrato) * 2, 0, fmIndex * decayEnv);
    // モジュレーター2: 3倍音（5度）
    mod2 = SinOsc.ar((freq + vibrato) * 3, 0, fmIndex * 0.3 * decayEnv);
    // モジュレーター3: 非整数倍音（ベル感）
    mod3 = SinOsc.ar((freq + vibrato) * 7.07, 0, fmIndex * 0.15 * decayEnv);

    // キャリア + わずかなデチューン
    sig = SinOsc.ar(freq + vibrato, mod1 + mod2 + mod3);
    sig = sig + SinOsc.ar((freq + vibrato) * 1.002, mod1 * 0.3, 0.1);

    // ハンマーアタック（短いノイズバースト）
    hammer = BPF.ar(WhiteNoise.ar, (freq * 8).clip(500, 12000), 0.5)
        * EnvGen.kr(Env.perc(0.001, 0.015))
        * vel.linlin(0, 1, 0.02, 0.12);
    sig = sig + hammer;

    // レジスター+ベロシティ連動フィルター
    filtered = RLPF.ar(sig,
        (cutoff * vel.linlin(0, 1, 0.3, 1.0) * freq.explin(50, 4000, 0.6, 1.2)).clip(80, 18000),
        resonance.clip(0.01, 1.0));
    filtered = filtered.softclip;

    sig = filtered * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
    Out.ar(delayBus, sig * delaySend);
}).add;

// ─── \organ: オルガン (加算合成) ──────────────────────────────────────────
// 5倍音加算合成 + キークリック, 速いアタック/ほぼフルサステイン
SynthDef(\organ, { |freq=440, gate=1, vel=0.8, amp=0.5,
                    attack=0.01, release=0.5, cutoff=8000, resonance=0.3,
                    reverbSend=0.3, delaySend=0.0, pan=0.0,
                    vibRate=5, vibDepth=0,
                    outBus=0, reverbBus=0, delayBus=0|
    var env, vibrato, sig, click, filtered;

    env = EnvGen.kr(
        Env.adsr(attack.min(0.005), 0.1, 0.95, release.min(0.01)),
        gate, doneAction: Done.freeSelf
    );

    // ビブラート (レスリー風に利用可能)
    vibrato = SinOsc.kr(vibRate, 0, vibDepth * freq * 0.01);

    // 加算合成 — 5倍音 (基音, 2倍, 3倍, 4倍, 8倍)
    sig = SinOsc.ar(freq + vibrato, 0, 0.5)
        + SinOsc.ar((freq + vibrato) * 2, 0, 0.3)
        + SinOsc.ar((freq + vibrato) * 3, 0, 0.25)
        + SinOsc.ar((freq + vibrato) * 4, 0, 0.15)
        + SinOsc.ar((freq + vibrato) * 8, 0, 0.1);

    // キークリック (短いノイズバースト)
    click = WhiteNoise.ar(0.03) * EnvGen.kr(Env.perc(0.001, 0.01));
    sig = sig + click;

    // LPFフィルター
    filtered = LPF.ar(sig, cutoff.clip(80, 18000));

    sig = filtered * env * amp * vel;
    sig = Pan2.ar(sig, pan);

    // 出力: メイン + センド
    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
    Out.ar(delayBus, sig * delaySend);
}).add;

// ─── \strings: ストリングスアンサンブル ───────────────────────────────────
// 4デチューンSawオシレーター, 遅いアタック, LFOフィルタースイープ
SynthDef(\strings, { |freq=440, gate=1, vel=0.8, amp=0.5,
                      attack=0.01, release=0.5, cutoff=8000, resonance=0.3,
                      reverbSend=0.3, delaySend=0.0, pan=0.0,
                      vibRate=5, vibDepth=0,
                      outBus=0, reverbBus=0, delayBus=0|
    var env, vibrato, sig, filtered;

    env = EnvGen.kr(
        Env.adsr(attack.max(0.2), 0.5, 0.8, release.max(0.5)),
        gate, doneAction: Done.freeSelf
    );

    // ビブラート
    vibrato = SinOsc.kr(vibRate, 0, vibDepth * freq * 0.01);

    // 4デチューンSawオシレーター (ストリングスアンサンブル)
    sig = Saw.ar((freq + vibrato) * 0.995, 0.25)
        + Saw.ar((freq + vibrato) * 0.998, 0.25)
        + Saw.ar((freq + vibrato) * 1.002, 0.25)
        + Saw.ar((freq + vibrato) * 1.005, 0.25);

    // LPF + 遅いLFOスイープ
    filtered = LPF.ar(sig, (cutoff * SinOsc.kr(0.1).range(0.7, 1.0)).clip(80, 18000));

    // ウォームサチュレーション
    filtered = filtered.softclip;

    sig = filtered * env * amp * vel;
    sig = Pan2.ar(sig, pan);

    // 出力: メイン + センド
    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
    Out.ar(delayBus, sig * delaySend);
}).add;

// ─── \guitar: アコースティックギター (カープラス・ストロング) ──────────────
// Pluck.ar物理モデリング, ベロシティでトーン変化, ボディレゾナンス
SynthDef(\guitar, { |freq=440, gate=1, vel=0.8, amp=0.5,
                     attack=0.01, release=0.5, cutoff=8000, resonance=0.3,
                     reverbSend=0.3, delaySend=0.0, pan=0.0,
                     vibRate=5, vibDepth=0,
                     outBus=0, reverbBus=0, delayBus=0|
    var env, vibrato, pluck, body, sig, filtered;

    env = EnvGen.kr(
        Env.adsr(0.001, 0.01, 1.0, release),
        gate, doneAction: Done.freeSelf
    );

    // ビブラート
    vibrato = SinOsc.kr(vibRate, 0, vibDepth * freq * 0.01);

    // カープラス・ストロング合成
    // 低vel = 高coef = ダル, 高vel = 低coef = ブライト
    pluck = Pluck.ar(
        WhiteNoise.ar,
        gate,
        (freq + vibrato).reciprocal,
        (freq + vibrato).reciprocal,
        release.max(1.0),
        coef: vel.linlin(0, 1, 0.5, 0.1)
    );

    // ボディレゾナンス (250Hz付近のBPF)
    body = BPF.ar(pluck, 250, 0.3) * 0.3;
    sig = pluck + body;

    // LPFフィルター
    filtered = LPF.ar(sig, cutoff.clip(80, 18000));

    // サチュレーション
    filtered = filtered.softclip;

    sig = filtered * env * amp;
    sig = Pan2.ar(sig, pan);

    // 出力: メイン + センド
    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
    Out.ar(delayBus, sig * delaySend);
}).add;


// ═══════════════════════════════════════════════════════════════════════════
// ドラム / パーカッション (ワンショット, vel で音色+音量変化)
// 共通キャラクター: テープサチュレーション + ヴァイナルテクスチャ
// ═══════════════════════════════════════════════════════════════════════════

// ─── \kick: ベーシックキック ──────────────────────────────────────────────
// SinOscピッチスイープ, vel→アタックの明るさ+音量
SynthDef(\kick, { |vel=0.8, amp=1.2, outBus=0, reverbBus=0, reverbAmt=0.0, pan=0.0|
    var env, clickEnv, sig, brightness;
    env = EnvGen.kr(Env.perc(0.01, 0.5, 1, -3), doneAction: Done.freeSelf);
    clickEnv = EnvGen.kr(Env.perc(0.001, 0.03));

    brightness = vel.linlin(0, 1, 80, 160);  // vel→ピッチスイープ上端
    sig = SinOsc.ar(XLine.kr(brightness, 42, 0.1)) * env * amp * vel;
    sig = sig + (WhiteNoise.ar(0.1 * vel) * clickEnv * amp);
    sig = (sig * 1.8).softclip;
    sig = LPF.ar(sig, vel.linlin(0, 1, 600, 1200));  // フィルター開放
    sig = sig + (PinkNoise.ar(0.008) * env);
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbAmt);
}).add;

// ─── \snare: スネア ──────────────────────────────────────────────────────
// トーン + ノイズ, vel→ノイズの明るさ+音量
SynthDef(\snare, { |vel=0.8, amp=0.7, outBus=0, reverbBus=0, reverbAmt=0.1, pan=0.0|
    var env, tone, noise, sig, noiseFreq;
    env = EnvGen.kr(Env.perc(0.005, 0.25, 1, -4), doneAction: Done.freeSelf);
    noiseFreq = vel.linlin(0, 1, 600, 1400);  // vel→ノイズBPF周波数

    tone = SinOsc.ar(170) * env * amp * vel * 0.4;
    noise = BPF.ar(WhiteNoise.ar, noiseFreq, 0.9) * env * amp * vel * 0.7;
    sig = tone + noise;
    sig = (sig * 1.4).softclip;
    sig = LPF.ar(sig, vel.linlin(0, 1, 2000, 5000));
    sig = sig + (PinkNoise.ar(0.005) * env);
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbAmt);
}).add;

// ─── \hihat: クローズドハイハット ────────────────────────────────────────
// HPFノイズ, 短いディケイ, vel→カットオフ+音量
SynthDef(\hihat, { |vel=0.8, amp=0.5, outBus=0, reverbBus=0, reverbAmt=0.0, pan=0.0|
    var env, sig, hpFreq;
    env = EnvGen.kr(Env.perc(0.002, 0.06, 1, -8), doneAction: Done.freeSelf);
    hpFreq = vel.linlin(0, 1, 5000, 8000);  // vel→HPFカットオフ

    sig = HPF.ar(WhiteNoise.ar, hpFreq) * env * amp * vel;
    sig = LPF.ar(sig, vel.linlin(0, 1, 7000, 12000));
    sig = (sig * 1.3).softclip;
    sig = sig + (PinkNoise.ar(0.004) * env);
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbAmt);
}).add;

// ─── \openhat: オープンハイハット ────────────────────────────────────────
// HPFノイズ, 長いディケイ, vel→カットオフ+音量
SynthDef(\openhat, { |vel=0.8, amp=0.5, outBus=0, reverbBus=0, reverbAmt=0.05, pan=0.0|
    var env, sig, hpFreq;
    env = EnvGen.kr(Env.perc(0.002, 0.35, 1, -4), doneAction: Done.freeSelf);
    hpFreq = vel.linlin(0, 1, 4000, 7000);

    sig = HPF.ar(WhiteNoise.ar, hpFreq) * env * amp * vel;
    sig = LPF.ar(sig, vel.linlin(0, 1, 6000, 10000));
    sig = (sig * 1.3).softclip;
    sig = sig + (PinkNoise.ar(0.005) * env);
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbAmt);
}).add;

// ─── \lofikick: ローファイバスドラ (ディープバリアント) ───────────────────
// vel→サチュレーション量
SynthDef(\lofikick, { |freq=55, vel=0.8, amp=1.2, outBus=0, reverbBus=0, reverbAmt=0.0, pan=0.0|
    var env, sig, drive;
    env = EnvGen.kr(Env.perc(0.01, 0.6, 1, -3), doneAction: Done.freeSelf);
    drive = vel.linlin(0, 1, 1.5, 2.5);  // vel→サチュレーション

    sig = SinOsc.ar(XLine.kr(freq * 3, freq * 0.8, 0.15)) * env * amp * vel;
    sig = (sig * drive).softclip;
    sig = LPF.ar(sig, vel.linlin(0, 1, 400, 800));
    sig = sig + (PinkNoise.ar(0.01) * env);
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbAmt);
}).add;

// ─── \clap: フィルタードノイズバースト ───────────────────────────────────
// vel→ノイズの明るさ
SynthDef(\clap, { |vel=0.8, amp=0.6, outBus=0, reverbBus=0, reverbAmt=0.1, pan=0.0|
    var env, sig, bpFreq;
    env = EnvGen.kr(
        Env([0, 1, 0, 0.5, 0], [0.001, 0.01, 0.005, 0.18], -4),
        doneAction: Done.freeSelf
    );
    bpFreq = vel.linlin(0, 1, 700, 1200);  // vel→BPF中心周波数

    sig = BPF.ar(WhiteNoise.ar, bpFreq, 0.8) * env * amp * vel;
    sig = (sig * 1.4).softclip;
    sig = LPF.ar(sig, vel.linlin(0, 1, 1800, 4000));
    sig = sig + (PinkNoise.ar(0.005) * env);
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbAmt);
}).add;

// ─── \perc: メタリックパーカッション ─────────────────────────────────────
// vel→倍音レベル (高vel = より金属的)
SynthDef(\perc, { |freq=440, vel=0.8, amp=0.6, outBus=0, reverbBus=0, reverbAmt=0.1, pan=0.0|
    var env, sig, harmonicLevel;
    env = EnvGen.kr(Env.perc(0.002, 0.25, 1, -5), doneAction: Done.freeSelf);
    harmonicLevel = vel.linlin(0, 1, 0.1, 0.35);  // vel→倍音量

    sig = SinOsc.ar(freq, 0, 0.6) + SinOsc.ar(freq * 2.3, 0, harmonicLevel);
    sig = sig + SinOsc.ar(freq * 3.7, 0, harmonicLevel * 0.4);  // 追加倍音
    sig = sig * env * amp * vel;
    sig = (sig * 1.5).softclip;
    sig = LPF.ar(sig, vel.linlin(0, 1, 1500, 3500));
    sig = sig + (PinkNoise.ar(0.006) * env);
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbAmt);
}).add;

// ─── \rimshot: リムショット ──────────────────────────────────────────────
// 短い金属的クリック + トーン, バンドパスフィルター
SynthDef(\rimshot, { |vel=0.8, amp=0.6, outBus=0, reverbBus=0, reverbAmt=0.05, pan=0.0|
    var env, clickEnv, click, tone, sig;
    env = EnvGen.kr(Env.perc(0.001, 0.12, 1, -6), doneAction: Done.freeSelf);
    clickEnv = EnvGen.kr(Env.perc(0.0005, 0.005));

    // 金属的クリック
    click = BPF.ar(WhiteNoise.ar, vel.linlin(0, 1, 1500, 2500), 0.3) * clickEnv * 2;
    // 短いトーン成分
    tone = SinOsc.ar(vel.linlin(0, 1, 700, 1000)) * env * 0.5;

    sig = (click + tone) * amp * vel;
    sig = BPF.ar(sig, 1800, 0.6);
    sig = (sig * 1.5).softclip;
    sig = sig + (PinkNoise.ar(0.003) * env);
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbAmt);
}).add;

// ─── \snap: フィンガースナップ ───────────────────────────────────────────
// 極短ノイズバースト + レゾナントBPF
SynthDef(\snap, { |vel=0.8, amp=0.6, outBus=0, reverbBus=0, reverbAmt=0.1, pan=0.0|
    var env, sig, bpFreq;
    env = EnvGen.kr(Env.perc(0.001, 0.08, 1, -10), doneAction: Done.freeSelf);
    bpFreq = vel.linlin(0, 1, 1800, 3000);  // vel→レゾナントBPF周波数

    sig = WhiteNoise.ar * EnvGen.kr(Env.perc(0.0005, 0.015));
    sig = BPF.ar(sig, bpFreq, 0.15) * 3;  // 狭いBPFで「パチッ」感
    sig = sig + (BPF.ar(WhiteNoise.ar, bpFreq * 0.5, 0.3) * env * 0.2);  // ボディ
    sig = sig * amp * vel;
    sig = (sig * 1.4).softclip;
    sig = sig + (PinkNoise.ar(0.003) * env);
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbAmt);
}).add;


// ═══════════════════════════════════════════════════════════════════════════
// 外部MIDI用シンセ
// ═══════════════════════════════════════════════════════════════════════════

// ─── \tone: ソフトパッド (percussive — 外部デバイス抜き差し安全) ──────────
// 三角波ベース, 深いLPFでこもった暖かさ
// 外部MIDIは物理切断でNoteOffが来ないため Env.perc を使用
SynthDef(\tone, { |freq=440, amp=0.3, attack=0.08, release=0.8,
                   cutoff=8000, reverbSend=0.2, pan=0.0,
                   outBus=0, reverbBus=0|
    var env, sig;

    env = EnvGen.kr(
        Env.perc(attack, release, 1, -3),
        doneAction: Done.freeSelf
    );

    // 三角波風 (わずかなデチューン)
    sig = LFTri.ar(freq * 0.999, 0, 0.5) + LFTri.ar(freq * 1.001, 0, 0.5);
    // 深いLPFでこもらせる
    sig = LPF.ar(sig, (cutoff * 0.3).clip(80, 4000));
    sig = sig * env * amp;
    sig = (sig * 1.2).softclip;
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
}).add;

// ─── \kalimba: カリンバ / 親指ピアノ (percussive) ────────────────────────
// 非整数倍音でコロコロした金属音, Env.percのまま (カリンバの性格に合う)
SynthDef(\kalimba, { |freq=440, amp=0.4, release=1.2, pan=0.0,
                      reverbSend=0.3, outBus=0, reverbBus=0|
    var env, sig, click;

    env = EnvGen.kr(Env.perc(0.001, release, 1, -8), doneAction: Done.freeSelf);

    // 基音 + 非整数倍音 (金属的キャラクター)
    sig = SinOsc.ar(freq, 0, 0.5)
        + SinOsc.ar(freq * 3.01, 0, 0.15)
        + SinOsc.ar(freq * 5.98, 0, 0.06);

    // 短いアタッククリック
    click = WhiteNoise.ar(0.2) * EnvGen.kr(Env.perc(0.0005, 0.008));

    sig = (sig * env * amp) + (click * amp);
    sig = LPF.ar(sig, 5000);
    sig = (sig * 1.2).softclip;
    sig = Pan2.ar(sig, pan);

    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * reverbSend);
}).add;

"synths.scd loaded.".postln;
