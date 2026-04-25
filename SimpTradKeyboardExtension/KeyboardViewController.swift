import UIKit
import CoreText
import KeyboardCore

/// True if the system font has a glyph for every scalar in `text`. Drops candidates
/// rendered as ☐ (CJK extension chars not in the iOS system font).
private func systemCanRender(_ text: String) -> Bool {
    let font = CTFontCreateWithName("PingFangTC-Regular" as CFString, 22, nil)
    let scalars = Array(text.unicodeScalars)
    var utf16: [UniChar] = []
    for s in scalars {
        if s.value > 0xFFFF {
            // Surrogate pair
            let v = s.value - 0x10000
            utf16.append(UniChar(0xD800 + (v >> 10)))
            utf16.append(UniChar(0xDC00 + (v & 0x3FF)))
        } else {
            utf16.append(UniChar(s.value))
        }
    }
    var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
    let ok = CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count)
    if !ok { return false }
    return glyphs.allSatisfy { $0 != 0 }
}

final class KeyboardViewController: UIInputViewController {
    private var inputEngine: InputEngine?
    private var convertEngine: ConvertEngine?
    private var learningStore: LearningStore?
    private var predictor: NextCharPredictor?
    private var settings: Settings = .shared()
    private var lastCommittedChar: String = ""    // for showing predictions after commit

    private var composingBuffer: String = ""        // raw codes typed (e.g. "of")
    private var composingDisplay: String = ""       // radical labels for preview (e.g. "人火")
    private enum LayoutMode { case chinese, symbols, moreSymbols }
    private var layoutMode: LayoutMode = .chinese
    private var keyboardView: KeyboardView?
    private let candidateBar = CandidateBar()
    private let candidateGrid = CandidateGridView()
    private var isExpanded = false

