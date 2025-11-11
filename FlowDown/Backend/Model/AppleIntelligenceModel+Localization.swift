import ChatClientKit
import Foundation

extension AppleIntelligenceModel {
    var availabilityStatus: String {
        switch availabilityState {
        case .available:
            return String(localized: "Available")
        case let .unavailable(reason):
            return status(for: reason)
        }
    }

    var availabilityDescription: String.LocalizationValue {
        switch availabilityState {
        case .available:
            return "Apple Intelligence is available and ready to use on this device."
        case let .unavailable(reason):
            return description(for: reason)
        }
    }

    var modelDisplayName: String {
        String(localized: canonicalName)
    }

    private func status(for rawReason: String) -> String {
        let lowered = rawReason.lowercased()
        if lowered.contains("appleintelligencenotenabled") {
            return String(localized: "Apple Intelligence Not Enabled")
        }
        if lowered.contains("devicenoteligible") {
            return String(localized: "Device Not Eligible")
        }
        if lowered.contains("modelnotready") {
            return String(localized: "Model Not Ready")
        }
        if rawReason == AppleIntelligenceModel.frameworkUnavailableReason {
            return String(localized: "Requires iOS 26+")
        }
        return String(localized: "Unavailable: \(rawReason)")
    }

    private func description(for rawReason: String) -> String.LocalizationValue {
        let lowered = rawReason.lowercased()
        if lowered.contains("appleintelligencenotenabled") {
            return "Apple Intelligence is not enabled. Check your device settings."
        }
        if lowered.contains("devicenoteligible") {
            return "This device is not eligible for Apple Intelligence. Requires compatible hardware."
        }
        if lowered.contains("modelnotready") {
            return "Apple Intelligence model is not ready. Try again later."
        }
        if rawReason == AppleIntelligenceModel.frameworkUnavailableReason {
            return "Apple Intelligence requires iOS 26 or later."
        }
        return "Apple Intelligence is unavailable: \(rawReason)"
    }
}

