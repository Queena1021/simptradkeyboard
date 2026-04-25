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
        // TODO (Task 5.5): build keyboard UI
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settings = .shared() // re-read after main app may have changed
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
}
