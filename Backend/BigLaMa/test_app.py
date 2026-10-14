import io, os, pathlib, sys
import numpy as np
from PIL import Image
from fastapi.testclient import TestClient
import app as module

ROOT = pathlib.Path(__file__).resolve().parents[2]
os.environ['RESTORATION_ORIGIN_TOKEN'] = 'test-only-private-origin-token'
os.environ['LAMA_MODEL_PATH'] = str(ROOT / '.work/big-lama-fp32.onnx')

def png(image):
    out = io.BytesIO();image.save(out, format='PNG');return out.getvalue()

def test_real_model_http_contract_and_pixel_protection():
    with TestClient(module.app) as client:
        assert client.get('/health').json()['ready']
        assert client.post('/v1/restore').status_code == 401
        directory = ROOT / '.work/lama-labelled'
        source = Image.open(directory / 'asura-white-spiked-bubble-source.png').convert('RGB')
        mask = Image.open(directory / 'asura-white-spiked-bubble-mask.png').convert('L')
        headers = {'authorization': 'Bearer ' + os.environ['RESTORATION_ORIGIN_TOKEN']}
        files = {'image': ('source.png', png(source), 'image/png'), 'mask': ('mask.png', png(mask), 'image/png')}
        response = client.post('/v1/restore', headers=headers, files=files)
        assert response.status_code == 200, response.text[:100] if response.status_code != 200 else ''
        patch = np.asarray(Image.open(io.BytesIO(response.content)).convert('RGBA'))
        selected = np.asarray(mask) > 0
        assert not patch[~selected, 3].any()
        assert patch[selected, :3].mean() > 240
        assert ((patch[selected, :3].max(axis=1)) < 160).mean() < .02
        assert response.headers['cache-control'] == 'no-store'
        wrong = client.post('/v1/restore', headers=headers, files={'image': files['image'], 'mask': ('bad.png', png(Image.new('L', (24, 24))), 'image/png')})
        assert wrong.status_code == 422
        assert client.post('/v1/restore', headers=headers, content=b'not a multipart').status_code == 415
