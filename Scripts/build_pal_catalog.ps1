param(
    [string]$FModelRoot = "D:\PalOutput\Exports\Pal\Content\Pal",
    [string]$GeneratedStaticLua = ".\generated_static_markers.lua",
    [string]$OutputLua = ".\generated_pal_catalog.lua",
    [string]$OutputCsv = ".\generated_pal_catalog_summary.csv"
)

$ErrorActionPreference = "Stop"

function Read-DataTableRows {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $rows = @()
    foreach ($asset in @($json)) {
        if ($asset.Rows) {
            foreach ($prop in $asset.Rows.PSObject.Properties) {
                $rows += [pscustomobject]@{
                    Name = [string]$prop.Name
                    Value = $prop.Value
                }
            }
        }
    }
    return $rows
}

function Get-RowMap {
    param([object[]]$Rows)
    $map = @{}
    foreach ($row in @($Rows)) {
        if ($row -and $row.Name -and -not $map.ContainsKey($row.Name)) {
            $map[$row.Name] = $row.Value
        }
    }
    return $map
}

function Clean-Value {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    $s = [string]$Value
    if ($s -eq "None") { return "" }
    return $s.Trim()
}

function Normalize-PalId {
    param([string]$PalId)
    $id = Clean-Value $PalId
    if (-not $id) { return "" }
    $id = $id -replace "^BOSS_", ""
    $id = $id -replace "^GYM_", ""
    $id = $id -replace "^RAID_", ""
    $id = $id -replace "^Quest_[^_]+_", ""
    $id = $id -replace "_Tower$", ""
    $id = $id -replace "_Oilrig$", ""
    $id = $id -replace "_Raid$", ""
    return $id
}

function Lua-String {
    param([object]$Value)
    if ($null -eq $Value) { return '""' }
    $s = [string]$Value
    $s = $s -replace "\\", "\\"
    $s = $s -replace '"', '\"'
    $s = $s -replace "`r", "\r"
    $s = $s -replace "`n", "\n"
    return '"' + $s + '"'
}

function Get-TextDataString {
    param(
        [object]$TextRowsById,
        [string]$TextId
    )
    if (-not $TextId -or -not $TextRowsById.ContainsKey($TextId)) { return "" }
    $row = $TextRowsById[$TextId]
    if ($row -and $row.TextData) {
        $localized = Clean-Value $row.TextData.LocalizedString
        if ($localized) { return $localized }
        return Clean-Value $row.TextData.SourceString
    }
    return ""
}

function Get-PalIconPath {
    param(
        [string]$PalId,
        [object]$IconRowsById
    )
    if ($IconRowsById.ContainsKey($PalId)) {
        $row = $IconRowsById[$PalId]
        if ($row -and $row.Icon -and $row.Icon.AssetPathName) {
            $path = Clean-Value $row.Icon.AssetPathName
            if ($path) { return $path }
        }
    }
    $textureName = "T_{0}_icon_normal" -f $PalId
    return "/Game/Pal/Texture/PalIcon/Normal/{0}.{0}" -f $textureName
}

function Get-NormalPalSpawnCounts {
    param([string]$Path)
    $counts = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $counts }

    $inNormalPal = $false
    foreach ($line in [IO.File]::ReadLines((Resolve-Path -LiteralPath $Path))) {
        if (-not $inNormalPal) {
            if ($line -match "^\s*NormalPal\s*=\s*\{") { $inNormalPal = $true }
            continue
        }
        if ($line -match "^    \},\s*$") { break }
        if ($line -match 'Pals\s*=\s*\{\s*"([^"]+)"') {
            $palId = Normalize-PalId $matches[1]
            if ($palId) {
                if (-not $counts.ContainsKey($palId)) { $counts[$palId] = 0 }
                $counts[$palId]++
            }
        }
    }
    return $counts
}

$monsterRows = Read-DataTableRows (Join-Path $FModelRoot "DataTable\Character\DT_PalMonsterParameter.json")
$palNameRows = Read-DataTableRows (Join-Path $FModelRoot "DataTable\Text\DT_PalNameText.json")
$palIconRows = Read-DataTableRows (Join-Path $FModelRoot "DataTable\Character\DT_PalCharacterIconDataTable.json")
$paldexDistributionRows = Read-DataTableRows (Join-Path $FModelRoot "DataTable\UI\DT_PaldexDistributionData.json")

$palNameById = Get-RowMap $palNameRows
$palIconById = Get-RowMap $palIconRows
$paldexDistributionById = Get-RowMap $paldexDistributionRows
$spawnCounts = Get-NormalPalSpawnCounts $GeneratedStaticLua

