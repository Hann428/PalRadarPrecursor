param(
    [int] $LogTailLines = 260
)

$ErrorActionPreference = "SilentlyContinue"
$palRoot = "D:\Steam\steamapps\common\Palworld"
$reportPath = Join-Path $PSScriptRoot ("PalRadar_Diagnostic_Report_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Add-Line {
    param([string] $Text = "")
    Add-Content -LiteralPath $reportPath -Value $Text -Encoding UTF8
}

function Add-Section {
    param([string] $Title)
    Add-Line ""
    Add-Line ("==== {0} ====" -f $Title)
}

function Add-PathState {
    param([string] $Label, [string] $Path)
    $exists = Test-Path -LiteralPath $Path
    Add-Line ("{0}: {1} | {2}" -f $Label, $exists, $Path)
    if ($exists) {
        $item = Get-Item -LiteralPath $Path
        Add-Line ("  Type={0} Length={1} LastWrite={2}" -f $item.PSIsContainer, $item.Length, $item.LastWriteTime)
    }
}

New-Item -ItemType File -Path $reportPath -Force | Out-Null

Add-Line "PalRadar Diagnostic Report"
Add-Line ("Created: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Line ("Computer: {0}" -f $env:COMPUTERNAME)
Add-Line ("User: {0}" -f $env:USERNAME)

$paths = @{
    "Native UE4SS root" = Join-Path $palRoot "Mods\NativeMods\UE4SS"
    "Native runtime mod" = Join-Path $palRoot "Mods\NativeMods\UE4SS\Mods\PalRadarPrecursor"
    "Native mods.txt" = Join-Path $palRoot "Mods\NativeMods\UE4SS\Mods\mods.txt"
    "Native enabled.txt" = Join-Path $palRoot "Mods\NativeMods\UE4SS\Mods\enabled.txt"
    "Native UE4SS.log" = Join-Path $palRoot "Mods\NativeMods\UE4SS\UE4SS.log"
    "Workshop PalRadar" = "D:\Steam\steamapps\workshop\content\1623730\3777580435"
    "Workshop UE4SS" = "D:\Steam\steamapps\workshop\content\1623730\3625223587"
    "Win64 manual Mods" = Join-Path $palRoot "Pal\Binaries\Win64\Mods"
    "Win64 dwmapi.dll" = Join-Path $palRoot "Pal\Binaries\Win64\dwmapi.dll"
    "Win64 UE4SS.dll" = Join-Path $palRoot "Pal\Binaries\Win64\UE4SS.dll"
}

Add-Section "Path State"
foreach ($entry in $paths.GetEnumerator() | Sort-Object Key) {
    Add-PathState $entry.Key $entry.Value
}

Add-Section "Runtime Config"
$runtimeConfig = Join-Path $palRoot "Mods\NativeMods\UE4SS\Mods\PalRadarPrecursor\Scripts\config.lua"
if (Test-Path -LiteralPath $runtimeConfig) {
    Select-String -LiteralPath $runtimeConfig -Pattern "MapWidgetHookMode|MapHookPollingLogInterval|RegisterMapDestructHook|RegisterMapToggleKey|EnablePackagedTextureCandidates|MaxLiveIcons|BatchSize|BatchIntervalMs|MaxPerCategory" |
        ForEach-Object { Add-Line ("{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()) }
} else {
    Add-Line "Runtime config.lua was not found."
}

Add-Section "mods.txt"
$modsTxt = Join-Path $palRoot "Mods\NativeMods\UE4SS\Mods\mods.txt"
if (Test-Path -LiteralPath $modsTxt) {
    Get-Content -LiteralPath $modsTxt | ForEach-Object { Add-Line $_ }
} else {
    Add-Line "mods.txt was not found."
}

Add-Section "UE4SS Log Tail"
$ue4ssLog = Join-Path $palRoot "Mods\NativeMods\UE4SS\UE4SS.log"
if (Test-Path -LiteralPath $ue4ssLog) {
    Get-Content -LiteralPath $ue4ssLog -Tail $LogTailLines | ForEach-Object { Add-Line $_ }
} else {
    Add-Line "UE4SS.log was not found."
}

Add-Section "PalRadar Log Files"
$runtimeScripts = Join-Path $palRoot "Mods\NativeMods\UE4SS\Mods\PalRadarPrecursor\Scripts"
if (Test-Path -LiteralPath $runtimeScripts) {
    Get-ChildItem -LiteralPath $runtimeScripts -Filter "PalRadar*Log*.txt" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 8 |
        ForEach-Object {
            Add-Line ("-- {0} | {1} bytes | {2}" -f $_.FullName, $_.Length, $_.LastWriteTime)
            Get-Content -LiteralPath $_.FullName -Tail 80 | ForEach-Object { Add-Line $_ }
        }
} else {
    Add-Line "Runtime Scripts folder was not found."
}

Add-Section "Recent Crash Dumps"
$win64 = Join-Path $palRoot "Pal\Binaries\Win64"
if (Test-Path -LiteralPath $win64) {
    Get-ChildItem -LiteralPath $win64 -Filter "crash_*.dmp" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 12 |
        ForEach-Object { Add-Line ("{0} | {1} bytes | {2}" -f $_.FullName, $_.Length, $_.LastWriteTime) }
} else {
    Add-Line "Win64 folder was not found."
}

Add-Line ""
Add-Line ("Report written to: {0}" -f $reportPath)
Write-Host "Report written to: $reportPath"
