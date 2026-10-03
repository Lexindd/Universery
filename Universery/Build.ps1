# Universery build script (module system v3).
# Each module file becomes a factory: __Modules["name"] = function(Require) ... end
# A tiny internal Require (with cycle detection + init-once cache) boots them in
# manifest order; parts (legacy slices) run after, seeing the chunk-local registry.
# PART files must never be hand-edited (see src/parts/README.md).
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$Modules = @(
    @{ Name = "registry"; Path = "src/00_registry.luau" },
    @{ Name = "gen/aimwork_blobs"; Path = "src/gen/aimwork_blobs.luau" },
    @{ Name = "Libraries/Aimwork/loader"; Path = "Libraries/Aimwork/loader.luau" },
    @{ Name = "Features/SilentAim/AimworkAdapter"; Path = "Features/SilentAim/AimworkAdapter.lua" },
    @{ Name = "Features/SilentAim/FireAdapter"; Path = "Features/SilentAim/FireAdapter.lua" },
    @{ Name = "Shared/TeamResolver"; Path = "Shared/TeamResolver.lua" }
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
function AddText([string]$s) {
    $b = $enc.GetBytes($s)
    $buf.AddRange($b)
}
function AddFile([string]$rel) {
    $p = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $p)) {
        throw ("missing file: {0}" -f $rel)
    }
    return [System.IO.File]::ReadAllBytes($p)
}
function AddBytes([byte[]]$b) {
    $buf.AddRange($b)
}

AddText("-- Universery dist bundle (built by Universery/Build.ps1). Do not edit.`n")
AddText("-- Module system: factories + internal Require (cycle-safe, init-once).`n")
AddText("local __Modules = {}`n")
AddText("local __Loaded = {}`n")
AddText("local __Loading = {}`n")
AddText("local function Require(name)`n")
AddText("`tif __Loaded[name] ~= nil then`n")
AddText("`t`treturn __Loaded[name]`n")
AddText("`tend`n")
AddText("`tif __Loading[name] then`n")
AddText("`t`terror(`"Circular dependency: `" .. tostring(name))`n")
AddText("`tend`n")
AddText("`tlocal factory = __Modules[name]`n")
AddText("`tassert(factory, `"Missing module: `" .. tostring(name))`n")
AddText("`t__Loading[name] = true`n")
AddText("`tlocal result = factory(Require)`n")
AddText("`t__Loading[name] = nil`n")
AddText("`tassert(result ~= nil, `"Module returned nil: `" .. tostring(name))`n")
AddText("`t__Loaded[name] = result`n")
AddText("`treturn result`n")
AddText("end`n")

foreach ($m in $Modules) {
    $b = AddFile($m.Path)
    AddText("__Modules[`"" + $m.Name + "`"] = function(Require)`n")
    AddBytes($b)
    if ($b[$b.Length - 1] -ne 10) {
        AddText("`n")
    }
    AddText("end`n")
    Write-Output ("module {0,-42} bytes {1}" -f $m.Path, $b.Length)
}

AddText("-- Boot: shared registry first, then every module exactly once, then parts.`n")
AddText("local Universery = Require(`"registry`")`n")
foreach ($m in $Modules) {
    if ($m.Name -ne "registry") {
        AddText("Require(`"" + $m.Name + "`")`n")
    }
}

foreach ($rel in $RawParts) {
    $b = AddFile($rel)
    AddBytes($b)
    Write-Output ("part   {0,-42} bytes {1}" -f $rel, $b.Length)
}

AddText("`nprint(`"[Universery] dist bundle (see ARCHITECTURE.md)`")`n")
[System.IO.File]::WriteAllBytes($OutFile, $buf.ToArray())

$h = (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash
Write-Output ("dist bytes: {0}" -f $buf.Count)
Write-Output ("dist sha256: {0}" -f $h)
Write-Output "validate: run validate_dist.py against the dist file"
