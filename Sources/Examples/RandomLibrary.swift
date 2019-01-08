import Metrics

class RandomLibrary {
    let methodCallsCounter = Metrics.global.makeCounter(label: "RandomLibrary::TotalMethodCalls")

    func doSomething() {
        self.methodCallsCounter.increment()
    }

    func doSomethingSlow(callback: @escaping () -> Void) {
        self.methodCallsCounter.increment()
        Metrics.global.withTimer(label: "RandomLibrary::doSomethingSlow") { timer in
            let start = Date()
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int.random(in: 5 ... 500))) {
                timer.record(Date().timeIntervalSince(start))
                callback()
            }
        }
    }
}
