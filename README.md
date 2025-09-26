# RunAndRead iOS

[![Platform iOS](https://img.shields.io/badge/platform-iOS-lightgrey.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-supported-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

RunAndRead is a distraction‑free Text‑to‑Speech (TTS) and audiobook player designed for reading while moving (running/walking). Open text, PDF, or EPUB files and let the app read them aloud using system voices, with speed control and background audio.

- Clean SwiftUI interface
- System Text‑to‑Speech with voice and speed selection
- Background audio playback (run while your screen is off)
- Support for .txt, .pdf, .epub and a custom `.randr` archive
- Share/open from the Files app and other apps


## Architecture
See docs/ARCHITECTURE.md for a high‑level overview of the app layers and data flow.


## Installation

Option A — Stores
- App Store: https://apps.apple.com/app/idXXXXXXXXX
- Google Play: https://play.google.com/store/apps/details?id=com.example.runandread

Option B — Build from source
- Requirements:
  - Xcode 15+
  - iOS 16+ deployment target (configurable)
  - Swift 5.9+
- Steps:
  1. Clone this repository.
  2. Open RunAndRead.xcodeproj in Xcode.
  3. Select the RunAndRead scheme and build/run on a device or simulator.


## Features
- Text‑to‑Speech player using system voices (AVSpeechSynthesizer)
- Audiobook playback
- Adjustable speed and voice selection
- Horizontally scrolled text reader
- Opens files from Files app or share sheet
- Background audio support


## Contributing
Contributions are welcome! Please open an issue to discuss changes or submit a pull request. See coding guidelines in docs/ARCHITECTURE.md.


## Privacy & Security
- No API keys or third‑party analytics are included.
- The app processes documents locally on device.


## License
This project is licensed under the MIT License — see the LICENSE file for details.
