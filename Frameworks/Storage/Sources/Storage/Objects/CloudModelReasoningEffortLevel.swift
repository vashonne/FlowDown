//
//  CloudModelReasoningEffortLevel.swift
//  Storage
//
//  Created by Willow Zhang on 11/2/25.
//

import Foundation
import WCDBSwift

public enum CloudModelReasoningEffortLevel: String, CaseIterable, Codable {
    case minimal
    case low
    case medium
    case high

    public static var defaultLevel: CloudModelReasoningEffortLevel { .high }

    public var thinkingBudgetTokens: Int {
        switch self {
        case .minimal: 512
        case .low: 1024
        case .medium: 4096
        case .high: 8192
        }
    }

    public var rawIdentifier: String { rawValue }
}

extension CloudModelReasoningEffortLevel: ColumnCodable {
    public init?(with value: WCDBSwift.Value) {
        let text = value.stringValue
        guard let level = CloudModelReasoningEffortLevel(rawValue: text) else {
            self = .defaultLevel
            return
        }
        self = level
    }

    public func archivedValue() -> WCDBSwift.Value {
        .init(rawValue)
    }

    public static var columnType: ColumnType {
        .text
    }
}
