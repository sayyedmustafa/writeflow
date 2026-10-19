import UIKit

class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {

    // Audio click feedback for native iOS feel
    var enableInputClicksWhenVisible: Bool {
        return true
    }

    // MARK: - API & Endpoints
    private let appGroupIdentifier = "group.com.sayyedmustafa.writeflow"
    private let defaultApiKey = String(decoding: Data(base64Encoded: "QVEuQWI4Uk42SmNMSGRIUjROc2cxbjQyOUxjUmRaUzMtcENZRVQ3clJVdERXTW92WkpaQVE=") ?? Data(), as: UTF8.self)
    
    // Blazing-fast models (~1s response time, zero 503 errors)
    private let primaryEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent"
    private let fallbackEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"

    // MARK: - UI Components (Grammarly-Style Assistant Toolbar)
    private var toolbarContainer: UIView!
    private var grammarlyLogoButton: UIButton!
    private var grammarlyStatusBadge: UILabel!
    private var activitySpinner: UIActivityIndicatorView!
    private var suggestionsScrollView: UIScrollView!
    private var suggestionsStackView: UIStackView!
    private var keyboardView: UIView!

    // MARK: - Haptic Feedback Generators
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationHaptic = UINotificationFeedbackGenerator()

    // MARK: - State
    private var isShifted = false
    private var isCapsLock = false
    private var isSymbolMode = false
    private var isAltSymbolMode = false
    private var lastShiftTapTime: TimeInterval = 0
    private var lastSpaceTapTime: TimeInterval = 0
    private var analysisTimer: Timer?
    private var deleteRepeatTimer: Timer?
    private var lastAnalyzedText = ""
    private var currentFullSentenceFix: String?
    private var currentFlawedSentence: String?
    private var isChecking = false

    // Color Palette matching Native iOS Dark Keyboard & Grammarly
    private let keyboardBgColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
    private let normalKeyColor = UIColor(red: 0.38, green: 0.38, blue: 0.40, alpha: 1.0)
    private let normalKeyHighlightColor = UIColor(red: 0.58, green: 0.58, blue: 0.60, alpha: 1.0)
    private let specialKeyColor = UIColor(red: 0.21, green: 0.21, blue: 0.22, alpha: 1.0)
    private let specialKeyHighlightColor = UIColor(red: 0.34, green: 0.34, blue: 0.36, alpha: 1.0)
    
    // Grammarly Branding Colors
    private let grammarlyGreen = UIColor(red: 0.08, green: 0.72, blue: 0.52, alpha: 1.0)
    private let grammarlyCoral = UIColor(red: 0.98, green: 0.38, blue: 0.38, alpha: 1.0)
    private let grammarlyBlue = UIColor(red: 0.10, green: 0.55, blue: 0.98, alpha: 1.0)

    // Dedicated Network Session with Cellular & Connectivity Guarantee
    private lazy var networkSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

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

    // MARK: - UI Setup (Exact Grammarly Keyboard Architecture)
    private func setupUI() {
        view.backgroundColor = keyboardBgColor

        // 1. Top Grammarly Assistant Strip (Height 46pt)
        toolbarContainer = UIView()
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1.0)
        
        let hairline = UIView()
        hairline.translatesAutoresizingMaskIntoConstraints = false
        hairline.backgroundColor = UIColor(white: 0.22, alpha: 1.0)
        toolbarContainer.addSubview(hairline)
        view.addSubview(toolbarContainer)

