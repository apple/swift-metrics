# ``CoreMetrics/NOOPMetricsHandler``

## Topics

### Inspecting the handler

- ``instance``

### Creating handlers

- ``makeCounter(label:dimensions:)``
- ``makeFloatingPointCounter(label:dimensions:)``
- ``makeMeter(label:dimensions:)``
- ``makeTimer(label:dimensions:)``
- ``makeRecorder(label:dimensions:aggregate:)``

### No-op operatings

- ``increment(by:)-(Int64)``
- ``increment(by:)-(Double)``
- ``decrement(by:)``
- ``record(_:)-(Int64)``
- ``record(_:)-(Double)``
- ``recordNanoseconds(_:)``
- ``set(_:)-(Int64)``
- ``set(_:)-(Double)``
- ``reset()``

### Cleaning up handlers

- ``destroyCounter(_:)``
- ``destroyFloatingPointCounter(_:)``
- ``destroyMeter(_:)``
- ``destroyTimer(_:)``
- ``destroyRecorder(_:)``

