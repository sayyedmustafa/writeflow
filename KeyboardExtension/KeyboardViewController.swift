import UIKit

class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {

    // MARK: - Native iOS Audio Click Feedback
    var enableInputClicksWhenVisible: Bool {
        return true
    }

    // MARK: - API & Endpoints
    private let appGroupIdentifier = "group.com.sayyedmustafa.writeflow"
    private let defaultApiKey = String(decoding: Data(base64Encoded: "QVEuQWI4Uk42SmNMSGRIUjROc2cxbjQyOUxjUmRaUzMtcENZRVQ3clJVdERXTW92WkpaQVE=") ?? Data(), as: UTF8.self)
    
    // Blazing-fast models (~1s response time, zero 503 errors)
    private let primaryEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent"
    private let fallbackEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"

    // MARK: - UI Components
    private var toolbarContainer: UIView!
    private var hairline: UIView!
    private var grammarlyLogoButton: UIButton!
    private var grammarlyStatusBadge: UILabel!
    private var activitySpinner: UIActivityIndicatorView!
    private var suggestionsScrollView: UIScrollView!
    private var suggestionsStackView: UIStackView!
    private var keyboardView: UIView!

    // Key collections for dynamic theming
    private var normalButtons: [UIButton] = []
    private var specialButtons: [UIButton] = []
    private var shiftButton: UIButton?

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

    private var heightConstraint: NSLayoutConstraint?

    // MARK: - Dynamic iOS & Grammarly Theme
    private var isDarkMode: Bool {
        return traitCollection.userInterfaceStyle == .dark
    }

