import UIKit
import KeyboardCore

final class CandidateGridView: UIView {
    var onSelect: ((Candidate) -> Void)?

    private let scroll = UIScrollView()
    private let rowsStack = UIStackView()
    private var candidates: [Candidate] = []
    private var lastLayoutWidth: CGFloat = 0

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

        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        rowsStack.alignment = .fill
        rowsStack.distribution = .fill
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(rowsStack)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: scroll.topAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            rowsStack.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])
    }

    func show(_ candidates: [Candidate]) {
        self.candidates = candidates
        rebuildIfNeeded(force: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildIfNeeded(force: false)
    }

    private func rebuildIfNeeded(force: Bool) {
        let width = bounds.width
        guard width > 0 else { return }
        if !force && abs(width - lastLayoutWidth) < 0.5 { return }
        lastLayoutWidth = width
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let columns = 7
        let cellHeight: CGFloat = 44
        let separatorColor = UIColor.separator.withAlphaComponent(0.3)

        for chunkStart in stride(from: 0, to: candidates.count, by: columns) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 0
            row.distribution = .fillEqually
            row.alignment = .fill

            let end = min(chunkStart + columns, candidates.count)
            for i in chunkStart..<end {
                row.addArrangedSubview(makeCell(for: candidates[i]))
            }
            // Pad final row with empty spacers so cell widths stay equal
            for _ in end..<(chunkStart + columns) {
                let spacer = UIView()
                spacer.backgroundColor = .clear
                row.addArrangedSubview(spacer)
            }
            row.heightAnchor.constraint(equalToConstant: cellHeight).isActive = true

            // Bottom hairline separator between rows
            let separator = UIView()
            separator.backgroundColor = separatorColor
            separator.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(separator)
            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                separator.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 0.5)
            ])

            rowsStack.addArrangedSubview(row)
        }
    }

    private func makeCell(for c: Candidate) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(c.text, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 22)
        btn.setTitleColor(.label, for: .normal)
        btn.backgroundColor = .clear
        btn.addAction(UIAction { [weak self] _ in self?.onSelect?(c) }, for: .touchUpInside)
        return btn
    }
}
