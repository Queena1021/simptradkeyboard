import UIKit
import KeyboardCore

final class CandidateGridView: UIView {
    var onSelect: ((Candidate) -> Void)?

    private let scroll = UIScrollView()
    private let container = UIView()
    private var candidates: [Candidate] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = true
        addSubview(scroll)
        container.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(container)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            container.topAnchor.constraint(equalTo: scroll.topAnchor),
            container.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            container.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])
    }

    func show(_ candidates: [Candidate]) {
        self.candidates = candidates
        container.subviews.forEach { $0.removeFromSuperview() }
        layoutGrid()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if container.bounds.width > 0 && !candidates.isEmpty && container.subviews.isEmpty {
            layoutGrid()
        }
    }

    private func layoutGrid() {
        let availableWidth = bounds.width
        guard availableWidth > 0 else { return }

        let columns: CGFloat = 5
        let spacing: CGFloat = 4
        let cellWidth = (availableWidth - spacing * (columns + 1)) / columns
        let cellHeight: CGFloat = 44

        var currentRow: UIStackView?
        var rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = spacing
        rowsStack.alignment = .leading
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rowsStack)

        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: spacing),
            rowsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -spacing),
            rowsStack.topAnchor.constraint(equalTo: container.topAnchor, constant: spacing),
            rowsStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -spacing)
        ])

        for (idx, c) in candidates.enumerated() {
            if idx % Int(columns) == 0 {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = spacing
                row.distribution = .fillEqually
                rowsStack.addArrangedSubview(row)
                currentRow = row
            }
            let btn = makeButton(for: c, height: cellHeight)
            currentRow?.addArrangedSubview(btn)
        }
        // Pad final row with empty spacers so cells stay equal width
        if let last = currentRow {
            let remainder = candidates.count % Int(columns)
            if remainder != 0 {
                for _ in 0..<(Int(columns) - remainder) {
                    let spacer = UIView()
                    last.addArrangedSubview(spacer)
                }
            }
        }
        // Fixed-height rows
        rowsStack.arrangedSubviews.compactMap { $0 as? UIStackView }.forEach { row in
            row.heightAnchor.constraint(equalToConstant: cellHeight).isActive = true
        }
        _ = cellWidth
    }

    private func makeButton(for c: Candidate, height: CGFloat) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(c.text, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 22)
        btn.setTitleColor(.label, for: .normal)
        btn.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.5)
        btn.layer.cornerRadius = 6
        btn.heightAnchor.constraint(equalToConstant: height).isActive = true
        btn.addAction(UIAction { [weak self] _ in self?.onSelect?(c) }, for: .touchUpInside)
        return btn
    }
}
