//
//  JsonEditorController.swift
//  FlowDown
//
//  Created by Willow Zhang on 10/31/25.
//

import AlertController
import RunestoneEditor
import Storage
import UIKit

class JsonEditorController: CodeEditorController {
    private let showsThinkingMenu: Bool
    var onTextDidChange: ((String) -> Void)?

    init(text: String, showsThinkingMenu: Bool = false) {
        self.showsThinkingMenu = showsThinkingMenu
        super.init(language: "json", text: text)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.editorDelegate = self
        configureAccessoryMenuIfNeeded()
    }

    override func done() {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = "{}"
            onTextDidChange?(textView.text)
            super.done()
            return
        }
        guard let data = textView.text.data(using: .utf8) else {
            presentErrorAlert(message: "Unable to decode text into data.")
            return
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard object is [String: Any] else {
                throw NSError(
                    domain: "JSONValidation",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "JSON must be an object (dictionary), not an array or primitive.")]
                )
            }
            Logger.ui.infoFile("JsonEditorController done with valid JSON object")
        } catch {
            presentErrorAlert(message: "Unable to parse JSON: \(error.localizedDescription)")
            return
        }
        super.done()
    }

    private func presentErrorAlert(message: String) {
        let alert = AlertViewController(
            title: "Error",
            message: message
        ) { context in
            context.addAction(title: "OK", attribute: .accent) {
                context.dispose()
            }
        }
        present(alert, animated: true)
    }

    private func configureAccessoryMenuIfNeeded() {
        guard showsThinkingMenu else { return }

        let toggleTitle = String(localized: "Thinking Mode Presets")
        let menuProvider: () -> [UIMenuElement] = { [weak self] in
            guard let self else { return [] }
            return makeThinkingMenuElements()
        }

        #if targetEnvironment(macCatalyst)
            let toggleItem = UIBarButtonItem(
                image: UIImage(systemName: "sparkle.text.clipboard"),
                style: .plain,
                target: nil,
                action: nil
            )
        #else
            let toggleItem = UIBarButtonItem(
                title: toggleTitle,
                style: .plain,
                target: nil,
                action: nil
            )
            toggleItem.image = UIImage(systemName: "sparkle.text.clipboard")
        #endif

        toggleItem.accessibilityLabel = toggleTitle
        toggleItem.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { completion in
                completion(menuProvider())
            },
        ])

        if var items = navigationItem.rightBarButtonItems {
            items.append(toggleItem)
            navigationItem.rightBarButtonItems = items
        } else {
            navigationItem.rightBarButtonItems = [toggleItem]
        }
    }
}

extension JsonEditorController: TextViewDelegate {
    func textViewDidChange(_ textView: TextView) {
        onTextDidChange?(textView.text)
    }
}

// MARK: - Thinking Mode Helpers

private extension JsonEditorController {
    struct ThinkingMenuState {
        var thinkingMode: CloudModelThinkingMode
        var thinkingModeEnabled: Bool
        var thinkingModeEffortEnabled: Bool
        var thinkingModeEffort: CloudModelReasoningEffortLevel
        var thinkingModeBudgetOverride: Int?
    }

    func makeThinkingMenuElements() -> [UIMenuElement] {
        let state = currentThinkingMenuState()

        let presetMenu = UIMenu(
            title: String(localized: "Preset Plan"),
            image: UIImage(systemName: "sparkle.text.clipboard.fill"),
            options: [.displayInline],
            children: buildThinkingModeActions(from: state)
        )

        var elements: [UIMenuElement] = [presetMenu]

        if let budgetMenu = buildThinkingBudgetMenu(from: state) {
            elements.append(budgetMenu)
        }

        if let effortMenu = buildReasoningEffortMenu(from: state) {
            elements.append(effortMenu)
        }

        if elements.isEmpty {
            let placeholder = UIAction(title: String(localized: "(None)"), attributes: .disabled) { _ in }
            return [placeholder]
        }

        return elements
    }

