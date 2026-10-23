# Decode

A front-end-only image generation app for iOS, built to be screen-recorded and shared.
There is no model behind it: every "generation" decodes one of a few bundled image sets onto the canvas.

The signature move is the reveal. Instead of the usual blur-to-sharp, each image is
**decoded from binary**: a wavy front of `0`s and `1`s sweeps from top to bottom. The bits
at the front glow blue, the bits behind it take on the picture's own colours (so you can
already read the image while it's still made of digits), and the real pixels fade in last.

## What's on screen

- **Canvas**: a dotted, node-editor-style background with white "folder" boards. Each board has
  a label tab that flares into the card.
- **Moodboard**: the first board, holding four reference images.
- **Composer**: suggestion chips, a prompt field, setting chips (moodboard / 4 / 3:4) and a round
  black generate button. While it works, the button shows a rolling binary readout.
- **Generate**: a cable draws from the previous board to a new one, the empty cells pop in,
  the title types itself in through flickering bits, then the four images decode one after
  another, with a light haptic as each one lands. Accent dots stream along the cable while it works.
- **Detail**: tap a finished image to zoom into it (iOS 18 zoom transition). **Re-decode** replays the
  sweep full-screen with larger glyphs, which is the best shot for recordings. Share and Save also work.
- **New canvas** (the `…` menu) resets everything for the next take.

## Run it

1. Open `Decode.xcodeproj` in Xcode 16 or later.
2. Select the **Decode** target, go to *Signing & Capabilities*, and pick your team.
   Change the bundle identifier if Xcode asks you to.
3. Run on an iPhone or simulator with iOS 18+.

The project uses a synced folder, so any file you add inside `Decode/` is picked up automatically.

## Recording tips

- Start from **New canvas**, tap a suggestion chip, then generate. A full sequence takes about 4 seconds.
- Generate two or three times in a row to show the chain of cabled boards.
- For a close-up, open an image and tap **Re-decode**.
- iOS screen recording captures at device resolution; crop to 4:5 for feeds or keep 9:16 for stories and reels.

## Using your own images

Images live in `Decode/Assets.xcassets/Photos`.

- `ref-1` … `ref-4` are the moodboard.
- Each preset in `Decode/Model/Preset.swift` uses `<id>-1` … `<id>-4`, for example `golden-1`.

Replace the JPGs (3:4 portrait, about 900×1200, works best), or add a new preset with its own id,
title, prompt and keywords. Typed prompts are matched to a preset by keyword; anything that doesn't
match cycles through the presets in order. Tapping a suggestion chip always uses that preset.

## Tuning the effect

The reveal is drawn in `Decode/Effect/DecodingImage.swift`, and the numbers that shape it are in `Decode/Effect/DecodeMath.swift`:

| Constant | What it changes |
| --- | --- |
| `band` | Height of the coloured-bits band behind the front |
| `jitter` | How wavy the front is |
| `columnWidth`, `rowHeight`, `fontSize` | Glyph size and density |
| `duration` (in `Studio.run`) | Sweep length per image, 2.4s by default |

Colours live in `Decode/App/Theme.swift`.

## Layout

```
Decode/
  App/        entry point, theme colours
  Model/      Studio (state + fake generation timeline), presets
  Effect/     the binary reveal: math, colour sampling, renderer
  Views/      canvas, boards, cable, composer, detail screen
  Assets.xcassets/
```

Photo credits are in [CREDITS.md](CREDITS.md).
