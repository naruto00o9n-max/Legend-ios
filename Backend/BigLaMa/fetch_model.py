"""Immutable public Big LaMa export; never execute downloaded Python code."""
import hashlib, json, os, pathlib, tempfile, urllib.request

SPEC = json.loads(pathlib.Path(__file__).with_name('model.json').read_text())

def fetch(destination: pathlib.Path):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and verify(destination):
        return
    url = f"https://huggingface.co/{SPEC['repository']}/resolve/{SPEC['revision']}/{SPEC['file']}"
    temporary = destination.with_suffix('.download')
    try:
        with urllib.request.urlopen(url, timeout=180) as response, temporary.open('wb') as out:
            while block := response.read(1024 * 1024):
                out.write(block)
        if not verify(temporary):
            raise RuntimeError('Big LaMa integrity check failed')
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)

def verify(path):
    if path.stat().st_size != SPEC['size']:
        return False
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest() == SPEC['sha256']

if __name__ == '__main__':
    fetch(pathlib.Path(os.environ.get('LAMA_MODEL_PATH', '/models/big-lama.onnx')))