    func currentThinkingMenuState() -> ThinkingMenuState {
        let draft = sanitizedText()
        var state = ThinkingMenuState(
            thinkingMode: .disabledMode,
            thinkingModeEnabled: false,
            thinkingModeEffortEnabled: false,
            thinkingModeEffort: .defaultLevel,
            thinkingModeBudgetOverride: nil
        )

        if let payload = ThinkingModeAnalyzer.payloadDictionary(from: draft),
           let detected = ThinkingModeAnalyzer.detectThinkingModePreset(
               in: payload,
               currentEffort: .defaultLevel
           )
        {
            state.thinkingMode = detected.mode
            state.thinkingModeEnabled = detected.enabled
            state.thinkingModeEffortEnabled = detected.effortEnabled
            if let level = detected.effortLevel {
                state.thinkingModeEffort = level
            }
            state.thinkingModeBudgetOverride = detected.budgetOverride
        }

        return state
    }

    func buildThinkingModeActions(from state: ThinkingMenuState) -> [UIAction] {
        let options: [(String.LocalizationValue, CloudModelThinkingMode)] = [
            (String.LocalizationValue("Disabled"), .disabled),
            (String.LocalizationValue("Enable Thinking Flag"), .enableThinkingFlag),
            (String.LocalizationValue("Thinking Mode Payload"), .thinkingModeDictionary),
            (String.LocalizationValue("Reasoning Payload"), .reasoningDictionary),
        ]

        let stateEnabled = state.thinkingModeEnabled
        let selectedMode: CloudModelThinkingMode = stateEnabled ? state.thinkingMode : .disabledMode

        return options.map { title, mode in
            let action = UIAction(
                title: String(localized: title),
                image: mode.menuIconSystemName.flatMap { UIImage(systemName: $0) }
            ) { [weak self] _ in
                self?.applyThinkingMode(mode)
            }

            let isOn: Bool = {
                if mode == .disabled {
                    return !stateEnabled
                }
                return stateEnabled && (mode == selectedMode)
            }()
            action.state = isOn ? .on : .off
            return action
        }
    }

    func buildThinkingBudgetMenu(from state: ThinkingMenuState) -> UIMenu? {
        let mode = state.thinkingModeEnabled ? state.thinkingMode : .disabledMode
        guard state.thinkingModeEnabled, mode.supportsThinkingBudget else { return nil }

        let isBudgetActive = state.thinkingModeEffortEnabled
        let currentLevel = state.thinkingModeEffort
        let overrideTokens = state.thinkingModeBudgetOverride

        var children: [UIMenuElement] = []

        let disabledAction = UIAction(title: String(localized: "Disabled")) { [weak self] _ in
            self?.setThinkingBudget(nil)
        }
        disabledAction.state = isBudgetActive ? .off : .on
        children.append(disabledAction)

        let levelActions = CloudModelReasoningEffortLevel.allCases.map { level -> UIAction in
            let titleFormat = String(localized: "%@ · %@ tokens")
            let title = String(format: titleFormat, level.displayTitle, "\(level.thinkingBudgetTokens)")
            let action = UIAction(title: title) { [weak self] _ in
                self?.setThinkingBudget(level.thinkingBudgetTokens)
            }
            let shouldHighlight = isBudgetActive && overrideTokens == nil && level == currentLevel
            action.state = shouldHighlight ? .on : .off
            return action
        }
        children.append(contentsOf: levelActions)

        let customAction = UIAction(title: String(localized: "Custom…")) { [weak self] _ in
            self?.promptForCustomBudget(currentLevel: currentLevel, overrideTokens: overrideTokens, isBudgetActive: isBudgetActive)
        }
        customAction.state = (isBudgetActive && overrideTokens != nil) ? .on : .off
        children.append(customAction)

        return UIMenu(
            title: String(localized: "Thinking Budget"),
            image: UIImage(systemName: "wallet.bifold"),
            options: [.displayInline],
            children: children
        )
    }

