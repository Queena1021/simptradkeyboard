# SimpTradKeyboard — iOS Chinese IME with Auto Simp/Trad Conversion

**Date:** 2026-04-24
**Status:** Design approved, pending implementation plan

## Summary

An iOS third-party keyboard app that accepts Cangjie (倉頡) and Quick/Sucheng (速成) input and outputs either simplified or traditional Chinese based on a user-controlled toggle, with phrase-level conversion powered by OpenCC data. V1 is fully offline, does not require Full Access, and ships a main settings app plus a keyboard extension.

## Goals

- Users can type Cangjie or Quick codes on an iOS system keyboard replacement.
- Users can toggle output between Simplified and Traditional Chinese directly on the keyboard (全局 toggle).
- Conversion is phrase-level (e.g. 「頭髮」→「头发」, 「發展」→「发展」) using OpenCC dictionaries.
- Offline-only, no Full Access required.
- UI follows native iOS 速成 keyboard layout and visual style.

## Non-Goals (V1)

- Simplified → Traditional conversion (V2).
- Pinyin / Jyutping / other input methods (V2+).
- User-editable custom dictionary (V2).
- iCloud sync (V2+).
- iPad split keyboard, landscape-optimized layout.
- Haptic feedback and key sounds (V2).
- Any network / telemetry.

## V1 Scope

| Included | Excluded |
|----------|----------|
| Cangjie + Quick input | Pinyin / Jyutping |
| T→S phrase-level conversion | S→T conversion |
| Global simp/trad toggle on keyboard | Per-candidate toggle |
| Learning (frequency-based candidate ranking) | User-added custom words |
| Symbol / number layout | Haptic / sound |
| Long-press delete, swipe-space cursor | iCloud sync, Full Access |

## Target Platform

- **iOS 16+** (broad coverage, modern APIs sufficient).
- **iPhone only** in V1 (Info.plist `PrimaryLanguage` + layout scoped to phone portrait; landscape uses stretched portrait layout).
- **Swift** + **UIKit** for the keyboard extension (SwiftUI is not mature enough inside keyboard extensions).
- **Swift** + **SwiftUI** for the main (settings) app.

## Architecture

Two build targets plus one shared local Swift package:

```
┌─────────────────────────────────────────┐
│  Main App (SwiftUI)                     │
│  - Settings / toggles                   │
│  - Onboarding                           │
│  - Learning data view / reset           │
└──────────────┬──────────────────────────┘
               │ App Group shared container
               │ (UserDefaults + learning.sqlite)
┌──────────────┴──────────────────────────┐
│  Keyboard Extension (UIKit)             │
│  KeyboardViewController                 │
│   ├─ KeyboardView (key grid)            │
│   ├─ SymbolKeyboardView                 │
│   └─ CandidateBar                       │
└──────────────┬──────────────────────────┘
               │ import
               ▼
       KeyboardCore (Swift package)
       ├─ InputEngine (trie lookup)
       ├─ ConvertEngine (OpenCC phrase)
       ├─ LearningStore (sqlite)
       └─ Settings (UserDefaults wrapper)
```

### Targets

- `SimpTradKeyboard` — main app.
- `SimpTradKeyboardExtension` — keyboard extension.
- `KeyboardCore` — local Swift package containing all engine logic, imported by both targets. Enables direct `swift test` on the core without Xcode host-app plumbing.

### App Group

- ID: `group.com.<bundle>.simptradkb`.
- Shared container holds:
  - `UserDefaults(suiteName:)` — user settings.
  - `learning.sqlite` — learning frequency data.
- App Group does **not** require Full Access. Full Access is not requested in V1.

### Data files (bundled)

- `cangjie5.trie` — Cangjie code table (from rime-cangjie5, pre-built into binary trie).
- `quick5.trie` — Quick/Sucheng code table.
- `opencc/t2s_phrases.json`, `opencc/t2s_chars.json` — OpenCC T→S data.
- A small fallback char-level mapping ships separately to survive trie corruption.

## Components

### KeyboardCore

**`InputEngine`**
- mmaps `cangjie5.trie` / `quick5.trie` on first use.
- `lookup(code: String, mode: .cangjie | .quick) -> [Candidate]`.
- `Candidate { text: String, frequency: Int, source: .builtin | .learned }`.
- Ranking: learned frequency → builtin frequency → stroke order (as stored in trie).

