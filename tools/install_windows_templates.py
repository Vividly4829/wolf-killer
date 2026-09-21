"""Install official Godot 4.6.2 Windows x64 templates without downloading other platforms.

Python 3 + requests. HTTPS byte ranges read the official ZIP; zipfile verifies
each extracted member's CRC. No engine/template binaries are stored in Git.
"""
import hashlib
import io
import os
from pathlib import Path
import zipfile
import requests

VERSION = "4.6.2"
URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"


class RemoteArchive(io.RawIOBase):
    def __init__(self):
        self.session = requests.Session()
        response = self.session.get(URL, headers={"Range": "bytes=0-0"}, timeout=60)
        response.raise_for_status()
        if response.status_code != 206:
            raise RuntimeError("The official download server did not accept byte ranges.")
        self.url = response.url
        self.length = int(response.headers["Content-Range"].split("/")[-1])
        self.position = 0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position

    def read(self, size=-1):
        size = self.length - self.position if size < 0 else min(size, self.length - self.position)
        if size <= 0: return b""
        end = self.position + size - 1
        response = self.session.get(self.url, headers={"Range": f"bytes={self.position}-{end}"}, timeout=180)
        response.raise_for_status()
        expected = f"bytes {self.position}-{end}/{self.length}"
        if response.status_code != 206 or response.headers.get("Content-Range") != expected:
            raise RuntimeError("Unexpected archive byte range; refusing incomplete template.")
        data = response.content
        if len(data) != size: raise RuntimeError("Truncated template archive range")
        self.position += size
        return data


if __name__ == "__main__":
    destination = Path(os.environ["APPDATA"]) / "Godot/export_templates" / f"{VERSION}.stable"
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RemoteArchive()) as archive:
        names = [n for n in archive.namelist() if Path(n).name in {
            "version.txt", "windows_release_x86_64.exe", "windows_debug_x86_64.exe",
            "windows_release_x86_64_console.exe", "windows_debug_x86_64_console.exe"}]
        for name in names:
            content = archive.read(name)
            target = destination / Path(name).name
            target.write_bytes(content)
            print(target.name, len(content), "bytes SHA256", hashlib.sha256(content).hexdigest(), flush=True)
    print("Installed official Windows templates in", destination)
