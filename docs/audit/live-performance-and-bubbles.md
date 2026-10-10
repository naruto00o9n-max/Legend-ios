# Live performance and bubble layout — 2026-10-10

User steering supersedes the parity batch. No screenshot delivery requested.

## Implemented in e5bd8a1 and 3c62517
- Canvas gesture edits use coordinator-local document drafts; the observable document commits once at gesture end. Cancellation restores the committed scene. Normal brush ink stays in CAShapeLayer while the finger moves. Soft/texture/eraser previews use a coalesced background worker bounded to the stroke region, instead of rerasterizing full drawing sprites on the main thread.
- Brush loupe samples at most 20 Hz, never queues concurrent requests, and uses a utility worker. Rendering culls layers outside the region before shaping/compositing; shaped text bounds and fallback fonts are cached.
- Font registration no longer repeats in the session view initializer.
- Text sprites use linear/trilinear filtering and bounded display-scale resolution buckets. Software tiles rerender glyphs at display scale up to 4× while source tile caching ignores text-resolution changes. Editable text/source assets remain unchanged; export uses the original document dimensions. Extremely small screen text still has finite screen pixels.
- Manual bubble frame tool: oval, scream, rectangle, system. Dynamic programming keeps word order and matches a symmetric line-width profile; fitting measures native glyph widths and text height, with margins. System paragraphs are preserved. Layout calculation runs off the main thread.
- Frame insertion takes the next unused pasteable Typer bubble, carries tag font/color/style, saves the layer, then persists the used/gray marker. Failure to persist progress rolls the page back. Existing Sniper detection remains available; automatic shape selection is not implemented.

## Verification
- Swift parser passed locally. The actual line-partition function was also compiled with Linux Swift/Foundation and passed 736 valid Arabic/diacritic/mixed-word cases with word-order preservation; these portable metrics count characters and do not replace UIKit glyph measurement. This Linux environment cannot compile UIKit.
- Native arm64 Release build passed; PNG integrity passed for 800×15000 with all 48,000,000 RGBA bytes unchanged. Full iPad/iPhone checks are pending in [run 38056479140](https://github.com/naruto00o9n-max/Legend-ios/actions/runs/38056479140).
- New tests cover odd/even width profiles, Arabic fit/word preservation, 100 gesture drafts with zero model publications, and persisted Typer usage. These are awaiting native execution.
- Previous cf42cbb iPad tests reported centering expectation, absent Application Support reset handling, layer accessibility lookup and workspace toggle lookup failures. Reset missing-directory handling, centering expectation, row accessibility containment and test wait were corrected. Further native results must be inspected before claiming success.
- Physical iPad FPS and subjective responsiveness have not been measured. No universal no-lag guarantee.

## Remaining
- Inspect native results; repair real failures. Obtain unsigned IPA tied to tested source.
- Advanced blend/effect software rendering still uses bounded-region compositing. Bubble exact line symmetry depends on word lengths; no fake spaces or stretched glyphs are introduced.
- The original 70-item parity batch remains paused until user authorization.

## Current unsigned package
Source 3c6251791df247d6202cb7c5a722f454d311328f; run 38056479140; artifact 11671082101. Verified Mach-O arm64, no LC_CODE_SIGNATURE, no _CodeSignature directory, no embedded.mobileprovision. Size 14,211,526 bytes; SHA256 e345a6bd683bbf388925c7d052060602eadc8ab8b18c5f29890f0b7db340b24a. Functional native checks still pending.

Intermediate native evidence: 3c62517/run 38056479140 iPad test log shows all four BubbleLayoutTests passing (Arabic fit, no per-point publications, odd/even profiles, persistent Typer insertion), plus nine StorageAndInteractionTests passing before that run was superseded to add complex-blend/drawing-stack gesture handling. This is partial execution, not a full-suite pass. The final source is now 3f2edc521d720aaed56ddd440201ab144059384d, run 38057499426 pending.

## نتيجة التشغيل 38057499426 للنسخة 3f2edc5

على iPad نجحت 74 اختبارات محرك (منها اختبارات التنسيق الخمسة واختبارات التخزين التسعة)، و6 اختبارات خدمات محلية، و16 من 17 اختبارات واجهة. أخفق الوصول إلى خيار اقتراح النص في قائمة الإعدادات؛ هذا الإخفاق مسجل، ولا يُعد التشغيل اجتيازًا لجميع الواجهات. نجح اختبارا الخدمات الأصلية الخارجيان. فحص PNG 800×15000 حافظ على كل 48,000,000 بايت RGBA، وبناء IPA غير الموقع تحقق فعلًا.

طلب المستخدم بعد التجربة تطوير القنص والتنسيق والتبييض؛ يدار ذلك بصورة مستقلة في `sniper-typesetting-and-whitening.md`. لا تُستأنف دفعة المطابقة ذات 70 بندًا.