**`ConvertEngine`**
- Loads OpenCC phrase + char dictionaries into in-memory tries.
- `convert(_ text: String, to: .simplified | .traditional) -> String`.
- V1 only implements `.simplified` (T→S). `.traditional` path returns input unchanged; full S→T is V2.
- Algorithm: longest-match phrase scan, fallback to per-char mapping.

**`LearningStore`**
- SQLite file at App Group container.
- Schema: `selections(code TEXT, candidate TEXT, count INT, last_used INT, PRIMARY KEY(code, candidate))`.
- API: `recordSelection(code, candidate)`, `frequencyBoost(code, candidate) -> Int`.
- Access serialized through a dedicated `DispatchQueue`.

**`Settings`**
- Wrapper over `UserDefaults(suiteName: appGroup)`.
- Keys: `outputMode` (.simplified | .traditional), `imeMode` (.cangjie | .quick).

### Keyboard extension

**`KeyboardViewController`** — extension entry point.
- Owns `InputEngine`, `ConvertEngine`, `LearningStore`, and the composing buffer.
- Reads settings on `viewWillAppear`.

**`KeyboardView`** — Chinese input layout (see "UI Layout" below).

**`SymbolKeyboardView`** — symbol / number layout.

**`CandidateBar`** — horizontal scrollable `UICollectionView` above the keyboard, shows current lookup results already converted to output mode.

**`KeyButton`** — custom `UIButton` subclass handling tap, long-press, and swipe gestures.

### Main app

- `SettingsView` (SwiftUI): toggle simp/trad default, pick Cangjie/Quick.
- `OnboardingView`: instructions to enable the keyboard in Settings.
- `LearningDataView`: list learned entries, reset button.

## UI Layout (follows native iOS 速成)

### Chinese mode (Quick/Cangjie)

```
Row 1:  手 田 水 口 廿 卜 山 戈 人 心        (10 keys)
Row 2:  日 尸 木 火 土 竹 十 大 中            (9 keys)
Row 3:  重 難 金 女 月 弓 一              ⌫   (7 keys + delete)
Row 4: [123] [😀]      [ space 速 ]      [.] [→]
Row 5:  🌐                                 🎤
```

### Symbol / Number mode

```
Row 1:  1 2 3 4 5 6 7 8 9 0
Row 2:  - / : ; ( ) $ @ 「 」
Row 3: [#+=] 。 , 、 ? ! .                ⌫
Row 4: [速成] [😀]    [ space 速 ]         [→]
Row 5:  🌐                                 🎤
```

### Visual spec

- Dark-mode-first; uses `systemBackground`, `systemGray3` to auto-follow light/dark.
- Each key: independent rounded rectangle, corner radius ~8pt, gaps between keys.
- Key background semi-transparent gray; label white in dark mode.
- Return key: `systemBlue` background, white arrow.
- Space bar: wide, right-aligned gray hint text showing current mode (「速」).
- Globe (🌐) uses `advanceToNextInputMode()`; mic row may be cosmetic (system-provided in some contexts).
- Candidate bar appears above the top key row only while composing.

### Layout implementation

- Vertical `UIStackView` stacks 4 rows; each row an `UIStackView` with `.fillEqually` distribution per row.
- `KeyButton` handles visual states: pressed (scale down), long-press repeat (delete), swipe (space → cursor move).

## Data Flow

### Typing a character (Quick, output=simplified)

1. User taps 「日」key (code `a`).
2. `KeyboardViewController.handleKey('a')`:
   - `composingBuffer += "a"`.
   - `candidates = InputEngine.lookup("a", mode: .quick)`.
   - If `outputMode == .simplified`: map each candidate through `ConvertEngine.convert(_, to: .simplified)`.
   - Apply `LearningStore.frequencyBoost` and re-rank.
   - `CandidateBar.show(candidates)`.
3. User taps a candidate:
   - `textDocumentProxy.insertText(candidate.displayText)`.
   - `LearningStore.recordSelection(code: composingBuffer, candidate: candidate.originalText)`.
   - `composingBuffer = ""`; hide candidate bar.

### Quick-specific behavior

- Buffer stores up to 2 codes (head + tail). Lookup on each keystroke.
- Space commits first candidate.
- Any non-letter key first commits first candidate, then handles itself.

### Cangjie-specific behavior

- Buffer stores up to 5 codes. Lookup on each keystroke.
- Space commits first candidate.

