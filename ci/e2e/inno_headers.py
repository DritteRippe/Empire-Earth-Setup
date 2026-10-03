#!/usr/bin/env python3
"""Decompresses the setup header blocks (headers0.bin, headers1.bin) of an Inno Setup 5.1.5+ or 6.x
installer with the Python standard library: the files innoextract --dump-headers writes, which
only DEBUG builds of innoextract have. ci/e2e/place_assets.py takes the wizard bitmaps from
headers0.bin.

Format (innoextract src/stream/block.cpp, src/loader/offsets.cpp): at the header offset a 64-byte
version string "Inno Setup Setup Data (x.y.z) (u)"; then CRC32 (4 bytes) of the next 5 bytes, the
stored size (4, little endian) and a compressed flag (1); then stored-size bytes made of chunks
"CRC32 (4) + up to 4096 bytes"; the concatenated chunk data is LZMA1 with a 5-byte properties
header (lc/lp/pb byte, dictionary size). The header offset is the occurrence of the version string
that is followed by a block header with a valid CRC32 (the string also appears in the setup loader).
Every CRC is checked; nothing of the content is printed.

Usage: inno_headers.py SETUP.exe OUT_DIR    (writes OUT_DIR/headers0.bin and OUT_DIR/headers1.bin)
Exit code 0 on success, 1 if no valid header is found or a CRC does not match.
"""
import lzma
import mmap
import os
import struct
import sys
import zlib

MAGIC = b"Inno Setup Setup Data ("
VERSION_LENGTH = 64
CHUNK_SIZE = 4096


def read_block(m, pos):
    """(data, end) of the block starting at pos: CRC-checked, decompressed if flagged."""
    crc, stored, compressed = struct.unpack_from("<IIB", m, pos)
    if zlib.crc32(m[pos + 4:pos + 9]) != crc:
        raise ValueError("block header CRC mismatch")
    pos += 9
    data, end = bytearray(), pos + stored
    if end > len(m):
        raise ValueError("block runs past the end of the file")
    while pos < end:
        n = min(CHUNK_SIZE, end - pos - 4)
        if n <= 0:
            raise ValueError("truncated chunk")
        chunk_crc = struct.unpack_from("<I", m, pos)[0]
        chunk = m[pos + 4:pos + 4 + n]
        if zlib.crc32(chunk) != chunk_crc:
            raise ValueError("chunk CRC mismatch")
        data += chunk
        pos += 4 + n
    if not compressed:
        return bytes(data), end
    props, dict_size = data[0], struct.unpack_from("<I", data, 1)[0]
    lc, rest = props % 9, props // 9
    lp, pb = rest % 5, rest // 5
    decompressor = lzma.LZMADecompressor(lzma.FORMAT_RAW, filters=[
        {"id": lzma.FILTER_LZMA1, "dict_size": dict_size, "lc": lc, "lp": lp, "pb": pb}])
    return decompressor.decompress(bytes(data[5:])), end


def find_header(m):
    """Offset of the version string that starts the setup header, or None."""
    off = m.find(MAGIC)
    while off >= 0:
        if off + VERSION_LENGTH + 9 <= len(m):
            crc = struct.unpack_from("<I", m, off + VERSION_LENGTH)[0]
            if zlib.crc32(m[off + VERSION_LENGTH + 4:off + VERSION_LENGTH + 9]) == crc:
                return off
        off = m.find(MAGIC, off + 1)
    return None


def extract_headers(setup):
    """(version string, headers0, headers1) of the setup file."""
    with open(setup, "rb") as fh:
        m = mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ)
        try:
            found = find_header(m)
            if found is None:
                raise ValueError("no Inno Setup header found")
            version = m[found:found + VERSION_LENGTH].rstrip(b"\0").decode("ascii", "replace")
            h0, nxt = read_block(m, found + VERSION_LENGTH)
            h1, _ = read_block(m, nxt)
        finally:
            m.close()
    return version, h0, h1


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2:
        print(__doc__)
        return 2
    setup, out = args
    try:
        version, h0, h1 = extract_headers(setup)
    except (OSError, ValueError, lzma.LZMAError) as ex:
        print(f"{os.path.basename(setup)}: {ex}")
        return 1
    os.makedirs(out, exist_ok=True)
    for i, blob in enumerate((h0, h1)):
        with open(os.path.join(out, f"headers{i}.bin"), "wb") as fh:
            fh.write(blob)
    print(f"{os.path.basename(setup)}: {version}; headers0.bin {len(h0)} bytes, headers1.bin {len(h1)} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
