-- static_markers.lua
--
-- Static map marker data for PalRadarPrecursor.
-- Prefer real Palworld world coordinates if available:
--     X/Y/Z = Unreal world coordinates.
--
-- Approximate map coordinates are also supported:
--     MapX/MapY = coordinates shown on the in-game map or an interactive map.
-- The conversion is controlled by Config.StaticMarkers.MapCoordinateToWorld.
--
-- Entry schema:
-- {
--     Id = "unique_stable_id",
--     Name = "Display/debug name",
--     X = 0.0,    -- optional if MapX/MapY are provided
--     Y = 0.0,    -- optional if MapX/MapY are provided
--     Z = 0.0,    -- optional
--     MapX = 0.0, -- optional approximate map coordinate
--     MapY = 0.0, -- optional approximate map coordinate
--     IconIndex = 0 -- optional; falls back to config category default
-- }

local Config = require("config")

local Markers = {
    Boss = {
        {
            Id = "validation_boss_grass_mammoth",
            Name = "BOSS_GrassMammoth",
            X = -343155.0,
            Y = 244585.0,
            Z = -95.0,
            IconIndex = 0,
            Source = "FModel:DT_PalSpawnerPlacement"
        },
        {
            Id = "validation_boss_king_alpaca",
            Name = "BOSS_KingAlpaca+Alpaca",
            X = -335225.0,
            Y = 180735.0,
            Z = 475.0,
            IconIndex = 0,
            Source = "FModel:DT_PalSpawnerPlacement"
        },
        {
            Id = "validation_boss_captain_penguin",
            Name = "BOSS_CaptainPenguin+Penguin",
            X = -285331.3,
            Y = 210162.69,
            Z = 766.80945,
            IconIndex = 0,
            Source = "FModel:DT_PalSpawnerPlacement"
        },
        {
            Id = "validation_boss_fairy_dragon",
            Name = "BOSS_FairyDragon",
            X = -254060.0,
            Y = 178050.0,
            Z = 4000.0,
            IconIndex = 0,
            Source = "FModel:DT_PalSpawnerPlacement"
        },
        {
            Id = "validation_boss_weasel_dragon",
            Name = "BOSS_WeaselDragon",
            X = -315583.53,
            Y = 237116.97,
            Z = 2448.4133,
            IconIndex = 0,
            Source = "FModel:DT_PalSpawnerPlacement"
        },
    },

    Dungeon = {
    },

    Collectible = {
    },

    BossTower = {
    },

    DungeonBoss = {
    },

    NPC = {
    },

    NPCMerchant = {
    },

    NPCOther = {
    },

    NPCDialogue = {
        {
            Id = "npc_expedition_survivor_001",
            Name = "Expedition Survivor",
            MapX = 241.0,
            MapY = -509.0,
            X = -357594.708267,
            Y = 268765.984383,
            Z = 0.0,
            IconIndex = 11
        },
    },

    NPCSpecial = {
    },

    FastTravel = {
    },

    Chest = {
    },

    SkillFruit = {
    },

    Relic = {
    },

    RelicCommon = {
    },

    PalRelicStatue = {
    },

    Note = {
    },

    MapUnlock = {
    },

    PickupItem = {
    },

    OilField = {
    },

    ResourceCoal = {
    },

    ResourceSulfur = {
    },

    ResourceQuartz = {
    },

    ResourceSkyIslandOre = {
    },

    ResourceWorldTreeOre = {
    },

    NormalPal = {
    },

    Custom = {
    }
}

local function EnsureCategory(categoryName)
    if not Markers[categoryName] then
        Markers[categoryName] = {}
    end
    return Markers[categoryName]
end

