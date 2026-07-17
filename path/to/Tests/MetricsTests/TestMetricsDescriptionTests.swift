# complete code
import XCTest
import Metrics
import MetricsTestKit

class TestMetricsDescriptionTests: XCTestCase {
    func testExpectCounter() {
        let metrics = StreamMetricsFactory().createMetrics()
        let counter = metrics.expectCounter("http_requests")
        XCTAssertNotNil(counter)
    }

    func testExpectCounterWithDimensions() {
        let metrics = StreamMetricsFactory().createMetrics()
        let counter = metrics.expectCounter("http_requests", dimensions: ["method": "GET", "status": "200"])
        XCTAssertNotNil(counter)
    }

    func testExpectTimer() {
        let metrics = StreamMetricsFactory().createMetrics()
        let timer = metrics.expectTimer("http_requests")
        XCTAssertNotNil(timer)
    }

    func testExpectTimerWithDimensions() {
        let metrics = StreamMetricsFactory().createMetrics()
        let timer = metrics.expectTimer("http_requests", dimensions: ["method": "GET", "status": "200"])
        XCTAssertNotNil(timer)
    }
}