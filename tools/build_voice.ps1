# Rebuild the game's original opening dialogue using an installed Windows voice.
# No online service, voice cloning, or third-party game audio is used.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$voiceOutput = Join-Path $PSScriptRoot '../assets/audio/opening_line.wav'
$voiceDirectory = Split-Path -Parent $voiceOutput
New-Item -ItemType Directory -Path $voiceDirectory -Force | Out-Null
$narrator = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $narrator.SelectVoice('Microsoft David Desktop')
    $narrator.Rate = -1
    $narrator.Volume = 95
    $narrator.SetOutputToWaveFile($voiceOutput)
    $narrator.Speak('Should go out and do something about these wolves.')
} finally {
    $narrator.Dispose()
}
Write-Output $voiceOutput
