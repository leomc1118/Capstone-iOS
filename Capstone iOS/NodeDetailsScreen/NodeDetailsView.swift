//
//  BluetoothView.swift
//  Capstone iOS
//
//  Created by Leo Chen on 10/9/25.
//

import UIKit

class NodeDetailsView: UIView {
    let statusLabel = UILabel()
    let logTextView = UITextView()
    let inputField = UITextField()
    let sendButton = UIButton(type: .system)
    private var inputBottomConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        configureSubviews()
        configureConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureSubviews() {
        statusLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        statusLabel.textColor = .label
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        logTextView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        logTextView.isEditable = false
        logTextView.layer.borderColor = UIColor.systemGray4.cgColor
        logTextView.layer.borderWidth = 1
        logTextView.layer.cornerRadius = 8
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logTextView)

        inputField.placeholder = "Type a command"
        inputField.borderStyle = .roundedRect
        inputField.autocorrectionType = .no
        inputField.autocapitalizationType = .none
        inputField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inputField)

        sendButton.setTitle("Send", for: .normal)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sendButton)
    }

    private func configureConstraints() {
        let guide = safeAreaLayoutGuide

        inputBottomConstraint = sendButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            logTextView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            logTextView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            logTextView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            logTextView.bottomAnchor.constraint(equalTo: inputField.topAnchor, constant: -16),

            inputField.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),
            inputField.heightAnchor.constraint(equalToConstant: 44),

            sendButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 80),
            inputBottomConstraint!
        ])
    }

    func updateStatus(_ text: String) {
        statusLabel.text = text
    }

    func appendLog(_ text: String) {
        let prefix = logTextView.text?.isEmpty == false ? "\n" : ""
        logTextView.text = (logTextView.text ?? "") + prefix + text
        let range = NSRange(location: max(logTextView.text.count - 1, 0), length: 1)
        logTextView.scrollRangeToVisible(range)
    }

    func consumeInputText() -> String {
        let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        inputField.text = ""
        return text
    }

    func setKeyboardInset(_ inset: CGFloat) {
        inputBottomConstraint?.constant = -16 - inset
    }
}
