param(
    [string]$FModelRoot = "D:\PalOutput\Exports\Pal\Content\Pal",
    [string]$OutputLua = ".\generated_static_markers.lua",
    [string]$OutputCsv = ".\generated_static_markers_summary.csv"
)

$ErrorActionPreference = "Stop"

function Read-DataTableRows {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing data table: $Path"
    }

    $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if (-not $json -or -not $json[0].Rows) {
        throw "Unexpected data table shape: $Path"
    }

    return @($json[0].Rows.PSObject.Properties)
}

function Lua-String {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return "nil" }
    $s = [string]$Value
    $s = $s -replace "\\", "\\"
    $s = $s -replace '"', '\"'
    $s = $s -replace "`r", "\r"
    $s = $s -replace "`n", "\n"
    return '"' + $s + '"'
}

function Lua-Number {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return "0.0" }
    $d = [double]$Value
    return $d.ToString("0.######", [Globalization.CultureInfo]::InvariantCulture)
}

function Clean-Value {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return $null }
    $s = [string]$Value
    if ($s -eq "" -or $s -eq "None" -or $s -eq "RowName") { return $null }
    return $s
}

function Get-NonEmptyList {
    param(
        [object]$Row,
        [string]$Prefix
    )

    $items = @()
    for ($i = 1; $i -le 3; $i++) {
        $name = Clean-Value $Row.("$Prefix$i")
        if ($name) { $items += $name }
    }
    return $items
}

function Read-OptionalDataTableRows {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Optional data table not found: $Path"
        return @()
    }

    try {
        return @(Read-DataTableRows $Path)
    } catch {
        Write-Host "Optional data table unreadable: $Path detail=$($_.Exception.Message)"
        return @()
    }
}

function Get-RowMap {
    param([object[]]$Rows)

    $map = @{}
    foreach ($prop in @($Rows)) {
        if ($prop -and $prop.Name) {
            $map[[string]$prop.Name] = $prop.Value
        }
    }
    return $map
}

function Normalize-PalId {
    param([AllowNull()][string]$Value)

    $palId = Clean-Value $Value
    if (-not $palId) { return $null }
    $palId = $palId -replace "^BOSS_", ""
    $palId = $palId -replace "^GYM_", ""
    $palId = $palId -replace "^RAID_", ""
    $palId = $palId -replace "^Quest_[^_]+_", ""
    $palId = $palId -replace "_Tower$", ""
    $palId = $palId -replace "_Oilrig$", ""
    return $palId
}

