# Gym Capture (Flutter Desktop)

Gym Capture is a desktop app for gymnastics competitions. It continuously records a rolling ffmpeg buffer and allows operators to mark START/STOP and export clips per participant.

## What the app does
- Setup Wizard with ffmpeg/ffplay detection, automatic install, output folder, source selection, and device scanning.
- Work screen with schedule loading (`FIO;APPARATUS;CITY(optional)`), list navigation, START/STOP/POSTPONE controls, hotkeys, and logs.
- Rolling segment buffer in Application Support with clip export on STOP using concat demuxer.
- Optional ffplay preview in a separate window.
- Language switcher (EN/RU/TR) with dictionary-based localization structure for adding new languages.

## Run (macOS / Windows)
1. Install Flutter SDK.
2. From this project, run:
   - `flutter pub get`
   - `flutter run -d macos` (macOS)
   - `flutter run -d windows` (Windows)

## Build
- macOS: `flutter build macos`
- Windows: `flutter build windows` (run this on Windows)

## Notes
- Blackmagic DeckLink requires Blackmagic Desktop Video driver.
- UVC capture cards typically appear as camera devices (AVFoundation on macOS, DirectShow on Windows).


## Localization
- Switch language in Setup screen or Work screen (language button).
- Localization dictionary lives in `lib/localization/app_localizations.dart`.
- To add a new language, add code to `supportedLanguages` and a map entry in `dictionary`.

- If auto install fails due to network policy, use manual "Pick ffmpeg path..." and "Pick ffplay path...".
