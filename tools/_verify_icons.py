"""Проверка сгенерированных иконок: валидность PNG + ASCII-превью (Этап 7.6).

Запуск: python tools/_verify_icons.py
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RES = REPO_ROOT / "android" / "app" / "src" / "main" / "res"


def read_png(path: Path) -> tuple[int, int, bytearray]:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{path}: bad signature"
    pos = 8
    width = height = 0
    idat = bytearray()
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        tag = data[pos + 4 : pos + 8]
        payload = data[pos + 8 : pos + 8 + length]
        if tag == b"IHDR":
            width, height = struct.unpack(">II", payload[:8])
        elif tag == b"IDAT":
            idat += payload
        pos += 12 + length
    raw = zlib.decompress(bytes(idat))
    stride = width * 4 + 1
    out = bytearray(width * height * 4)
    for y in range(height):
        assert raw[y * stride] == 0, f"{path}: unsupported filter"
        out[y * width * 4 : (y + 1) * width * 4] = raw[y * stride + 1 : (y + 1) * stride]
    return width, height, out


def preview(path: Path, cols: int = 32) -> None:
    width, height, px = read_png(path)
    print(f"\n{path.name}  {width}x{height}")
    for gy in range(cols):
        line = ""
        for gx in range(cols):
            x = int((gx + 0.5) / cols * width)
            y = int((gy + 0.5) / cols * height)
            i = (y * width + x) * 4
            r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
            if a < 128:
                line += "."  # прозрачный
            elif r > 200 and g > 200 and b > 200:
                line += "#"  # белый (домик)
            else:
                line += "o"  # teal-фон
        print(line)


def main() -> None:
    preview(RES / "mipmap-xxxhdpi" / "ic_launcher.png")
    preview(RES / "mipmap-xxxhdpi" / "ic_launcher_foreground.png")
    # Валидность всех файлов
    for grp in ("mipmap-mdpi", "mipmap-hdpi", "mipmap-xhdpi", "mipmap-xxhdpi", "mipmap-xxxhdpi"):
        for name in ("ic_launcher.png", "ic_launcher_foreground.png"):
            p = RES / grp / name
            w, h, _ = read_png(p)
            print(f"OK {grp}/{name} {w}x{h} {p.stat().st_size}B")


if __name__ == "__main__":
    main()
