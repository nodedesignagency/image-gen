# Decode: working notes for Claude

Front-end-only SwiftUI image-generation app, built for screen-recorded social videos. No model:
"generating" decodes bundled photo sets. The signature effect is the **binary reveal**: images
decode top-to-bottom from 0s and 1s (blue front, bits tinted with the image's colours, pixels fade
in behind). It runs entirely in a Metal shader (`decodeReveal` in `Effect/Shaders.metal`, driven
by `Effect/DecodingImage.swift`): glyphs are distance fields, colours are sampled from the image,
and the CPU only supplies a clock. See README.md for the feature tour.

## Rules for every update

- **End every update by giving the user the pull-and-run command**, ready to paste:
  `cd ~/image-gen && git pull && ./scripts/run.sh`
- Work on branch `claude/affectionate-galileo-lrgc2w` (also the repo's default branch). Push there.
- **Never tell the user to pull before CI has compiled the commit.** There is no Xcode in the cloud
  container. After pushing, wait for the `Build, boot and install (scripts/run.sh)` step of the
  `Simulator` workflow to succeed (poll `https://api.github.com/repos/nodedesignagency/image-gen/actions/runs?branch=claude/affectionate-galileo-lrgc2w`
  then `/actions/runs/<id>/jobs`; the repo is public so no auth is needed). Commits that only touch
  `*.md` don't trigger CI.
- Before pushing, syntax-check every Swift file with `swiftc -parse` (download the Linux toolchain
  `swift-6.1.2-RELEASE-ubuntu24.04` from download.swift.org into the scratchpad if it isn't there).
- To *see* the app: the CI job records the hands-free demo (`-autopilot YES -edgeLens YES`) on an
  iPhone simulator and uploads `simulator-output` (decode-demo.mp4, app-log.txt, build.log). Get it
  with the GitHub MCP tool `actions_get` → `download_workflow_run_artifact`, curl the returned URL,
  and pull frames with ffmpeg. The CI simulator is much slower than the user's Mac.
- The user is a designer. Keep replies short, plain, visual. They usually send screenshots or
  screen recordings from their Mac (iPhone 18 Pro simulator, iOS 27, Xcode 26+).

## Hard-won gotchas

- **Never put Metal effects (`distortionEffect`, `layerEffect`, `colorEffect`) on a `ScrollView`**
  or anything UIKit-backed: it renders blank. Apply them to content inside, e.g. via `visualEffect`.
- Scroll ids must differ from `ForEach` row identity, or `scrollTo` lands on the row's first child.
- Don't derive safe-area padding from a measured overlay's height (feedback loop moved the
  composer). Use `contentMargins(_, for: .scrollContent)`.
- `scripts/run.sh` runs on macOS's bash 3.2: brace variables next to non-ASCII (`"${NAME}…"`),
  guard empty arrays under `set -u`.
- Liquid Glass / iOS 26 APIs must sit inside `#if compiler(>=6.2)` + `if #available(iOS 26.0, *)`.
- `VariableBlur` uses Core Animation's private `variableBlur` filter (fine for this demo, not App
  Store-safe) and must re-apply its filter in `layoutSubviews`.
- Performance matters to the user ("feels heavy"). Avoid anything that re-blurs or re-rasterises
  large areas every frame, and never draw per-frame animation with `Canvas` text (the old decode
  drew ~1400 glyphs a frame and ran at 20 fps on the user's Mac). Put per-frame effects in
  `Shaders.metal`. Profile has a **Reduce effects** switch that turns glass, blur, lights and
  lens into flat fills.
- Image JPEGs and ambient palettes are pre-warmed off the main thread in `Studio.generate()`.
- Measuring smoothness: a QuickTime recording of the simulator at 60 fps has duplicate frames
  where the app stalled; count unique frames per half second (numpy over `ffmpeg -f rawvideo`).
  The baseline before the shader rewrite was 9–12 unique per half second during a decode.
- Shadows go on still shapes *behind* live content (`FolderShape` behind boards, a filled shape
  behind decoding images), never on the content itself, or the whole view is re-rendered and
  re-blurred on every decode frame.
- The CI simulator can't measure performance: identical screens vary 2× in frame rate between
  runs, and an A/B with every effect off showed no consistent difference. Judge "heavy" on the
  user's Mac.

## Design decisions the user has made

- **Dark smoked glass** for floating UI: Liquid Glass tinted black (`smokedGlass`, `glassChrome` in
  `Views/Common/EdgeBar.swift`). Light painted gradients were rejected as "not glass". References:
  dark prompt boxes with a top-left glow and light rim; Perplexity's composer layout.
- Glass needs something behind it: `AmbientWash` paints static soft lights from the latest board's
  colours behind the canvas edges.
- Composer: roomy 2-line prompt, round moodboard + enhance buttons, plain mono pills for model
  (`decode-2`, `decode-2-pro` costs 2 credits, `decode-lite`) and style, light send button.
  **The row never scrolls** (user hated the clipped pills); it is sized so the longest names fit.
  Floats ~10pt above the bottom edge with screen-concentric bottom corners.
- Metadata is shown as small chips (`MetaChip`, Framer-property style: grey fill on cards, white
  on the canvas, accent while live) in a wrapping `ChipFlow`, never a horizontal scroll.
- **Output is always 4 square (1:1) images** so the whole 2×2 decodes on screen in recordings.
- **Tab bar hidden.** The ☰ glass button (top left) is the navigation (Create / Explore / Library /
  Profile, New canvas, Play demo). No logo in the Create header.
- Short progressive blur under the top bar only (status bar + header).
- **Edge lens** (on by default): boards are magnified toward the edge as they leave the screen,
  under the header and under the composer: content stretches along the scroll axis, the sides
  flare out, and it smears along the stretch (`View.edgeLens` in `Effect/EdgeLens.swift`, a
  `layerEffect` in `Shaders.metal`). Per board but computed in screen space; cables are *not*
  lensed (a thin line through it read as a blob). Reference: a carousel where cards stretch and
  blur into the screen edges like thick glass. Bands reach ~70pt past the header and ~50pt above
  the composer; stretch is 0.34 of the band, widen 0.14, smear 0.08.
- Typography: SF for prose, SF Mono for machine values (counts, model ids, seeds, prices, timers,
  bits). Use the named scale in `App/Theme.swift` (`.display`, `.screenTitle`, `.heading`,
  `.prose`, `.button`, `.label`, `.chip`, `.supporting`, `.note`, `.micro`; `.monoStat`,
  `.monoValue`, `.monoMeta`, `.monoBadge`); `Font.mono(_:)` / `Font.sans(_:)` only for one-offs
  like the wordmark.

## Open items

- Confirm on the user's Mac that the shader decode runs smoothly (ask for a 10 s recording and
  count unique frames). Remaining known hitch: ~200 ms when generate is tapped (glass composer
  resizing as the suggestions hide, new board + cable appearing).
- Lens tuning against the reference (strength, band size, bottom edge) is new and unreviewed.
- The user wants the whole thing to look premium for a client-facing post: keep polishing
  typography and spacing wherever a screenshot shows something rough.

## Layout

```
Decode/
  App/       DecodeApp, RootView (splash → onboarding → hidden-tab TabView), Theme
  Model/     Studio (state + fake generation timeline), Preset, Feed, Options, Autopilot
  Effect/    DecodeMath, DecodingImage, ImagePalette, DecodeOnce, VariableBlur, AmbientWash, Shaders.metal
  Views/     Create (CreateView, BoardView, Cable, Composer), Explore, Library, Profile, Onboarding, Detail, Common
scripts/run.sh                  build + boot simulator + install + launch (--demo, --fresh, SIM=)
.github/workflows/simulator.yml CI build + autopilot recording
```
