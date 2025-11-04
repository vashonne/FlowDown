//
//  CloudModelThinkingMode+Display.swift
//  FlowDown
//
//  Created by Willow Zhang on 11/2/25.
//

import Foundation
import Storage

extension CloudModelThinkingMode {
    var menuIconSystemName: String? {
        switch self {
        case .disabled:
            "xmark.circle"
        case .extraField(key: "enable_thinking", value: .bool):
            "1.circle"
        case .extraField(key: "thinking_mode", value: .dictionary):
            "2.circle"
        case .extraField(key: "reasoning", value: .dictionary):
            "3.circle"
        case .extraField:
            "questionmark.circle"
        }
    }
}
