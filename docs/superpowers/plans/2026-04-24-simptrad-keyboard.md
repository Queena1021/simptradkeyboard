# SimpTradKeyboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS third-party keyboard that accepts Cangjie / Quick (速成) input and outputs either Simplified or Traditional Chinese via user toggle, with phrase-level OpenCC conversion, offline, no Full Access.

**Architecture:** Xcode project with two app targets (main SwiftUI settings app + UIKit keyboard extension) sharing a local Swift package `KeyboardCore` that holds all engine logic (trie lookup, OpenCC conversion, learning store, settings). State is shared via an App Group container.

**Tech Stack:** Swift 5.9+, iOS 16+, UIKit (extension), SwiftUI (main app), SQLite (GRDB.swift or raw `sqlite3`), OpenCC dictionary data, rime-cangjie5 / rime-quick5 code tables, XCTest, Swift Testing, GitHub Actions.

---

## File Structure

```
simptradkeyboard/
├── SimpTradKeyboard.xcodeproj/
├── SimpTradKeyboard/                     (main app target)
│   ├── SimpTradKeyboardApp.swift
│   ├── Views/
│   │   ├── SettingsView.swift
│   │   ├── OnboardingView.swift
│   │   └── LearningDataView.swift
│   └── Resources/
│       └── Assets.xcassets
├── SimpTradKeyboardExtension/            (keyboard extension target)
│   ├── Info.plist                        (NSExtension configured)
│   ├── KeyboardViewController.swift
│   ├── Views/
│   │   ├── KeyboardView.swift
│   │   ├── SymbolKeyboardView.swift
│   │   ├── CandidateBar.swift
│   │   └── KeyButton.swift
│   └── Layout/
│       └── KeyLayouts.swift              (layout constants: cangjie rows, symbol rows)
├── KeyboardCore/                         (local Swift package)
│   ├── Package.swift
│   ├── Sources/KeyboardCore/
│   │   ├── InputEngine/
│   │   │   ├── InputEngine.swift
│   │   │   ├── Trie.swift
│   │   │   └── Candidate.swift
│   │   ├── ConvertEngine/
│   │   │   ├── ConvertEngine.swift
│   │   │   └── OpenCCData.swift
│   │   ├── LearningStore/
│   │   │   ├── LearningStore.swift
│   │   │   └── SQLiteWrapper.swift
│   │   ├── Settings/
│   │   │   └── Settings.swift
│   │   └── AppGroup.swift
│   ├── Resources/
│   │   ├── cangjie5.trie
│   │   ├── quick5.trie
│   │   └── opencc/
│   │       ├── t2s_phrases.json
│   │       └── t2s_chars.json
│   └── Tests/KeyboardCoreTests/
│       ├── InputEngineTests.swift
│       ├── TrieTests.swift
│       ├── ConvertEngineTests.swift
│       ├── LearningStoreTests.swift
│       ├── SettingsTests.swift
│       └── Fixtures/
│           └── conversion_fixtures.json
├── tools/
│   └── build-trie/                       (Swift command-line data prep)
│       ├── Package.swift
│       └── Sources/build-trie/main.swift
├── .github/workflows/ci.yml
└── docs/ (specs, plans — already exists)
```

---

## Part 0: Project setup

### Task 0.1: Create Xcode project

**Files:**
- Create: `SimpTradKeyboard.xcodeproj/`
- Create: `SimpTradKeyboard/SimpTradKeyboardApp.swift`

- [ ] **Step 1: Create Xcode project**

Open Xcode → File → New → Project → iOS App.
- Product Name: `SimpTradKeyboard`
- Organization Identifier: `com.<yourname>`
- Bundle Identifier: `com.<yourname>.simptradkeyboard`
- Interface: SwiftUI
- Language: Swift
- Include Tests: yes (main app UI tests)
- Save under `/Users/qqna/project/simptradkeyboard/`

- [ ] **Step 2: Set iOS deployment target to 16.0**

In Xcode, select the project → Targets → `SimpTradKeyboard` → General → Minimum Deployments → iOS `16.0`.

- [ ] **Step 3: Verify build**

Run: `xcodebuild -project SimpTradKeyboard.xcodeproj -scheme SimpTradKeyboard -destination 'generic/platform=iOS Simulator' build`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add SimpTradKeyboard.xcodeproj SimpTradKeyboard/ .gitignore
git commit -m "chore: scaffold SimpTradKeyboard iOS app"
```

---

### Task 0.2: Add Keyboard extension target

**Files:**
- Create: `SimpTradKeyboardExtension/` (via Xcode template)
- Modify: `SimpTradKeyboard.xcodeproj`

- [ ] **Step 1: Add Custom Keyboard Extension target**

In Xcode: File → New → Target → iOS → Custom Keyboard Extension.
- Product Name: `SimpTradKeyboardExtension`
- Language: Swift
- Embed in Application: `SimpTradKeyboard`

- [ ] **Step 2: Set extension's iOS deployment target to 16.0**

Targets → `SimpTradKeyboardExtension` → General → Minimum Deployments → iOS `16.0`.

- [ ] **Step 3: Set Info.plist NSExtension attributes**

Open `SimpTradKeyboardExtension/Info.plist` and ensure:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>IsASCIICapable</key>
        <false/>
        <key>PrefersRightToLeft</key>
        <false/>
        <key>PrimaryLanguage</key>
        <string>zh-Hant</string>
        <key>RequestsOpenAccess</key>
        <false/>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.keyboard-service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).KeyboardViewController</string>
</dict>
```

- [ ] **Step 4: Build both targets**

Run: `xcodebuild -project SimpTradKeyboard.xcodeproj -scheme SimpTradKeyboard -destination 'generic/platform=iOS Simulator' build`

Expected: BUILD SUCCEEDED. Both targets compile.

- [ ] **Step 5: Commit**

```bash
git add SimpTradKeyboardExtension/ SimpTradKeyboard.xcodeproj
git commit -m "chore: add SimpTradKeyboardExtension keyboard target"
```

---

### Task 0.3: Configure App Group

**Files:**
- Modify: `SimpTradKeyboard/SimpTradKeyboard.entitlements`
- Modify: `SimpTradKeyboardExtension/SimpTradKeyboardExtension.entitlements`

- [ ] **Step 1: Enable App Groups capability on main app target**

Targets → `SimpTradKeyboard` → Signing & Capabilities → + Capability → App Groups → add group `group.com.<yourname>.simptradkb`.

- [ ] **Step 2: Enable same App Group on extension target**

Targets → `SimpTradKeyboardExtension` → Signing & Capabilities → + Capability → App Groups → enable the same `group.com.<yourname>.simptradkb`.

- [ ] **Step 3: Verify entitlements files contain the group**

Both `.entitlements` should have:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.<yourname>.simptradkb</string>
</array>
```

- [ ] **Step 4: Build**

Run: `xcodebuild build` (same as 0.2 Step 4).

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add SimpTradKeyboard/*.entitlements SimpTradKeyboardExtension/*.entitlements SimpTradKeyboard.xcodeproj
git commit -m "chore: enable App Group for settings/learning sharing"
```

---

### Task 0.4: Create KeyboardCore Swift package

**Files:**
- Create: `KeyboardCore/Package.swift`
- Create: `KeyboardCore/Sources/KeyboardCore/KeyboardCore.swift`
- Create: `KeyboardCore/Tests/KeyboardCoreTests/PackageSmokeTests.swift`

- [ ] **Step 1: Create package directory and Package.swift**

```bash
mkdir -p KeyboardCore/Sources/KeyboardCore KeyboardCore/Tests/KeyboardCoreTests
```

Write `KeyboardCore/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyboardCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "KeyboardCore", targets: ["KeyboardCore"])
    ],
    targets: [
        .target(
            name: "KeyboardCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KeyboardCoreTests",
            dependencies: ["KeyboardCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
```

- [ ] **Step 2: Create placeholder source file**

Write `KeyboardCore/Sources/KeyboardCore/KeyboardCore.swift`:

```swift
import Foundation

public enum KeyboardCore {
    public static let version = "0.1.0"
}
```

- [ ] **Step 3: Create placeholder resources directory**

```bash
mkdir -p KeyboardCore/Sources/KeyboardCore/Resources KeyboardCore/Tests/KeyboardCoreTests/Fixtures
touch KeyboardCore/Sources/KeyboardCore/Resources/.gitkeep
touch KeyboardCore/Tests/KeyboardCoreTests/Fixtures/.gitkeep
```

- [ ] **Step 4: Write smoke test**

Write `KeyboardCore/Tests/KeyboardCoreTests/PackageSmokeTests.swift`:

```swift
import XCTest
@testable import KeyboardCore

final class PackageSmokeTests: XCTestCase {
    func test_version_isNotEmpty() {
        XCTAssertFalse(KeyboardCore.version.isEmpty)
    }
}
```

- [ ] **Step 5: Run the test**

Run: `cd KeyboardCore && swift test`

Expected: `Test Suite 'All tests' passed`.

- [ ] **Step 6: Add package to Xcode project**

In Xcode → File → Add Package Dependencies → Add Local → select `KeyboardCore` folder.

Then add product `KeyboardCore` to both `SimpTradKeyboard` and `SimpTradKeyboardExtension` targets (Targets → Frameworks, Libraries → + → KeyboardCore).

- [ ] **Step 7: Verify both targets still build**

Run: `xcodebuild build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Commit**

```bash
git add KeyboardCore/ SimpTradKeyboard.xcodeproj
git commit -m "chore: add KeyboardCore local Swift package"
```

---

## Part 1: KeyboardCore — Trie and InputEngine

### Task 1.1: `Candidate` type

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/InputEngine/Candidate.swift`
- Create: `KeyboardCore/Tests/KeyboardCoreTests/CandidateTests.swift`

- [ ] **Step 1: Write the failing test**

Write `KeyboardCore/Tests/KeyboardCoreTests/CandidateTests.swift`:

