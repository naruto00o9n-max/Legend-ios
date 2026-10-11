# Text creation and full tag style editing — 2026-10-11

The user tested the surrounding-interface update and accepted it, then reported that automatic dialogue creation ignores tag appearance. This work is independent of the paused parity batch.

## Required behavior

- Sniper and drawn bubble layout take the **bubble's actual tag**, including ordinary dialogue without a prefix. Saved panel tag/font overrides cannot replace it. Autosizing may change font size, box width and centered layout to fit the bubble; it preserves font, ink, gradients, outlines, spacing, shadows and effects.
- A new manual text starts black without an outline/effects before any manual preset has been confirmed. **Done** and leaving text mode explicitly confirm its reusable appearance. New manual texts use that saved appearance across projects/relaunches. Typer text and tag previews cannot update it.
- Older projects decode without the optional text-origin/transform fields. Unknown legacy origins are never silently learned as manual styles.
- Tag settings open the real canvas with its real text inspector, handles, every reusable text style panel, undo/redo, and Save tag → confirmation. Preview text and position are examples, not stored dialogue content. Selected-character spans and destructive rasterization/masks are content-specific, not reusable tag settings.
- Texture assets are owned by Styles before the disposable preview closes. Content hashes reuse identical textures. Selective Styles backup includes the manual preset and its textures; Typer backup includes tag appearance and transforms. Full reset clears both directories.

## Implementation

Document.swift adds backward-compatible optional origin and tag transforms. StyleStore owns the independent manual-text.json preset and reusable assets. TyperStore.dialogueLayer centralizes tag resolution; actual EditorView and TyperPanel paths call it before background layout. TagStyleEditorView uses CanvasHost/TextInspector and an isolated temporary project; its save callback persists DialogueTag and owned assets. No original-server configuration or entitlements changed.

## Validation status

Swift syntax parsing and diff whitespace checks passed locally (Linux). Six native integration tests cover default/manual confirmation, relaunches, no learning from Typer, actual marked/unmarked insertion through both fitters, tag-group identity, texture survival/selective backup, full tag effects/transforms, and legacy origin behavior. A real UI test saves/reopens outline thickness in the tag editor. Native build/test and the two unsigned arm64 IPAs are pending CI for this revision; do not mark them passed before checking results.

The preceding bbcafee run passed 103 editor tests and 6 service mocks on each device; its Typer reopen/filter interaction passed. Real Files UI still showed the system picker after a label tap, despite a background font-close element existing, so that assertion was not proof of dismissal/import. This revision verifies the foreground picker disappears, selects the real Files cell, and includes explicit UIKit dismissal after delivery. Full connected/UI and local-edition gates must be rerun after App changes.

Initial native build 38148092332 rejected ambiguous CGFloat/Double arithmetic in the new preview centering expression before producing an IPA. Explicit Double coordinates correct it; the follow-up also verifies the manual Done → new text outline path in real UI. No successful runtime result is claimed for the failed build.

## Native follow-up dbfa37a

Source: `dbfa37a13234c4e7559bd8ad2aeab233e9dce67b`; [run 38148730485](https://github.com/naruto00o9n-max/Legend-ios/actions/runs/38148730485). The two unsigned Release arm64 builds passed. Actual downloaded IPA bundle contents, source revisions, URL schemes, service flags/configuration and absence of Mach-O signatures/provisioning were verified. The native PNG 800×15000 integrity gate passed.

On each iPad/iPhone, 109 editor integration tests and 6 mocked service tests passed with zero failures, including all six new manual/tag regressions. Full connected interface tests and both local editions remain pending at this checkpoint. Package and core success alone are not an end-to-end interface success.
