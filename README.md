# lattice

Launchkey Mini MK4 25 用 SuperCollider シンセ。4プリセット切替、エフェクトチェーン、サスティンペダル対応。

## 動作環境

- Raspberry Pi (pi02, aarch64, Debian 12)
- SuperCollider 3.13.0
- PulseAudio / PipeWire

## 起動

```bash
bash bin/lattice
# または
systemctl --user restart lattice
```

## アーキテクチャ

```
[鍵盤]  → kbBus ──────┬──→ reverbSend ──→ [ReverbFX] ──→ fxBus ─┐
                       └──→ delaySend  ──→ [DelayFX]  ──→ fxBus ─┤
[ドラム] → drumBus ────┤                                          │
[外部]   → toneBus ────┤                                          │
                       └──────────────────────────────────────────┘
                                                                   │
                                    [MasterFX: Tape → Limiter]
                                             ↓
                                      Hardware Out (0-1)
```

5つの Group で実行順序を保証: kbGroup → drumGroup → toneGroup → fxGroup → masterGroup

## 鍵盤（25キー, ch1）

- **NoteOn** → 現在のプリセットで発音（gate-based ADSR — 押し続ける限りサスティン）
- **NoteOff** → ADSR リリースで自然に減衰（`.set(\gate, 0)`）
- **サスティンペダル (CC64)** → ペダル中は離した鍵も鳴り続ける。ペダルオフで全解放
- **アフタータッチ** → フィルターカットオフ変調（押し込むほどブライト）
- **Mod ストリップ (CC1)** → ビブラート深度
- **ピッチベンド** → ±2半音

## プリセット切替（パッド上段, ch10 note 48-51）

| パッド | Note | プリセット | 特徴 |
|--------|------|-----------|------|
| 左     | 48   | **Rhodes** (デフォルト) | FM電子ピアノ、ベロシティで明るさ変化 |
| 左中   | 49   | **Wurlitzer** | グリッティなFM、内蔵トレモロ |
| 右中   | 50   | **Analog Pad** | 4オシレータ+サブ、スローフィルタースイープ |
| 右     | 51   | **Lead** | Saw+Pulse、ポルタメント |

切替時に現在の全ボイスをリリースしてから切り替わる。

## ドラム（パッド下3段, ch10 note 36-47）

ベロシティが音量だけでなく**音色に影響**（強く叩く→ブライト）。

| Note | 音色 | Note | 音色 |
|------|------|------|------|
| 36   | Kick | 40   | LofiKick (55Hz) |
| 37   | Snare | 41   | Rimshot |
| 38   | HiHat (closed) | 42   | LofiKick (65Hz) |
| 39   | HiHat (open) | 43   | Snap |
| 44-47 | Metallic Perc (ピッチ可変) | | |

## ノブ — 2ページ（上下ボタンで切替）

Launchkey の Custom Encoder Mode を使用。上下ボタン（Encoder Bank Next/Previous）でページ切替。
Novation Components で Custom Encoder Mode 1 に Page 1: CC21-28 / Page 2: CC29-36 を設定すること。

### Page 1: Sound (CC21-28)

| ノブ | CC | パラメーター | 範囲 |
|------|-----|------------|------|
| 1 | 21 | Cutoff | 80-18000Hz (exp) |
| 2 | 22 | Resonance | 0.01-0.99 |
| 3 | 23 | Attack | 0.001-2.0s (exp) |
| 4 | 24 | Release | 0.05-5.0s (exp) |
| 5 | 25 | Reverb Send | 0-1 |
| 6 | 26 | Delay Send | 0-1 |
| 7 | 27 | Tape Drive | 0-1 |
| 8 | 28 | Master Volume | 0-1 |

### Page 2: FX (CC29-36)

| ノブ | CC | パラメーター | 範囲 |
|------|-----|------------|------|
| 1 | 29 | Reverb Size | 0.1-1.0 |
| 2 | 30 | Reverb Damp | 0-1 |
| 3 | 31 | Delay Time | 0.05-1.0s (exp) |
| 4 | 32 | Delay Feedback | 0-0.9 |
| 5 | 33 | LFO Rate | 0.1-20Hz (exp) |
| 6 | 34 | LFO Depth | 0-1 |
| 7 | 35 | (reserved) | — |
| 8 | 36 | (reserved) | — |

## 外部MIDIデバイス

| チャンネル | シンセ | 方式 |
|-----------|--------|------|
| ch1 (Launchkey) | 現在のプリセット | gate-based ADSR |
| ch10 | ドラム / プリセット切替 | ワンショット |
| ch16 | Kalimba | パーカッシブ (fire-and-forget) |
| その他 | Tone (三角波パッド) | パーカッシブ (fire-and-forget) |

gol-synth 等の外部デバイスはそのまま接続可能（NoteOnで発音、自然に減衰）。

## ディレクトリ構成

```
lattice/
├── sc/
│   ├── main.scd       # エントリーポイント
│   ├── boot.scd       # Server起動 + バス/グループ + FXインスタンス
│   ├── synths.scd     # SynthDef群 (Rhodes/Wurli/Pad/Lead/ドラム/Tone/Kalimba)
│   ├── effects.scd    # FX SynthDef群 (ReverbFX/DelayFX/MasterFX)
│   └── midi.scd       # MIDIハンドラー + ボイス管理
└── bin/
    └── lattice        # 起動スクリプト (JACK + sclang)
```
