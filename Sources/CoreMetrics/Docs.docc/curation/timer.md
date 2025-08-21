# ``CoreMetrics/Timer``

## Topics

### Creating a timer

- ``init(label:dimensions:)``
- ``init(label:dimensions:preferredDisplayUnit:)``
- ``init(label:dimensions:factory:)``
- ``init(label:dimensions:preferredDisplayUnit:factory:)``
- ``init(label:dimensions:handler:)``
- ``init(label:dimensions:handler:factory:)``

### Updating a timer

- ``recordNanoseconds(_:)-(Int64)``
- ``recordNanoseconds(_:)-(DataType)``
- ``recordMicroseconds(_:)-3qrc6``
- ``recordMicroseconds(_:)-35aca``
- ``recordMilliseconds(_:)-6kuy8``
- ``recordMilliseconds(_:)-1eh0n``
- ``recordSeconds(_:)-7vp6b``
- ``recordSeconds(_:)-740dd``

### Inspecting a timer

- ``dimensions``
- ``label``

### Finalizing a timer

- ``destroy()``

