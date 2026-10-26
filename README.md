# Decode

A front-end-only image generation app for iOS, built to be screen-recorded and shared.
There is no model behind it: every "generation" decodes one of a few bundled image sets.

The signature move is the reveal. Instead of the usual blur-to-sharp, each image is
**decoded from binary**: a wavy front of `0`s and `1`s sweeps from top to bottom. The bits
at the front glow blue, the bits behind it take on the picture's own colours (so you can
already read the image while it's still made of digits), and the real pixels fade in last.

## The app

| Screen | What it does |
| --- | --- |
| **Splash** | Logo mark spins in, the wordmark types itself through flickering bits. |
| **Onboarding** | Three pages; each picture decodes as its page comes into view. Skippable. |
| **Create** | Dotted canvas of white "folder" boards. The first is your moodboard. Each generation cables in from the previous board, its title scrambles in, and the images decode one after another with a light haptic each. |
| **Composer** | Dark frosted-glass panel: prompt, moodboard toggle, working menus for image count (1/2/4), style and aspect ratio (3:4, 1:1, 9:16), **Enhance** (types extra style words into your prompt), the credit cost and send. Suggestion chips float above it. |
| **Navigation** | The tab bar is hidden so recordings show only the canvas. The ☰ glass button (top left) switches between Create, Explore, Library and Profile, and has New canvas and Play demo. Content blurs progressively under the top bar and composer. |
| **Detail** | Zooms in from the tile (iOS 18 zoom transition). **Re-decode** replays the sweep full size, **Upscale 2×** replays it with finer bits and badges the result. Remix, Vary, Share, Save, Favourite, and long-press the prompt to copy it. |
| **Explore** | Community feed in a two-column masonry, filter chips, made-up creators and like counts. Tiles decode in the first time they appear. |
| **Library** | Everything you've generated, grouped by day, with an All / Favourites switch. |
| **Profile** | Stats, credits meter, settings (haptics, decode speed, decode Explore tiles) and demo controls. |
| **Paywall** | "Decode Pro" sheet. Purely cosmetic; it flips the account to Pro and tops up credits. It also opens when you run out of credits or tap the credit pill. |

Generating costs one credit per image, the same as a real app would charge. **New canvas** (in the ☰ menu or the `…` menu on Create) clears the board for another take.

## Run it

You need a Mac with Xcode 16 or later (Xcode 26 recommended) and an iOS 18+ simulator.

**First time** (clone, then build and launch in the simulator):

```sh
git clone https://github.com/nodedesignagency/image-gen.git ~/image-gen && cd ~/image-gen && git checkout claude/affectionate-galileo-lrgc2w && ./scripts/run.sh
```

**After that** (pull the latest and run):

```sh
cd ~/image-gen && git fetch origin && git checkout claude/affectionate-galileo-lrgc2w && git pull && ./scripts/run.sh
```

`scripts/run.sh` builds the app, boots a simulator (reusing one that's already open, otherwise the
newest iPhone Pro), installs and launches. Options:

| Command | Does |
| --- | --- |
| `./scripts/run.sh --demo` | Launch straight into the hands-free demo |
| `./scripts/run.sh --fresh` | Reinstall from scratch, so onboarding shows again |
| `SIM="iPhone 16 Pro" ./scripts/run.sh` | Use a specific simulator |

To run from Xcode instead, open `Decode.xcodeproj`, pick a simulator and press ⌘R. For a physical
iPhone, choose your team under *Signing & Capabilities* first.

The project uses a synced folder, so any file you add inside `Decode/` is picked up automatically.

## Recording a demo

**Hands-free:** ☰ → **Play demo**. The app types a prompt, generates, enhances a second
prompt, generates again in a different style and ratio, opens a result and re-decodes it, favourites it,
then tours Explore, Library and Profile. It takes about 45 seconds.

To start that from launch, including onboarding, pass the launch argument `-autopilot YES`
(*Product → Scheme → Edit Scheme → Run → Arguments*), or use the simulator directly:

```sh
xcrun simctl launch booted com.nodedesign.decode -autopilot YES
xcrun simctl io booted recordVideo --codec=h264 demo.mp4   # Ctrl-C to stop
```

**By hand:** start from **New canvas**, tap a suggestion chip, generate, then generate again with a
different style. For a close-up, open an image and tap **Re-decode** or **Upscale 2×**.

### CI recording

`.github/workflows/simulator.yml` builds the app on a macOS runner, runs the autopilot in an
iPhone simulator, and uploads `decode-demo.mp4` plus screenshots as the `simulator-output`
artifact on each push to the working branch. You can also trigger it from the Actions tab.

## Using your own images

Images live in `Decode/Assets.xcassets/Photos`.

- `ref-1` … `ref-4` are the moodboard.
- Each preset in `Decode/Model/Preset.swift` uses `<id>-1` … `<id>-4`, for example `golden-1`.
- Explore reuses the same images; creators, likes and captions are in `Decode/Model/Feed.swift`.

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
| `duration` (in `Studio.run`) | Sweep length per image: 2.4s, scaled by the decode-speed setting |

Colours live in `Decode/App/Theme.swift`.

## Layout

```
Decode/
  App/        entry point, root (splash, onboarding, tabs), theme
  Model/      Studio (state + fake generation timeline), presets, feed, autopilot
  Effect/     the binary reveal: math, colour sampling, renderer
  Views/      Create, Explore, Library, Profile, Onboarding, Detail, shared components
  Assets.xcassets/
```

Photo credits are in [CREDITS.md](CREDITS.md).
