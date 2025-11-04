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
                intent: GenerateChatResponseWithToolsIntent(),
                phrases: [
                    "Ask Model with tools on \(.applicationName)",
                ],
                shortTitle: LocalizedStringResource("Ask Model + Tools", defaultValue: "Ask Model + Tools"),
                systemImageName: "hammer"
            ),
        ]

        if #available(iOS 18.0, macCatalyst 18.0, *) {
            shortcuts.append(contentsOf: [
                AppShortcut(
                    intent: GenerateChatResponseWithImagesIntent(),
                    phrases: [
                        "Ask Model with image on \(.applicationName)",
                    ],
                    shortTitle: LocalizedStringResource("Ask Model + Image", defaultValue: "Ask Model + Image"),
                    systemImageName: "photo"
                ),
                AppShortcut(
                    intent: GenerateChatResponseWithImagesAndToolsIntent(),
                    phrases: [
                        "Ask Model with image and tools on \(.applicationName)",
                    ],
                    shortTitle: LocalizedStringResource("Ask Model + Image + Tools", defaultValue: "Ask Model + Image + Tools"),
                    systemImageName: "photo.badge.checkmark"
                ),
            ])
        }

        return shortcuts
    }
}
