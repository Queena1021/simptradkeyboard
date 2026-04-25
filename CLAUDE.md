# SimpTradKeyboard

iOS 速成/倉頡 keyboard，自動簡繁轉換 (OpenCC 詞級)。

## Docs

| 路徑 | 內容 |
|------|------|
| `docs/superpowers/specs/2026-04-24-simptrad-keyboard-design.md` | V1 design spec — 架構、components、data flow、error handling、testing |
| `docs/superpowers/plans/2026-04-24-simptrad-keyboard.md` | V1 implementation plan — 11 parts, TDD bite-sized tasks |

## Project Setup (Part 0 — done)

- Xcode project is generated via **XcodeGen** from `project.yml`. Run `xcodegen generate` after editing `project.yml`. `SimpTradKeyboard.xcodeproj/` is gitignored.
- Bundle IDs: main app `com.qqna.simptradkeyboard`, extension `com.qqna.simptradkeyboard.keyboard`.
- **App Group identifier: `group.com.qqna.simptradkb`** — use this in `AppGroup.swift`.
- Build check: `xcodebuild -project SimpTradKeyboard.xcodeproj -scheme SimpTradKeyboard -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation build`
- **After adding any new file to `SimpTradKeyboard/` or `SimpTradKeyboardExtension/`, run `xcodegen generate` from the project root before `xcodebuild`** — XcodeGen globs at generation time, not at build time. A "BUILD SUCCEEDED" without regen means the new file was silently ignored.
- Package tests: `cd KeyboardCore && swift test`

## Execution

Plan tasks are executed subagent-driven. Part 0 is complete; begin at Part 1 Task 1.1. Skip plan tasks 0.1–0.4 (replaced by XcodeGen scaffolding).
