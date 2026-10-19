import UIKit

class KeyboardViewController: UIInputViewController {

    // MARK: - API & Endpoints
    private let appGroupIdentifier = "group.com.sayyedmustafa.writeflow"
    private let defaultApiKey = String(decoding: Data(base64Encoded: "QVEuQWI4Uk42SmNMSGRIUjROc2cxbjQyOUxjUmRaUzMtcENZRVQ3clJVdERXTW92WkpaQVE=") ?? Data(), as: UTF8.self)
    
    // Lightning-fast models that never return 503
    private let primaryEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent"
    private let fallbackEndpoint1 = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
    private let fallbackEndpoint2 = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"

    // MARK: - UI Components
    private var suggestionsBar: UIView!
    private var suggestionsScrollView: UIScrollView!
    private var suggestionsStackView: UIStackView!
    private var statusIndicator: UIView!
    private var statusLabel: UILabel!
    private var keyboardView: UIView!

    // MARK: - Haptic Feedback Generators
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationHaptic = UINotificationFeedbackGenerator()

    // MARK: - State
    private var isShifted = false
    private var isSymbolMode = false
    private var analysisTimer: Timer?
    private var deleteRepeatTimer: Timer?
    private var lastAnalyzedText = ""
    private var currentFullSentenceFix: String?
    private var currentFlawedSentence: String?

    // Color Palette matching Native iOS Dark Keyboard exactly
    private let keyboardBgColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
    private let normalKeyColor = UIColor(red: 0.38, green: 0.38, blue: 0.40, alpha: 1.0)
    private let normalKeyHighlightColor = UIColor(red: 0.58, green: 0.58, blue: 0.60, alpha: 1.0)
    private let specialKeyColor = UIColor(red: 0.21, green: 0.21, blue: 0.22, alpha: 1.0)
    private let specialKeyHighlightColor = UIColor(red: 0.34, green: 0.34, blue: 0.36, alpha: 1.0)
    private let accentBlueColor = UIColor(red: 0.10, green: 0.50, blue: 0.98, alpha: 1.0)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        lightHaptic.prepare()
        mediumHaptic.prepare()
        rigidHaptic.prepare()
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
        view.backgroundColor = keyboardBgColor

