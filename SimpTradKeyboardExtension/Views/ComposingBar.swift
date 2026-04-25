import UIKit

/// Thin label that shows the in-progress composition (e.g. "人火") with an
/// underline, mimicking the native iOS marked-text indicator that
/// third-party keyboard extensions cannot access.
final class ComposingBar: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 22)
        label.textColor = .label
        label.textAlignment = .left
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ text: String) {
        if text.isEmpty {
            label.attributedText = nil
            isHidden = true
            return
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.systemYellow,
            .font: UIFont.systemFont(ofSize: 22),
            .foregroundColor: UIColor.label
        ]
        label.attributedText = NSAttributedString(string: text, attributes: attrs)
        isHidden = false
    }

    func clear() { show("") }
}
