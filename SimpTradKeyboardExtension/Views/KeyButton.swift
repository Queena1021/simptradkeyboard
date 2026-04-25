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

        if case .space = kind {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            addGestureRecognizer(pan)
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

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }
}
