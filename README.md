# RunAndRead iOS | [[RunAndRead-Android]](https://github.com/answersolutionsapps/runandread-android) | [[Audiobook-Pipeline]](https://github.com/sergenes/runandread-audiobook)

[![Platform iOS](https://img.shields.io/badge/platform-iOS-lightgrey.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-supported-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Ultimate Text‑to‑Speech player for iPhone, iPad, Mac, and visionOS — listen to your books while running, exercising, or on the go.

<img src="assets/ic_launcher.png" width="100" height="100" alt="Run & Read app icon">

Run & Read is a distraction‑free Text‑to‑Speech (TTS) and audiobook player designed for reading while moving. Open text, PDF, or EPUB files and let the app read them aloud using system voices, with speed control and background audio.

- Clean SwiftUI interface
- System Text‑to‑Speech with voice and speed selection
- Background audio playback (keep listening with the screen off)
- Supports .txt, .pdf, .epub, and a custom `.randr` archive
- Open from the Files app and other apps via the share sheet

## Architecture
See the high‑level overview in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Installation

### From the App Store
🍏 **App Store**: [Ran & Read for Apple Devices](https://apps.apple.com/us/app/run-read-listen-on-the-go/id6741396289)

### From Google Play
🤖 **Google Play**: [Ran & Read for Android](https://play.google.com/store/apps/details?id=com.answersolutions.runandread)

📱 **Scan QR codes to download**

<div align="center">
  <img src="assets/apple_runandread_qr_code.png" width="150" alt="App Store QR code">&nbsp;&nbsp;&nbsp;
  <img src="assets/google_runandread_qr_code.png" width="150" alt="Google Play QR code">
</div>

### Build from source

- Requirements:
  - Xcode 15+
  - iOS 16+ deployment target (configurable)
  - Swift 5.9+
- Steps:
  1. Clone the repository:
     ```
     git clone https://github.com/answersolutions/runandread-ios.git
     ```
  2. Open RunAndRead.xcodeproj in Xcode.
  3. Select the RunAndRead scheme and build/run on a device or simulator.

## Features
- Text‑to‑Speech player using system voices (AVSpeechSynthesizer)
- Audiobook playback
- Adjustable speed and voice selection
- Horizontally scrolled text reader
- Open files from the Files app or share sheet
- Background audio support

## 📦 Dependencies
[RunAndRead-Audiobook](https://github.com/sergenes/runandread-audiobook) is an open‑source project aimed at generating high‑quality TTS audiobooks using models like Zyphra/Zonos.
Run & Read supports MP3 audiobooks generated using the RANDR pipeline in this repository. See the [RANDR instructions](https://github.com/sergenes/runandread-audiobook/blob/main/RANDR.md).

## Contributing
Contributions are welcome! Please open an issue to discuss changes or submit a pull request. See coding guidelines in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 📞 Contact
- **[Sergey N](https://www.linkedin.com/in/sergey-neskoromny/)**

## License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
