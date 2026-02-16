import Foundation

enum ActivationType: String {
    case closed
    case timeout
    case contentsClicked
    case actionClicked
    case replied
    case none
}

struct ActivationEvent {
    let type: ActivationType
    let value: String?
    let valueIndex: Int?
    let deliveredAt: Date?
    let activatedAt: Date
}

struct OutputFormatter {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return f
    }()

    static func format(event: ActivationEvent, asJSON: Bool) -> String {
        if asJSON {
            return formatJSON(event: event)
        } else {
            return formatText(event: event)
        }
    }

    private static func formatText(event: ActivationEvent) -> String {
        switch event.type {
        case .closed:
            if let value = event.value, !value.isEmpty {
                return value
            }
            return "@CLOSED"
        case .timeout:
            return "@TIMEOUT"
        case .contentsClicked:
            return "@CONTENTCLICKED"
        case .actionClicked, .replied:
            if let value = event.value, !value.isEmpty {
                return value
            }
            return "@ACTIONCLICKED"
        case .none:
            return "@NONE"
        }
    }

    private static func formatJSON(event: ActivationEvent) -> String {
        var dict: [String: Any] = [
            "activationType": event.type.rawValue,
            "activationAt": dateFormatter.string(from: event.activatedAt),
        ]
        if let value = event.value {
            dict["activationValue"] = value
        }
        if let index = event.valueIndex {
            dict["activationValueIndex"] = "\(index)"
        }
        if let delivered = event.deliveredAt {
            dict["deliveredAt"] = dateFormatter.string(from: delivered)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}
