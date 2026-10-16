# Capability coverage

The library intentionally mixes implemented signals with reference entries that explain platform limits. Only real source readings count as live data; demo readings are labeled simulated.

| Kind | Coverage |
|---|---|
| Motion | Fused orientation/quaternion, acceleration including gravity, angular velocity, gravity |
| Derived motion | Movement strength, stillness, gesture rhythm; these are app-derived signals, not additional physical sensors |
| Controls | Digital Crown control value and Play-pad activations; Crown requires focus on the Watch's input control |
| Environment | Battery/charge state, microphone RMS, relative altitude, pressure, magnetic heading, location/speed, steps/cadence |
| Saved Health | Latest authorized heart rate, HRV, oxygen saturation and sleeping wrist-temperature records, with their source dates |
| Outputs | Mac tones/metronome; Watch notification haptic and display-color commands; Watch-local tone test |
| Diagnostics | Watch capture/submission, Mac ingress/processing/display cadence, own-process CPU/memory, thermal/runtime status |

The 20 numeric routes are orientation, acceleration, rotation, gravity, intensity, stillness, Crown, touch, battery, microphone, altitude, pressure, heading, steps, heart rate, HRV, oxygen, wrist temperature, rhythm and location. Quaternion pose and quality/diagnostic metadata accompany those routes. Availability varies by device, permissions and records.

Double tap invokes the same primary action as Touch, not a separately identifiable gesture stream. Action button support is a reference (and the button is absent on Series 10). Sleep/ECG/workout imports, depth/water sensors, workout high-rate motion, external Bluetooth accessories and Nearby Interaction/UWB are not implemented integrations. Raw optical PPG, ambient light, NFC/Secure Element and raw-radio access are not exposed by this app.

The Neural Engine is not used. The app is not a medical device or navigation instrument. Frequency targets, background continuity and UI refresh rate are distinct measurements.
