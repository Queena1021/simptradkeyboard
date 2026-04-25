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
        // Naive: clear buffer (Task 6 refines this)
        composingBuffer = ""
    }
}
