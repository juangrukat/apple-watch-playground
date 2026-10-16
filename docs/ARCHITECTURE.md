# Architecture

```text
Watch sensors → bounded SampleStore → latest pose + fair secondary queue
                                       ↓ Bluetooth or local HTTP
Mac transport decoder → Studio source/history store → instruments + responses
                                       ↑
                        acknowledged output commands
```

## Watch

- CaptureEngine: Core Motion capture away from view updates.
- SensorServices: optional microphone, Core Location, pedometer, altimeter and saved Health queries.
- SessionCore: bounded thread-safe storage, revisions, timestamps and runtime snapshots.
- PacketScheduler: latest-pose replacement, fair secondary feeds and source-time frames; no unbounded stale-sample backlog.
- BluetoothTransport / HTTPTransport: connection state, retry deadlines and transport work.
- WatchSession / WatchApp: session coordination and four-page SwiftUI interface.

## Mac

- BluetoothLink / Model: receive and validate frames; preserve source timestamps, freshness and raw units.
- CardModels: typed card settings, bounded timed history, mappings, preset definitions and tone generation.
- CapabilityCards / CardInstruments: source-specific visual instruments and physical Watch pose.
- ResponseEditor: optional creative mappings, thresholds and destinations.
- CardDragHandle / CanvasNavigator: native stable window-coordinate dragging and card reveal.
- PresetLibrary: additive/removable groups and recoverable saved presets.
- DiagnosticsViews / RuntimeMetrics / PoseMath: measured cadence/resources and quaternion math.

## Protocol notes

BLEWire and CommandWire are shared by both targets. The Watch is the Bluetooth central; the Mac advertises as peripheral. Controller frames contain quantized quaternion/acceleration with sequence/native-time fields. Secondary readings preserve source dates. Latest readings replace older pending ones; source freshness and connection contact are distinct.

Location uses speed/latitude/longitude plus a separate quality channel. Heading accuracy has its own small channel. Temporary location failure retains the previous fix with a searching state; off/denied/permanent errors clear it. Invalid GPS speed stays unavailable. Display-only compass smoothing uses the shortest circular arc without modifying raw readings.

Commands use correlated IDs, acknowledgements, bounded retries and Watch deduplication. An acknowledgement confirms app execution, not that a person physically perceived the result.

Local HTTP is paired but not TLS-encrypted. It belongs on trusted private networks, with no public port forwarding. The source release includes no cloud backend.
