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
- **No backdrop blurs of any kind**: no Liquid Glass (`glassEffect`), no materials
  (`.ultraThinMaterial`), no private `variableBlur`. In the simulator they re-render on every
  frame content moves beneath them; with them on the user's Mac a scroll ran at ~10 fps and a
  decode at ~20. Glass is painted (`SmokedTint`: charcoal tint, top-left glow, rim) and the top bar
  is a fade into the canvas (`edgeBar`). Over the soft ambient lights the tint reads as glass.
- Performance matters to the user ("feels heavy"). Avoid anything that re-blurs or re-rasterises
  large areas every frame, and never draw per-frame animation with `Canvas` text (the old decode
  drew ~1400 glyphs a frame and ran at 20 fps on the user's Mac). Put per-frame effects in
  `Shaders.metal`. Profile has a **Reduce effects** switch that turns glass, blur, lights and
  lens into flat fills.
- Image JPEGs and ambient palettes are pre-warmed off the main thread in `Studio.generate()`.
- **Nothing expensive may touch the decoding board or sit behind every blur during a decode.**
  Two regressions came from exactly this: a bottom-edge lens band that caught the decoding board
  (whole board through a 21-sample shader every frame), and the ambient lights cross-fading as a
  decode started (behind all five blurs). The lens is top-edge only, the lights change at `.done`,
  and header chrome (`glassChrome`) has no backdrop blur of its own (it sits on the header's
  progressive blur), so only the composer and the header blur sample the backdrop.
- Camera: `ScrollPosition.scrollTo(edge: .bottom)` as soon as a board is appended, with a bottom
  content margin that stays fixed while generating (panel height + `Composer.suggestionsHeight`).
  A margin that changed mid-scroll (suggestions hiding) cut the camera short.
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

- **Dark smoked glass** for floating UI (`smokedGlass`, `glassChrome` in
  `Views/Common/EdgeBar.swift`): a translucent charcoal tint with a top-left glow and light rim,
  painted (no blur, see gotchas). *Light* painted gradients were rejected as "not glass".
- Glass needs something behind it: `AmbientWash` paints static soft lights from the latest board's
  colours behind the canvas edges.
- Composer, structured after a reference the user loves (attach · grouped icon segment · model
  pill · send): round moodboard button, one outlined pill grouping the icon actions (enhance,
  style), one model pill with the Decode mark in white (the user disliked the blue square there)
  and the model's *name* in SF ("Decode 2.1", like
  "GPT 5.0"; also "Decode 2.1 Pro" at 2 credits, "Decode 2.1 Lite"), light send button. Slugs
  (`decode-2.1`) only appear in metadata chips. **The row never scrolls** and the user rejected
  two text pills side by side. Floats ~10pt above the bottom edge with screen-concentric corners.
- Credits use a coin (`CreditCoin`), not a sparkle: the user said the sparkle "looks like AI".
- Metadata is shown as small chips (`MetaChip`, Framer-property style: grey fill on cards, white
  on the canvas, accent while live) in a wrapping `ChipFlow`, never a horizontal scroll.
- **Output is always 4 square (1:1) images** so the whole 2×2 decodes on screen in recordings.
- **Tab bar hidden.** The ☰ glass button (top left) is the navigation (Create / Explore / Library /
  Profile, New canvas, Play demo). No logo in the Create header.
- A short fade into the canvas under the top bar (status bar + header); it used to be a
  progressive blur, removed for performance.
- **Edge lens** (on by default): boards are magnified toward the top edge as they slide under the
  header: content stretches upward, the sides flare out, it smears along the stretch and the
  colour channels split like a prism, which the user asked for after the reference
  (`View.edgeLens` in `Effect/EdgeLens.swift`, a five-sample `layerEffect` in `Shaders.metal`).
  Per board but computed in screen space; cables are *not* lensed (a thin line through it read
  as a blob). Reference: a carousel where cards stretch and blur into the screen edges like thick
  glass. The band ends 16pt under the header (the user wanted the resting moodboard untouched);
  stretch 0.36 of the band, widen 0.18, smear 0.14, fringe 0.05. **Top edge only** (see gotchas).
- Typography: SF for prose, SF Mono for machine values (counts, model ids, seeds, prices, timers,
  bits). Use the named scale in `App/Theme.swift` (`.display`, `.screenTitle`, `.heading`,
  `.prose`, `.button`, `.label`, `.chip`, `.supporting`, `.note`, `.micro`; `.monoStat`,
  `.monoValue`, `.monoMeta`, `.monoBadge`); `Font.mono(_:)` / `Font.sans(_:)` only for one-offs
  like the wordmark.

## Open items

- Confirm on the user's Mac that scrolling and decoding are smooth now (ask for a 10 s recording;
  `mpdecimate` unique frames per half second: 30 = 60 fps). Baseline before removing the blurs:
  scroll ~5, decode ~10. If still slow, remaining per-frame work is the edge lens on the board
  under the header during scrolls and the 30 fps decode shader; try Profile → Reduce effects to
  split them.
- Lens tuning against the reference (strength, band size, bottom edge) is new and unreviewed.
- The user wants the whole thing to look premium for a client-facing post: keep polishing
  typography and spacing wherever a screenshot shows something rough.

## Layout

```
Decode/
  App/       DecodeApp, RootView (splash → onboarding → hidden-tab TabView), Theme
  Model/     Studio (state + fake generation timeline), Preset, Feed, Options, Autopilot
  Effect/    DecodeMath, DecodingImage, ImagePalette, DecodeOnce, EdgeLens, AmbientWash, Shaders.metal
  Views/     Create (CreateView, BoardView, Cable, Composer), Explore, Library, Profile, Onboarding, Detail, Common
scripts/run.sh                  build + boot simulator + install + launch (--demo, --fresh, SIM=)
.github/workflows/simulator.yml CI build + autopilot recording
```