```swift
import XCTest
@testable import KeyboardCore

final class CandidateTests: XCTestCase {
    func test_candidate_sortsByFrequencyDescending() {
        let a = Candidate(text: "日", frequency: 100, source: .builtin)
        let b = Candidate(text: "曰", frequency: 10, source: .builtin)
        XCTAssertGreaterThan(a.frequency, b.frequency)
    }

    func test_candidate_equatable() {
        let a = Candidate(text: "日", frequency: 100, source: .builtin)
        let b = Candidate(text: "日", frequency: 100, source: .builtin)
        XCTAssertEqual(a, b)
    }
}
```

- [ ] **Step 2: Run test, verify failure**

Run: `cd KeyboardCore && swift test --filter CandidateTests`
Expected: FAIL — "cannot find 'Candidate' in scope".

- [ ] **Step 3: Implement `Candidate`**

Write `KeyboardCore/Sources/KeyboardCore/InputEngine/Candidate.swift`:

```swift
import Foundation

public struct Candidate: Equatable, Hashable {
    public enum Source: String, Equatable, Hashable {
        case builtin
        case learned
    }

    public let text: String
    public let frequency: Int
    public let source: Source

    public init(text: String, frequency: Int, source: Source) {
        self.text = text
        self.frequency = frequency
        self.source = source
    }
}
```

- [ ] **Step 4: Run test, verify pass**

Run: `cd KeyboardCore && swift test --filter CandidateTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add KeyboardCore/
git commit -m "feat(core): add Candidate type"
```

---

### Task 1.2: `Trie` data structure

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/InputEngine/Trie.swift`
- Create: `KeyboardCore/Tests/KeyboardCoreTests/TrieTests.swift`

- [ ] **Step 1: Write failing tests**

Write `KeyboardCore/Tests/KeyboardCoreTests/TrieTests.swift`:

```swift
import XCTest
@testable import KeyboardCore

final class TrieTests: XCTestCase {
    func test_insertAndLookup_exactMatch() {
        var trie = Trie()
        trie.insert(key: "a", candidate: Candidate(text: "日", frequency: 9999, source: .builtin))
        let result = trie.lookup(key: "a")
        XCTAssertEqual(result, [Candidate(text: "日", frequency: 9999, source: .builtin)])
    }

    func test_insertMultipleForSameKey_returnsAllSortedByFrequency() {
        var trie = Trie()
        trie.insert(key: "a", candidate: Candidate(text: "曰", frequency: 10, source: .builtin))
        trie.insert(key: "a", candidate: Candidate(text: "日", frequency: 9999, source: .builtin))
        let result = trie.lookup(key: "a")
        XCTAssertEqual(result.map(\.text), ["日", "曰"])
    }

    func test_lookup_missingKey_returnsEmpty() {
        let trie = Trie()
        XCTAssertEqual(trie.lookup(key: "xyz"), [])
    }

    func test_lookup_isAutoCompleteFree_prefixDoesNotMatchDeeper() {
        var trie = Trie()
        trie.insert(key: "ap", candidate: Candidate(text: "曰", frequency: 1, source: .builtin))
        XCTAssertEqual(trie.lookup(key: "a"), [])
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

Run: `cd KeyboardCore && swift test --filter TrieTests`
Expected: FAIL — "cannot find 'Trie' in scope".

- [ ] **Step 3: Implement `Trie`**

Write `KeyboardCore/Sources/KeyboardCore/InputEngine/Trie.swift`:

```swift
import Foundation

public struct Trie {
    private final class Node {
        var children: [Character: Node] = [:]
        var candidates: [Candidate] = []
    }

    private let root = Node()

    public init() {}

    public mutating func insert(key: String, candidate: Candidate) {
        var node = root
        for ch in key {
            if let child = node.children[ch] {
                node = child
            } else {
                let child = Node()
                node.children[ch] = child
                node = child
            }
        }
        node.candidates.append(candidate)
        node.candidates.sort { $0.frequency > $1.frequency }
    }

    public func lookup(key: String) -> [Candidate] {
        var node = root
        for ch in key {
            guard let next = node.children[ch] else { return [] }
            node = next
        }
        return node.candidates
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `cd KeyboardCore && swift test --filter TrieTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add KeyboardCore/
git commit -m "feat(core): add Trie with frequency-sorted candidates"
```

---

### Task 1.3: Trie binary serialization

**Files:**
- Modify: `KeyboardCore/Sources/KeyboardCore/InputEngine/Trie.swift`
- Modify: `KeyboardCore/Tests/KeyboardCoreTests/TrieTests.swift`

- [ ] **Step 1: Add failing serialization tests**

Append to `TrieTests.swift`:

```swift
    func test_serialize_roundTrip() throws {
        var trie = Trie()
        trie.insert(key: "a", candidate: Candidate(text: "日", frequency: 9999, source: .builtin))
        trie.insert(key: "a", candidate: Candidate(text: "曰", frequency: 10, source: .builtin))
        trie.insert(key: "hqm", candidate: Candidate(text: "拜", frequency: 500, source: .builtin))

        let data = try trie.encode()
        let decoded = try Trie.decode(from: data)

        XCTAssertEqual(decoded.lookup(key: "a").map(\.text), ["日", "曰"])
        XCTAssertEqual(decoded.lookup(key: "hqm").map(\.text), ["拜"])
        XCTAssertEqual(decoded.lookup(key: "zzz"), [])
    }
```

- [ ] **Step 2: Run test, verify failure**

Run: `cd KeyboardCore && swift test --filter TrieTests.test_serialize_roundTrip`
Expected: FAIL — "no 'encode' method".

- [ ] **Step 3: Implement encode / decode using JSON (simple, correct; switch to custom binary later if needed)**

Append to `Trie.swift`:

```swift
extension Trie {
    fileprivate struct Entry: Codable {
        let key: String
        let text: String
        let frequency: Int
    }

    public func encode() throws -> Data {
        var entries: [Entry] = []
        collect(node: root, prefix: "", into: &entries)
        return try JSONEncoder().encode(entries)
    }

    public static func decode(from data: Data) throws -> Trie {
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        var trie = Trie()
        for e in entries {
            trie.insert(key: e.key, candidate: Candidate(text: e.text, frequency: e.frequency, source: .builtin))
        }
        return trie
    }

    private func collect(node: Node, prefix: String, into entries: inout [Entry]) {
        for c in node.candidates {
            entries.append(Entry(key: prefix, text: c.text, frequency: c.frequency))
        }
        for (ch, child) in node.children {
            collect(node: child, prefix: prefix + String(ch), into: &entries)
        }
    }
}
```

Note: `Node` is `private`; make it `fileprivate` so the extension can touch it:

Change in `Trie.swift`:

```swift
private struct Trie {
```

remains `public struct Trie`, but the nested `Node` class — change `private final class Node` to `fileprivate final class Node`.

- [ ] **Step 4: Run tests, verify all TrieTests pass**

Run: `cd KeyboardCore && swift test --filter TrieTests`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add KeyboardCore/
git commit -m "feat(core): add Trie JSON serialization"
```

---

### Task 1.4: Data prep — build Cangjie/Quick trie files from rime sources

**Files:**
- Create: `tools/build-trie/Package.swift`
- Create: `tools/build-trie/Sources/build-trie/main.swift`
- Create: `tools/data/cangjie5.dict.yaml` (downloaded; see Step 1)
- Create: `KeyboardCore/Sources/KeyboardCore/Resources/cangjie5.trie`
- Create: `KeyboardCore/Sources/KeyboardCore/Resources/quick5.trie`

- [ ] **Step 1: Download rime source dictionaries**

```bash
mkdir -p tools/data
curl -L -o tools/data/cangjie5.dict.yaml https://raw.githubusercontent.com/rime/rime-cangjie/master/cangjie5.dict.yaml
curl -L -o tools/data/quick5.dict.yaml https://raw.githubusercontent.com/rime/rime-quick/master/quick5.dict.yaml
```

Expected: both files saved, non-empty (`ls -l tools/data/` shows > 1MB each).

- [ ] **Step 2: Create the build-trie tool package**

```bash
mkdir -p tools/build-trie/Sources/build-trie
```

Write `tools/build-trie/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "build-trie",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../KeyboardCore")
    ],
    targets: [
        .executableTarget(
            name: "build-trie",
            dependencies: ["KeyboardCore"]
        )
    ]
)
```

- [ ] **Step 3: Write `main.swift` to parse rime YAML and emit `.trie`**

Write `tools/build-trie/Sources/build-trie/main.swift`:

```swift
import Foundation
import KeyboardCore

// Usage: build-trie <input.dict.yaml> <output.trie>

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: build-trie <input.yaml> <output.trie>\n".utf8))
    exit(2)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

let content = try String(contentsOfFile: inputPath, encoding: .utf8)

// Skip YAML header (everything up to and including "..." line or first blank line after header)
var inBody = false
var trie = Trie()
var count = 0

for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
    let s = String(line)
    if !inBody {
        if s.hasPrefix("...") { inBody = true }
        continue
    }
    if s.isEmpty || s.hasPrefix("#") { continue }
    // Rime table rows: "<text>\t<code>[\t<weight>]"
    let parts = s.split(separator: "\t", omittingEmptySubsequences: false)
    guard parts.count >= 2 else { continue }
    let text = String(parts[0])
    let code = String(parts[1])
    let weight = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0
    trie.insert(key: code, candidate: Candidate(text: text, frequency: weight, source: .builtin))
    count += 1
}

let data = try trie.encode()
try data.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(count) entries (\(data.count) bytes) to \(outputPath)")
```

- [ ] **Step 4: Build the tool**

Run: `cd tools/build-trie && swift build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Generate `.trie` resources**

```bash
cd tools/build-trie
swift run build-trie ../data/cangjie5.dict.yaml ../../KeyboardCore/Sources/KeyboardCore/Resources/cangjie5.trie
swift run build-trie ../data/quick5.dict.yaml ../../KeyboardCore/Sources/KeyboardCore/Resources/quick5.trie
cd ../..
```

Expected: prints "Wrote N entries..." twice. Resource files created.

- [ ] **Step 6: Sanity check trie files load**

Write a quick integration test, `KeyboardCore/Tests/KeyboardCoreTests/TrieResourceTests.swift`:

```swift
import XCTest
@testable import KeyboardCore

final class TrieResourceTests: XCTestCase {
    func test_cangjie5_loads() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "cangjie5", withExtension: "trie"))
        let data = try Data(contentsOf: url)
        let trie = try Trie.decode(from: data)
        // 「日」in Cangjie is "a"
        let cands = trie.lookup(key: "a")
        XCTAssertTrue(cands.contains { $0.text == "日" })
    }

