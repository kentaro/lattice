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
        MIDIIn.connectAll;
        "MIDI initialized. Connected all devices.".postln;

        // 各モジュールをロード
        thisProcess.interpreter.executeFile(dir +/+ "synths.scd");
        thisProcess.interpreter.executeFile(dir +/+ "midi.scd");

        // MIDI自動再接続 (USBデバイス抜き差し対応)
        // 10秒ごとに新しいMIDIソースを検出して接続
        ~midiReconnect = Task({
            var prevCount = MIDIClient.sources.size;
            loop {
                10.wait;
                MIDIClient.init(verbose: false);
                if (MIDIClient.sources.size != prevCount) {
                    MIDIIn.connectAll;
                    ("MIDI reconnected. Sources: " ++ MIDIClient.sources.size).postln;
                    prevCount = MIDIClient.sources.size;
                };
            };
        }).play;

        "lattice ready.".postln;
    });
)
