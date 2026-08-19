"""Gera favicon + ícones PWA no padrão da marca (AuthScaffold._brand):
quadrado laranja #E8833A, raio ~27%, Icons.grass em #2A1806.
Uso: python tool/gen_icons.py <materialicons-regular.otf>
"""
import sys
from PIL import Image, ImageDraw, ImageFont

FONT = sys.argv[1]
ACCENT, ON_ACCENT = (0xE8, 0x83, 0x3A, 255), (0x2A, 0x18, 0x06, 255)
GRASS = "\ue2e4"  # Icons.grass

def tile(size, maskable=False):
    s = size * 4  # supersample
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if maskable:
        d.rectangle([0, 0, s, s], fill=ACCENT)   # bleed total, safe zone 80%
        glyph = int(s * 0.46)
    else:
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 14 / 52), fill=ACCENT)
        glyph = int(s * 30 / 52)
    f = ImageFont.truetype(FONT, glyph)
    l, t, r, b = d.textbbox((0, 0), GRASS, font=f)
    d.text(((s - (r - l)) / 2 - l, (s - (b - t)) / 2 - t), GRASS, font=f, fill=ON_ACCENT)
    return img.resize((size, size), Image.LANCZOS)

tile(64).save("web/favicon.png")
for n in (192, 512):
    tile(n).save(f"web/icons/Icon-{n}.png")
    tile(n, maskable=True).save(f"web/icons/Icon-maskable-{n}.png")
print("ok")
