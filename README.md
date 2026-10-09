# Cookies Editor for iPhone

Native SwiftUI / UIKit editor under active implementation. Black and gold glass interface, Arabic UI, nested project folders, tiled original-size canvas, text and drawing layers, native OpenCV cleaning and banded lossless PNG export. Two targets: `CookiesOffline` and `CookiesServices`.

This is **not yet verified as fully equivalent to YTyper**. The reference APK is pinned by SHA-256; original fonts and public client configuration are fetched during CI. No administrator credential is used. Original services are accessed through ordinary client APIs. A successful auth settings read does not prove Google callback, Drive, community, purchase or cloud sync portability.

GitHub Actions builds real arm64 application bundles, packages unsigned IPAs, and tests image integrity and actual interfaces on two iPhone simulators. Artifacts are development builds until those checks pass.

## Build

On an Intel Mac with Xcode 16+, Python 3.11+ and XcodeGen:

```sh
python3 scripts/fetch_resources.py
xcodegen generate
bash scripts/build_ipas.sh
bash scripts/test_simulators.sh
```

OpenCV 4.11.0 official universal iOS static framework is pinned. Simulator verification currently uses x86_64 because that framework has an arm64 device slice but no arm64 simulator slice. The PNG core uses pinned libpng sources with their license. See `docs/` for reference measurements and outstanding parity requirements.
