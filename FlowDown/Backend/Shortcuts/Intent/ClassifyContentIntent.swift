import AppIntents
import Foundation

struct ClassifyContentIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Classify Content"
    }

    static var description: IntentDescription {
        "Use the model to classify content into one of the provided candidates. If the model cannot decide, the first candidate is returned."
    }

    @Parameter(title: "Content", requestValueDialog: "What content should be classified?")
    var content: String

    @Parameter(title: "Candidates", requestValueDialog: "Provide the candidate labels.")
    var candidates: [String]

    static var parameterSummary: some ParameterSummary {
        Summary("Classify the provided content using the candidate list") {
            \.$content
            \.$candidates
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let request = try ClassificationPromptBuilder.make(
            content: content,
            candidates: candidates,
            requireContent: true,
            includeImageInstruction: false
        )

        let response = try await InferenceIntentHandler.execute(
            model: nil,
            message: request.message,
            image: nil,
            options: .init(allowsImages: false)
        )

        let resolved = request.resolveCandidate(from: response)
        let dialog = IntentDialog(.init(stringLiteral: resolved))
        return .result(value: resolved, dialog: dialog)
    }
}

@available(iOS 18.0, macCatalyst 18.0, *)
struct ClassifyContentWithImageIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Classify Content with Image"
    }

    static var description: IntentDescription {
        "Use the model to classify content with the help of an accompanying image. If the model cannot decide, the first candidate is returned."
    }

    @Parameter(title: "Content", default: "", requestValueDialog: "Add any additional details for the classification.")
    var content: String

    @Parameter(title: "Image", supportedContentTypes: [.image], requestValueDialog: "Select an image to accompany the request.")
    var image: IntentFile

    @Parameter(title: "Candidates", requestValueDialog: "Provide the candidate labels.")
    var candidates: [String]

    static var parameterSummary: some ParameterSummary {
        Summary("Classify the provided image using the candidate list") {
            \.$content
            \.$image
            \.$candidates
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let request = try ClassificationPromptBuilder.make(
            content: content,
            candidates: candidates,
            requireContent: false,
            includeImageInstruction: true
        )

        let response = try await InferenceIntentHandler.execute(
            model: nil,
            message: request.message,
            image: image,
            options: .init(allowsImages: true)
        )

        let resolved = request.resolveCandidate(from: response)
        let dialog = IntentDialog(.init(stringLiteral: resolved))
        return .result(value: resolved, dialog: dialog)
    }
}

private enum ClassificationPromptBuilder {
    struct Request {
        let message: String
        let sanitizedCandidates: [String]
        let primaryCandidate: String

        func resolveCandidate(from response: String) -> String {
            if let label = response.extractXMLLabelValue() {
                let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
                if let matchedCandidate = sanitizedCandidates.first(where: {
                    $0.compare(normalizedLabel, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }) {
                    return matchedCandidate
                }
            }

            let normalized = response
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"'")))
                ?? ""

            return sanitizedCandidates.first {
                $0.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            } ?? primaryCandidate
        }
    }

    static func make(
        content: String,
        candidates: [String],
        requireContent: Bool,
        includeImageInstruction: Bool
    ) throws -> Request {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if requireContent, trimmedContent.isEmpty {
            throw ShortcutError.emptyMessage
        }

        let sanitizedCandidates = candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let primaryCandidate = sanitizedCandidates.first else {
            throw ShortcutError.invalidCandidates
        }

        let candidateList = sanitizedCandidates.enumerated()
            .map { index, value in
                "\(index + 1). \(value)"
            }
            .joined(separator: "\n")

        let baseInstruction = String(
            localized: "You are a classification assistant. Choose the best candidate for the provided content."
        )

        let imageInstruction = String(
            localized: "An image is provided with this request. Consider the visual details when selecting the candidate."
        )

        let candidateUsageInstruction = String(
            localized: "Select exactly one label from the candidate list."
        )

        let xmlOutputInstruction = String(
            localized: "Respond only with XML formatted as <classification><label>VALUE</label></classification>, replacing VALUE with a label from the candidate list."
        )

        let fallbackInstructionFormat = String(
            localized: "If you are unsure, use '%@' for VALUE."
        )
        let fallbackInstruction = String(format: fallbackInstructionFormat, primaryCandidate)

        var instructionSegments: [String] = [baseInstruction]

        if includeImageInstruction {
            instructionSegments.append(imageInstruction)
        }

        instructionSegments.append(candidateUsageInstruction)

        instructionSegments.append(String(localized: "Candidates:"))
        instructionSegments.append(candidateList)

        if !trimmedContent.isEmpty {
            instructionSegments.append(String(localized: "Content:"))
            instructionSegments.append(trimmedContent)
        }

        instructionSegments.append(xmlOutputInstruction)
        instructionSegments.append(fallbackInstruction)

        let message = instructionSegments.joined(separator: "\n\n")

        return Request(
            message: message,
            sanitizedCandidates: sanitizedCandidates,
            primaryCandidate: primaryCandidate
        )
    }
}

private extension String {
    func extractXMLLabelValue() -> String? {
        guard let labelStart = range(of: "<label>") else {
            return nil
        }

        let searchRange = labelStart.upperBound ..< endIndex
        guard let labelEnd = range(of: "</label>", range: searchRange) else {
            return nil
        }

        let valueRange = labelStart.upperBound ..< labelEnd.lowerBound
        return String(self[valueRange])
    }
}