local function CategorizeGeneratedMarker(categoryName, marker)
    if type(marker) ~= "table" then
        return categoryName
    end

    local placementType = tostring(marker.PlacementType or "")
    if categoryName == "Relic" then
        if placementType == "BP_LevelObject_Relic_C" then
            return "RelicCommon"
        end
        if placementType:match("^BP_LevelObject_Relic_") then
            marker.ParentCategory = "Relic"
            marker.RelicSubtype = placementType:gsub("^BP_LevelObject_Relic_", ""):gsub("_C$", "")
            return "PalRelicStatue"
        end
    end

    if categoryName == "ResourceNode" then
        marker.ParentCategory = "ResourceNode"
        if placementType == "BP_PalMapObjectSpawner_RockCoal_C" then
            return "ResourceCoal"
        end
        if placementType == "BP_PalMapObjectSpawner_Sulfur_C" then
            return "ResourceSulfur"
        end
        if placementType == "BP_PalMapObjectSpawner_RockQuartz_C" then
            return "ResourceQuartz"
        end
        if placementType == "BP_PalMapObjectSpawner_SkyIslandOre_C" then
            return "ResourceSkyIslandOre"
        end
        if placementType == "BP_PalMapObjectSpawner_WorldTreeOre_C" then
            return "ResourceWorldTreeOre"
        end
    end

    if categoryName == "NPC" or categoryName == "NPCDialogue" or categoryName == "NPCSpecial" then
        return "NPCOther"
    end

    return categoryName
end

local function AppendGeneratedMarkers(generated)
    if type(generated) ~= "table" then return end

    for categoryName, entries in pairs(generated) do
        if categoryName == "PalCatalog" and type(entries) == "table" then
            Markers.PalCatalog = entries
        elseif categoryName == "PalDistributions" and type(entries) == "table" then
            Markers.PalDistributions = entries
        elseif categoryName ~= "Metadata" and type(entries) == "table" then
            for _, marker in ipairs(entries) do
                local targetCategory = CategorizeGeneratedMarker(categoryName, marker)
                local target = EnsureCategory(targetCategory)
                target[#target + 1] = marker
            end
        end
    end

    Markers.Metadata = generated.Metadata
end

local shouldLoadGenerated = false
if Config.StaticMarkers and Config.StaticMarkers.LoadGenerated then
    shouldLoadGenerated = true
end
if Config.OverlayMarkers and Config.OverlayMarkers.LoadGenerated then
    shouldLoadGenerated = true
end

if shouldLoadGenerated then
    local ok, generated = pcall(require, "generated_static_markers")
    if ok then
        AppendGeneratedMarkers(generated)
    else
        Markers.GeneratedLoadError = tostring(generated)
    end

    local uniqueNpcOk, uniqueNpcMarkers = pcall(require, "generated_unique_npc_markers")
    if uniqueNpcOk and type(uniqueNpcMarkers) == "table" then
        AppendGeneratedMarkers(uniqueNpcMarkers)
    else
        Markers.GeneratedUniqueNpcMarkersLoadError = tostring(uniqueNpcMarkers)
    end

    local catalogOk, catalog = pcall(require, "generated_pal_catalog")
    if catalogOk and type(catalog) == "table" then
        Markers.PalCatalog = catalog.PalCatalog or catalog
        if type(Markers.Metadata) ~= "table" then Markers.Metadata = {} end
        Markers.Metadata.PalCatalogRows = #(Markers.PalCatalog or {})
    else
        Markers.GeneratedPalCatalogLoadError = tostring(catalog)
    end

    local distributionOk, distribution = pcall(require, "generated_pal_distribution")
    if distributionOk and type(distribution) == "table" then
        Markers.PalDistributions = distribution.PalDistributions or distribution
        if type(Markers.Metadata) ~= "table" then Markers.Metadata = {} end
        if type(distribution.Metadata) == "table" then
            Markers.Metadata.PalDistributionRows = distribution.Metadata.PalDistributionRows
            Markers.Metadata.PalDistributionPoints = distribution.Metadata.PalDistributionPoints
        end
    else
        Markers.GeneratedPalDistributionLoadError = tostring(distribution)
    end

    -- Disabled after an M-open crash on 2026-08-04. The four entries extracted
    -- from DT_PalSpawnerPlacement are human-boss spawners, not the ordinary
    -- fixed merchants we need. Keep the generated file for inspection only.
    Markers.GeneratedMerchantMarkersDisabled = true
end

return Markers
