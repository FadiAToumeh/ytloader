# YT Downloader — Feature Development Progress

## Branch: `testing`
## Last Updated: 2026-06-24

---

## Overall Goal
Add 3 new features to the YouTube Downloader app without breaking existing functionality.

---

## Phase 1: Download History ✅ COMPLETED

**Status:** Done — `flutter analyze` passes with 0 issues.

**What was added:**
- `shared_preferences: ^2.3.0` dependency in `pubspec.yaml`
- `lib/models/download_entry.dart` — Data model with JSON serialization
- `lib/services/history_service.dart` — SharedPreferences CRUD (max 100 entries)

**What was modified:**
- `lib/screens/home_screen.dart`:
  - Added bottom navigation bar (Home | History tabs)
  - History tab shows past downloads with thumbnails, titles, timestamps
  - Share button on each history entry
  - Clear history button in app bar with confirmation dialog
  - Auto-saves to history after every successful download
  - Relative timestamps ("Just now", "5m ago", "2h ago", "24/6/2026")

**What was NOT changed (DO NOT TOUCH zones preserved):**
- `lib/main.dart` — untouched
- `lib/services/download_service.dart` — untouched
- `lib/models/video_info.dart` — untouched
- `android/app/src/main/kotlin/.../MainActivity.kt` — untouched
- `android/app/build.gradle.kts` — untouched
- `android/app/src/main/AndroidManifest.xml` — untouched

**Smoke test checklist:**
- [ ] Paste YouTube URL → fetch info works
- [ ] Download video → works as before
- [ ] History tab shows downloaded video
- [ ] Share from history works
- [ ] Clear history works
- [ ] App theme (dark/light) still works

---

## Phase 2: FFmpeg Integration ✅ COMPLETED

**Status:** Done — `flutter analyze` passes with 0 issues.

**What was added:**
- `ffmpeg_kit_flutter_new: ^4.2.0` dependency in `pubspec.yaml`

**What was NOT changed:**
- `MainActivity.kt` — untouched
- `build.gradle.kts` — untouched
- `AndroidManifest.xml` — untouched

---

## Phase 3: Quality Selector + FFmpeg Download Flow ✅ COMPLETED

**Status:** Done — `flutter analyze` passes with 0 issues.

**What was added:**
- `lib/models/stream_option.dart` — StreamOption model with StreamType enum (muxed, videoOnly, audioOnly)

**What was modified:**
- `lib/models/video_info.dart` — Added `availableStreams` field (List<StreamOption>)
- `lib/services/download_service.dart`:
  - `getVideoInfo()` now builds a full list of StreamOption objects from the manifest
  - `downloadVideo()` accepts a `StreamOption` parameter
  - Added `_downloadMuxed()` for video+audio merging via FFmpeg
  - Added `_saveToDownloads()` and `_cleanupTempFiles()` helpers
  - Multi-phase DownloadProgress with `phase` field
- `lib/screens/home_screen.dart`:
  - Added `_selectedStream` state variable
  - Quality selector dropdown in video card
  - Download button shows selected quality label
  - Multi-phase progress display ("Downloading video...", "Downloading audio...", "Merging streams...")
  - History records selected quality label

---

## Package Dependencies (Current)

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  youtube_explode_dart: ^3.1.0
  dio: ^5.8.0+1
  path_provider: ^2.1.6
  share_plus: ^12.0.2
  shared_preferences: ^2.3.0          # Added in Phase 1
  ffmpeg_kit_flutter_new: ^4.2.0      # Added in Phase 2

dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^6.0.0
```

---

## File Structure

```
lib/
├── main.dart                          — App entry (DO NOT TOUCH)
├── models/
│   ├── video_info.dart                — VideoInfo data model (extended in Phase 3)
│   ├── stream_option.dart             — NEW: StreamOption model (Phase 3)
│   └── download_entry.dart            — NEW: history entry model (Phase 1)
├── screens/
│   └── home_screen.dart               — Single screen with bottom nav + quality selector (Phases 1 & 3)
└── services/
    ├── download_service.dart          — YouTube API + download + FFmpeg muxing (Phase 3)
    └── history_service.dart           — NEW: SharedPreferences history (Phase 1)
```

---

## Key Risks & Mitigations

1. **FFmpeg APK size increase** — Use `_min` variant (~5-8MB) instead of full (~30-50MB)
2. **Quality selector without FFmpeg = broken files** — Only expose muxed streams if FFmpeg not active
3. **Temp file orphaning** — Use try/finally cleanup in download flow
4. **MethodChannel mismatch** — Never change the channel name string
5. **SharedPreferences corruption** — History service wraps parse in try/catch, returns empty on failure

---

## Git Safety

- Working on `testing` branch
- `main` branch preserved with original working code
- To rollback: `git checkout main` or `git checkout -- .`
