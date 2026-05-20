#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SNAPSHOT_PATH="${TMPDIR:-/tmp}/pixelcat-editor-render.png"

cd "$ROOT_DIR"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache" \
swift build

rm -f "$SNAPSHOT_PATH"

PIXELCAT_SCREENSHOT_EDITOR_TEST=1 \
PIXELCAT_SCREENSHOT_EDITOR_SNAPSHOT="$SNAPSHOT_PATH" \
"$ROOT_DIR/.build/debug/PixelCatPop"

python3 - "$SNAPSHOT_PATH" <<'PY'
import struct
import sys
import zlib

path = sys.argv[1]
data = open(path, "rb").read()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("snapshot is not a PNG")

offset = 8
width = height = color_type = bit_depth = None
compressed = b""
while offset < len(data):
    length = struct.unpack(">I", data[offset:offset + 4])[0]
    chunk_type = data[offset + 4:offset + 8]
    chunk = data[offset + 8:offset + 8 + length]
    offset += 12 + length

    if chunk_type == b"IHDR":
        width, height, bit_depth, color_type = struct.unpack(">IIBB", chunk[:10])
    elif chunk_type == b"IDAT":
        compressed += chunk
    elif chunk_type == b"IEND":
        break

if width is None or height is None:
    raise SystemExit("snapshot has no IHDR")
if width < 900 or height < 600:
    raise SystemExit(f"snapshot is too small: {width}x{height}")
if bit_depth != 8 or color_type not in (2, 6):
    raise SystemExit(f"unsupported PNG format: bit_depth={bit_depth} color_type={color_type}")

channels = 4 if color_type == 6 else 3
stride = width * channels
raw = zlib.decompress(compressed)
rows = []
prev = bytearray(stride)
pos = 0

for _ in range(height):
    filter_type = raw[pos]
    pos += 1
    row = bytearray(raw[pos:pos + stride])
    pos += stride

    for i in range(stride):
        left = row[i - channels] if i >= channels else 0
        up = prev[i]
        up_left = prev[i - channels] if i >= channels else 0

        if filter_type == 1:
            row[i] = (row[i] + left) & 0xff
        elif filter_type == 2:
            row[i] = (row[i] + up) & 0xff
        elif filter_type == 3:
            row[i] = (row[i] + ((left + up) // 2)) & 0xff
        elif filter_type == 4:
            p = left + up - up_left
            pa, pb, pc = abs(p - left), abs(p - up), abs(p - up_left)
            predictor = left if pa <= pb and pa <= pc else up if pb <= pc else up_left
            row[i] = (row[i] + predictor) & 0xff
        elif filter_type != 0:
            raise SystemExit(f"unsupported PNG filter: {filter_type}")

    rows.append(bytes(row))
    prev = row

blue_pixels = 0
green_pixels = 0
yellow_pixels = 0
for row in rows:
    for i in range(0, stride, channels):
        r, g, b = row[i], row[i + 1], row[i + 2]
        if b > 180 and g > 120 and r < 120:
            blue_pixels += 1
        if g > 170 and r < 80 and b < 140:
            green_pixels += 1
        if r > 200 and g > 150 and b < 90:
            yellow_pixels += 1

if min(blue_pixels, green_pixels, yellow_pixels) < 5000:
    raise SystemExit(
        f"snapshot does not contain expected editor image colors: "
        f"blue={blue_pixels} green={green_pixels} yellow={yellow_pixels}"
    )

print(f"screenshot editor snapshot OK: {width}x{height}")
PY
