# TinyAudioUnitHost

💡 A tiny macOS app that hosts Audio Units and routes live audio input through them in real time.

🎛️ Pick any effect AU from the sidebar, route your mic or audio interface through it, and listen to the result. Useful for practicing — when you just need a piano to sing along to, or a single guitar amp sim, without firing up something heavy like Logic.

🧪 Built directly on Apple's audio stack — Core Audio (aggregate devices, channel maps, low-level device control), `AVAudioEngine`, CoreMIDI, and CoreAudioKit for AU GUIs. SwiftUI front-end. Swift 6 strict concurrency. Zero external dependencies. Modular architecture with Tuist.

🎸 A small idea that I'll be growing over time. Let's see where it goes.

## Getting Started

### Prerequisites

Install [mise](https://mise.jdx.dev/getting-started.html) if you don't have it yet. After installing, make sure to [activate it in your shell](https://mise.jdx.dev/getting-started.html#activate-mise).

### Setup

```bash
mise run generate     # resolves dependencies and generates the Xcode project
```
