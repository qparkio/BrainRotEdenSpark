"""Generates the tileable Roblox-style textures (studs, paving tiles, window glass) used by the map.

Usage: python gen_textures.py <output_dir>
Every texture is grayscale-ish and tinted in game with the mesh color.
"""
import sys
import math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 256


def studs(n=4, base=238, stud_hi=252, stud_lo=214):
    """Subtle raised square studs, matching the reference's classic baseplates."""
    img = Image.new("RGB", (SIZE, SIZE), (base, base, base))
    d = ImageDraw.Draw(img)
    cell = SIZE // n
    for iy in range(n):
        for ix in range(n):
            cx = ix * cell + cell // 2
            cy = iy * cell + cell // 2
            r = int(cell * 0.34)
            d.rectangle((cx-r+2,cy-r+3,cx+r+2,cy+r+3),fill=(stud_lo,)*3)
            d.rectangle((cx-r,cy-r,cx+r,cy+r),fill=(stud_hi,)*3)
            d.line((cx-r,cy+r,cx-r,cy-r,cx+r,cy-r),fill=(255,)*3,width=2)
            d.line((cx+r,cy-r,cx+r,cy+r,cx-r,cy+r),fill=(220,)*3,width=2)
    return img.filter(ImageFilter.GaussianBlur(0.6))


def tiles(n=2):
    """Large paving tiles with dark seams and a little stud in the corner."""
    img = Image.new("RGB", (SIZE, SIZE), (215, 215, 215))
    d = ImageDraw.Draw(img)
    cell = SIZE // n
    for iy in range(n):
        for ix in range(n):
            x0, y0 = ix * cell, iy * cell
            d.rectangle((x0, y0, x0 + cell - 1, y0 + cell - 1), outline=(120, 120, 124), width=4)
            d.rectangle((x0 + 5, y0 + 5, x0 + cell - 6, y0 + cell - 6), outline=(240, 240, 242), width=2)
            cx, cy = x0 + cell // 2, y0 + cell // 2
            r = int(cell * 0.16)
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(190, 190, 194))
            d.ellipse((cx - r + 2, cy - r + 2, cx + r - 3, cy + r - 3), fill=(245, 245, 248))
    return img.filter(ImageFilter.GaussianBlur(0.5))


def glass():
    """Window glass with a soft diagonal sheen."""
    img = Image.new("RGB", (SIZE, SIZE), (150, 190, 215))
    d = ImageDraw.Draw(img)
    for i in range(-SIZE, SIZE * 2, 64):
        d.polygon([(i, 0), (i + 26, 0), (i + 26 - SIZE // 2, SIZE), (i - SIZE // 2, SIZE)], fill=(185, 220, 240))
    return img.filter(ImageFilter.GaussianBlur(1.0))


def write_meta(path, guid, filt):
    with open(path + ".meta", "w", encoding="utf-8") as f:
        f.write(
            f'guid:t="{guid}"\nassetType:i=0\nfilter:t="{filt}"\naddressing:t="Wrap"\n'
            f'anisotropicLevel:i=4\ngenerateMipLevels:b=yes\nusage:t="Color"\ncompressTexture:b=no\n'
        )


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    items = {
        "studs.png": (studs(4), "0199a000-0000-7000-8000-000000000001", "Bilinear"),
        "studs_big.png": (studs(2), "0199a000-0000-7000-8000-000000000002", "Bilinear"),
        "tiles.png": (tiles(2), "0199a000-0000-7000-8000-000000000003", "Bilinear"),
        "glass.png": (glass(), "0199a000-0000-7000-8000-000000000004", "Bilinear"),
    }
    for name, (img, guid, filt) in items.items():
        path = f"{out}/{name}"
        img.save(path)
        write_meta(path, guid, filt)
        print("wrote", path)


if __name__ == "__main__":
    main()
