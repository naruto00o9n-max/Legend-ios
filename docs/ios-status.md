# Cookies Editor iPhone — current scope and evidence

Native SwiftUI/UIKit app, separate offline and original-service targets. Android development is frozen as requested; its oversized/out-of-screen control feedback was recorded in Legend.

## Functional implementation

- Black/gold glass welcome, responsive library, nested folders, import, rename/move, project archive, in-app assistant and reader.
- Native tiled original-size canvas with one/two-finger interaction and up to 12,800% zoom. Source RGBA is on disk; sampled preview pixels are never used for export.
- Text, image, shape and drawing layers; ordering, visibility, locking, duplication, opacity, eight blend modes, undo/redo, selection/move/scale/rotation.
- Original 47 font files plus custom font import. Arabic text, alignment, sizing, spacing, stroke/background/shadow, depth, gradients, texture, perspective, mesh and circular mask.
- Twenty shape paths translated from the provided APK. Nine named text effects are implemented, but effect pixels have not been certified against the Android renderer.
- Native OpenCV Telea region cleaning. This uses official iOS OpenCV 4.11.0, whereas the APK includes 4.5.3. Exact cleaner output/performance parity is not certified.
- Full-dimension PNG export, adjustable-quality JPEG, separate raster layers in PSD, and editable `.cookies` projects. The original APK PSD exporter also writes raster layer imageData rather than editable Photoshop text.

## Tests and limits

The C image-core check verifies every one of the 48,000,000 RGBA bytes of an 800×15000 fixture, including hidden RGB under transparent pixels. Sampled-region guard bytes, blending and sanitizer checks are included. Native XCTest checks original dimensions, unedited byte-identical PNG, text at the bottom of the image, editable archive, JPEG and PSD readability, layers and cleaner output. UI tests use iPhone SE and a modern iPhone and export actual screenshot attachments.

A successful build is not full YTyper parity. Original CoreText measurement prototype matched 130/235 strict Android fixtures and differed on 105; that baseline is not certification of this app renderer. See the [earlier baseline](https://github.com/naruto00o9n-max/Legend/blob/722718f6e8d8ff8f02337c5bf83a6455d9f4b6a1/docs/font-parity-report.json) and [reference inventory](https://github.com/naruto00o9n-max/Legend/blob/722718f6e8d8ff8f02337c5bf83a6455d9f4b6a1/docs/reference-inventory.json).

Outstanding parity areas include Android project/style format migration, original PSD layer import, the full tag/style management flow, original reader/assistant behavior details, all effect parameters and strict font/effect pixel comparison. PSD imports currently use ImageIO composite pixels. Canvas cropping/resizing and advanced selection operations are not complete. PNG16 is rejected explicitly rather than silently down-converted. JPEG uses lossy compression by design. Real iPhone FPS/memory measurements have not been taken; simulator results do not establish identical Android performance.

## Original services

On 2026-10-09, public client API checks returned HTTP 200 for auth settings, app_config and an approved community post. Signup, email and Google are enabled and new accounts require email confirmation. The offline app rejects network requests before transport and does not bundle the service configuration. The online app supports ordinary email/password signup/login, Supabase web PKCE for Google, session refresh, original profile and community reads. No user session was fabricated and no admin credential is used.

Actual login with the user's account and the Google callback allow-list remain unverified. Drive sync, billing/store/entitlements, original cloud font/style/project flows and notifications have not been ported. An ordinary user account does not provide developer OAuth configuration or iOS purchase setup. The online IPA must not be described as “all original server features working”.

## Delivery

CI compiles real arm64 binaries with code signing disabled, rejects an unexpected signature/provisioning profile, and packages separate offline/online IPAs. `verification.json`, build/test logs, xcresult bundles and a gallery of unmodified screenshots identify what passed or failed. Only passing final builds should be offered as verified development previews.
