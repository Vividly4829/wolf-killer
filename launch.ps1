param([switch]$Editor, [switch]$CheckOnly)

$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$engineName = 'Godot_v4.6.2-stable_win64.exe'
$enginePath = Join-Path $gameRoot ('tools\' + $engineName)
$consolePath = Join-Path $gameRoot 'tools\Godot_v4.6.2-stable_win64_console.exe'
$projectPath = Join-Path $gameRoot 'project.godot'

try {
    if (-not (Test-Path -LiteralPath $projectPath)) {
        throw 'project.godot is missing. Keep this launcher inside the Wolf Island Godot folder.'
    }
    if (-not (Test-Path -LiteralPath $enginePath)) {
        # Source checkouts omit the portable engine. Accept an installed engine.
        if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN)) {
            $enginePath = $env:GODOT_BIN
        } else {
            $installedGodot = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $installedGodot) {
                throw 'Install Godot 4.6.2, then import project.godot in Godot. For this launcher, add Godot to PATH or set GODOT_BIN to its executable path.'
            }
            $enginePath = $installedGodot.Source
        }
        $consolePath = $enginePath
    }
    if (-not (Test-Path -LiteralPath $consolePath)) { $consolePath = $enginePath }

    # Import changed assets before running. Godot skips assets already up to date.
    $importLog = Join-Path $gameRoot 'tools\last-import.log'
    Write-Host 'Preparing Wolf Island...'
    & $consolePath --headless --path $gameRoot --import --log-file $importLog
    if ($LASTEXITCODE -ne 0) {
        throw "Godot could not import the project. See $importLog"
    }
    $importText = Get-Content -LiteralPath $importLog -Raw
    if ($importText -match '(?m)^(?:SCRIPT ERROR|ERROR):') {
        throw "Godot reported a project error. See $importLog"
    }
    if ($CheckOnly) { exit 0 }

    $engineArguments = @('--path', ('"' + $gameRoot + '"'))
    if ($Editor) { $engineArguments += '--editor' }
    Start-Process -FilePath $enginePath -ArgumentList $engineArguments -WorkingDirectory $gameRoot
} catch {
    Write-Host ('Unable to start Wolf Island: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
