"""Private inference origin. No image storage, request-body logs or external OCR."""
import hashlib, hmac, io, os, pathlib
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from PIL import Image, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool
from engine import BigLaMa
from fetch_model import SPEC, verify

MAX_BODY = 20_000_000
Image.MAX_IMAGE_PIXELS = 4_194_304
model = None

@asynccontextmanager
async def lifespan(app):
    global model
    path = pathlib.Path(os.environ.get('LAMA_MODEL_PATH', '/models/big-lama.onnx'))
    if not os.environ.get('RESTORATION_ORIGIN_TOKEN'):
        raise RuntimeError('Missing private origin token')
    if not verify(path):
        raise RuntimeError('Invalid Big LaMa model checksum')
    model = await run_in_threadpool(BigLaMa, path)
    yield
    model = None

app = FastAPI(lifespan=lifespan, docs_url=None, redoc_url=None, openapi_url=None)

@app.get('/health')
def health():
    return {'ready': model is not None, 'model': 'Big LaMa', 'revision': SPEC['revision'], 'protocol': 1}

def image(data, *, mask=False):
    try:
        value = Image.open(io.BytesIO(data))
        w, h = value.size
        if value.format != 'PNG' or min(w, h) < 24 or max(w, h) > 4096 or w*h > 4_194_304:
            raise ValueError()
        value.load()
        return value.convert('L' if mask else 'RGB')
    except (ValueError, UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise HTTPException(422, 'invalid_image')

@app.post('/v1/restore')
async def restore(request: Request):
    expected = 'Bearer ' + os.environ.get('RESTORATION_ORIGIN_TOKEN', '')
    if not hmac.compare_digest(request.headers.get('authorization', ''), expected):
        raise HTTPException(401, 'unauthorized')
    chunks, size = [], 0
    async for chunk in request.stream():
        size += len(chunk)
        if size > MAX_BODY:
            raise HTTPException(413, 'region_too_large')
        chunks.append(chunk)
    # JSON base64 is intentionally avoided; binary PNGs stay bounded.
    from python_multipart.multipart import parse_options_header, MultipartParser
    content_type, options = parse_options_header(request.headers.get('content-type', ''))
    if content_type != b'multipart/form-data' or b'boundary' not in options:
        raise HTTPException(415, 'multipart_required')
    fields = {}
    part = {'name': None, 'data': bytearray(), 'header': bytearray(), 'value': bytearray()}
    headers = {}
    def begin():
        part.update(name=None, data=bytearray(), header=bytearray(), value=bytearray());headers.clear()
    def header_field(data, start, end): part['header'].extend(data[start:end])
    def header_value(data, start, end): part['value'].extend(data[start:end])
    def header_end():
        headers[bytes(part['header']).lower()] = bytes(part['value']);part['header'].clear();part['value'].clear()
    def headers_finished():
        _, disposition = parse_options_header(headers.get(b'content-disposition', b''));part['name'] = disposition.get(b'name', b'').decode('ascii', errors='ignore')
    def data(data, start, end):
        if part['name'] in ('image', 'mask'):part['data'].extend(data[start:end])
    def end():
        if part['name'] in ('image', 'mask'):
            if part['name'] in fields:raise ValueError('Duplicate image part')
            fields[part['name']] = bytes(part['data'])
    parser = MultipartParser(options[b'boundary'], {'on_part_begin': begin, 'on_header_field': header_field, 'on_header_value': header_value, 'on_header_end': header_end, 'on_headers_finished': headers_finished, 'on_part_data': data, 'on_part_end': end})
    try:
        for chunk in chunks:parser.write(chunk)
        parser.finalize()
    except Exception:
        raise HTTPException(422, 'invalid_multipart')
    if set(fields) != {'image', 'mask'}:
        raise HTTPException(422, 'missing_image_or_mask')
    source, selection = image(fields['image']), image(fields['mask'], mask=True)
    if source.size != selection.size:
        raise HTTPException(422, 'dimensions_do_not_match')
    try:
        patch = await run_in_threadpool(model.repair, source, selection)
    except BlockingIOError:
        raise HTTPException(429, 'restoration_busy', headers={'Retry-After': '5'})
    except ValueError:
        raise HTTPException(422, 'invalid_mask')
    out = io.BytesIO();patch.save(out, format='PNG')
    return Response(out.getvalue(), media_type='image/png', headers={'Cache-Control': 'no-store', 'X-Cookies-Model': 'big-lama-onnx-512', 'X-Cookies-Source-SHA256': hashlib.sha256(fields['image']).hexdigest()})
