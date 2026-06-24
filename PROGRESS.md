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

## Phase 2: FFmpeg Integration 🔄 PENDING

**Status:** Not started.

**Goal:** Add `ffmpeg_kit_flutter_new` package to enable merging video+audio streams for high-quality (1080p+) downloads.

**Planned changes:**
- `pubspec.yaml` — Add `ffmpeg_kit_flutter_new: ^4.2.0` (use `_min` variant for ~5-8MB APK increase)
- Build and verify no Gradle/SDK conflicts
- Test FFmpeg works on device in isolation

**DO NOT TOUCH:**
- `MainActivity.kt` lines 13, 15-37 (MethodChannel setup)
- `build.gradle.kts` lines 17-26 (SDK versions)
- `AndroidManifest.xml` (permissions already complete)

**Smoke test checklist:**
- [ ] `flutter pub get` succeeds
- [ ] APK builds without errors
- [ ] FFmpeg test command runs on device
- [ ] Existing download flow still works (regression test)

---

## Phase 3: Quality Selector + FFmpeg Download Flow 🔄 PENDING

**Status:** Not started — depends on Phase 2.

**Goal:** Let users pick quality (1080p, 720p, 480p, audio-only). For 1080p+, download video+audio separately and merge with FFmpeg.

**Planned changes:**
- `lib/models/video_info.dart` — Add `StreamOption` model, extend `VideoInfo` with stream list
- `lib/services/download_service.dart`:
  - Restructure `getVideoInfo()` to expose all streams (muxed, video-only, audio-only)
  - Rewrite `downloadVideo()` for multi-phase download + FFmpeg merge
  - Update file extension logic (audio → `.m4a`, muxed/video+audio → `.mp4`)
- `lib/screens/home_screen.dart`:
  - Add quality selector UI (dropdown or bottom sheet) between video card and download button
  - Update download progress to show multi-phase states ("Downloading video...", "Downloading audio...", "Merging...")
- `lib/main.dart` — untouched

**DO NOT TOUCH:**
- `download_service.dart` lines 22-24 (MethodChannel name)
- `download_service.dart` lines 82-101 (oEmbed metadata fetch)
- `download_service.dart` lines 103-138 (manifest fetch with retry)
- `home_screen.dart` lines 106-109 (share functionality)
- `MainActivity.kt` lines 39-67 (saveToDownloads — format-agnostic)

**Critical safety rule:**
Quality selector MUST NOT expose video-only or audio-only streams unless FFmpeg is active. Otherwise users get broken files.

**Smoke test checklist:**
- [ ] Quality selector shows all available streams
- [ ] Selecting muxed stream (360p) downloads correctly (same as before)
- [ ] Selecting 1080p downloads video+audio and merges correctly
- [ ] Audio-only selection works
- [ ] File saved to Downloads with correct extension
- [ ] Share works for all quality types
- [ ] History records correct quality info
- [ ] No orphaned temp files after download

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

dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^6.0.0
```

**Phase 2 will add:**
- `ffmpeg_kit_flutter_new: ^4.2.0` (min variant)

---

## File Structure

```
lib/
├── main.dart                          — App entry (DO NOT TOUCH)
├── models/
│   ├── video_info.dart                — VideoInfo data model (Phase 3: will extend)
│   └── download_entry.dart            — NEW: history entry model (Phase 1)
├── screens/
│   └── home_screen.dart               — Single screen with bottom nav (Phase 1: modified)
└── services/
    ├── download_service.dart          — YouTube API + download (Phase 3: will rewrite)
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
