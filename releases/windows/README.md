# Windows build

[Download WolfIsland-Windows-x64.zip](https://github.com/Vividly4829/wolf-killer/raw/refs/heads/main/releases/windows/WolfIsland-Windows-x64.zip)

1. Download and extract the ZIP.
2. Double-click **WolfIsland.exe**.

Godot is not required. This is a Windows x64 build with the game data embedded in the executable. Keep the included engine and asset notices with it. Progress is saved separately in `%APPDATA%\Wolf Island`.

The build is unsigned. Version, source commit, file sizes and SHA-256 checksums are recorded in [build.json](build.json).

## Rebuild

Use Godot **4.6.2 Standard** and the matching Windows x64 export templates. Install templates through Godot's **Editor → Manage Export Templates**, or run `python tools/install_windows_templates.py` with Python and `requests` installed. The helper reads only the Windows templates from the official archive and validates each ZIP member.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_windows.ps1
```

Pass `-Godot C:\path\to\Godot.exe` or set `GODOT_BIN` when the engine is not bundled or on PATH. The export preset excludes test tools and generated captures, while including the JSON map/navigation data required at runtime. Raw build output is in `build/windows/`; the distributable archive and checksum manifest are in this folder.

The Windows export workflow follows [Godot's export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_windows.html).
