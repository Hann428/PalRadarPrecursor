-- config.lua
local Config = {
    RefreshRateMs = 250,
    ScanInterval = 2.0,
    MapProbeInterval = 2.0,
    MapHookRetryMs = 5000,
    EnableMapWidgetProbe = false,
    EnableNativeMapInjection = false,
    EnableNativeMapHookTrace = false,
    EnableCustomMarkerHookTrace = false,
    CustomMarkerHookTraceMaxEvents = 600,
    EnableCustomMarkerInjection = false,
    CustomMarkerInjectionCount = 5,
    NativeInjectionTestOnly = true,
    NativeInjectionMaxIcons = 1,
    NativeInjectionOffset = {
        X = 25000.0,
        Y = 25000.0,
        Z = 0.0
    },
    TelemetryInterval = 5.0,
    DebugWorldLabels = false,
    DebugCustomDepth = false,
    DebugLabelRangeMeters = 80,

    StaticMarkers = {
        Enabled = false,
        -- AddLocalCustomMarker writes into the game's custom map marker data.
        -- Keep this false unless you are on a backed-up/test save.
        AcknowledgeWritesToSave = false,
        DryRun = true,
        LoadGenerated = true,
        LogFileName = "PalRadar_StaticMarkers_Log.txt",
        StateFileName = "PalRadar_StaticMarkers_State_BeijingTest.txt",
        SkipPreviouslyGenerated = true,
        MaxPerCategory = 500,
        MaxTotal = 2000,
        MaxPerCategoryByCategory = {
            Boss = 100,
            BossTower = 50,
            Dungeon = 500,
            DungeonBoss = 300,
            NPC = 200,
            FastTravel = 200,
            MapUnlock = 50,
            Chest = 200,
            SkillFruit = 200,
            Relic = 500,
            RelicCommon = 200,
            PalRelicStatue = 300,
            PickupItem = 100,
            OilField = 300,
            TreasureMapPointStatic = 100,
            Note = 200,
            PalEgg = 300,
            FishingSpot = 200,
            FishingJunkSpot = 200,
            ResourceNode = 300,
            Collectible = 200,
            NormalPal = 0,
            Custom = 0
        },
        DefaultZ = 0.0,

        -- For coordinates copied from the in-game map display or interactive maps.
        -- If a static marker entry uses MapX/MapY instead of X/Y, it is converted here.
        MapCoordinateToWorld = {
            Scale = 100.0,
            OffsetX = 0.0,
            OffsetY = 0.0,
            SwapXY = false,
            InvertX = false,
            InvertY = false
        },

        -- AddLocalCustomMarker uses zero-based icon indexes.
        -- Confirmed examples: 0=star; other values map to the game's built-in marker icons.
        DefaultIconIndexByCategory = {
            Boss = 0,
            BossTower = 0,
            Dungeon = 2,
            DungeonBoss = 0,
            Collectible = 4,
            NPC = 11,
            FastTravel = 1,
            MapUnlock = 1,
            Chest = 12,
            SkillFruit = 4,
            Relic = 4,
            RelicCommon = 4,
            PalRelicStatue = 4,
            PickupItem = 4,
            OilField = 12,
            TreasureMapPointStatic = 4,
            Note = 4,
            PalEgg = 4,
            FishingSpot = 4,
            FishingJunkSpot = 4,
            ResourceNode = 4,
            NormalPal = 4,
            Custom = 0
        },

        Filters = {
            Boss = false,
            BossTower = true,
            Dungeon = false,
            DungeonBoss = false,
            Collectible = false,
            NPC = false,
            FastTravel = true,
            MapUnlock = true,
            Chest = false,
            SkillFruit = true,
            Relic = false,
            RelicCommon = false,
            PalRelicStatue = true,
            PickupItem = false,
            OilField = true,
            TreasureMapPointStatic = true,
            Note = true,
            PalEgg = true,
            FishingSpot = true,
            FishingJunkSpot = true,
            ResourceNode = true,
            NormalPal = false,
            Custom = false
        }
    },

    OverlayMarkers = {
        Enabled = true,
        LoadGenerated = true,
        LogFileName = "PalRadar_OverlayMarkers_Log.txt",
        MaxPerCategory = 999999,
        MaxTotal = 0,
        IgnoreMask = true,
        ToPriority = true,
        SortByDistanceToPlayer = true,
        GenerateHiddenCategories = true,
        LazyCreate = {
            Enabled = true,
            BatchSize = 32,
            BatchIntervalMs = 30,
            LogEachMarker = false,
            DestroyIconsOnHide = false,
            MaxLiveIcons = 0
        },
        Cleanup = {
            RegisterMapDestructHook = true,
            RegisterMapToggleKey = true,
            RemoveWidgetsOnMapClose = true
        },
        CategoryOrder = {
            "FastTravel",
            "MapUnlock",
            "BossTower",
            "Boss",
            "Dungeon",
            "DungeonBoss",
            "NPC",
            "SkillFruit",
            "Relic",
            "RelicCommon",
            "PalRelicStatue",
            "OilField",
            "TreasureMapPointStatic",
            "Note",
            "PalEgg",
            "FishingSpot",
            "FishingJunkSpot",
            "ResourceNode",
            "Chest",
            "PickupItem",
            "NormalPal",
            "Collectible",
            "Custom"
        },
        MaxPerCategoryByCategory = {
            FastTravel = 999999,
            MapUnlock = 999999,
            BossTower = 999999,
            Boss = 999999,
            Dungeon = 999999,
            DungeonBoss = 999999,
            NPC = 999999,
            SkillFruit = 999999,
            Relic = 999999,
            RelicCommon = 999999,
            PalRelicStatue = 999999,
            OilField = 999999,
            TreasureMapPointStatic = 999999,
            Note = 999999,
            PalEgg = 999999,
            FishingSpot = 999999,
            FishingJunkSpot = 999999,
            ResourceNode = 999999,
            Chest = 999999,
            PickupItem = 999999,
            NormalPal = 999999,
            Collectible = 999999,
            Custom = 0
        },

        TempMarkerProbe = {
            Enabled = false,
            EntryPoint = "AddCustomIcon",
            Id = "temp_marker_probe_skillfruit",
            OffsetX = 5000.0,
            OffsetY = 5000.0,
            OffsetZ = 0.0,
            IconType = 0
        },

        LocationManagerProbe = {
            -- This route goes through PalLocationManager:AddLocalCustomMarker.
            -- It can produce the visible map marker path, but it may touch the
            -- game's custom marker save data. Keep disabled until a single-marker
            -- cleanup test is explicitly approved.
            Enabled = false,
            AcknowledgeWritesToSave = false,
            AttemptAutoRemove = false,
            Id = "location_manager_probe_skillfruit",
            OffsetX = 5000.0,
            OffsetY = 5000.0,
            OffsetZ = 0.0,
            IconIndex = 0
        },

        NativeIconProbe = {
            Enabled = false,
            Id = "native_worldmap_probe_skillfruit",
            OffsetX = 5000.0,
            OffsetY = 5000.0,
            OffsetZ = 0.0,
            SetupIconType = 19
        },

        NativeStaticMarkers = {
            Enabled = true,
            UseMapBodyRouter = false,
            CallUpdateMapIcon = true,
            CallUpdateMapIconsAtEnd = true,
            PreStepLog = false,
            ChooseNearestToPlayer = true,
            ForcePlayerRelativeLocation = false,
            PlayerRelativeLocation = {
                OffsetX = 5000.0,
                OffsetY = 5000.0,
                OffsetZ = 0.0
            },
            IconScaleByCategory = {
                Boss = 0.5,
                BossTower = 0.6,
                Dungeon = 0.55,
                FastTravel = 0.55,
                MapUnlock = 0.55,
                SkillFruit = 0.5,
                Relic = 0.5,
                RelicCommon = 0.5,
                PalRelicStatue = 0.5,
                OilField = 0.55,
                TreasureMapPointStatic = 0.45,
                Note = 0.42,
                PalEgg = 0.45,
                FishingSpot = 0.45,
                FishingJunkSpot = 0.45,
                ResourceNode = 0.45,
                Chest = 0.45,
                PickupItem = 0.45,
                NPC = 0.45,
                NormalPal = 0.4,
                Collectible = 0.45,
                Custom = 0.45
            },
            IconRenderOffsetByCategory = {
                SkillFruit = {
                    X = -12.0,
                    Y = -12.0
                }
            },
            SetupIconTypeByCategory = {
                SkillFruit = 19
            }
        },

        RuntimeFilters = {
            Enabled = true,
            Hotkeys = {
            },
            ShowAllKey = nil
        },

        AutoShowOnOpen = {
            Enabled = true,
            Categories = {
                "FastTravel",
                "MapUnlock",
                "BossTower",
                "Boss",
                "Dungeon",
                "DungeonBoss",
                "NPC",
                "SkillFruit",
                "Relic",
                "RelicCommon",
                "PalRelicStatue",
                "OilField",
                "TreasureMapPointStatic",
                "Note",
                "PalEgg",
                "FishingSpot",
                "FishingJunkSpot",
                "ResourceNode",
                "Chest",
                "PickupItem",
                "NormalPal",
                "Collectible"
            }
        },

        FilterPanel = {
            Enabled = true,
            MouseClickEnabled = true,
            LazyBuildRows = true,
            StartExpanded = false,
            AutoSize = true,
            Position = { X = 1290.0, Y = 142.0 },
            Size = { X = 410.0, Y = 36.0 },
            PanelWidth = 410.0,
            ColumnCount = 2,
            ColumnWidth = 200.0,
            RowHeight = 24.0,
            IconSize = 15.0,
            FontSize = 12,
            ZOrder = 10050,
            Categories = {
                { NativeFilter = "PointBaseCamp", LocationType = "EPalLocationType::PointBaseCamp", TextureCategory = "BaseCamp", Label = "据点", Column = 1 },
                { NativeFilter = "FieldBoss", LocationType = "EPalLocationType::FieldBoss", TextureCategory = "FieldBoss", Label = "区域头目", Column = 1 },
                { NativeFilter = "HumanBoss", LocationType = "EPalLocationType::HumanBoss", TextureCategory = "HumanBoss", Label = "悬赏头目", Column = 1 },
                { NativeFilter = "Oilrig", LocationType = "EPalLocationType::Oilrig", TextureCategory = "Oilrig", Label = "油田要塞", Column = 1 },
                { NativeFilter = "TreasureMapPoint", LocationType = "EPalLocationType::TreasureMapPoint", TextureCategory = "TreasureMapPoint", Label = "藏宝图", Column = 1 },
                { NativeFilter = "SupplyMarker", LocationType = "EPalLocationType::SupplyMarker", TextureCategory = "SupplyMarker", Label = "补给", Column = 1 },
                { Category = "Boss", Label = "首领", Column = 1 },
                { Category = "BossTower", Label = "高塔", Column = 1 },
                { Category = "Dungeon", Label = "地下城", Column = 1 },
                { Category = "DungeonBoss", Label = "地下城首领", Column = 1 },
                { Category = "NPC", Label = "NPC", Column = 1 },
                { Category = "FastTravel", Label = "巨鹫之像", Column = 1 },
                { Category = "MapUnlock", Label = "地图解锁", Column = 1 },
                { Category = "Chest", Label = "宝箱", Column = 1 },
                { Category = "OilField", Label = "油田", Column = 1 },
                { Category = "SkillFruit", Label = "技能果树", Column = 2 },
                { Category = "TreasureMapPointStatic", Label = "藏宝图点", Column = 2 },
                { Category = "Note", Label = "笔记", Column = 2 },
                { Category = "PalEgg", Label = "帕鲁蛋", Column = 2 },
                { Category = "FishingSpot", Label = "钓鱼点", Column = 2 },
                { Category = "FishingJunkSpot", Label = "打捞点", Column = 2 },
                { Category = "ResourceNode", Label = "资源点", Column = 2 },
                { Category = "Relic", Label = "遗物", Column = 2 },
                { Category = "RelicCommon", Label = "普通遗物", Column = 2 },
                { Category = "PalRelicStatue", Label = "帕鲁雕像", Column = 2 },
                { Category = "PickupItem", Label = "拾取物", Column = 2 },
                { Category = "NormalPal", Label = "普通帕鲁", Column = 2 },
                { Category = "Collectible", Label = "收集物", Column = 2 }
            }
        },

        DebugNearPlayer = {
            Enabled = false,
            CanvasProbe = false,
            ViewportProbe = false,
            Markers = {
                {
                    Id = "overlay_probe_treasure_east",
                    OffsetX = 30000.0,
                    OffsetY = 0.0,
                    OffsetZ = 0.0,
                    WidgetPath = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C"
                },
                {
                    Id = "overlay_probe_treasure_north",
                    OffsetX = 0.0,
                    OffsetY = 30000.0,
                    OffsetZ = 0.0,
                    WidgetPath = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C"
                },
                {
                    Id = "overlay_probe_treasure_diag",
                    OffsetX = 30000.0,
                    OffsetY = 30000.0,
                    OffsetZ = 0.0,
                    WidgetPath = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C"
                }
            }
        },

        Filters = {
            Boss = false,
            BossTower = false,
            Dungeon = false,
            DungeonBoss = false,
            Collectible = false,
            NPC = false,
            FastTravel = false,
            MapUnlock = false,
            Chest = false,
            SkillFruit = false,
            Relic = false,
            RelicCommon = false,
            PalRelicStatue = false,
            PickupItem = false,
            OilField = false,
            TreasureMapPointStatic = false,
            Note = false,
            PalEgg = false,
            FishingSpot = false,
            FishingJunkSpot = false,
            ResourceNode = false,
            NormalPal = false,
            Custom = false
        },

        IconWidgetByCategory = {
            Boss = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconBoss.WBP_Map_IconBoss_C",
            BossTower = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTower.WBP_Map_IconTower_C",
            Dungeon = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconDungeon.WBP_Map_IconDungeon_C",
            DungeonBoss = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconDungeon.WBP_Map_IconDungeon_C",
            NPC = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            FastTravel = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconFTTower.WBP_Map_IconFTTower_C",
            MapUnlock = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconFTTower.WBP_Map_IconFTTower_C",
            Chest = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            SkillFruit = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            Relic = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            RelicCommon = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            PalRelicStatue = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            PickupItem = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            OilField = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconBoss.WBP_Map_IconBoss_C",
            TreasureMapPointStatic = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            Note = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            PalEgg = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            FishingSpot = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            FishingJunkSpot = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            ResourceNode = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            NormalPal = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            Collectible = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C",
            Custom = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconTreasureMapPoint.WBP_Map_IconTreasureMapPoint_C"
        },

        TextureReplacement = {
            Enabled = true,
            -- Keep this false until these PNGs are imported and cooked into the
            -- PalRadarPrecursor content package. While false, Lua can still test
            -- the brush replacement path with the game's original textures.
            PreferPackagedTextures = false,
            FallbackToGameTexturesForTesting = true,
            BossPalIcons = {
                Enabled = true,
                PackagedBasePath = "/Game/PalRadarPrecursor/UI/Icons/PalIcon/Normal",
                GameBasePath = "/Game/Pal/Texture/PalIcon/Normal"
            },
            ImageFieldCandidates = {
                "Icon",
                "Icon_Base",
                "Icon_BaseShadow",
                "Icon_EnemyCamp",
                "Icon_HumanBoss",
                "Icon_Oilrig",
                "Image",
                "Image_0",
                "Image_Icon",
                "Image_ClearMark",
                "Image_InCave"
            },

            TextureByCategory = {
                Debug = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/BuildObject/T_icon_buildObject_Farm_SkillFruits.T_icon_buildObject_Farm_SkillFruits",
                Boss = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_boss.T_icon_compass_boss",
                BossTower = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_tower.T_icon_compass_tower",
                BaseCamp = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_camp.T_icon_compass_camp",
                FieldBoss = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Boss_Unknown.T_icon_compass_Boss_Unknown",
                HumanBoss = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Bounty_Unknown.T_icon_compass_Bounty_Unknown",
                Oilrig = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Oilrig.T_icon_compass_Oilrig",
                CustomMarker = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Search_Treasure.T_icon_compass_Search_Treasure",
                DeathPoint = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_prt_map_death_1.T_prt_map_death_1",
                QuestStatic = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_Compass_Quest_0.T_icon_Compass_Quest_0",
                TreasureMapPoint = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_TreasureMap_01.T_icon_compass_TreasureMap_01",
                SupplyMarker = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_16.T_icon_compass_16",
                Dungeon = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_dungeon.T_icon_compass_dungeon",
                DungeonBoss = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_KeyBoss.T_icon_compass_KeyBoss",
                FastTravel = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_FTtower.T_icon_compass_FTtower",
                MapUnlock = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_FTUnlockMap.T_icon_compass_FTUnlockMap",
                Chest = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/BuildObject/T_icon_buildObject_ItemChest.T_icon_buildObject_ItemChest",
                SkillFruit = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/BuildObject/T_icon_buildObject_Farm_SkillFruits.T_icon_buildObject_Farm_SkillFruits",
                TreasureMapPointStatic = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_TreasureMap_01.T_icon_compass_TreasureMap_01",
                Note = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_Compass_Quest_0.T_icon_Compass_Quest_0",
                PalEgg = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/BuildObject/T_icon_buildObject_HatchingPalEgg.T_icon_buildObject_HatchingPalEgg",
                FishingSpot = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Search_Treasure.T_icon_compass_Search_Treasure",
                FishingJunkSpot = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Search_Junk.T_icon_compass_Search_Junk",
                ResourceNode = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/BuildObject/T_icon_buildObject_SkyIslandOrePit.T_icon_buildObject_SkyIslandOrePit",
                Relic = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/BuildObject/T_icon_buildObject_BuildableGoddessStatue.T_icon_buildObject_BuildableGoddessStatue",
                RelicCommon = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/BuildObject/T_icon_buildObject_BuildableGoddessStatue.T_icon_buildObject_BuildableGoddessStatue",
                PalRelicStatue = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/BuildObject/T_icon_buildObject_BuildableGoddessStatue.T_icon_buildObject_BuildableGoddessStatue",
                PickupItem = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Search_Junk.T_icon_compass_Search_Junk",
                OilField = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Oilrig.T_icon_compass_Oilrig",
                NPC = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_character_common_human_00.T_character_common_human_00",
                NormalPal = "/Game/PalRadarPrecursor/UI/Icons/DynamicRadar/Markers/T_icon_pal_rare.T_icon_pal_rare",
                Collectible = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Search_Treasure.T_icon_compass_Search_Treasure",
                Custom = "/Game/PalRadarPrecursor/UI/Icons/StaticMap/Compass/T_icon_compass_Search_Treasure.T_icon_compass_Search_Treasure"
            },

            TextureByRelicSubtype = {
                BP_LevelObject_Relic_NegativeKoala_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_NegativeKoala_icon_normal.T_NegativeKoala_icon_normal",
                BP_LevelObject_Relic_Monkey_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_Monkey_icon_normal.T_Monkey_icon_normal",
                BP_LevelObject_Relic_Penguin_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_Penguin_icon_normal.T_Penguin_icon_normal",
                BP_LevelObject_Relic_SheepBall_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_SheepBall_icon_normal.T_SheepBall_icon_normal",
                BP_LevelObject_Relic_PinkCat_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_PinkCat_icon_normal.T_PinkCat_icon_normal",
                BP_LevelObject_Relic_FlameBambi_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_FlameBambi_icon_normal.T_FlameBambi_icon_normal",
                BP_LevelObject_Relic_IceCrocodile_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_IceCrocodile_icon_normal.T_IceCrocodile_icon_normal",
                BP_LevelObject_Relic_LeafMomonga_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_LeafMomonga_icon_normal.T_LeafMomonga_icon_normal",
                BP_LevelObject_Relic_LazyDragon_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_LazyDragon_icon_normal.T_LazyDragon_icon_normal",
                BP_LevelObject_Relic_GuardianDog_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_GuardianDog_icon_normal.T_GuardianDog_icon_normal",
                BP_LevelObject_Relic_Mutant_C = "/Game/PalRadarPrecursor/UI/Icons/PalRelicStatues/T_Mutant_icon_normal.T_Mutant_icon_normal"
            },

            GameTextureFallbackByCategory = {
                Debug = "/Game/Pal/Texture/BuildObject/PNG/T_icon_buildObject_Farm_SkillFruits.T_icon_buildObject_Farm_SkillFruits",
                Boss = "/Game/Pal/Texture/UI/InGame/T_icon_compass_boss.T_icon_compass_boss",
                BossTower = "/Game/Pal/Texture/UI/InGame/T_icon_compass_tower.T_icon_compass_tower",
                BaseCamp = "/Game/Pal/Texture/UI/InGame/T_icon_compass_camp.T_icon_compass_camp",
                FieldBoss = "/Game/Pal/Texture/UI/Map/T_icon_compass_Boss_Unknown.T_icon_compass_Boss_Unknown",
                HumanBoss = "/Game/Pal/Texture/UI/InGame/T_icon_compass_Bounty_Unknown.T_icon_compass_Bounty_Unknown",
                Oilrig = "/Game/Pal/Texture/UI/InGame/T_icon_compass_Oilrig.T_icon_compass_Oilrig",
                CustomMarker = "/Game/Pal/Texture/UI/InGame/T_icon_compass_Search_Treasure.T_icon_compass_Search_Treasure",
                DeathPoint = "/Game/Pal/Texture/UI/InGame/T_prt_map_death_1.T_prt_map_death_1",
                QuestStatic = "/Game/Pal/Texture/UI/InGame/T_icon_Compass_Quest_0.T_icon_Compass_Quest_0",
                TreasureMapPoint = "/Game/Pal/Texture/UI/InGame/T_icon_compass_TreasureMap_01.T_icon_compass_TreasureMap_01",
                SupplyMarker = "/Game/Pal/Texture/UI/InGame/T_icon_compass_16.T_icon_compass_16",
                Dungeon = "/Game/Pal/Texture/UI/InGame/T_icon_compass_dungeon.T_icon_compass_dungeon",
                DungeonBoss = "/Game/Pal/Texture/UI/InGame/T_icon_compass_KeyBoss.T_icon_compass_KeyBoss",
                FastTravel = "/Game/Pal/Texture/UI/InGame/T_icon_compass_FTtower.T_icon_compass_FTtower",
                MapUnlock = "/Game/Pal/Texture/UI/InGame/T_icon_compass_FTUnlockMap.T_icon_compass_FTUnlockMap",
                Chest = "/Game/Pal/Texture/BuildObject/PNG/T_icon_buildObject_ItemChest.T_icon_buildObject_ItemChest",
                SkillFruit = "/Game/Pal/Texture/BuildObject/PNG/T_icon_buildObject_Farm_SkillFruits.T_icon_buildObject_Farm_SkillFruits",
                TreasureMapPointStatic = "/Game/Pal/Texture/UI/InGame/T_icon_compass_TreasureMap_01.T_icon_compass_TreasureMap_01",
                Note = "/Game/Pal/Texture/UI/InGame/T_icon_Compass_Quest_0.T_icon_Compass_Quest_0",
                PalEgg = "/Game/Pal/Texture/BuildObject/PNG/T_icon_buildObject_HatchingPalEgg.T_icon_buildObject_HatchingPalEgg",
                FishingSpot = "/Game/Pal/Texture/UI/InGame/T_icon_compass_Search_Treasure.T_icon_compass_Search_Treasure",
                FishingJunkSpot = "/Game/Pal/Texture/UI/InGame/T_icon_compass_Search_Junk.T_icon_compass_Search_Junk",
                ResourceNode = "/Game/Pal/Texture/BuildObject/PNG/T_icon_buildObject_SkyIslandOrePit.T_icon_buildObject_SkyIslandOrePit",
                Relic = "/Game/Pal/Texture/BuildObject/PNG/T_icon_buildObject_BuildableGoddessStatue.T_icon_buildObject_BuildableGoddessStatue",
                RelicCommon = "/Game/Pal/Texture/BuildObject/PNG/T_icon_buildObject_BuildableGoddessStatue.T_icon_buildObject_BuildableGoddessStatue",
                PalRelicStatue = "/Game/Pal/Texture/BuildObject/PNG/T_icon_buildObject_BuildableGoddessStatue.T_icon_buildObject_BuildableGoddessStatue",
                PickupItem = "/Game/Pal/Texture/UI/InGame/T_icon_compass_Search_Junk.T_icon_compass_Search_Junk",
                OilField = "/Game/Pal/Texture/UI/InGame/T_icon_compass_Oilrig.T_icon_compass_Oilrig",
                NPC = "/Game/Pal/Texture/UI/InGame/T_character_common_human_00.T_character_common_human_00",
                NormalPal = "/Game/Pal/Texture/UI/InGame/T_icon_pal_rare.T_icon_pal_rare",
                Collectible = "/Game/Pal/Texture/UI/InGame/T_icon_compass_Search_Treasure.T_icon_compass_Search_Treasure",
                Custom = "/Game/Pal/Texture/UI/InGame/T_icon_compass_Search_Treasure.T_icon_compass_Search_Treasure"
            },

            GameTextureFallbackByRelicSubtype = {
                BP_LevelObject_Relic_NegativeKoala_C = "/Game/Pal/Texture/PalIcon/Normal/T_NegativeKoala_icon_normal.T_NegativeKoala_icon_normal",
                BP_LevelObject_Relic_Monkey_C = "/Game/Pal/Texture/PalIcon/Normal/T_Monkey_icon_normal.T_Monkey_icon_normal",
                BP_LevelObject_Relic_Penguin_C = "/Game/Pal/Texture/PalIcon/Normal/T_Penguin_icon_normal.T_Penguin_icon_normal",
                BP_LevelObject_Relic_SheepBall_C = "/Game/Pal/Texture/PalIcon/Normal/T_SheepBall_icon_normal.T_SheepBall_icon_normal",
                BP_LevelObject_Relic_PinkCat_C = "/Game/Pal/Texture/PalIcon/Normal/T_PinkCat_icon_normal.T_PinkCat_icon_normal",
                BP_LevelObject_Relic_FlameBambi_C = "/Game/Pal/Texture/PalIcon/Normal/T_FlameBambi_icon_normal.T_FlameBambi_icon_normal",
                BP_LevelObject_Relic_IceCrocodile_C = "/Game/Pal/Texture/PalIcon/Normal/T_IceCrocodile_icon_normal.T_IceCrocodile_icon_normal",
                BP_LevelObject_Relic_LeafMomonga_C = "/Game/Pal/Texture/PalIcon/Normal/T_LeafMomonga_icon_normal.T_LeafMomonga_icon_normal",
                BP_LevelObject_Relic_LazyDragon_C = "/Game/Pal/Texture/PalIcon/Normal/T_LazyDragon_icon_normal.T_LazyDragon_icon_normal",
                BP_LevelObject_Relic_GuardianDog_C = "/Game/Pal/Texture/PalIcon/Normal/T_GuardianDog_icon_normal.T_GuardianDog_icon_normal",
                BP_LevelObject_Relic_Mutant_C = "/Game/Pal/Texture/PalIcon/Normal/T_Mutant_icon_normal.T_Mutant_icon_normal"
            }
        }
    },

    Filters = {
        Boss = true,
        Lucky = true,
        NPC = true,
        Chests = true,
        Dungeons = true,
        SkillFruit = true,
        NormalPal = false
    },

    Assets = {
        WorldMapMaskPaint = "/Game/Pal/Blueprint/UI/WorldMap/M_WorldMapMaskPaint.M_WorldMapMaskPaint",
        WorldMapMaskRenderTarget = "/Game/Pal/Blueprint/UI/WorldMap/RT_WorldMapMask.RT_WorldMapMask",
        FastTravelIconTexture = "/Game/Pal/Blueprint/UI/WorldMap/IconWidgets/T_worldmap_icon_fasttravel.T_worldmap_icon_fasttravel",
        RespawnIconWidget = "/Game/Pal/Blueprint/UI/WorldMap/IconWidgets/WBP_WorldMap_Icon_Respawn.WBP_WorldMap_Icon_Respawn_C",
        IconBaseNoDesignWidget = "/Game/Pal/Blueprint/UI/WorldMap/IconWidgets/WBP_WorldMap_IconBase_NoDesign.WBP_WorldMap_IconBase_NoDesign_C",
        IconBaseOnlyIconWidget = "/Game/Pal/Blueprint/UI/WorldMap/IconWidgets/WBP_WorldMap_IconBase_OnlyIcon.WBP_WorldMap_IconBase_OnlyIcon_C",
        SkillFruitFarmWidget = "/Game/Pal/Blueprint/UI/MapObject/WBP_SkillFruitFarm.WBP_SkillFruitFarm_C",
        ItemChestPreferenceWidget = "/Game/Pal/Blueprint/UI/MapObject/ItemChest/Preference/WBP_ItemChest_Preference.WBP_ItemChest_Preference_C",
        ItemSearchFilterWidget = "/Game/Pal/Blueprint/UI/MapObject/ItemChest/Preference/WBP_ItemSearch_Filter.WBP_ItemSearch_Filter_C",
        TestBossIconWidget = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconBoss.WBP_Map_IconBoss_C"
    },

    -- Runtime class probes. These are intentionally broad because FModel gives us
    -- asset paths, while UE4SS needs the live generated class name.
    WorldMapWidgetCandidates = {
        "WBP_Map_Body_C",
        "WBP_Map_Body",
        "WBP_Map_Base_C",
        "WBP_Map_Base",
        "WBP_WorldMap_C",
        "WBP_WorldMap",
        "WBP_PlayerUI_C",
        "WBP_PlayerUI",
        "WBP_WorldMap_Icon_Respawn_C",
        "WBP_WorldMap_Icon_Respawn",
        "WBP_WorldMap_IconBase_NoDesign_C",
        "WBP_WorldMap_IconBase_NoDesign",
        "WBP_WorldMap_IconBase_OnlyIcon_C",
        "WBP_WorldMap_IconBase_OnlyIcon",
        "WBP_Map_IconBoss_C",
        "WBP_Map_IconBoss",
        "WBP_Map_StandAloneBossIcon_C",
        "WBP_Map_StandAloneBossIcon",
        "WBP_Map_IconPortal_C",
        "WBP_Map_IconPortal",
        "WBP_Map_IconFTTower_C",
        "WBP_Map_IconFTTower",
        "WBP_Map_IconTower_C",
        "WBP_Map_IconTower",
        "WBP_Map_IconQuest_C",
        "WBP_Map_IconQuest",
        "WBP_Map_IconPlayer_C",
        "WBP_Map_IconPlayer",
        "WBP_SkillFruitFarm_C",
        "WBP_SkillFruitFarm",
        "WBP_ItemChest_Preference_C",
        "WBP_ItemChest_Preference",
        "WBP_ItemSearch_Filter_C",
        "WBP_ItemSearch_Filter"
    },

    MapBodyWidgetCandidates = {
        "WBP_Map_Body_C",
        "WBP_Map_Body"
    },

    MapBodyKnownFields = {
        "Canvas_ForIcon_Mask",
        "Canvas_ForIcon_NoMask",
        "Canvas_ForIcon_Priority",
        "Canvas_MapBody",
        "Image_MapBody",
        "Image_MapMask",
        "WBP_Map_Cursor"
    },

    MapBodyKnownFunctions = {
        "Add Icon",
        "AddIcon",
        "Add_Icon",
        "Add Icon By Location",
        "AddIconByLocation",
        "Add_Icon_By_Location",
        "WorldLocationToWidgetOffset",
        "World Location To Widget Offset",
        "WorldLocation To WidgetOffset",
        "GetMapCanvasPosition",
        "GetMapCanvasScalingSize",
        "Update Icon Visibility",
        "UpdateIconVisibility",
        "Update_Icon_Visibility"
    }
}

return Config
