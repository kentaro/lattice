// main.scd — エントリーポイント
// Usage: sclang sc/main.scd

(
    var dir = thisProcess.nowExecutingPath.dirname;
    "lattice starting...".postln;
    ("Directory: " ++ dir).postln;

    thisProcess.interpreter.executeFile(dir +/+ "boot.scd");
)
