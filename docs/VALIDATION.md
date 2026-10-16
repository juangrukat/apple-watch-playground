# Release validation

Validated locally on 16 October 2026 with Xcode 27 on macOS.

| Check | Result |
|---|---|
| Release Mac package/app build | Passed |
| Mac app self-test | Passed |
| Card model/preset/history fixtures | Passed |
| Physical pose and circular heading fixtures | Passed |
| Watch store/recovery/scheduler fixtures | Passed |
| Pose/wire/resource diagnostics fixtures | Passed |
| Audio RMS/timestamp fixtures | Passed |
| BLE framing at 20/64/185/512-byte payload limits | Passed |
| Unsigned Watch simulator build, portable project | Passed |
| Unsigned iPhone simulator build, portable project | Passed |

The private development build was exercised on a Series 10 GPS Watch running watchOS 26.6, including touch/Crown input, Bluetooth streaming, Watch-local haptic/tone/color output, location fixes and heading-quality reception. The public copy changes bundle identifiers/signing placeholders and makes the iPhone host configurable. Its unsigned simulator builds validate portability; they do not establish physical behavior on all devices.

The Mac screenshot was captured from a separate app identity with synthetic feeds. The Watch screenshot shows the Play interface and contains no Health/location values or pairing information. No personal recordings, provisioning files or device-specific logs are part of the release.

Known gaps: broader Watch/OS coverage, independently measured latency under varied networks, reliable microphone-off wrist-down behavior over long sessions, notarized binary distribution, TestFlight distribution and navigation-grade sensor accuracy.
