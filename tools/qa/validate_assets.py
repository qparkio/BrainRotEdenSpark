"""Validate baked model bounds, feet, alpha atlas cells, and import settings."""
import hashlib
import json
import re
import struct
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def validate():
    slugs = re.findall(r'"([a-z0-9_]+)"', (ROOT/'brainrot_files.das').read_text())
    heights = [float(x) for x in re.search(r'fixed_array\(([^)]+)\)', (ROOT/'brainrot_bounds.das').read_text())[1].split(',')]
    assert len(slugs) == len(heights) == 56
    models = []
    for slug, target in zip(slugs, heights):
        path = ROOT/'assets/brainrots'/f'{slug}.glb'
        data = path.read_bytes()
        magic, version, total = struct.unpack_from('<III', data)
        assert magic == 0x46546C67 and version == 2 and total == len(data), path
        length, kind = struct.unpack_from('<II', data, 12)
        assert kind == 0x4E4F534A, path
        document = json.loads(data[20:20+length])
        primitive = document['meshes'][0]['primitives'][0]
        accessor = document['accessors'][primitive['attributes']['POSITION']]
        low, high = accessor['min'], accessor['max']
        assert abs(low[1]) < 1e-5, f'{slug}: feet not at zero'
        assert abs(high[1]-low[1]-target) < 1e-4, f'{slug}: stale height table'
        assert document.get('images'), f'{slug}: palette missing'
        assert len(data) < 3_000_000, f'{slug}: unexpected asset size'
        models.append({'name': slug, 'height': target, 'width': high[0]-low[0], 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    assert len({m['sha256'] for m in models}) == 56, 'Duplicated model bytes'
    atlases = []
    for name, count, cols, tileHeight in [('brainrot', 56, 8, 256), ('gear', 11, 4, 256), ('base', 12, 4, 128)]:
        path = ROOT/'assets/ui'/f'{name}_atlas.png'
        atlas = Image.open(path)
        assert atlas.mode == 'RGBA' and atlas.size == (cols*256, ((count+cols-1)//cols)*tileHeight), path
        for i in range(count):
            alpha = atlas.crop((i%cols*256, i//cols*tileHeight, (i%cols+1)*256, (i//cols+1)*tileHeight)).getchannel('A')
            bounds = alpha.getbbox()
            assert bounds and 0 < bounds[0] < bounds[2] < 256 and 0 < bounds[1] < bounds[3] < tileHeight, f'{name} {i}: missing or clipped thumbnail'
        meta = path.with_suffix('.png.meta').read_text()
        assert 'addressing:t="Clamp"' in meta and 'generateMipLevels:b=no' in meta
        atlases.append({'name': name, 'cells': count, 'size': atlas.size})
    for name in ('studs', 'tiles', 'portal'):
        meta = (ROOT/'assets/textures'/f'{name}.png.meta').read_text()
        assert 'filter:t="Bilinear"' in meta and 'addressing:t="Wrap"' in meta and 'generateMipLevels:b=yes' in meta
    logo_path = ROOT/'assets/textures/eden_logo.png'
    logo = Image.open(logo_path)
    assert logo.size == (512, 512) and logo.mode == 'RGBA'
    assert logo.getchannel('A').getextrema() == (0, 255), 'Logo transparency missing'
    logo_meta = logo_path.with_suffix('.png.meta').read_text()
    assert 'filter:t="Bilinear"' in logo_meta and 'addressing:t="Clamp"' in logo_meta and 'generateMipLevels:b=yes' in logo_meta
    return {'models': models, 'atlases': atlases, 'result': 'passed'}


if __name__ == '__main__':
    result = validate()
    output = ROOT/'tools/qa/asset_validation.json'
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    print(f'Passed: 56 unique GLBs with matching bounds, 79 unclipped thumbnails, 3 UI atlases, 3 world textures and the EdenSpark logo. {output}')
