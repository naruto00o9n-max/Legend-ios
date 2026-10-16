# ibisPaint reference, layers and project vault — 16 October 2026

## Scope and evidence

Priority is the actual ibisPaint APK, layers/added images/eraser first, project storage second, hosted restoration alternatives last. This is not a claim of complete ibisPaint parity. Existing unrelated parity ledgers remain intact.

Downloaded the unmodified Android **ibisPaint X 14.1.2**, versionCode 1401020064, from the public release distribution. The Play listing and release listing agreed on the Android version. 14.1.3 was an iOS release at inspection time.

- XAPK URL: https://apk.captain-droid.com/wp-content/uploads/2026/10/jp.ne.ibis.ibispaintx.app_1401020064.xapk
- SHA256: `7c52acb5d784eef2d4b9f39c4f83829a5d0ff99cc36d9e23626330be4f55ff12`
- Base package: `jp.ne.ibis.ibispaintx.app`; target SDK 36; minimum 24.
- Signer: CN=Eiji Kamiya, O=ibis inc., Nagoya, Aichi, JP.
- Signer SHA256: `c22440bac71bef2a17b1b7a3d5e78dec069a29f9c2c166a857b71b045e37b37a`.
- Inventory: 3,639 APK entries across splits, 4,237 English localization keys, 22,812 Java output files. JADX reported 165 decompilation errors. The native editor is not recovered original C++ source.
- Native function inventory contains 72,273 exported defined function rows, 32,330 in the ibispaint namespace; aliases can contribute rows. Counts are inventory, not individually verified behavior.
- Layer command entrypoints, eraser commands, direct call targets and ARM-independent x86_64 disassembly were examined. Third-party code, binaries, icons and assets are not committed into this implementation.
- Local TCG Android was unusable (system ANRs). Accelerated Android 30 exited during native startup after `FORTIFY: pthread_mutex_lock called on a destroyed mutex`. Android 35 showed `libEGL: called unimplemented OpenGL ES API` and process exit. These runs do **not** establish successful interface inspection. A GLES-renderer retry is tracked separately. No license bypass or binary patch was used.

## Comparison based on executable/source evidence

| Area | Reference evidence | Cookies changes in this work | Still missing or unverified |
| --- | --- | --- | --- |
| Layers | Native add/clone/rename/reorder/hide/lock/clear/save/merge commands; floating layer window | Separate row controls, command rail, rename, reorder, mirror, selected-layer opacity/blend, PNG export, reversible rasterization, large iPad inspector over live canvas | True folder hierarchy, alpha lock, clipping, all 27 reference blend modes, selection layer, moving/resizing floating panel |
| Added pictures | Layer creation, import and transform commands | Native-resolution asynchronous import above selection, centered in viewport; tile-backed rendering | Full reference perspective/mesh/interpolation UI parity |
| Eraser | Distinct BrushToolEraser, brush engine, bounding-box undo-cache calls | Direct toolbar eraser; selected image/text/shape gets an independent alpha mask; drawing strokes erase their own history; base promoted by reference; partial alpha works | Reference vector eraser, complete eraser preset/brush configuration parity |
| Performance | SurfaceView + native pointer batches and historical samples; EGL/GLES drawing and sub-image updates; dirty-area methods; texture-cache budgeting; framebuffer swap-out; undo chunks | Preserve stable underlying image rasters, exclude masks from inner raster cache identity, cache decoded image providers; debounce/cancel layer thumbnails; avoid whole added-image decoding for every display tile | No physical-device or same-device ibisPaint benchmark has been performed |

The reference engine architecture explains useful design directions, not a proven speed ratio. Bitmap images still have finite original resolution; vector text and native-pixel source preservation are separate concerns.

## Verification branches

- `verify/layer-workbench-oct16`, source `f9e6eb9e7a0fbba5aa40884f4046e91e7f4679b5`, Actions run 38868021071.
- Both unsigned arm64 layer-only IPAs built successfully; all four simulator jobs passed. iPad logs confirm 178 editor tests (including 9 new layer tests), 14 service unit tests, four focused layer/gesture UI tests, real Photos import and two external-service checks. Local iPad/iPhone UI/source-integrity checks also passed. Source comparison covered all 48,000,000 RGBA bytes of an 800×15,000 image. iPhone job status is green; its detailed artifact still needs to be archived alongside iPad evidence.
- New native tests cover layer alpha isolation, partial erasure, metadata serialization, base source references, locked/hidden behavior, stack order, reversible clear, export and rasterization, and native-resolution image import.

