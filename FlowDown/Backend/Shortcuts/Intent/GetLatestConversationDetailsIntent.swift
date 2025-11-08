import AppIntents
import Foundation

struct GetLatestConversationDetailsIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Fetch Last Conversation"
    }

    static var description: IntentDescription {
        "Return the full document of the most recent conversation"
    }

    static var authenticationPolicy: IntentAuthenticationPolicy {
        .requiresAuthentication
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Fetch the latest conversation details")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let transcript = try ShortcutUtilities.latestConversationTranscript()
        let dialog = IntentDialog(.init(stringLiteral: transcript))
        return .result(value: transcript, dialog: dialog)
    }
}
