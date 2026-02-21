// boot.scd — Server起動 + MIDIClient.init
(
    // async コールバック内では nowExecutingPath が nil になるため、先にキャプチャ
    var dir = thisProcess.nowExecutingPath.dirname;

    Server.default.options.numOutputBusChannels = 2;
    Server.default.options.numInputBusChannels = 0;
    Server.default.options.sampleRate = 44100;
    Server.default.options.blockSize = 1024;
    Server.default.options.memSize = 65536;
    // hw:1 = HDMI on Raspberry Pi (hw:0 is headphone jack)
    Server.default.options.device = "hw:1,0";

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