function Get-TextDataString {
    param(
        [object]$TextRowsById,
        [AllowNull()][string]$TextId
    )

    $key = Clean-Value $TextId
    if (-not $key -or -not $TextRowsById.ContainsKey($key)) { return $null }

    $row = $TextRowsById[$key]
    if ($row -and $row.TextData) {
        $localized = Clean-Value $row.TextData.LocalizedString
        if ($localized) { return $localized }
        $source = Clean-Value $row.TextData.SourceString
        if ($source) { return $source }
    }
    return $null
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

function Get-NpcMarkerCategory {
    param(
        [string[]]$Npcs,
        [object]$Wild
    )

    $parts = @()
    foreach ($npc in @($Npcs)) {
        if ($npc) { $parts += [string]$npc }
    }
    if ($Wild) {
        if ($Wild.SpawnerName) { $parts += [string]$Wild.SpawnerName }
        if ($Wild.SpawnerType) { $parts += [string]$Wild.SpawnerType }
    }
    $text = ($parts -join " ").ToLowerInvariant()

    if ($text -match "merchant|marchant|sales|salsman|trader|dealer|shop") {
        return "NPCMerchant"
    }
    return "NPCOther"
}

function Get-LevelText {
    param([object]$Row)

    $levels = @()
    for ($i = 1; $i -le 3; $i++) {
        $min = $Row.("LvMin_$i")
        $max = $Row.("LvMax_$i")
        if ($null -ne $min -and $null -ne $max) {
            $minInt = [int]$min
            $maxInt = [int]$max
            if ($minInt -gt 0 -or $maxInt -gt 0) {
                if ($minInt -eq $maxInt) {
                    $levels += [string]$minInt
                } else {
                    $levels += "$minInt-$maxInt"
                }
            }
        }
    }
    return ($levels -join ",")
}

function Get-MarkerCategory {
    param(
        [object]$Placement,
        [object]$Wild,
        [string[]]$Pals,
        [string[]]$Npcs
    )

    $type = [string]$Placement.SpawnerType
    if ($Wild -and $Wild.SpawnerType) {
        $type = [string]$Wild.SpawnerType
    }

    if ($type -match "FieldBoss|ImprisonmentBoss") {
        return "Boss"
    }
    if ($type -match "RandomDungeonBoss") {
        return "DungeonBoss"
    }
    if ([string]$Placement.PlacementType -match "Dungeon") {
        return "Dungeon"
    }
    if ($Npcs.Count -gt 0) {
        return Get-NpcMarkerCategory $Npcs $Wild
    }
    if ($Pals.Count -gt 0) {
        return "NormalPal"
    }
    return "Custom"
}

function Get-IconIndex {
    param([string]$Category)

    switch ($Category) {
        "Boss" { return 0 }
        "BossTower" { return 0 }
        "Dungeon" { return 2 }
        "DungeonBoss" { return 0 }
        "NPC" { return 11 }
        "NPCMerchant" { return 11 }
        "NPCOther" { return 11 }
        "FastTravel" { return 1 }
        "MapUnlock" { return 1 }
        "Chest" { return 12 }
        "SkillFruit" { return 4 }
        "Relic" { return 4 }
        "RelicCommon" { return 4 }
        "PalRelicStatue" { return 4 }
        "PickupItem" { return 4 }
        "OilField" { return 12 }
        "TreasureMapPointStatic" { return 4 }
        "Note" { return 4 }
        "PalEgg" { return 4 }
        "FishingSpot" { return 4 }
        "FishingJunkSpot" { return 4 }
        "ResourceNode" { return 4 }
        "NormalPal" { return 4 }
        default { return 0 }
    }
}

function Get-ObjectInstancePath {
    param([AllowNull()][string]$ObjectName)

    if (-not $ObjectName) { return $null }
    if ($ObjectName -match "^[^']+'(.+)'$") {
        return $Matches[1]
    }
    return $null
}

function Get-SafeIdPart {
    param([AllowNull()][string]$Value)

    $text = [string]$Value
    if (-not $text) { return "unnamed" }
    return ($text -replace "[^A-Za-z0-9_]+", "_").Trim("_")
}

function Add-MainWorldActorMarkers {
    param(
        [string]$MapPath,
        [object]$Categories,
        [System.Collections.ArrayList]$SummaryRows
    )

    if (-not (Test-Path -LiteralPath $MapPath)) {
        Write-Host "MainWorld map JSON not found, skipping placed actor markers: $MapPath"
        return
    }

    Write-Host "Reading placed actors: $MapPath"
    $objects = Get-Content -LiteralPath $MapPath -Raw | ConvertFrom-Json
    if (-not $objects) { return }

    $locationByComponentObjectName = @{}
    foreach ($obj in $objects) {
        $props = $obj.Properties
        if (-not $props -or -not $props.RelativeLocation) { continue }

        $outerName = if ($obj.Outer) { [string]$obj.Outer.ObjectName } else { $null }
        $ownerPath = Get-ObjectInstancePath $outerName
        if (-not $ownerPath) { continue }

        $componentObjectName = "{0}'{1}.{2}'" -f ([string]$obj.Type), $ownerPath, ([string]$obj.Name)
        $locationByComponentObjectName[$componentObjectName] = $props.RelativeLocation
    }

    foreach ($obj in $objects) {
        $props = $obj.Properties
        $classText = "{0} {1} {2} {3}" -f ([string]$obj.Type), ([string]$obj.Name), ([string]$obj.Class), ([string]$obj.ActorLabel)
        $category = $null

        if ($classText -match "BP_LevelObject_TowerFastTravelPoint") {
            $category = "FastTravel"
        } elseif ($classText -match "BP_LevelObject_UnlockMapPoint") {
            $category = "MapUnlock"
        } elseif ($classText -match "BP_PalBossTower") {
            $category = "BossTower"
        } elseif ($classText -match "BP_LevelObject_TreasureMapPoint|BP_TreasureMapInteractivePoint") {
            $category = "TreasureMapPointStatic"
        } elseif ($classText -match "BP_LevelObject_Note") {
            $category = "Note"
        } else {
            continue
        }

        if (-not $Categories.Contains($category)) {
            $Categories[$category] = @()
        }

        $rootObjectName = if ($props -and $props.RootComponent) { [string]$props.RootComponent.ObjectName } else { $null }
        $location = if ($rootObjectName -and $locationByComponentObjectName.ContainsKey($rootObjectName)) {
            $locationByComponentObjectName[$rootObjectName]
        } else {
            $null
        }
        if (-not $location -or $null -eq $location.X -or $null -eq $location.Y) {
            continue
        }

        $safeId = Get-SafeIdPart ([string]$obj.Name)
        $displayName = if ($category -eq "Note" -and $props -and $props.NoteRowName -and $props.NoteRowName.Key) {
            [string]$props.NoteRowName.Key
        } elseif ($obj.ActorLabel) {
            [string]$obj.ActorLabel
        } else {
            [string]$obj.Name
        }
        $marker = [pscustomobject]@{
            Id = "fmodel_" + $category.ToLowerInvariant() + "_" + $safeId
            Name = $displayName
            Category = $category
            X = [double]$location.X
            Y = [double]$location.Y
            Z = [double]$location.Z
            IconIndex = Get-IconIndex $category
            SpawnerName = ""
            SpawnerType = ""
            WildSpawnerType = ""
            PlacementType = [string]$obj.Type
            WorldName = "PL_MainWorld5"
            Pals = @()
            NPCs = @()
            Levels = ""
            Source = "FModel:Maps/MainWorld_5/PL_MainWorld5"
        }

        $Categories[$category] += $marker
        [void]$SummaryRows.Add($marker)
    }
}

function New-StaticMarker {
    param(
        [string]$Category,
        [string]$Id,
        [string]$Name,
        [object]$Location,
        [string]$PlacementType,
        [string]$Source
    )

    return [pscustomobject]@{
        Id = $Id
        Name = $Name
        Category = $Category
        X = [double]$Location.X
        Y = [double]$Location.Y
        Z = [double]$Location.Z
        IconIndex = Get-IconIndex $Category
        SpawnerName = ""
        SpawnerType = ""
        WildSpawnerType = ""
        PlacementType = $PlacementType
        WorldName = "PL_MainWorld5"
        Pals = @()
        NPCs = @()
        Levels = ""
        Source = $Source
    }
}

function Get-GeneratedCellCandidateFiles {
    param(
        [string]$GeneratedCellsPath,
        [string]$Pattern
    )

    if (-not (Test-Path -LiteralPath $GeneratedCellsPath)) {
        return @()
    }

    $patternParts = @($Pattern -split "\|" | Where-Object { $_ })
    if ($patternParts.Count -gt 0 -and [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        $jsonGlob = Join-Path $GeneratedCellsPath "*.json"
        $cmdArgs = @("/c", "findstr", "/s", "/m", "/i")
        foreach ($part in $patternParts) {
            $cmdArgs += "/c:$part"
        }
        $cmdArgs += $jsonGlob

        $result = @(& cmd @cmdArgs 2>$null)
        if ($result.Count -gt 0) {
            return @($result | Select-Object -Unique)
        }
    }

    $rg = Get-Command rg -ErrorAction SilentlyContinue
    if ($rg) {
        return @(& rg -l -i $Pattern $GeneratedCellsPath)
    }

    return @(
        Get-ChildItem -LiteralPath $GeneratedCellsPath -File -Filter *.json |
            Select-String -Pattern $Pattern -List |
            ForEach-Object { $_.Path }
    )
}

function Add-GeneratedCellActorMarkers {
    param(
        [string]$GeneratedCellsPath,
        [object]$Categories,
        [System.Collections.ArrayList]$SummaryRows
    )

    if (-not (Test-Path -LiteralPath $GeneratedCellsPath)) {
        Write-Host "Generated cell JSON folder not found, skipping cell actor markers: $GeneratedCellsPath"
        return
    }

    $rules = @(
        @{ Category = "Chest"; Pattern = "BP_PalMapObjectSpawnerTreasureBox" },
        @{ Category = "TreasureMapPointStatic"; Pattern = "BP_LevelObject_TreasureMapPoint" },
        @{ Category = "TreasureMapPointStatic"; Pattern = "BP_TreasureMapInteractivePoint" },
        @{ Category = "SkillFruit"; Pattern = "BP_PalMapObjectSpawner_SkillFruits" },
        @{ Category = "Note"; Pattern = "BP_LevelObject_Note" },
        @{ Category = "PalEgg"; Pattern = "bp_palmapobjectspawner_palegg" },
        @{ Category = "PalEgg"; Pattern = "BP_MapObject_PickupItem_PalEgg" },
        @{ Category = "FishingSpot"; Pattern = "BP_FishingSpot" },
        @{ Category = "FishingJunkSpot"; Pattern = "BP_MapObject_FishingJunkSpot" },
        @{ Category = "ResourceNode"; Pattern = "BP_PalMapObjectSpawner_RockCoal" },
        @{ Category = "ResourceNode"; Pattern = "BP_PalMapObjectSpawner_RockQuartz" },
        @{ Category = "ResourceNode"; Pattern = "BP_PalMapObjectSpawner_SkyIslandOre" },
        @{ Category = "ResourceNode"; Pattern = "BP_PalMapObjectSpawner_Sulfur" },
        @{ Category = "ResourceNode"; Pattern = "BP_PalMapObjectSpawner_WorldTreeOre" },
        @{ Category = "Relic"; Pattern = "BP_LevelObject_Relic" },
        @{ Category = "PickupItem"; Pattern = "BP_MapObject_PickupItem" },
        @{ Category = "OilField"; Pattern = "BP_LevelObject_OilField" }
    )
    $combinedPattern = ($rules | ForEach-Object { $_.Pattern }) -join "|"
    $candidateFiles = @(Get-GeneratedCellCandidateFiles $GeneratedCellsPath $combinedPattern)

    if ($candidateFiles.Count -eq 0) {
        Write-Host "No generated cell actor marker candidates found in: $GeneratedCellsPath"
        return
    }

    Write-Host "Reading generated cell actor marker candidates: $($candidateFiles.Count) files"
    $dedupeLocations = @{}
    $skippedInvalidJson = 0

    foreach ($filePath in $candidateFiles) {
        $objects = $null
        try {
            $objects = Get-Content -LiteralPath $filePath -Raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            $skippedInvalidJson++
            Write-Host "Skipping invalid generated cell JSON: $filePath"
            continue
        }
        if (-not $objects) { continue }

        $locationByComponentObjectName = @{}
        foreach ($obj in $objects) {
            $props = $obj.Properties
            if (-not $props -or -not $props.RelativeLocation) { continue }

            $outerName = if ($obj.Outer) { [string]$obj.Outer.ObjectName } else { $null }
            $ownerPath = Get-ObjectInstancePath $outerName
            if (-not $ownerPath) { continue }

            $componentObjectName = "{0}'{1}.{2}'" -f ([string]$obj.Type), $ownerPath, ([string]$obj.Name)
            $locationByComponentObjectName[$componentObjectName] = $props.RelativeLocation
        }

        foreach ($obj in $objects) {
            $props = $obj.Properties
            if (-not $props -or -not $props.RootComponent) { continue }

            $classText = "{0} {1} {2} {3}" -f ([string]$obj.Type), ([string]$obj.Name), ([string]$obj.Class), ([string]$obj.ActorLabel)
            $category = $null
            foreach ($rule in $rules) {
                if ($classText -match $rule.Pattern) {
                    $category = [string]$rule.Category
                    break
                }
            }
            if (-not $category) { continue }

            if (-not $Categories.Contains($category)) {
                $Categories[$category] = @()
            }

            $rootObjectName = [string]$props.RootComponent.ObjectName
            $location = if ($rootObjectName -and $locationByComponentObjectName.ContainsKey($rootObjectName)) {
                $locationByComponentObjectName[$rootObjectName]
            } else {
                $null
            }
            if (-not $location -or $null -eq $location.X -or $null -eq $location.Y) {
                continue
            }

            $locationKey = "{0}:{1}:{2}:{3}" -f $category, [math]::Round([double]$location.X, 0), [math]::Round([double]$location.Y, 0), [math]::Round([double]$location.Z, 0)
            if ($dedupeLocations.ContainsKey($locationKey)) {
                continue
            }
            $dedupeLocations[$locationKey] = $true

            $safeId = Get-SafeIdPart ([string]$obj.Name)
            $displayName = if ($category -eq "Note" -and $props.NoteRowName -and $props.NoteRowName.Key) {
                [string]$props.NoteRowName.Key
            } elseif ($obj.ActorLabel) {
                [string]$obj.ActorLabel
            } else {
                [string]$obj.Name
            }
            $marker = New-StaticMarker `
                -Category $category `
                -Id ("fmodel_" + $category.ToLowerInvariant() + "_" + $safeId) `
                -Name $displayName `
                -Location $location `
                -PlacementType ([string]$obj.Type) `
                -Source ("FModel:Maps/MainWorld_5/PL_MainWorld5/_Generated_/" + [IO.Path]::GetFileNameWithoutExtension($filePath))

            $Categories[$category] += $marker
            [void]$SummaryRows.Add($marker)
        }
    }

    if ($skippedInvalidJson -gt 0) {
        Write-Host "Skipped invalid generated cell JSON files: $skippedInvalidJson"
    }
}

$placementPath = Join-Path $FModelRoot "DataTable\Spawner\DT_PalSpawnerPlacement.json"
$wildPath = Join-Path $FModelRoot "DataTable\Spawner\DT_PalWildSpawner.json"

$placementRows = Read-DataTableRows $placementPath
$wildRows = Read-DataTableRows $wildPath

$wildByName = @{}
foreach ($prop in $wildRows) {
    $row = $prop.Value
    $keys = @($prop.Name)
    if ($row.SpawnerName) { $keys += [string]$row.SpawnerName }

    foreach ($key in $keys) {
        if (-not $wildByName.ContainsKey($key)) { $wildByName[$key] = @() }
        $wildByName[$key] += $row
    }
}

$categories = [ordered]@{
    Boss = @()
    BossTower = @()
    Dungeon = @()
    DungeonBoss = @()
    NPC = @()
    NPCMerchant = @()
    NPCOther = @()
    FastTravel = @()
    MapUnlock = @()
    Chest = @()
    SkillFruit = @()
    Relic = @()
    RelicCommon = @()
    PalRelicStatue = @()
    PickupItem = @()
    OilField = @()
    TreasureMapPointStatic = @()
    Note = @()
    PalEgg = @()
    FishingSpot = @()
    FishingJunkSpot = @()
    ResourceNode = @()
    Collectible = @()
    NormalPal = @()
    Custom = @()
}
$summaryRows = New-Object System.Collections.ArrayList
$dedupeByCategoryAndLocation = @{}
$unjoined = 0
$skippedUnknown = 0
$dedupedRows = 0

foreach ($prop in $placementRows) {
    $placement = $prop.Value
    $spawnerName = [string]$placement.SpawnerName
    $wild = $null
    if ($wildByName.ContainsKey($spawnerName)) {
        $wild = @($wildByName[$spawnerName] | Where-Object {
            (Clean-Value $_.Pal_1) -or (Clean-Value $_.NPC_1)
        } | Select-Object -First 1)[0]
        if (-not $wild) {
            $wild = @($wildByName[$spawnerName] | Select-Object -First 1)[0]
        }
    } else {
        $unjoined++
    }

    $pals = if ($wild) { @(Get-NonEmptyList $wild "Pal_") } else { @() }
    $npcs = if ($wild) { @(Get-NonEmptyList $wild "NPC_") } else { @() }
    $category = Get-MarkerCategory $placement $wild $pals $npcs
    if ($category -eq "Custom") {
        $skippedUnknown++
        continue
    }
    if (-not $categories.Contains($category)) { $categories[$category] = @() }

    $displayName = $spawnerName
    if ($pals.Count -gt 0) { $displayName = ($pals -join "+") }
    if ($npcs.Count -gt 0) { $displayName = ($npcs -join "+") }

    $location = $placement.Location
    if (-not $location -or $null -eq $location.X -or $null -eq $location.Y) {
        continue
    }

    if ($category -eq "Dungeon") {
        $dedupeKey = "{0}:{1}:{2}:{3}" -f $category, [math]::Round([double]$location.X, 0), [math]::Round([double]$location.Y, 0), [math]::Round([double]$location.Z, 0)
        if ($dedupeByCategoryAndLocation.ContainsKey($dedupeKey)) {
            $dedupedRows++
            continue
        }
        $dedupeByCategoryAndLocation[$dedupeKey] = $true
    }

    $id = "fmodel_" + $category.ToLowerInvariant() + "_" + $prop.Name
    $levelText = if ($wild) { Get-LevelText $wild } else { "" }
    $worldName = [string]$placement.WorldName
    $placementType = [string]$placement.PlacementType
    $spawnerType = [string]$placement.SpawnerType
    $wildType = if ($wild) { [string]$wild.SpawnerType } else { "" }
    $iconIndex = Get-IconIndex $category

    $marker = [pscustomobject]@{
        Id = $id
        Name = $displayName
        Category = $category
        X = [double]$location.X
        Y = [double]$location.Y
        Z = [double]$location.Z
        IconIndex = $iconIndex
        SpawnerName = $spawnerName
        SpawnerType = $spawnerType
        WildSpawnerType = $wildType
        PlacementType = $placementType
        WorldName = $worldName
        Pals = $pals
        NPCs = $npcs
        Levels = $levelText
        Source = "FModel:DataTable/Spawner"
    }

    $categories[$category] += $marker
    [void]$summaryRows.Add($marker)
}

$mainWorldPath = Join-Path $FModelRoot "Maps\MainWorld_5\PL_MainWorld5.json"
Add-MainWorldActorMarkers $mainWorldPath $categories $summaryRows
$generatedCellsPath = Join-Path $FModelRoot "Maps\MainWorld_5\PL_MainWorld5\_Generated_"
Add-GeneratedCellActorMarkers $generatedCellsPath $categories $summaryRows

$monsterRows = Read-OptionalDataTableRows (Join-Path $FModelRoot "DataTable\Character\DT_PalMonsterParameter.json")
$palNameRows = Read-OptionalDataTableRows (Join-Path $FModelRoot "DataTable\Text\DT_PalNameText.json")
$palIconRows = Read-OptionalDataTableRows (Join-Path $FModelRoot "DataTable\Character\DT_PalCharacterIconDataTable.json")
$paldexDistributionRows = Read-OptionalDataTableRows (Join-Path $FModelRoot "DataTable\UI\DT_PaldexDistributionData.json")

$palNameById = Get-RowMap $palNameRows
$palIconById = Get-RowMap $palIconRows
$paldexDistributionById = Get-RowMap $paldexDistributionRows

$normalPalSpawnCounts = @{}
foreach ($marker in @($categories.NormalPal)) {
    foreach ($palIdRaw in @($marker.Pals)) {
        $palId = Normalize-PalId $palIdRaw
        if (-not $palId) { continue }
        if (-not $normalPalSpawnCounts.ContainsKey($palId)) { $normalPalSpawnCounts[$palId] = 0 }
        $normalPalSpawnCounts[$palId]++
    }
}

$palCatalogByDexKey = @{}
foreach ($prop in @($monsterRows)) {
    $row = $prop.Value
    if (-not $row -or $row.IsPal -ne $true) { continue }
    $dexNo = [int]($row.ZukanIndex)
    if ($dexNo -le 0) { continue }

    $rawId = [string]$prop.Name
    if ($rawId -match "^(BOSS_|GYM_|RAID_|Quest_)") { continue }
    if ($rawId -match "(_Oilrig|_Raid)$") { continue }
    $palId = Normalize-PalId $rawId
    if (-not $palId -or $palId -match "^(SUMMON_)") { continue }

    $suffix = [string]($row.ZukanIndexSuffix)
    if ($suffix -eq "None") { $suffix = "" }
    $dexKey = "{0:D3}{1}" -f $dexNo, $suffix
    $score = 0
    if ($rawId -eq $palId) { $score += 10 }
    if ($palIconById.ContainsKey($palId)) { $score += 4 }
    if ($paldexDistributionById.ContainsKey($palId)) { $score += 2 }
    if ($normalPalSpawnCounts.ContainsKey($palId)) { $score += 1 }

    if ($palCatalogByDexKey.ContainsKey($dexKey) -and $palCatalogByDexKey[$dexKey].Score -ge $score) {
        continue
    }

    $nameTextId = Clean-Value $row.OverrideNameTextID
    if (-not $nameTextId) { $nameTextId = "PAL_NAME_$palId" }
    $localizedName = Get-TextDataString $palNameById $nameTextId
    if (-not $localizedName -or $localizedName -eq "-") { $localizedName = "" }

    $spawnCount = if ($normalPalSpawnCounts.ContainsKey($palId)) { [int]$normalPalSpawnCounts[$palId] } else { 0 }
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

    $palCatalogByDexKey[$dexKey] = [pscustomobject]@{
        Id = $palId
        DexNo = $dexNo
        DexSuffix = $suffix
        DexKey = $dexKey
        NameTextId = $nameTextId
        LocalizedName = $localizedName
        IconPath = Get-PalIconPath $palId $palIconById
        SpawnPointCount = $spawnCount
        PaldexLocationCount = $paldexLocationCount
        HasPaldexDistribution = $paldexDistributionById.ContainsKey($palId)
        Score = $score
    }
}
$palCatalog = @($palCatalogByDexKey.Values | Sort-Object DexNo, DexSuffix, Id)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("-- generated_static_markers.lua")
$lines.Add("-- Generated by build_generated_markers.ps1. Do not edit by hand.")
$lines.Add("-- Source root: $FModelRoot")
$lines.Add("return {")

foreach ($category in $categories.Keys) {
    $markers = @($categories[$category])
    $lines.Add("    $category = {")

    foreach ($m in $markers) {
        $palText = ($m.Pals | ForEach-Object { Lua-String $_ }) -join ", "
        $npcText = ($m.NPCs | ForEach-Object { Lua-String $_ }) -join ", "
        $lines.Add("        {")
        $lines.Add("            Id = $(Lua-String $m.Id),")
        $lines.Add("            Name = $(Lua-String $m.Name),")
        $lines.Add("            X = $(Lua-Number $m.X), Y = $(Lua-Number $m.Y), Z = $(Lua-Number $m.Z),")
        $lines.Add("            IconIndex = $($m.IconIndex),")
        $lines.Add("            SpawnerName = $(Lua-String $m.SpawnerName),")
        $lines.Add("            SpawnerType = $(Lua-String $m.SpawnerType),")
        $lines.Add("            WildSpawnerType = $(Lua-String $m.WildSpawnerType),")
        $lines.Add("            PlacementType = $(Lua-String $m.PlacementType),")
        $lines.Add("            WorldName = $(Lua-String $m.WorldName),")
        $lines.Add("            Pals = { $palText },")
        $lines.Add("            NPCs = { $npcText },")
        $lines.Add("            Levels = $(Lua-String $m.Levels),")
        $lines.Add("            Source = $(Lua-String $m.Source),")
        $lines.Add("        },")
    }

    $lines.Add("    },")
}

$lines.Add("    PalCatalog = {")
foreach ($pal in $palCatalog) {
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

$lines.Add("    Metadata = {")
$lines.Add("        PlacementRows = $(@($placementRows).Count),")
$lines.Add("        WildRows = $(@($wildRows).Count),")
$lines.Add("        JoinedRows = $($summaryRows.Count),")
$lines.Add("        UnjoinedRows = $unjoined,")
$lines.Add("        SkippedUnknownRows = $skippedUnknown,")
$lines.Add("        DedupedRows = $dedupedRows,")
$lines.Add("        PalCatalogRows = $(@($palCatalog).Count),")
$lines.Add("    },")
$lines.Add("}")

$outPath = Resolve-Path -LiteralPath (Split-Path -Parent $OutputLua)
if (-not $outPath) { throw "Output directory does not exist: $OutputLua" }
[IO.File]::WriteAllLines((Join-Path $outPath (Split-Path -Leaf $OutputLua)), $lines, [Text.UTF8Encoding]::new($false))

$summaryRows |
    Select-Object Category,Name,SpawnerName,SpawnerType,WildSpawnerType,WorldName,PlacementType,X,Y,Z,IconIndex,Levels |
    Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Generated $OutputLua"
Write-Host "Generated $OutputCsv"
Write-Host "Counts:"
foreach ($category in $categories.Keys) {
    Write-Host ("  {0}: {1}" -f $category, @($categories[$category]).Count)
}
Write-Host "  Unjoined placements: $unjoined"
Write-Host "  Skipped unknown placements: $skippedUnknown"
