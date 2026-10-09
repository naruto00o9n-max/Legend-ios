# YTyper 4.5 → Cookies Editor · interface evidence

Exact reference SHA256: `a3758bcdf50c802c25d9023c90456f6bdde922a94cda08fc3ce737c2a9b29789`. APK resources include 219 layout XML files and 47 unchanged original fonts. JADX reported 305 errors; compiled code is not a complete buildable source project.

| Workflow | Current iOS implementation | Evidence and remaining limits |
|---|---|---|
| Welcome / account | Full-screen Arabic Cookies account and welcome | Original launch screenshot shows native Google sign-in; email form is a user request. Temporary email signup/confirmation/password API test succeeded; The user confirmed physical-device email/password login; Google return unresolved. |
| Projects | Two import cards, recent projects, nested folders, workspace | Actual original dashboard/workspace captures; original batch pages, metrics, Store/cloud actions unfinished. |
| Editor image | Persistent tile views, preview, cache, original-size source | Original `BitmapRegionDecoder` keeps a cached chunk plus preview; native source-read and gesture tests. Physical performance unverified. |
| Text toolbar | Replaces primary toolbar, icon-based subtools | Actual original primary/text modes captured and XML dimensions inspected. Native text/draw/image/shape are direct; supplementary tools use More. Original Drafts is unfinished. |
| Text handles | Nine actions arranged from recovered 4.5 handler | Original top delete/vertical/rotate; sides horizontal/box; bottom edit/duplicate/styles/scale. Perspective/mesh handles incomplete. |
| Text entry | Arabic native UITextView in canvas overlay | RTL input/rendering; original rich span/tag flow incomplete. |
| Fonts | Original 47 files plus custom imports | Actual original font-library screenshot; cloud filters/collections incomplete. |
| Layers | Layer thumbnails, visibility, lock, reorder, opacity/blend | Actual original layer popup captured; type-filter chips, visual and erase/restore parity unfinished. |
| Export | Original-size PNG, JPEG, raster-layer PSD, Cookies archive | Integrity and native format tests; original batch export UI unfinished. |
| Typer / Sniper / reader | Persistent line/paragraph chapters, grey-used bubbles, direct text placement, original default tags, ordered ROI bubble targeting; independent reader zoom | New native/UI tests cover progress and interaction. Original paid-ammo sync, exact fit and multiple-page reader incomplete. |
| Settings | Full-screen native settings and account navigation | Actual original settings screenshot; Working local tag/font/style, separation and default text-size settings; many remaining original preferences missing. |
| Community / profile | Real typed public feed/detail, authenticated requests/view | API fields inspected; User confirmed email/password login and posting a comment; authenticated original screenshots and other write flows remain unverified. |
| Store / cloud / webtoon / gamification | Unfinished | No matching-functionality claim. |

`reference-inspection.yml` installs the original APK unchanged. Its exported ProjectsActivity is opened for unauthenticated UI research; this is recorded in the evidence. The first header shortcut opens **Rewards Protocol**, not Community. A failed tap or inaccessible authenticated state is not counted as a captured feature.

Opening all text panels in UI tests verifies navigation and visible bounds. It does not prove original effect pixels, complete parameters, original performance or full application parity. Native font/effect comparison and physical iPad testing remain necessary.

The detailed [Arabic audit](audit/comparison-ar.md), [screen map](audit/screen-map.md) and [implementation plan](audit/implementation-plan.md) supersede this abbreviated table for remaining-feature tracking.
