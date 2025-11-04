import AppIntents

struct FlowDownAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .lime }

    static var appShortcuts: [AppShortcut] {
        var shortcuts: [AppShortcut] = [
            AppShortcut(
                intent: GenerateChatResponseIntent(),
                phrases: [
                    "Ask Model on \(.applicationName)",
                ],
                shortTitle: LocalizedStringResource("Ask Model", defaultValue: "Ask Model"),
                systemImageName: "text.bubble"
            ),
            AppShortcut(
                intent: SetConversationModelIntent(),
                phrases: [
                    "Set conversation model on \(.applicationName)",
                    "Set default model on \(.applicationName)",
                ],
                shortTitle: LocalizedStringResource("Set Model", defaultValue: "Set Model"),
                systemImageName: "slider.horizontal.3"
            ),
        ]

        if #available(iOS 18.0, macCatalyst 18.0, *) {
            shortcuts.append(
                AppShortcut(
                    intent: GenerateChatResponseWithImagesIntent(),
                    phrases: [
                        "Ask Model with image on \(.applicationName)",
                    ],
                    shortTitle: LocalizedStringResource("Ask Model + Image", defaultValue: "Ask Model + Image"),
                    systemImageName: "photo"
                )
            )
        }

        return shortcuts
    }
}
