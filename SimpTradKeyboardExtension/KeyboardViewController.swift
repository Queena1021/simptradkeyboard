import UIKit
import KeyboardCore

final class KeyboardViewController: UIInputViewController {
    private var inputEngine: InputEngine?
    private var convertEngine: ConvertEngine?
    private var learningStore: LearningStore?
    private var settings: Settings = .shared()

    private var composingBuffer: String = ""        // raw codes typed (e.g. "of")
    private var composingDisplay: String = ""       // radical labels shown in document (e.g. "人火")
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
    }

    private func handleKey(_ key: KeyKind) {
        switch key {
        case .code(let k, let label):
            composingBuffer += k
            composingDisplay += label
            textDocumentProxy.insertText(label)
            refreshCandidates()
        case .symbol(let s):
            commitFirstCandidate()
            textDocumentProxy.insertText(s)
        case .delete:
            if !composingBuffer.isEmpty {
                composingBuffer.removeLast()
                composingDisplay.removeLast()
                textDocumentProxy.deleteBackward()
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
            layoutMode = .symbols
            rebuildKeyboard()
        case .toggleChinese:
            commitFirstCandidate()
            layoutMode = .chinese
            rebuildKeyboard()
        case .toggleSimpTrad:
            settings.outputMode = (settings.outputMode == .simplified) ? .traditional : .simplified
            keyboardView?.updateSimpTradToggle(showing: settings.outputMode == .simplified ? "简" : "繁")
            refreshCandidates()
        case .globe:
            commitFirstCandidate()
            advanceToNextInputMode()
        case .emoji, .moreSymbols:
            break
        }
    }

    /// Remove the radical placeholders we inserted into the document during composing.
    private func clearComposingDisplay() {
        for _ in 0..<composingDisplay.count {
            textDocumentProxy.deleteBackward()
        }
        composingDisplay = ""
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
        clearComposingDisplay()
        textDocumentProxy.insertText(dc.display)
        learningStore?.recordSelection(code: composingBuffer, candidate: dc.original.text)
        composingBuffer = ""
        candidateBar.clear()
        currentCandidates = []
    }

    private func commitFirstCandidate() {
        guard let first = currentCandidates.first else {
            clearComposingDisplay()
            composingBuffer = ""
            candidateBar.clear()
            return
        }
        clearComposingDisplay()
        textDocumentProxy.insertText(first.display)
        learningStore?.recordSelection(code: composingBuffer, candidate: first.original.text)
        composingBuffer = ""
        candidateBar.clear()
        currentCandidates = []
    }
}
