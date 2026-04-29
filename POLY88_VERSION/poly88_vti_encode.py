
#!/usr/bin/env python3
"""
poly88_vti_encode_no_pil.py

Convert a BMP into POLY-88 VTI 2x3 character bytes without Pillow.

Supports uncompressed BMP files with bit depths:
    1, 4, 8, 24, 32 bpp

For indexed BMPs (1/4/8 bpp), the palette luminance is used to decide
whether a pixel is dark or light.
For 24/32 bpp BMPs, RGB luminance is used directly.

POLY-88 VTI 2x3 bit layout:

    TL TR
    ML MR
    BL BR

    value = (BR<<0) | (MR<<1) | (TR<<2) | (BL<<3) | (ML<<4) | (TL<<5)

Default behavior:
    dark pixel   => set bit (1)
    light pixel  => clear bit (0)

Use --invert to reverse that.

Examples:
    python poly88_vti_encode_no_pil.py art.bmp
    python poly88_vti_encode_no_pil.py art.bmp --db-per-row
    python poly88_vti_encode_no_pil.py art.bmp --invert
"""

from __future__ import annotations

import argparse
import struct
from pathlib import Path
from typing import List, Tuple


def read_bmp(path: Path) -> List[List[int]]:
    with open(path, "rb") as f:
        data = f.read()

    if len(data) < 54 or data[0:2] != b"BM":
        raise SystemExit("Not a BMP file.")

    file_size = struct.unpack_from("<I", data, 2)[0]
    pixel_offset = struct.unpack_from("<I", data, 10)[0]
    dib_size = struct.unpack_from("<I", data, 14)[0]

    if file_size > len(data):
        # Some BMP writers leave this inconsistent; do not hard-fail.
        file_size = len(data)

    if dib_size < 40:
        raise SystemExit(f"Unsupported DIB header size: {dib_size}")

    width = struct.unpack_from("<i", data, 18)[0]
    height_raw = struct.unpack_from("<i", data, 22)[0]
    planes = struct.unpack_from("<H", data, 26)[0]
    bpp = struct.unpack_from("<H", data, 28)[0]
    compression = struct.unpack_from("<I", data, 30)[0]
    colors_used = struct.unpack_from("<I", data, 46)[0]

    if planes != 1:
        raise SystemExit(f"Unsupported BMP planes value: {planes}")
    if compression != 0:
        raise SystemExit("Only uncompressed BMP files are supported.")

    top_down = height_raw < 0
    height = abs(height_raw)

    if width <= 0 or height <= 0:
        raise SystemExit(f"Invalid BMP size: {width}x{height}")

    # Palette handling for indexed images.
    palette: List[int] = []
    if bpp <= 8:
        if colors_used == 0:
            colors_used = 1 << bpp
        palette_offset = 14 + dib_size
        entry_size = 4  # standard BMP palette entries: B,G,R,0
        needed = palette_offset + colors_used * entry_size
        if needed > len(data):
            raise SystemExit("BMP palette extends past end of file.")
        for i in range(colors_used):
            b, g, r, _ = struct.unpack_from("<BBBB", data, palette_offset + i * 4)
            # integer luminance approximation
            lum = (299 * r + 587 * g + 114 * b) // 1000
            palette.append(lum)

    # Row size is padded to 4-byte boundary.
    row_size = ((bpp * width + 31) // 32) * 4

    if pixel_offset + row_size * height > len(data):
        raise SystemExit("BMP pixel data extends past end of file.")

    pixels: List[List[int]] = [[0] * width for _ in range(height)]

    for row in range(height):
        src_row = row if top_down else (height - 1 - row)
        row_start = pixel_offset + src_row * row_size

        if bpp == 1:
            for x in range(width):
                byte_index = row_start + (x // 8)
                bit_index = 7 - (x % 8)
                palette_index = (data[byte_index] >> bit_index) & 1
                lum = palette[palette_index]
                pixels[row][x] = lum

        elif bpp == 4:
            for x in range(width):
                byte_index = row_start + (x // 2)
                byte_val = data[byte_index]
                if x % 2 == 0:
                    palette_index = (byte_val >> 4) & 0x0F
                else:
                    palette_index = byte_val & 0x0F
                lum = palette[palette_index]
                pixels[row][x] = lum

        elif bpp == 8:
            for x in range(width):
                palette_index = data[row_start + x]
                lum = palette[palette_index]
                pixels[row][x] = lum

        elif bpp == 24:
            for x in range(width):
                px = row_start + x * 3
                b, g, r = struct.unpack_from("<BBB", data, px)
                lum = (299 * r + 587 * g + 114 * b) // 1000
                pixels[row][x] = lum

        elif bpp == 32:
            for x in range(width):
                px = row_start + x * 4
                b, g, r, _a = struct.unpack_from("<BBBB", data, px)
                lum = (299 * r + 587 * g + 114 * b) // 1000
                pixels[row][x] = lum

        else:
            raise SystemExit(f"Unsupported BMP bit depth: {bpp}")

    return pixels


def luminance_to_bits(lums: List[List[int]], invert: bool) -> List[List[int]]:
    bits: List[List[int]] = []
    for row in lums:
        out_row: List[int] = []
        for lum in row:
            is_dark = 1 if lum < 128 else 0
            out_row.append(1 - is_dark if invert else is_dark)
        bits.append(out_row)
    return bits


def tile_to_code(tile_bits: List[List[int]]) -> int:
    tl, tr = tile_bits[0]
    ml, mr = tile_bits[1]
    bl, br = tile_bits[2]
    return (
        (br << 0)
        | (mr << 1)
        | (tr << 2)
        | (bl << 3)
        | (ml << 4)
        | (tl << 5)
    )


def encode_vti(bits: List[List[int]]) -> List[List[int]]:
    height = len(bits)
    width = len(bits[0]) if bits else 0

    if width % 2 != 0 or height % 3 != 0:
        raise SystemExit(f"Image size must be divisible by 2x3 tiles. Got {width}x{height}.")

    rows: List[List[int]] = []
    for y in range(0, height, 3):
        out_row: List[int] = []
        for x in range(0, width, 2):
            tile = [
                [bits[y + 0][x + 0], bits[y + 0][x + 1]],
                [bits[y + 1][x + 0], bits[y + 1][x + 1]],
                [bits[y + 2][x + 0], bits[y + 2][x + 1]],
            ]
            out_row.append(tile_to_code(tile))
        rows.append(out_row)
    return rows


def format_output(rows: List[List[int]], db_per_row: bool) -> str:
    if db_per_row:
        return "\n".join(
            "        DB      " + ",".join(f"{v:02X}H" for v in row)
            for row in rows
        )
    flat = [v for row in rows for v in row]
    return "        DB      " + ",".join(f"{v:02X}H" for v in flat)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert BMP into POLY-88 VTI 2x3 DB hex sequence, without Pillow."
    )
    parser.add_argument("image", type=Path, help="Input BMP file")
    parser.add_argument("--width", type=int, default=8, help="Expected width (default: 8)")
    parser.add_argument("--height", type=int, default=48, help="Expected height (default: 48)")
    parser.add_argument("--invert", action="store_true", help="Treat light pixels as set")
    parser.add_argument("--db-per-row", action="store_true", help="Emit one DB per VTI row")
    args = parser.parse_args()

    lums = read_bmp(args.image)
    height = len(lums)
    width = len(lums[0]) if lums else 0

    if width != args.width or height != args.height:
        raise SystemExit(f"Expected {args.width}x{args.height}, got {width}x{height}.")

    bits = luminance_to_bits(lums, invert=args.invert)
    rows = encode_vti(bits)

    print(f"; {width}x{height} pixels -> {width // 2}x{height // 3} VTI chars")
    print(format_output(rows, db_per_row=args.db_per_row))


if __name__ == "__main__":
    main()
