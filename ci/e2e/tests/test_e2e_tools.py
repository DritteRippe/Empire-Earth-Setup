#!/usr/bin/env python3
"""Tests of the Python tools of the real-data end-to-end test with synthetic data (no game data,
no network): inno_headers.py (a made-up setup with an LZMA1 header block), place_assets.py,
readset.py and gen_map.py (a made-up asset tree, extraction and preprocessed script), guard_upload.py
and report.py. Also checks that the committed map is well-formed and data-free, and the rules of
.github/workflows/e2e-realdata.yml that its text must keep (gates, launcher pin, time limits; read
as text, the runner has no YAML library).

  python -m unittest discover -s ci/e2e/tests -p "test_*.py"
"""
import contextlib
import hashlib
import io
import json
import lzma
import os
import random
import re
import struct
import sys
import tempfile
import unittest
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
E2E = os.path.dirname(HERE)
sys.path.insert(0, E2E)

import gen_map  # noqa: E402
import guard_upload  # noqa: E402
import inno_headers  # noqa: E402
import place_assets  # noqa: E402
import readset  # noqa: E402
import report  # noqa: E402

MAP = os.path.join(E2E, "assets-map.tsv")
WORKFLOW = os.path.join(os.path.dirname(os.path.dirname(E2E)), ".github", "workflows", "e2e-realdata.yml")


def quiet(func, *args):
    """(exit code, printed text) of func(*args)."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = func(*args)
    return code, out.getvalue()


def bitmap(width, seed):
    """A small, valid-looking BMP: BITMAPFILEHEADER with bfSize and pixel data."""
    rng = random.Random(seed)
    pixels = bytes(rng.randrange(256) for _ in range(width * 3))
    size = 14 + 40 + len(pixels)
    return (b"BM" + struct.pack("<IHHI", size, 0, 0, 54) + struct.pack("<IiiHHIIiiII", 40, width, 1, 1, 24, 0, len(pixels), 0, 0, 0, 0)
            + pixels)


def block(payload, compressed):
    """An Inno Setup header block: CRC32 + stored size + compressed flag, then CRC'd 4096-byte chunks."""
    if compressed:
        props = (2 * 5 + 0) * 9 + 3
        raw = lzma.compress(payload, format=lzma.FORMAT_RAW,
                            filters=[{"id": lzma.FILTER_LZMA1, "dict_size": 1 << 16, "lc": 3, "lp": 0, "pb": 2}])
        data = bytes([props]) + struct.pack("<I", 1 << 16) + raw
    else:
        data = payload
    chunks = b""
    for i in range(0, len(data), 4096):
        chunk = data[i:i + 4096]
        chunks += struct.pack("<I", zlib.crc32(chunk)) + chunk
    head = struct.pack("<IB", len(chunks), 1 if compressed else 0)
    return struct.pack("<I", zlib.crc32(head)) + head + chunks


def fake_setup(path, headers0, headers1):
    version = b"Inno Setup Setup Data (6.1.0) (u)".ljust(64, b"\0")
    with open(path, "wb") as fh:
        fh.write(b"MZ" + os.urandom(3000))
        fh.write(version + b"\x00" * 9)          # the copy in the loader: no valid block CRC
        fh.write(os.urandom(5000))
        fh.write(version + block(headers0, True) + block(headers1, False))
        fh.write(os.urandom(100))