    private struct DisplayedCandidate {
        let display: String        // maybe simplified
        let original: Candidate    // traditional (trie source)
    }
    private var currentCandidates: [DisplayedCandidate] = []
    private var currentPredictions: [String] = []
    private enum BarMode { case candidates, predictions, empty }
    private var barMode: BarMode = .empty

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
            guard let self else { return }
            switch self.barMode {
            case .candidates: self.selectCandidate(cand)
            case .predictions: self.selectPrediction(cand.text)
            case .empty: break
            }
        }
        candidateBar.onToggleExpand = { [weak self] in
            self?.toggleExpanded()
        }
        candidateGrid.onSelect = { [weak self] cand in
            guard let self else { return }
            switch self.barMode {
            case .candidates: self.selectCandidate(cand)
            case .predictions: self.selectPrediction(cand.text)
            case .empty: break
            }
        }
        candidateGrid.isHidden = true
        rebuildKeyboard()
    }

    private func toggleExpanded() {
        isExpanded.toggle()
        candidateBar.setExpanded(isExpanded)
        candidateGrid.isHidden = !isExpanded
        keyboardView?.isHidden = isExpanded
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
            predictor = try? NextCharPredictor.loadFromBundle()
            if let url = AppGroup.learningDBURL() {
                learningStore = try? LearningStore(path: url.path)
            }
        } catch {
            NSLog("[SimpTradKeyboard] engine load failed: \(error)")
        }
    }

    private func rebuildKeyboard() {
        keyboardView?.removeFromSuperview()
        let rows: [KeyRow]
        switch layoutMode {
        case .chinese: rows = KeyLayouts.chineseRows
        case .symbols: rows = KeyLayouts.symbolRows
        case .moreSymbols: rows = KeyLayouts.moreSymbolRows
        }
        let view = KeyboardView(rows: rows)
        view.onKeyTap = { [weak self] in self?.handleKey($0) }
        view.onDeleteRepeat = { [weak self] in self?.handleKey(.delete) }
        view.onSpacePan = { [weak self] delta in
            guard let self else { return }
            if delta > 0 {
                for _ in 0..<delta { self.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1) }
            } else if delta < 0 {
                for _ in 0..<(-delta) { self.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1) }
            }
        }
        self.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            view.topAnchor.constraint(equalTo: candidateBar.bottomAnchor),
            view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        keyboardView = view
        view.updateSimpTradToggle(showing: settings.outputMode == .simplified ? "简" : "繁")

        // Mount the candidate grid above the keyboard view, occupying the same area.
        if candidateGrid.superview == nil {
            self.view.addSubview(candidateGrid)
            NSLayoutConstraint.activate([
                candidateGrid.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                candidateGrid.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                candidateGrid.topAnchor.constraint(equalTo: candidateBar.bottomAnchor),
                candidateGrid.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
        } else {
            self.view.bringSubviewToFront(candidateGrid)
        }
        candidateGrid.isHidden = !isExpanded
        view.isHidden = isExpanded
    }

    private var maxBufferLength: Int {
        settings.imeMode == .quick ? 2 : 5
    }

    private func handleKey(_ key: KeyKind) {
        switch key {
        case .code(let k, let label):
            // If buffer already at max for this IME mode, auto-commit first
            // candidate before starting a new buffer with this keystroke.
            if composingBuffer.count >= maxBufferLength {
                commitFirstCandidate()
            }
            composingBuffer += k
            composingDisplay += label
            refreshCandidates()
        case .symbol(let s):
            commitFirstCandidate()
            textDocumentProxy.insertText(s)
        case .delete:
            if !composingBuffer.isEmpty {
                composingBuffer.removeLast()
                composingDisplay.removeLast()
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
            if !composingBuffer.isEmpty {
                commitFirstCandidate()
            } else {
                textDocumentProxy.insertText("\n")
            }
        case .toggleSymbols:
            commitFirstCandidate()
            // From #+= layer, "123" goes back to numbers; otherwise enter numbers.
            layoutMode = (layoutMode == .moreSymbols) ? .symbols : .symbols
            rebuildKeyboard()
        case .toggleMoreSymbols:
            commitFirstCandidate()
            layoutMode = .moreSymbols
            rebuildKeyboard()
        case .toggleChinese:
            commitFirstCandidate()
            layoutMode = .chinese
            rebuildKeyboard()
        case .toggleSimpTrad:
            settings.outputMode = (settings.outputMode == .simplified) ? .traditional : .simplified
            keyboardView?.updateSimpTradToggle(showing: settings.outputMode == .simplified ? "简" : "繁")
            refreshCandidates()
        case .globe, .emoji:
            commitFirstCandidate()
            advanceToNextInputMode()
        }
    }

    private func refreshCandidates() {
        guard !composingBuffer.isEmpty else {
            currentCandidates = []
            candidateBar.clear()
            candidateGrid.show([])
            collapseGridIfNeeded()
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
        var seenDisplay = Set<String>()
        currentCandidates = raw
            .filter { systemCanRender($0.text) }
            .compactMap { c -> DisplayedCandidate? in
                let display = converter.convert(c.text, to: mode)
                guard seenDisplay.insert(display).inserted else { return nil }
                return DisplayedCandidate(display: display, original: c)
            }
        let displayed = currentCandidates.map {
            Candidate(text: $0.display, frequency: $0.original.frequency, source: $0.original.source)
        }
        candidateBar.show(displayed, composing: composingDisplay)
        candidateGrid.show(displayed)
        barMode = displayed.isEmpty ? .empty : .candidates
    }

    private func showPredictions(after committed: String) {
        guard let predictor = predictor, !committed.isEmpty else {
            candidateBar.clear()
            candidateGrid.show([])
            barMode = .empty
            return
        }
        // Predictor table is keyed on Simplified chars. Normalize the prefix to
        // Simplified before lookup so traditional input (e.g. "頭") still finds
        // the simplified entry ("头").
        let rawPrefix = String(committed.suffix(1))
        let normalized = convertEngine?.convert(rawPrefix, to: .simplified) ?? rawPrefix
        let mode = settings.outputMode
        let suggestions = predictor.suggestions(after: normalized)
            .map { convertEngine?.convert($0, to: mode) ?? $0 }
            .filter { systemCanRender($0) }
        let cands = suggestions.map { Candidate(text: $0, frequency: 0, source: .builtin) }
        candidateBar.show(cands)
        candidateGrid.show(cands)
        barMode = cands.isEmpty ? .empty : .predictions
        currentPredictions = suggestions
    }

    private func selectPrediction(_ char: String) {
        textDocumentProxy.insertText(char)
        lastCommittedChar = char
        showPredictions(after: char)
        collapseGridIfNeeded()
    }

    private func collapseGridIfNeeded() {
        guard isExpanded else { return }
        isExpanded = false
        candidateBar.setExpanded(false)
        candidateGrid.isHidden = true
        keyboardView?.isHidden = false
    }

    private func selectCandidate(_ displayed: Candidate) {
        // Candidate passed to the bar carries the `display` text; we find matching DisplayedCandidate
        guard let dc = currentCandidates.first(where: { $0.display == displayed.text }) else { return }
        textDocumentProxy.insertText(dc.display)
        learningStore?.recordSelection(code: composingBuffer, candidate: dc.original.text)
        composingBuffer = ""
        composingDisplay = ""
        currentCandidates = []
        lastCommittedChar = dc.display
        showPredictions(after: dc.display)
        collapseGridIfNeeded()
    }

    private func commitFirstCandidate() {
        guard let first = currentCandidates.first else {
            composingBuffer = ""
            composingDisplay = ""
            candidateBar.clear()
            barMode = .empty
            collapseGridIfNeeded()
            return
        }
        textDocumentProxy.insertText(first.display)
        learningStore?.recordSelection(code: composingBuffer, candidate: first.original.text)
        composingBuffer = ""
        composingDisplay = ""
        currentCandidates = []
        lastCommittedChar = first.display
        showPredictions(after: first.display)
        collapseGridIfNeeded()
    }
}
