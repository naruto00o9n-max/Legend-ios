"""Sequential native-resolution windows; only selected text pixels can change."""
import os, threading
import numpy as np
import onnxruntime as ort
from PIL import Image

EXTENT, OVERLAP = 512, 64

def origins(length, lower=None, upper=None):
    if length <= EXTENT:
        return [-((EXTENT - length) // 2)]
    if lower is not None and upper-lower+1 <= EXTENT:
        return [max(0, min(length-EXTENT, (lower+upper+1-EXTENT)//2))]
    result = list(range(0, length - EXTENT, EXTENT - OVERLAP))
    if not result or result[-1] != length - EXTENT:
        result.append(length - EXTENT)
    return result

class BigLaMa:
    def __init__(self, path):
        options = ort.SessionOptions()
        options.intra_op_num_threads = int(os.environ.get('LAMA_THREADS', '2'))
        options.inter_op_num_threads = 1
        options.enable_cpu_mem_arena = False
        options.enable_mem_pattern = False
        options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        self.session = ort.InferenceSession(str(path), sess_options=options, providers=['CPUExecutionProvider'])
        self.lock = threading.Lock()
        if {v.name for v in self.session.get_inputs()} != {'image', 'mask'}:
            raise RuntimeError('Unexpected Big LaMa model inputs')

    def repair(self, source, mask):
        image = np.asarray(source.convert('RGB'), dtype=np.uint8)
        hole = np.asarray(mask.convert('L'), dtype=np.uint8) > 0
        height, width = hole.shape
        if image.shape[:2] != hole.shape or width * height > 4_194_304:
            raise ValueError('Invalid restoration dimensions')
        if not hole.any():
            raise ValueError('Empty text mask')
        if not self.lock.acquire(blocking=False):
            raise BlockingIOError('Restoration is busy')
        try:
            total = np.zeros((height, width, 3), dtype=np.float32)
            weights = np.zeros((height, width), dtype=np.float32)
            axis = np.minimum(np.arange(1, EXTENT + 1), np.arange(EXTENT, 0, -1))
            feather = np.minimum(1.0, np.minimum(axis[:, None], axis[None, :]) / OVERLAP).astype(np.float32)
            xx_mask = np.flatnonzero(hole.any(axis=0));yy_mask = np.flatnonzero(hole.any(axis=1))
            for y in origins(height, int(yy_mask[0]), int(yy_mask[-1])):
                for x in origins(width, int(xx_mask[0]), int(xx_mask[-1])):
                    x0, y0, x1, y1 = max(0, x), max(0, y), min(width, x + EXTENT), min(height, y + EXTENT)
                    if not hole[y0:y1, x0:x1].any():
                        continue
                    xx = np.clip(np.arange(x, x + EXTENT), 0, width - 1)
                    yy = np.clip(np.arange(y, y + EXTENT), 0, height - 1)
                    tile = image[yy[:, None], xx[None, :]].astype(np.float32).transpose(2, 0, 1)[None] / 255.0
                    selection = np.zeros((EXTENT, EXTENT), dtype=np.float32)
                    tx, ty = x0 - x, y0 - y
                    selection[ty:ty + y1-y0, tx:tx + x1-x0] = hole[y0:y1, x0:x1]
                    fill = self.session.run(['output'], {'image': tile, 'mask': selection[None, None]})[0][0].transpose(1, 2, 0)
                    if not np.isfinite(fill).all():
                        raise ValueError('Non-finite model output')
                    part = fill[ty:ty+y1-y0, tx:tx+x1-x0]
                    blend = feather[ty:ty+y1-y0, tx:tx+x1-x0] * hole[y0:y1, x0:x1]
                    total[y0:y1, x0:x1] += part * blend[..., None]
                    weights[y0:y1, x0:x1] += blend
            patch = np.zeros((height, width, 4), dtype=np.uint8)
            patch[hole, :3] = np.clip(np.rint(total[hole] / weights[hole, None]), 0, 255).astype(np.uint8)
            patch[hole, 3] = 255
            return Image.fromarray(patch)
        finally:
            self.lock.release()