    func buildReasoningEffortMenu(from state: ThinkingMenuState) -> UIMenu? {
        let mode = state.thinkingModeEnabled ? state.thinkingMode : .disabledMode
        guard state.thinkingModeEnabled, mode.supportsReasoningEffort else { return nil }

        let isEnabled = state.thinkingModeEffortEnabled
        let currentLevel = state.thinkingModeEffort

        var children: [UIMenuElement] = []

        let disabledAction = UIAction(title: String(localized: "Disabled"), image: UIImage(systemName: "xmark")) { [weak self] _ in
            self?.setReasoningEffort(nil)
        }
        disabledAction.state = isEnabled ? .off : .on
        children.append(disabledAction)

        let levelActions = CloudModelReasoningEffortLevel.allCases.map { level -> UIAction in
            let action = UIAction(
                title: level.displayTitle,
                image: iconImage(for: level)
            ) { [weak self] _ in
                self?.setReasoningEffort(level)
            }
            action.state = (isEnabled && level == currentLevel) ? .on : .off
            return action
        }
        children.append(contentsOf: levelActions)

        return UIMenu(
            title: String(localized: "Reasoning Effort"),
            image: UIImage(systemName: "arrow.up.and.down.and.sparkles"),
            options: [.displayInline],
            children: children
        )
    }

    func applyThinkingMode(_ mode: CloudModelThinkingMode) {
        guard var body = editableJSONObjectOrPresentError(actionDescription: "apply the preset") else { return }
        clearThinkingRelatedFields(in: &body)

        guard mode != .disabled else {
            writeBody(body)
            return
        }

        body.mergeRecursively(with: mode.mergedPayload())

        if !mode.supportsThinkingBudget {
            body.removeValue(forKey: "thinking_budget")
        }

        if !mode.supportsReasoningEffort {
            stripReasoningEffort(from: &body)
        }

        writeBody(body)
    }

    func setThinkingBudget(_ tokens: Int?) {
        guard var body = editableJSONObjectOrPresentError(actionDescription: "update the thinking budget") else { return }
        if let value = tokens, value > 0 {
            body["thinking_budget"] = value
        } else {
            body.removeValue(forKey: "thinking_budget")
        }
        writeBody(body)
    }

    func setReasoningEffort(_ level: CloudModelReasoningEffortLevel?) {
        guard var body = editableJSONObjectOrPresentError(actionDescription: "update the reasoning effort") else { return }
        guard let level else {
            stripReasoningEffort(from: &body)
            writeBody(body)
            return
        }

        var reasoning = body["reasoning"] as? [String: Any] ?? [:]
        if reasoning["enabled"] == nil {
            reasoning["enabled"] = true
        }
        reasoning["effort"] = level.rawIdentifier
        body["reasoning"] = reasoning
        writeBody(body)
    }

    func promptForCustomBudget(currentLevel: CloudModelReasoningEffortLevel, overrideTokens: Int?, isBudgetActive: Bool) {
        let suggested = overrideTokens
            ?? (isBudgetActive ? currentLevel.thinkingBudgetTokens : nil)
            ?? CloudModelReasoningEffortLevel.defaultLevel.thinkingBudgetTokens

        let input = AlertInputViewController(
            title: "Custom Thinking Budget",
            message: "Set the thinking_budget tokens that will be merged into the request body.",
            placeholder: "\(suggested)",
            text: "\(suggested)"
        ) { [weak self] output in
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Int(trimmed), value > 0 else {
                return
            }
            self?.setThinkingBudget(value)
        }
        present(input, animated: true)
    }

    func sanitizedText() -> String {
        let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "{}" : textView.text
    }

    func currentJSONObject() -> [String: Any]? {
        let draft = sanitizedText()
        guard let data = draft.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json
    }

    func editableJSONObjectOrPresentError(actionDescription: String) -> [String: Any]? {
        guard let body = currentJSONObject() else {
            let format = String(localized: "Unable to %@ because the JSON payload is invalid. Please fix the syntax and try again.")
            let message = String(format: format, actionDescription)
            presentErrorAlert(message: message)
            return nil
        }
        return body
    }

    func clearThinkingRelatedFields(in body: inout [String: Any]) {
        let managedKeys: [String] = [
            "enable_thinking",
            "thinking_mode",
            "reasoning",
            "reasoning_effort",
            "thinking_budget",
        ]
        managedKeys.forEach { body.removeValue(forKey: $0) }
    }

    func iconImage(for level: CloudModelReasoningEffortLevel) -> UIImage? {
        guard let image = UIImage(systemName: level.menuIconSystemName) else { return nil }
        if level == .minimal {
            return image.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        }
        return image
    }