        // 2. Circular Grammarly Logo Widget on the Left (Interactive)
        grammarlyLogoButton = UIButton(type: .custom)
        grammarlyLogoButton.translatesAutoresizingMaskIntoConstraints = false
        grammarlyLogoButton.layer.cornerRadius = 16
        grammarlyLogoButton.layer.borderWidth = 1.5
        grammarlyLogoButton.layer.borderColor = grammarlyGreen.cgColor
        grammarlyLogoButton.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        grammarlyLogoButton.setTitle("G", for: .normal)
        grammarlyLogoButton.setTitleColor(grammarlyGreen, for: .normal)
        grammarlyLogoButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .black)
        grammarlyLogoButton.addTarget(self, action: #selector(grammarlyLogoTapped), for: .touchUpInside)
        toolbarContainer.addSubview(grammarlyLogoButton)

        // Error Badge Counter on Logo (like Grammarly)
        grammarlyStatusBadge = UILabel()
        grammarlyStatusBadge.translatesAutoresizingMaskIntoConstraints = false
        grammarlyStatusBadge.layer.cornerRadius = 7
        grammarlyStatusBadge.layer.masksToBounds = true
        grammarlyStatusBadge.backgroundColor = grammarlyCoral
        grammarlyStatusBadge.textColor = .white
        grammarlyStatusBadge.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        grammarlyStatusBadge.textAlignment = .center
        grammarlyStatusBadge.isHidden = true
        toolbarContainer.addSubview(grammarlyStatusBadge)

        activitySpinner = UIActivityIndicatorView(style: .medium)
        activitySpinner.translatesAutoresizingMaskIntoConstraints = false
        activitySpinner.color = grammarlyGreen
        activitySpinner.hidesWhenStopped = true
        toolbarContainer.addSubview(activitySpinner)

        // 3. Scrollable Grammarly Suggestions Strip
        suggestionsScrollView = UIScrollView()
        suggestionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsScrollView.showsHorizontalScrollIndicator = false
        toolbarContainer.addSubview(suggestionsScrollView)

        suggestionsStackView = UIStackView()
        suggestionsStackView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsStackView.axis = .horizontal
        suggestionsStackView.spacing = 8
        suggestionsStackView.alignment = .center
        suggestionsScrollView.addSubview(suggestionsStackView)

        // 4. Native iOS QWERTY Keypad
        keyboardView = UIView()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        // Constraints
        NSLayoutConstraint.activate([
            toolbarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            toolbarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarContainer.heightAnchor.constraint(equalToConstant: 46),

            hairline.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor),
            hairline.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 0.5),

            grammarlyLogoButton.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 10),
            grammarlyLogoButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            grammarlyLogoButton.widthAnchor.constraint(equalToConstant: 32),
            grammarlyLogoButton.heightAnchor.constraint(equalToConstant: 32),

            grammarlyStatusBadge.topAnchor.constraint(equalTo: grammarlyLogoButton.topAnchor, constant: -3),
            grammarlyStatusBadge.trailingAnchor.constraint(equalTo: grammarlyLogoButton.trailingAnchor, constant: 4),
            grammarlyStatusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 14),
            grammarlyStatusBadge.heightAnchor.constraint(equalToConstant: 14),

            activitySpinner.centerXAnchor.constraint(equalTo: grammarlyLogoButton.centerXAnchor),
            activitySpinner.centerYAnchor.constraint(equalTo: grammarlyLogoButton.centerYAnchor),

            suggestionsScrollView.leadingAnchor.constraint(equalTo: grammarlyLogoButton.trailingAnchor, constant: 10),
            suggestionsScrollView.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -10),
            suggestionsScrollView.topAnchor.constraint(equalTo: toolbarContainer.topAnchor),
            suggestionsScrollView.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),

            suggestionsStackView.leadingAnchor.constraint(equalTo: suggestionsScrollView.leadingAnchor),
            suggestionsStackView.trailingAnchor.constraint(equalTo: suggestionsScrollView.trailingAnchor),
            suggestionsStackView.topAnchor.constraint(equalTo: suggestionsScrollView.topAnchor),
            suggestionsStackView.bottomAnchor.constraint(equalTo: suggestionsScrollView.bottomAnchor),
            suggestionsStackView.heightAnchor.constraint(equalTo: suggestionsScrollView.heightAnchor),

            keyboardView.topAnchor.constraint(equalTo: toolbarContainer.bottomAnchor, constant: 6),
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
        setLogoState(mode: .clean)

        // Check if user has an API key in clipboard that they can paste with 1 tap
        checkClipboardForApiKey()

        if !hasFullAccess {
            let label = UILabel()
            label.text = "⚠️ Enable 'Allow Full Access' in iOS Settings"
            label.textColor = UIColor.systemYellow
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            suggestionsStackView.addArrangedSubview(label)
        } else {
            // Clean state Grammarly tone pills
            addTonePill(title: "✨ All Clear", isStatic: true)
            addTonePill(title: "👔 Professional", tone: "Professional")
            addTonePill(title: "⚡ Shorten", tone: "Concise")
            addTonePill(title: "💬 Casual", tone: "Casual")
        }
    }

    private func clearSuggestions() {
        for subview in suggestionsStackView.arrangedSubviews {
            suggestionsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }

    enum LogoMode {
        case clean
        case checking
        case errors(count: Int)
        case offline
    }

    private func setLogoState(mode: LogoMode) {
        switch mode {
        case .clean:
            activitySpinner.stopAnimating()
            grammarlyLogoButton.setTitle("G", for: .normal)
            grammarlyLogoButton.layer.borderColor = grammarlyGreen.cgColor
            grammarlyLogoButton.setTitleColor(grammarlyGreen, for: .normal)
            grammarlyStatusBadge.isHidden = true
        case .checking:
            grammarlyLogoButton.setTitle("", for: .normal)
            activitySpinner.startAnimating()
            grammarlyLogoButton.layer.borderColor = grammarlyBlue.cgColor
            grammarlyStatusBadge.isHidden = true
        case .errors(let count):
            activitySpinner.stopAnimating()
            grammarlyLogoButton.setTitle("G", for: .normal)
            grammarlyLogoButton.layer.borderColor = grammarlyCoral.cgColor
            grammarlyLogoButton.setTitleColor(grammarlyCoral, for: .normal)
            grammarlyStatusBadge.text = "\(count)"
            grammarlyStatusBadge.isHidden = false
        case .offline:
            activitySpinner.stopAnimating()
            grammarlyLogoButton.setTitle("!", for: .normal)
            grammarlyLogoButton.layer.borderColor = UIColor.systemYellow.cgColor
            grammarlyLogoButton.setTitleColor(UIColor.systemYellow, for: .normal)
            grammarlyStatusBadge.isHidden = true
        }
    }

    @objc private func grammarlyLogoTapped() {
        mediumHaptic.impactOccurred()
        checkCurrentContext(immediate: true)
    }

    // MARK: - 1-Tap Clipboard API Key Importer
    private func checkClipboardForApiKey() {
        guard UIPasteboard.general.hasStrings,
              let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              clip.count > 25, (clip.hasPrefix("AIza") || clip.hasPrefix("AQ.")) else { return }

        let importBtn = UIButton(type: .custom)
        importBtn.setTitle("🔑 Tap to Use Copied API Key", for: .normal)
        importBtn.setTitleColor(.white, for: .normal)
        importBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        importBtn.backgroundColor = grammarlyBlue
        importBtn.layer.cornerRadius = 13
        importBtn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        importBtn.addAction(UIAction { [weak self] _ in
            UserDefaults.standard.set(clip, forKey: "custom_gemini_api_key")
            self?.notificationHaptic.notificationOccurred(.success)
            self?.showDefaultAssistantPrompt()
        }, for: .touchUpInside)

        suggestionsStackView.addArrangedSubview(importBtn)
    }

    // MARK: - Keypad Generation (Exact iPhone Geometry & SF Symbols)
    private func buildKeys() {
        for subview in keyboardView.subviews {
            subview.removeFromSuperview()
        }

        let isUpper = isShifted || isCapsLock
        let row1Letters: [String]
        let row2Letters: [String]
        let row3Letters: [String]

        if isSymbolMode {
            if isAltSymbolMode {
                row1Letters = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
                row2Letters = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
                row3Letters = [".", ",", "?", "!", "'"]
            } else {
                row1Letters = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
                row2Letters = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
                row3Letters = [".", ",", "?", "!", "'"]
            }
        } else {
            row1Letters = isUpper ? ["Q","W","E","R","T","Y","U","I","O","P"] : ["q","w","e","r","t","y","u","i","o","p"]
            row2Letters = isUpper ? ["A","S","D","F","G","H","J","K","L"] : ["a","s","d","f","g","h","j","k","l"]
            row3Letters = isUpper ? ["Z","X","C","V","B","N","M"] : ["z","x","c","v","b","n","m"]
        }

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

        // Row 2 (Centered like native iOS with margin)
        let row2Container = UIStackView()
        row2Container.axis = .horizontal
        row2Container.spacing = 6
        let spacerL = UIView()
        let spacerR = UIView()
        let margin: CGFloat = (isSymbolMode) ? 8 : 16
        NSLayoutConstraint.activate([
            spacerL.widthAnchor.constraint(equalToConstant: margin),
            spacerR.widthAnchor.constraint(equalToConstant: margin)
        ])
        row2Container.addArrangedSubview(spacerL)
        row2Container.addArrangedSubview(createRow(keys: row2Letters))
        row2Container.addArrangedSubview(spacerR)
        mainStack.addArrangedSubview(row2Container)

        // Row 3 (Shift / Symbols Switcher, Keys, Delete)
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = 6
        row3.distribution = .fillProportionally

        if isSymbolMode {
            let altSwitchBtn = createSpecialKey(title: isAltSymbolMode ? "123" : "#+=", flex: 1.25)
            altSwitchBtn.addTarget(self, action: #selector(toggleAltSymbolMode), for: .touchUpInside)
            row3.addArrangedSubview(altSwitchBtn)
        } else {
            let shiftIcon = isCapsLock ? "capslock.fill" : (isShifted ? "shift.fill" : "shift")
            let shiftBtn = createSpecialKey(systemImage: shiftIcon, flex: 1.25)
            if isUpper {
                shiftBtn.backgroundColor = UIColor(white: 0.90, alpha: 1.0)
                shiftBtn.tintColor = .black
            }
            shiftBtn.addTarget(self, action: #selector(toggleShift), for: .touchUpInside)
            row3.addArrangedSubview(shiftBtn)
        }

        let row3LetterStack = createRow(keys: row3Letters)
        row3.addArrangedSubview(row3LetterStack)

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
        UIDevice.current.playInputClick()
    }

    @objc private func keyTouchUp(_ sender: UIButton) {
        sender.backgroundColor = normalKeyColor
    }

    @objc private func specialKeyTouchDown(_ sender: UIButton) {
        sender.backgroundColor = specialKeyHighlightColor
        rigidHaptic.impactOccurred()
        UIDevice.current.playInputClick()
    }

    @objc private func specialKeyTouchUp(_ sender: UIButton) {
        if sender.title(for: .normal) == "return" || sender.title(for: .normal) == "123" || sender.title(for: .normal) == "ABC" || sender.title(for: .normal) == "#+=" {
            sender.backgroundColor = specialKeyColor
        } else if (isShifted || isCapsLock) && sender.image(for: .normal) != nil {
            // keep shifted white
        } else {
            sender.backgroundColor = specialKeyColor
        }
    }

    // MARK: - Key Actions
    @objc private func keyTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        textDocumentProxy.insertText(title)
        if isShifted && !isCapsLock {
            isShifted = false
            buildKeys()
        }
        debounceAnalysis(immediate: false)
    }

    @objc private func deleteTouchDown() {
        textDocumentProxy.deleteBackward()
        rigidHaptic.impactOccurred()
        UIDevice.current.playInputClick()
        debounceAnalysis(immediate: false)

        deleteRepeatTimer?.invalidate()
        deleteRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.textDocumentProxy.deleteBackward()
            self?.rigidHaptic.impactOccurred()
            UIDevice.current.playInputClick()
            self?.debounceAnalysis(immediate: false)
        }
    }

    @objc private func deleteTouchUp() {
        deleteRepeatTimer?.invalidate()
        deleteRepeatTimer = nil
    }

    @objc private func handleSpaceTouchDown() {
        let now = Date().timeIntervalSince1970
        if now - lastSpaceTapTime < 0.35 {
            // Double-tap space shortcut: convert space to ". "
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText(". ")
            lastSpaceTapTime = 0
        } else {
            textDocumentProxy.insertText(" ")
            lastSpaceTapTime = now
        }
        mediumHaptic.impactOccurred()
        UIDevice.current.playInputClick()
        debounceAnalysis(immediate: true)
    }

    @objc private func handleReturnTouchDown() {
        textDocumentProxy.insertText("\n")
        mediumHaptic.impactOccurred()
        UIDevice.current.playInputClick()
        debounceAnalysis(immediate: true)
    }

    @objc private func toggleShift() {
        let now = Date().timeIntervalSince1970
        if now - lastShiftTapTime < 0.35 {
            // Double tap = Caps Lock
            isCapsLock.toggle()
            isShifted = isCapsLock
        } else {
            if isCapsLock {
                isCapsLock = false
                isShifted = false
            } else {
                isShifted.toggle()
            }
        }
        lastShiftTapTime = now
        mediumHaptic.impactOccurred()
        buildKeys()
    }

    @objc private func toggleSymbolMode() {
        isSymbolMode.toggle()
        isAltSymbolMode = false
        isShifted = false
        isCapsLock = false
        mediumHaptic.impactOccurred()
        buildKeys()
    }

    @objc private func toggleAltSymbolMode() {
        isAltSymbolMode.toggle()
        mediumHaptic.impactOccurred()
        buildKeys()
    }

    // MARK: - Grammarly AI Logic & Text Analysis
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
        // 1. Check local keyboard preference
        if let custom = UserDefaults.standard.string(forKey: "custom_gemini_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), custom.count > 25 {
            return custom
        }
        // 2. Check App Group if available
        if let shared = UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: "@writing_assistant_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), shared.count > 25 {
            return shared
        }
        // 3. Fallback to default verified working key
        return defaultApiKey
    }

    private func analyzeText(_ sentence: String) {
        setLogoState(mode: .checking)

        // 1. Instant local offline check with Apple UITextChecker
        let localSuggestions = checkOfflineSpelling(in: sentence)

        // If Full Access is off, notify user
        if !hasFullAccess {
            clearSuggestions()
            setLogoState(mode: .offline)

            let label = UILabel()
            label.text = "⚠️ Enable 'Allow Full Access' in iOS Settings for AI"
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            label.textColor = UIColor.systemYellow
            suggestionsStackView.addArrangedSubview(label)

            for item in localSuggestions {
                addSuggestionCard(original: item.original, replacement: item.replacement)
            }
            return
        }

        // 2. Query High-Speed Gemini Model with safetySettings
        let apiKey = getApiKey()
        guard let url = URL(string: "\(primaryEndpoint)?key=\(apiKey)") else { return }

        let prompt = """
        You are a strict grammar proofreader like Grammarly.
        Proofread and correct this text thoroughly:
        "\(sentence)"

        Strict Instructions:
        1. Fix missing auxiliary verbs (e.g. "how you want" -> "how do you want").
        2. Fix typos, slang, and colloquial shorthand (e.g. "wan" -> "want").
        3. Fix capitalization (sentences must start with an uppercase letter).
        4. Preserve tone/profanity if present, but fix all syntax and grammar.
        5. If there are ANY typos, grammatical omissions, or errors, you MUST set "hasErrors": true.

        Return ONLY valid JSON:
        {
          "fullSentenceFix": "complete grammatically corrected text",
          "hasErrors": true,
          "suggestions": [
            {"original": "flawed phrase", "replacement": "corrected phrase", "explanation": "brief reason"}
          ]
        }
        If completely flawless standard English, return: {"fullSentenceFix": "", "hasErrors": false, "suggestions": []}.
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0

        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.1
            ],
            "safetySettings": [
                ["category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = bodyData

        networkSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0

            if let data = data, error == nil, httpStatus == 200,
               let parsed = self.parseGrammarResponse(from: data) {
                DispatchQueue.main.async {
                    self.displayResults(fullFix: parsed.fullFix, suggestions: parsed.suggestions, sentence: sentence)
                }
            } else {
                // If network timeout or offline
                DispatchQueue.main.async {
                    if !localSuggestions.isEmpty {
                        self.setLogoState(mode: .errors(count: localSuggestions.count))
                        self.displayResults(fullFix: nil, suggestions: localSuggestions, sentence: sentence)
                    } else {
                        self.setLogoState(mode: .offline)
                        self.clearSuggestions()
                        
                        let retryBtn = UIButton(type: .custom)
                        retryBtn.setTitle("🔄 Tap to Re-check", for: .normal)
                        retryBtn.setTitleColor(UIColor.systemYellow, for: .normal)
                        retryBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
                        retryBtn.layer.cornerRadius = 13
                        retryBtn.layer.borderWidth = 1.0
                        retryBtn.layer.borderColor = UIColor.systemYellow.cgColor
                        retryBtn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
                        retryBtn.addAction(UIAction { [weak self] _ in
                            self?.checkCurrentContext(immediate: true)
                        }, for: .touchUpInside)
                        self.suggestionsStackView.addArrangedSubview(retryBtn)
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

        setLogoState(mode: .checking)

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
        request.timeoutInterval = 15.0
        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["response_mime_type": "application/json", "temperature": 0.2],
            "safetySettings": [
                ["category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        networkSession.dataTask(with: request) { [weak self] data, _, err in
            guard let self = self, let data = data, err == nil else {
                DispatchQueue.main.async { self?.setLogoState(mode: .clean) }
                return
            }
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
              let parts = content["parts"] as? [[String: Any]] else { return nil }

        let textParts = parts.compactMap { $0["text"] as? String }
        let text = textParts.joined(separator: "\n")
        guard !text.isEmpty else { return nil }

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

    // MARK: - Display Grammarly Suggestion Cards
    private func displayResults(fullFix: String?, suggestions: [(original: String, replacement: String, explanation: String)], sentence: String) {
        clearSuggestions()

        if suggestions.isEmpty && (fullFix == nil || fullFix == sentence) {
            setLogoState(mode: .clean)
            addTonePill(title: "✓ Perfect", isStatic: true)
            addTonePill(title: "👔 Professional", tone: "Professional")
            addTonePill(title: "⚡ Shorten", tone: "Concise")
            addTonePill(title: "💬 Casual", tone: "Casual")
            return
        }

        // Errors Found -> Update Grammarly Logo Badge
        setLogoState(mode: .errors(count: suggestions.count))

        // 1. One-Tap Grammarly "✨ Fix All" Card
        if let fullFix = fullFix, fullFix != sentence {
            let fixAllCard = UIButton(type: .custom)
            fixAllCard.setTitle("✨ Fix All: \"\(fullFix)\"", for: .normal)
            fixAllCard.setTitleColor(.white, for: .normal)
            fixAllCard.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            fixAllCard.backgroundColor = grammarlyBlue
            fixAllCard.layer.cornerRadius = 14
            fixAllCard.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
            fixAllCard.addAction(UIAction { [weak self] _ in
                self?.applyFullSentenceFix(original: sentence, replacement: fullFix)
            }, for: .touchUpInside)
            suggestionsStackView.addArrangedSubview(fixAllCard)
        }

        // 2. Individual Grammarly Suggestion Cards (Strikethrough Red -> Green Replacement)
        for item in suggestions {
            addSuggestionCard(original: item.original, replacement: item.replacement)
        }
    }

    private func addTonePill(title: String, tone: String? = nil, isStatic: Bool = false) {
        let pill = UIButton(type: .custom)
        pill.setTitle(title, for: .normal)
        pill.setTitleColor(isStatic ? grammarlyGreen : UIColor(white: 0.88, alpha: 1.0), for: .normal)
        pill.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: isStatic ? .bold : .medium)
        pill.backgroundColor = isStatic ? UIColor(white: 0.18, alpha: 0.7) : UIColor(white: 0.22, alpha: 1.0)
        pill.layer.cornerRadius = 13
        pill.layer.borderWidth = 0.8
        pill.layer.borderColor = isStatic ? grammarlyGreen.withAlphaComponent(0.4).cgColor : UIColor(white: 0.32, alpha: 1.0).cgColor
        pill.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

        if let tone = tone {
            pill.addAction(UIAction { [weak self] _ in
                self?.requestToneRewrite(tone: tone)
            }, for: .touchUpInside)
        }

        suggestionsStackView.addArrangedSubview(pill)
    }

    private func addSuggestionCard(original: String, replacement: String) {
        let card = UIButton(type: .custom)
        
        // Exact Grammarly-style visual: Red wrong -> Green fix
        let normalText = "\(original)  ➔  \(replacement)"
        let attr = NSMutableAttributedString(string: normalText)
        if let range = normalText.range(of: original) {
            let nsRange = NSRange(range, in: normalText)
            attr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
            attr.addAttribute(.foregroundColor, value: grammarlyCoral, range: nsRange)
        }
        if let range = normalText.range(of: replacement) {
            let nsRange = NSRange(range, in: normalText)
            attr.addAttribute(.foregroundColor, value: grammarlyGreen, range: nsRange)
            attr.addAttribute(.font, value: UIFont.systemFont(ofSize: 13, weight: .bold), range: nsRange)
        }
        
        card.setAttributedTitle(attr, for: .normal)
        card.backgroundColor = UIColor(red: 0.18, green: 0.20, blue: 0.25, alpha: 1.0)
        card.layer.cornerRadius = 13
        card.layer.borderWidth = 1.0
        card.layer.borderColor = grammarlyGreen.withAlphaComponent(0.6).cgColor
        card.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

        card.addAction(UIAction { [weak self, weak card] _ in
            self?.applyWordCorrection(original: original, replacement: replacement)
            if let card = card {
                self?.suggestionsStackView.removeArrangedSubview(card)
                card.removeFromSuperview()
                if self?.suggestionsStackView.arrangedSubviews.isEmpty == true {
                    self?.setLogoState(mode: .clean)
                    self?.showDefaultAssistantPrompt()
                }
            }
        }, for: .touchUpInside)

        suggestionsStackView.addArrangedSubview(card)
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
        } else {
            // Trimmed fallback
            let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmedRange = context.range(of: trimmed, options: [.backwards, .caseInsensitive]) {
                let distance = context.distance(from: trimmedRange.upperBound, to: context.endIndex)
                if distance > 0 {
                    textDocumentProxy.adjustTextPosition(byCharacterOffset: -distance)
                }
                for _ in 0..<trimmed.count {
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