    // Authentic iOS Keyboard Background Colors
    private var keyboardBgColor: UIColor {
        return isDarkMode ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) : UIColor(red: 0.82, green: 0.835, blue: 0.855, alpha: 1.0)
    }

    // Authentic iOS Key Colors
    private var normalKeyColor: UIColor {
        return isDarkMode ? UIColor(white: 0.38, alpha: 1.0) : UIColor.white
    }

    private var normalKeyHighlightColor: UIColor {
        return isDarkMode ? UIColor(white: 0.58, alpha: 1.0) : UIColor(red: 0.72, green: 0.73, blue: 0.76, alpha: 1.0)
    }

    private var normalKeyTextColor: UIColor {
        return isDarkMode ? UIColor.white : UIColor.black
    }

    private var specialKeyColor: UIColor {
        return isDarkMode ? UIColor(white: 0.22, alpha: 1.0) : UIColor(red: 0.68, green: 0.70, blue: 0.74, alpha: 1.0)
    }

    private var specialKeyHighlightColor: UIColor {
        return isDarkMode ? UIColor(white: 0.34, alpha: 1.0) : UIColor(white: 0.88, alpha: 1.0)
    }

    private var specialKeyTextColor: UIColor {
        return isDarkMode ? UIColor.white : UIColor.black
    }

    private var keyShadowColor: UIColor {
        return isDarkMode ? UIColor.black : UIColor(red: 0.53, green: 0.54, blue: 0.57, alpha: 1.0)
    }

    private var keyShadowOpacity: Float {
        return isDarkMode ? 0.45 : 1.0
    }

    // Grammarly Branding Colors
    private let grammarlyGreen = UIColor(red: 0.0, green: 0.788, blue: 0.46, alpha: 1.0) // Iconic #00C975
    private let grammarlyCoral = UIColor(red: 1.0, green: 0.32, blue: 0.32, alpha: 1.0) // Error red #FF5252
    private let grammarlyBlue = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)   // iOS Blue #007AFF

    private var toolbarBgColor: UIColor {
        return isDarkMode ? UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0) : UIColor(red: 0.88, green: 0.89, blue: 0.91, alpha: 1.0)
    }

    private var hairlineColor: UIColor {
        return isDarkMode ? UIColor(white: 0.22, alpha: 1.0) : UIColor(white: 0.72, alpha: 1.0)
    }

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
        setupHeightConstraint()
        checkCurrentContext(immediate: true)
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        setupHeightConstraint()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyTheme()
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        debounceAnalysis(immediate: false)
    }

    // MARK: - Height Management (Prevents UIKit from crushing the keyboard)
    private func setupHeightConstraint() {
        let desiredHeight: CGFloat = 280.0 // 44pt toolbar + 6pt gap + 216pt keyboard rows + 14pt bottom padding
        if heightConstraint == nil {
            heightConstraint = view.heightAnchor.constraint(equalToConstant: desiredHeight)
            heightConstraint?.priority = UILayoutPriority(999)
            heightConstraint?.isActive = true
        } else if heightConstraint?.constant != desiredHeight {
            heightConstraint?.constant = desiredHeight
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = keyboardBgColor

        // 1. Top Grammarly Assistant Strip (Height 42pt)
        toolbarContainer = UIView()
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.backgroundColor = toolbarBgColor
        view.addSubview(toolbarContainer)

        hairline = UIView()
        hairline.translatesAutoresizingMaskIntoConstraints = false
        hairline.backgroundColor = hairlineColor
        toolbarContainer.addSubview(hairline)

        // 2. Circular Grammarly Logo Widget (Solid Green Circle with White "G")
        grammarlyLogoButton = UIButton(type: .custom)
        grammarlyLogoButton.translatesAutoresizingMaskIntoConstraints = false
        grammarlyLogoButton.layer.cornerRadius = 15
        grammarlyLogoButton.layer.masksToBounds = true
        grammarlyLogoButton.backgroundColor = grammarlyGreen
        grammarlyLogoButton.setTitle("G", for: .normal)
        grammarlyLogoButton.setTitleColor(.white, for: .normal)
        grammarlyLogoButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .black)
        grammarlyLogoButton.addTarget(self, action: #selector(grammarlyLogoTapped), for: .touchUpInside)
        toolbarContainer.addSubview(grammarlyLogoButton)

        // Error Badge Counter on Logo
        grammarlyStatusBadge = UILabel()
        grammarlyStatusBadge.translatesAutoresizingMaskIntoConstraints = false
        grammarlyStatusBadge.layer.cornerRadius = 7.5
        grammarlyStatusBadge.layer.masksToBounds = true
        grammarlyStatusBadge.backgroundColor = grammarlyCoral
        grammarlyStatusBadge.textColor = .white
        grammarlyStatusBadge.font = UIFont.systemFont(ofSize: 9.5, weight: .bold)
        grammarlyStatusBadge.textAlignment = .center
        grammarlyStatusBadge.isHidden = true
        toolbarContainer.addSubview(grammarlyStatusBadge)

        // White Spinner inside Logo when checking
        activitySpinner = UIActivityIndicatorView(style: .medium)
        activitySpinner.translatesAutoresizingMaskIntoConstraints = false
        activitySpinner.color = .white
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

        // 4. Native iOS QWERTY Keypad Container
        keyboardView = UIView()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        // Constraints
        NSLayoutConstraint.activate([
            toolbarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            toolbarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarContainer.heightAnchor.constraint(equalToConstant: 42),

            hairline.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor),
            hairline.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 0.5),

            grammarlyLogoButton.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 10),
            grammarlyLogoButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            grammarlyLogoButton.widthAnchor.constraint(equalToConstant: 30),
            grammarlyLogoButton.heightAnchor.constraint(equalToConstant: 30),

            grammarlyStatusBadge.topAnchor.constraint(equalTo: grammarlyLogoButton.topAnchor, constant: -3),
            grammarlyStatusBadge.trailingAnchor.constraint(equalTo: grammarlyLogoButton.trailingAnchor, constant: 4),
            grammarlyStatusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 15),
            grammarlyStatusBadge.heightAnchor.constraint(equalToConstant: 15),

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
            keyboardView.heightAnchor.constraint(equalToConstant: 216)
        ])

        buildKeys()
        showDefaultAssistantPrompt()
    }

    private func applyTheme() {
        view.backgroundColor = keyboardBgColor
        toolbarContainer.backgroundColor = toolbarBgColor
        hairline.backgroundColor = hairlineColor

        for btn in normalButtons {
            btn.backgroundColor = normalKeyColor
            btn.setTitleColor(normalKeyTextColor, for: .normal)
            btn.layer.shadowColor = keyShadowColor.cgColor
            btn.layer.shadowOpacity = keyShadowOpacity
        }

        for btn in specialButtons {
            btn.backgroundColor = specialKeyColor
            btn.setTitleColor(specialKeyTextColor, for: .normal)
            btn.tintColor = specialKeyTextColor
            btn.layer.shadowColor = keyShadowColor.cgColor
            btn.layer.shadowOpacity = keyShadowOpacity
        }

        if isShifted || isCapsLock {
            shiftButton?.backgroundColor = isDarkMode ? UIColor(white: 0.90, alpha: 1.0) : UIColor.white
            shiftButton?.tintColor = UIColor.black
        }
    }

    private func showDefaultAssistantPrompt() {
        clearSuggestions()
        setLogoState(mode: .clean)

        checkClipboardForApiKey()

        if !hasFullAccess {
            let label = UILabel()
            label.text = "⚠️ Enable 'Allow Full Access' in iOS Settings"
            label.textColor = UIColor.systemYellow
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            suggestionsStackView.addArrangedSubview(label)
        } else {
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
            grammarlyLogoButton.backgroundColor = grammarlyGreen
            grammarlyStatusBadge.isHidden = true
        case .checking:
            grammarlyLogoButton.setTitle("", for: .normal)
            grammarlyLogoButton.backgroundColor = grammarlyGreen
            activitySpinner.startAnimating()
            grammarlyStatusBadge.isHidden = true
        case .errors(let count):
            activitySpinner.stopAnimating()
            grammarlyLogoButton.setTitle("G", for: .normal)
            grammarlyLogoButton.backgroundColor = grammarlyGreen
            grammarlyStatusBadge.text = "\(count)"
            grammarlyStatusBadge.isHidden = false
        case .offline:
            activitySpinner.stopAnimating()
            grammarlyLogoButton.setTitle("!", for: .normal)
            grammarlyLogoButton.backgroundColor = UIColor.systemOrange
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

    // MARK: - 100% Authentic iOS Keypad Builder (Mathematical Alignment)
    private func buildKeys() {
        normalButtons.removeAll()
        specialButtons.removeAll()
        shiftButton = nil

        for subview in keyboardView.subviews {
            subview.removeFromSuperview()
        }

        let isUpper = isShifted || isCapsLock
        let row1Keys: [String]
        let row2Keys: [String]
        let row3Keys: [String]

        if isSymbolMode {
            if isAltSymbolMode {
                row1Keys = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
                row2Keys = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
                row3Keys = [".", ",", "?", "!", "'"]
            } else {
                row1Keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
                row2Keys = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
                row3Keys = [".", ",", "?", "!", "'"]
            }
        } else {
            row1Keys = isUpper ? ["Q","W","E","R","T","Y","U","I","O","P"] : ["q","w","e","r","t","y","u","i","o","p"]
            row2Keys = isUpper ? ["A","S","D","F","G","H","J","K","L"] : ["a","s","d","f","g","h","j","k","l"]
            row3Keys = isUpper ? ["Z","X","C","V","B","N","M"] : ["z","x","c","v","b","n","m"]
        }

        let mainStack = UIStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.distribution = .fillEqually
        mainStack.spacing = 10 // Exact Apple vertical row gap!
        keyboardView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: 4),
            mainStack.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -4),
            mainStack.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 3),
            mainStack.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -3)
        ])

        // --- ROW 1 (10 Keys) ---
        let row1Stack = UIStackView()
        row1Stack.axis = .horizontal
        row1Stack.distribution = .fillEqually
        row1Stack.spacing = 6
        var row1KeyViews: [UIButton] = []
        for key in row1Keys {
            let btn = createNormalKey(title: key)
            row1Stack.addArrangedSubview(btn)
            row1KeyViews.append(btn)
        }
        mainStack.addArrangedSubview(row1Stack)

        guard let sampleKey = row1KeyViews.first else { return }

        // --- ROW 2 (9 Keys Centered with Sub-Pixel Apple Precision) ---
        let row2Stack = UIStackView()
        row2Stack.axis = .horizontal
        row2Stack.spacing = 6

        if !isSymbolMode {
            // Left spacer: exactly (keyWidth + 6.0) / 2.0 so 'A' is centered under 'Q'-'W' gap
            let leftSpacer = UIView()
            leftSpacer.translatesAutoresizingMaskIntoConstraints = false
            let rightSpacer = UIView()
            rightSpacer.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                leftSpacer.widthAnchor.constraint(equalTo: sampleKey.widthAnchor, multiplier: 0.5, constant: 3.0),
                rightSpacer.widthAnchor.constraint(equalTo: leftSpacer.widthAnchor)
            ])
            row2Stack.addArrangedSubview(leftSpacer)

            for key in row2Keys {
                let btn = createNormalKey(title: key)
                btn.translatesAutoresizingMaskIntoConstraints = false
                btn.widthAnchor.constraint(equalTo: sampleKey.widthAnchor).isActive = true
                row2Stack.addArrangedSubview(btn)
            }
            row2Stack.addArrangedSubview(rightSpacer)
        } else {
            // Symbol mode: 10 equal keys
            row2Stack.distribution = .fillEqually
            for key in row2Keys {
                let btn = createNormalKey(title: key)
                row2Stack.addArrangedSubview(btn)
            }
        }
        mainStack.addArrangedSubview(row2Stack)

        // --- ROW 3 (Shift, Keys, Delete) ---
        let row3Stack = UIStackView()
        row3Stack.axis = .horizontal
        row3Stack.spacing = 6

        // Left Key (Shift or Symbol mode switch)
        let leftBtn: UIButton
        if isSymbolMode {
            leftBtn = createSpecialKey(title: isAltSymbolMode ? "123" : "#+=")
            leftBtn.addTarget(self, action: #selector(toggleAltSymbolMode), for: .touchUpInside)
        } else {
            let shiftIcon = isCapsLock ? "capslock.fill" : (isShifted ? "shift.fill" : "shift")
            leftBtn = createSpecialKey(systemImage: shiftIcon)
            leftBtn.addTarget(self, action: #selector(toggleShift), for: .touchUpInside)
            self.shiftButton = leftBtn
            if isUpper {
                leftBtn.backgroundColor = isDarkMode ? UIColor(white: 0.90, alpha: 1.0) : UIColor.white
                leftBtn.tintColor = .black
            }
        }
        leftBtn.translatesAutoresizingMaskIntoConstraints = false
        // Exactly 1.5 * keyWidth + 3.0 so 'Z' sits directly under 'S'!
        leftBtn.widthAnchor.constraint(equalTo: sampleKey.widthAnchor, multiplier: 1.5, constant: 3.0).isActive = true
        row3Stack.addArrangedSubview(leftBtn)

        if !isSymbolMode {
            for key in row3Keys {
                let btn = createNormalKey(title: key)
                btn.translatesAutoresizingMaskIntoConstraints = false
                btn.widthAnchor.constraint(equalTo: sampleKey.widthAnchor).isActive = true
                row3Stack.addArrangedSubview(btn)
            }
        } else {
            let midStack = UIStackView()
            midStack.axis = .horizontal
            midStack.distribution = .fillEqually
            midStack.spacing = 6
            for key in row3Keys {
                let btn = createNormalKey(title: key)
                midStack.addArrangedSubview(btn)
            }
            row3Stack.addArrangedSubview(midStack)
        }

        // Right Key (Delete / Backspace)
        let deleteBtn = createSpecialKey(systemImage: "delete.left.fill")
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        deleteBtn.widthAnchor.constraint(equalTo: leftBtn.widthAnchor).isActive = true
        deleteBtn.addTarget(self, action: #selector(deleteTouchDown), for: .touchDown)
        deleteBtn.addTarget(self, action: #selector(deleteTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        row3Stack.addArrangedSubview(deleteBtn)

        mainStack.addArrangedSubview(row3Stack)

        // --- ROW 4 (123/ABC, Globe, Space, Return) ---
        let row4Stack = UIStackView()
        row4Stack.axis = .horizontal
        row4Stack.spacing = 6

        let modeBtn = createSpecialKey(title: isSymbolMode ? "ABC" : "123")
        modeBtn.translatesAutoresizingMaskIntoConstraints = false
        modeBtn.widthAnchor.constraint(equalTo: leftBtn.widthAnchor, multiplier: 0.88).isActive = true
        modeBtn.addTarget(self, action: #selector(toggleSymbolMode), for: .touchUpInside)
        row4Stack.addArrangedSubview(modeBtn)

        let globeBtn = createSpecialKey(systemImage: "globe")
        globeBtn.translatesAutoresizingMaskIntoConstraints = false
        globeBtn.widthAnchor.constraint(equalTo: leftBtn.widthAnchor, multiplier: 0.80).isActive = true
        globeBtn.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        row4Stack.addArrangedSubview(globeBtn)

        let spaceBtn = createNormalKey(title: "space")
        spaceBtn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        spaceBtn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spaceBtn.addTarget(self, action: #selector(handleSpaceTouchDown), for: .touchDown)
        spaceBtn.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        row4Stack.addArrangedSubview(spaceBtn)

        let returnBtn = createSpecialKey(title: "return")
        returnBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        returnBtn.translatesAutoresizingMaskIntoConstraints = false
        returnBtn.widthAnchor.constraint(equalTo: leftBtn.widthAnchor, multiplier: 1.55).isActive = true
        returnBtn.addTarget(self, action: #selector(handleReturnTouchDown), for: .touchDown)
        returnBtn.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        row4Stack.addArrangedSubview(returnBtn)

        mainStack.addArrangedSubview(row4Stack)
    }

    // MARK: - Key Factory Methods
    private func createNormalKey(title: String) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(normalKeyTextColor, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 23, weight: .regular)
        btn.backgroundColor = normalKeyColor
        
        // Exact Apple Continuous Squircle Corners
        btn.layer.cornerRadius = 5.0
        btn.layer.cornerCurve = .continuous
        
        // Crisp 1-pixel bottom 3D shadow
        btn.layer.masksToBounds = false
        btn.layer.shadowColor = keyShadowColor.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1.0)
        btn.layer.shadowOpacity = keyShadowOpacity
        btn.layer.shadowRadius = 0.0

        btn.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        btn.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)

        normalButtons.append(btn)
        return btn
    }

    private func createSpecialKey(title: String? = nil, systemImage: String? = nil) -> UIButton {
        let btn = UIButton(type: .custom)
        if let title = title {
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(specialKeyTextColor, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 15.5, weight: .regular)
        }
        if let systemImage = systemImage {
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            let img = UIImage(systemName: systemImage, withConfiguration: config)
            btn.setImage(img, for: .normal)
            btn.tintColor = specialKeyTextColor
        }
        btn.backgroundColor = specialKeyColor
        
        btn.layer.cornerRadius = 5.0
        btn.layer.cornerCurve = .continuous
        btn.layer.masksToBounds = false
        btn.layer.shadowColor = keyShadowColor.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1.0)
        btn.layer.shadowOpacity = keyShadowOpacity
        btn.layer.shadowRadius = 0.0

        btn.addTarget(self, action: #selector(specialKeyTouchDown(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(specialKeyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        specialButtons.append(btn)
        return btn
    }

    // MARK: - Key Events & Feedback
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
        if (isShifted || isCapsLock) && sender == shiftButton {
            sender.backgroundColor = isDarkMode ? UIColor(white: 0.90, alpha: 1.0) : UIColor.white
            sender.tintColor = .black
        } else {
            sender.backgroundColor = specialKeyColor
            sender.tintColor = specialKeyTextColor
        }
    }

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
        if let custom = UserDefaults.standard.string(forKey: "custom_gemini_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), custom.count > 25 {
            return custom
        }
        if let shared = UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: "@writing_assistant_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), shared.count > 25 {
            return shared
        }
        return defaultApiKey
    }

    private func analyzeText(_ sentence: String) {
        setLogoState(mode: .checking)

        let localSuggestions = checkOfflineSpelling(in: sentence)

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

        // 2. Individual Grammarly Suggestion Cards
        for item in suggestions {
            addSuggestionCard(original: item.original, replacement: item.replacement)
        }
    }

    private func addTonePill(title: String, tone: String? = nil, isStatic: Bool = false) {
        let pill = UIButton(type: .custom)
        pill.setTitle(title, for: .normal)
        pill.setTitleColor(isStatic ? grammarlyGreen : (isDarkMode ? UIColor(white: 0.88, alpha: 1.0) : UIColor(white: 0.20, alpha: 1.0)), for: .normal)
        pill.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: isStatic ? .bold : .medium)
        pill.backgroundColor = isStatic ? grammarlyGreen.withAlphaComponent(0.15) : (isDarkMode ? UIColor(white: 0.22, alpha: 1.0) : UIColor.white)
        pill.layer.cornerRadius = 13
        pill.layer.borderWidth = 0.8
        pill.layer.borderColor = isStatic ? grammarlyGreen.withAlphaComponent(0.4).cgColor : (isDarkMode ? UIColor(white: 0.32, alpha: 1.0).cgColor : UIColor(white: 0.80, alpha: 1.0).cgColor)
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
        card.backgroundColor = isDarkMode ? UIColor(red: 0.18, green: 0.20, blue: 0.25, alpha: 1.0) : UIColor.white
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
