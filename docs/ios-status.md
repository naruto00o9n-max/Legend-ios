# Current scope · iPhone and iPad

One application named **Cookies Editor**, bundle `com.cookies.editor.ios`. Earlier Offline/Online targets and IPAs are superseded. Android product development remains frozen. The user's iPad runs iPadOS 18; the exact model is unknown.

## Work in this repair

- Full-screen welcome, account, settings, community and profile destinations; account form centred within the full iPad viewport. White labels/icons on black glass with gold accents. Local editing does not require an account.
- Native Photos picker for gallery, image layers and textures. Provider files are copied before the callback returns, preserving their representation and original filename. Files is used separately for editable project archives.
- Persistent image tiles and a small source preview. Source-tile cache, selection controls and viewport updates are separate; a tile retains its previous image until replacement is ready. Changing selection/panning does not invalidate the source. The source on disk is immutable; layer drags persist metadata only when the gesture ends.
- A compact primary toolbar for text, drawing, image and shape, with supplementary tools in a menu and an in-canvas assistant. It is replaced by icon-based text tools in text mode and drawing tools in brush mode. Text panels overlay the canvas so opening them does not change the image viewport. Arabic input and paragraph rendering use RTL.
- Text handles follow the recovered 4.5 arrangement: delete, vertical stretch, rotate, horizontal stretch, box width, edit, duplicate, styles and proportional scaling. Perspective and mesh points are still inspector-controlled, not the original on-canvas control workflow.
- Typed community posts, details and approved comments, plus original vote/comment requests initiated only by an authenticated user's explicit action. Profile reads the original view. These authenticated operations have not been tested with a real account.

## Existing editing engine

Nested folders, rename/move/delete, text/image/shape/drawing layers, layer reorder, visibility, lock, opacity, duplication, eight blend modes and undo/redo. The editor can pan/pinch to 12800%, and supports 47 original fonts plus custom TTF/OTF import. In-app dialogue assistant and independent reader viewport remain available.

PNG import uses original-size disk RGBA. An 800×15000 page has a 48 MB RGBA backing, in addition to its source and assets. PNG export composes bands at original dimensions and retains the source ICC profile. An unedited PNG is copied byte-for-byte. Preview sampling is never the export source. JPEG is lossy and uses a full ImageIO image in memory. PSD export has separate raster layers; editable `.cookies` archives rebuild their RGBA backing when imported.

Native OpenCV Telea cleans a limited selected region. Its version differs from the original Android OpenCV, so exact cleaning pixels/performance are unverified. Effects, shape geometry, perspective/mesh and some stored style fields are incomplete or approximate; opening a panel does not certify its original rendering behavior.

## Verification

Actions build a real unsigned arm64 IPA and run native XCTest/UI tests on iPad and iPhone simulators. Test logs and `verification.json` record pass/failure rather than inferring success from compilation. Screenshots are unmodified attachments captured during actual tests. The Photos test must select an actual seeded 800×15000 asset; the canvas test verifies source reads remain stable through selection, panning and text edits. Pixel tests compare 48,000,000 RGBA bytes and original dimensions; native tests cover PNG export, original bytes, bottom-of-image text, archives, JPEG, PSD, fonts, cleaner and undo.

Physical iPad memory/FPS, iCloud-only assets, HDR/wide-gamut edited pixels, huge image formats beyond the tested fixture and original font/effect pixel parity remain unverified. 16-bit PNG is rejected explicitly. Earlier font measurements differed on 105 of 235 strict Android fixtures; that historical result is not certification of the current renderer.

## Authentication and server limits

Public original-service reads returned HTTP 200 for auth settings, configuration and approved community content. Email and Google are enabled; new email users require confirmation. Email signup includes `full_name`/`display_name`; the app reports actual HTTP/backend errors and stores real sessions in Keychain with refresh handling.

**Successful signup and login have not been demonstrated.** The original Android client uses native Google ID-token exchange, while this iOS client uses web PKCE and `cookies-editor://auth/callback`. An authorize redirect to Google does not establish that the service accepts this return URI. No owner-provided iOS OAuth client or redirect configuration is available. The user's observed final Google server error and failed email signup cannot be declared fixed without a successful account test or diagnostic response. No account/session was fabricated, no administrator endpoint or entitlement bypass was used, and no external test account was created.

## Unfinished parity

Original multi-page/batch projects, tag/style tables and tag-driven dialogue parsing, original project-format migration, PSD layer import, crop/resize, arbitrary text/image erase/restore, SOFT/MARKER brush behavior, blank-canvas UI, drafts/watermarks, web chapter imports, original cloud/font/style/project sync, Store/billing, notifications and gamification are incomplete. Community/profile UI parity has not been visually certified against authenticated original screens. No percentage of parity is asserted.
