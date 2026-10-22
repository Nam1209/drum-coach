# DrumCoach

An iPad practice app for drummers learning without a teacher. It listens to a practice pad through the iPad mic, or to an e-kit over MIDI, while you play along to a click, and colours every note: green when it's on time, amber when it's early or late, red when it's missed.

I built it for myself while working through Stick Control toward Rockschool Grade 8, on a 12" pad and a Roland TD-4K. It isn't on the App Store.

- **Intro page with a playable demo:** https://nam1209.github.io/drum-coach/
- **Clickable prototype of every screen:** https://nam1209.github.io/drum-coach/prototype-en.html ([Tiếng Việt](https://nam1209.github.io/drum-coach/prototype.html))

## What it does

- **Hears what you play.** Pad through the mic, with an 8-tap setup for room noise, softest stroke and latency per output device. E-kit over USB or Bluetooth MIDI, with Roland note numbers built in and MIDI learn for other kits.
- **Scores every note.** Within ±30 ms is green (±20 and ±45 ms are also available). Amber marks sit before the note when you rushed and after it when you dragged. Each run ends with a percentage: green 1, amber 0.5, red 0, and every extra stroke takes off 0.5.
- **Says where it goes wrong.** Which hand, which part of "1 e & a", and whether you drift through the run or are consistently off, which usually means latency.
- **Counting coach.** Speaks a smooth "1 e & a" or "1 trip-let" at any tempo, then listens to you count and marks each syllable.
- **Levels follow Rockschool grades.** Level N means the app's Grade N tests are passed at over 90% at the book tempo and enough practice points have been earned.
- **AI teacher through Notion.** The app writes a daily practice report to a shared Notion page. A Claude chat with access to that page reads it and writes next week's plan back, and the app syncs the plan into Today.
- **Metronome** with a recorded mechanical click, spoken count-in and tempo ramps (50 → 90 BPM, +2 after four bars at 90%).

## Book content

Stick Control and the Rockschool books are under copyright, so this repo contains none of their content. Exercises come from generated sticking permutations, the app's own curriculum, the 40 PAS rudiments, and exercises you transcribe from your own books into `PrivateLibrary/`. That folder is git-ignored and loaded at runtime.

## Building

- Xcode with Swift 6, iPadOS 18 or later.
- Generate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate`, then open `DrumCoach.xcodeproj`.
- Change `DEVELOPMENT_TEAM` in `project.yml` to your own team to install on a device.
- The timing and scoring core is the `DrumKit` Swift package in `Packages/DrumKit`. Run its tests on a Mac with `swift test`.

## Docs

- `docs/index.html`: intro page with the browser demo
- `docs/prototype-en.html` and `docs/prototype.html`: clickable prototypes (English and Vietnamese)
- `docs/giao-trinh.html`: fundamentals curriculum (Vietnamese)
- `docs/plan.html` and `docs/superpowers/plans/`: implementation plan
