# RunAndRead iOS — Architecture Overview

This document provides a high‑level overview of the app architecture to help new contributors navigate the codebase quickly.

## Goals
- Smooth, distraction‑free reading while moving (running/walking), via Text‑to‑Speech (TTS) and audio.
- Simple, maintainable layers with clear responsibilities.
- Offline‑friendly where possible; no backend dependencies.

## Layers and Modules

1. App Layer
   - Entry point: `RunAndReadApp` (SwiftUI `@main`)
   - Dependency wiring via `EnvironmentObject` for core services:
     - `BookManager` (file management/opened file path)
     - `SimpleTTSPlayer`, `TextToSpeechPlayer` (system TTS)
     - `AudioBookPlayer` (audio playback for audiobooks)
   - Handles incoming file URLs via `onOpenURL`.

2. UI (SwiftUI Views)
   - `UI/Init/` — `SplashScreenView` (initialization / first launch surface)
   - `UI/Home/` — Home screen and book list (`HomeScreenView`, `BookItemView`)
   - `UI/BookPlayer/` — Player screen and controls (`BookPlayerView`)
   - `UI/BookSettings/` — Reading/playback settings (`BookSettingsView`)
   - `UI/Components/` — Reusable UI elements (buttons, pickers, modifiers, activity indicator, horizontally scrolled text, etc.)
   - `UI/About/` — About screen

   Views bind to ViewModels via `@StateObject`/`@ObservedObject`, reacting to published state.

3. ViewModels
   - `HomeScreenViewModel`, `BookPlayerViewModel`, `BookSettingsViewModel`.
   - Own UI state, orchestrate use‑cases, and coordinate with services (TTS/audio, file manager, models).
   - Expose intents/actions (play/pause, speed change, voice selection, open file, etc.).

4. Models
   - `Book`, `AudioBook` — immutable model structs (where possible) representing domain entities used across ViewModels and services.

5. File & Data Layer
   - `Files/BookManager` — tracks current opened file path and basic book management state.
   - `Files/FileTextExtractor` — loads/extracts text from various supported document types (plain text, PDF, EPUB) for TTS playback.

6. Speech / Audio Layer
   - `Speech/SimpleTTSPlayer` — thin wrapper around AVSpeechSynthesizer for straightforward TTS needs.
   - `Speech/TextToSpeechPlayer` — richer TTS engine controller (rate, pitch, language/voice selection, paging/segments, and lifecycle events).
   - `Speech/SpeechSpeedSelector` — encapsulates logic for allowed speeds.
   - `Audio/AudioBookPlayer` — playback for prerecorded audiobooks.
   - `Speech/AudioSessionManager` — configures and manages `AVAudioSession` (category, interruptions, background audio).

7. App Utilities
   - `App/EmailService` — opens prefilled email compose for feedback/logs, can attach exported audio files.
   - `App/Extensions` — app‑wide extensions/helpers.
   - `App/TimeLogger`, `App/UIConfig` — diagnostic logging and UI styling tokens.

## Data Flow
- User selects a document (or opens via Files/share sheet) → `RunAndReadApp` resolves URL → `BookManager.openedFilePath` updated.
- A ViewModel detects change, loads content via `FileTextExtractor`, then instructs a player (`TextToSpeechPlayer` or `AudioBookPlayer`).
- Player emits state updates (current position, isPlaying, errors) observed by ViewModels, which bind to Views.

## Threading & Concurrency
- UI updates occur on the main thread as required by SwiftUI.
- Long‑running or I/O tasks (file reading, parsing) are dispatched off the main thread where applicable.
- AVFoundation callbacks may arrive on internal queues; state is marshaled back to main for UI.

## Routing and Deep Links
- `onOpenURL` in `RunAndReadApp` handles `.randr`, `.txt`, `.epub`, `.pdf` file types configured in `Info.plist`.
- Security‑scoped resource access is used when necessary (Files app / external locations).

## Permissions
- Background audio enabled (Info.plist `UIBackgroundModes: audio`).
- No network access by default; the app does not store or transmit personal data.

## Dependencies
- Built with SwiftUI and AVFoundation (system frameworks). No third‑party SDKs are required for core features.

## Testing
- `RunAndReadTests` contains unit tests for core logic (e.g., book parsing). Expand with tests for ViewModels and text extraction segments.

## Extensibility
- Add new document types by extending `FileTextExtractor`.
- Add new TTS voices/languages through `AVSpeechSynthesisVoice` discovery in `TextToSpeechPlayer`.
- Introduce analytics or crash reporting behind an optional feature flag (ensure opt‑in and privacy safeguards).

## Folder Map (Quick Reference)
- App entry and utilities: `RunAndRead/App/`
- Assets: `RunAndRead/Assets.xcassets/`
- Models: `RunAndRead/Model/`
- Files & parsing: `RunAndRead/Files/`
- Speech/Audio: `RunAndRead/Speech/`, `RunAndRead/Audio/`
- UI: `RunAndRead/UI/`
- Tests: `RunAndReadTests/`

## Coding Guidelines
- Swift API Design Guidelines + SwiftUI best practices.
- Use meaningful names; avoid abbreviations.
- Prefer `struct` for value types; use `class` where reference semantics or Objective‑C interop is required.
- Keep Views small and composable; put logic in ViewModels/services.
- Document public types and important methods.
