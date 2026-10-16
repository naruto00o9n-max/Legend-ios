#!/usr/bin/env python3
"""Pin official SPM sources without unbounded Git history downloads.

Unchanged upstream Package.swift files retain their own binary checksums.
Third-party source/binaries stay in .work and are never committed.
"""
import hashlib
import io
import pathlib
import shutil
import tarfile
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPECS = [
    ('ONNXRuntime', 'https://codeload.github.com/microsoft/onnxruntime-swift-package-manager/tar.gz/refs/tags/1.24.2',
     '2efe4fc48eb43400daa0caffd7d1e1289492d64a87f5a2b7a98dfdcb8176d703', 2 * 1024 * 1024),
    ('ZIPFoundation', 'https://codeload.github.com/weichsel/ZIPFoundation/tar.gz/refs/tags/0.9.19',
     '29ed1147f6e1a065257999eca46a10326caee10248d197654ca2f8d044b11628', 32 * 1024 * 1024),
]


def prepare_one(name, url, digest, limit):
    dest = ROOT / '.work/SwiftPackages' / name
    stamp = dest / '.cookies-source-sha256'
    if stamp.is_file() and stamp.read_text().strip() == digest and (dest / 'Package.swift').is_file():
        return
    request = urllib.request.Request(url, headers={'User-Agent': 'CookiesEditor-build'})
    with urllib.request.urlopen(request, timeout=45) as response:
        data = response.read(limit + 1)
    if len(data) > limit or hashlib.sha256(data).hexdigest() != digest:
        raise RuntimeError(f'Pinned {name} SPM source checksum mismatch')
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dest.parent, prefix='.package-') as scratch:
        stage = pathlib.Path(scratch)
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            members = archive.getmembers()
            if sum(m.size for m in members) > 128 * 1024 * 1024 or any(m.issym() or m.islnk() or not (m.isfile() or m.isdir()) or '..' in pathlib.PurePosixPath(m.name).parts or m.name.startswith('/') for m in members):
                raise RuntimeError('Unsafe upstream package archive')
            archive.extractall(stage, filter='data')
        folders = list(stage.iterdir())
        if len(folders) != 1 or not (folders[0] / 'Package.swift').is_file():
            raise RuntimeError('Missing upstream package manifest')
        if dest.exists():
            shutil.rmtree(dest)
        shutil.move(str(folders[0]), dest)
    stamp.write_text(digest + '\n')
    print(f'Pinned {name} SPM source ready; upstream manifest unchanged')


def prepare():
    for spec in SPECS:
        prepare_one(*spec)


if __name__ == '__main__':
    prepare()
