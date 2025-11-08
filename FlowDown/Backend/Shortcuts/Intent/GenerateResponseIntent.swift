import AppIntents
import ChatClientKit
import Foundation
import UIKit
import UniformTypeIdentifiers

struct GenerateResponseIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Generate Model Response"
    }

    static var description: IntentDescription {
        "Send a message and get the model's response."
    }

    @Parameter(title: "Model", default: nil, requestValueDialog: "Which model should answer?")
    var model: ShortcutsEntities.ModelEntity?

    @Parameter(title: "Message", requestValueDialog: "What do you want to ask?")
    var message: String

    @Parameter(title: "Save to Conversation", default: false)
    var saveToConversation: Bool

    @Parameter(title: "Enable Memory Tools", default: false)
    var enableMemory: Bool

    static var parameterSummary: some ParameterSummary {
        When(\.$model, .hasAnyValue) {
            Summary("Send your \(\.$message) with the selected model") {
                \.$model
                \.$message
                \.$saveToConversation
                \.$enableMemory
            }
        } otherwise: {
            Summary("Send your \(\.$message) with the default model") {
                \.$model
                \.$message
                \.$saveToConversation
                \.$enableMemory
            }
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let response = try await InferenceIntentHandler.execute(
            model: model,
            message: message,
            image: nil,
            options: .init(
                allowsImages: false,
                saveToConversation: saveToConversation,
                enableMemory: enableMemory
            )
        )
        let dialog = IntentDialog(.init(stringLiteral: response))
        return .result(value: response, dialog: dialog)
    }
}

@available(iOS 18.0, macCatalyst 18.0, *)
struct GenerateChatResponseWithImagesIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Generate Model Response with Image"
    }

    static var description: IntentDescription {
        "Send a message and get the model's response."
    }

    @Parameter(title: "Model", default: nil, requestValueDialog: "Which model should answer?")
    var model: ShortcutsEntities.ModelEntity?

    @Parameter(title: "Message", requestValueDialog: "What do you want to ask?")
    var message: String

    @Parameter(title: "Image", supportedContentTypes: [.image], requestValueDialog: "Select an image to include.")
    var image: IntentFile?

    @Parameter(title: "Save to Conversation", default: false)
    var saveToConversation: Bool

    @Parameter(title: "Enable Memory", default: false)
    var enableMemory: Bool

    static var parameterSummary: some ParameterSummary {
        When(\.$model, .hasAnyValue) {
            Summary("Send your message with the selected model and optional image") {
                \.$model
                \.$message
                \.$image
                \.$saveToConversation
                \.$enableMemory
            }
        } otherwise: {
            Summary("Send your message with the default model and optional image") {
                \.$model
                \.$message
                \.$image
                \.$saveToConversation
                \.$enableMemory
            }
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let response = try await InferenceIntentHandler.execute(
            model: model,
            message: message,
            image: image,
            options: .init(
                allowsImages: true,
                saveToConversation: saveToConversation,
                enableMemory: enableMemory
            )
        )
        let dialog = IntentDialog(.init(stringLiteral: response))
        return .result(value: response, dialog: dialog)
    }
}