        // 1. Sleek Grammarly-Style Assistant Toolbar
        suggestionsBar = UIView()
        suggestionsBar.translatesAutoresizingMaskIntoConstraints = false
        suggestionsBar.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1.0)
        
        let hairline = UIView()
        hairline.translatesAutoresizingMaskIntoConstraints = false
        hairline.backgroundColor = UIColor(white: 0.24, alpha: 1.0)
        suggestionsBar.addSubview(hairline)
        view.addSubview(suggestionsBar)

        statusIndicator = UIView()
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.layer.cornerRadius = 4.0
        statusIndicator.backgroundColor = UIColor.systemGreen
        suggestionsBar.addSubview(statusIndicator)

        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        statusLabel.textColor = UIColor.systemGreen
        statusLabel.text = "AI"
        suggestionsBar.addSubview(statusLabel)

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

        // 2. Native iOS Keypad View Container
        keyboardView = UIView()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        // Constraints
        NSLayoutConstraint.activate([
            suggestionsBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionsBar.heightAnchor.constraint(equalToConstant: 44),

            hairline.leadingAnchor.constraint(equalTo: suggestionsBar.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: suggestionsBar.trailingAnchor),
            hairline.bottomAnchor.constraint(equalTo: suggestionsBar.bottomAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 0.5),

            statusIndicator.leadingAnchor.constraint(equalTo: suggestionsBar.leadingAnchor, constant: 10),
            statusIndicator.centerYAnchor.constraint(equalTo: suggestionsBar.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),

            statusLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 5),
            statusLabel.centerYAnchor.constraint(equalTo: suggestionsBar.centerYAnchor),

            suggestionsScrollView.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8),
            suggestionsScrollView.trailingAnchor.constraint(equalTo: suggestionsBar.trailingAnchor, constant: -10),
            suggestionsScrollView.topAnchor.constraint(equalTo: suggestionsBar.topAnchor),
            suggestionsScrollView.bottomAnchor.constraint(equalTo: suggestionsBar.bottomAnchor),

            suggestionsStackView.leadingAnchor.constraint(equalTo: suggestionsScrollView.leadingAnchor),
            suggestionsStackView.trailingAnchor.constraint(equalTo: suggestionsScrollView.trailingAnchor),
            suggestionsStackView.topAnchor.constraint(equalTo: suggestionsScrollView.topAnchor),
            suggestionsStackView.bottomAnchor.constraint(equalTo: suggestionsScrollView.bottomAnchor),
            suggestionsStackView.heightAnchor.constraint(equalTo: suggestionsScrollView.heightAnchor),

            keyboardView.topAnchor.constraint(equalTo: suggestionsBar.bottomAnchor, constant: 6),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            keyboardView.heightAnchor.constraint(equalToConstant: 216)
        ])

        buildKeys()
        showDefaultAssistantPrompt()
    }

    private func showDefaultAssistantPrompt() {
        clearSuggestions()
        statusIndicator.backgroundColor = UIColor.systemGreen
        statusLabel.text = "AI"
        statusLabel.textColor = UIColor.systemGreen

        if !hasFullAccess {
            let label = UILabel()
            label.text = "⚠️ Tap here to Enable 'Full Access' in Settings"
            label.textColor = UIColor.systemYellow
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            suggestionsStackView.addArrangedSubview(label)
        } else {
            // Show Tone Suggestions for Clean State
            addToneButton(title: "✨ WriteFlow AI Active", isHeader: true)
            addToneButton(title: "👔 Professional", tone: "Professional")
            addToneButton(title: "⚡ Shorten", tone: "Concise")
            addToneButton(title: "💬 Casual", tone: "Casual")
        }
    }

    private func clearSuggestions() {
        for subview in suggestionsStackView.arrangedSubviews {
            suggestionsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }

    // MARK: - Keypad Generation (Exact iPhone Geometry & SF Symbols)
    private func buildKeys() {
        for subview in keyboardView.subviews {
            subview.removeFromSuperview()
        }

        let row1Letters = isSymbolMode ? ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"] :
            (isShifted ? ["Q","W","E","R","T","Y","U","I","O","P"] : ["q","w","e","r","t","y","u","i","o","p"])
        let row2Letters = isSymbolMode ? ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""] :
            (isShifted ? ["A","S","D","F","G","H","J","K","L"] : ["a","s","d","f","g","h","j","k","l"])
        let row3Letters = isSymbolMode ? [".", ",", "?", "!", "'"] :
            (isShifted ? ["Z","X","C","V","B","N","M"] : ["z","x","c","v","b","n","m"])

        let mainStack = UIStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.distribution = .fillEqually
        mainStack.spacing = 8
        keyboardView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor)
        ])

        // Row 1 (10 Keys)
        mainStack.addArrangedSubview(createRow(keys: row1Letters))

        // Row 2 (9 Keys, centered like native iOS with 18pt padding)
        let row2Container = UIStackView()
        row2Container.axis = .horizontal
        row2Container.spacing = 6
        let spacerL = UIView()
        let spacerR = UIView()
        NSLayoutConstraint.activate([
            spacerL.widthAnchor.constraint(equalToConstant: 16),
            spacerR.widthAnchor.constraint(equalToConstant: 16)
        ])
        row2Container.addArrangedSubview(spacerL)
        row2Container.addArrangedSubview(createRow(keys: row2Letters))
        row2Container.addArrangedSubview(spacerR)
        mainStack.addArrangedSubview(row2Container)

        // Row 3 (Shift, 7 Keys, Delete)
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = 6
        row3.distribution = .fillProportionally

        // Native SF Symbol Shift Key
        let shiftBtn = createSpecialKey(systemImage: isShifted ? "shift.fill" : "shift", flex: 1.25)
        if isShifted {
            shiftBtn.backgroundColor = UIColor(white: 0.90, alpha: 1.0)
            shiftBtn.tintColor = .black
        }
        shiftBtn.addTarget(self, action: #selector(toggleShift), for: .touchUpInside)
        row3.addArrangedSubview(shiftBtn)

        let row3LetterStack = createRow(keys: row3Letters)
        row3.addArrangedSubview(row3LetterStack)

        // Native SF Symbol Backspace Key with Rapid Repeating Delete
        let deleteBtn = createSpecialKey(systemImage: "delete.left.fill", flex: 1.25)
        deleteBtn.addTarget(self, action: #selector(deleteTouchDown), for: .touchDown)
        deleteBtn.addTarget(self, action: #selector(deleteTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        row3.addArrangedSubview(deleteBtn)
        mainStack.addArrangedSubview(row3)

        // Row 4 (123/ABC, Globe, Space, Return)
        let row4 = UIStackView()
        row4.axis = .horizontal
        row4.spacing = 6
        row4.distribution = .fillProportionally

        let modeBtn = createSpecialKey(title: isSymbolMode ? "ABC" : "123", flex: 1.3)
        modeBtn.addTarget(self, action: #selector(toggleSymbolMode), for: .touchUpInside)
        row4.addArrangedSubview(modeBtn)

        let globeBtn = createSpecialKey(systemImage: "globe", flex: 1.0)
        globeBtn.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        row4.addArrangedSubview(globeBtn)

        let spaceBtn = createNormalKey(title: "space", flex: 4.6)
        spaceBtn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        spaceBtn.setTitleColor(UIColor(white: 0.78, alpha: 1.0), for: .normal)
        spaceBtn.addTarget(self, action: #selector(handleSpaceTouchDown), for: .touchDown)
        spaceBtn.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        row4.addArrangedSubview(spaceBtn)

        let returnBtn = createSpecialKey(title: "return", flex: 1.8)
        returnBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        returnBtn.addTarget(self, action: #selector(handleReturnTouchDown), for: .touchDown)
        returnBtn.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        row4.addArrangedSubview(returnBtn)

        mainStack.addArrangedSubview(row4)
    }

    private func createRow(keys: [String]) -> UIStackView {
        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.distribution = .fillEqually
        rowStack.spacing = 6

        for key in keys {
            let btn = createNormalKey(title: key)
            btn.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            btn.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            rowStack.addArrangedSubview(btn)
        }
        return rowStack
    }

    private func createNormalKey(title: String, flex: CGFloat = 1.0) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 22.5, weight: .regular)
        btn.backgroundColor = normalKeyColor
        
        // Exact iPhone key shadow & corner geometry
        btn.layer.cornerRadius = 5.0
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1.0)
        btn.layer.shadowOpacity = 0.35
        btn.layer.shadowRadius = 0.0
        btn.layer.masksToBounds = false
        
        if flex != 1.0 {
            btn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        return btn
    }

    private func createSpecialKey(title: String? = nil, systemImage: String? = nil, flex: CGFloat) -> UIButton {
        let btn = UIButton(type: .custom)
        if let title = title {
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 15.5, weight: .medium)
        }
        if let systemImage = systemImage {
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
            let img = UIImage(systemName: systemImage, withConfiguration: config)
            btn.setImage(img, for: .normal)
            btn.tintColor = .white
        }
        btn.backgroundColor = specialKeyColor
        btn.layer.cornerRadius = 5.0
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1.0)
        btn.layer.shadowOpacity = 0.35
        btn.layer.shadowRadius = 0.0
        btn.layer.masksToBounds = false
        
        btn.addTarget(self, action: #selector(specialKeyTouchDown(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(specialKeyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return btn
    }

    // MARK: - Haptic Touch Feedback & Visual Highlights
    @objc private func keyTouchDown(_ sender: UIButton) {
        sender.backgroundColor = normalKeyHighlightColor
        lightHaptic.impactOccurred()
    }

    @objc private func keyTouchUp(_ sender: UIButton) {
        sender.backgroundColor = normalKeyColor
    }

    @objc private func specialKeyTouchDown(_ sender: UIButton) {
        sender.backgroundColor = specialKeyHighlightColor
        rigidHaptic.impactOccurred()
    }

    @objc private func specialKeyTouchUp(_ sender: UIButton) {
        if sender.title(for: .normal) == "return" || sender.title(for: .normal) == "123" || sender.title(for: .normal) == "ABC" {
            sender.backgroundColor = specialKeyColor
        } else if isShifted && sender.image(for: .normal) != nil {
            // keep shifted white
        } else {
            sender.backgroundColor = specialKeyColor
        }
    }

    // MARK: - Key Action Handlers
    @objc private func keyTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        textDocumentProxy.insertText(title)
        if isShifted {
            isShifted = false
            buildKeys()
        }
        debounceAnalysis(immediate: false)
    }

    @objc private func deleteTouchDown() {
        textDocumentProxy.deleteBackward()
        rigidHaptic.impactOccurred()
        debounceAnalysis(immediate: false)

        deleteRepeatTimer?.invalidate()
        deleteRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.textDocumentProxy.deleteBackward()
            self?.rigidHaptic.impactOccurred()
            self?.debounceAnalysis(immediate: false)
        }
    }

    @objc private func deleteTouchUp() {
        deleteRepeatTimer?.invalidate()
        deleteRepeatTimer = nil
    }

    @objc private func handleSpaceTouchDown() {
        textDocumentProxy.insertText(" ")
        mediumHaptic.impactOccurred()
        debounceAnalysis(immediate: true)
    }

    @objc private func handleReturnTouchDown() {
        textDocumentProxy.insertText("\n")
        mediumHaptic.impactOccurred()
        debounceAnalysis(immediate: true)
    }

    @objc private func toggleShift() {
        isShifted.toggle()
        mediumHaptic.impactOccurred()
        buildKeys()
    }

    @objc private func toggleSymbolMode() {
        isSymbolMode.toggle()
        isShifted = false
        mediumHaptic.impactOccurred()
        buildKeys()
    }

    // MARK: - Grammar & Full-Sentence AI Logic
    private func checkCurrentContext(immediate: Bool = false) {
        guard let context = textDocumentProxy.documentContextBeforeInput, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showDefaultAssistantPrompt()
            return
        }

        let sentence = extractActiveSentence(from: context)
        guard sentence.count >= 4 else {
            showDefaultAssistantPrompt()
            return
        }

        if sentence == lastAnalyzedText && !immediate {
            return
        }
        lastAnalyzedText = sentence
        currentFlawedSentence = sentence

        analyzeText(sentence)
    }

    private func extractActiveSentence(from rawText: String) -> String {
        // Take the active sentence or paragraph
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
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: false) { [weak self] _ in
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
        statusLabel.text = "Checking"
        statusLabel.textColor = UIColor.systemOrange

        // 1. Instant local offline check with Apple UITextChecker
        let localSuggestions = checkOfflineSpelling(in: sentence)

        // If Full Access is off, notify user while showing local offline suggestions
        if !hasFullAccess {
            clearSuggestions()
            statusIndicator.backgroundColor = UIColor.systemYellow
            statusLabel.text = "Access"
            statusLabel.textColor = UIColor.systemYellow

            let label = UILabel()
            label.text = "⚠️ Full Access required for AI grammar (Settings > WriteFlow)"
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            label.textColor = UIColor.systemYellow
            suggestionsStackView.addArrangedSubview(label)

            for item in localSuggestions {
                addSuggestionChip(original: item.original, replacement: item.replacement)
            }
            return
        }

        // 2. Query High-Speed Gemini Model (gemini-3.1-flash-lite-preview)
        let apiKey = getApiKey()
        guard let url = URL(string: "\(primaryEndpoint)?key=\(apiKey)") else { return }

        let prompt = """
        You are a Grammarly-level AI writing assistant.
        Analyze and proofread this text thoroughly for grammar, spelling, tense, and phrasing:
        "\(sentence)"

        Return ONLY valid JSON:
        {
          "fullSentenceFix": "complete grammatically corrected text",
          "hasErrors": true,
          "suggestions": [
            {"original": "flawed phrase", "replacement": "corrected phrase", "explanation": "brief reason"}
          ]
        }
        If perfectly correct: {"fullSentenceFix": "", "hasErrors": false, "suggestions": []}.
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0

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
               let parsed = self.parseGrammarResponse(from: data) {
                DispatchQueue.main.async {
                    self.displayResults(fullFix: parsed.fullFix, suggestions: parsed.suggestions, sentence: sentence)
                }
            } else {
                // Fallback to offline local check
                DispatchQueue.main.async {
                    if !localSuggestions.isEmpty {
                        self.displayResults(fullFix: nil, suggestions: localSuggestions, sentence: sentence)
                    } else {
                        self.showDefaultAssistantPrompt()
                    }
                }
            }
        }.resume()
    }

    // MARK: - Tone Rewrite Helper
    private func requestToneRewrite(tone: String) {
        guard let context = textDocumentProxy.documentContextBeforeInput, !context.isEmpty else { return }
        let sentence = extractActiveSentence(from: context)
        guard !sentence.isEmpty else { return }

        statusIndicator.backgroundColor = UIColor.systemOrange
        statusLabel.text = "Writing"

        let apiKey = getApiKey()
        guard let url = URL(string: "\(primaryEndpoint)?key=\(apiKey)") else { return }

        let prompt = """
        Rewrite this sentence with a \(tone) tone while maintaining core meaning:
        "\(sentence)"
        Return ONLY valid JSON: {"rewritten": "..."}
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["response_mime_type": "application/json", "temperature": 0.2]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, err in
            guard let self = self, let data = data, err == nil else { return }
            if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = root["candidates"] as? [[String: Any]],
               let text = candidates.first?["content"] as? [String: Any],
               let parts = text["parts"] as? [[String: Any]],
               let raw = parts.first?["text"] as? String {
                let cleaned = self.stripMarkdown(raw)
                if let inner = try? JSONSerialization.jsonObject(with: cleaned.data(using: .utf8) ?? Data()) as? [String: Any],
                   let rewritten = inner["rewritten"] as? String {
                    DispatchQueue.main.async {
                        self.applyFullSentenceFix(original: sentence, replacement: rewritten)
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
    private func parseGrammarResponse(from data: Data) -> (fullFix: String?, suggestions: [(original: String, replacement: String, explanation: String)])? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { return nil }

        let cleaned = stripMarkdown(text)
        guard let innerData = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] else { return nil }

        let fullFix = dict["fullSentenceFix"] as? String
        var suggestions: [(original: String, replacement: String, explanation: String)] = []

        if let rawList = dict["suggestions"] as? [[String: Any]] {
            for item in rawList {
                if let orig = item["original"] as? String,
                   let rep = item["replacement"] as? String,
                   !orig.isEmpty, orig.lowercased() != rep.lowercased() {
                    suggestions.append((original: orig, replacement: rep, explanation: (item["explanation"] as? String) ?? ""))
                }
            }
        }

        return (fullFix: (fullFix?.isEmpty == false ? fullFix : nil), suggestions: suggestions)
    }

    private func stripMarkdown(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Visual Results & Fix Chips
    private func displayResults(fullFix: String?, suggestions: [(original: String, replacement: String, explanation: String)], sentence: String) {
        clearSuggestions()

        if suggestions.isEmpty && (fullFix == nil || fullFix == sentence) {
            statusIndicator.backgroundColor = UIColor.systemGreen
            statusLabel.text = "Flawless"
            statusLabel.textColor = UIColor.systemGreen

            addToneButton(title: "✓ Perfect", isHeader: true)
            addToneButton(title: "👔 Professional", tone: "Professional")
            addToneButton(title: "⚡ Shorten", tone: "Concise")
            addToneButton(title: "💬 Casual", tone: "Casual")
            return
        }

        // Errors Found -> Vibrant Coral Indicator
        statusIndicator.backgroundColor = UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
        statusLabel.text = "\(suggestions.count) Fix\(suggestions.count > 1 ? "es" : "")"
        statusLabel.textColor = UIColor(red: 1.0, green: 0.45, blue: 0.45, alpha: 1.0)

        // 1. One-Tap "✨ Fix All" Button (Replaces entire sentence in 1 tap!)
        if let fullFix = fullFix, fullFix != sentence {
            let fixAllBtn = UIButton(type: .custom)
            fixAllBtn.setTitle("✨ Fix All: \"\(fullFix)\"", for: .normal)
            fixAllBtn.setTitleColor(.white, for: .normal)
            fixAllBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            fixAllBtn.backgroundColor = accentBlueColor
            fixAllBtn.layer.cornerRadius = 14
            fixAllBtn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
            fixAllBtn.addAction(UIAction { [weak self] _ in
                self?.applyFullSentenceFix(original: sentence, replacement: fullFix)
            }, for: .touchUpInside)
            suggestionsStackView.addArrangedSubview(fixAllBtn)
        }

        // 2. Individual Word Fix Chips
        for item in suggestions {
            addSuggestionChip(original: item.original, replacement: item.replacement)
        }
    }

    private func addToneButton(title: String, tone: String? = nil, isHeader: Bool = false) {
        let btn = UIButton(type: .custom)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(isHeader ? UIColor(red: 0.5, green: 0.9, blue: 0.6, alpha: 1.0) : UIColor(white: 0.85, alpha: 1.0), for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: isHeader ? .bold : .medium)
        btn.backgroundColor = isHeader ? UIColor(white: 0.18, alpha: 0.6) : UIColor(white: 0.22, alpha: 1.0)
        btn.layer.cornerRadius = 13
        btn.layer.borderWidth = 0.8
        btn.layer.borderColor = UIColor(white: 0.32, alpha: 1.0).cgColor
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

        if let tone = tone {
            btn.addAction(UIAction { [weak self] _ in
                self?.requestToneRewrite(tone: tone)
            }, for: .touchUpInside)
        }

        suggestionsStackView.addArrangedSubview(btn)
    }

    private func addSuggestionChip(original: String, replacement: String) {
        let chip = UIButton(type: .custom)
        chip.setTitle("❌ \(original) ➔ ✅ \(replacement)", for: .normal)
        chip.setTitleColor(.white, for: .normal)
        chip.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        chip.backgroundColor = UIColor(red: 0.20, green: 0.24, blue: 0.32, alpha: 1.0)
        chip.layer.cornerRadius = 13
        chip.layer.borderWidth = 1.0
        chip.layer.borderColor = UIColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 0.7).cgColor
        chip.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

        chip.addAction(UIAction { [weak self] _ in
            self?.applyWordCorrection(original: original, replacement: replacement)
        }, for: .touchUpInside)

        suggestionsStackView.addArrangedSubview(chip)
    }

    // MARK: - Replacement Actions
    private func applyFullSentenceFix(original: String, replacement: String) {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return }

        if let range = context.range(of: original, options: [.backwards, .caseInsensitive]) {
            let distance = context.distance(from: range.upperBound, to: context.endIndex)
            if distance > 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: -distance)
            }

            let matched = String(context[range])
            for _ in 0..<matched.count {
                textDocumentProxy.deleteBackward()
            }

            textDocumentProxy.insertText(replacement)

            if distance > 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: distance)
            }

            notificationHaptic.notificationOccurred(.success)
            debounceAnalysis(immediate: true)
        }
    }

    private func applyWordCorrection(original: String, replacement: String) {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return }

        if let range = context.range(of: original, options: [.backwards, .caseInsensitive]) {
            let distance = context.distance(from: range.upperBound, to: context.endIndex)

            if distance > 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: -distance)
            }

            let matched = String(context[range])
            for _ in 0..<matched.count {
                textDocumentProxy.deleteBackward()
            }

            textDocumentProxy.insertText(replacement)

            if distance > 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: distance)
            }

            notificationHaptic.notificationOccurred(.success)
            debounceAnalysis(immediate: true)
        }
    }
}
