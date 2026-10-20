"""Bake the portal texture and persistent materials for the arena and bases."""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GUIDS = {
    'glass': '01a104a5-32bc-70ee-8f22-babcba8aff52',
    'plastic': '01a104a5-32bc-7b2b-b6b8-3d636dba8781',
    'glow': '01a104a5-32bc-7c4e-abdc-335c050dd790',
    'portal': '01a104a5-32bc-77f8-8b98-738407ebc9c2',
    'texture': '01a104a5-32bc-71e0-ae5c-c4dc91a98ec3',
}


def property_block(name, value):
    if isinstance(value, int):
        variant, field = 2, f'i:i={value}'
    elif isinstance(value, tuple):
        variant, field = 1, 'f4:p4=' + ', '.join(map(str, value))
    else:
        variant, field = 0, f'f:r={value}'
    return f'{name}{{\n__variant_index:i={variant}\n{field}\n}}\n'


def material(name, shader, properties, texture=None):
    textures = ''.join(
        f'it{{\nguid:t="{texture}"\ntype:i=2\n}}\n' if i == 0 and texture else 'it{}\n'
        for i in range(6)
    )
    text = f'shader:t="{shader}"\ntextures{{\n{textures}}}\nproperties{{\n'
    text += ''.join(property_block(k, v) for k, v in properties.items()) + '}\n'
    path = ROOT/'assets/materials'/f'{name}.material'
    path.write_text(text, encoding='utf8', newline='\n')
    path.with_suffix('.material.meta').write_text(f'guid:t="{GUIDS[name]}"\nassetType:i=2\n', encoding='utf8')


def main():
    image = Image.new('RGBA', (256, 256))
    for y in range(256):
        for x in range(256):
            u, v = x/255, y/256
            edge = math.exp(-min(u, 1-u)*18)
            mist = (math.sin(v*math.tau*3 + math.sin(u*math.tau)*1.8) + 1)*.5
            detail = (math.sin(u*math.tau*9-v*math.tau*2) + 1)*.5
            glow = edge*(.65+.35*mist) + .07*mist*detail
            image.putpixel((x, y), (int(6+65*glow), int(4+24*glow), int(14+90*glow), 255))
    path = ROOT/'assets/textures/portal.png'
    image.save(path)
    path.with_suffix('.png.meta').write_text(
        f'guid:t="{GUIDS["texture"]}"\nassetType:i=0\nfilter:t="Bilinear"\naddressing:t="Wrap"\n'
        'anisotropicLevel:i=4\ngenerateMipLevels:b=yes\nusage:t="Color"\ncompressTexture:b=no\n', encoding='utf8')
    common = {'faceCullMode': 1, 'color': (1, 1, 1, 1)}
    material('glass', 'standard_specular_shader', {**common, 'faceCullMode': 0, 'transparencyMode': 1, 'specularColor': (.25, .3, .35, 1), 'glossiness': .65})
    material('plastic', 'standard_specular_shader', {**common, 'specularColor': (.12, .12, .12, 1), 'glossiness': .55})
    material('glow', 'standard_unlit_shader', common)
    material('portal', 'standard_unlit_shader', {**common, 'faceCullMode': 0}, GUIDS['texture'])
    print('Created portal.png and 4 persistent materials')


if __name__ == '__main__':
    main()
