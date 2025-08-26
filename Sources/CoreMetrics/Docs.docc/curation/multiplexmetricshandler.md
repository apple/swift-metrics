# ``CoreMetrics/MultiplexMetricsHandler``

## Topics

### Creating a multiplex metrics handler

- ``init(factories:)``

### Creating handlers

- ``makeCounter(label:dimensions:)``
- ``makeFloatingPointCounter(label:dimensions:)``
- ``makeMeter(label:dimensions:)``
- ``makeTimer(label:dimensions:)``
- ``makeRecorder(label:dimensions:aggregate:)``

### Destroying handlers

- ``destroyCounter(_:)``
- ``destroyFloatingPointCounter(_:)``
- ``destroyMeter(_:)``
- ``destroyTimer(_:)``
- ``destroyRecorder(_:)``
