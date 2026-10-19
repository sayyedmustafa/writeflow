import SwiftUI
import UIKit

struct SuggestionItem: Identifiable {
    let id = UUID()
    let original: String
    let replacement: String
    let category: String // "Correctness", "Clarity", "Tone"
    let explanation: String
}

struct SentenceSegment: Identifiable {
    let id = UUID()
    let text: String
    let isCorrect: Bool
    let suggestion: String?
}

struct ContentView: View {
    @State private var textInput: String = "how the fuck you wan this?"
    @State private var suggestions: [SuggestionItem] = []
    @State private var segments: [SentenceSegment] = []
    @State private var fullSentenceFix: String? = nil
    @State private var isAnalyzing: Bool = false
    @State private var performanceScore: Int = 85
    @State private var correctnessCount: Int = 0
    @State private var clarityCount: Int = 0
    @State private var deliveryCount: Int = 0
    @State private var selectedTone: String = "Professional"
    @State private var apiKey: String = ""
    @State private var apiKeyStatus: String? = nil
    @State private var isTestingApiKey: Bool = false
    @State private var debounceTimer: Timer? = nil
    @State private var showCopiedAlert: Bool = false
    
    // Obfuscated default verified working key
    private let defaultApiKey = String(decoding: Data(base64Encoded: "QVEuQWI4Uk42SmNMSGRIUjROc2cxbjQyOUxjUmRaUzMtcENZRVQ3clJVdERXTW92WkpaQVE=") ?? Data(), as: UTF8.self)
    private let appGroupSuite = "group.com.sayyedmustafa.writeflow"
    private let primaryEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent"
    
    // Grammarly Brand Colors
    private let grammarlyGreen = Color(red: 0.08, green: 0.76, blue: 0.55)
    private let grammarlyCoral = Color(red: 0.98, green: 0.38, blue: 0.38)
    private let grammarlyBlue = Color(red: 0.15, green: 0.55, blue: 0.98)
    private let darkBackground = Color(red: 0.08, green: 0.09, blue: 0.12)
    private let cardBackground = Color(red: 0.13, green: 0.15, blue: 0.20)
    
    let tones = ["Professional", "Casual", "Academic", "Creative"]
    
    var body: some View {
        NavigationView {
            ZStack {
                darkBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        // 1. Grammarly Performance Dashboard Card
                        performanceDashboard
                        
                        // 2. 1-Tap "Accept All" Action Button (If mistakes exist)
                        if let fix = fullSentenceFix, !suggestions.isEmpty, fix != textInput {
                            acceptAllBanner(fix: fix)
                        }
                        
                        // 3. Grammarly Live Document Editor
                        documentEditorSection
                        
                        // 4. Detailed Grammarly Suggestion Cards
                        suggestionsCardsSection
                        
                        // 5. Writing Tone Selector
                        toneSelectorSection
                        
                        // 6. User Gemini API Key & Direct Integration Card
                        apiKeySection
                        
                        // 7. Systemwide Keyboard Activation Instructions
                        keyboardGuideCard
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        // Circular Grammarly Logo Badge
                        ZStack {
                            Circle()
                                .fill(grammarlyGreen)
                                .frame(width: 26, height: 26)
                            Text("G")
                                .font(.system(size: 15, weight: .black))
                                .foregroundColor(.white)
                        }
                        Text("Grammarly AI")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(suggestions.isEmpty ? grammarlyGreen : grammarlyCoral)
                            .frame(width: 8, height: 8)
                        Text(suggestions.isEmpty ? "All Good" : "\(suggestions.count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(suggestions.isEmpty ? grammarlyGreen : grammarlyCoral)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.16))
                    .cornerRadius(12)
                }
            }
        }
        .onAppear {
            loadSavedKey()
            analyzeGrammar()
        }
    }
    
