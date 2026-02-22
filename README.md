# lattice

Launchkey Mini MK4 25 用 SuperCollider シンセ。8プリセット切替、エフェクトチェーン、サスティンペダル対応。

## 動作環境

- Raspberry Pi (pi02, aarch64, Debian 12)
- SuperCollider 3.13.0
- PipeWire (JACK bridge)

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

MIDI接続は `MIDIIn.connectAll` のみ（aconnect 不使用）。DAW In ポートの重複イベントは srcID フィルタで除外。

## 鍵盤（25キー, ch1）

- **NoteOn** → 現在のプリセットで発音（gate-based ADSR — 押し続ける限りサスティン）
- **NoteOff** → ADSR リリースで自然に減衰（`.set(\gate, 0)`）
- **サスティンペダル (CC64)** → ペダル中は離した鍵も鳴り続ける。ペダルオフで全解放
- **アフタータッチ** → フィルターカットオフ変調（押し込むほどブライト）
- **Mod ストリップ (CC1)** → ビブラート深度
- **ピッチベンド** → ±2半音

## パッドレイアウト（2行×8列, ch10）

左4列がドラム、右4列がプリセット切替。各列 bottom=N, top=N+4。

```
         左4列(ドラム)                        右4列(プリセット)
Top:   [40 Lofi] [41 Rim]  [42 Snap] [43 Perc]   [48 Pad]   [49 Lead]  [50 Str]   [51 Guitar]
Bot:   [36 Kick] [37 Snare][38 HH]   [39 OH]     [44 Grand] [45 Rhodes][46 Wurli]  [47 Organ]
```

### プリセット（右8パッド）

| Note | プリセット | 特徴 |
|------|-----------|------|
| 44   | **Grand Piano** (デフォルト) | FM 3オペレータ+ハンマーノイズ、レジスター別音色変化 |
| 45   | **Rhodes** | FM電子ピアノ、テープ風の揺らぎ |
| 46   | **Wurlitzer** | グリッティなFM、内蔵トレモロ |
| 47   | **Organ** | 加算合成5倍音、キークリック |
| 48   | **Analog Pad** | 4オシレータ+サブ、スローフィルタースイープ |
| 49   | **Lead** | Saw+Pulse、ポルタメント |
| 50   | **Strings** | デチューンSaw×4、スローアタック、アンサンブル |
| 51   | **Guitar** | Karplus-Strong、ベロシティで明るさ変化 |

切替時に現在の全ボイスをリリースしてから切り替わる。

### ドラム（左8パッド）

ベロシティが音量だけでなく**音色に影響**（強く叩く→ブライト）。

| Note | 音色 | Note | 音色 |
|------|------|------|------|
| 36   | Kick | 40   | LofiKick (55Hz) |
| 37   | Snare | 41   | Rimshot |
| 38   | HiHat (closed) | 42   | Snap |
| 39   | HiHat (open) | 43   | Metallic Perc |

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
│   ├── boot.scd       # Server起動 + バス/グループ + MIDIIn.connectAll + FXインスタンス
│   ├── synths.scd     # SynthDef群 (Grand/Rhodes/Wurli/Organ/Strings/Guitar/Pad/Lead/ドラム/Tone/Kalimba)
│   ├── effects.scd    # FX SynthDef群 (ReverbFX/DelayFX/MasterFX)
│   └── midi.scd       # MIDIハンドラー + ボイス管理
└── bin/
    └── lattice        # 起動スクリプト (pw-jack + sclang)
```
