#!/usr/bin/env python3
"""Fetch the exact upstream ONNX SPM source without an unbounded Git clone.

The source tarball and the binary checksums inside its unchanged Package.swift
are pinned independently. No third-party source or binary is committed.
"""
import hashlib
import io
import pathlib
import shutil
import tarfile
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = 'https://codeload.github.com/microsoft/onnxruntime-swift-package-manager/tar.gz/refs/tags/1.24.2'
SHA = '2efe4fc48eb43400daa0caffd7d1e1289492d64a87f5a2b7a98dfdcb8176d703'
DEST = ROOT / '.work/SwiftPackages/ONNXRuntime'
STAMP = DEST / '.cookies-source-sha256'


def prepare():
    if STAMP.is_file() and STAMP.read_text().strip() == SHA and (DEST / 'Package.swift').is_file():
        return
    request = urllib.request.Request(URL, headers={'User-Agent': 'CookiesEditor-build'})
    with urllib.request.urlopen(request, timeout=45) as response:
        data = response.read(2 * 1024 * 1024 + 1)
    if len(data) > 2 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != SHA:
        raise RuntimeError('Pinned ONNX SPM source checksum mismatch')
    DEST.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=DEST.parent, prefix='.onnx-') as scratch:
        stage = pathlib.Path(scratch)
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            members = archive.getmembers()
            if any(m.issym() or m.islnk() or not (m.isfile() or m.isdir()) or '..' in pathlib.PurePosixPath(m.name).parts or m.name.startswith('/') for m in members):
                raise RuntimeError('Unsafe upstream package archive')
            archive.extractall(stage, filter='data')
        folders = list(stage.iterdir())
        if len(folders) != 1 or not (folders[0] / 'Package.swift').is_file():
            raise RuntimeError('Missing upstream ONNX package manifest')
        if DEST.exists():
            shutil.rmtree(DEST)
        shutil.move(str(folders[0]), DEST)
    STAMP.write_text(SHA + '\n')
    print('Pinned ONNX Runtime 1.24.2 SPM source ready; official binary checksums retained')


if __name__ == '__main__':
    prepare()