    // MARK: - Grammarly Performance Dashboard
    private var performanceDashboard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                // Score Circle
                ZStack {
                    Circle()
                        .stroke(Color(white: 0.2), lineWidth: 5)
                        .frame(width: 58, height: 58)
                    Circle()
                        .trim(from: 0, to: CGFloat(performanceScore) / 100.0)
                        .stroke(suggestions.isEmpty ? grammarlyGreen : grammarlyCoral, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 58, height: 58)
                    Text("\(performanceScore)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestions.isEmpty ? "Great writing! No issues found." : "\(suggestions.count) issues need your review")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(suggestions.isEmpty ? "Grammar, spelling, and tone are on point." : "Tap cards below to accept one-click corrections.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            
            Divider().background(Color(white: 0.2))
            
            // 3 Grammarly Pillars: Correctness, Clarity, Delivery
            HStack(spacing: 10) {
                pillarBadge(title: "Correctness", count: correctnessCount, color: grammarlyCoral, icon: "checkmark.circle.fill")
                pillarBadge(title: "Clarity", count: clarityCount, color: grammarlyBlue, icon: "sparkles")
                pillarBadge(title: "Tone", count: deliveryCount, color: Color.purple, icon: "person.wave.2.fill")
            }
        }
        .padding(14)
        .background(cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(suggestions.isEmpty ? grammarlyGreen.opacity(0.3) : grammarlyCoral.opacity(0.4), lineWidth: 1.2)
        )
    }
    
    private func pillarBadge(title: String, count: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(count > 0 ? color : Color.gray)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(count > 0 ? "\(count) issue\(count > 1 ? "s" : "")" : "Clean")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(count > 0 ? color : Color.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(white: 0.10))
        .cornerRadius(8)
    }
    
