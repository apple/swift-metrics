# complete code
import XCTest
import Metrics

class StreamMetricsFactory {
    func createMetrics() -> TestMetrics {
        let metrics = TestMetrics()
        metrics.addMetric("http_requests", ["counter": Counter(label: "http_requests")])
        metrics.addMetric("http_requests:method=GET,status=200", ["counter": Counter(label: "http_requests", dimensions: ["method": "GET", "status": "200"])])
        return metrics
    }
}