## Project vault

User explicitly selected Supabase connection **Z**, accepted download-only-open-project / verify-upload / evict-after-close, and approved organization `miroumar4951-ship-it's Org` after it was confirmed as the only empty free organization.

- Created healthy project **Cookies Project Vault**, ref `ilagswvocznnrrreiswq`, eu-central-1.
- Private `cookies-projects` bucket; no client access to tables or privileged RPCs. RLS enabled without policies intentionally denies direct anonymous/authenticated table access. Only the server function uses its own platform-provided service credential.
- Server validates ordinary sessions through the fixed original issuer's public `/auth/v1/user`, or the vault's own Auth issuer. Owner namespace includes the issuer. No original-service admin key, entitlement or table is touched.
- 8 MiB immutable chunks, SHA256 per chunk and archive, 128 MiB compressed-project cap, 512 MiB per account and 800 MiB global reservation budget within the free 1 GB storage allowance. This is **not unlimited storage**. No paid plan was enabled.
- Compare-and-swap generations prevent silent stale writes/deletes. Pending and retired physical revisions stay charged until objects are actually removed. Grace period protects in-flight requests.
- Native archive includes original PNG, editable layers, referenced assets, and used imported fonts; excludes rebuildable RGBA and discarded intermediate pictures. Global style/Typer/font/settings libraries remain covered by selective backup, not implicit project sync.
- Native directory swaps are journaled. Startup restores the original on an interrupted replacement. Eviction is allowed only while closed, after upload/commit/readback and matching page/account checks. Active/reopened/changed projects are retained.
- Device copies retain metadata and thumbnail after eviction. Reopening downloads and verifies the archive before pixel access; rebuildable pixel files are recreated as needed. Cloud-dependent chapter/backup operations require the relevant project to be downloaded first.

### Actual server verification

`Backend/ProjectVault/protocol.test.ts`: three protocol/security tests passed under Node's native TypeScript stripping.

Live SQL transaction verified reservation/atomic commit, idempotence, stale-write/delete rejection, current-head removal protection, private grants and deletion. Test transaction rolled back.

Live service probe created two isolated ordinary users **in this newly owned project**, signed them in, uploaded 8 MiB + 97 bytes in two chunks, rejected corruption/incomplete commit, committed and read back identical full SHA256, rejected cross-user access and stale operations, and deleted the test project. All 17 checks passed, including safe global collection of expired transfers without exposing another account’s content. Users, storage objects and rows were then removed; readback counts were all zero. The temporary privileged probe was replaced by a JWT-protected `410 Gone` handler. No real user images or account credentials were used.

Native archive/recovery/client/coordinator/UI tests and full native builds are required before enabling this branch in a release. Project creation or live backend checks alone do not prove the iPad workflow works.

## Restoration alternatives

Not yet implemented in this work. User requested this after layers and project storage. Future providers must offer a documented/authorized hosted API and be compared on the same comic regions. A modified SnapEdit client's private entitlement cannot be reused or bypassed. Provider billing/keys are not invented. Existing restoration service is unchanged.

### Native live integration gate

The vault verification workflow now requests a signed GitHub OIDC token with audience `cookies-vault-native-tests`. A separate test-only function verifies GitHub signature, repository ID/owner ID, exact branch and workflow path before provisioning a short-lived **ordinary user in this owned test project**. It returns only that user's session and a public client key, never a platform admin key. The JSON fixture is generated in the XCTest resource directory, ignored by git, never part of the production app target or IPA job, and excluded from uploaded artifacts. Cleanup checks the same run ID and CI account metadata before removing test accounts/objects. Native logs must show the actual round-trip test **passed**, not skipped. This verifies archive, live transfer, eviction, reopening, editing/resaving and keeping a device copy before server deletion.

Project leases follow navigation destination lifetime rather than disappearance callbacks: covering the editor with a full-screen tool must not upload/evict its source. Reader/editor leases for the same project are independent. Closing the last lease permits the transfer. Cache/reset/restore/backup operations refuse to race an active transfer.