    // MARK: - 1-Tap "Accept All" Banner
    private func acceptAllBanner(fix: String) -> some View {
        Button(action: {
            textInput = fix
            analyzeGrammar()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accept All Corrections (1-Tap)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(fix)
                        .font(.caption)
                        .lineLimit(1)
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(grammarlyGreen)
            .cornerRadius(12)
            .shadow(color: grammarlyGreen.opacity(0.3), radius: 6, y: 3)
        }
    }
    
    // MARK: - Document Editor
    private var documentEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DOCUMENT EDITOR")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
                if isAnalyzing {
                    HStack(spacing: 4) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: grammarlyGreen)).scaleEffect(0.7)
                        Text("Proofreading...")
                            .font(.caption2)
                            .foregroundColor(grammarlyGreen)
                    }
                } else {
                    Text("\(textInput.split(separator: " ").count) words")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            TextEditor(text: $textInput)
                .frame(minHeight: 110)
                .padding(10)
                .background(Color(white: 0.10))
                .foregroundColor(.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(white: 0.22), lineWidth: 1)
                )
                .onChange(of: textInput) { _ in
                    debounceTimer?.invalidate()
                    debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { _ in
                        analyzeGrammar()
                    }
                }
        }
    }
    
    // MARK: - Detailed Suggestion Cards
    private var suggestionsCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !suggestions.isEmpty {
                Text("SUGGESTIONS (\(suggestions.count))")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                ForEach(suggestions) { item in
                    suggestionCard(item: item)
                }
            } else if !isAnalyzing {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(grammarlyGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Everything looks clear and correct!")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("No spelling, grammatical, or punctuation issues found.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(cardBackground)
                .cornerRadius(10)
            }
        }
    }
    
    private func suggestionCard(item: SuggestionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.category.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item.category == "Correctness" ? grammarlyCoral.opacity(0.2) : grammarlyBlue.opacity(0.2))
                    .foregroundColor(item.category == "Correctness" ? grammarlyCoral : grammarlyBlue)
                    .cornerRadius(4)
                Spacer()
                Button(action: {
                    dismissSuggestion(item)
                }) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // Flawed -> Replacement Preview
            HStack(spacing: 8) {
                Text(item.original)
                    .strikethrough(true, color: grammarlyCoral)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(grammarlyCoral)
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(item.replacement)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(grammarlyGreen)
                
                Spacer()
                
                Button(action: {
                    applySingleSuggestion(item)
                }) {
                    Text("Accept")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(grammarlyGreen)
                        .cornerRadius(14)
                }
            }
            
            if !item.explanation.isEmpty {
                Text(item.explanation)
                    .font(.caption)
                    .foregroundColor(Color(white: 0.75))
            }
        }
        .padding(12)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.22), lineWidth: 1)
        )
    }
    
    // MARK: - Tone Selector
    private var toneSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WRITING TONE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            HStack(spacing: 8) {
                ForEach(tones, id: \.self) { tone in
                    Button(action: {
                        selectedTone = tone
                        analyzeGrammar()
                    }) {
                        Text(tone)
                            .font(.caption)
                            .fontWeight(selectedTone == tone ? .bold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedTone == tone ? grammarlyGreen : Color(white: 0.16))
                            .foregroundColor(selectedTone == tone ? .white : Color(white: 0.8))
                            .cornerRadius(16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - API Key Section (Full User Freedom)
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.yellow)
                Text("GEMINI API KEY (YOUR KEY)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                if let status = apiKeyStatus {
                    Text(status)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(status.contains("Verified") ? grammarlyGreen : grammarlyCoral)
                }
            }
            
            SecureField("Paste your Google Gemini API key here", text: $apiKey)
                .padding(10)
                .background(Color(white: 0.10))
                .foregroundColor(.white)
                .cornerRadius(8)
            
            HStack(spacing: 10) {
                Button(action: {
                    testAndSaveApiKey()
                }) {
                    HStack(spacing: 4) {
                        if isTestingApiKey {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.7)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Save & Test Key")
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(grammarlyGreen)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    let keyToCopy = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultApiKey : apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    UIPasteboard.general.string = keyToCopy
                    showCopiedAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copy Key for Keyboard")
                    }
                    .font(.caption)
                    .foregroundColor(Color(white: 0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(white: 0.20))
                    .cornerRadius(8)
                }
            }
            
            Text("Tip: In the keyboard, tap '🔑 Use Copied Key' to activate your key everywhere in WhatsApp, Notes & Messages.")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(cardBackground)
        .cornerRadius(12)
        .alert(isPresented: $showCopiedAlert) {
            Alert(title: Text("API Key Copied!"), message: Text("Switch to WriteFlow keyboard in WhatsApp or any app and tap '🔑 Use Copied Key' to activate it."), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Keyboard Guide
    private var keyboardGuideCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "keyboard.fill")
                    .foregroundColor(grammarlyGreen)
                Text("HOW TO ACTIVATE GRAMMARLY KEYBOARD")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("1. Settings > General > Keyboard > Keyboards > Add WriteFlow\n2. Tap WriteFlow > Toggle 'Allow Full Access' ON\n3. Switch with 🌐 Globe icon in any app!")
                .font(.caption)
                .foregroundColor(Color(white: 0.8))
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open iPhone Settings")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(grammarlyGreen)
            }
        }
        .padding(14)
        .background(cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Logic & AI API Calls
    private func loadSavedKey() {
        if let custom = UserDefaults.standard.string(forKey: "custom_gemini_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), custom.count > 25 {
            self.apiKey = custom
        } else if let shared = UserDefaults(suiteName: appGroupSuite)?.string(forKey: "@writing_assistant_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), shared.count > 25 {
            self.apiKey = shared
        }
    }
    
    private func testAndSaveApiKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            apiKeyStatus = "Key cannot be empty"
            return
        }
        
        isTestingApiKey = true
        apiKeyStatus = "Testing..."
        
        guard let url = URL(string: "\(primaryEndpoint)?key=\(trimmed)") else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8.0
        
        let payload: [String: Any] = [
            "contents": [["parts": [["text": "ping"]]]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: req) { data, response, err in
            DispatchQueue.main.async {
                self.isTestingApiKey = false
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 {
                    self.apiKeyStatus = "Verified 🟢"
                    UserDefaults.standard.set(trimmed, forKey: "custom_gemini_api_key")
                    UserDefaults(suiteName: self.appGroupSuite)?.set(trimmed, forKey: "@writing_assistant_api_key")
                    self.analyzeGrammar()
                } else {
                    self.apiKeyStatus = "Invalid (HTTP \(code)) 🔴"
                }
            }
        }.resume()
    }
    
    private func applySingleSuggestion(_ item: SuggestionItem) {
        if let range = textInput.range(of: item.original, options: .caseInsensitive) {
            textInput.replaceSubrange(range, with: item.replacement)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            analyzeGrammar()
        }
    }
    
    private func dismissSuggestion(_ item: SuggestionItem) {
        suggestions.removeAll { $0.id == item.id }
        calculateScore()
    }
    
    private func calculateScore() {
        let errs = suggestions.count
        if errs == 0 {
            performanceScore = 100
        } else if errs == 1 {
            performanceScore = 90
        } else if errs == 2 {
            performanceScore = 80
        } else {
            performanceScore = max(40, 100 - (errs * 12))
        }
        correctnessCount = suggestions.filter { $0.category == "Correctness" }.count
        clarityCount = suggestions.filter { $0.category == "Clarity" }.count
        deliveryCount = suggestions.filter { $0.category == "Tone" }.count
    }
    
    private func analyzeGrammar() {
        guard !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            suggestions = []
            fullSentenceFix = nil
            performanceScore = 100
            return
        }
        
        isAnalyzing = true
        
        let keyToUse = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).count > 25 ? apiKey.trimmingCharacters(in: .whitespacesAndNewlines) : defaultApiKey
        guard let url = URL(string: "\(primaryEndpoint)?key=\(keyToUse)") else { return }
        
        let prompt = """
        You are a strict, world-class grammar proofreader like Grammarly.
        Analyze and proofread this text with a \(selectedTone) tone:
        "\(textInput)"

        Strict Instructions:
        1. Fix missing auxiliary verbs (e.g. "how you want" -> "how do you want").
        2. Fix typos, slang, and colloquial shorthand (e.g. "wan" -> "want").
        3. Fix capitalization (sentences must start with an uppercase letter).
        4. Preserve user intent/tone/profanity, but correct all grammar and spelling mistakes.
        5. If there are ANY typos, grammatical omissions, or errors, you MUST set "hasErrors": true.

        Return ONLY valid JSON:
        {
          "fullSentenceFix": "complete grammatically corrected text",
          "hasErrors": true,
          "suggestions": [
            {
              "original": "flawed phrase",
              "replacement": "corrected phrase",
              "category": "Correctness",
              "explanation": "brief grammatical reason"
            }
          ]
        }
        If completely flawless standard English, return: {"fullSentenceFix": "", "hasErrors": false, "suggestions": []}.
        """
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15.0
        
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
        
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: req) { data, response, err in
            DispatchQueue.main.async {
                self.isAnalyzing = false
            }
            
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            if let data = data, err == nil, httpStatus == 200,
               let parsed = self.parseGrammarData(data) {
                DispatchQueue.main.async {
                    self.fullSentenceFix = parsed.fullFix
                    self.suggestions = parsed.suggestions
                    self.calculateScore()
                }
            } else {
                // Local fallback check
                DispatchQueue.main.async {
                    let localItems = self.checkOfflineSpelling(in: self.textInput)
                    self.fullSentenceFix = nil
                    self.suggestions = localItems
                    self.calculateScore()
                }
            }
        }.resume()
    }
    
    private func parseGrammarData(_ data: Data) -> (fullFix: String?, suggestions: [SuggestionItem])? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { return nil }
        
        let textParts = parts.compactMap { $0["text"] as? String }
        let text = textParts.joined(separator: "\n")
        guard !text.isEmpty else { return nil }
        
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
        
        guard let innerData = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] else { return nil }
        
        let fullFix = dict["fullSentenceFix"] as? String
        var results: [SuggestionItem] = []
        
        if let rawList = dict["suggestions"] as? [[String: Any]] {
            for item in rawList {
                if let orig = item["original"] as? String,
                   let repl = item["replacement"] as? String,
                   !orig.isEmpty, orig.lowercased() != repl.lowercased() {
                    let cat = (item["category"] as? String) ?? "Correctness"
                    let expl = (item["explanation"] as? String) ?? ""
                    results.append(SuggestionItem(original: orig, replacement: repl, category: cat, explanation: expl))
                }
            }
        }
        
        return (fullFix: (fullFix?.isEmpty == false ? fullFix : nil), suggestions: results)
    }
    
    private func checkOfflineSpelling(in text: String) -> [SuggestionItem] {
        let checker = UITextChecker()
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        var results: [SuggestionItem] = []
        var offset = 0
        
        while offset < nsText.length {
            let searchRange = NSRange(location: offset, length: nsText.length - offset)
            let misspelled = checker.rangeOfMisspelledWord(in: text, range: searchRange, startingAt: offset, wrap: false, language: "en_US")
            if misspelled.location == NSNotFound { break }
            
            let badWord = nsText.substring(with: misspelled)
            if let guesses = checker.guesses(forWordRange: misspelled, in: text, language: "en_US"), let best = guesses.first {
                results.append(SuggestionItem(original: badWord, replacement: best, category: "Correctness", explanation: "Spelling correction"))
            }
            offset = misspelled.location + misspelled.length
        }
        return results
    }
}
