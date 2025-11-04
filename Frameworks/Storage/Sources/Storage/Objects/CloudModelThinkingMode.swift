//
//  CloudModelThinkingMode.swift
//  Storage
//
//  Created by Willow Zhang on 11/2/25.
//

import Foundation
import WCDBSwift

public enum CloudModelThinkingMode: Equatable, Hashable, Codable {
    case disabled
    case extraField(key: String, value: Value)

    public enum Value: Equatable, Hashable, Codable {
        case bool(Bool)
        case string(String)
        case dictionary([String: Value])

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let boolValue = try? container.decode(Bool.self) {
                self = .bool(boolValue)
            } else if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let dictValue = try? container.decode([String: Value].self) {
                self = .dictionary(dictValue)
            } else {
                self = .dictionary([:])
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .bool(value):
                try container.encode(value)
            case let .string(value):
                try container.encode(value)
            case let .dictionary(value):
                try container.encode(value)
            }
        }
    }
}

public extension CloudModelThinkingMode {
    static var disabledMode: CloudModelThinkingMode { .disabled }

    static var enableThinkingFlag: CloudModelThinkingMode {
        .extraField(key: "enable_thinking", value: .bool(true))
    }

    static var thinkingModeDictionary: CloudModelThinkingMode {
        .extraField(key: "thinking_mode", value: .dictionary(["type": .string("enabled")]))
    }

    static var reasoningDictionary: CloudModelThinkingMode {
        .extraField(key: "reasoning", value: .dictionary(["enabled": .bool(true)]))
    }

    func mergedPayload() -> [String: Any] {
        switch self {
        case .disabled:
            [:]
        case let .extraField(key, value):
            [key: value.toJSONObject()]
        }
    }
}

public extension CloudModelThinkingMode {
    var supportsReasoningEffort: Bool {
        switch self {
        case .extraField(key: "reasoning", value: .dictionary):
            true
        default:
            false
        }
    }

    var supportsThinkingBudget: Bool {
        switch self {
        case .extraField(key: "enable_thinking", value: .bool):
            true
        case .extraField(key: "thinking_mode", value: .dictionary):
            true
        default:
            false
        }
    }
}

extension CloudModelThinkingMode.Value {
    func toJSONObject() -> Any {
        switch self {
        case let .bool(value):
            return value
        case let .string(value):
            return value
        case let .dictionary(dict):
            var json: [String: Any] = [:]
            for (key, value) in dict {
                json[key] = value.toJSONObject()
            }
            return json
        }
    }
}

extension CloudModelThinkingMode: ColumnCodable {
    public init?(with value: WCDBSwift.Value) {
        let text = value.stringValue
        guard let data = text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(CloudModelThinkingMode.self, from: data)
        else {
            self = .disabled
            return
        }
        self = decoded
    }

    public func archivedValue() -> WCDBSwift.Value {
        guard let data = try? JSONEncoder().encode(self),
              let text = String(data: data, encoding: .utf8)
        else {
            return .init("")
        }
        return .init(text)
    }

    public static var columnType: ColumnType {
        .text
    }
}
