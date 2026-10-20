"""Pack Blender renders with alpha unchanged; write Eden texture import metadata."""
from pathlib import Path
from PIL import Image
import sys
import uuid

out = Path(sys.argv[1]) / 'assets/ui'
def meta(path):
    if path.with_suffix(path.suffix + '.meta').exists():
        return
    path.with_suffix(path.suffix + '.meta').write_text(
        f'guid:t="{uuid.uuid4()}"\nassetType:i=0\nfilter:t="Bilinear"\naddressing:t="Clamp"\nanisotropicLevel:i=1\ngenerateMipLevels:b=no\nusage:t="Color"\ncompressTexture:b=no\n', encoding='utf8')

for name, count, cols, tileHeight in [('brainrot', 56, 8, 256), ('gear', 11, 4, 256), ('base', 12, 4, 128)]:
    rows = (count + cols - 1) // cols
    sheet = Image.new('RGBA', (cols*256, rows*tileHeight))
    for i in range(count):
        tile = Image.open(out / 'renders' / f'{name}_{i:02d}.png').convert('RGBA')
        sheet.paste(tile, ((i % cols)*256, (i // cols)*tileHeight))
    path = out / f'{name}_atlas.png'
    sheet.save(path)
    meta(path)
    print(path, sheet.size)
meta(out/'navigation.png')
