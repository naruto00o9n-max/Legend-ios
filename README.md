# Cookies Editor · native iPhone and iPad

One SwiftUI/UIKit application, with local image editing available without login and ordinary client access to the original service. White text and icons, black glass and restrained gold accents; Arabic RTL. The current reference is YTyper **4.5**, not the earlier 3.8 APK.

This is a development preview, **not a certified replica or a production release**. The work prioritizes real Photos import, stable image rendering, text tools and tablet layout. A temporary-email test demonstrated signup, confirmation and a real password session on the original API. The user subsequently confirmed email/password login, commenting, Typer and Sniper on their device. Google return configuration, all service features and complete interface/renderer parity remain unfinished or unverified. See [the current Typer/performance repair](docs/repair-typer-and-performance.md).

## Build and inspect

On an Intel Mac with Xcode 16+, Python 3.11+ and XcodeGen:

```sh
python3 scripts/fetch_resources.py
xcodegen generate
bash scripts/build_ipas.sh
bash scripts/test_simulators.sh ipad
bash scripts/test_simulators.sh iphone
python3 scripts/collect_evidence.py
```

CI produces one `Cookies-Editor-unsigned.ipa`; sign it before installing. Minimum iOS/iPadOS is 17. Tests seed an actual Photos-library asset at 800×15000, exercise the application on iPad and iPhone, and export unmodified screenshot attachments and test logs. Simulator success does not certify a physical device.

OpenCV 4.11.0 is pinned. Simulator builds currently require x86_64 because its supplied framework has an arm64 device slice but no arm64 simulator slice. PNG uses pinned libpng with its license. Original public client configuration and 47 font files are fetched from the verified APK; no administrator credentials are used.

See [scope and limitations](docs/ios-status.md), [interface evidence](docs/interface-parity.md), and [reference metadata](docs/reference-v45.json). The reference-inspection Action runs the unmodified original APK on an accelerated Android emulator; screenshots are evidence of the states actually reached, not certification of every screen.

## Full reference inventory and completion plan

See the [Arabic comparison of 182 work items](docs/audit/comparison-ar.md), [screen map](docs/audit/screen-map.md), [button/input associations](docs/audit/control-associations.csv), and [staged implementation plan](docs/audit/implementation-plan.md). Download the audit directory and open index.html for an offline searchable viewer. These are evidence-qualified work items, not a parity percentage.
