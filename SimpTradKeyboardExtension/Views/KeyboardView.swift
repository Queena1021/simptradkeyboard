import UIKit

final class KeyboardView: UIView {
    var onKeyTap: ((KeyKind) -> Void)?
    var onDeleteRepeat: (() -> Void)?
    var onSpacePan: ((Int) -> Void)?

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
            h.distribution = .fill
            // Width weights — give space ~4× a normal key, return ~1.5×.
            var rowButtons: [KeyButton] = []
            for key in row.keys {
                let btn = KeyButton(kind: key)
                btn.onTap = { [weak self] in self?.onKeyTap?(key) }
                if case .delete = key {
                    btn.onLongPressRepeat = { [weak self] in self?.onDeleteRepeat?() }
                }
                if case .space = key {
                    btn.onPanDelta = { [weak self] delta in self?.onSpacePan?(delta) }
                }
                h.addArrangedSubview(btn)
                buttons.append(btn)
                rowButtons.append(btn)
            }
            // Set width-weight constraints relative to the first 1×-weight button in the row.
            if let unitButton = rowButtons.first(where: { weight(for: $0.kind) == 1 }) {
                for btn in rowButtons where btn !== unitButton {
                    let w = weight(for: btn.kind)
                    btn.widthAnchor.constraint(equalTo: unitButton.widthAnchor, multiplier: CGFloat(w)).isActive = true
                }
            }
            vStack.addArrangedSubview(h)
        }
    }

    private func weight(for kind: KeyKind) -> Double {
        switch kind {
        case .space: return 4.0
        case .return: return 1.6
        case .delete, .toggleSymbols, .toggleMoreSymbols, .toggleChinese, .toggleSimpTrad: return 1.4
        default: return 1.0
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
