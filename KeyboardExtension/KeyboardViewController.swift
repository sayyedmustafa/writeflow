import UIKit

class KeyboardViewController: UIInputViewController {

    // MARK: - Constants
    private let appGroupIdentifier = "group.com.sayyedmustafa.writeflow"
    private let defaultApiKey = String(decoding: Data(base64Encoded: "QVEuQWI4Uk42SmNMSGRIUjROc2cxbjQyOUxjUmRaUzMtcENZRVQ3clJVdERXTW92WkpaQVE=") ?? Data(), as: UTF8.self)
    private let geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent"

    // MARK: - UI Components
    private var suggestionsBar: UIView!
    private var suggestionsScrollView: UIScrollView!
    private var suggestionsStackView: UIStackView!
    private var statusIndicator: UIView!
    private var keyboardView: UIView!

    // MARK: - State
    private var isShifted = false
    private var isSymbolMode = false
    private var analysisTimer: Timer?
    private var activeSuggestions: [(original: String, replacement: String, explanation: String)] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkCurrentContext()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        debounceAnalysis()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)

        // 1. Top Suggestions Bar (Grammarly-style)
        suggestionsBar = UIView()
        suggestionsBar.translatesAutoresizingMaskIntoConstraints = false
        suggestionsBar.backgroundColor = UIColor(red: 0.06, green: 0.08, blue: 0.11, alpha: 1.0)
        view.addSubview(suggestionsBar)

        statusIndicator = UIView()
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.layer.cornerRadius = 4
        statusIndicator.backgroundColor = UIColor.systemGreen
        suggestionsBar.addSubview(statusIndicator)

        suggestionsScrollView = UIScrollView()
        suggestionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsScrollView.showsHorizontalScrollIndicator = false
        suggestionsBar.addSubview(suggestionsScrollView)

        suggestionsStackView = UIStackView()
        suggestionsStackView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsStackView.axis = .horizontal
        suggestionsStackView.spacing = 8
        suggestionsStackView.alignment = .center
        suggestionsScrollView.addSubview(suggestionsStackView)

        // 2. Main Keypad Container
        keyboardView = UIView()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        // AutoLayout
        NSLayoutConstraint.activate([
            suggestionsBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionsBar.heightAnchor.constraint(equalToConstant: 44),

            statusIndicator.leadingAnchor.constraint(equalTo: suggestionsBar.leadingAnchor, constant: 12),
            statusIndicator.centerYAnchor.constraint(equalTo: suggestionsBar.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),

            suggestionsScrollView.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 10),
            suggestionsScrollView.trailingAnchor.constraint(equalTo: suggestionsBar.trailingAnchor, constant: -12),
            suggestionsScrollView.topAnchor.constraint(equalTo: suggestionsBar.topAnchor),
            suggestionsScrollView.bottomAnchor.constraint(equalTo: suggestionsBar.bottomAnchor),

            suggestionsStackView.leadingAnchor.constraint(equalTo: suggestionsScrollView.leadingAnchor),
            suggestionsStackView.trailingAnchor.constraint(equalTo: suggestionsScrollView.trailingAnchor),
            suggestionsStackView.topAnchor.constraint(equalTo: suggestionsScrollView.topAnchor),
            suggestionsStackView.bottomAnchor.constraint(equalTo: suggestionsScrollView.bottomAnchor),
            suggestionsStackView.heightAnchor.constraint(equalTo: suggestionsScrollView.heightAnchor),

            keyboardView.topAnchor.constraint(equalTo: suggestionsBar.bottomAnchor, constant: 6),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            keyboardView.heightAnchor.constraint(equalToConstant: 216)
        ])

        buildKeys()
        showDefaultAssistantPrompt()
    }

    private func showDefaultAssistantPrompt() {
        clearSuggestions()
        let label = UILabel()
        label.text = "✨ WriteFlow AI: Type to analyze grammar & tone"
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1.0)
        suggestionsStackView.addArrangedSubview(label)
    }

    private func clearSuggestions() {
        for subview in suggestionsStackView.arrangedSubviews {
            suggestionsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }

    // MARK: - Keypad Generation
    private func buildKeys() {
        for subview in keyboardView.subviews {
            subview.removeFromSuperview()
        }

        let row1Keys = isSymbolMode ? ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"] :
            (isShifted ? ["Q","W","E","R","T","Y","U","I","O","P"] : ["q","w","e","r","t","y","u","i","o","p"])
        let row2Keys = isSymbolMode ? ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""] :
            (isShifted ? ["A","S","D","F","G","H","J","K","L"] : ["a","s","d","f","g","h","j","k","l"])
        let row3Letters = isSymbolMode ? [".", ",", "?", "!", "'"] :
            (isShifted ? ["Z","X","C","V","B","N","M"] : ["z","x","c","v","b","n","m"])

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 7
        keyboardView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -4)
        ])

        // Row 1
        stack.addArrangedSubview(createRow(keys: row1Keys))

        // Row 2
        let row2 = createRow(keys: row2Keys)
        stack.addArrangedSubview(row2)

        // Row 3 (Shift, Letters, Backspace)
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.distribution = .fillProportionally
        row3.spacing = 6

        let shiftBtn = createSpecialKey(title: isShifted ? "⬆︎" : "⇧", flex: 1.25)
        shiftBtn.addTarget(self, action: #selector(toggleShift), for: .touchUpInside)
        row3.addArrangedSubview(shiftBtn)

        let row3LetterStack = createRow(keys: row3Letters)
        row3.addArrangedSubview(row3LetterStack)

        let deleteBtn = createSpecialKey(title: "⌫", flex: 1.25)
        deleteBtn.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)
        row3.addArrangedSubview(deleteBtn)
        stack.addArrangedSubview(row3)

        // Row 4 (123, Globe, Space, Return)
        let row4 = UIStackView()
        row4.axis = .horizontal
        row4.distribution = .fillProportionally
        row4.spacing = 6

        let modeBtn = createSpecialKey(title: isSymbolMode ? "ABC" : "123", flex: 1.3)
        modeBtn.addTarget(self, action: #selector(toggleSymbolMode), for: .touchUpInside)
        row4.addArrangedSubview(modeBtn)

        let globeBtn = createSpecialKey(title: "🌐", flex: 1.0)
        globeBtn.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        row4.addArrangedSubview(globeBtn)

        let spaceBtn = createSpecialKey(title: "space", flex: 4.5)
        spaceBtn.backgroundColor = UIColor(red: 0.28, green: 0.32, blue: 0.38, alpha: 1.0)
        spaceBtn.addTarget(self, action: #selector(handleSpace), for: .touchUpInside)
        row4.addArrangedSubview(spaceBtn)

        let returnBtn = createSpecialKey(title: "return", flex: 1.5)
        returnBtn.addTarget(self, action: #selector(handleReturn), for: .touchUpInside)
        row4.addArrangedSubview(returnBtn)

        stack.addArrangedSubview(row4)
    }

    private func createRow(keys: [String]) -> UIStackView {
        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.distribution = .fillEqually
        rowStack.spacing = 5

        for key in keys {
            let btn = UIButton(type: .system)
            btn.setTitle(key, for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 21, weight: .regular)
            btn.backgroundColor = UIColor(red: 0.22, green: 0.25, blue: 0.31, alpha: 1.0)
            btn.layer.cornerRadius = 6
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 1.5)
            btn.layer.shadowOpacity = 0.3
            btn.layer.shadowRadius = 0
            btn.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            rowStack.addArrangedSubview(btn)
        }
        return rowStack
    }

    private func createSpecialKey(title: String, flex: CGFloat) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        btn.backgroundColor = UIColor(red: 0.16, green: 0.18, blue: 0.23, alpha: 1.0)
        btn.layer.cornerRadius = 6
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        btn.layer.shadowOpacity = 0.3
        btn.layer.shadowRadius = 0
        return btn
    }

    // MARK: - Key Actions
    @objc private func keyTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        textDocumentProxy.insertText(title)
        if isShifted {
            isShifted = false
            buildKeys()
        }
    }

    @objc private func handleDelete() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func handleSpace() {
        textDocumentProxy.insertText(" ")
        debounceAnalysis(immediate: true)
    }

    @objc private func handleReturn() {
        textDocumentProxy.insertText("\n")
    }

    @objc private func toggleShift() {
        isShifted.toggle()
        buildKeys()
    }

    @objc private func toggleSymbolMode() {
        isSymbolMode.toggle()
        isShifted = false
        buildKeys()
    }

    // MARK: - Grammar & AI Logic
    private func checkCurrentContext() {
        guard let context = textDocumentProxy.documentContextBeforeInput, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showDefaultAssistantPrompt()
            return
        }
        analyzeText(context)
    }

    private func debounceAnalysis(immediate: Bool = false) {
        analysisTimer?.invalidate()
        if immediate {
            checkCurrentContext()
            return
        }
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.checkCurrentContext()
        }
    }

    private func getApiKey() -> String {
        if let shared = UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: "@writing_assistant_api_key"), !shared.isEmpty {
            return shared
        }
        return defaultApiKey
    }

    private func analyzeText(_ rawText: String) {
        let sentence = rawText.components(separatedBy: CharacterSet(charactersIn: ".?!;\n")).last?.trimmingCharacters(in: .whitespaces) ?? rawText
        guard sentence.count >= 4 else { return }

        statusIndicator.backgroundColor = UIColor.systemOrange

        let apiKey = getApiKey()
        guard let url = URL(string: "\(geminiEndpoint)?key=\(apiKey)") else { return }

        let prompt = """
        You are a real-time keyboard writing assistant.
        Analyze this sentence for grammar, spelling, and conciseness:
        "\(sentence)"

        Return ONLY a JSON array of suggestions:
        [
          {"original": "incorrectWord", "replacement": "correctWord", "explanation": "brief reason"}
        ]
        If no errors, return [].
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.1
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.statusIndicator.backgroundColor = UIColor.systemGray
                }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String,
               let innerData = text.data(using: .utf8),
               let items = try? JSONSerialization.jsonObject(with: innerData) as? [[String: String]] {

                DispatchQueue.main.async {
                    self.displaySuggestions(items)
                }
            } else {
                DispatchQueue.main.async {
                    self.statusIndicator.backgroundColor = UIColor.systemGreen
                }
            }
        }.resume()
    }

    private func displaySuggestions(_ items: [[String: String]]) {
        clearSuggestions()
        statusIndicator.backgroundColor = items.isEmpty ? UIColor.systemGreen : UIColor(red: 0.22, green: 0.65, blue: 0.98, alpha: 1.0)

        if items.isEmpty {
            let label = UILabel()
            label.text = "✓ Clear & correct"
            label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            label.textColor = UIColor.systemGreen
            suggestionsStackView.addArrangedSubview(label)
            return
        }

        for item in items {
            guard let original = item["original"], let replacement = item["replacement"] else { continue }
            let chip = UIButton(type: .system)
            chip.setTitle("\(original) → \(replacement)", for: .normal)
            chip.setTitleColor(.white, for: .normal)
            chip.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            chip.backgroundColor = UIColor(red: 0.15, green: 0.28, blue: 0.45, alpha: 1.0)
            chip.layer.cornerRadius = 14
            chip.layer.borderWidth = 1
            chip.layer.borderColor = UIColor(red: 0.22, green: 0.65, blue: 0.98, alpha: 1.0).cgColor
            chip.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

            chip.addAction(UIAction { [weak self] _ in
                self?.applyCorrection(original: original, replacement: replacement)
            }, for: .touchUpInside)

            suggestionsStackView.addArrangedSubview(chip)
        }
    }

    private func applyCorrection(original: String, replacement: String) {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return }

        if let range = context.range(of: original, options: .backwards) {
            let distance = context.distance(from: range.upperBound, to: context.endIndex)

            // 1. Move back if needed
            if distance > 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: -distance)
            }

            // 2. Delete original word
            for _ in 0..<original.count {
                textDocumentProxy.deleteBackward()
            }

            // 3. Insert corrected word
            textDocumentProxy.insertText(replacement)

            // 4. Restore cursor position
            if distance > 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: distance)
            }

            checkCurrentContext()
        }
    }
}
