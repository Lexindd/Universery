# Universery build script (Phase M2a: registry + modules + parts).
# Manifest order = execution order. Module files (*.luau outside src/parts)
# are wrapped in do/end (register hygiene: their locals die, exports live on
# Universery.*). Part slices stay raw (they share chunk scope, Phase-1 proof).
# PART files must never be hand-edited: they are verbatim slices of the live
# artifact (see src/parts/README.md). New code goes to modules, never parts.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$WrappedModules = @(
    "src/00_registry.luau",
    "src/gen/aimwork_blobs.luau",
    "Libraries/Aimwork/loader.luau",
    "Features/SilentAim/AimworkAdapter.lua",
    "Features/SilentAim/FireAdapter.lua",
    "Shared/TeamResolver.lua"
)

$RawParts = @(
    "src/parts/00_Boot.luau",
    "src/parts/10_AimbotBase.luau",
    "src/parts/11_Environment.luau",
    "src/parts/12_AimbotCore.luau",
    "src/parts/13_ESP.luau",
    "src/parts/14_Methods.luau",
    "src/parts/15_SilentAim.luau",
    "src/parts/16_APIExit.luau",
    "src/parts/17_AutoStart.luau",
    "src/parts/18a_UIInfra.luau",
    "src/parts/18b_TabAimbot.luau",
    "src/parts/18c_TabESP.luau",
    "src/parts/18d_TabSilent.luau",
    "src/parts/18e_TabDebug.luau",
    "src/parts/18f_TabSettings.luau"
)

$OutDir = Join-Path $Root "dist"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutFile = Join-Path $OutDir "Universery.lua"

$enc = [System.Text.Encoding]::UTF8
$buf = New-Object System.Collections.Generic.List[byte]
foreach ($rel in $WrappedModules) {
    $p = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $p)) {
        throw ("missing module: {0}" -f $rel)
    }
    $b = [System.IO.File]::ReadAllBytes($p)
    $head = $enc.GetBytes("do -- module: " + $rel + "`n")
    $tail = $enc.GetBytes("`nend -- module: " + $rel + "`n")
    $buf.AddRange($head)
    $buf.AddRange($b)
    if ($b[$b.Length - 1] -ne 10) {
        $buf.Add(10)
    }
    $buf.AddRange($tail)
    Write-Output ("module {0,-42} bytes {1}" -f $rel, $b.Length)
}
foreach ($rel in $RawParts) {
    $p = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $p)) {
        throw ("missing part: {0}" -f $rel)
    }
    $b = [System.IO.File]::ReadAllBytes($p)
    $buf.AddRange($b)
    Write-Output ("part   {0,-42} bytes {1}" -f $rel, $b.Length)
}
[System.IO.File]::WriteAllBytes($OutFile, $buf.ToArray())
$marker = $enc.GetBytes("`nprint(`"[Universery] dist bundle (see ARCHITECTURE.md)`")`n")
$old = [System.IO.File]::ReadAllBytes($OutFile)
$final = New-Object System.Collections.Generic.List[byte]
$final.AddRange($old)
$final.AddRange($marker)
[System.IO.File]::WriteAllBytes($OutFile, $final.ToArray())

$h = (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash
Write-Output ("dist bytes: {0}" -f $buf.Count)
Write-Output ("dist sha256: {0}" -f $h)
Write-Output "verify: run bal.py + count2.py + chain.py against dist file"