    func stripReasoningEffort(from body: inout [String: Any]) {
        if var reasoning = body["reasoning"] as? [String: Any] {
            reasoning.removeValue(forKey: "effort")
            if reasoning.isEmpty {
                body.removeValue(forKey: "reasoning")
            } else {
                body["reasoning"] = reasoning
            }
        } else {
            body.removeValue(forKey: "reasoning")
        }
    }

    func writeBody(_ body: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: body.isEmpty ? [:] : body, options: [.prettyPrinted]),
              let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        textView.text = text
        onTextDidChange?(text)
    }
}

// MARK: - Thinking Mode Analyzer

private enum ThinkingModeAnalyzer {
    struct Detection {
        let mode: CloudModelThinkingMode
        let enabled: Bool
        let effortEnabled: Bool
        let effortLevel: CloudModelReasoningEffortLevel?
        let budgetOverride: Int?
    }

    static func payloadDictionary(from text: String) -> [String: Any]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json
    }

    static func detectThinkingModePreset(
        in payload: [String: Any],
        currentEffort: CloudModelReasoningEffortLevel
    ) -> Detection? {
        if let reasoning = payload["reasoning"] as? [String: Any],
           isEnabledFlagTrue(reasoning["enabled"])
        {
            let effortValue = reasoning["effort"] as? String
            let level = effortValue.flatMap(CloudModelReasoningEffortLevel.init(rawValue:))
            let effortEnabled = level != nil
            return Detection(
                mode: .reasoningDictionary,
                enabled: true,
                effortEnabled: effortEnabled,
                effortLevel: level,
                budgetOverride: nil
            )
        }

        if let thinkingMode = payload["thinking_mode"] as? [String: Any],
           let type = (thinkingMode["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !type.isEmpty,
           type.lowercased() == "enabled"
        {
            if let tokens = parsePositiveInteger(from: payload["thinking_budget"]), tokens > 0 {
                let match = CloudModelReasoningEffortLevel.allCases.first { $0.thinkingBudgetTokens == tokens }
                let resolvedLevel = match ?? currentEffort
                let useOverride = match == nil
                return Detection(
                    mode: .thinkingModeDictionary,
                    enabled: true,
                    effortEnabled: true,
                    effortLevel: resolvedLevel,
                    budgetOverride: useOverride ? tokens : nil
                )
            }
            return Detection(
                mode: .thinkingModeDictionary,
                enabled: true,
                effortEnabled: false,
                effortLevel: nil,
                budgetOverride: nil
            )
        }

        if isEnabledFlagTrue(payload["enable_thinking"]) {
            if let tokens = parsePositiveInteger(from: payload["thinking_budget"]), tokens > 0 {
                let match = CloudModelReasoningEffortLevel.allCases.first { $0.thinkingBudgetTokens == tokens }
                let resolvedLevel = match ?? currentEffort
                let useOverride = match == nil
                return Detection(
                    mode: .enableThinkingFlag,
                    enabled: true,
                    effortEnabled: true,
                    effortLevel: resolvedLevel,
                    budgetOverride: useOverride ? tokens : nil
                )
            }
            return Detection(
                mode: .enableThinkingFlag,
                enabled: true,
                effortEnabled: false,
                effortLevel: nil,
                budgetOverride: nil
            )
        }

        return nil
    }

    static func isEnabledFlagTrue(_ value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            return (string as NSString).boolValue
        }
        return false
    }

    static func parsePositiveInteger(from value: Any?) -> Int? {
        guard let value else { return nil }
        if let number = value as? NSNumber {
            let intValue = number.intValue
            return intValue > 0 ? intValue : nil
        }
        if let string = value as? String,
           let intValue = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)),
           intValue > 0
        {
            return intValue
        }
        if let intValue = value as? Int, intValue > 0 {
            return intValue
        }
        return nil
    }
}

private extension [String: Any] {
    mutating func mergeRecursively(with other: [String: Any]) {
        for (key, value) in other {
            if var existing = self[key] as? [String: Any],
               let addition = value as? [String: Any]
            {
                existing.mergeRecursively(with: addition)
                self[key] = existing
            } else {
                self[key] = value
            }
        }
    }
}
