# Samploom

Slice any sample by the musical grid and jam with it — a local, offline loop slicer for iOS.

An audio file from Files becomes grid-aligned slices; slices are replayed as a loop and exported back to a file. Everything runs on device: no server, no account.

## Requirements

- Xcode 16 or newer (project uses buildable folders)
- iOS 18.0+
- Swift 6 language mode

## Status

Scaffold, design system, sample import, tempo detection and the musical grid.
A file picked in Files is copied into the app container, its BPM is read from
tags or from the name, and the grid shows bar and step lengths. Slicing and
playback are next.

## Structure

```
Samploom/
├── App/            App entry point and the root screen
├── Core/Audio/     Duration and tempo detection for imported files
├── Core/Storage/   On-device copy of imported samples
├── DesignSystem/   Colour, type and metric tokens, shared surfaces
├── Features/       Screen state and behaviour, one folder per feature
└── Resources/      Asset catalog
SamploomTests/      Unit tests for storage, detection and screen state
Packages/
└── SamploomDomain/ Pure musical model: tempo, meter, grid, quantisation
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
