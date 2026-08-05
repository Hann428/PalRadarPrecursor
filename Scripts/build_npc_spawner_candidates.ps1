param(
    [string]$FModelRoot = "D:\PalOutput\Exports\Pal\Content\Pal",
    [string]$InputCsv = ".\npc_spawner_partition_candidates.csv",
    [string]$OutputCsv = ".\npc_spawner_candidates_summary.csv"
)

$ErrorActionPreference = "Stop"

function Get-RelativeLocationText {
    param([object]$Location)

    if (-not $Location) {
        return ""
    }

    return "{0},{1},{2}" -f $Location.X, $Location.Y, $Location.Z
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputPath = if ([IO.Path]::IsPathRooted($InputCsv)) { $InputCsv } else { Join-Path $scriptDir $InputCsv }
$outputPath = if ([IO.Path]::IsPathRooted($OutputCsv)) { $OutputCsv } else { Join-Path $scriptDir $OutputCsv }

if (-not (Test-Path -LiteralPath $inputPath)) {
    throw "Missing input CSV: $inputPath"
}

$generatedRoot = Join-Path $FModelRoot "Maps\MainWorld_5\PL_MainWorld5\_Generated_"
$rows = Import-Csv -LiteralPath $inputPath
$rowsByCell = $rows | Group-Object Cell
$out = New-Object System.Collections.Generic.List[object]

foreach ($cellGroup in $rowsByCell) {
    $cellName = $cellGroup.Name
    $cellPath = Join-Path $generatedRoot ($cellName + ".json")
    if (-not (Test-Path -LiteralPath $cellPath)) {
        continue
    }

    Write-Host "Reading NPC spawner cell: $cellName"
    $objects = Get-Content -LiteralPath $cellPath -Raw | ConvertFrom-Json

    $locationByOwner = @{}
    foreach ($obj in $objects) {
        $props = $obj.Properties
        if (-not $props -or -not $props.RelativeLocation) {
            continue
        }

        $outerName = ""
        if ($obj.Outer -and $obj.Outer.ObjectName) {
            $outerName = [string]$obj.Outer.ObjectName
        }
        if (-not $outerName) {
            continue
        }

        $locationByOwner[$outerName] = $props.RelativeLocation
    }

    foreach ($candidate in $cellGroup.Group) {
        $actor = @($objects | Where-Object { [string]$_.Name -eq [string]$candidate.Key } | Select-Object -First 1)[0]
        if (-not $actor) {
            continue
        }

        $props = $actor.Properties
        $actorObjectName = "{0}'PL_MainWorld5:PersistentLevel.{1}'" -f ([string]$actor.Type), ([string]$actor.Name)
        $loc = $null
        if ($props -and $props.RelativeLocation) {
            $loc = $props.RelativeLocation
        } elseif ($locationByOwner.ContainsKey($actorObjectName)) {
            $loc = $locationByOwner[$actorObjectName]
        }

        $out.Add([pscustomobject]@{
            Cell = $cellName
            Type = [string]$actor.Type
            Name = [string]$actor.Name
            ActorLabel = [string]$actor.ActorLabel
            UniqueName = [string]$props.UniqueName.Key
            OtomoName = [string]$props.OtomoName.Key
            Level = [string]$props.Level
            RespawnTime = [string]$props.RespawnTime
            RelativeLocation = Get-RelativeLocationText $loc
            X = if ($loc) { $loc.X } else { "" }
            Y = if ($loc) { $loc.Y } else { "" }
            Z = if ($loc) { $loc.Z } else { "" }
        })
    }
}

$out |
    Sort-Object UniqueName, Name |
    Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding UTF8

Write-Host "Wrote $($out.Count) NPC spawner candidates to $outputPath"
