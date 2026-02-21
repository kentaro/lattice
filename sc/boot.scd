// boot.scd — Server起動 + MIDIClient.init
(
    var waitForBoot = {
        Server.default.waitForBoot({
            "SuperCollider server booted.".postln;
            MIDIClient.init;
            MIDIIn.connectAll;
            "MIDI initialized. Connected all devices.".postln;

            // 各モジュールをロード
            thisProcess.interpreter.executeFile(
                thisProcess.nowExecutingPath.dirname +/+ "synths.scd"
            );
            thisProcess.interpreter.executeFile(
                thisProcess.nowExecutingPath.dirname +/+ "midi.scd"
            );
            "lattice ready.".postln;
        });
    };

    Server.default.options.numOutputBusChannels = 2;
    Server.default.options.numInputBusChannels = 2;
    Server.default.options.sampleRate = 44100;
    Server.default.options.blockSize = 512;
    Server.default.options.memSize = 65536;

    Server.default.boot;
    waitForBoot.value;
)
