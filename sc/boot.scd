// boot.scd — Server起動 + バス/グループ + MIDIClient.init
(
    var dir = thisProcess.nowExecutingPath.dirname;

    Server.default.options.numOutputBusChannels = 2;
    Server.default.options.numInputBusChannels = 0;
    Server.default.options.sampleRate = 48000;
    Server.default.options.blockSize = 1024;
    Server.default.options.memSize = 65536;
    Server.default.options.maxNodes = 8192;

    Server.default.waitForBoot({
        "SuperCollider server booted.".postln;

        // ─── ステレオバス割り当て ─────────────────────────────────────────
        ~kbBus      = Bus.audio(s, 2);  // キーボードシンセ出力
        ~drumBus    = Bus.audio(s, 2);  // ドラム出力
        ~toneBus    = Bus.audio(s, 2);  // 外部MIDI出力
        ~reverbSend = Bus.audio(s, 2);  // リバーブセンド
        ~delaySend  = Bus.audio(s, 2);  // ディレイセンド
        ~fxBus      = Bus.audio(s, 2);  // FXリターン（リバーブ+ディレイ混合）
        "Buses allocated.".postln;

        // ─── グループ（実行順序保証）─────────────────────────────────────
        ~kbGroup     = Group.new(s);
        ~drumGroup   = Group.after(~kbGroup);
        ~toneGroup   = Group.after(~drumGroup);
        ~fxGroup     = Group.after(~toneGroup);
        ~masterGroup = Group.after(~fxGroup);
        "Groups created.".postln;

        // ─── MIDI初期化 ──────────────────────────────────────────────────
        MIDIClient.init;
        MIDIIn.connectAll;
        "MIDI connectAll done.".postln;

        // ─── 各モジュールをロード ────────────────────────────────────────
        thisProcess.interpreter.executeFile(dir +/+ "synths.scd");
        s.sync;  // SynthDef登録完了を保証（effects.scdでSynth生成する前に必須）
        thisProcess.interpreter.executeFile(dir +/+ "effects.scd");
        thisProcess.interpreter.executeFile(dir +/+ "midi.scd");

        "lattice ready.".postln;
    });
)