$catalogByDexKey = @{}
foreach ($prop in @($monsterRows)) {
    $row = $prop.Value
    if (-not $row -or $row.IsPal -ne $true) { continue }
    $dexNo = [int]($row.ZukanIndex)
    if ($dexNo -le 0) { continue }

    $rawId = [string]$prop.Name
    if ($rawId -match "^(BOSS_|GYM_|RAID_|Quest_)") { continue }
    if ($rawId -match "(_Oilrig|_Raid)$") { continue }
    $palId = Normalize-PalId $rawId
    if (-not $palId -or $palId -match "^SUMMON_") { continue }

    $suffix = Clean-Value $row.ZukanIndexSuffix
    if ($suffix -eq "None") { $suffix = "" }
    $dexKey = "{0:D3}{1}" -f $dexNo, $suffix

    $score = 0
    if ($rawId -eq $palId) { $score += 10 }
    if ($palIconById.ContainsKey($palId)) { $score += 4 }
    if ($paldexDistributionById.ContainsKey($palId)) { $score += 2 }
    if ($spawnCounts.ContainsKey($palId)) { $score += 1 }
    if ($catalogByDexKey.ContainsKey($dexKey) -and $catalogByDexKey[$dexKey].Score -ge $score) { continue }

    $nameTextId = Clean-Value $row.OverrideNameTextID
    if (-not $nameTextId) { $nameTextId = "PAL_NAME_$palId" }
    $localizedName = Get-TextDataString $palNameById $nameTextId
    if ($localizedName -eq "-") { $localizedName = "" }
    # The current exported text table is mojibake on this machine. Keep the
    # field reserved, but avoid writing unsafe garbled text into runtime Lua.
    $localizedName = ""

    $paldexLocationCount = 0
    if ($paldexDistributionById.ContainsKey($palId)) {
        $distribution = $paldexDistributionById[$palId]
        if ($distribution.dayTimeLocations -and $distribution.dayTimeLocations.Locations) {
            $paldexLocationCount += @($distribution.dayTimeLocations.Locations).Count
        }
        if ($distribution.nightTimeLocations -and $distribution.nightTimeLocations.Locations) {
            $paldexLocationCount += @($distribution.nightTimeLocations.Locations).Count
        }
    }

    $catalogByDexKey[$dexKey] = [pscustomobject]@{
        Id = $palId
        DexNo = $dexNo
        DexSuffix = $suffix
        DexKey = $dexKey
        NameTextId = $nameTextId
        LocalizedName = $localizedName
        IconPath = Get-PalIconPath $palId $palIconById
        SpawnPointCount = if ($spawnCounts.ContainsKey($palId)) { [int]$spawnCounts[$palId] } else { 0 }
        PaldexLocationCount = $paldexLocationCount
        HasPaldexDistribution = $paldexDistributionById.ContainsKey($palId)
        Score = $score
    }
}

$catalog = @($catalogByDexKey.Values | Sort-Object DexNo, DexSuffix, Id)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("-- generated_pal_catalog.lua")
$lines.Add("-- Generated by build_pal_catalog.ps1. Do not edit by hand.")
$lines.Add("return {")
$lines.Add("    PalCatalog = {")
foreach ($pal in $catalog) {
    $hasDistribution = if ($pal.HasPaldexDistribution) { "true" } else { "false" }
    $lines.Add("        {")
    $lines.Add("            Id = $(Lua-String $pal.Id),")
    $lines.Add("            DexNo = $($pal.DexNo),")
    $lines.Add("            DexSuffix = $(Lua-String $pal.DexSuffix),")
    $lines.Add("            DexKey = $(Lua-String $pal.DexKey),")
    $lines.Add("            NameTextId = $(Lua-String $pal.NameTextId),")
    $lines.Add("            LocalizedName = $(Lua-String $pal.LocalizedName),")
    $lines.Add("            IconPath = $(Lua-String $pal.IconPath),")
    $lines.Add("            SpawnPointCount = $($pal.SpawnPointCount),")
    $lines.Add("            PaldexLocationCount = $($pal.PaldexLocationCount),")
    $lines.Add("            HasPaldexDistribution = $hasDistribution,")
    $lines.Add("        },")
}
$lines.Add("    },")
$lines.Add("    Metadata = { PalCatalogRows = $(@($catalog).Count), NormalPalSpawnIds = $($spawnCounts.Count) },")
$lines.Add("}")

$outDir = Resolve-Path -LiteralPath (Split-Path -Parent $OutputLua)
[IO.File]::WriteAllLines((Join-Path $outDir (Split-Path -Leaf $OutputLua)), $lines, [Text.UTF8Encoding]::new($false))

$catalog |
    Select-Object Id,DexNo,DexSuffix,DexKey,NameTextId,LocalizedName,IconPath,SpawnPointCount,PaldexLocationCount,HasPaldexDistribution |
    Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Generated $OutputLua"
Write-Host "Generated $OutputCsv"
Write-Host ("PalCatalogRows: {0}" -f @($catalog).Count)
Write-Host ("NormalPalSpawnIds: {0}" -f $spawnCounts.Count)
