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
        asJSON ? formatJSON(event: event) : formatText(event: event)
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

    private struct JSONOutput: Encodable {
        let activationType: String
        let activationAt: String
        var activationValue: String?
        var activationValueIndex: String?
        var deliveredAt: String?
    }

    private static func formatJSON(event: ActivationEvent) -> String {
        var output = JSONOutput(
            activationType: event.type.rawValue,
            activationAt: dateFormatter.string(from: event.activatedAt)
        )
        output.activationValue = event.value
        if let index = event.valueIndex {
            output.activationValueIndex = "\(index)"
        }
        if let delivered = event.deliveredAt {
            output.deliveredAt = dateFormatter.string(from: delivered)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(output),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}
