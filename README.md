# Cookies Editor · native iPhone and iPad

A shared SwiftUI/UIKit codebase with two installable editions: the connected application, with ordinary client access to the original service and editing without login; and a standalone edition with no account/community routes or bundled original-service configuration. Both are named Cookies Editor and use separate bundle IDs. White text and icons, black glass and restrained gold accents; Arabic RTL. The current reference is YTyper **4.5**, not the earlier 3.8 APK.

This is a development preview, **not a certified replica or a production release**. The work prioritizes real Photos import, stable image rendering, text tools and tablet layout. A temporary-email test demonstrated signup, confirmation and a real password session on the original API. The user subsequently confirmed email/password login, commenting, Typer and Sniper on their device. Google return configuration, all service features and complete interface/renderer parity remain unfinished or unverified. See [the current Typer/performance repair](docs/repair-typer-and-performance.md).

## Build and inspect

On an Intel Mac with Xcode 16+, Python 3.11+ and XcodeGen:

```sh
python3 scripts/fetch_resources.py
python3 scripts/fetch_whitening_fixtures.py
xcodegen generate
bash scripts/build_ipas.sh
bash scripts/test_simulators.sh ipad core
bash scripts/test_simulators.sh ipad ui
bash scripts/test_local_simulator.sh ipad
bash scripts/test_simulators.sh iphone core
bash scripts/test_simulators.sh iphone ui
bash scripts/test_local_simulator.sh iphone
python3 scripts/collect_evidence.py
```

CI produces `Cookies-Editor-unsigned.ipa` and `Cookies-Editor-Local-unsigned.ipa`; sign each before installing. Local means no account/community; website chapter import remains available. The editions can coexist because their bundle IDs differ. Each IPA embeds its exact source revision, and CI checks service configuration isolation and unsigned status. Minimum iOS/iPadOS is 17. Tests seed an actual Photos-library asset at 800×15000, exercise the application on iPad and iPhone, and export unmodified screenshot attachments and test logs. Simulator success does not certify a physical device.

OpenCV 4.11.0 is pinned. Simulator builds currently require x86_64 because its supplied framework has an arm64 device slice but no arm64 simulator slice. PNG uses pinned libpng with its license. Original public client configuration and 47 font files are fetched from the verified APK; no administrator credentials are used.

See [scope and limitations](docs/ios-status.md), [interface evidence](docs/interface-parity.md), and [reference metadata](docs/reference-v45.json). The reference-inspection Action runs the unmodified original APK on an accelerated Android emulator; screenshots are evidence of the states actually reached, not certification of every screen.

## Full reference inventory and completion plan

See the [Arabic comparison of 182 work items](docs/audit/comparison-ar.md), [screen map](docs/audit/screen-map.md), [button/input associations](docs/audit/control-associations.csv), and [staged implementation plan](docs/audit/implementation-plan.md). Download the audit directory and open index.html for an offline searchable viewer. These are evidence-qualified work items, not a parity percentage.

## Workspace refresh

See [the October 11 workspace redesign](docs/audit/workspace-redesign-oct11.md): a persistent floating Typer, automatic resumption, independent editable tag colors, organized settings, chapter studio, live color feedback and a searchable Arabic guide. The earlier editor quality repairs remain in place; the 70-item parity batch is still paused.


## Optional Big LaMa restoration

Each selected bubble can use classic whitening, local Big LaMa, or explicit
cloud execution. The optional pinned ONNX weights download is about 208 MB;
neither IPA embeds them. Local inference uses ONNX Runtime CPU instead of the
Core ML ML Program path that failed on a physical iPad. Cloud inference runs
on a user-owned Railway CPU origin behind Cloudflare Worker/SQLite DO. The
standalone edition retains this optional service without original-app login
or community. Images are not uploaded automatically.

See [the Arabic implementation and quality report](docs/audit/big-lama-cloud-oct14.md),
[model/deployment evidence](docs/audit/big-lama-oct14.json), and
[the inference service](Backend/BigLaMa/README.md). Text-only masks, protected
bubble contours, manual corrections, preview and undo are retained. Occluded
art is estimated reconstruction and needs review; Railway trial capacity is
temporary. Simulator results do not certify physical-device latency.

Verified restoration release: app source `5c98fc4`, [final native UI/local verification](https://github.com/naruto00o9n-max/Legend-ios/actions/runs/38566918791), and [composite immutable-source evidence](docs/audit/restoration-release-oct14.json). Original-device performance and exact hidden-art recovery remain unverified.