    func test_quick5_loads() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "quick5", withExtension: "trie"))
        let data = try Data(contentsOf: url)
        let trie = try Trie.decode(from: data)
        // 「日」Quick code is "a" (single-code)
        let cands = trie.lookup(key: "a")
        XCTAssertTrue(cands.contains { $0.text == "日" })
    }
}
```

Run: `cd KeyboardCore && swift test --filter TrieResourceTests`

Expected: PASS.

- [ ] **Step 7: Commit**

Add `tools/data/*.yaml` to `.gitignore` (these are third-party rime sources, large, re-downloadable):

```bash
echo "tools/data/*.yaml" >> .gitignore
git add tools/ KeyboardCore/Sources/KeyboardCore/Resources/cangjie5.trie KeyboardCore/Sources/KeyboardCore/Resources/quick5.trie KeyboardCore/Tests/KeyboardCoreTests/TrieResourceTests.swift .gitignore
git commit -m "feat(data): build cangjie5/quick5 trie resources"
```

---

### Task 1.5: `InputEngine`

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/InputEngine/InputEngine.swift`
- Create: `KeyboardCore/Tests/KeyboardCoreTests/InputEngineTests.swift`

- [ ] **Step 1: Write failing tests**

Write `InputEngineTests.swift`:

```swift
import XCTest
@testable import KeyboardCore

final class InputEngineTests: XCTestCase {
    var engine: InputEngine!

    override func setUpWithError() throws {
        engine = try InputEngine.loadFromBundle()
    }

    func test_lookup_quick_singleCode_returnsExpectedCandidates() {
        let cands = engine.lookup(code: "a", mode: .quick)
        XCTAssertTrue(cands.contains { $0.text == "日" })
    }

    func test_lookup_cangjie_fullCode_returnsExactCharacter() {
        // 「日」Cangjie code is "a"
        let cands = engine.lookup(code: "a", mode: .cangjie)
        XCTAssertTrue(cands.contains { $0.text == "日" })
    }

    func test_lookup_invalidCode_returnsEmpty() {
        XCTAssertEqual(engine.lookup(code: "zzzzz", mode: .cangjie), [])
    }

    func test_lookup_emptyCode_returnsEmpty() {
        XCTAssertEqual(engine.lookup(code: "", mode: .cangjie), [])
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

Run: `cd KeyboardCore && swift test --filter InputEngineTests`
Expected: FAIL — "cannot find 'InputEngine'".

- [ ] **Step 3: Implement `InputEngine`**

Write `InputEngine.swift`:

```swift
import Foundation

public enum IMEMode: String, Equatable {
    case cangjie
    case quick
}

public final class InputEngine {
    private let cangjieTrie: Trie
    private let quickTrie: Trie

    public init(cangjieTrie: Trie, quickTrie: Trie) {
        self.cangjieTrie = cangjieTrie
        self.quickTrie = quickTrie
    }

    public static func loadFromBundle(_ bundle: Bundle = .module) throws -> InputEngine {
        let cangjieURL = bundle.url(forResource: "cangjie5", withExtension: "trie")!
        let quickURL = bundle.url(forResource: "quick5", withExtension: "trie")!
        let cangjie = try Trie.decode(from: Data(contentsOf: cangjieURL))
        let quick = try Trie.decode(from: Data(contentsOf: quickURL))
        return InputEngine(cangjieTrie: cangjie, quickTrie: quick)
    }

    public func lookup(code: String, mode: IMEMode) -> [Candidate] {
        guard !code.isEmpty else { return [] }
        switch mode {
        case .cangjie: return cangjieTrie.lookup(key: code)
        case .quick: return quickTrie.lookup(key: code)
        }
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `cd KeyboardCore && swift test --filter InputEngineTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add KeyboardCore/
git commit -m "feat(core): add InputEngine with cangjie/quick trie lookup"
```

---

## Part 2: KeyboardCore — ConvertEngine (T→S via OpenCC data)

### Task 2.1: Fetch OpenCC dictionary data

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/Resources/opencc/t2s_phrases.json`
- Create: `KeyboardCore/Sources/KeyboardCore/Resources/opencc/t2s_chars.json`

- [ ] **Step 1: Download OpenCC source text dictionaries**

```bash
mkdir -p tools/data/opencc
curl -L -o tools/data/opencc/TSPhrases.txt https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/TSPhrases.txt
curl -L -o tools/data/opencc/TSCharacters.txt https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/TSCharacters.txt
```

Expected: two files, non-empty.

- [ ] **Step 2: Create a conversion script to transform txt → JSON dict**

Write `tools/build-trie/Sources/build-trie/opencc.swift`:

```swift
import Foundation

public enum OpenCCBuilder {
    /// Transforms rows of "<traditional>\t<simplified>[ <alt> ...]" into [String: String]
    /// (first simplified variant is kept — canonical mapping).
    public static func buildDict(from inputPath: String, to outputPath: String) throws {
        let content = try String(contentsOfFile: inputPath, encoding: .utf8)
        var dict: [String: String] = [:]
        for line in content.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count == 2 else { continue }
            let trad = String(parts[0])
            let simpFirst = String(parts[1].split(separator: " ").first ?? "")
            guard !simpFirst.isEmpty else { continue }
            dict[trad] = simpFirst
        }
        let data = try JSONEncoder().encode(dict)
        try data.write(to: URL(fileURLWithPath: outputPath))
        print("Wrote \(dict.count) entries (\(data.count) bytes) to \(outputPath)")
    }
}
```

Extend `main.swift` to dispatch on arg:

Replace `main.swift` with:

```swift
import Foundation
import KeyboardCore

let args = CommandLine.arguments

func usage() -> Never {
    FileHandle.standardError.write(Data("""
Usage:
  build-trie trie <input.yaml> <output.trie>
  build-trie opencc <input.txt> <output.json>

""".utf8))
    exit(2)
}

guard args.count >= 4 else { usage() }

switch args[1] {
case "trie":
    let inputPath = args[2]
    let outputPath = args[3]
    let content = try String(contentsOfFile: inputPath, encoding: .utf8)
    var inBody = false
    var trie = Trie()
    var count = 0
    for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
        let s = String(line)
        if !inBody { if s.hasPrefix("...") { inBody = true }; continue }
        if s.isEmpty || s.hasPrefix("#") { continue }
        let parts = s.split(separator: "\t", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { continue }
        let text = String(parts[0])
        let code = String(parts[1])
        let weight = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0
        trie.insert(key: code, candidate: Candidate(text: text, frequency: weight, source: .builtin))
        count += 1
    }
    let data = try trie.encode()
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(count) entries (\(data.count) bytes) to \(outputPath)")
case "opencc":
    try OpenCCBuilder.buildDict(from: args[2], to: args[3])
default:
    usage()
}
```

- [ ] **Step 3: Build the tool**

Run: `cd tools/build-trie && swift build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Generate JSON dictionaries**

```bash
mkdir -p KeyboardCore/Sources/KeyboardCore/Resources/opencc
cd tools/build-trie
swift run build-trie opencc ../data/opencc/TSPhrases.txt ../../KeyboardCore/Sources/KeyboardCore/Resources/opencc/t2s_phrases.json
swift run build-trie opencc ../data/opencc/TSCharacters.txt ../../KeyboardCore/Sources/KeyboardCore/Resources/opencc/t2s_chars.json
cd ../..
```

Expected: "Wrote N entries…" twice.

- [ ] **Step 5: Commit**

```bash
echo "tools/data/opencc/" >> .gitignore
git add KeyboardCore/Sources/KeyboardCore/Resources/opencc/ tools/build-trie/Sources/build-trie/ .gitignore
git commit -m "feat(data): bundle OpenCC T→S phrase and char dictionaries"
```

---

### Task 2.2: `ConvertEngine` — T→S

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/ConvertEngine/ConvertEngine.swift`
- Create: `KeyboardCore/Tests/KeyboardCoreTests/ConvertEngineTests.swift`

- [ ] **Step 1: Write failing tests**

Write `ConvertEngineTests.swift`:

```swift
import XCTest
@testable import KeyboardCore

final class ConvertEngineTests: XCTestCase {
    var engine: ConvertEngine!

    override func setUpWithError() throws {
        engine = try ConvertEngine.loadFromBundle()
    }

    func test_convert_T2S_singleChar_fa() {
        XCTAssertEqual(engine.convert("發", to: .simplified), "发")
    }

    func test_convert_T2S_phraseOverridesChar_touFa() {
        // 「頭髮」should map to 「头发」(phrase match), not 「头發」(char-only)
        XCTAssertEqual(engine.convert("頭髮", to: .simplified), "头发")
    }

    func test_convert_T2S_phraseOverridesChar_faZhan() {
        XCTAssertEqual(engine.convert("發展", to: .simplified), "发展")
    }

    func test_convert_T2S_noMatch_returnsInput() {
        XCTAssertEqual(engine.convert("xyz", to: .simplified), "xyz")
    }

    func test_convert_T2S_mixedText() {
        XCTAssertEqual(engine.convert("我發現了", to: .simplified), "我发现了")
    }

    func test_convert_traditional_isPassthrough_inV1() {
        // V1 does not implement S→T; .traditional returns input unchanged.
        XCTAssertEqual(engine.convert("发", to: .traditional), "发")
    }

    func test_convert_empty() {
        XCTAssertEqual(engine.convert("", to: .simplified), "")
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

Run: `cd KeyboardCore && swift test --filter ConvertEngineTests`
Expected: FAIL — "cannot find 'ConvertEngine'".

- [ ] **Step 3: Implement `ConvertEngine`**

Write `ConvertEngine.swift`:

```swift
import Foundation

public enum OutputMode: String, Equatable {
    case simplified
    case traditional
}

public final class ConvertEngine {
    private let phraseDict: [String: String]
    private let charDict: [String: String]
    private let maxPhraseLength: Int

    public init(phraseDict: [String: String], charDict: [String: String]) {
        self.phraseDict = phraseDict
        self.charDict = charDict
        self.maxPhraseLength = phraseDict.keys.map { $0.count }.max() ?? 0
    }

    public static func loadFromBundle(_ bundle: Bundle = .module) throws -> ConvertEngine {
        let phrasesURL = bundle.url(forResource: "t2s_phrases", withExtension: "json", subdirectory: "opencc")!
        let charsURL = bundle.url(forResource: "t2s_chars", withExtension: "json", subdirectory: "opencc")!
        let phrases = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: phrasesURL))
        let chars = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: charsURL))
        return ConvertEngine(phraseDict: phrases, charDict: chars)
    }

    public func convert(_ text: String, to mode: OutputMode) -> String {
        guard mode == .simplified else { return text }
        guard !text.isEmpty else { return text }
        let chars = Array(text)
        var result = ""
        var i = 0
        while i < chars.count {
            // Longest-match phrase scan
            var matched = false
            let maxLen = min(maxPhraseLength, chars.count - i)
            if maxLen >= 2 {
                var len = maxLen
                while len >= 2 {
                    let candidate = String(chars[i..<i+len])
                    if let mapped = phraseDict[candidate] {
                        result += mapped
                        i += len
                        matched = true
                        break
                    }
                    len -= 1
                }
            }
            if !matched {
                let single = String(chars[i])
                result += charDict[single] ?? single
                i += 1
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `cd KeyboardCore && swift test --filter ConvertEngineTests`
Expected: 7 tests pass.

(If `t2s_phrases.json` happens to lack `發展` or `頭髮`, inspect the source OpenCC data and confirm. These are standard entries in `TSPhrases.txt`.)

- [ ] **Step 5: Commit**

```bash
git add KeyboardCore/
git commit -m "feat(core): add ConvertEngine with OpenCC phrase-level T→S"
```

---

### Task 2.3: Golden fixture tests for conversion

**Files:**
- Create: `KeyboardCore/Tests/KeyboardCoreTests/Fixtures/conversion_fixtures.json`
- Modify: `KeyboardCore/Tests/KeyboardCoreTests/ConvertEngineTests.swift`

- [ ] **Step 1: Write fixture file**

Write `KeyboardCore/Tests/KeyboardCoreTests/Fixtures/conversion_fixtures.json`:

```json
[
  {"traditional": "發展", "simplified": "发展"},
  {"traditional": "頭髮", "simplified": "头发"},
  {"traditional": "我發現了", "simplified": "我发现了"},
  {"traditional": "中國", "simplified": "中国"},
  {"traditional": "電腦", "simplified": "电脑"},
  {"traditional": "網絡", "simplified": "网络"},
  {"traditional": "臺灣", "simplified": "台湾"},
  {"traditional": "學校", "simplified": "学校"},
  {"traditional": "書籍", "simplified": "书籍"},
  {"traditional": "讀書", "simplified": "读书"}
]
```

- [ ] **Step 2: Add parametrized golden test**

Append to `ConvertEngineTests.swift`:

```swift
    struct ConversionPair: Decodable {
        let traditional: String
        let simplified: String
    }

    func test_golden_conversionFixtures() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "conversion_fixtures", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let pairs = try JSONDecoder().decode([ConversionPair].self, from: data)
        XCTAssertFalse(pairs.isEmpty)
        for p in pairs {
            XCTAssertEqual(engine.convert(p.traditional, to: .simplified),
                           p.simplified,
                           "T→S failure for \(p.traditional)")
        }
    }
```

- [ ] **Step 3: Run test, verify pass**

Run: `cd KeyboardCore && swift test --filter test_golden_conversionFixtures`
Expected: PASS.

If any individual pair fails, investigate: it usually means OpenCC data does not contain that exact phrase (use only entries verified against TSPhrases.txt).

- [ ] **Step 4: Commit**

```bash
git add KeyboardCore/
git commit -m "test(core): golden fixture file for T→S conversion"
```

---

## Part 3: KeyboardCore — LearningStore

### Task 3.1: `LearningStore` with SQLite

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/LearningStore/LearningStore.swift`
- Create: `KeyboardCore/Tests/KeyboardCoreTests/LearningStoreTests.swift`

- [ ] **Step 1: Write failing tests**

Write `LearningStoreTests.swift`:

```swift
import XCTest
@testable import KeyboardCore

final class LearningStoreTests: XCTestCase {
    var store: LearningStore!

    override func setUpWithError() throws {
        store = try LearningStore(path: ":memory:")
    }

    func test_frequencyBoost_unknownReturnsZero() {
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 0)
    }

    func test_recordSelection_incrementsCount() {
        store.recordSelection(code: "a", candidate: "日")
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 1)
        store.recordSelection(code: "a", candidate: "日")
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 2)
    }

    func test_recordSelection_isolatesByCandidate() {
        store.recordSelection(code: "a", candidate: "日")
        store.recordSelection(code: "a", candidate: "日")
        store.recordSelection(code: "a", candidate: "曰")
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 2)
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "曰"), 1)
    }

    func test_reset_clearsAllEntries() {
        store.recordSelection(code: "a", candidate: "日")
        store.reset()
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 0)
    }

    func test_allEntries_returnsRecorded() {
        store.recordSelection(code: "a", candidate: "日")
        store.recordSelection(code: "b", candidate: "月")
        let entries = store.allEntries()
        XCTAssertEqual(entries.count, 2)
    }

    func test_concurrentWrites_noCrash() {
        let exp = expectation(description: "concurrent")
        exp.expectedFulfillmentCount = 100
        for i in 0..<100 {
            DispatchQueue.global().async {
                self.store.recordSelection(code: "a", candidate: "日")
                if i % 10 == 0 {
                    _ = self.store.frequencyBoost(code: "a", candidate: "日")
                }
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 5)
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 100)
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

Run: `cd KeyboardCore && swift test --filter LearningStoreTests`
Expected: FAIL — "cannot find 'LearningStore'".

- [ ] **Step 3: Implement `LearningStore` using system `sqlite3`**

Write `LearningStore.swift`:

```swift
import Foundation
import SQLite3

public final class LearningStore {
    public struct Entry: Equatable {
        public let code: String
        public let candidate: String
        public let count: Int
    }

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "LearningStore.serial")

    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open(path, &handle) == SQLITE_OK else {
            if let h = handle { sqlite3_close(h) }
            throw NSError(domain: "LearningStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "sqlite3_open failed"])
        }
        self.db = handle

        let sql = """
        CREATE TABLE IF NOT EXISTS selections (
            code TEXT NOT NULL,
            candidate TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 0,
            last_used INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (code, candidate)
        );
        """
        try exec(sql)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    public func recordSelection(code: String, candidate: String) {
        queue.sync {
            let sql = """
            INSERT INTO selections(code, candidate, count, last_used)
            VALUES(?, ?, 1, ?)
            ON CONFLICT(code, candidate)
            DO UPDATE SET count = count + 1, last_used = excluded.last_used;
            """
            let now = Int64(Date().timeIntervalSince1970)
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, code, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, candidate, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int64(stmt, 3, now)
            _ = sqlite3_step(stmt)
        }
    }

    public func frequencyBoost(code: String, candidate: String) -> Int {
        queue.sync {
            let sql = "SELECT count FROM selections WHERE code = ? AND candidate = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, code, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, candidate, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if sqlite3_step(stmt) == SQLITE_ROW {
                return Int(sqlite3_column_int64(stmt, 0))
            }
            return 0
        }
    }

    public func reset() {
        queue.sync { try? exec("DELETE FROM selections;") }
    }

    public func allEntries() -> [Entry] {
        queue.sync {
            var out: [Entry] = []
            let sql = "SELECT code, candidate, count FROM selections ORDER BY count DESC;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let code = String(cString: sqlite3_column_text(stmt, 0))
                let cand = String(cString: sqlite3_column_text(stmt, 1))
                let cnt = Int(sqlite3_column_int64(stmt, 2))
                out.append(Entry(code: code, candidate: cand, count: cnt))
            }
            return out
        }
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw NSError(domain: "LearningStore", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `cd KeyboardCore && swift test --filter LearningStoreTests`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add KeyboardCore/
git commit -m "feat(core): add LearningStore backed by sqlite"
```

---

## Part 4: KeyboardCore — Settings and AppGroup

### Task 4.1: `AppGroup` helper

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/AppGroup.swift`

- [ ] **Step 1: Write file**

Write `AppGroup.swift`:

```swift
import Foundation

public enum AppGroup {
    /// The App Group identifier shared between the main app and the keyboard extension.
    /// Must match the value configured in both `.entitlements` files.
    public static let identifier = "group.com.<yourname>.simptradkb"

    public static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static func userDefaults() -> UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    public static func learningDBURL() -> URL? {
        containerURL()?.appendingPathComponent("learning.sqlite")
    }
}
```

Note: `<yourname>` must be replaced to match the actual bundle identifier configured in Task 0.3. Use a single constant so there's exactly one place to update.

- [ ] **Step 2: Commit (no tests — pure config)**

```bash
git add KeyboardCore/Sources/KeyboardCore/AppGroup.swift
git commit -m "feat(core): add AppGroup identifier constants"
```

---

### Task 4.2: `Settings` wrapper

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/Settings/Settings.swift`
- Create: `KeyboardCore/Tests/KeyboardCoreTests/SettingsTests.swift`

- [ ] **Step 1: Write failing tests**

Write `SettingsTests.swift`:

```swift
import XCTest
@testable import KeyboardCore

final class SettingsTests: XCTestCase {
    var defaults: UserDefaults!
    var settings: Settings!

    override func setUp() {
        defaults = UserDefaults(suiteName: "SettingsTests-\(UUID().uuidString)")
        settings = Settings(defaults: defaults)
    }

    func test_defaults_outputMode_isTraditional() {
        XCTAssertEqual(settings.outputMode, .traditional)
    }

    func test_defaults_imeMode_isQuick() {
        XCTAssertEqual(settings.imeMode, .quick)
    }

    func test_setOutputMode_persists() {
        settings.outputMode = .simplified
        let reloaded = Settings(defaults: defaults)
        XCTAssertEqual(reloaded.outputMode, .simplified)
    }

    func test_setImeMode_persists() {
        settings.imeMode = .cangjie
        let reloaded = Settings(defaults: defaults)
        XCTAssertEqual(reloaded.imeMode, .cangjie)
    }
}
```

- [ ] **Step 2: Run test, verify failure**

Run: `cd KeyboardCore && swift test --filter SettingsTests`
Expected: FAIL.

- [ ] **Step 3: Implement `Settings`**

Write `Settings.swift`:

```swift
import Foundation

public final class Settings {
    private let defaults: UserDefaults

    private enum Key {
        static let outputMode = "outputMode"
        static let imeMode = "imeMode"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public static func shared() -> Settings {
        Settings(defaults: AppGroup.userDefaults() ?? .standard)
    }

    public var outputMode: OutputMode {
        get {
            (defaults.string(forKey: Key.outputMode).flatMap(OutputMode.init(rawValue:))) ?? .traditional
        }
        set { defaults.set(newValue.rawValue, forKey: Key.outputMode) }
    }

    public var imeMode: IMEMode {
        get {
            (defaults.string(forKey: Key.imeMode).flatMap(IMEMode.init(rawValue:))) ?? .quick
        }
        set { defaults.set(newValue.rawValue, forKey: Key.imeMode) }
    }
}
```

- [ ] **Step 4: Run test, verify pass**

Run: `cd KeyboardCore && swift test --filter SettingsTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add KeyboardCore/
git commit -m "feat(core): add Settings wrapper over UserDefaults"
```

---

## Part 5: Keyboard Extension — shell wiring

### Task 5.1: `KeyboardViewController` skeleton

**Files:**
- Modify: `SimpTradKeyboardExtension/KeyboardViewController.swift`

- [ ] **Step 1: Replace the Xcode template with our skeleton**

Write `SimpTradKeyboardExtension/KeyboardViewController.swift`:

```swift
import UIKit
import KeyboardCore

final class KeyboardViewController: UIInputViewController {
    private var inputEngine: InputEngine?
    private var convertEngine: ConvertEngine?
    private var learningStore: LearningStore?
    private var settings: Settings = .shared()

    private var composingBuffer: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        loadEngines()
        // TODO (Task 5.2): build keyboard UI
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settings = .shared() // re-read after main app may have changed
    }

    private func loadEngines() {
        do {
            inputEngine = try InputEngine.loadFromBundle(.main)
            convertEngine = try ConvertEngine.loadFromBundle(.main)
            if let url = AppGroup.learningDBURL() {
                learningStore = try? LearningStore(path: url.path)
            }
        } catch {
            NSLog("[SimpTradKeyboard] engine load failed: \(error)")
        }
    }
}
```

Note: `.main` bundle is used because resources are copied into the extension bundle (see Step 2).

- [ ] **Step 2: Ensure KeyboardCore resources are embedded in the extension**

KeyboardCore's `Bundle.module` resolves to the package resource bundle. Because the package's resource bundle is vended as a sub-bundle inside any consumer target, our runtime loader must use `Bundle(for: ...)` + module resource bundle lookup. Adjust loader calls:

Modify `InputEngine.swift` and `ConvertEngine.swift`:

In `InputEngine.loadFromBundle`, change default from `.module` to a resolved module bundle. Replace signature with:

```swift
public static func loadFromBundle(_ bundle: Bundle = .module) throws -> InputEngine {
```

This already works — `.module` is synthesized for Swift packages. The extension target links the package, so `Bundle.module` inside KeyboardCore code resolves to the package's own resource bundle which is copied into the extension. Leave `.module` as default.

Update `KeyboardViewController.swift` accordingly:

```swift
    private func loadEngines() {
        do {
            inputEngine = try InputEngine.loadFromBundle()
            convertEngine = try ConvertEngine.loadFromBundle()
            if let url = AppGroup.learningDBURL() {
                learningStore = try? LearningStore(path: url.path)
            }
        } catch {
            NSLog("[SimpTradKeyboard] engine load failed: \(error)")
        }
    }
```

- [ ] **Step 3: Build extension**

Run: `xcodebuild -project SimpTradKeyboard.xcodeproj -scheme SimpTradKeyboard -destination 'generic/platform=iOS Simulator' build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add SimpTradKeyboardExtension/
git commit -m "feat(ext): wire KeyboardCore engines into extension controller"
```

---

### Task 5.2: `KeyLayouts` constants

**Files:**
- Create: `SimpTradKeyboardExtension/Layout/KeyLayouts.swift`

- [ ] **Step 1: Write layout constants**

Write `SimpTradKeyboardExtension/Layout/KeyLayouts.swift`:

```swift
import Foundation

enum KeyKind: Equatable {
    case code(key: String, label: String)       // e.g. ("a", "日") — 倉頡 radical key
    case symbol(String)                          // literal char to insert (e.g. "，")
    case delete
    case space
    case `return`
    case toggleSymbols                           // switch to number/symbol layout
    case toggleChinese                           // switch back to Chinese layout
    case toggleSimpTrad                          // cycle simplified/traditional
    case globe                                   // advanceToNextInputMode
    case emoji                                   // placeholder: does nothing in V1
    case moreSymbols                             // #+= layer, V1 no-op
}

struct KeyRow {
    let keys: [KeyKind]
}

enum KeyLayouts {
    // Native iOS 速成 layout (3 code rows + bottom control row)
    static let chineseRows: [KeyRow] = [
        KeyRow(keys: [
            .code(key: "q", label: "手"),
            .code(key: "w", label: "田"),
            .code(key: "e", label: "水"),
            .code(key: "r", label: "口"),
            .code(key: "t", label: "廿"),
            .code(key: "y", label: "卜"),
            .code(key: "u", label: "山"),
            .code(key: "i", label: "戈"),
            .code(key: "o", label: "人"),
            .code(key: "p", label: "心")
        ]),
        KeyRow(keys: [
            .code(key: "a", label: "日"),
            .code(key: "s", label: "尸"),
            .code(key: "d", label: "木"),
            .code(key: "f", label: "火"),
            .code(key: "g", label: "土"),
            .code(key: "h", label: "竹"),
            .code(key: "j", label: "十"),
            .code(key: "k", label: "大"),
            .code(key: "l", label: "中")
        ]),
        KeyRow(keys: [
            .code(key: "z", label: "重"),
            .code(key: "x", label: "難"),
            .code(key: "c", label: "金"),
            .code(key: "v", label: "女"),
            .code(key: "b", label: "月"),
            .code(key: "n", label: "弓"),
            .code(key: "m", label: "一"),
            .delete
        ]),
        KeyRow(keys: [
            .toggleSymbols,
            .emoji,
            .space,
            .toggleSimpTrad,
            .return
        ])
    ]

    static let symbolRows: [KeyRow] = [
        KeyRow(keys: [
            .symbol("1"), .symbol("2"), .symbol("3"), .symbol("4"), .symbol("5"),
            .symbol("6"), .symbol("7"), .symbol("8"), .symbol("9"), .symbol("0")
        ]),
        KeyRow(keys: [
            .symbol("-"), .symbol("/"), .symbol(":"), .symbol(";"), .symbol("("),
            .symbol(")"), .symbol("$"), .symbol("@"), .symbol("「"), .symbol("」")
        ]),
        KeyRow(keys: [
            .moreSymbols, .symbol("。"), .symbol("，"), .symbol("、"), .symbol("?"),
            .symbol("!"), .symbol("."), .delete
        ]),
        KeyRow(keys: [
            .toggleChinese, .emoji, .space, .return
        ])
    ]
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimpTradKeyboardExtension/Layout/
git commit -m "feat(ext): define key layouts for Chinese and symbol modes"
```

---

### Task 5.3: `KeyButton` custom UIButton

**Files:**
- Create: `SimpTradKeyboardExtension/Views/KeyButton.swift`

- [ ] **Step 1: Write `KeyButton`**

Write `SimpTradKeyboardExtension/Views/KeyButton.swift`:

```swift
import UIKit

final class KeyButton: UIButton {
    let kind: KeyKind
    var onTap: (() -> Void)?
    var onLongPressRepeat: (() -> Void)?
    private var repeatTimer: Timer?

    init(kind: KeyKind) {
        self.kind = kind
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
        setTitleColor(.label, for: .normal)
        applyStyle()
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        if case .delete = kind {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.3
            addGestureRecognizer(longPress)
        }
    }

    private func applyStyle() {
        switch kind {
        case .return:
            backgroundColor = .systemBlue
            setTitle("→", for: .normal)
            setTitleColor(.white, for: .normal)
        case .code(_, let label):
            backgroundColor = UIColor.systemGray3.withAlphaComponent(0.6)
            setTitle(label, for: .normal)
        case .symbol(let s):
            backgroundColor = UIColor.systemGray3.withAlphaComponent(0.6)
            setTitle(s, for: .normal)
        case .delete:
            backgroundColor = UIColor.systemGray4.withAlphaComponent(0.6)
            setTitle("⌫", for: .normal)
        case .space:
            backgroundColor = UIColor.systemGray3.withAlphaComponent(0.6)
            setTitle(" ", for: .normal)
        case .toggleSymbols:
            backgroundColor = UIColor.systemGray4.withAlphaComponent(0.6)
            setTitle("123", for: .normal)
        case .toggleChinese:
            backgroundColor = UIColor.systemGray4.withAlphaComponent(0.6)
            setTitle("速成", for: .normal)
        case .toggleSimpTrad:
            backgroundColor = UIColor.systemGray4.withAlphaComponent(0.6)
            setTitle("繁", for: .normal) // updated externally
        case .globe:
            backgroundColor = UIColor.systemGray4.withAlphaComponent(0.6)
            setTitle("🌐", for: .normal)
        case .emoji:
            backgroundColor = UIColor.systemGray4.withAlphaComponent(0.6)
            setTitle("😀", for: .normal)
        case .moreSymbols:
            backgroundColor = UIColor.systemGray4.withAlphaComponent(0.6)
            setTitle("#+=", for: .normal)
        }
    }

    @objc private func handleTap() { onTap?() }

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        switch g.state {
        case .began:
            repeatTimer?.invalidate()
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.onLongPressRepeat?()
            }
        case .ended, .cancelled, .failed:
            repeatTimer?.invalidate()
            repeatTimer = nil
        default: break
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimpTradKeyboardExtension/Views/KeyButton.swift
git commit -m "feat(ext): add KeyButton with styling and long-press repeat"
```

---

### Task 5.4: `KeyboardView` (Chinese layout render)

**Files:**
- Create: `SimpTradKeyboardExtension/Views/KeyboardView.swift`

- [ ] **Step 1: Write `KeyboardView`**

Write `SimpTradKeyboardExtension/Views/KeyboardView.swift`:

```swift
import UIKit

final class KeyboardView: UIView {
    var onKeyTap: ((KeyKind) -> Void)?
    var onDeleteRepeat: (() -> Void)?

    private var buttons: [KeyButton] = []
    private let vStack = UIStackView()

    init(rows: [KeyRow]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        setupStack(rows: rows)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupStack(rows: [KeyRow]) {
        vStack.axis = .vertical
        vStack.spacing = 8
        vStack.distribution = .fillEqually
        vStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            vStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            vStack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            vStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        for row in rows {
            let h = UIStackView()
            h.axis = .horizontal
            h.spacing = 6
            h.distribution = .fillEqually
            for key in row.keys {
                let btn = KeyButton(kind: key)
                btn.onTap = { [weak self] in self?.onKeyTap?(key) }
                if case .delete = key {
                    btn.onLongPressRepeat = { [weak self] in self?.onDeleteRepeat?() }
                }
                h.addArrangedSubview(btn)
                buttons.append(btn)
            }
            vStack.addArrangedSubview(h)
        }
    }

    /// Update the label of the toggleSimpTrad button to reflect current mode.
    func updateSimpTradToggle(showing mode: String) {
        for btn in buttons {
            if case .toggleSimpTrad = btn.kind {
                btn.setTitle(mode, for: .normal)
            }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimpTradKeyboardExtension/Views/KeyboardView.swift
git commit -m "feat(ext): render KeyboardView from KeyRow layout"
```

---

### Task 5.5: Mount `KeyboardView` in controller, hook taps

**Files:**
- Modify: `SimpTradKeyboardExtension/KeyboardViewController.swift`

- [ ] **Step 1: Update controller to build and manage the keyboard view**

Replace `KeyboardViewController.swift`:

```swift
import UIKit
import KeyboardCore

final class KeyboardViewController: UIInputViewController {
    private var inputEngine: InputEngine?
    private var convertEngine: ConvertEngine?
    private var learningStore: LearningStore?
    private var settings: Settings = .shared()

    private var composingBuffer: String = ""
    private enum LayoutMode { case chinese, symbols }
    private var layoutMode: LayoutMode = .chinese
    private var keyboardView: KeyboardView?

    override func viewDidLoad() {
        super.viewDidLoad()
        loadEngines()
        rebuildKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settings = .shared()
        keyboardView?.updateSimpTradToggle(showing: settings.outputMode == .simplified ? "简" : "繁")
    }

    private func loadEngines() {
        do {
            inputEngine = try InputEngine.loadFromBundle()
            convertEngine = try ConvertEngine.loadFromBundle()
            if let url = AppGroup.learningDBURL() {
                learningStore = try? LearningStore(path: url.path)
            }
        } catch {
            NSLog("[SimpTradKeyboard] engine load failed: \(error)")
        }
    }

    private func rebuildKeyboard() {
        keyboardView?.removeFromSuperview()
        let rows: [KeyRow] = (layoutMode == .chinese) ? KeyLayouts.chineseRows : KeyLayouts.symbolRows
        let view = KeyboardView(rows: rows)
        view.onKeyTap = { [weak self] in self?.handleKey($0) }
        view.onDeleteRepeat = { [weak self] in self?.handleKey(.delete) }
        self.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            view.topAnchor.constraint(equalTo: self.view.topAnchor),
            view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        keyboardView = view
        view.updateSimpTradToggle(showing: settings.outputMode == .simplified ? "简" : "繁")
    }

    private func handleKey(_ key: KeyKind) {
        switch key {
        case .code(let k, _):
            composingBuffer += k
            // TODO Task 6: update candidate bar
        case .symbol(let s):
            commitComposingIfNeeded()
            textDocumentProxy.insertText(s)
        case .delete:
            if !composingBuffer.isEmpty {
                composingBuffer.removeLast()
                // TODO Task 6: refresh candidates
            } else {
                textDocumentProxy.deleteBackward()
            }
        case .space:
            // TODO Task 6: commit first candidate; if no buffer, insert space
            commitComposingIfNeeded()
            textDocumentProxy.insertText(" ")
        case .return:
            commitComposingIfNeeded()
            textDocumentProxy.insertText("\n")
        case .toggleSymbols:
            layoutMode = .symbols
            rebuildKeyboard()
        case .toggleChinese:
            layoutMode = .chinese
            rebuildKeyboard()
        case .toggleSimpTrad:
            settings.outputMode = (settings.outputMode == .simplified) ? .traditional : .simplified
            keyboardView?.updateSimpTradToggle(showing: settings.outputMode == .simplified ? "简" : "繁")
            // TODO Task 6: re-render candidates with new mode
        case .globe:
            advanceToNextInputMode()
        case .emoji, .moreSymbols:
            break
        }
    }

    private func commitComposingIfNeeded() {
        guard !composingBuffer.isEmpty else { return }
        // Naive: insert first trie hit as fallback (Task 6 refines this)
        composingBuffer = ""
    }
}
```

- [ ] **Step 2: Build & run in simulator**

Run: `xcodebuild -project SimpTradKeyboard.xcodeproj -scheme SimpTradKeyboard -destination 'platform=iOS Simulator,name=iPhone 15' build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimpTradKeyboardExtension/KeyboardViewController.swift
git commit -m "feat(ext): mount KeyboardView and route key taps"
```

---

## Part 6: Candidate bar and typing flow

### Task 6.1: `CandidateBar` UI

**Files:**
- Create: `SimpTradKeyboardExtension/Views/CandidateBar.swift`

- [ ] **Step 1: Write `CandidateBar`**

Write `SimpTradKeyboardExtension/Views/CandidateBar.swift`:

```swift
import UIKit
import KeyboardCore

final class CandidateBar: UIView {
    var onSelect: ((Candidate) -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var candidates: [Candidate] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        setupScroll()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupScroll() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        addSubview(scroll)
        stack.axis = .horizontal
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])
    }

    func show(_ candidates: [Candidate]) {
        self.candidates = candidates
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for c in candidates {
            let btn = UIButton(type: .system)
            btn.setTitle("  \(c.text)  ", for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 22)
            btn.setTitleColor(.label, for: .normal)
            btn.addAction(UIAction { [weak self] _ in self?.onSelect?(c) }, for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }
    }

    func clear() {
        candidates = []
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    var firstCandidate: Candidate? { candidates.first }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimpTradKeyboardExtension/Views/CandidateBar.swift
git commit -m "feat(ext): add CandidateBar horizontal scroll view"
```

---

### Task 6.2: Wire candidates into controller

**Files:**
- Modify: `SimpTradKeyboardExtension/KeyboardViewController.swift`

- [ ] **Step 1: Mount CandidateBar at top of extension view**

Replace `KeyboardViewController.swift` body with:

```swift
import UIKit
import KeyboardCore

final class KeyboardViewController: UIInputViewController {
    private var inputEngine: InputEngine?
    private var convertEngine: ConvertEngine?
    private var learningStore: LearningStore?
    private var settings: Settings = .shared()

    private var composingBuffer: String = ""
    private enum LayoutMode { case chinese, symbols }
    private var layoutMode: LayoutMode = .chinese
    private var keyboardView: KeyboardView?
    private let candidateBar = CandidateBar()

    private struct DisplayedCandidate {
        let display: String        // maybe simplified
        let original: Candidate    // traditional (trie source)
    }
    private var currentCandidates: [DisplayedCandidate] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        loadEngines()
        view.addSubview(candidateBar)
        NSLayoutConstraint.activate([
            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            candidateBar.topAnchor.constraint(equalTo: view.topAnchor),
            candidateBar.heightAnchor.constraint(equalToConstant: 40)
        ])
        candidateBar.onSelect = { [weak self] cand in
            self?.selectCandidate(cand)
        }
        rebuildKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settings = .shared()
        keyboardView?.updateSimpTradToggle(showing: settings.outputMode == .simplified ? "简" : "繁")
    }

    private func loadEngines() {
        do {
            inputEngine = try InputEngine.loadFromBundle()
            convertEngine = try ConvertEngine.loadFromBundle()
            if let url = AppGroup.learningDBURL() {
                learningStore = try? LearningStore(path: url.path)
            }
        } catch {
            NSLog("[SimpTradKeyboard] engine load failed: \(error)")
        }
    }

    private func rebuildKeyboard() {
        keyboardView?.removeFromSuperview()
        let rows: [KeyRow] = (layoutMode == .chinese) ? KeyLayouts.chineseRows : KeyLayouts.symbolRows
        let view = KeyboardView(rows: rows)
        view.onKeyTap = { [weak self] in self?.handleKey($0) }
        view.onDeleteRepeat = { [weak self] in self?.handleKey(.delete) }
        self.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            view.topAnchor.constraint(equalTo: candidateBar.bottomAnchor),
            view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        keyboardView = view
        view.updateSimpTradToggle(showing: settings.outputMode == .simplified ? "简" : "繁")
    }

    private func handleKey(_ key: KeyKind) {
        switch key {
        case .code(let k, _):
            composingBuffer += k
            refreshCandidates()
        case .symbol(let s):
            commitFirstCandidate()
            textDocumentProxy.insertText(s)
        case .delete:
            if !composingBuffer.isEmpty {
                composingBuffer.removeLast()
                refreshCandidates()
            } else {
                textDocumentProxy.deleteBackward()
            }
        case .space:
            if !composingBuffer.isEmpty {
                commitFirstCandidate()
            } else {
                textDocumentProxy.insertText(" ")
            }
        case .return:
            commitFirstCandidate()
            textDocumentProxy.insertText("\n")
        case .toggleSymbols:
            layoutMode = .symbols
            rebuildKeyboard()
        case .toggleChinese:
            layoutMode = .chinese
            rebuildKeyboard()
        case .toggleSimpTrad:
            settings.outputMode = (settings.outputMode == .simplified) ? .traditional : .simplified
            keyboardView?.updateSimpTradToggle(showing: settings.outputMode == .simplified ? "简" : "繁")
            refreshCandidates()
        case .globe:
            advanceToNextInputMode()
        case .emoji, .moreSymbols:
            break
        }
    }

    private func refreshCandidates() {
        guard !composingBuffer.isEmpty else {
            currentCandidates = []
            candidateBar.clear()
            return
        }
        guard let engine = inputEngine, let converter = convertEngine else { return }
        var raw = engine.lookup(code: composingBuffer, mode: settings.imeMode)

        // Re-rank with learning
        if let store = learningStore {
            raw.sort { lhs, rhs in
                let lb = store.frequencyBoost(code: composingBuffer, candidate: lhs.text)
                let rb = store.frequencyBoost(code: composingBuffer, candidate: rhs.text)
                if lb != rb { return lb > rb }
                return lhs.frequency > rhs.frequency
            }
        }

        let mode = settings.outputMode
        currentCandidates = raw.map {
            DisplayedCandidate(display: converter.convert($0.text, to: mode), original: $0)
        }
        candidateBar.show(currentCandidates.map {
            Candidate(text: $0.display, frequency: $0.original.frequency, source: $0.original.source)
        })
    }

    private func selectCandidate(_ displayed: Candidate) {
        // Candidate passed to the bar carries the `display` text; we find matching DisplayedCandidate
        guard let dc = currentCandidates.first(where: { $0.display == displayed.text }) else { return }
        textDocumentProxy.insertText(dc.display)
        learningStore?.recordSelection(code: composingBuffer, candidate: dc.original.text)
        composingBuffer = ""
        candidateBar.clear()
        currentCandidates = []
    }

    private func commitFirstCandidate() {
        guard let first = currentCandidates.first else {
            composingBuffer = ""
            candidateBar.clear()
            return
        }
        textDocumentProxy.insertText(first.display)
        learningStore?.recordSelection(code: composingBuffer, candidate: first.original.text)
        composingBuffer = ""
        candidateBar.clear()
        currentCandidates = []
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimpTradKeyboardExtension/KeyboardViewController.swift
git commit -m "feat(ext): wire candidate lookup, conversion, learning into typing flow"
```

---

### Task 6.3: End-to-end integration test (KeyboardCore level)

**Files:**
- Create: `KeyboardCore/Tests/KeyboardCoreTests/EndToEndTests.swift`

- [ ] **Step 1: Write test**

Write `EndToEndTests.swift`:

```swift
import XCTest
@testable import KeyboardCore

final class EndToEndTests: XCTestCase {
    func test_typeSelectLearn_nextTimeCandidateRanksFirst() throws {
        let input = try InputEngine.loadFromBundle()
        let store = try LearningStore(path: ":memory:")

        // First lookup
        var cands = input.lookup(code: "a", mode: .quick)
        XCTAssertTrue(cands.count >= 2)

        // User selects a non-first candidate
        let selected = cands[1]
        store.recordSelection(code: "a", candidate: selected.text)
        store.recordSelection(code: "a", candidate: selected.text)
        store.recordSelection(code: "a", candidate: selected.text)

        // Next lookup, apply learning boost
        cands = input.lookup(code: "a", mode: .quick)
        cands.sort { lhs, rhs in
            let lb = store.frequencyBoost(code: "a", candidate: lhs.text)
            let rb = store.frequencyBoost(code: "a", candidate: rhs.text)
            if lb != rb { return lb > rb }
            return lhs.frequency > rhs.frequency
        }
        XCTAssertEqual(cands.first?.text, selected.text)
    }

    func test_typeCangjieCodeThenConvertToSimplified() throws {
        let input = try InputEngine.loadFromBundle()
        let conv = try ConvertEngine.loadFromBundle()

        // Cangjie code for 髮 is "shu" (long-hair) — verify candidate includes 髮
        let cands = input.lookup(code: "shu", mode: .cangjie)
        XCTAssertTrue(cands.contains { $0.text == "髮" }, "expected 髮 among cangjie 'shu' lookups")

        let simplified = conv.convert("髮", to: .simplified)
        XCTAssertEqual(simplified, "发")
    }
}
```

Note: The Cangjie code for `髮` may vary (traditionally it's `shu` = 尸竹水). If the assertion fails, adjust the code to match the actual rime-cangjie5 table; `xcodebuild` output will show which candidates actually returned.

- [ ] **Step 2: Run test**

Run: `cd KeyboardCore && swift test --filter EndToEndTests`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add KeyboardCore/
git commit -m "test(core): end-to-end typing+learning+conversion"
```

---

## Part 7: Main app — Settings and onboarding

### Task 7.1: `SettingsView`

**Files:**
- Create: `SimpTradKeyboard/Views/SettingsView.swift`
- Modify: `SimpTradKeyboard/SimpTradKeyboardApp.swift`

- [ ] **Step 1: Write `SettingsView`**

Write `SimpTradKeyboard/Views/SettingsView.swift`:

```swift
import SwiftUI
import KeyboardCore

struct SettingsView: View {
    @State private var outputMode: OutputMode = .traditional
    @State private var imeMode: IMEMode = .quick
    private let settings = Settings.shared()

    var body: some View {
        Form {
            Section("輸出") {
                Picker("語言", selection: $outputMode) {
                    Text("繁體").tag(OutputMode.traditional)
                    Text("简体").tag(OutputMode.simplified)
                }
                .pickerStyle(.segmented)
                .onChange(of: outputMode) { _, newValue in
                    settings.outputMode = newValue
                }
            }
            Section("輸入法") {
                Picker("輸入方式", selection: $imeMode) {
                    Text("速成").tag(IMEMode.quick)
                    Text("倉頡").tag(IMEMode.cangjie)
                }
                .pickerStyle(.segmented)
                .onChange(of: imeMode) { _, newValue in
                    settings.imeMode = newValue
                }
            }
            Section {
                NavigationLink("啟用鍵盤教學") { OnboardingView() }
                NavigationLink("學習資料") { LearningDataView() }
            }
        }
        .navigationTitle("SimpTradKeyboard")
        .onAppear {
            outputMode = settings.outputMode
            imeMode = settings.imeMode
        }
    }
}

#Preview { NavigationStack { SettingsView() } }
```

- [ ] **Step 2: Wire app entry**

Modify `SimpTradKeyboardApp.swift`:

```swift
import SwiftUI

@main
struct SimpTradKeyboardApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack { SettingsView() }
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add SimpTradKeyboard/
git commit -m "feat(app): settings view with simp/trad and IME toggles"
```

---

### Task 7.2: `OnboardingView`

**Files:**
- Create: `SimpTradKeyboard/Views/OnboardingView.swift`

- [ ] **Step 1: Write view**

```swift
import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("啟用 SimpTradKeyboard").font(.title2).bold()
                StepView(number: 1, text: "打開 iOS「設定」")
                StepView(number: 2, text: "揀「一般」→「鍵盤」→「鍵盤」")
                StepView(number: 3, text: "㩒「加入新鍵盤」")
                StepView(number: 4, text: "揀 SimpTradKeyboard")
                Text("打字嗰陣長㩒🌐切到新鍵盤。")
                    .foregroundStyle(.secondary)
                Button("打開系統設定") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("啟用鍵盤")
    }
}

private struct StepView: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.headline).frame(width: 28, height: 28)
                .background(Circle().fill(.tint.opacity(0.2)))
            Text(text)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimpTradKeyboard/Views/OnboardingView.swift
git commit -m "feat(app): onboarding view"
```

---

### Task 7.3: `LearningDataView`

**Files:**
- Create: `SimpTradKeyboard/Views/LearningDataView.swift`

- [ ] **Step 1: Write view**

```swift
import SwiftUI
import KeyboardCore

struct LearningDataView: View {
    @State private var entries: [LearningStore.Entry] = []
    @State private var store: LearningStore?

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    store?.reset()
                    reload()
                } label: {
                    Text("重設學習資料")
                }
            }
            Section("已學詞彙") {
                if entries.isEmpty {
                    Text("（未有資料）").foregroundStyle(.secondary)
                } else {
                    ForEach(entries, id: \.code) { e in
                        HStack {
                            Text(e.candidate).font(.title3)
                            Spacer()
                            Text(e.code).font(.caption).foregroundStyle(.secondary)
                            Text("×\(e.count)").monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("學習資料")
        .onAppear {
            if store == nil, let url = AppGroup.learningDBURL() {
                store = try? LearningStore(path: url.path)
            }
            reload()
        }
    }

    private func reload() {
        entries = store?.allEntries() ?? []
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimpTradKeyboard/Views/LearningDataView.swift
git commit -m "feat(app): learning data view with reset"
```

---

## Part 8: Performance + memory sanity

### Task 8.1: Performance benchmark tests

**Files:**
- Create: `KeyboardCore/Tests/KeyboardCoreTests/PerformanceTests.swift`

- [ ] **Step 1: Write benchmark**

```swift
import XCTest
@testable import KeyboardCore

final class PerformanceTests: XCTestCase {
    func test_perf_trieLookup() throws {
        let engine = try InputEngine.loadFromBundle()
        measure {
            for _ in 0..<1000 {
                _ = engine.lookup(code: "a", mode: .quick)
            }
        }
    }

    func test_perf_convertTenChars() throws {
        let conv = try ConvertEngine.loadFromBundle()
        let text = String(repeating: "我發現了頭髮飛舞", count: 1)
        measure {
            for _ in 0..<100 {
                _ = conv.convert(text, to: .simplified)
            }
        }
    }
}
```

- [ ] **Step 2: Run**

Run: `cd KeyboardCore && swift test --filter PerformanceTests`

Expected: PASS. Inspect output for average times — should be well under the targets (< 5ms per lookup, < 10ms per 10-char convert).

- [ ] **Step 3: Commit**

```bash
git add KeyboardCore/
git commit -m "test(core): performance benchmarks for lookup and convert"
```

---

## Part 9: CI

### Task 9.1: GitHub Actions workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write workflow**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  keyboard-core:
    name: KeyboardCore swift test
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Regenerate trie + opencc data
        run: |
          mkdir -p tools/data tools/data/opencc
          curl -L -o tools/data/cangjie5.dict.yaml https://raw.githubusercontent.com/rime/rime-cangjie/master/cangjie5.dict.yaml
          curl -L -o tools/data/quick5.dict.yaml https://raw.githubusercontent.com/rime/rime-quick/master/quick5.dict.yaml
          curl -L -o tools/data/opencc/TSPhrases.txt https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/TSPhrases.txt
          curl -L -o tools/data/opencc/TSCharacters.txt https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/TSCharacters.txt
          cd tools/build-trie
          swift build
          swift run build-trie trie ../data/cangjie5.dict.yaml ../../KeyboardCore/Sources/KeyboardCore/Resources/cangjie5.trie
          swift run build-trie trie ../data/quick5.dict.yaml ../../KeyboardCore/Sources/KeyboardCore/Resources/quick5.trie
          swift run build-trie opencc ../data/opencc/TSPhrases.txt ../../KeyboardCore/Sources/KeyboardCore/Resources/opencc/t2s_phrases.json
          swift run build-trie opencc ../data/opencc/TSCharacters.txt ../../KeyboardCore/Sources/KeyboardCore/Resources/opencc/t2s_chars.json
      - name: Test
        run: cd KeyboardCore && swift test

  xcode-build:
    name: Xcode build app + extension
    runs-on: macos-14
    needs: keyboard-core
    steps:
      - uses: actions/checkout@v4
      - name: Regenerate data (same as keyboard-core)
        run: |
          mkdir -p tools/data tools/data/opencc
          curl -L -o tools/data/cangjie5.dict.yaml https://raw.githubusercontent.com/rime/rime-cangjie/master/cangjie5.dict.yaml
          curl -L -o tools/data/quick5.dict.yaml https://raw.githubusercontent.com/rime/rime-quick/master/quick5.dict.yaml
          curl -L -o tools/data/opencc/TSPhrases.txt https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/TSPhrases.txt
          curl -L -o tools/data/opencc/TSCharacters.txt https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/TSCharacters.txt
          cd tools/build-trie
          swift build
          swift run build-trie trie ../data/cangjie5.dict.yaml ../../KeyboardCore/Sources/KeyboardCore/Resources/cangjie5.trie
          swift run build-trie trie ../data/quick5.dict.yaml ../../KeyboardCore/Sources/KeyboardCore/Resources/quick5.trie
          swift run build-trie opencc ../data/opencc/TSPhrases.txt ../../KeyboardCore/Sources/KeyboardCore/Resources/opencc/t2s_phrases.json
          swift run build-trie opencc ../data/opencc/TSCharacters.txt ../../KeyboardCore/Sources/KeyboardCore/Resources/opencc/t2s_chars.json
      - name: Build
        run: xcodebuild -project SimpTradKeyboard.xcodeproj -scheme SimpTradKeyboard -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation build
```

Note: CI requires a valid signing/team to build the app target for device, but "generic/platform=iOS Simulator" typically does not require signing. If build fails on signing, add `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` to the xcodebuild call.

- [ ] **Step 2: Commit**

```bash
mkdir -p .github/workflows
# (then write file)
git add .github/
git commit -m "ci: swift test + xcodebuild on macos-14"
```

---

## Part 10: Manual verification

### Task 10.1: Simulator manual test run

**Files:** none; documentation only.

- [ ] **Step 1: Run on iOS simulator**

- Launch `SimpTradKeyboard` on iPhone 15 simulator.
- Simulator → Settings → General → Keyboard → Keyboards → Add New Keyboard → SimpTradKeyboard.
- Open Notes in simulator → tap text field → hold 🌐 → select SimpTradKeyboard.

- [ ] **Step 2: Test typing**

- Type `a` → candidate bar shows 「日, 曰, …」.
- Tap 「日」→ inserted into Notes.
- Tap simp/trad toggle → label flips 繁↔简.
- Type `hqm` (Cangjie for 「拜」, if IME mode = .cangjie via settings app) → expect 「拜」 / `拜`.
- Type multi-char string that has phrase conversion (e.g., 頭 → select 「頭」, then 髮 → select 「髮」; candidate bar would not show phrase conversion for separate commits — phrase conversion is scoped to a single candidate lookup. For phrase conversion to trigger visibly, an `outputMode=simplified` single-code lookup whose candidate text is a pre-converted phrase would only arise in V2 phrase-level input; V1 converts each candidate char).

Note: In V1, since trie returns single characters, the ConvertEngine phrase path is only exercised for any multi-char candidates in the trie itself (rare). The phrase engine is still essential for V2 expansion and for any multi-char trie entries. Document in spec if not already.

- [ ] **Step 3: Test delete long-press, space, symbol layout, return**

- Delete long-press: buffer clears, then deletes prior text.
- Tap 123 → symbol layout appears.
- Tap 「，」 → 「，」 inserted.
- Tap 速成 from symbol layout → back to Chinese layout.
- Tap return in text field → newline inserted.

- [ ] **Step 4: Settings roundtrip**

- In main app, toggle simp/trad.
- Kill app.
- Reopen Notes → 喺鍵盤度打字 → candidates reflect new mode.

- [ ] **Step 5: Reset learning data**

- Type & select a few chars.
- Main app → Learning Data → shows entries.
- Tap reset → entries cleared → next lookup no longer boosts.

- [ ] **Step 6: Record pass / any issues**

If all pass, commit a test-run note:

```bash
# Append a note in docs/ if desired, or skip.
```

---

## Self-Review (author's pass before execution)

Already performed. Key items verified:

- **Spec coverage:**
  - Cangjie + Quick input → Tasks 1.4, 1.5 ✓
  - T→S phrase conversion → Tasks 2.1–2.3 ✓
  - Global simp/trad toggle → Task 6.2 ✓
  - Learning → Tasks 3.1, 6.2 ✓
  - Symbol/number layout → Task 5.2 ✓
  - Long-press delete → Task 5.3 ✓
  - Space swipe cursor → **NOT COVERED in V1 tasks** (see below)
  - Main app settings, onboarding, learning data → Tasks 7.1–7.3 ✓
  - App Group, no Full Access → Task 0.3, 4.1 ✓
  - Performance benchmarks → Task 8.1 ✓
  - CI → Task 9.1 ✓
  - Manual checklist → Task 10.1 ✓

- **Gap:** Space-swipe cursor movement (PanGesture on space key) was in the spec as item (d) but is not wired in tasks above. Add a follow-up task:

### Task 11.1 (follow-up): Space-bar swipe moves cursor

**Files:**
- Modify: `SimpTradKeyboardExtension/Views/KeyButton.swift`
- Modify: `SimpTradKeyboardExtension/Views/KeyboardView.swift`
- Modify: `SimpTradKeyboardExtension/KeyboardViewController.swift`

- [ ] **Step 1: Add pan gesture on space-kind KeyButton**

In `KeyButton.configure()`, after the long-press block, add:

```swift
        if case .space = kind {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            addGestureRecognizer(pan)
        }
```

Add property and handler to `KeyButton`:

```swift
    var onPanDelta: ((Int) -> Void)?
    private var panLastX: CGFloat = 0

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: self)
        switch g.state {
        case .began:
            panLastX = 0
        case .changed:
            let delta = t.x - panLastX
            let step: CGFloat = 10  // pixels per char
            if abs(delta) >= step {
                let chars = Int(delta / step)
                onPanDelta?(chars)
                panLastX += CGFloat(chars) * step
            }
        default:
            break
        }
    }
```

- [ ] **Step 2: Pipe delta through `KeyboardView`**

Add to `KeyboardView`:

```swift
    var onSpacePan: ((Int) -> Void)?
```

In its key loop, after assigning `onTap`:

```swift
            if case .space = key {
                btn.onPanDelta = { [weak self] delta in self?.onSpacePan?(delta) }
            }
```

- [ ] **Step 3: Handle in controller**

In `KeyboardViewController.rebuildKeyboard()`, after `view.onDeleteRepeat = ...`:

```swift
        view.onSpacePan = { [weak self] delta in
            guard let self else { return }
            if delta > 0 {
                for _ in 0..<delta { self.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1) }
            } else if delta < 0 {
                for _ in 0..<(-delta) { self.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1) }
            }
        }
```

- [ ] **Step 4: Build**

Run: `xcodebuild build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add SimpTradKeyboardExtension/
git commit -m "feat(ext): space-bar swipe moves cursor"
```

---

## Conventions reminder for implementers

- **TDD strictly:** Every `KeyboardCore` task has tests first, failing, then implementation.
- **One commit per task** (or per logical sub-step for bigger tasks). Frequent commits.
- **Do not combine tasks**: each one above is sized for 5–30 min of focused work.
- **Do not speculate beyond the task**: no pre-emptive refactors, no V2 features bleeding into V1.
- **When trie-loading tests fail** because actual data differs from expected chars (e.g. rime tables updated), fix the test expectation against what the actual rime source contains, not the other way around.
