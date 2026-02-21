// boot.scd — Server起動 + MIDIClient.init
(
    // async コールバック内では nowExecutingPath が nil になるため、先にキャプチャ
    var dir = thisProcess.nowExecutingPath.dirname;

    Server.default.options.numOutputBusChannels = 2;
    Server.default.options.numInputBusChannels = 0;
    Server.default.options.sampleRate = 48000;
    Server.default.options.blockSize = 1024;
    Server.default.options.memSize = 65536;

    Server.default.waitForBoot({
        "SuperCollider server booted.".postln;
        MIDIClient.init;
        // MIDIIn.connectAll はソース数が多いとIndex out of rangeになるため
        // 個別に安全に接続する
        MIDIClient.sources.do { |src, i|
            try {
                MIDIIn.connect(i, src);
            } { |err|
                ("MIDI connect skipped: " ++ src.device).postln;
            };
        };
        "MIDI initialized.".postln;

        // 各モジュールをロード
        thisProcess.interpreter.executeFile(dir +/+ "synths.scd");
        thisProcess.interpreter.executeFile(dir +/+ "midi.scd");

        "lattice ready.".postln;
    });
)
