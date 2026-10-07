"""Генератор иконок запуска приложения Kommunalka (Этап 7.6).

Рисует логотип (домик на фирменном teal-фоне) и сохраняет PNG во всех
плотностях Android (mipmap-*), а также foreground для адаптивной иконки
(Android 8+, mipmap-anydpi-v26).

Чистый Python 3 (только стандартная библиотека: zlib/struct) — в среде нет
Pillow/cairosvg, поэтому PNG собирается вручную. Скрипт идемпотентен:
повторный запуск перезаписывает те же файлы теми же байтами.

Запуск: python tools/make_launcher_icons.py
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

# Фирменный цвет — совпадает с seed-цветом темы (Colors.teal).
BRAND_TEAL = (0x00, 0x89, 0x8B)  # #00898B
BRAND_TEAL_DARK = (0x00, 0x6B, 0x6D)  # #006B6D (для мягкого градиента)
WHITE = (0xFF, 0xFF, 0xFF)
TRANSPARENT = (0, 0, 0, 0)

REPO_ROOT = Path(__file__).resolve().parent.parent
ANDROID_RES = REPO_ROOT / "android" / "app" / "src" / "main" / "res"

# Плотности Android: имя папки -> размер стороны в пикселях.
DENSITIES: dict[str, int] = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def _write_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    """Собирает PNG (RGBA, 8 бит) из готового буфера пикселей."""

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    # Каждая строка предваряется байтом фильтра 0 (None).
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = bytearray()
    png += b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def _rounded_rect_sdf(x: float, y: float, w: float, h: float, r: float) -> float:
    """Знаковая дистанция до скруглённого прямоугольника (в пикселях)."""
    cx, cy = w / 2.0, h / 2.0
    dx = abs(x - cx) - (cx - r)
    dy = abs(y - cy) - (cy - r)
    ax, ay = max(dx, 0.0), max(dy, 0.0)
    outside = (ax * ax + ay * ay) ** 0.5
    inside = min(max(dx, dy), 0.0)
    return outside + inside - r


def _coverage(sdf: float, aa: float) -> float:
    """Сглаженная альфа по знаковой дистанции."""
    if sdf <= -aa:
        return 1.0
    if sdf >= aa:
        return 0.0
    return (aa - sdf) / (2 * aa)


def _point_seg_dist(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
    """Расстояние от точки до отрезка."""
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    seg = vx * vx + vy * vy
    t = 0.0 if seg == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / seg))
    cx, cy = ax + t * vx, ay + t * vy
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5


def _draw_icon(size: int, background: bool) -> bytearray:
    """Растеризует логотип с аналитическим сглаживанием (1 проход по пикселям).

    background=True  — фирменный фон с белым домиком (ic_launcher legacy);
    background=False — только белый домик на прозрачном фоне
                       (ic_launcher_foreground для адаптивной иконки).
    """
    cell = 1.0 / size  # размер пикселя в долях размера иконки
    aa = 0.9 * cell  # ширина полосы сглаживания в долях
    # Толщина крыши/линий в долях; для больших иконок линия тоньше не нужна.

    roof_apex = (0.50, 0.24)
    roof_left = (0.17, 0.50)
    roof_right = (0.83, 0.50)
    roof_thickness = 0.055

    body_left, body_right = 0.28, 0.72
    body_top, body_bottom = 0.50, 0.80

    door_left, door_right = 0.45, 0.55
    door_top, door_bottom = 0.62, 0.80

    radius = 0.22  # скругление фона в долях
    out = bytearray(size * size * 4)

    for y in range(size):
        ny = (y + 0.5) / size
        crow = y * size * 4
        for x in range(size):
            nx = (x + 0.5) / size
            o = crow + x * 4

            if background:
                sdf = _rounded_rect_sdf(nx * size, ny * size, size, size, radius * size)
                cov_bg = _coverage(sdf, aa * size)
                if cov_bg <= 0:
                    out[o : o + 4] = TRANSPARENT
                    continue
                t = ny
                r = round(BRAND_TEAL[0] * (1 - t) + BRAND_TEAL_DARK[0] * t)
                g = round(BRAND_TEAL[1] * (1 - t) + BRAND_TEAL_DARK[1] * t)
                b = round(BRAND_TEAL[2] * (1 - t) + BRAND_TEAL_DARK[2] * t)
            else:
                r = g = b = 0
                cov_bg = 0

            # --- Домик: считаем покрытие по расстоянию до контура ---
            d_roof = min(
                _point_seg_dist(nx, ny, *roof_left, *roof_right),
                _point_seg_dist(nx, ny, *roof_left, *roof_apex),
                _point_seg_dist(nx, ny, *roof_apex, *roof_right),
            ) - roof_thickness
            d_body = max(body_left - nx, nx - body_right, body_top - ny, ny - body_bottom)
            # квадрат: внутри, если все четыре разности <= 0 → берём максимум
            d_house = min(d_roof, d_body)

            # Дверь — вычитаем. d_door <= 0 внутри двери (как и остальные SDF).
            d_door = max(door_left - nx, nx - door_right, door_top - ny, ny - door_bottom)

            cov_house = _coverage(d_house, aa)
            cov_door = _coverage(d_door, aa)
            cov_white = cov_house * (1.0 - cov_door)
            if cov_white <= 0:
                cov_white = 0.0

            if background:
                # белый поверх teal-фона
                r = round(r * (1 - cov_white) + WHITE[0] * cov_white)
                g = round(g * (1 - cov_white) + WHITE[1] * cov_white)
                b = round(b * (1 - cov_white) + WHITE[2] * cov_white)
                out[o] = r
                out[o + 1] = g
                out[o + 2] = b
                out[o + 3] = round(255 * cov_bg)
            else:
                out[o] = WHITE[0]
                out[o + 1] = WHITE[1]
                out[o + 2] = WHITE[2]
                out[o + 3] = round(255 * cov_white)

    return out



def _generate_legacy() -> list[Path]:
    written: list[Path] = []
    for folder, size in DENSITIES.items():
        path = ANDROID_RES / folder / "ic_launcher.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        _write_png(path, size, size, _draw_icon(size, background=True))
        written.append(path)
    return written


def _generate_foreground() -> list[Path]:
    # Adaptive-icon foreground: 108dp canvas, safe zone ~66dp. Домик рисуем
    # в центре, оставляя поля (foreground рисуется с запасом под обрезку).
    written: list[Path] = []
    fg_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }
    for folder, size in fg_sizes.items():
        path = ANDROID_RES / folder / "ic_launcher_foreground.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        _write_png(path, size, size, _draw_icon(size, background=False))
        written.append(path)
    return written


def main() -> None:
    for p in _generate_legacy() + _generate_foreground():
        print(f"written {p.relative_to(REPO_ROOT)} ({p.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
