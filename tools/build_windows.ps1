param([string]$Godot = $env:GODOT_BIN, [string]$OutputDirectory = 'build/windows')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $bundledEngine = Join-Path $PSScriptRoot 'Godot_v4.6.2-stable_win64_console.exe'
    if (Test-Path -LiteralPath $bundledEngine) { $Godot = $bundledEngine }
    else {
        $installed = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $installed) { throw 'Install Godot 4.6.2 and set GODOT_BIN or pass -Godot.' }
        $Godot = $installed.Source
    }
}
$buildRoot = Join-Path $projectRoot $OutputDirectory
$releaseRoot = Join-Path $projectRoot 'releases/windows'
New-Item -ItemType Directory -Force -Path $buildRoot, $releaseRoot | Out-Null
$exePath = Join-Path $buildRoot 'WolfIsland.exe'
& $Godot --headless --path $projectRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed.' }
& $Godot --headless --path $projectRoot --export-release 'Windows Desktop' $exePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) { throw 'Windows export failed. Install the Godot 4.6.2 export templates.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'GODOT-LICENSE.txt') -Destination (Join-Path $buildRoot 'GODOT-LICENSE.txt') -Force
$creditsRoot = Join-Path $buildRoot 'asset-credits'
New-Item -ItemType Directory -Force -Path $creditsRoot | Out-Null
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'assets') -Recurse -Filter '*.md' | ForEach-Object {
    $relative = $_.FullName.Substring((Join-Path $projectRoot 'assets').Length + 1).Replace('\', '_')
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $creditsRoot $relative) -Force
}
@'
WOLF ISLAND - WINDOWS X64

Extract this entire ZIP, then double-click WolfIsland.exe.
Godot is not required. Game data is embedded in the executable.
INTERNET CO-OP: choose HOST INTERNET / 4 PLAYERS. First hosting downloads a
verified 55 MB Cloudflare helper. Invite copies automatically; friends paste
it into JOIN. Pause > COPY INTERNET INVITE copies it again. No port forwarding.
Experimental free playtest relay: availability is not guaranteed. Host must stay open.
Progress is stored in %APPDATA%\Wolf Island, outside this folder.
The build is unsigned. Local split screen supports 2, 3 or 4 players. P1 uses keyboard/mouse;
P2-P4 each use a separate controller. Select the player count in the main menu.
Source and updates: https://github.com/Vividly4829/wolf-killer
Engine and asset notices accompany the executable.
'@ | Set-Content -LiteralPath (Join-Path $buildRoot 'PLAY.txt') -Encoding UTF8
$archivePath = Join-Path $releaseRoot 'WolfIsland-Windows-x64.zip'
Compress-Archive -Path (Join-Path $buildRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal -Force
$sourceCommit = (& git -C $projectRoot rev-parse HEAD).Trim()
$manifest = [ordered]@{
    name = 'Wolf Island'; version = '0.1.0'; platform = 'Windows x86_64'
    engine = 'Godot 4.6.2 stable'; source_commit = $sourceCommit
    built_utc = [DateTime]::UtcNow.ToString('o')
    archive = 'WolfIsland-Windows-x64.zip'
    archive_bytes = (Get-Item -LiteralPath $archivePath).Length
    archive_sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    executable = 'WolfIsland.exe'
    executable_bytes = (Get-Item -LiteralPath $exePath).Length
    executable_sha256 = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $releaseRoot 'build.json') -Encoding UTF8
Write-Output "Windows archive: $archivePath"
