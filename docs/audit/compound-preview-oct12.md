# Compound text performance follow-up — 12 October 2026

Scope is performance/stability only. New inventory features are paused following device feedback. Earlier engine success is not evidence of smooth editing on iPad 7/A10.

## Concrete problems found

- GeometryInspector computed a full attributed-text/filter/perspective raster synchronously from SwiftUI body. It used the export budget, not the screen budget. Every geometry or published model change could block the main thread.
- Sprite completion rejected an image whenever a newer knob value was pending. Continuous changes therefore starved the displayed result until input stopped.
- Tool sliders edited software image tiles outside a finger gesture. The same text could be rendered repeatedly across viewport tiles instead of one selected-layer surface.
- Perspective changes invalidated glyph shaping, gradient fill, outline and style filtering, although those stages did not change.
- Debounced synchronous document writes and thumbnail preparation could start during slower ongoing slider movement.

## Changes

- Asynchronous geometry inspector, one running request plus one replaceable latest request; publish completed images during continuous input. Cancel discarded inspectors.
- Keep selected normal-blend text and its normal foreground stack on compositor sprites throughout tool editing. Complex blend stacks and drawing foregrounds retain their original compositor. Hidden/reordered foregrounds retire the old surface before rebuilding; gesture-sized drawing crops are not retained across scrolling.
- Publish completed sprite results while newer work is pending. Track each displayed image's actual local rectangle separately, so moving a layer still transforms the visible frame immediately.
- Use a 65,536-pixel live preview while settings change; schedule one complete screen-quality refinement after 300 ms of quiet. Draft, screen and export cache entries remain separate even at identical resolution.
- Separate typography alpha-mask and decorated pre-perspective caches. Geometry changes reuse decoration; gradient/style changes reuse typography. Clear both on memory pressure. Bound post-perspective screen allocation and keep gradient-shadow composition at that same effective image scale; export stays separate.
- Suspend autosave and thumbnail scheduling during inspector slider tracking. Resume after release, and flush when inspector closes.

## Verification required before acceptance

Seven new native regressions cover actual compound fill/stroke/shadow gradients + outline + bevel + perspective renders, intermediate frame publication while 60 edits are still arriving, no image-tile/source invalidation for tool edits, inspector work off main, cache invalidation on font changes, cancellation, and deferred document persistence. Add a real UI slider exercise with gradient preset, bevel and perspective followed by creating another text. Existing engine, Files, Photos, colors, outline, manual style and export-integrity checks remain required.

These tests use iPhone/iPad simulators and cannot establish frame rate or guarantee smoothness on a physical A10 device. Do not mark all missing features completed or describe hardware performance as confirmed. Do not release a failed native build as a verified fix.

## Rejected first candidate

Candidate `aee63cd` compiled and packaged, but each device had a failed continuous-edit regression. iPhone produced zero new frames during 60 edits; iPad produced one. The source-read assertion also incorrectly began before initial tile loading completed. This candidate is not accepted as a verified performance fix. The follow-up waits for initial scene readiness, retains the intermediate-frame requirement, and bounds live filter work rather than weakening that assertion.
