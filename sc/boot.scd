// boot.scd — Server起動 + MIDIClient.init
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

        // サーバー起動後にMIDI初期化（ポートマッピング安定後）
        MIDIClient.init;
        MIDIIn.connectAll;
        "MIDI connectAll done.".postln;

        // 各モジュールをロード
        thisProcess.interpreter.executeFile(dir +/+ "synths.scd");
        thisProcess.interpreter.executeFile(dir +/+ "midi.scd");

        "lattice ready.".postln;
    });
)