### Delete key

- If `composingBuffer` non-empty: remove last char from buffer, re-lookup.
- Otherwise: `textDocumentProxy.deleteBackward()`.

### Simp/Trad toggle

- Toggle key writes new `outputMode` to App Group `UserDefaults`.
- Already-committed text is not changed (it has left our process).
- Next lookup uses new mode.

### Settings sync (main app ↔ extension)

- V1: extension re-reads `UserDefaults(suiteName:)` on `viewWillAppear`. Sufficient because toggling in main app means the keyboard is not currently active.
- V2 optional: Darwin notifications for real-time sync.

## Error Handling

| Situation | Behavior |
|-----------|----------|
| Trie / OpenCC file missing from bundle | Fatal assert in debug; `os_log` error + best-effort fallback char-level mapping in release. |
| Trie file corrupt | Fallback to bundled char-level mapping; log error. |
| Learning DB open fail | Read-only mode: lookups work, no recording. User can reset from main app. |
| Memory warning | Drop candidate cache; if severe, drop phrase dict (char-level only). |
| `textDocumentProxy` missing context | Insert text normally; skip context-aware features. |
| Invalid code (no trie match) | Empty candidate bar with a hint indicator; user can delete or space to clear buffer. |
| T→S conversion returns input unchanged | Use as-is (input was already Simplified or has no mapping). |
| Fast key repeat | No debounce; trie lookup is sub-millisecond. |

### Memory budget (60MB extension limit)

- Tries: ~3MB mmap
- OpenCC data: ~8MB
- Learning DB: <1MB typical
- UI + runtime: ~20-30MB
- **Total ~35-45MB**, safely within limit.

### Logging

`os_log` only. No analytics, no network. Crash reports via Apple TestFlight / App Store Connect.

## Testing Strategy

### Unit tests (KeyboardCore, target ~90% coverage)

**InputEngine**
- Quick single-code lookup with correct ordering.
- Quick two-code lookup.
- Cangjie full-code lookup (e.g. `hqm` → 「拜」).
- Invalid code returns empty, no crash.
- Learning boost moves candidate to front.

**ConvertEngine**
- T→S single char (「發」→「发」).
- Phrase overrides char (「頭髮」→「头发」, 「發展」→「发展」).
- No-match returns input unchanged.
- Mixed text (「我發現」→「我发现」).
- Golden fixture file `conversion_fixtures.json` with hundreds of curated pairs, run parametrized.

**LearningStore**
- Record increments count.
- Frequency boost is zero for unknown (code, candidate).
- Concurrent writes safe (serial queue).
- Uses `:memory:` sqlite in tests.

**Settings**
- Defaults are correct.
- Persist-and-reload round-trips.

### Integration tests (KeyboardCore)

- End-to-end: type → lookup → select → record; next type shows learned candidate first.
- End-to-end with `outputMode=.simplified`: Cangjie code for 「髮」 produces candidate 「发」.
- Toggle mid-session: next lookup reflects new mode.

### UI tests (main app)

- Onboarding view links to Settings.
- Toggle output mode persists across app restart.
- Learning data view reset clears DB.

### Manual test checklist (per release)

- Add-keyboard flow works.
- Typing works in iMessage, Safari, Notes.
- 「頭髮」produces both variants correctly.
- Simp/Trad toggle reflects in next lookup.
- Long-press delete repeats correctly.
- Swipe-space moves cursor.
- Symbol layout switch works.
- Dark and light modes render correctly.
- Low-memory scenario (many Safari tabs) does not crash.
- Landscape works.
- Globe switches input mode.

### Performance benchmarks (CI)

- Trie lookup p99 < 5ms.
- OpenCC phrase convert on 10-char string p99 < 10ms.
- Keyboard cold start < 300ms.

### CI

- GitHub Actions macOS runner.
- `swift test` on KeyboardCore every commit.
- `xcodebuild test` on main app UI tests every PR.
- Build verification that the extension target links cleanly.

## Open Questions / Future Work

- V2: S→T conversion, with per-candidate disambiguation for one-to-many (e.g. 发 → 發 / 髮).
- V2: User custom dictionary.
- V2: Haptic feedback, key sounds.
- V2: iCloud sync of learning and custom dictionary (requires Full Access or CloudKit alternative).
- V3: Pinyin / Jyutping support.
