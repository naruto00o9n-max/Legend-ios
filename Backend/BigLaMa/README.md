# Cookies Editor — Big LaMa restoration origin

This service runs the pinned **Big LaMa** ONNX export on CPU. It is not an LLM,
diffusion substitute, or a white rectangle. The matching iOS implementation uses
the same model. Model patches are clipped to the submitted text mask, at native
source resolution; large regions use overlapping 512-pixel windows.

`POST /v1/restore`: multipart PNG fields `image`, `mask`; private origin Bearer
credential required. Output: transparent PNG of exactly the input dimensions.
Pixels outside the selected text mask have zero alpha. No image persistence,
request-body logging, accounts or original-app points are involved.

Cloudflare Worker + SQLite Durable Object in `cloudflare/` protects the origin
credential, caps concurrent inference at one, and enforces persistent temporary
daily capacity limits. The app never receives the origin credential. The
default trial limits are 300 requests/day overall and 120 per client IP/day;
these are editable deployment settings, not fake user credits. No images enter
the DO database; only salted IP digests and counts are stored for the current day.

Deploy this repository using the root `railway.toml`. Set the private
`RESTORATION_ORIGIN_TOKEN` before starting. On Cloudflare set `BACKEND_URL` and
secret `BACKEND_TOKEN` to match; deploy the Worker and DO migration. A plain
Cloudflare Worker cannot load the Python model: full Cloudflare hosting needs
Containers and an enabled Workers Paid plan. The connected account currently
does not have that entitlement, so an external CPU origin can sit behind the
Cloudflare endpoint without changing the inference model.

Validation: real Asura Scans crops and public comic/manhwa references, exact
outside-mask preservation, white-text-remnant measurements, authenticated HTTP
inference, concurrency and capacity checks. Quality is estimated reconstruction
of occluded art; exact invisible decorations and flawless OCR are not promised.
