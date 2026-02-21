# lattice

汎用SuperColliderシンセ。任意のMIDIデバイスを接続すれば音が出る楽器。

## 動作環境

- Raspberry Pi (pi02, aarch64, Debian 12)
- SuperCollider 3.13.0
- PulseAudio

## 起動

```bash
bash bin/lattice
```

## コントロール仕様 (Launchkey Mini MK4 25)

| コントロール | MIDI ch | メッセージ | 割り当て |
|-------------|---------|-----------|---------|
| 鍵盤 25鍵   | ch1     | NoteOn/Off | `\piano` シンセ |
| パッド 4×4  | ch10    | NoteOn/Off | Note 36-51 → ドラム/パーカッション |
| ノブ×8      | ch16    | CC 21-28   | グローバルパラメーター |
| Modストリップ | ch1   | CC 1       | Piano detune/vibrato |
| ピッチベンド | ch1    | Pitch Bend | ±2半音 |

### ノブマッピング

| ノブ | CC | 割り当て |
|-----|-----|---------|
| 1   | 21  | Filter Cutoff |
| 2   | 22  | Filter Resonance |
| 3   | 23  | Attack |
| 4   | 24  | Release |
| 5   | 25  | Reverb Amount |
| 6   | 26  | Detune (コーラス感) |
| 7   | 27  | LFO Rate |
| 8   | 28  | LFO Depth |

### パッドマッピング

| Note | パッド | 音色 |
|------|--------|------|
| 36   | 下段 L  | Kick |
| 37   | 下段    | Snare |
| 38   | 下段    | HiHat |
| 39   | 下段 R  | Open HiHat |
| 40   | 2段 L  | Tom Low |
| 41   | 2段     | Tom Mid |
| 42   | 2段     | Tom High |
| 43   | 2段 R  | Clap |
| 44-47 | 3段   | Perc 1-4 |
| 48-51 | 上段   | FX 1-4 |

## 他MIDIデバイスとの接続

ch1/ch10/ch16 以外のチャンネルのNoteOn/Off は `\tone`（SinOscベース）で発音。
gol-synth などの外部デバイスをそのまま接続できる。

## ディレクトリ構成

```
lattice/
├── sc/
│   ├── main.scd    # エントリーポイント
│   ├── boot.scd    # Server起動 + MIDI init
│   ├── synths.scd  # SynthDef群
│   └── midi.scd    # MIDI受信ハンドラー
└── bin/
    └── lattice     # 起動スクリプト
```
