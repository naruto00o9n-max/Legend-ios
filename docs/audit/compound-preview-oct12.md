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
- Keep selected normal-blend text and its normal foreground stack on compositor sprites throughout tool editing. Complex blend stacks retain their original compositor.
- Publish completed sprite results while newer work is pending. Track each displayed image's actual local rectangle separately, so moving a layer still transforms the visible frame immediately.
- Separate typography alpha-mask and decorated pre-perspective caches. Geometry changes reuse decoration; gradient/style changes reuse typography. Clear both on memory pressure. Bound post-perspective screen allocation; export stays separate.
- Suspend autosave and thumbnail scheduling during inspector slider tracking. Resume after release, and flush when inspector closes.

## Verification required before acceptance

Four new native regressions cover actual compound gradient + outline + bevel + perspective renders, intermediate frame publication while 60 edits are still arriving, no image-tile/source invalidation for tool edits, inspector work off main, cache invalidation on font changes, cancellation, and deferred document persistence. Add a real UI slider exercise with gradient preset, bevel and perspective followed by creating another text. Existing engine, Files, Photos, colors, outline, manual style and export-integrity checks remain required.

These tests use iPhone/iPad simulators and cannot establish frame rate or guarantee smoothness on a physical A10 device. Do not mark all missing features completed or describe hardware performance as confirmed. Do not release a failed native build as a verified fix.
