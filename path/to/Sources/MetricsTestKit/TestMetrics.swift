# complete code
import XCTest
import Metrics

class TestMetrics {
    private var metrics: [String: [String: Any]] = [:]

    func expectCounter(_ label: String, dimensions: [String: String] = [:]) -> Counter? {
        let key = createKey(label, dimensions)
        return metrics[key]?.first(where: { $0.key == "counter" })?.value as? Counter
    }

    func expectTimer(_ label: String, dimensions: [String: String] = [:]) -> Timer? {
        let key = createKey(label, dimensions)
        return metrics[key]?.first(where: { $0.key == "timer" })?.value as? Timer
    }

    private func createKey(_ label: String, _ dimensions: [String: String]) -> String {
        return "\(label):\(dimensions.map { "\($0.key)=\($0.value)" }.joined(separator: ","))"
    }

    func addMetric(_ key: String, _ value: Any) {
        metrics[key] = [value]
    }
}