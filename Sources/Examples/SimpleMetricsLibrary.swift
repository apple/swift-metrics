import Metrics

class SimpleMetricsLibrary: MetricsHandler {
    init() {}
    
    func makeCounter(label: String, dimensions: [(String, String)]) -> Counter {
        return ExampleCounter(label, dimensions)
    }
    
    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder {
        let maker:(String,  [(String, String)]) -> Recorder = aggregate ? ExampleRecorder.init : ExampleGauge.init
        return maker(label, dimensions)
    }
    
    func makeTimer(label: String, dimensions: [(String, String)]) -> Timer {
        return ExampleTimer(label, dimensions)
    }
    
    private class ExampleCounter: Counter {
        init(_: String, _: [(String, String)]) {}
        
        let lock = NSLock()
        var value: Int64 = 0
        func increment<DataType: BinaryInteger>(_ value: DataType) {
            self.lock.withLock {
                self.value += Int64(value)
            }
        }
    }
    
    private class ExampleRecorder: Recorder {
        init(_: String, _: [(String, String)]) {}
        
        private let lock = NSLock()
        var values = [(Int64, Double)]()
        func record<DataType: BinaryInteger>(_ value: DataType) {
            self.record(Double(value))
        }
        
        func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
            // this may loose percision, but good enough as an example
            let v = Double(value)
            // TODO: sliding window
            lock.withLock {
                values.append((Date().nanoSince1970, v))
                self._count += 1
                self._sum += v
                if 0 == self._min || v < self._min { self._min = v }
                if 0 == self._max || v > self._max { self._max = v }
            }
        }
        
        var _sum: Double = 0
        var sum: Double {
            return self.lock.withLock { _sum }
        }
        
        private var _count: Int = 0
        var count: Int {
            return self.lock.withLock { _count }
        }
        
        private var _min: Double = 0
        var min: Double {
            return self.lock.withLock { _min }
        }
        
        private var _max: Double = 0
        var max: Double {
            return self.lock.withLock { _max }
        }
    }
    
    private class ExampleGauge: Recorder {
        init(_: String, _: [(String, String)]) {}
        
        let lock = NSLock()
        var _value: Double = 0
        func record<DataType: BinaryInteger>(_ value: DataType) {
            self.record(Double(value))
        }
        
        func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
            // this may loose percision but good enough as an example
            self.lock.withLock { _value = Double(value) }
        }
    }
    
    private class ExampleTimer: ExampleRecorder, Timer {
        func recordNanoseconds(_ duration: Int64) {
            super.record(duration)
        }
    }
}

private extension Foundation.Date {
    var nanoSince1970: Int64 {
        return Int64(self.timeIntervalSince1970 * 1_000_000_000)
    }
}

private extension Foundation.NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}
