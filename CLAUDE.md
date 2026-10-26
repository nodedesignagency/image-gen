# Decode: working notes for Claude

Front-end-only SwiftUI image-generation app, built for screen-recorded social videos. No model:
"generating" decodes bundled photo sets. The signature effect is the **binary reveal**: images
decode top-to-bottom from 0s and 1s (blue front, bits tinted with the image's colours, pixels fade
in behind). See README.md for the feature tour.

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
  large areas every frame. Decode/cable timelines run at 30 fps. Profile has a **Reduce effects**
  switch that turns glass, blur, lights and lens into flat fills.
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
- Composer: roomy 2-line prompt, round moodboard + enhance buttons, mono pills for model
  (`decode-2`, `decode-2-pro` costs 2 credits, `decode-lite`) and style, light send button.
  Floats ~10pt above the bottom edge with screen-concentric bottom corners.
- **Output is always 4 square (1:1) images** so the whole 2×2 decodes on screen in recordings.
- **Tab bar hidden.** The ☰ glass button (top left) is the navigation (Create / Explore / Library /
  Profile, New canvas, Play demo). No logo in the Create header.
- Short progressive blur under the top bar only (status bar + header).
- **Edge lens** (on by default): boards and cables stretch toward the top edge and their sides
  draw in as they slide under the header blur (`View.edgeLens` in `Effect/EdgeLens.swift`, shader
  in `Effect/Shaders.metal`). Applied per view but computed in screen space, so neighbours bend
  together; stretch stays under a third of the band so it never folds. User asked for this after
  a reference video where cards bend at the screen edges while scrolling.
- Typography: SF for prose, SF Mono for machine values (counts, model ids, seeds, prices, timers,
  bits). Use the named scale in `App/Theme.swift` (`.display`, `.screenTitle`, `.heading`,
  `.prose`, `.button`, `.label`, `.chip`, `.supporting`, `.note`, `.micro`; `.monoStat`,
  `.monoValue`, `.monoMeta`, `.monoBadge`); `Font.mono(_:)` / `Font.sans(_:)` only for one-offs
  like the wordmark.

## Open items

- "Heavy" is still unconfirmed on the user's Mac (CI can't tell). Latest fix: shadows moved off
  live content. Ask for a short Mac recording if they report it again.
- Edge lens: possibly also at the bottom edge (behind the composer); ask before adding.

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
