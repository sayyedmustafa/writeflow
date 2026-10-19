import UIKit

class KeyboardViewController: UIInputViewController {

    // MARK: - Constants & Config
    private let appGroupIdentifier = "group.com.sayyedmustafa.writeflow"
    private let defaultApiKey = String(decoding: Data(base64Encoded: "QVEuQWI4Uk42SmNMSGRIUjROc2cxbjQyOUxjUmRaUzMtcENZRVQ3clJVdERXTW92WkpaQVE=") ?? Data(), as: UTF8.self)
    private let primaryEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent"
    private let fallbackEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"

    // MARK: - UI Components
    private var suggestionsBar: UIView!
    private var suggestionsScrollView: UIScrollView!
    private var suggestionsStackView: UIStackView!
    private var statusIndicator: UIView!
    private var statusLabel: UILabel!
    private var keyboardView: UIView!

    // MARK: - State
    private var isShifted = false
    private var isSymbolMode = false
    private var analysisTimer: Timer?
    private var lastAnalyzedText = ""
    private var isChecking = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkCurrentContext(immediate: true)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        debounceAnalysis(immediate: false)
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)

        // 1. Top Grammarly-Style Assistant Bar
        suggestionsBar = UIView()
        suggestionsBar.translatesAutoresizingMaskIntoConstraints = false
        suggestionsBar.backgroundColor = UIColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1.0)
        view.addSubview(suggestionsBar)

        statusIndicator = UIView()
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.layer.cornerRadius = 4.5
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

        // Layout Constraints
        NSLayoutConstraint.activate([
            suggestionsBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionsBar.heightAnchor.constraint(equalToConstant: 44),

            statusIndicator.leadingAnchor.constraint(equalTo: suggestionsBar.leadingAnchor, constant: 12),
            statusIndicator.centerYAnchor.constraint(equalTo: suggestionsBar.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 9),
            statusIndicator.heightAnchor.constraint(equalToConstant: 9),

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
        statusIndicator.backgroundColor = UIColor.systemGreen

        let label = UILabel()
        if !hasFullAccess {
            label.text = "⚠️ Enable 'Allow Full Access' in iOS Settings for AI"
            label.textColor = UIColor.systemYellow
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        } else {
            label.text = "✨ WriteFlow AI: Live grammar checking active"
            label.textColor = UIColor(red: 0.65, green: 0.72, blue: 0.82, alpha: 1.0)
            label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        }
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
        debounceAnalysis(immediate: false)
    }

    @objc private func handleDelete() {
        textDocumentProxy.deleteBackward()
        debounceAnalysis(immediate: false)
    }

    @objc private func handleSpace() {
        textDocumentProxy.insertText(" ")
        debounceAnalysis(immediate: true)
    }

    @objc private func handleReturn() {
        textDocumentProxy.insertText("\n")
        debounceAnalysis(immediate: true)
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
    private func checkCurrentContext(immediate: Bool = false) {
        guard let context = textDocumentProxy.documentContextBeforeInput, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showDefaultAssistantPrompt()
            return
        }

        let sentence = extractActiveSentence(from: context)
        guard sentence.count >= 3 else {
            showDefaultAssistantPrompt()
            return
        }

        if sentence == lastAnalyzedText && !immediate {
            return
        }
        lastAnalyzedText = sentence

        analyzeText(sentence)
    }

    private func extractActiveSentence(from rawText: String) -> String {
        let delimiters = CharacterSet(charactersIn: ".?!;\n")
        let components = rawText.components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return components.last ?? rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func debounceAnalysis(immediate: Bool = false) {
        analysisTimer?.invalidate()
        if immediate {
            checkCurrentContext(immediate: true)
            return
        }
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            self?.checkCurrentContext()
        }
    }

    private func getApiKey() -> String {
        if let shared = UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: "@writing_assistant_api_key"), !shared.isEmpty {
            return shared
        }
        return defaultApiKey
    }

    private func analyzeText(_ sentence: String) {
        statusIndicator.backgroundColor = UIColor.systemOrange

        // 1. Instant local offline check with Apple UITextChecker
        let localSuggestions = checkOfflineSpelling(in: sentence)
        if !localSuggestions.isEmpty && !hasFullAccess {
            // Full Access not enabled, but offline engine caught errors!
            displaySuggestions(localSuggestions, isFromAI: false)
            return
        }

        // If Full Access is disabled, prompt user while showing local suggestions
        if !hasFullAccess {
            clearSuggestions()
            statusIndicator.backgroundColor = UIColor.systemYellow

            let label = UILabel()
            label.text = "⚠️ Full Access required for AI grammar (Settings > WriteFlow)"
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            label.textColor = UIColor.systemYellow
            suggestionsStackView.addArrangedSubview(label)

            if !localSuggestions.isEmpty {
                for item in localSuggestions {
                    addSuggestionChip(original: item.original, replacement: item.replacement)
                }
            }
            return
        }

        // 2. Perform AI Grammar Check via Gemini API
        let apiKey = getApiKey()
        guard let url = URL(string: "\(primaryEndpoint)?key=\(apiKey)") else { return }

        let prompt = """
        You are a real-time keyboard grammar assistant.
        Analyze this sentence for grammar, spelling, and word choice mistakes:
        "\(sentence)"

        Return ONLY a JSON array of suggestions:
        [
          {"original": "incorrectWord", "replacement": "correctWord", "explanation": "brief reason"}
        ]
        If no errors exist, return [].
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 6.0

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
            guard let self = self else { return }

            if let data = data, error == nil,
               let suggestions = self.parseSuggestions(from: data) {
                DispatchQueue.main.async {
                    self.displaySuggestions(suggestions, isFromAI: true)
                }
            } else {
                // Primary failed, fallback to offline local check or fallback endpoint
                DispatchQueue.main.async {
                    if !localSuggestions.isEmpty {
                        self.displaySuggestions(localSuggestions, isFromAI: false)
                    } else {
                        self.statusIndicator.backgroundColor = UIColor.systemGreen
                        self.clearSuggestions()
                        let label = UILabel()
                        label.text = "✓ Grammar looks good"
                        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
                        label.textColor = UIColor.systemGreen
                        self.suggestionsStackView.addArrangedSubview(label)
                    }
                }
            }
        }.resume()
    }

    // MARK: - Offline Apple UITextChecker Engine
    private func checkOfflineSpelling(in text: String) -> [(original: String, replacement: String, explanation: String)] {
        let checker = UITextChecker()
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        var results: [(original: String, replacement: String, explanation: String)] = []
        var offset = 0

        while offset < nsText.length {
            let searchRange = NSRange(location: offset, length: nsText.length - offset)
            let misspelled = checker.rangeOfMisspelledWord(in: text, range: searchRange, startingAt: offset, wrap: false, language: "en_US")
            if misspelled.location == NSNotFound { break }

            let badWord = nsText.substring(with: misspelled)
            if let guesses = checker.guesses(forWordRange: misspelled, in: text, language: "en_US"), let best = guesses.first {
                results.append((original: badWord, replacement: best, explanation: "Spelling"))
            }
            offset = misspelled.location + misspelled.length
        }
        return results
    }

    // MARK: - JSON Parsing
    private func parseSuggestions(from data: Data) -> [(original: String, replacement: String, explanation: String)]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { return nil }

        // Strip markdown code fences if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let innerData = cleaned.data(using: .utf8) else { return nil }

        var rawList: [[String: Any]] = []
        if let list = try? JSONSerialization.jsonObject(with: innerData) as? [[String: Any]] {
            rawList = list
        } else if let dict = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] {
            if let suggestions = dict["suggestions"] as? [[String: Any]] {
                rawList = suggestions
            }
        }

        var results: [(original: String, replacement: String, explanation: String)] = []
        for item in rawList {
            if let orig = item["original"] as? String,
               let rep = item["replacement"] as? String,
               !orig.isEmpty, orig.lowercased() != rep.lowercased() {
                results.append((original: orig, replacement: rep, explanation: (item["explanation"] as? String) ?? "Grammar correction"))
            }
        }
        return results
    }

    // MARK: - Suggestion Chips & Display
    private func displaySuggestions(_ items: [(original: String, replacement: String, explanation: String)], isFromAI: Bool) {
        clearSuggestions()

        if items.isEmpty {
            statusIndicator.backgroundColor = UIColor.systemGreen
            let label = UILabel()
            label.text = "✓ Grammar is correct & clear"
            label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            label.textColor = UIColor.systemGreen
            suggestionsStackView.addArrangedSubview(label)
            return
        }

        // Errors found -> Coral/Red Indicator
        statusIndicator.backgroundColor = UIColor(red: 1.0, green: 0.38, blue: 0.38, alpha: 1.0)

        // Summary Pill
        let countLabel = UILabel()
        countLabel.text = "\(items.count) Fix\(items.count > 1 ? "es" : ""):"
        countLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        countLabel.textColor = UIColor(red: 1.0, green: 0.45, blue: 0.45, alpha: 1.0)
        suggestionsStackView.addArrangedSubview(countLabel)

        for item in items {
            addSuggestionChip(original: item.original, replacement: item.replacement)
        }
    }

    private func addSuggestionChip(original: String, replacement: String) {
        let chip = UIButton(type: .system)
        chip.setTitle("❌ \(original) ➔ ✅ \(replacement)", for: .normal)
        chip.setTitleColor(.white, for: .normal)
        chip.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        chip.backgroundColor = UIColor(red: 0.16, green: 0.22, blue: 0.32, alpha: 1.0)
        chip.layer.cornerRadius = 14
        chip.layer.borderWidth = 1.2
        chip.layer.borderColor = UIColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1.0).cgColor
        chip.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

        chip.addAction(UIAction { [weak self] _ in
            self?.applyCorrection(original: original, replacement: replacement)
        }, for: .touchUpInside)

        suggestionsStackView.addArrangedSubview(chip)
    }

    private func applyCorrection(original: String, replacement: String) {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return }

        if let range = context.range(of: original, options: [.backwards, .caseInsensitive]) {
            let distance = context.distance(from: range.upperBound, to: context.endIndex)

            // 1. Move cursor back to word boundary if not at end
            if distance > 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: -distance)
            }

            // 2. Delete original characters
            let matchedText = String(context[range])
            for _ in 0..<matchedText.count {
                textDocumentProxy.deleteBackward()
            }

            // 3. Insert replacement
            textDocumentProxy.insertText(replacement)

            // 4. Restore cursor position
            if distance > 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: distance)
            }

            // Haptic tap feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            // Re-analyze
            debounceAnalysis(immediate: true)
        }
    }
}
