# Hosted reconstruction comparison — 16 October 2026

The extra provider follows layer and storage implementation. It does not replace white-bubble filling or the existing balanced restoration service. Product labels use generic Arabic names; implementation identifiers remain in maintainable source and this engineering record.

## Actually evaluated

Cloudflare-hosted FLUX.2 klein 9B multi-reference editing: two aspect-preserving 480×480 PNG references (source and magenta-marked text areas), fixed server prompt and 512×512 output. Five actual requests were made, four on a private evaluation Worker and one through the production `/v1/reconstruct` route. The private evaluation Worker and its local temporary credential were removed afterwards.

Three real crops from the user's supplied comic were tested: purple fingerprint ornament with outlined Korean lettering, a red patterned/translucent statistics panel, and pale gradient dialogue bubbles. Generic-prompt inference took 1.79–2.85 seconds for these crops in this experiment, excluding native preparation. The production request took 2.45 seconds. These are single-request observations, not a device performance guarantee.

The ornament example recovered line detail more convincingly than the existing blurred fill, but raw output shifted colors and left rectangular seams on the other examples. OpenCV 4.11 normal seamless cloning matched generated gradients to the untouched surroundings. Reapplying the original local mask changed **zero pixels outside that mask** in each of the three evaluated crops. Mask input must be copied because seamlessClone can mutate it. Color matching does not prove the reconstruction of hidden decorations is historically accurate. No universal ranking or flawless-whitening claim is made.

The native pipeline maps the generated crop back to original image dimensions, performs background-thread color matching, and produces a mask-only alpha layer. Native tests cover aspect ratio, marker placement, digest/dimension rejection, mask clipping, removal of a controlled black glyph, cancellation, capacity errors and independent saved provider selection. Their CI result must be recorded before release.

## Capacity and privacy

Existing `/v1/restore` remains unchanged. The additional route uses a separate persistent budget and serial inference gate: maximum five accepted requests globally per UTC day, maximum two per hashed connection per day. Four private evaluations are seeded into the same 16 October budget. Failed inference reservations remain charged and no automatic paid fallback is enabled. A real sixth-request check returned HTTP 429 `daily_capacity_reached` before another inference. Both old origin and public gateway health checks remained successful.

Only the selected crop/marked crop is sent, without filenames, chapter or account credentials. The gateway does not store image bodies. Cloudflare handles inference under its own service terms; the application must not promise that a third-party provider has no internal processing or retention. Current free Workers AI allocation is 10,000 neurons/day. Five fixed-size 9B calls conservatively fit this allocation if it is not consumed elsewhere in the account. Provider limits/errors remain visible, and this is not a free unlimited public restoration service.

## Other authorized hosted APIs found

| Provider | Official endpoint/documentation | Actual status here |
| --- | --- | --- |
| SnapEdit | https://snapedit.app/api | Official GAN inpaint and SD Super Remove APIs exist. Advertised unit prices were $0.0028/$0.0056. No key, subscription or credits created; not integrated or quality-ranked. A modified client is unnecessary. |
| Clipdrop Cleanup | https://clipdrop.co/apis/docs/cleanup | Source plus binary mask, `mode=quality`, same-size PNG response; API key/credits required. Not integrated or evaluated. |
| Bria Eraser via fal | https://fal.ai/models/fal-ai/bria/eraser | Hosted mask-based API, advertised $0.04/generation; no key/credits configured. Not integrated or evaluated. |

Sources: https://developers.cloudflare.com/workers-ai/models/flux-2-klein-9b/ ; https://developers.cloudflare.com/changelog/post/2026-01-28-flux-2-klein-9b-workers-ai/ ; https://developers.cloudflare.com/workers-ai/platform/pricing/ . Cloudflare's model page links the hosted partner service terms at https://bfl.ai/legal/terms-of-service . No model weights from this provider are redistributed.
