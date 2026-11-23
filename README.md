# Samploom

Slice any sample by the musical grid and jam with it — a local, offline loop slicer for iOS.

An audio file from Files becomes grid-aligned slices; the app plays them back once so you can hear the loop. Everything runs on device: no server, no account.

## Requirements

- Xcode 16 or newer (project uses buildable folders)
- iOS 18.0+
- Swift 6 language mode

## Status

Scaffold, design system, sample import, tempo detection, the musical grid and
slice planning. A file picked in Files is copied into the app container, its
BPM is read from tags or from the name, can be adjusted by hand (90 BPM is
assumed when nothing is found), and the grid origin can be shifted inside the
bar when a file does not start on a downbeat. Audio is decoded once: channels
stay separate, the rate is normalised to 48 kHz, and files longer than 40 s are
cut to their first 40 s.
The screen draws the waveform with the slice windows on top; silent positions
are skipped so a slice is never empty. The Bar / 1/2 bar / Beat / 1/2 beat /
1/4 beat control sets both the slice length and the grid its start may land on,
so a finer division really does cut a shorter piece. The whole pass is 8–16
bars — half a square to one square — and the number of slices follows from the
division. `SliceRenderer` cuts the planned slices
and bakes 8 ms fades into their edges. Every generated pattern is four slices
long and repeats to fill the pass, so a random loop keeps coming back; when the
pass length is not a multiple of four, the last loop is cut short. Playback
joins the slices with those
fades as crossfades, so repeats have neither a gap nor a click at the join, and
schedules the whole pass before the first sample is heard. A pass plays once,
highlights the slice being heard on the waveform and shows the position.

## Signing

`DEVELOPMENT_TEAM` is not committed. Xcode's automatic signing keeps it in
`Config/Local.xcconfig`, which is git-ignored:

```
cp Config/Local.xcconfig.sample Config/Local.xcconfig
# set DEVELOPMENT_TEAM to your 10-character team ID
```

`Config/Base.xcconfig` includes that file optionally, so a fresh clone builds
without it.

## Structure

```
Samploom/
├── App/            App entry point and the root screen
├── Core/Audio/     Decoding, tempo detection and playback of samples
├── Core/Storage/   On-device copy of imported samples
├── DesignSystem/   Colour, type and metric tokens, shared surfaces
├── Features/       Screen state and behaviour, one folder per feature
└── Resources/      Asset catalog
SamploomTests/      Unit tests for storage, detection and screen state
Packages/
└── SamploomDomain/ Pure musical model: tempo, meter, grid, slicing
```

`SamploomDomain` has no UIKit, SwiftUI or AVFoundation dependency, so the
musical maths stays testable without a simulator and cannot quietly grow a
view or file dependency.

Tokens live in `Assets.xcassets` as semantic colours with light/dark appearances. Xcode generates typed accessors from asset names, so code writes `.foregroundStyle(.textSecondary)` or `.background(.backgroundPrimary)` and never touches raw colours or hex values. The palette is listed in `DesignSystem/PaletteGallery.swift` (Debug-only preview).

## Build

```
xcodebuild -scheme Samploom -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild test -scheme Samploom -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
swift test --package-path Packages/SamploomDomain
```

The domain tests run on macOS in milliseconds; the app tests need a simulator
because they exercise AVFoundation and the app's own storage.

## Licensing

Audio material is not part of this repository: `*.wav`, `*.mp3`, `*.m4a` and `Assets/Audio/` are git-ignored. Third-party samples stay on the user's device and under their own licences.
