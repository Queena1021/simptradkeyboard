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
