# Build and install

## Mac

Install Xcode and finish its initial setup. The Swift package requires Swift 6 and macOS 14+. From the repository root, run `./build-mac.sh`, then open `Watch Playground.app`. The app starts in demo mode on a fresh install.

Xcode's active developer directory must point to the installation with the SDKs you want to use. A toolchain without the needed platforms cannot build the corresponding target.

## Watch

The checked-in Xcode project is ready to open. `project.yml` is its optional XcodeGen source; XcodeGen is not needed to open the existing project.

Choose the WatchPlaygroundWatch scheme, then set Signing & Capabilities to your own team and a unique identifier. The public project deliberately contains no signing team or provisioning profile. HealthKit is an entitlement; your account and provisioning must support it. Do not assume a free Personal Team can provision all included capabilities.

Pair your Watch with an iPhone, add your Apple Account to Xcode, enable Developer Mode where required, and choose the physical Watch as destination. Developer Mode controls may appear only after Xcode has prepared the device. Keep it unlocked and awake during first deployment. Development profiles may need to be trusted on the phone.

After installation, start the Mac receiver and enter its pairing code in the Watch's Connection setup. Both apps must grant Bluetooth access. Keep the Watch nearby. Microphone, location, motion and Health prompts are separate from pairing.

For an unsigned simulator compile (no provisioning):

```sh
xcodebuild -project WatchCompanion/WatchPlayground.xcodeproj \
  -scheme WatchPlaygroundWatch -configuration Debug \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath .build/watch-simulator CODE_SIGNING_ALLOWED=NO build
```

Simulator builds verify compilation and UI structure; they do not validate real sensors, permissions, or radio performance.

## Optional iPhone diagnostic

The PlaygroundPhoneProbe scheme is a local network troubleshooting tool. Choose your signing team/unique identifier, install it on an iPhone, enter your Mac's hostname or IP, and tap Test connection. It tests ports 8765 and 8766 and starts a reverse diagnostic listener on the phone at port 8767. Port 8766 is a legacy diagnostic endpoint, so its failure alone does not mean the current Mac receiver is broken. The utility is not needed for the normal Watch-to-Mac Bluetooth path.

## Troubleshooting

- Bluetooth denied: check the relevant OS privacy controls. Check both apps' connection pages for the correct pairing code.
- HTTP timeout: check local-network permission, host address, firewall rules, VPN routing, and whether your network permits device-to-device communication. Do not disable security tools indiscriminately or expose the listener publicly.
- Deployment timeout: this is Xcode's installation connection, separate from the app's sensor transport. Reconnect/unlock the devices and keep the Watch awake during installation.
- No location: enable it in Watch Feeds, grant permission, and try near a window or outdoors. A retained position or unavailable speed is not a fresh movement estimate.
- Compass jumps: check reported accuracy and nearby magnetic sources. The display smooths around north; it cannot repair a bad magnetic reading.
- Saved Health absent: the app cannot distinguish missing records from withheld read permission. Read access does not start live heart-rate sampling.

## Distribution status

This repository is a developer source release. Sharing the Watch source does not let another person directly install your development-signed app. For broader distribution, prepare appropriate signing, TestFlight/App Store submission, privacy information and review. A public Mac download should use a Developer ID-signed, notarized build. No distribution credentials or notarized installers are included here.
