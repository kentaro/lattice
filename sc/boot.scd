// boot.scd — Server起動 + MIDIClient.init
(
    // async コールバック内では nowExecutingPath が nil になるため、先にキャプチャ
    var dir = thisProcess.nowExecutingPath.dirname;

    Server.default.options.numOutputBusChannels = 2;
    Server.default.options.numInputBusChannels = 0;
    Server.default.options.sampleRate = 44100;
    Server.default.options.blockSize = 1024;
    Server.default.options.memSize = 65536;
    // device は設定しない → jackd は ~/.jackdrc を読む (hw:1 = HDMI)

    Server.default.waitForBoot({
        "SuperCollider server booted.".postln;
        MIDIClient.init;
        MIDIIn.connectAll;
        "MIDI initialized. Connected all devices.".postln;

        // 各モジュールをロード
        thisProcess.interpreter.executeFile(dir +/+ "synths.scd");
        thisProcess.interpreter.executeFile(dir +/+ "midi.scd");
        "lattice ready.".postln;
    });
)