def write(path, data, mtime=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(data)
    if mtime is not None:
        os.utime(path, (mtime, mtime))


class InnoHeadersTests(unittest.TestCase):
    def test_extracts_both_blocks_and_finds_the_bitmaps(self):
        with tempfile.TemporaryDirectory() as tmp:
            small, banner = bitmap(10, 1), bitmap(3000, 2)
            h0 = os.urandom(20000) + struct.pack("<I", len(small)) + small + os.urandom(7) + struct.pack("<I", len(banner)) + banner
            h1 = b"second block " * 50
            setup = os.path.join(tmp, "setup.exe")
            fake_setup(setup, h0, h1)
            code, out = quiet(inno_headers.main, [setup, os.path.join(tmp, "hd")])
            self.assertEqual(code, 0, out)
            self.assertIn("Inno Setup Setup Data (6.1.0) (u)", out)
            with open(os.path.join(tmp, "hd", "headers0.bin"), "rb") as fh:
                self.assertEqual(fh.read(), h0)
            with open(os.path.join(tmp, "hd", "headers1.bin"), "rb") as fh:
                self.assertEqual(fh.read(), h1)
            found = place_assets.header_bitmaps(os.path.join(tmp, "hd", "headers0.bin"))
            self.assertIn((hashlib.sha1(small).hexdigest(), len(small)), found)
            self.assertIn((hashlib.sha1(banner).hexdigest(), len(banner)), found)

    def test_a_damaged_chunk_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            setup = os.path.join(tmp, "setup.exe")
            fake_setup(setup, os.urandom(9000), b"x")
            with open(setup, "r+b") as fh:
                data = fh.read()
                at = data.rfind(b"Inno Setup Setup Data (") + 64 + 9 + 4 + 100
                fh.seek(at)
                fh.write(bytes([data[at] ^ 0xFF]))
            code, out = quiet(inno_headers.main, [setup, os.path.join(tmp, "hd")])
            self.assertEqual(code, 1)
            self.assertIn("CRC", out)

    def test_no_header(self):
        with tempfile.TemporaryDirectory() as tmp:
            setup = os.path.join(tmp, "setup.exe")
            write(setup, b"MZ" + os.urandom(1000))
            self.assertEqual(quiet(inno_headers.main, [setup, os.path.join(tmp, "hd")])[0], 1)


class AssetToolsTests(unittest.TestCase):
    """A small world: an asset tree, the 'extraction' of two setups with other file names, setup
    headers with a bitmap, a preprocessed script; gen_map makes the map, place_assets rebuilds the
    tree from it, readset checks the script against it."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.tmp.name
        self.assets = os.path.join(t, "assets")
        self.files = {
            "data\\Empire Earth Base\\Empire Earth\\game.exe": (os.urandom(3000), 1500000000),
            "data\\Empire Earth Base\\Empire Earth\\Data\\a.dat": (os.urandom(500), 1500000100),
            "data\\Add-on\\Civs\\eC\\x.civ": (b"civ one", 1600000000),
            "data\\Add-on\\Civs\\eC_full\\x.civ": (b"civ one", 1600000500),   # same content, other time
            "internal\\runtime\\directx\\dxwebsetup.exe": (os.urandom(800), 1400000000),
        }
        for rel, (data, mtime) in self.files.items():
            write(place_assets.local_path(self.assets, rel), data, mtime)
        os.makedirs(place_assets.local_path(self.assets, "data\\Empire Earth Base\\Empire Earth\\Data\\Saved Games"))
        self.banner = bitmap(40, 3)
        write(place_assets.local_path(self.assets, "internal\\media\\SetupBanner.bmp"), self.banner)
        write(place_assets.local_path(self.assets, "data\\localized-text.sha256"), b"0" * 64 + b"  Game/de/EE/Language.dll\r\n")
        for product in ("EE", "NeoEE"):
            ex = os.path.join(t, "x", product)
            write(os.path.join(ex, "app", "renamed_game.exe"), self.files["data\\Empire Earth Base\\Empire Earth\\game.exe"][0])
            write(os.path.join(ex, "app", "a.dat"), self.files["data\\Empire Earth Base\\Empire Earth\\Data\\a.dat"][0])
            write(os.path.join(ex, "app", "civ.civ"), b"civ one")
            write(os.path.join(ex, "tmp", "dxwebsetup.exe"), self.files["internal\\runtime\\directx\\dxwebsetup.exe"][0])
            write(os.path.join(ex, "app", "not in the build.txt"), b"other")
            write(os.path.join(t, "hd", product, "headers0.bin"),
                  os.urandom(300) + struct.pack("<I", len(self.banner)) + self.banner + os.urandom(30))
        script = "\r\n".join([
            "[Setup]",
            "WizardImageFile=internal\\media\\SetupBanner.bmp",
            "[Files]",
            'Source: "data\\Empire Earth Base\\Empire Earth\\*"; DestDir: "{app}\\Empire Earth"; Flags: ignoreversion recursesubdirs createallsubdirs',
            'Source: "data\\Add-on\\Civs\\eC\\*"; DestDir: "{app}\\c"; Flags: ignoreversion recursesubdirs createallsubdirs',
            'Source: "data\\Add-on\\Civs\\eC_full\\*"; DestDir: "{app}\\c"; Flags: ignoreversion recursesubdirs createallsubdirs',
            'Source: "internal\\runtime\\directx\\dxwebsetup.exe"; DestDir: "{tmp}\\directx"; Flags: deleteafterinstall',
            'Source: "{tmp}\\verified\\EE\\*"; DestDir: "{app}"; Flags: external skipifsourcedoesntexist',
            "",
        ])
        self.pp = os.path.join(t, "EE_Regular.iss")
        with open(self.pp, "w", encoding="utf-8-sig", newline="") as fh:
            fh.write(script)
        self.map = os.path.join(t, "map.tsv")
        self.extract = [f"EE={os.path.join(t, 'x', 'EE')}", f"NeoEE={os.path.join(t, 'x', 'NeoEE')}"]
        self.headers = [f"EE={os.path.join(t, 'hd', 'EE')}", f"NeoEE={os.path.join(t, 'hd', 'NeoEE')}"]
        code, out = quiet(gen_map.main, ["--assets", self.assets, "--pp", f"EE={self.pp}", "--pp", f"NeoEE={self.pp}",
                                         "--extract"] + self.extract + ["--headers"] + self.headers + ["--out", self.map])
        self.assertEqual(code, 0, out)

    def tearDown(self):
        self.tmp.cleanup()

    def rows(self):
        return place_assets.read_map(self.map)

    def test_the_map_names_every_file_and_folder_without_content(self):
        rows = {r["path"]: r for r in self.rows()}
        self.assertEqual(len([r for r in rows.values() if r["kind"] == "file"]), 6)
        self.assertEqual(rows["internal\\media\\SetupBanner.bmp"]["origin"], "header:EE+NeoEE")
        self.assertEqual(rows["internal\\media\\SetupBanner.bmp"]["mtime_utc"], "-")
        self.assertEqual(rows["data\\Add-on\\Civs\\eC_full\\x.civ"]["mtime_utc"], "2020-09-13T12:35:00Z")
        self.assertEqual(rows["data\\Empire Earth Base\\Empire Earth\\Data\\Saved Games"]["kind"], "dir")
        generated = rows["data\\localized-text.sha256"]
        self.assertEqual(generated["kind"], "generated")
        self.assertEqual(generated["sha1"], hashlib.sha1(b"0" * 64 + b"  Game/de/EE/Language.dll\n").hexdigest())
        with open(self.map, "rb") as fh:
            text = fh.read()
        self.assertNotIn(b"civ one", text)

    def test_placing_rebuilds_the_tree_exactly(self):
        root = os.path.join(self.tmp.name, "root")
        code, out = quiet(place_assets.main, ["--map", self.map, "--root", root, "--extract"] + self.extract + ["--headers"] + self.headers)
        self.assertEqual(code, 0, out)
        for rel, (data, mtime) in self.files.items():
            p = place_assets.local_path(root, rel)
            with open(p, "rb") as fh:
                self.assertEqual(fh.read(), data, rel)
            self.assertEqual(int(os.stat(p).st_mtime), mtime, rel)
        with open(place_assets.local_path(root, "internal\\media\\SetupBanner.bmp"), "rb") as fh:
            self.assertEqual(fh.read(), self.banner)
        self.assertTrue(os.path.isdir(place_assets.local_path(root, "data\\Empire Earth Base\\Empire Earth\\Data\\Saved Games")))
        self.assertNotIn("other", out)
        # the read set of the script equals the map
        code, out = quiet(readset.main, ["--root", root, "--pp", f"EE={self.pp}", "--check-map", self.map])
        self.assertEqual(code, 0, out)

    def test_verify_reports_every_kind_of_difference(self):
        root = os.path.join(self.tmp.name, "root")
        quiet(place_assets.main, ["--map", self.map, "--root", root, "--extract"] + self.extract + ["--headers"] + self.headers)
        changed = place_assets.local_path(root, "data\\Add-on\\Civs\\eC\\x.civ")
        with open(changed, "ab") as fh:
            fh.write(b"!")
        later = place_assets.local_path(root, "data\\Empire Earth Base\\Empire Earth\\Data\\a.dat")
        os.utime(later, (1700000000, 1700000000))
        os.remove(place_assets.local_path(root, "internal\\runtime\\directx\\dxwebsetup.exe"))
        write(place_assets.local_path(root, "data\\Add-on\\new.dll"), b"new")
        code, out = quiet(place_assets.main, ["--map", self.map, "--root", root, "--verify-only"])
        self.assertEqual(code, 1)
        self.assertIn("content differs data\\Add-on\\Civs\\eC\\x.civ", out)
        self.assertIn("time differs data\\Empire Earth Base\\Empire Earth\\Data\\a.dat", out)
        self.assertIn("missing internal\\runtime\\directx\\dxwebsetup.exe", out)
        self.assertIn("not in the map: data\\Add-on\\new.dll", out)

    def test_a_file_without_source_fails(self):
        os.remove(os.path.join(self.tmp.name, "x", "EE", "app", "civ.civ"))
        os.remove(os.path.join(self.tmp.name, "x", "NeoEE", "app", "civ.civ"))
        root = os.path.join(self.tmp.name, "root")
        code, out = quiet(place_assets.main, ["--map", self.map, "--root", root, "--extract"] + self.extract + ["--headers"] + self.headers)
        self.assertEqual(code, 1)
        self.assertIn("no source for data\\Add-on\\Civs\\eC\\x.civ", out)

    def test_readset_reports_a_new_source(self):
        root = os.path.join(self.tmp.name, "root")
        quiet(place_assets.main, ["--map", self.map, "--root", root, "--extract"] + self.extract + ["--headers"] + self.headers)
        write(place_assets.local_path(root, "data\\Add-on\\Civs\\eC\\y.civ"), b"new civ")
        with open(self.pp, "a", encoding="utf-8", newline="") as fh:
            fh.write('Source: "data\\Add-on\\Missing\\z.dll"; DestDir: "{app}"; Flags: ignoreversion\r\n')
        code, out = quiet(readset.main, ["--root", root, "--pp", f"EE={self.pp}", "--check-map", self.map])
        self.assertEqual(code, 1)
        self.assertIn("read by the script, not in the map (file): data\\Add-on\\Civs\\eC\\y.civ", out)
        self.assertIn("source missing: data\\Add-on\\Missing\\z.dll", out)


class DownloadOriginTests(unittest.TestCase):
    """The origin download:<name>: a file of another public download (the dgVoodoo archive), found by
    SHA-1 and size in the extracted folder of --download <name>=<dir>."""

    DDRAW = "data\\Add-on\\DirectX_Wrapper\\dgVoodoo_bin\\DDraw.dll"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.tmp.name
        self.assets = os.path.join(t, "assets")
        self.content = os.urandom(2000)
        write(place_assets.local_path(self.assets, self.DDRAW), self.content, 1789425354)   # 2026-09-14 22:35:54 UTC
        write(place_assets.local_path(self.assets, "data\\Empire Earth Base\\game.exe"), b"game", 1500000000)
        write(place_assets.local_path(self.assets, "data\\localized-text.sha256"), b"0" * 64 + b"  Game/de/EE/Language.dll\n")
        for product in ("EE", "NeoEE"):
            write(os.path.join(t, "x", product, "app", "g.exe"), b"game")
            write(os.path.join(t, "hd", product, "headers0.bin"), os.urandom(50))
        # the 'extracted archive': another name, in a subfolder, next to files nobody reads
        self.download = os.path.join(t, "dgvoodoo")
        write(os.path.join(self.download, "MS", "x86", "DDraw.dll"), self.content)
        write(os.path.join(self.download, "readme.txt"), b"other")
        self.pp = os.path.join(t, "EE_Regular.iss")
        with open(self.pp, "w", encoding="utf-8-sig", newline="") as fh:
            fh.write("\r\n".join([
                "[Files]",
                'Source: "data\\Empire Earth Base\\game.exe"; DestDir: "{app}"; Flags: ignoreversion',
                'Source: "data\\Add-on\\DirectX_Wrapper\\dgVoodoo_bin\\DDraw.dll"; DestDir: "{app}"; Flags: ignoreversion',
                'Source: "config\\dgVoodoo\\dgVoodoo_DX11_LVL11.conf"; DestDir: "{app}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion',
                ""]))
        self.map = os.path.join(t, "map.tsv")
        self.extract = [f"EE={os.path.join(t, 'x', 'EE')}", f"NeoEE={os.path.join(t, 'x', 'NeoEE')}"]
        self.headers = [f"EE={os.path.join(t, 'hd', 'EE')}", f"NeoEE={os.path.join(t, 'hd', 'NeoEE')}"]
        self.args = ["--assets", self.assets, "--pp", f"EE={self.pp}", "--pp", f"NeoEE={self.pp}", "--extract"] + self.extract \
            + ["--headers"] + self.headers + ["--out", self.map]

    def tearDown(self):
        self.tmp.cleanup()

    def make_map(self):
        code, out = quiet(gen_map.main, self.args + ["--download", f"dgvoodoo-v2.87.5={self.download}"])
        self.assertEqual(code, 0, out)

    def test_gen_map_names_the_download_and_the_time_of_the_file(self):
        self.make_map()
        rows = {r["path"]: r for r in place_assets.read_map(self.map)}
        row = rows[self.DDRAW]
        self.assertEqual(row["origin"], "download:dgvoodoo-v2.87.5")
        self.assertEqual(row["mtime_utc"], "2026-09-14T22:35:54Z")
        self.assertEqual(rows["data\\Empire Earth Base\\game.exe"]["origin"], "setup:EE+NeoEE")
        self.assertFalse([p for p in rows if p.startswith("config")])   # config\\ is not an asset folder

    def test_a_file_in_no_setup_and_no_download_has_no_origin(self):
        code, out = quiet(gen_map.main, self.args)
        self.assertEqual(code, 1)
        self.assertIn("no origin for " + self.DDRAW, out)

    def test_placing_from_the_download(self):
        self.make_map()
        root = os.path.join(self.tmp.name, "root")
        place = ["--map", self.map, "--root", root, "--extract"] + self.extract + ["--headers"] + self.headers
        code, out = quiet(place_assets.main, place + ["--download", f"dgvoodoo-v2.87.5={self.download}"])
        self.assertEqual(code, 0, out)
        self.assertIn("1 from downloads", out)
        p = place_assets.local_path(root, self.DDRAW)
        with open(p, "rb") as fh:
            self.assertEqual(fh.read(), self.content)
        self.assertEqual(int(os.stat(p).st_mtime), 1789425354)
        self.assertNotIn("other", out)
        code, out = quiet(readset.main, ["--root", root, "--pp", f"EE={self.pp}", "--check-map", self.map])
        self.assertEqual(code, 0, out)

    def test_no_download_or_a_missing_folder_is_no_source(self):
        self.make_map()
        root = os.path.join(self.tmp.name, "root")
        place = ["--map", self.map, "--root", root, "--extract"] + self.extract + ["--headers"] + self.headers
        code, out = quiet(place_assets.main, place)
        self.assertEqual(code, 1)
        self.assertIn(f"no source for {self.DDRAW} (download:dgvoodoo-v2.87.5)", out)
        code, out = quiet(place_assets.main, place + ["--download", f"dgvoodoo-v2.87.5={os.path.join(self.tmp.name, 'nowhere')}"])
        self.assertEqual(code, 1)
        self.assertIn("extraction folder missing", out)
        self.assertIn("no source for " + self.DDRAW, out)

    def test_a_download_with_other_content_is_no_source(self):
        self.make_map()
        write(os.path.join(self.download, "MS", "x86", "DDraw.dll"), self.content + b"!")
        root = os.path.join(self.tmp.name, "root")
        code, out = quiet(place_assets.main, ["--map", self.map, "--root", root, "--extract"] + self.extract + ["--headers"] + self.headers
                          + ["--download", f"dgvoodoo-v2.87.5={self.download}"])
        self.assertEqual(code, 1)
        self.assertIn("no source for " + self.DDRAW, out)

    def test_a_bad_download_argument_is_refused(self):
        for bad in ("dgvoodoo", "=folder", "bad name=folder"):
            with self.assertRaises(SystemExit):
                place_assets.parse_downloads([bad])


class CommittedMapTests(unittest.TestCase):
    def test_well_formed_and_data_free(self):
        rows = place_assets.read_map(MAP)
        kinds = {}
        for r in rows:
            kinds[r["kind"]] = kinds.get(r["kind"], 0) + 1
            self.assertTrue(all(ord(c) < 128 for c in r["path"]), r["path"])
            if r["kind"] == "file":
                self.assertRegex(r["sha1"], "^[0-9a-f]{40}$")
                self.assertTrue(r["size"].isdigit())
                self.assertTrue(r["origin"].startswith(("setup:", "header:", "download:")), r["path"])
                self.assertTrue(r["mtime_utc"] == "-" or r["mtime_utc"].endswith("Z"))
        self.assertEqual(kinds, {"file": 1794, "dir": 16, "generated": 1})
        # the only download is the dgVoodoo archive of pins/dgvoodoo.txt, whose three files it holds
        downloads = {r["path"]: r["origin"] for r in rows if r["origin"].startswith("download:")}
        self.assertEqual(sorted(downloads), [
            "data\\Add-on\\DirectX_Wrapper\\dgVoodoo_bin\\D3DImm.dll", "data\\Add-on\\DirectX_Wrapper\\dgVoodoo_bin\\DDraw.dll",
            "data\\Add-on\\DirectX_Wrapper\\dgVoodoo_bin\\dgVoodooCpl.exe"])
        self.assertEqual(set(downloads.values()), {"download:dgvoodoo-v2.87.5"})
        self.assertFalse([r for r in rows if "dgVoodoo_conf" in r["path"]])
        self.assertEqual(len({r["path"].lower() for r in rows}), len(rows))
        self.assertLess(os.path.getsize(MAP), 1 << 20)


class GuardTests(unittest.TestCase):
    def run_guard(self, folder, *extra):
        return quiet(guard_upload.main, ["--dir", folder, "--map", MAP] + list(extra))

    def test_logs_and_reports_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            write(os.path.join(tmp, "logs", "A-install.log"), "﻿2026-10-03 10:00:00.000   Log opened.\r\n".encode("utf-8"))
            write(os.path.join(tmp, "launcher", "A-installed.xml"), b"<?xml version='1.0'?><test-run/>")
            write(os.path.join(tmp, "results.jsonl"), b'{"status":"PASS"}\n')
            write(os.path.join(tmp, "utf16.log"), "x\r\n".encode("utf-16"))
            code, out = self.run_guard(tmp)
            self.assertEqual(code, 0, out)

    def test_refusals(self):
        cases = {
            "setup.exe": (b"text", "extension not allowed"),
            "big.log": (b"a" * (2 << 20), "larger than 1 MB"),
            "nul.log": (b"abc\x00def", "NUL bytes"),
            "bitmap.txt": (b"BM" + b"x" * 100, "signature"),
        }
        for name, (data, expected) in cases.items():
            with tempfile.TemporaryDirectory() as tmp:
                write(os.path.join(tmp, name), data)
                code, out = self.run_guard(tmp, "--max-file-mb", "1")
                self.assertEqual(code, 1, name)
                self.assertIn(expected, out, name)

    def test_a_game_file_under_another_name_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            # a text file whose SHA-1 is in the map: simulated by a map with the hash of this text
            data = b"just text\n"
            fake_map = os.path.join(tmp, "map.tsv")
            with open(fake_map, "w", encoding="utf-8") as fh:
                fh.write("# test\nkind\tpath\tsize\tsha1\tmtime_utc\tproducts\torigin\n")
                fh.write(f"file\tdata\\x.txt\t{len(data)}\t{hashlib.sha1(data).hexdigest()}\t-\tEE\tsetup:EE\n")
            report_dir = os.path.join(tmp, "report")
            write(os.path.join(report_dir, "copied.txt"), data)
            code, out = quiet(guard_upload.main, ["--dir", report_dir, "--map", fake_map])
            self.assertEqual(code, 1)
            self.assertIn("file of the asset map", out)

    def test_overlap_with_a_forbidden_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            report_dir = os.path.join(tmp, "work", "report")
            write(os.path.join(report_dir, "a.log"), b"x\n")
            code, out = self.run_guard(report_dir, "--forbid", os.path.join(tmp, "work"))
            self.assertEqual(code, 1)
            self.assertIn("overlaps the forbidden folder", out)

    @unittest.skipIf(os.name == "nt", "symbolic links need a privilege on Windows")
    def test_links_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            report_dir = os.path.join(tmp, "report")
            write(os.path.join(report_dir, "a.log"), b"x\n")
            os.makedirs(os.path.join(tmp, "data"))
            os.symlink(os.path.join(tmp, "data"), os.path.join(report_dir, "data"))
            code, out = self.run_guard(report_dir)
            self.assertEqual(code, 1)
            self.assertIn("link or junction", out)


class ReportTests(unittest.TestCase):
    def results(self, tmp, lines):
        path = os.path.join(tmp, "results.jsonl")
        with open(path, "w", encoding="utf-8") as fh:
            for line in lines:
                fh.write(json.dumps(line) + "\n")
        return path

    def all_done(self, extra=()):
        lines = [{"scenario": p, "check": "DONE", "status": "INFO", "details": []} for p in report.PHASES]
        return list(extra) + lines

    def test_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self.results(tmp, self.all_done([{"scenario": "A", "check": "install/K1", "status": "PASS", "details": ["ok | fine"]},
                                                    {"scenario": "A", "check": "install/DL", "status": "SERVER", "details": ["mirror down"]}]))
            out_file = os.path.join(tmp, "report.md")
            summary = os.path.join(tmp, "summary.md")
            code, out = quiet(report.main, ["--results", path, "--out", out_file, "--summary", summary, "--verdict",
                                            "--context", "Commit=abc"])
            self.assertEqual(code, 0, out)
            with open(out_file, encoding="utf-8") as fh:
                text = fh.read()
            self.assertIn("BESTANDEN / PASSED", text)
            self.assertIn("Installationseintrag (Vertrag 1.1) / Install record (contract 1.1)", text)
            self.assertIn("ok \\| fine", text)
            self.assertIn("| Commit | abc |", text)
            with open(summary, encoding="utf-8") as fh:
                self.assertEqual(fh.read(), text)

    def test_fail_and_missing_phase(self):
        with tempfile.TemporaryDirectory() as tmp:
            lines = [l for l in self.all_done([{"scenario": "B", "check": "install/K9", "status": "FAIL", "details": ["dummy changed"]}])
                     if l["scenario"] != "C"]
            code, out = quiet(report.main, ["--results", self.results(tmp, lines), "--verdict"])
            self.assertEqual(code, 1)
            self.assertIn("1 check(s) failed", out)
            self.assertIn("phase C did not run to its end", out)

    def test_missing_results(self):
        code, out = quiet(report.main, ["--results", os.path.join(tempfile.gettempdir(), "no-such-file.jsonl"), "--verdict"])
        self.assertEqual(code, 1)
        self.assertIn("result file missing", out)

    def test_warn_does_not_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self.results(tmp, self.all_done([{"scenario": "C", "check": "x/RMS", "status": "WARN", "details": []}]))
            self.assertEqual(quiet(report.main, ["--results", path, "--verdict"])[0], 0)


class WorkflowTests(unittest.TestCase):
    """What the review of the workflow asked for and the workflow text must keep."""

    @classmethod
    def setUpClass(cls):
        with open(WORKFLOW, encoding="utf-8") as f:
            cls.text = f.read()
        with open(os.path.join(E2E, "e2e_helpers.ps1"), encoding="ascii") as f:
            cls.helpers = f.read()
        with open(os.path.join(E2E, "run_e2e.ps1"), encoding="ascii") as f:
            cls.run_e2e = f.read()

    def constant(self, name):
        match = re.search(r"(?m)^\s*%s\s*=\s*(\d+)\s*$" % name, self.helpers)
        self.assertIsNotNone(match, name)
        return int(match.group(1))

    def test_the_job_runs_by_hand_only(self):
        # ADR 0011, amendment 2026-10-07: r2.empireearth.eu answers GitHub runners with HTTP 403, so a check on pull
        # requests would always be red. The only trigger is workflow_dispatch with the input launcher_commit
        triggers = self.text.split("\non:\n", 1)[1].split("\npermissions:", 1)[0]
        self.assertEqual(re.findall(r"(?m)^  ([\w_]+):$", triggers), ["workflow_dispatch"])
        self.assertEqual(re.findall(r"(?m)^      ([\w_]+):$", triggers), ["launcher_commit"])
        for name in ("pull_request", "pull_request_target", "push", "schedule", "workflow_run", "workflow_call"):
            self.assertNotRegex(triggers, r"(?m)^\s*%s:" % name, name)
        self.assertNotIn("paths:", self.text)
        self.assertNotIn("'ci/**'", self.text)
        self.assertNotIn("'config/**'", self.text)
        # Nothing of the pull request gate is left to decide: no job condition, no label, no fork check
        self.assertNotRegex(self.text, r"(?m)^    if:")
        for gone in ("github.event.pull_request", "github.event.label", "github.event.action", "github.head_ref"):
            self.assertNotIn(gone, self.text)
        # One run per ref: a newer dispatch on the same branch cancels the older one
        self.assertRegex(self.text, r"(?m)^concurrency:\n  group: e2e-realdata-\$\{\{ github\.ref_name \}\}\n  cancel-in-progress: true$")
        # The header says why and where the way back is recorded
        header = self.text.split("\nname: E2E real data\n", 1)[0]
        for phrase in ("by hand only", "HTTP 403", "r2.empireearth.eu", "label e2e", "ADR 0011"):
            self.assertIn(phrase, header)
        # One job: another one would run without a gate
        self.assertEqual(re.findall(r"(?m)^  ([\w-]+):$", self.text.split("\njobs:\n", 1)[1]), ["e2e"])

    def test_the_launcher_is_a_pinned_commit_on_its_branch(self):
        self.assertRegex(self.text, r"(?m)^  LAUNCHER_COMMIT: [0-9a-f]{40}$")
        self.assertRegex(self.text, r"(?m)^  LAUNCHER_BRANCH: main$")
        self.assertNotIn("launcher_ref", self.text)
        self.assertIn("ref: ${{ steps.launcher.outputs.commit }}", self.text)
        self.assertIn("-cnotmatch '^[0-9a-f]{40}$'", self.text)
        self.assertIn('git merge-base --is-ancestor HEAD "refs/remotes/origin/$env:LAUNCHER_BRANCH"', self.text)

    def test_the_dgvoodoo_archive_is_read_from_its_pin_and_cached_by_its_hash(self):
        pins = os.path.join(os.path.dirname(os.path.dirname(E2E)), "pins", "dgvoodoo.txt")
        with open(pins, encoding="utf-8") as f:
            pin_text = f.read()
        archive = re.search(r"(?m)^Archive ([0-9a-f]{64}) (\d+) (https://\S+)$", pin_text)
        self.assertIsNotNone(archive)
        # neither the hash, nor the size, nor the URL of the archive is repeated in the workflow
        for value in archive.groups():
            self.assertNotIn(value, self.text)
        self.assertIn("Read-DgVoodooPins 'pins/dgvoodoo.txt'", self.text)
        self.assertIn("key: dgvoodoo-${{ steps.dgvoodoo.outputs.sha256 }}", self.text)
        self.assertEqual(self.text.count("key: dgvoodoo-${{ steps.dgvoodoo.outputs.sha256 }}"), 2)   # restore and save
        self.assertIn("DGVOODOO_SHA256: ${{ steps.dgvoodoo.outputs.sha256 }}", self.text)
        self.assertIn("DGVOODOO_SIZE: ${{ steps.dgvoodoo.outputs.size }}", self.text)
        self.assertIn("--proto '=https' --proto-redir '=https'", self.text.split("Download the dgVoodoo archive (cache miss)", 1)[1].split("- name:", 1)[0])
        self.assertIn('--download "$env:DGVOODOO_NAME=$env:E2E_ROOT\\dgvoodoo"', self.text)
        # the origin of the three files in the map is the name the workflow passes
        version = re.search(r"(?m)^Version (\S+)$", pin_text).group(1)
        origins = {r["origin"] for r in place_assets.read_map(MAP) if r["path"].startswith("data\\Add-on\\DirectX_Wrapper\\dgVoodoo_bin\\")}
        self.assertEqual(origins, {"download:dgvoodoo-" + version})
        self.assertIn('"name=dgvoodoo-$($pins.Version)"', self.text)

    def test_every_action_is_pinned_to_a_commit(self):
        uses = re.findall(r"(?m)^\s+(?:- )?uses: (\S+)", self.text)
        self.assertGreater(len(uses), 5)
        for action in uses:
            self.assertRegex(action, r"^[\w.-]+/[\w.-]+(/[\w.-]+)*@[0-9a-f]{40}$")

    def test_the_scripts_stop_their_programs_before_the_step_limits(self):
        steps = re.findall(r"(?m)^        timeout-minutes: (\d+)\n        shell: pwsh\n        run: \|\n"
                           r"          powershell [^\n]*run_e2e\.ps1 -Phase (\w+) -BudgetMinutes (\d+)$", self.text)
        self.assertEqual([phase for _, phase, _ in steps], ["A", "B", "E", "D", "C"])
        self.assertEqual(len(re.findall(r"run_e2e\.ps1 -Phase", self.text)), 6)  # and Prepare, without a budget
        setup = self.constant("SetupTimeoutMinutes")
        reserve = self.constant("CleanupReserveMinutes")
        self.assertLessEqual(self.constant("UninstallTimeoutMinutes") + 4, reserve)
        self.assertLessEqual(self.constant("LauncherTimeoutMinutes"), setup)
        self.assertIn("if ($Phase -eq 'E' -or $Phase -eq 'Prepare') { $reserve = 0 }", self.run_e2e)
        for limit, phase, budget in steps:
            self.assertLessEqual(int(budget) + 5, int(limit), phase)
            # A setup run fits in the budget before the reserve for the uninstallation (E keeps none)
            self.assertGreaterEqual(int(budget) - (0 if phase == "E" else reserve), setup, phase)
        job = int(re.search(r"(?m)^    timeout-minutes: (\d+)$", self.text).group(1))
        self.assertLessEqual(sum(int(limit) for limit, _, _ in steps) + 45, job)
        self.assertLessEqual(job, 360)


if __name__ == "__main__":
    unittest.main()
