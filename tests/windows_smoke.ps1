#Requires -Version 5.1
# End-to-end smoke test of the Windows install path of getcsound.ps1.
#
# Runs on a real Windows CI runner and exercises the real code path: GitHub API
# run/artifact resolution, nightly.link download, Expand-Archive extraction, and
# a real silent install (GitHub-hosted Windows runners are elevated already). It
# then verifies the installed csound binary works by rendering a small .csd.
#
# This depends on the csound/csound "develop" branch having a recent successful
# build with a Windows x64 artifact.
#
# When RENDER_ARTIFACT_DIR is set, the rendered output, the .csd and the logs
# are copied there so CI can upload them for inspection.

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Join-Path $PSScriptRoot '..')

$Work = Join-Path ([System.IO.Path]::GetTempPath()) ("csound-win-smoke-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

$ArtifactDir = $env:RENDER_ARTIFACT_DIR
if ($ArtifactDir) { New-Item -ItemType Directory -Path $ArtifactDir -Force | Out-Null }

$Log = Join-Path $Work 'install.log'

function Save-Artifact {
    param([string]$Path, [string]$Name)
    if ($ArtifactDir -and (Test-Path -LiteralPath $Path)) {
        Copy-Item -LiteralPath $Path -Destination (Join-Path $ArtifactDir $Name) -Force
    }
}

function Fail {
    param([string]$Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
    if ($Log -and (Test-Path -LiteralPath $Log)) {
        Write-Host '--- getcsound.ps1 output ---'
        Get-Content -LiteralPath $Log | ForEach-Object { Write-Host $_ }
    }
    exit 1
}

# --- Syntax check --------------------------------------------------
$tokens = $null
$parseErrors = $null
$ScriptPath = (Resolve-Path -LiteralPath './getcsound.ps1').Path
[System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -gt 0) { Fail 'getcsound.ps1 has syntax errors' }

# --- Run the installer (under Windows PowerShell 5.1) --------------
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath > $Log 2>&1
$rc = $LASTEXITCODE
Save-Artifact $Log 'install.log'
if ($rc -ne 0) { Fail "getcsound.ps1 exited with $rc" }

$output = Get-Content -LiteralPath $Log -Raw
if ($output -notmatch 'Using workflow run:') { Fail 'no workflow run was resolved' }
if ($output -notmatch 'Using artifact: Csound_x64') { Fail 'no matching Windows artifact was resolved' }
if ($output -notmatch 'Installer: Csound7-windows_x86_64') { Fail 'no installer .exe was located' }
if ($output -notmatch 'Csound installed successfully\.') { Fail 'install did not complete' }

# --- Verify the installed binary -----------------------------------
$ProgramFiles = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
$CsoundExe = Join-Path $ProgramFiles 'Csound7\bin\csound.exe'
if (-not (Test-Path -LiteralPath $CsoundExe)) { Fail "csound binary not found at $CsoundExe" }

$version = & $CsoundExe --version 2>&1
if ($LASTEXITCODE -ne 0) {
    $version | ForEach-Object { Write-Host $_ }
    Fail 'csound --version failed'
}
Write-Host "csound --version: $version"

# --- Render a trivial instrument to a WAV file on disk -------------
$Csd = @'
<CsoundSynthesizer>
<CsInstruments>
sr = 44100
kr = 4410
ksmps = 10
nchnls = 1
0dbfs = 1

instr 1
  a1 oscili p4, p5
  outch 1, a1
endin

</CsInstruments>
<CsScore>
i 1 0 1 0.5 440
i 1 1 1 0.5 880
e
</CsScore>
</CsoundSynthesizer>
'@

$CsdPath = Join-Path $Work 'render.csd'
Set-Content -LiteralPath $CsdPath -Value $Csd -Encoding ASCII
Save-Artifact $CsdPath 'render.csd'

$RenderLog = Join-Path $Work 'render.log'
$WavPath = Join-Path $Work 'out.wav'
Push-Location $Work
try {
    & $CsoundExe -W -o out.wav render.csd > $RenderLog 2>&1
    $renderRc = $LASTEXITCODE
} finally {
    Pop-Location
}
Save-Artifact $RenderLog 'render.log'
Save-Artifact $WavPath 'out.wav'

if ($renderRc -ne 0) {
    Get-Content -LiteralPath $RenderLog | ForEach-Object { Write-Host $_ }
    Fail "csound render exited with $renderRc"
}
if (-not (Test-Path -LiteralPath $WavPath)) {
    Get-Content -LiteralPath $RenderLog | ForEach-Object { Write-Host $_ }
    Fail 'no output file written'
}

$size = (Get-Item -LiteralPath $WavPath).Length
if ($size -eq 0) {
    Get-Content -LiteralPath $RenderLog | ForEach-Object { Write-Host $_ }
    Fail 'rendered output is empty'
}

Write-Host "Windows install + render smoke test OK: $WavPath ($size bytes)"
Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
