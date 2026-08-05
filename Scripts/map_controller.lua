-- map_controller.lua
local Config = require("config")
local MapController = {}

local LastProbeTime = 0
local DumpedClassNames = {}
local DumpedMapBodyAddresses = {}
local InjectedMapBodyAddresses = {}
local HookTraceRegistered = false
local HookTraceLogCount = 0
local LastHookTraceRegisterAttemptTime = 0
local ScriptFilePaths = {}
local CustomMarkerHookTraceRegistered = false
local CustomMarkerHookTraceLogCount = 0
local LastCustomMarkerHookTraceRegisterAttemptTime = 0
local CustomMarkerInjectedMapBaseAddresses = {}
local StaticMarkersGeneratedThisSession = false
local OverlayInjectedMapBodyAddresses = {}
local StaticMarkerState = nil
local LastCursorWorldLocation = nil
local LastCursorWorldLocationAt = nil
local LastCursorTraceLogTime = 0
local LastCustomMarkerIconIndex = nil
local LastCustomMarkerIconChangedAt = nil
local NativeIconCaptureHookRegistered = false
local NativePendingLocationPoint = nil
local NativeCapturedWorldMapIcon = nil
local OverlayIconRecords = {}
local OverlayRuntimeFilterState = {}
local OverlayNativeFilterState = {}
local OverlaySourceCategoryCounts = {}
local OverlayFilterPanelMapAddresses = {}
local OverlayFilterPanelRows = {}
local RefreshOverlayFilterPanelCategory = function() end
local OverlayFilterPanelRoot = nil
local OverlayFilterPanelHeader = nil
local OverlayFilterPanelBody = nil
local OverlayFilterPanelWidgetTree = nil
local OverlayFilterPanelContainer = nil
local OverlayFilterPanelPanelConfig = nil
local OverlayFilterPanelExpanded = false
local OverlayFilterPanelProgressText = nil
local OverlayLazyContext = nil
MapController.NormalPalSelectedCategory = "NormalPalSelected"
MapController.NormalPalSelector = { MenuExpanded = false, SelectedIndex = 1 }
local OverlayLazyCategoryState = {}
local OverlayLazyQueue = {}
local OverlayLazyQueued = {}
local OverlayLazyActiveCategory = nil
local OverlayActiveLimitProfileName = nil
MapController.OverlayLazyRunSerial = 0
local EnsureOverlayCategoryIconsGenerated = function() return false end
local SetOverlayFilterPanelProgress = function() end

function MapController.IsOverlayMarkerCategoryName(categoryName)
    return type(categoryName) == "string"
        and categoryName ~= "Metadata"
        and categoryName ~= "PalCatalog"
        and categoryName ~= "PalDistributions"
        and categoryName ~= "GeneratedLoadError"
        and categoryName ~= "GeneratedPalCatalogLoadError"
        and categoryName ~= "GeneratedPalDistributionLoadError"
end

local function IsNativeFilterRuntimeVisible(filterName)
    if OverlayNativeFilterState[filterName] ~= nil then
        return OverlayNativeFilterState[filterName] == true
    end
    return true
end

local function RefreshOverlaySourceCategoryCounts(staticMarkerData)
    OverlaySourceCategoryCounts = {}
    if type(staticMarkerData) ~= "table" then return end

    for categoryName, markers in pairs(staticMarkerData) do
        if MapController.IsOverlayMarkerCategoryName(categoryName) and type(markers) == "table" then
            OverlaySourceCategoryCounts[categoryName] = #markers
        end
    end

    if MapController.GetSelectedNormalPalSourceCount then
        OverlaySourceCategoryCounts[MapController.NormalPalSelectedCategory] = MapController.GetSelectedNormalPalSourceCount(staticMarkerData)
    end
end

local function GetDumpFilePath()
    if ScriptFilePaths.Dump then return ScriptFilePaths.Dump end

    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*[\\/])")
    if dir and dir ~= "" then
        ScriptFilePaths.Dump = dir .. "PalRadar_WorldMap_SafeProbe.txt"
    else
        ScriptFilePaths.Dump = "PalRadar_WorldMap_SafeProbe.txt"
    end

    return ScriptFilePaths.Dump
end

local function GetHookTraceLogFilePath()
    if ScriptFilePaths.HookTrace then return ScriptFilePaths.HookTrace end

    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*[\\/])")
    if dir and dir ~= "" then
        ScriptFilePaths.HookTrace = dir .. "PalRadar_NativeHookTrace_Log.txt"
    else
        ScriptFilePaths.HookTrace = "PalRadar_NativeHookTrace_Log.txt"
    end

    return ScriptFilePaths.HookTrace
end

local function GetCustomMarkerTraceLogFilePath()
    if ScriptFilePaths.CustomMarkerTrace then return ScriptFilePaths.CustomMarkerTrace end

    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*[\\/])")
    if dir and dir ~= "" then
        ScriptFilePaths.CustomMarkerTrace = dir .. "PalRadar_CustomMarkerTrace_Log.txt"
    else
        ScriptFilePaths.CustomMarkerTrace = "PalRadar_CustomMarkerTrace_Log.txt"
    end

    return ScriptFilePaths.CustomMarkerTrace
end

local function GetCustomMarkerInjectionLogFilePath()
    if ScriptFilePaths.CustomMarkerInjection then return ScriptFilePaths.CustomMarkerInjection end

    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*[\\/])")
    if dir and dir ~= "" then
        ScriptFilePaths.CustomMarkerInjection = dir .. "PalRadar_CustomMarkerInjection_Log.txt"
    else
        ScriptFilePaths.CustomMarkerInjection = "PalRadar_CustomMarkerInjection_Log.txt"
    end

    return ScriptFilePaths.CustomMarkerInjection
end

local function GetStaticMarkersLogFilePath()
    if ScriptFilePaths.StaticMarkersLog then return ScriptFilePaths.StaticMarkersLog end

    local fileName = "PalRadar_StaticMarkers_Log.txt"
    if Config.StaticMarkers and Config.StaticMarkers.LogFileName then
        fileName = Config.StaticMarkers.LogFileName
    end

    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*[\\/])")
    if dir and dir ~= "" then
        ScriptFilePaths.StaticMarkersLog = dir .. fileName
    else
        ScriptFilePaths.StaticMarkersLog = fileName
    end

    return ScriptFilePaths.StaticMarkersLog
end

local function GetOverlayMarkersLogFilePath()
    if ScriptFilePaths.OverlayMarkersLog then return ScriptFilePaths.OverlayMarkersLog end

    local fileName = "PalRadar_OverlayMarkers_Log.txt"
    if Config.OverlayMarkers and Config.OverlayMarkers.LogFileName then
        fileName = Config.OverlayMarkers.LogFileName
    end

    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*[\\/])")
    if dir and dir ~= "" then
        ScriptFilePaths.OverlayMarkersLog = dir .. fileName
    else
        ScriptFilePaths.OverlayMarkersLog = fileName
    end

    return ScriptFilePaths.OverlayMarkersLog
end

local function GetStaticMarkersStateFilePath()
    if ScriptFilePaths.StaticMarkersState then return ScriptFilePaths.StaticMarkersState end

    local fileName = "PalRadar_StaticMarkers_State.txt"
    if Config.StaticMarkers and Config.StaticMarkers.StateFileName then
        fileName = Config.StaticMarkers.StateFileName
    end

    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*[\\/])")
    if dir and dir ~= "" then
        ScriptFilePaths.StaticMarkersState = dir .. fileName
    else
        ScriptFilePaths.StaticMarkersState = fileName
    end

    return ScriptFilePaths.StaticMarkersState
end

local function GetInjectionLogFilePath()
    if ScriptFilePaths.InjectionLog then return ScriptFilePaths.InjectionLog end

    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*[\\/])")
    if dir and dir ~= "" then
        ScriptFilePaths.InjectionLog = dir .. "PalRadar_NativeInjection_Log.txt"
    else
        ScriptFilePaths.InjectionLog = "PalRadar_NativeInjection_Log.txt"
    end

    return ScriptFilePaths.InjectionLog
end

local function GetBridgeProbeFilePath()
    if ScriptFilePaths.BridgeProbe then return ScriptFilePaths.BridgeProbe end

    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*[\\/])")
    if dir and dir ~= "" then
        ScriptFilePaths.BridgeProbe = dir .. "PalRadar_MapBody_BridgeProbe.txt"
    else
        ScriptFilePaths.BridgeProbe = "PalRadar_MapBody_BridgeProbe.txt"
    end

    return ScriptFilePaths.BridgeProbe
end

local function IsValidObject(obj)
    local ok, result = pcall(function()
        return obj and obj:IsValid()
    end)
    return ok and result
end

local function SafeMethod(obj, funcName)
    if not IsValidObject(obj) then return nil end
    local ok, result = pcall(function()
        return obj[funcName](obj)
    end)
    if ok then return result end
    return nil
end

local function SafeField(obj, fieldName)
    if not IsValidObject(obj) then return nil, false end
    local ok, result = pcall(function()
        return obj[fieldName]
    end)
    if ok then return result, true end
    return nil, false
end

local function SafeFunctionLookup(obj, funcName)
    if not IsValidObject(obj) then return false, "invalid-object" end
    local ok, result = pcall(function()
        return obj[funcName]
    end)
    if not ok then return false, "lookup-error" end
    if result == nil then return false, "nil" end
    return true, tostring(result)
end

local function GetObjectClassName(obj)
    local class = SafeMethod(obj, "GetClass")
    local name = SafeMethod(class, "GetName")
    if name and name ~= "" then return name end

    local fullName = SafeMethod(obj, "GetFullName")
    if fullName then
        local parsed = fullName:match("^([^%s]+)")
        if parsed and parsed ~= "" then return parsed end
    end

    return SafeMethod(obj, "GetName") or "UnknownClass"
end

local function GetObjectName(obj)
    return SafeMethod(obj, "GetFullName") or SafeMethod(obj, "GetName") or "UnknownObject"
end

local function GetObjectAddress(obj)
    local addr = SafeMethod(obj, "GetAddress")
    if addr then return tostring(addr) end
    return tostring(obj)
end

local function AppendLine(file, text)
    file:write(tostring(text))
    file:write("\n")
end

local function AppendInjectionLog(text)
    local file, err = io.open(GetInjectionLogFilePath(), "a")
    if not file then
        print("[!] [MAP_INJECT] Could not write injection log: " .. tostring(err))
        return
    end
    AppendLine(file, os.date("%Y-%m-%d %H:%M:%S") .. " | " .. tostring(text))
    file:close()
end

local function AppendHookTraceLog(text)
    local file, err = io.open(GetHookTraceLogFilePath(), "a")
    if not file then
        print("[!] [MAP_HOOK] Could not write hook trace log: " .. tostring(err))
        return
    end
    AppendLine(file, os.date("%Y-%m-%d %H:%M:%S") .. " | " .. tostring(text))
    file:close()
end

local function AppendCustomMarkerTraceLog(text)
    local file, err = io.open(GetCustomMarkerTraceLogFilePath(), "a")
    if not file then
        print("[!] [CUSTOM_MARKER] Could not write custom marker trace log: " .. tostring(err))
        return
    end
    AppendLine(file, os.date("%Y-%m-%d %H:%M:%S") .. " | " .. tostring(text))
    file:close()
end

local function AppendCustomMarkerInjectionLog(text)
    local file, err = io.open(GetCustomMarkerInjectionLogFilePath(), "a")
    if not file then
        print("[!] [CUSTOM_MARKER_INJECT] Could not write custom marker injection log: " .. tostring(err))
        return
    end
    AppendLine(file, os.date("%Y-%m-%d %H:%M:%S") .. " | " .. tostring(text))
    file:close()
end

local function AppendStaticMarkersLog(text)
    local file, err = io.open(GetStaticMarkersLogFilePath(), "a")
    if not file then
        print("[!] [STATIC_MARKERS] Could not write static marker log: " .. tostring(err))
        return
    end
    AppendLine(file, os.date("%Y-%m-%d %H:%M:%S") .. " | " .. tostring(text))
    file:close()
end

local function AppendOverlayMarkersLog(text)
    local file, err = io.open(GetOverlayMarkersLogFilePath(), "a")
    if not file then
        print("[!] [OVERLAY_MARKERS] Could not write overlay marker log: " .. tostring(err))
        return
    end
    AppendLine(file, os.date("%Y-%m-%d %H:%M:%S") .. " | " .. tostring(text))
    file:close()
end

local function UnwrapParam(value)
    if value == nil then return nil end

    local ok, unwrapped = pcall(function()
        if value.get then return value:get() end
        if value.Get then return value:Get() end
        return value
    end)

    if ok then return unwrapped end
    return value
end

local function DescribeValue(value)
    local unwrapped = UnwrapParam(value)
    if unwrapped == nil then return "nil" end

    local luaType = type(unwrapped)
    if luaType ~= "userdata" then
        return luaType .. ":" .. tostring(unwrapped)
    end

    local ueType = nil
    pcall(function()
        ueType = unwrapped:type()
    end)

    if ueType == "UObject" or ueType == "UFunction" then
        local fullName = GetObjectName(unwrapped)
        local className = GetObjectClassName(unwrapped)
        return tostring(ueType) .. " class=" .. tostring(className) .. " name=" .. tostring(fullName)
    end

    local coords = {}
    pcall(function()
        coords[#coords + 1] = "X=" .. tostring(unwrapped.X)
        coords[#coords + 1] = "Y=" .. tostring(unwrapped.Y)
        coords[#coords + 1] = "Z=" .. tostring(unwrapped.Z)
    end)
    if #coords > 0 then
        return tostring(ueType or luaType) .. " " .. table.concat(coords, ",")
    end

    local guidParts = {}
    pcall(function()
        guidParts[#guidParts + 1] = "A=" .. tostring(unwrapped.A)
        guidParts[#guidParts + 1] = "B=" .. tostring(unwrapped.B)
        guidParts[#guidParts + 1] = "C=" .. tostring(unwrapped.C)
        guidParts[#guidParts + 1] = "D=" .. tostring(unwrapped.D)
    end)
    if #guidParts > 0 then
        return tostring(ueType or luaType) .. " " .. table.concat(guidParts, ",")
    end

    local markerParts = {}
    local markerFields = {
        "Location",
        "WorldLocation",
        "MapLocation",
        "Position",
        "IconType",
        "Type",
        "MarkerType",
        "IconIndex",
        "Index"
    }
    for _, fieldName in ipairs(markerFields) do
        pcall(function()
            local fieldValue = unwrapped[fieldName]
            if fieldValue ~= nil then
                markerParts[#markerParts + 1] = fieldName .. "=" .. DescribeValue(fieldValue)
            end
        end)
    end
    if #markerParts > 0 then
        return tostring(ueType or luaType) .. " {" .. table.concat(markerParts, "; ") .. "}"
    end

    return tostring(ueType or luaType) .. ":" .. tostring(unwrapped)
end

local function ReadVector(value)
    local unwrapped = UnwrapParam(value)
    if unwrapped == nil then return nil end

    local x = nil
    local y = nil
    local z = nil
    local ok = pcall(function()
        x = tonumber(unwrapped.X)
        y = tonumber(unwrapped.Y)
        z = tonumber(unwrapped.Z)
    end)

    if not ok or not x or not y then return nil end
    if math.abs(x) < 1.0 and math.abs(y) < 1.0 and math.abs(z or 0.0) < 1.0 then
        return nil
    end

    return {
        X = x,
        Y = y,
        Z = z or 0.0
    }
end

local function FormatVector(vector)
    if not vector then return "nil" end

    return string.format(
        "X=%.6f,Y=%.6f,Z=%.6f",
        tonumber(vector.X) or 0.0,
        tonumber(vector.Y) or 0.0,
        tonumber(vector.Z) or 0.0
    )
end

local function RememberCursorWorldLocation(value)
    local vector = ReadVector(value)
    if not vector then return false end

    LastCursorWorldLocation = vector
    LastCursorWorldLocationAt = os.clock()
    return true
end

local function RememberSelectedCustomMarkerIcon(value)
    local unwrapped = UnwrapParam(value)
    if type(unwrapped) ~= "number" then return false end

    LastCustomMarkerIconIndex = unwrapped
    LastCustomMarkerIconChangedAt = os.clock()
    return true
end

local function ReadIconType(value)
    local unwrapped = UnwrapParam(value)
    if unwrapped == nil then return nil end

    local iconType = nil
    pcall(function()
        iconType = tonumber(unwrapped.IconType)
    end)

    return iconType
end

local function AppendRecentCustomMarkerContext()
    AppendCustomMarkerTraceLog("  lastCursorWorldLocation=" .. FormatVector(LastCursorWorldLocation))
    AppendCustomMarkerTraceLog("  lastCursorAgeSeconds=" .. tostring(LastCursorWorldLocationAt and (os.clock() - LastCursorWorldLocationAt) or "nil"))
    AppendCustomMarkerTraceLog("  lastSelectedIconIndex=" .. tostring(LastCustomMarkerIconIndex))
    AppendCustomMarkerTraceLog("  lastSelectedIconAgeSeconds=" .. tostring(LastCustomMarkerIconChangedAt and (os.clock() - LastCustomMarkerIconChangedAt) or "nil"))
end

local function CustomMarkerTraceLimit()
    return tonumber(Config.CustomMarkerHookTraceMaxEvents) or 600
end

local function DescribeCustomIconFields(icon)
    if not IsValidObject(icon) then return "invalid-icon" end

    local fields = {
        "LocationID",
        "LocationId",
        "MarkerId",
        "MarkerID",
        "CustomMarkerId",
        "CustomMarkerID",
        "IconType",
        "Index",
        "WorldLocation",
        "Location",
        "MapLocation"
    }
    local parts = {}

    for _, fieldName in ipairs(fields) do
        local value, readable = SafeField(icon, fieldName)
        if readable and value ~= nil then
            parts[#parts + 1] = fieldName .. "=" .. DescribeValue(value)
        end
    end

    if #parts == 0 then return "no-known-fields" end
    return table.concat(parts, "; ")
end

function MapController.TryRegisterCustomMarkerHookTrace()
    if CustomMarkerHookTraceRegistered then return end
    if not Config.EnableCustomMarkerHookTrace then return end

    local now = os.clock()
    if now - LastCustomMarkerHookTraceRegisterAttemptTime < 2.0 then return end
    LastCustomMarkerHookTraceRegisterAttemptTime = now

    local hookSpecs = {
        {
            Label = "WBP_Map_Base:AddCustomIcon",
            Paths = {
                "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:AddCustomIcon",
                "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:AddCustomIcon",
                "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:AddCustomIcon",
                "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:AddCustomIcon"
            },
            Handler = function(hookPath, self, locationId, markerData)
                CustomMarkerHookTraceLogCount = CustomMarkerHookTraceLogCount + 1
                if CustomMarkerHookTraceLogCount > CustomMarkerTraceLimit() then return end

                local iconType = ReadIconType(markerData)
                if iconType ~= nil then
                    LastCustomMarkerIconIndex = iconType
                    LastCustomMarkerIconChangedAt = os.clock()
                end

                AppendCustomMarkerTraceLog("Hook=" .. hookPath)
                AppendCustomMarkerTraceLog("  self=" .. DescribeValue(self))
                AppendCustomMarkerTraceLog("  locationId=" .. DescribeValue(locationId))
                AppendCustomMarkerTraceLog("  markerData=" .. DescribeValue(markerData))
                AppendRecentCustomMarkerContext()
                AppendCustomMarkerTraceLog("  --")
            end
        },
        {
            Label = "WBP_Map_Base:RemoveCustomIcon",
            Paths = {
                "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:RemoveCustomIcon",
                "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:RemoveCustomIcon",
                "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:RemoveCustomIcon",
                "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:RemoveCustomIcon"
            },
            Handler = function(hookPath, self, ...)
                CustomMarkerHookTraceLogCount = CustomMarkerHookTraceLogCount + 1
                if CustomMarkerHookTraceLogCount > CustomMarkerTraceLimit() then return end

                local args = { ... }
                AppendCustomMarkerTraceLog("Hook=" .. hookPath)
                AppendCustomMarkerTraceLog("  self=" .. DescribeValue(self))
                for i, arg in ipairs(args) do
                    AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. "=" .. DescribeValue(arg))
                    local unwrapped = UnwrapParam(arg)
                    if IsValidObject(unwrapped) then
                        AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. ".customFields=" .. DescribeCustomIconFields(unwrapped))
                    end
                end
                AppendRecentCustomMarkerContext()
                AppendCustomMarkerTraceLog("  --")
            end
        },
        {
            Label = "WBP_Map_Base:ChangeCustomIcon",
            Paths = {
                "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:ChangeCustomIcon",
                "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:ChangeCustomIcon",
                "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:ChangeCustomIcon",
                "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:ChangeCustomIcon"
            },
            Handler = function(hookPath, self, ...)
                CustomMarkerHookTraceLogCount = CustomMarkerHookTraceLogCount + 1
                if CustomMarkerHookTraceLogCount > CustomMarkerTraceLimit() then return end

                local args = { ... }
                AppendCustomMarkerTraceLog("Hook=" .. hookPath)
                AppendCustomMarkerTraceLog("  self=" .. DescribeValue(self))
                for i, arg in ipairs(args) do
                    RememberSelectedCustomMarkerIcon(arg)
                    AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. "=" .. DescribeValue(arg))
                    local unwrapped = UnwrapParam(arg)
                    if IsValidObject(unwrapped) then
                        AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. ".customFields=" .. DescribeCustomIconFields(unwrapped))
                    end
                end
                AppendRecentCustomMarkerContext()
                AppendCustomMarkerTraceLog("  --")
            end
        },
        {
            Label = "WBP_Map_Base:ConfirmTempCustomIcon",
            Paths = {
                "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:ConfirmTempCustomIcon",
                "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:ConfirmTempCustomIcon",
                "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:ConfirmTempCustomIcon",
                "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:ConfirmTempCustomIcon"
            },
            Handler = function(hookPath, self, ...)
                CustomMarkerHookTraceLogCount = CustomMarkerHookTraceLogCount + 1
                if CustomMarkerHookTraceLogCount > CustomMarkerTraceLimit() then return end

                local args = { ... }
                AppendCustomMarkerTraceLog("Hook=" .. hookPath)
                AppendCustomMarkerTraceLog("  self=" .. DescribeValue(self))
                for i, arg in ipairs(args) do
                    AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. "=" .. DescribeValue(arg))
                    local unwrapped = UnwrapParam(arg)
                    if IsValidObject(unwrapped) then
                        AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. ".customFields=" .. DescribeCustomIconFields(unwrapped))
                    end
                end
                AppendRecentCustomMarkerContext()
                AppendCustomMarkerTraceLog("  --")
            end
        },
        {
            Label = "WBP_Map_Base:On Custom Mark Changed",
            Paths = {
                "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:On Custom Mark Changed",
                "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:On Custom Mark Changed",
                "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:On Custom Mark Changed",
                "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:On Custom Mark Changed"
            },
            Handler = function(hookPath, self, ...)
                CustomMarkerHookTraceLogCount = CustomMarkerHookTraceLogCount + 1
                if CustomMarkerHookTraceLogCount > CustomMarkerTraceLimit() then return end

                local args = { ... }
                AppendCustomMarkerTraceLog("Hook=" .. hookPath)
                AppendCustomMarkerTraceLog("  self=" .. DescribeValue(self))
                for i, arg in ipairs(args) do
                    AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. "=" .. DescribeValue(arg))
                end
                AppendRecentCustomMarkerContext()
                AppendCustomMarkerTraceLog("  --")
            end
        },
        {
            Label = "WBP_Map_Body:GetCursorWorldLocation",
            Paths = {
                "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:GetCursorWorldLocation",
                "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:GetCursorWorldLocation",
                "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:GetCursorWorldLocation",
                "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:GetCursorWorldLocation"
            },
            Handler = function(hookPath, self, ...)
                local args = { ... }
                for _, arg in ipairs(args) do
                    RememberCursorWorldLocation(arg)
                end

                local now = os.clock()
                if now - LastCursorTraceLogTime < 0.75 then return end
                LastCursorTraceLogTime = now

                AppendCustomMarkerTraceLog("Hook=" .. hookPath)
                AppendCustomMarkerTraceLog("  self=" .. DescribeValue(self))
                for i, arg in ipairs(args) do
                    AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. "=" .. DescribeValue(arg))
                end
                AppendRecentCustomMarkerContext()
                AppendCustomMarkerTraceLog("  --")
            end
        },
        {
            Label = "WBP_Map_Body:GetWIndowCenterWorldLocation",
            Paths = {
                "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:GetWIndowCenterWorldLocation",
                "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:GetWIndowCenterWorldLocation",
                "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:GetWIndowCenterWorldLocation",
                "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:GetWIndowCenterWorldLocation"
            },
            Handler = function(hookPath, self, ...)
                CustomMarkerHookTraceLogCount = CustomMarkerHookTraceLogCount + 1
                if CustomMarkerHookTraceLogCount > CustomMarkerTraceLimit() then return end

                local args = { ... }
                AppendCustomMarkerTraceLog("Hook=" .. hookPath)
                AppendCustomMarkerTraceLog("  self=" .. DescribeValue(self))
                for i, arg in ipairs(args) do
                    AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. "=" .. DescribeValue(arg))
                end
                AppendRecentCustomMarkerContext()
                AppendCustomMarkerTraceLog("  --")
            end
        },
        {
            Label = "PalLocationManager:AddLocalCustomMarker",
            Paths = {
                "/Script/Pal.PalLocationManager:AddLocalCustomMarker",
                "Function /Script/Pal.PalLocationManager:AddLocalCustomMarker",
                "PalLocationManager:AddLocalCustomMarker",
                "Function PalLocationManager:AddLocalCustomMarker"
            },
            Handler = function(hookPath, self, ...)
                CustomMarkerHookTraceLogCount = CustomMarkerHookTraceLogCount + 1
                if CustomMarkerHookTraceLogCount > CustomMarkerTraceLimit() then return end

                local args = { ... }
                AppendCustomMarkerTraceLog("Hook=" .. hookPath)
                AppendCustomMarkerTraceLog("  self=" .. DescribeValue(self))
                for i, arg in ipairs(args) do
                    RememberCursorWorldLocation(arg)
                    AppendCustomMarkerTraceLog("  arg" .. tostring(i) .. "=" .. DescribeValue(arg))
                end
                AppendRecentCustomMarkerContext()
                AppendCustomMarkerTraceLog("  --")
            end
        }
    }

    local registered = 0
    for _, spec in ipairs(hookSpecs) do
        for _, hookPath in ipairs(spec.Paths) do
            local ok, preId, postId = pcall(function()
                return RegisterHook(hookPath, function(...)
                    spec.Handler(hookPath, ...)
                end)
            end)

            if ok then
                registered = registered + 1
                AppendCustomMarkerTraceLog("Registered " .. spec.Label .. ": " .. hookPath .. " preId=" .. tostring(preId) .. " postId=" .. tostring(postId))
                break
            else
                AppendCustomMarkerTraceLog("RegisterHook failed " .. spec.Label .. ": " .. hookPath .. " | " .. tostring(preId))
            end
        end
    end

    if registered > 0 then
        CustomMarkerHookTraceRegistered = true
        print("[+] [CUSTOM_MARKER] Registered custom marker hook trace.")
    end
end

function MapController.TryRegisterNativeMapHookTrace()
    if HookTraceRegistered then return end
    if not Config.EnableNativeMapHookTrace then return end

    local now = os.clock()
    if now - LastHookTraceRegisterAttemptTime < 2.0 then return end
    LastHookTraceRegisterAttemptTime = now

    local functionPaths = {
        "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:Add Icon By Location",
        "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:Add Icon By Location",
        "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:Add Icon By Location",
        "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:Add Icon By Location"
    }

    for _, hookPath in ipairs(functionPaths) do
        local ok, preId, postId = pcall(function()
            return RegisterHook(hookPath, function(self, widget, worldLocation, ignoreMask, toPriority, added)
                HookTraceLogCount = HookTraceLogCount + 1
                if HookTraceLogCount > 40 then return end

                AppendHookTraceLog("HookPath=" .. hookPath)
                AppendHookTraceLog("  self=" .. DescribeValue(self))
                AppendHookTraceLog("  widget=" .. DescribeValue(widget))
                AppendHookTraceLog("  worldLocation=" .. DescribeValue(worldLocation))
                AppendHookTraceLog("  ignoreMask=" .. DescribeValue(ignoreMask))
                AppendHookTraceLog("  toPriority=" .. DescribeValue(toPriority))
                AppendHookTraceLog("  added=" .. DescribeValue(added))
                AppendHookTraceLog("  --")
            end)
        end)

        if ok then
            HookTraceRegistered = true
            AppendHookTraceLog("Registered hook trace: " .. hookPath .. " preId=" .. tostring(preId) .. " postId=" .. tostring(postId))
            print("[+] [MAP_HOOK] Registered native map icon hook trace.")
            return
        else
            AppendHookTraceLog("RegisterHook failed: " .. hookPath .. " | " .. tostring(preId))
        end
    end
end

local function WriteSafeProbeSummary(className, objects)
    if not objects or #objects == 0 then return end

    local firstObject = nil
    for _, obj in ipairs(objects) do
        if IsValidObject(obj) then
            firstObject = obj
            break
        end
    end
    if not firstObject then return end

    local resolvedClass = GetObjectClassName(firstObject)
    if DumpedClassNames[resolvedClass] then return end
    DumpedClassNames[resolvedClass] = true

    local dumpPath = GetDumpFilePath()
    local file, err = io.open(dumpPath, "a")
    if not file then
        print("[!] [MAP_PROBE] Could not write " .. tostring(dumpPath) .. ": " .. tostring(err))
        return
    end

    AppendLine(file, "")
    AppendLine(file, "============================================================")
    AppendLine(file, "Candidate: " .. className)
    AppendLine(file, "ResolvedClass: " .. resolvedClass)
    AppendLine(file, "Count: " .. tostring(#objects))
    AppendLine(file, "FirstObject: " .. GetObjectName(firstObject))
    AppendLine(file, "FirstAddress: " .. GetObjectAddress(firstObject))
    AppendLine(file, "============================================================")
    file:close()

    print("[+] [MAP_PROBE] Safe class probe: " .. resolvedClass .. " x" .. tostring(#objects))
end

local function FindLiveMapBody()
    local fallback = nil
    local fallbackClassName = nil
    local fallbackObjects = nil
    local preferredFragments = {
        "WBP_Map_Body_MW5",
        "Map_Body_MW5",
        "MainWorld",
        "PL_MainWorld"
    }

    for _, className in ipairs(Config.MapBodyWidgetCandidates or {}) do
        local objects = nil
        pcall(function()
            objects = FindAllOf(className)
        end)

        if objects then
            for _, obj in ipairs(objects) do
                if IsValidObject(obj) then
                    if not fallback then
                        fallback = obj
                        fallbackClassName = className
                        fallbackObjects = objects
                    end

                    local name = GetObjectName(obj)
                    for _, fragment in ipairs(preferredFragments) do
                        if tostring(name):find(fragment, 1, true) then
                            return obj, className, objects
                        end
                    end
                end
            end
        end
    end

    return fallback, fallbackClassName, fallbackObjects
end

local function WriteMapBodyBridgeProbe(mapBody, candidateName, objects)
    if not IsValidObject(mapBody) then return end

    local address = GetObjectAddress(mapBody)
    if DumpedMapBodyAddresses[address] then return end
    DumpedMapBodyAddresses[address] = true

    local dumpPath = GetBridgeProbeFilePath()
    local file, err = io.open(dumpPath, "a")
    if not file then
        print("[!] [MAP_BRIDGE] Could not write " .. tostring(dumpPath) .. ": " .. tostring(err))
        return
    end

    AppendLine(file, "")
    AppendLine(file, "============================================================")
    AppendLine(file, "Map body bridge probe")
    AppendLine(file, "Candidate: " .. tostring(candidateName))
    AppendLine(file, "ResolvedClass: " .. GetObjectClassName(mapBody))
    AppendLine(file, "Count: " .. tostring(objects and #objects or 1))
    AppendLine(file, "Object: " .. GetObjectName(mapBody))
    AppendLine(file, "Address: " .. address)
    AppendLine(file, "")
    AppendLine(file, "Known widget fields:")

    for _, fieldName in ipairs(Config.MapBodyKnownFields or {}) do
        local field, readable = SafeField(mapBody, fieldName)
        local valid = IsValidObject(field)
        local fieldNameText = valid and GetObjectName(field) or tostring(field)
        AppendLine(file, string.format("  %s | readable=%s | valid=%s | value=%s", fieldName, tostring(readable), tostring(valid), fieldNameText))
    end

    AppendLine(file, "")
    AppendLine(file, "Known callable entries:")
    for _, funcName in ipairs(Config.MapBodyKnownFunctions or {}) do
        local exists, detail = SafeFunctionLookup(mapBody, funcName)
        AppendLine(file, string.format("  %s | exists=%s | detail=%s", funcName, tostring(exists), tostring(detail)))
    end

    AppendLine(file, "============================================================")
    file:close()

    print("[+] [MAP_BRIDGE] WBP_Map_Body bridge probe captured.")
end

function MapController.FindLiveMapBody()
    local mapBody = nil
    local candidateName = nil
    local objects = nil
    mapBody, candidateName, objects = FindLiveMapBody()
    return mapBody, candidateName, objects
end

function MapController.FindLiveMapBase()
    local classNames = {
        "WBP_Map_Base_C",
        "WBP_Map_Base"
    }

    for _, className in ipairs(classNames) do
        local objects = nil
        pcall(function()
            objects = FindAllOf(className)
        end)

        if objects then
            for _, obj in ipairs(objects) do
                if IsValidObject(obj) then
                    return obj, className, objects
                end
            end
        end

        local first = nil
        pcall(function()
            first = FindFirstOf(className)
        end)
        if IsValidObject(first) then
            return first, className, nil
        end
    end

    return nil, "not-found", nil
end

function MapController.ProbeMapBodyBridge()
    local mapBody, candidateName, objects = FindLiveMapBody()
    if not IsValidObject(mapBody) then return nil end

    WriteMapBodyBridgeProbe(mapBody, candidateName, objects)
    return mapBody
end

local function LoadIconWidgetClass(classPath)
    local defaultClassPath = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconBoss.WBP_Map_IconBoss_C"
    local selectedClassPath = classPath or (Config.Assets and Config.Assets.TestBossIconWidget) or defaultClassPath
    local assetPath = tostring(selectedClassPath):gsub("_C$", "")
    local classPaths = { selectedClassPath }

    -- When the caller explicitly asks for a widget class, do not silently fall
    -- back to the boss widget. Boss widgets need native initialization and can
    -- crash when called from Lua.
    if not classPath then
        classPaths[#classPaths + 1] = Config.Assets and Config.Assets.TestBossIconWidget
        classPaths[#classPaths + 1] = defaultClassPath
        classPaths[#classPaths + 1] = "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconBoss.WBP_Map_IconBoss_C"
    end

    pcall(function()
        LoadAsset(assetPath)
    end)

    for _, path in ipairs(classPaths) do
        local klass = nil
        pcall(function()
            klass = StaticFindObject(path)
        end)
        if IsValidObject(klass) then
            return klass, path
        end
    end

    local found = nil
    local className = tostring(selectedClassPath):match("([^/%.]+_C)$") or "WBP_Map_IconBoss_C"
    pcall(function()
        found = FindObject(nil, className, EObjectFlags.RF_NoFlags, EObjectFlags.RF_NoFlags)
    end)
    if IsValidObject(found) then
        return found, "FindObject:" .. tostring(className)
    end

    return nil, "not-found"
end

local function FindPlayerController()
    local classNames = {
        "BP_PalPlayerController_C",
        "PalPlayerController",
        "PlayerController"
    }

    for _, className in ipairs(classNames) do
        local obj = nil
        pcall(function()
            obj = FindFirstOf(className)
        end)
        if IsValidObject(obj) then return obj, className end
    end

    return nil, "not-found"
end

local function FindWidgetBlueprintLibrary()
    local paths = {
        "/Script/UMG.Default__WidgetBlueprintLibrary",
        "WidgetBlueprintLibrary /Script/UMG.Default__WidgetBlueprintLibrary",
        "Default__WidgetBlueprintLibrary"
    }

    for _, path in ipairs(paths) do
        local obj = nil
        pcall(function()
            obj = StaticFindObject(path)
        end)
        if IsValidObject(obj) then return obj, path end
    end

    local found = nil
    pcall(function()
        found = FindFirstOf("WidgetBlueprintLibrary")
    end)
    if IsValidObject(found) then return found, "FindFirstOf:WidgetBlueprintLibrary" end

    return nil, "not-found"
end

local function ForceIconWidgetVisible(widget)
    if not IsValidObject(widget) then return 0 end

    local touched = 0
    local knownParts = {
        "CanvasPanel",
        "CanvasPanel_0",
        "CanvasPanel_166",
        "CanvasPanel_Boss",
        "Icon",
        "Icon_Base",
        "Icon_BaseShadow",
        "Icon_EnemyCamp",
        "Icon_HumanBoss",
        "Icon_Oilrig",
        "Image_ClearMark",
        "Image_InCave",
        "WBP_PalCommonButton",
        "WBP_PalCommonCharacterIcon"
    }

    local function makeVisible(obj)
        if not obj then return end

        local changed = false
        local okVisibility = pcall(function()
            if obj.SetVisibility then obj:SetVisibility(0) end
        end)
        changed = changed or okVisibility

        local okOpacity = pcall(function()
            if obj.SetRenderOpacity then obj:SetRenderOpacity(1.0) end
        end)
        changed = changed or okOpacity

        if changed then touched = touched + 1 end
    end

    makeVisible(widget)

    for _, fieldName in ipairs(knownParts) do
        local part = nil
        pcall(function()
            part = widget[fieldName]
        end)
        makeVisible(part)
    end

    pcall(function()
        if widget.ForceLayoutPrepass then widget:ForceLayoutPrepass() end
    end)

    return touched
end

local function ConstructIconWidgetWithLibrary(klass, mapBody)
    local playerController, pcSource = FindPlayerController()
    if not IsValidObject(playerController) then
        return nil, "no-player-controller:" .. tostring(pcSource)
    end

    local library, libSource = FindWidgetBlueprintLibrary()
    if not IsValidObject(library) then
        return nil, "no-widget-library:" .. tostring(libSource)
    end

    local attempts = {
        {
            "Create:world-pc",
            function()
                return library:Create(playerController, klass, playerController)
            end
        },
        {
            "Create:world-mapbody",
            function()
                return library:Create(mapBody, klass, playerController)
            end
        },
        {
            "Create:spaced",
            function()
                return library["Create"](library, playerController, klass, playerController)
            end
        }
    }

    for _, attempt in ipairs(attempts) do
        local ok, widget = pcall(attempt[2])
        if ok and IsValidObject(widget) then
            return widget, "WidgetBlueprintLibrary:" .. tostring(attempt[1]) .. " pc=" .. tostring(pcSource) .. " lib=" .. tostring(libSource)
        end
    end

    return nil, "widget-library-create-failed"
end

local function ConstructIconWidgetWithObject(klass, mapBody)
    local playerController, pcSource = FindPlayerController()
    local widget = nil
    local ok, err = pcall(function()
        local outer = playerController or mapBody
        local keepFlags = 0x0E000000
        widget = StaticConstructObject(klass, outer, 0, 0, keepFlags, nil, false, false, nil)
    end)

    if not ok then
        return nil, "construct-error:" .. tostring(err)
    end

    if not IsValidObject(widget) then
        return nil, "constructed-invalid"
    end

    if IsValidObject(playerController) then
        pcall(function()
            if widget.SetOwningPlayer then widget:SetOwningPlayer(playerController) end
        end)
    end

    return widget, "StaticConstructObject pc=" .. tostring(pcSource)
end

local function ConstructIconWidget(mapBody, classPath)
    local klass, source = LoadIconWidgetClass(classPath)
    if not IsValidObject(klass) then
        return nil, "icon-class-" .. tostring(source)
    end

    local widget, createSource = ConstructIconWidgetWithLibrary(klass, mapBody)
    if not IsValidObject(widget) then
        local fallbackWidget, fallbackSource = ConstructIconWidgetWithObject(klass, mapBody)
        widget = fallbackWidget
        createSource = tostring(createSource) .. " fallback=" .. tostring(fallbackSource)
    end

    if not IsValidObject(widget) then
        return nil, tostring(createSource)
    end

    pcall(function()
        if widget.Initialize then widget:Initialize() end
    end)

    pcall(function()
        if widget.SetVisibility then widget:SetVisibility(0) end
    end)

    local touched = ForceIconWidgetVisible(widget)
    AppendInjectionLog("Constructed widget via " .. tostring(source) .. " / " .. tostring(createSource) .. " | " .. GetObjectName(widget) .. " | forcedVisibleParts=" .. tostring(touched))

    return widget, source
end

local function GetInjectionLocation(dataState)
    local anchor = dataState and dataState.PlayerAnchor or nil
    if not anchor then return nil end

    local offset = Config.NativeInjectionOffset or {}
    local nativeLocation = nil
    pcall(function()
        nativeLocation = anchor.Instance:K2_GetActorLocation()
    end)

    if nativeLocation then
        pcall(function()
            nativeLocation.X = nativeLocation.X + (offset.X or 0)
            nativeLocation.Y = nativeLocation.Y + (offset.Y or 0)
            nativeLocation.Z = nativeLocation.Z + (offset.Z or 0)
        end)
        return nativeLocation
    end

    return nil
end

local function TryCallAddIconByLocation(mapBody, widget, worldLocation, ignoreMask, toPriority)
    local ufunc = nil
    pcall(function()
        ufunc = mapBody["Add Icon By Location"]
    end)

    if ufunc == nil then
        return false, "ufunction-not-valid"
    end

    local errors = {}
    local addedOut = {}
    local useIgnoreMask = ignoreMask == true
    local useToPriority = toPriority == true

    local attempts = {
        {
            "Direct:AddIconByLocation",
            function()
                return mapBody:AddIconByLocation(widget, worldLocation, useIgnoreMask, useToPriority, addedOut)
            end
        },
        {
            "Direct:Add_Icon_By_Location",
            function()
                return mapBody:Add_Icon_By_Location(widget, worldLocation, useIgnoreMask, useToPriority, addedOut)
            end
        },
        {
            "Direct:spaced",
            function()
                return mapBody["Add Icon By Location"](mapBody, widget, worldLocation, useIgnoreMask, useToPriority, addedOut)
            end
        },
        {
            "CallFunction:withOutTable",
            function()
                return mapBody:CallFunction(ufunc, widget, worldLocation, useIgnoreMask, useToPriority, addedOut)
            end
        },
        {
            "UFunction:withOutTable",
            function()
                return ufunc(mapBody, widget, worldLocation, useIgnoreMask, useToPriority, addedOut)
            end
        },
        {
            "Direct:AddIconByLocation-noOut",
            function()
                return mapBody:AddIconByLocation(widget, worldLocation, useIgnoreMask, useToPriority)
            end
        },
        {
            "Direct:Add_Icon_By_Location-noOut",
            function()
                return mapBody:Add_Icon_By_Location(widget, worldLocation, useIgnoreMask, useToPriority)
            end
        },
        {
            "CallFunction:noOut",
            function()
                return mapBody:CallFunction(ufunc, widget, worldLocation, useIgnoreMask, useToPriority)
            end
        }
    }

    for _, attempt in ipairs(attempts) do
        local label = attempt[1]
        local ok, result = pcall(attempt[2])
        if ok then
            local outValue = addedOut.Added
            if outValue == nil then outValue = addedOut.added end
            if outValue == false then
                return false, label .. " result=" .. tostring(result) .. " outAdded=false"
            end
            return true, label .. " result=" .. tostring(result) .. " outAdded=" .. tostring(outValue)
        end
        errors[#errors + 1] = label .. "=" .. tostring(result)
    end

    return false, "call-error:" .. table.concat(errors, " | ")
end

local function GetMapCanvasLayer(mapBody, preferPriority)
    if not mapBody then return nil, "no-map-body" end

    local fieldNames = {}
    if preferPriority == true then
        fieldNames = {
            "Canvas_ForIcon_Priority",
            "Canvas_ForIcon_NoMask",
            "Canvas_MapBody",
            "Canvas_ForIcon_Mask"
        }
    else
        fieldNames = {
            "Canvas_ForIcon_NoMask",
            "Canvas_ForIcon_Priority",
            "Canvas_MapBody",
            "Canvas_ForIcon_Mask"
        }
    end

    local errors = {}
    for _, fieldName in ipairs(fieldNames) do
        local panel = nil
        local ok, result = pcall(function()
            return mapBody[fieldName]
        end)
        if ok and result then
            panel = result
            return panel, "field:" .. tostring(fieldName)
        end
        errors[#errors + 1] = tostring(fieldName) .. "=" .. tostring(result)
    end

    local widgetTree = nil
    pcall(function()
        widgetTree = mapBody.WidgetTree
    end)
    if widgetTree then
        for _, fieldName in ipairs(fieldNames) do
            local panel = nil
            local ok, result = pcall(function()
                if widgetTree.FindWidget then return widgetTree:FindWidget(fieldName) end
                return nil
            end)
            if ok and result then
                panel = result
                return panel, "WidgetTree.FindWidget:" .. tostring(fieldName)
            end
            errors[#errors + 1] = "tree:" .. tostring(fieldName) .. "=" .. tostring(result)
        end
    end

    return nil, "not-found:" .. table.concat(errors, " | ")
end

local function MakeVector2D(x, y)
    return {
        X = tonumber(x) or 0.0,
        Y = tonumber(y) or 0.0
    }
end

local function ConfigureCanvasSlot(slot, x, y, size)
    if not slot then return "no-slot" end

    local details = {}
    local position = MakeVector2D(x, y)
    local desiredSize = MakeVector2D(size, size)
    local alignment = MakeVector2D(0.5, 0.5)

    local attempts = {
        {
            "SetPosition",
            function()
                if slot.SetPosition then return slot:SetPosition(position) end
                return nil
            end
        },
        {
            "Set Position",
            function()
                if slot["Set Position"] then return slot["Set Position"](slot, position) end
                return nil
            end
        },
        {
            "SetSize",
            function()
                if slot.SetSize then return slot:SetSize(desiredSize) end
                return nil
            end
        },
        {
            "Set Size",
            function()
                if slot["Set Size"] then return slot["Set Size"](slot, desiredSize) end
                return nil
            end
        },
        {
            "SetAlignment",
            function()
                if slot.SetAlignment then return slot:SetAlignment(alignment) end
                return nil
            end
        },
        {
            "Set Alignment",
            function()
                if slot["Set Alignment"] then return slot["Set Alignment"](slot, alignment) end
                return nil
            end
        },
        {
            "SetAutoSize",
            function()
                if slot.SetAutoSize then return slot:SetAutoSize(false) end
                return nil
            end
        },
        {
            "SetZOrder",
            function()
                if slot.SetZOrder then return slot:SetZOrder(999) end
                return nil
            end
        }
    }

    for _, attempt in ipairs(attempts) do
        local label = attempt[1]
        local ok, result = pcall(attempt[2])
        details[#details + 1] = tostring(label) .. "=" .. tostring(ok) .. ":" .. tostring(result)
    end

    return table.concat(details, "; ")
end

local function TryAttachWidgetToMapCanvas(mapBody, widget, localX, localY, size, toPriority)
    if not widget then return false, "no-widget" end

    local panel, panelSource = GetMapCanvasLayer(mapBody, toPriority)
    if not panel then return false, "no-panel:" .. tostring(panelSource) end

    pcall(function()
        if panel.SetVisibility then panel:SetVisibility(0) end
    end)
    pcall(function()
        if widget.SetVisibility then widget:SetVisibility(0) end
    end)
    pcall(function()
        if widget.SetRenderOpacity then widget:SetRenderOpacity(1.0) end
    end)
    pcall(function()
        if widget.SetRenderScale then widget:SetRenderScale(MakeVector2D(1.5, 1.5)) end
    end)

    local errors = {}
    local slot = nil
    local attempts = {
        {
            "AddChildToCanvas",
            function()
                return panel:AddChildToCanvas(widget)
            end
        },
        {
            "Add Child To Canvas",
            function()
                return panel["Add Child To Canvas"](panel, widget)
            end
        },
        {
            "AddChild",
            function()
                return panel:AddChild(widget)
            end
        },
        {
            "Add Child",
            function()
                return panel["Add Child"](panel, widget)
            end
        }
    }

    for _, attempt in ipairs(attempts) do
        local label = attempt[1]
        local ok, result = pcall(attempt[2])
        if ok and result then
            slot = result
            local slotDetail = ConfigureCanvasSlot(slot, localX, localY, size or 80.0)
            return true, tostring(label) .. " panel=" .. tostring(panelSource) .. " slot=" .. tostring(result) .. " | " .. tostring(slotDetail)
        end
        errors[#errors + 1] = tostring(label) .. "=" .. tostring(ok) .. ":" .. tostring(result)
    end

    pcall(function()
        slot = widget.Slot
    end)
    if slot then
        local slotDetail = ConfigureCanvasSlot(slot, localX, localY, size or 80.0)
        return true, "slot-existing panel=" .. tostring(panelSource) .. " | " .. tostring(slotDetail) .. " addErrors=" .. table.concat(errors, " | ")
    end

    return false, "panel=" .. tostring(panelSource) .. " add-failed:" .. table.concat(errors, " | ")
end

local function TryAddWidgetToViewport(widget, screenX, screenY, size, zOrder)
    if not widget then return false, "no-widget" end

    local details = {}
    local desiredSize = MakeVector2D(size or 96.0, size or 96.0)
    local position = MakeVector2D(screenX or 960.0, screenY or 540.0)
    local alignment = MakeVector2D(0.5, 0.5)

    pcall(function()
        if widget.SetVisibility then widget:SetVisibility(0) end
    end)
    pcall(function()
        if widget.SetRenderOpacity then widget:SetRenderOpacity(1.0) end
    end)
    pcall(function()
        if widget.SetRenderScale then widget:SetRenderScale(MakeVector2D(2.0, 2.0)) end
    end)

    local addAttempts = {
        {
            "AddToViewport:z",
            function()
                if widget.AddToViewport then return widget:AddToViewport(zOrder or 9999) end
                return nil
            end
        },
        {
            "AddToViewport",
            function()
                if widget.AddToViewport then return widget:AddToViewport() end
                return nil
            end
        },
        {
            "Add To Viewport:z",
            function()
                if widget["Add To Viewport"] then return widget["Add To Viewport"](widget, zOrder or 9999) end
                return nil
            end
        },
        {
            "AddToPlayerScreen:z",
            function()
                if widget.AddToPlayerScreen then return widget:AddToPlayerScreen(zOrder or 9999) end
                return nil
            end
        }
    }

    local added = false
    for _, attempt in ipairs(addAttempts) do
        local label = attempt[1]
        local ok, result = pcall(attempt[2])
        details[#details + 1] = tostring(label) .. "=" .. tostring(ok) .. ":" .. tostring(result)
        if ok then added = true end
    end

    local placeAttempts = {
        {
            "SetPositionInViewport",
            function()
                if widget.SetPositionInViewport then return widget:SetPositionInViewport(position, false) end
                return nil
            end
        },
        {
            "Set Position In Viewport",
            function()
                if widget["Set Position In Viewport"] then return widget["Set Position In Viewport"](widget, position, false) end
                return nil
            end
        },
        {
            "SetDesiredSizeInViewport",
            function()
                if widget.SetDesiredSizeInViewport then return widget:SetDesiredSizeInViewport(desiredSize) end
                return nil
            end
        },
        {
            "Set Desired Size In Viewport",
            function()
                if widget["Set Desired Size In Viewport"] then return widget["Set Desired Size In Viewport"](widget, desiredSize) end
                return nil
            end
        },
        {
            "SetAlignmentInViewport",
            function()
                if widget.SetAlignmentInViewport then return widget:SetAlignmentInViewport(alignment) end
                return nil
            end
        },
        {
            "SetRenderTranslation",
            function()
                if widget.SetRenderTranslation then return widget:SetRenderTranslation(position) end
                return nil
            end
        }
    }

    for _, attempt in ipairs(placeAttempts) do
        local label = attempt[1]
        local ok, result = pcall(attempt[2])
        details[#details + 1] = tostring(label) .. "=" .. tostring(ok) .. ":" .. tostring(result)
    end

    return added, table.concat(details, "; ")
end

local function MakeGuidCandidate(seed)
    seed = seed or os.time()
    return {
        A = 0x50414C52,
        B = seed,
        C = math.floor(os.clock() * 1000000),
        D = 0x4D415031
    }
end

local function TryCallAddCustomIcon(mapBase, locationId, markerData)
    local ufunc = nil
    pcall(function()
        ufunc = mapBase["AddCustomIcon"]
    end)
    if not IsValidObject(ufunc) then
        pcall(function()
            ufunc = mapBase["Add Custom Icon"]
        end)
    end

    local errors = {}
    local attempts = {
        {
            "Direct:AddCustomIcon",
            function()
                return mapBase:AddCustomIcon(locationId, markerData)
            end
        },
        {
            "Direct:spaced",
            function()
                return mapBase["AddCustomIcon"](mapBase, locationId, markerData)
            end
        },
        {
            "CallFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return mapBase:CallFunction(ufunc, locationId, markerData)
            end
        },
        {
            "UFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return ufunc(mapBase, locationId, markerData)
            end
        }
    }

    for _, attempt in ipairs(attempts) do
        local label = attempt[1]
        local ok, result = pcall(attempt[2])
        if ok then
            return true, label .. " result=" .. tostring(result)
        end
        errors[#errors + 1] = label .. "=" .. tostring(result)
    end

    return false, "call-error:" .. table.concat(errors, " | ")
end

local function TryCallAddTempMarker(mapBase, worldLocation)
    local ufunc = nil
    pcall(function()
        ufunc = mapBase["AddTempMarker"]
    end)
    if not IsValidObject(ufunc) then
        pcall(function()
            ufunc = mapBase["Add Temp Marker"]
        end)
    end

    local errors = {}
    local attempts = {
        {
            "Direct:AddTempMarker",
            function()
                return mapBase:AddTempMarker(worldLocation)
            end
        },
        {
            "Direct:spaced",
            function()
                return mapBase["AddTempMarker"](mapBase, worldLocation)
            end
        },
        {
            "CallFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return mapBase:CallFunction(ufunc, worldLocation)
            end
        },
        {
            "UFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return ufunc(mapBase, worldLocation)
            end
        }
    }

    for _, attempt in ipairs(attempts) do
        local label = attempt[1]
        local ok, result = pcall(attempt[2])
        if ok then
            return true, label .. " result=" .. tostring(result)
        end
        errors[#errors + 1] = label .. "=" .. tostring(result)
    end

    return false, "call-error:" .. table.concat(errors, " | ")
end

local function TryCallChangeFilter(mapBase, locationType, isEnable)
    if not IsValidObject(mapBase) then return false, "no-map-base" end

    local ufunc = nil
    pcall(function()
        ufunc = mapBase["ChangeFilter"]
    end)
    if not IsValidObject(ufunc) then
        pcall(function()
            ufunc = mapBase["Change Filter"]
        end)
    end

    local useLocationType = locationType or "EPalLocationType::CustomMarker"
    local useEnable = isEnable == true
    local attempts = {
        {
            "Direct:ChangeFilter",
            function()
                return mapBase:ChangeFilter(useLocationType, useEnable)
            end
        },
        {
            "Direct:spaced",
            function()
                return mapBase["ChangeFilter"](mapBase, useLocationType, useEnable)
            end
        },
        {
            "CallFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return mapBase:CallFunction(ufunc, useLocationType, useEnable)
            end
        }
    }

    local errors = {}
    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt[2])
        if ok then return true, tostring(attempt[1]) .. " result=" .. tostring(result) end
        errors[#errors + 1] = tostring(attempt[1]) .. "=" .. tostring(result)
    end

    return false, table.concat(errors, " | ")
end

function MapController.SetNativeMapFilterVisibility(filterName, locationType, isVisible)
    if not filterName or filterName == "" then return false, "no-filter-name" end

    local visible = isVisible == true
    OverlayNativeFilterState[filterName] = visible

    local mapBase = MapController.FindLiveMapBase()
    local ok, detail = TryCallChangeFilter(mapBase, locationType, visible)
    AppendOverlayMarkersLog("Native map filter name=" .. tostring(filterName)
        .. " locationType=" .. tostring(locationType)
        .. " visible=" .. tostring(visible)
        .. " ok=" .. tostring(ok)
        .. " detail=" .. tostring(detail))

    return ok, detail
end

function MapController.ToggleNativeMapFilterVisibility(filterName, locationType)
    local visible = not IsNativeFilterRuntimeVisible(filterName)
    local ok, detail = MapController.SetNativeMapFilterVisibility(filterName, locationType, visible)
    print(string.format("[+] [NATIVE_MAP_FILTER] %s=%s ok=%s detail=%s",
        tostring(filterName),
        visible and "ON" or "OFF",
        tostring(ok),
        tostring(detail)))
    return visible, ok, detail
end

local function DescribeVectorLike(value)
    if value == nil then return "nil" end

    local unwrapped = UnwrapParam(value)
    if unwrapped == nil then return "nil" end

    local x, y, z = nil, nil, nil
    pcall(function()
        x = unwrapped.X
        y = unwrapped.Y
        z = unwrapped.Z
    end)
    if x ~= nil or y ~= nil or z ~= nil then
        return string.format("(%.1f, %.1f, %.1f)", tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0)
    end

    return tostring(unwrapped)
end

local function DescribeCustomMarkerData(icon)
    if not IsValidObject(icon) then return "markerData=invalid-icon" end

    local markerData = nil
    pcall(function()
        markerData = icon.MarkerSaveData
    end)

    if markerData == nil then return "markerData=nil" end

    local iconLocation = nil
    local iconType = nil
    pcall(function()
        iconLocation = markerData.IconLocation
        iconType = markerData.IconType
    end)

    return "markerData.loc=" .. DescribeVectorLike(iconLocation) .. " markerData.iconType=" .. tostring(iconType)
end

local function DescribeWidgetSlot(widget)
    if not IsValidObject(widget) then return "slot=invalid-widget" end

    local parts = {}
    local parent = nil
    local slot = nil
    local visibility = nil
    local opacity = nil

    pcall(function()
        if widget.GetParent then parent = widget:GetParent() end
    end)
    pcall(function()
        slot = widget.Slot
    end)
    pcall(function()
        if widget.GetVisibility then visibility = widget:GetVisibility() end
    end)
    pcall(function()
        if widget.GetRenderOpacity then opacity = widget:GetRenderOpacity() end
    end)

    parts[#parts + 1] = "parent=" .. (IsValidObject(parent) and GetObjectName(parent) or tostring(parent))
    parts[#parts + 1] = "slot=" .. (IsValidObject(slot) and GetObjectName(slot) or tostring(slot))
    parts[#parts + 1] = "visibility=" .. tostring(visibility)
    parts[#parts + 1] = "opacity=" .. tostring(opacity)

    if IsValidObject(slot) then
        local position, size, zOrder, autoSize = nil, nil, nil, nil
        pcall(function()
            if slot.GetPosition then position = slot:GetPosition() end
        end)
        pcall(function()
            if slot.GetSize then size = slot:GetSize() end
        end)
        pcall(function()
            if slot.GetZOrder then zOrder = slot:GetZOrder() end
        end)
        pcall(function()
            if slot.GetAutoSize then autoSize = slot:GetAutoSize() end
        end)
        parts[#parts + 1] = "slotPos=" .. DescribeVectorLike(position)
        parts[#parts + 1] = "slotSize=" .. DescribeVectorLike(size)
        parts[#parts + 1] = "slotZ=" .. tostring(zOrder)
        parts[#parts + 1] = "slotAuto=" .. tostring(autoSize)
    end

    return table.concat(parts, " ")
end

local function PrepareCustomMapIconForOverlay(icon, markerData)
    if not IsValidObject(icon) then return "prepare=invalid-icon" end

    local details = {}
    local fields = {
        { Name = "IgnoreMask", Value = true },
        { Name = "bEnableHideOnZoom", Value = false },
        { Name = "SetAsCustomMarker", Value = true }
    }

    for _, field in ipairs(fields) do
        local ok, err = pcall(function()
            icon[field.Name] = field.Value
        end)
        details[#details + 1] = tostring(field.Name) .. "=" .. tostring(ok) .. ":" .. tostring(err)
    end

    if markerData ~= nil then
        local ok, err = pcall(function()
            icon.MarkerSaveData = markerData
        end)
        details[#details + 1] = "MarkerSaveDataSet=" .. tostring(ok) .. ":" .. tostring(err)
    end

    details[#details + 1] = "forcedVisible=" .. tostring(ForceIconWidgetVisible(icon))
    return table.concat(details, "; ")
end

local function TryCallUpdateMapIcon(mapBody, icon)
    if not IsValidObject(mapBody) then return false, "no-map-body" end
    if not IsValidObject(icon) then return false, "no-icon" end

    local ufunc = nil
    pcall(function()
        ufunc = mapBody["Update Map Icon"]
    end)

    local attempts = {
        {
            "Direct:Update_Map_Icon",
            function()
                if mapBody.Update_Map_Icon then return mapBody:Update_Map_Icon(icon) end
                error("missing")
            end
        },
        {
            "Direct:spaced",
            function()
                return mapBody["Update Map Icon"](mapBody, icon)
            end
        },
        {
            "CallFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return mapBody:CallFunction(ufunc, icon)
            end
        },
        {
            "UFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return ufunc(mapBody, icon)
            end
        }
    }

    local errors = {}
    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt[2])
        if ok then return true, tostring(attempt[1]) .. " result=" .. tostring(result) end
        errors[#errors + 1] = tostring(attempt[1]) .. "=" .. tostring(result)
    end

    return false, table.concat(errors, " | ")
end

local function TryCallUpdateIconVisibility(mapBody, icon)
    if not IsValidObject(mapBody) then return false, "no-map-body" end
    if not IsValidObject(icon) then return false, "no-icon" end

    local ufunc = nil
    pcall(function()
        ufunc = mapBody["Update Icon Visibility"]
    end)

    local visibleOut = { Visible = true }
    local attempts = {
        {
            "Direct:Update_Icon_Visibility-bool",
            function()
                if mapBody.Update_Icon_Visibility then return mapBody:Update_Icon_Visibility(icon, true) end
                error("missing")
            end
        },
        {
            "Direct:spaced-bool",
            function()
                return mapBody["Update Icon Visibility"](mapBody, icon, true)
            end
        },
        {
            "Direct:spaced-out",
            function()
                return mapBody["Update Icon Visibility"](mapBody, icon, visibleOut)
            end
        },
        {
            "CallFunction-bool",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return mapBody:CallFunction(ufunc, icon, true)
            end
        },
        {
            "CallFunction-out",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return mapBody:CallFunction(ufunc, icon, visibleOut)
            end
        }
    }

    local errors = {}
    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt[2])
        if ok then
            return true, tostring(attempt[1]) .. " result=" .. tostring(result) .. " out=" .. DescribeValue(visibleOut)
        end
        errors[#errors + 1] = tostring(attempt[1]) .. "=" .. tostring(result)
    end

    return false, table.concat(errors, " | ")
end

local function TryCallUpdateMapIcons(mapBody)
    if not IsValidObject(mapBody) then return false, "no-map-body" end

    local ufunc = nil
    pcall(function()
        ufunc = mapBody["Update Map Icons"]
    end)

    local attempts = {
        {
            "Direct:Update_Map_Icons",
            function()
                if mapBody.Update_Map_Icons then return mapBody:Update_Map_Icons() end
                error("missing")
            end
        },
        {
            "Direct:spaced",
            function()
                return mapBody["Update Map Icons"](mapBody)
            end
        },
        {
            "CallFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return mapBody:CallFunction(ufunc)
            end
        },
        {
            "UFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return ufunc(mapBody)
            end
        }
    }

    local errors = {}
    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt[2])
        if ok then return true, tostring(attempt[1]) .. " result=" .. tostring(result) end
        errors[#errors + 1] = tostring(attempt[1]) .. "=" .. tostring(result)
    end

    return false, table.concat(errors, " | ")
end

local function MakeCustomMarkerSaveData(worldLocation, iconType)
    return {
        IconLocation = worldLocation,
        IconType = tonumber(iconType) or 0
    }
end

local function FindLocationManager()
    local classNames = {
        "BP_PalLocationManager_C",
        "PalLocationManager"
    }

    for _, className in ipairs(classNames) do
        local obj = nil
        pcall(function()
            obj = FindFirstOf(className)
        end)
        if IsValidObject(obj) then return obj, className end
    end

    return nil, "not-found"
end

local function TryCallAddLocalCustomMarker(locationManager, worldLocation, iconIndex)
    local ufunc = nil
    pcall(function()
        ufunc = locationManager["AddLocalCustomMarker"]
    end)
    if not IsValidObject(ufunc) then
        pcall(function()
            ufunc = locationManager["Add Local Custom Marker"]
        end)
    end

    local errors = {}
    local attempts = {
        {
            "Direct:AddLocalCustomMarker",
            function()
                return locationManager:AddLocalCustomMarker(worldLocation, iconIndex)
            end
        },
        {
            "Direct:spaced",
            function()
                return locationManager["AddLocalCustomMarker"](locationManager, worldLocation, iconIndex)
            end
        },
        {
            "CallFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return locationManager:CallFunction(ufunc, worldLocation, iconIndex)
            end
        },
        {
            "UFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return ufunc(locationManager, worldLocation, iconIndex)
            end
        }
    }

    for _, attempt in ipairs(attempts) do
        local label = attempt[1]
        local ok, result = pcall(attempt[2])
        if ok then
            return true, label .. " result=" .. DescribeValue(result), result
        end
        errors[#errors + 1] = label .. "=" .. tostring(result)
    end

    return false, "call-error:" .. table.concat(errors, " | ")
end

local function EscapeStateValue(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub("|", "\\p")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\n", "\\n")
    return text
end

local function UnescapeStateValue(value)
    local text = tostring(value or "")
    text = text:gsub("\\p", "|")
    text = text:gsub("\\r", "\r")
    text = text:gsub("\\n", "\n")
    text = text:gsub("\\\\", "\\")
    return text
end

local function ExtractStaticMarkerStateKey(line)
    local text = tostring(line or ""):match("^%s*(.-)%s*$")
    if not text or text == "" then return nil end

    local encodedKey = text:match("^v=%d+|key=([^|]+)")
    if encodedKey then return UnescapeStateValue(encodedKey) end

    encodedKey = text:match("^key=([^|]+)")
    if encodedKey then return UnescapeStateValue(encodedKey) end

    return text
end

local function ExtractStaticMarkerStateField(line, fieldName)
    local text = tostring(line or "")
    local value = text:match("|" .. fieldName .. "=([^|]+)")
    if value then return UnescapeStateValue(value) end
    return nil
end

local function MakeStaticMarkerLocationKey(categoryName, worldLocation)
    if not worldLocation then return nil end

    local x = tonumber(worldLocation.X)
    local y = tonumber(worldLocation.Y)
    local z = tonumber(worldLocation.Z)
    if not x or not y then return nil end
    z = z or 0.0

    return string.format(
        "loc:%s:%d:%d:%d",
        tostring(categoryName),
        math.floor(x + 0.5),
        math.floor(y + 0.5),
        math.floor(z + 0.5)
    )
end

local function BuildStaticMarkerStateLine(key, categoryName, marker, worldLocation, iconIndex, detail)
    marker = marker or {}
    worldLocation = worldLocation or {}

    local parts = {
        "v=2",
        "key=" .. EscapeStateValue(key),
        "category=" .. EscapeStateValue(categoryName),
        "id=" .. EscapeStateValue(marker.Id),
        "name=" .. EscapeStateValue(marker.Name),
        "icon=" .. EscapeStateValue(iconIndex),
        "x=" .. EscapeStateValue(worldLocation.X),
        "y=" .. EscapeStateValue(worldLocation.Y),
        "z=" .. EscapeStateValue(worldLocation.Z),
        "source=" .. EscapeStateValue(marker.Source),
        "addedAt=" .. EscapeStateValue(os.date("%Y-%m-%d %H:%M:%S")),
        "detail=" .. EscapeStateValue(detail)
    }

    return table.concat(parts, "|")
end

local function LoadStaticMarkerState()
    if StaticMarkerState then return StaticMarkerState end

    StaticMarkerState = {}

    local file = io.open(GetStaticMarkersStateFilePath(), "r")
    if not file then return StaticMarkerState end

    for line in file:lines() do
        local key = ExtractStaticMarkerStateKey(line)
        if key and key ~= "" then
            StaticMarkerState[key] = true
        end

        local categoryName = ExtractStaticMarkerStateField(line, "category")
        local x = tonumber(ExtractStaticMarkerStateField(line, "x"))
        local y = tonumber(ExtractStaticMarkerStateField(line, "y"))
        local z = tonumber(ExtractStaticMarkerStateField(line, "z")) or 0.0
        if categoryName and x and y then
            local locationKey = MakeStaticMarkerLocationKey(categoryName, { X = x, Y = y, Z = z })
            if locationKey then StaticMarkerState[locationKey] = true end
        end
    end

    file:close()
    return StaticMarkerState
end

local function RememberStaticMarkerKey(key, categoryName, marker, worldLocation, iconIndex, detail)
    if not key or key == "" then return end

    local state = LoadStaticMarkerState()
    if state[key] then return end
    state[key] = true
    local locationKey = MakeStaticMarkerLocationKey(categoryName, worldLocation)
    if locationKey then state[locationKey] = true end

    local file, err = io.open(GetStaticMarkersStateFilePath(), "a")
    if not file then
        AppendStaticMarkersLog("Could not write state file: " .. tostring(err))
        return
    end

    AppendLine(file, BuildStaticMarkerStateLine(key, categoryName, marker, worldLocation, iconIndex, detail))
    file:close()
end

local function MakeStaticMarkerKey(categoryName, marker)
    if marker.Id and marker.Id ~= "" then
        return tostring(categoryName) .. ":" .. tostring(marker.Id)
    end

    return string.format(
        "%s:%s:%d:%d:%d",
        tostring(categoryName),
        tostring(marker.Name or "unnamed"),
        math.floor(tonumber(marker.X) or 0),
        math.floor(tonumber(marker.Y) or 0),
        math.floor(tonumber(marker.Z) or 0)
    )
end

local function MakeLocationFromStaticMarker(anchor, marker)
    if not anchor or not anchor.Instance then return nil end
    if type(marker) ~= "table" then return nil end

    local x = tonumber(marker.X)
    local y = tonumber(marker.Y)
    local z = tonumber(marker.Z)

    if not x or not y then
        local mapX = tonumber(marker.MapX)
        local mapY = tonumber(marker.MapY)
        if mapX and mapY then
            local transform = Config.StaticMarkers and Config.StaticMarkers.MapCoordinateToWorld or {}
            local scale = tonumber(transform.Scale) or 100.0
            local convertedX = mapX
            local convertedY = mapY

            if transform.SwapXY then
                convertedX = mapY
                convertedY = mapX
            end
            if transform.InvertX then convertedX = -convertedX end
            if transform.InvertY then convertedY = -convertedY end

            x = (convertedX * scale) + (tonumber(transform.OffsetX) or 0.0)
            y = (convertedY * scale) + (tonumber(transform.OffsetY) or 0.0)
        end
    end

    if not z then
        z = (Config.StaticMarkers and tonumber(Config.StaticMarkers.DefaultZ)) or 0.0
    end
    if not x or not y then return nil end

    local worldLocation = nil
    pcall(function()
        worldLocation = anchor.Instance:K2_GetActorLocation()
    end)
    if not worldLocation then return nil end

    local ok = pcall(function()
        worldLocation.X = x
        worldLocation.Y = y
        worldLocation.Z = z
    end)
    if not ok then return nil end

    return worldLocation
end

local function GetStaticMarkerIconIndex(categoryName, marker)
    if marker.IconIndex ~= nil then
        return tonumber(marker.IconIndex) or 0
    end

    local defaults = Config.StaticMarkers and Config.StaticMarkers.DefaultIconIndexByCategory or {}
    return tonumber(defaults[categoryName]) or 0
end

local function IsStaticMarkerCategoryEnabled(categoryName)
    local staticConfig = Config.StaticMarkers or {}
    local filters = staticConfig.Filters or {}
    return filters[categoryName] == true
end

local function GetStaticMarkerCategoryLimit(categoryName, fallback)
    local staticConfig = Config.StaticMarkers or {}
    local limits = staticConfig.MaxPerCategoryByCategory or {}
    local limit = limits[categoryName]
    if limit ~= nil then
        return tonumber(limit) or 0
    end

    return tonumber(fallback) or 0
end

function MapController.GenerateStaticMarkers(staticMarkerData, dataState, mapBaseOverride)
    local staticConfig = Config.StaticMarkers or {}
    if not staticConfig.Enabled then return end
    if StaticMarkersGeneratedThisSession then return end
    if type(staticMarkerData) ~= "table" then return end
    if not dataState or not dataState.PlayerAnchor then return end

    local dryRun = staticConfig.DryRun == true
    if not dryRun and staticConfig.AcknowledgeWritesToSave ~= true then
        StaticMarkersGeneratedThisSession = true
        AppendStaticMarkersLog("Skipped: StaticMarkers.Enabled is true but AcknowledgeWritesToSave is not true. This prevents accidental save custom-marker writes.")
        print("[!] [STATIC_MARKERS] Skipped: set StaticMarkers.AcknowledgeWritesToSave=true after backing up or choosing a test save.")
        return
    end

    local mapBase = mapBaseOverride
    if not IsValidObject(mapBase) then
        mapBase = MapController.FindLiveMapBase()
    end
    if not IsValidObject(mapBase) then return end

    local locationManager, locationManagerSource = FindLocationManager()
    if not dryRun and not IsValidObject(locationManager) then
        AppendStaticMarkersLog("Skipped: no location manager available: " .. tostring(locationManagerSource))
        return
    end

    local state = LoadStaticMarkerState()
    local skipGenerated = staticConfig.SkipPreviouslyGenerated ~= false
    local maxPerCategory = tonumber(staticConfig.MaxPerCategory) or 500
    local maxTotal = tonumber(staticConfig.MaxTotal) or 0
    local attempted = 0
    local addedCount = 0
    local skippedCount = 0
    local totalCapped = false

    AppendStaticMarkersLog("Static marker generation started for " .. GetObjectName(mapBase))
    AppendStaticMarkersLog("Options dryRun=" .. tostring(dryRun) .. " maxPerCategory=" .. tostring(maxPerCategory) .. " maxTotal=" .. tostring(maxTotal))
    if IsValidObject(locationManager) then
        AppendStaticMarkersLog("Location manager: " .. GetObjectName(locationManager) .. " source=" .. tostring(locationManagerSource))
    else
        AppendStaticMarkersLog("Location manager: unavailable source=" .. tostring(locationManagerSource))
    end

    for categoryName, markers in pairs(staticMarkerData) do
        if totalCapped then break end
        if type(markers) == "table" then
            if IsStaticMarkerCategoryEnabled(categoryName) then
                local categoryCount = 0
                local categoryLimit = GetStaticMarkerCategoryLimit(categoryName, maxPerCategory)

                for _, marker in ipairs(markers) do
                    if maxTotal > 0 and attempted >= maxTotal then
                        totalCapped = true
                        AppendStaticMarkersLog("Total capped: maxTotal=" .. tostring(maxTotal))
                        break
                    end

                    categoryCount = categoryCount + 1
                    if categoryLimit <= 0 then
                        skippedCount = skippedCount + #markers
                        AppendStaticMarkersLog("Category capped: " .. tostring(categoryName) .. " max=0")
                        break
                    end
                    if categoryCount > categoryLimit then
                        AppendStaticMarkersLog("Category capped: " .. tostring(categoryName) .. " max=" .. tostring(categoryLimit))
                        break
                    end

                    if type(marker) ~= "table" then
                        skippedCount = skippedCount + 1
                        AppendStaticMarkersLog("Skipped invalid marker entry category=" .. tostring(categoryName))
                    else
                        local key = MakeStaticMarkerKey(categoryName, marker)
                        if skipGenerated and state[key] then
                            skippedCount = skippedCount + 1
                        else
                            local worldLocation = MakeLocationFromStaticMarker(dataState.PlayerAnchor, marker)
                            if worldLocation then
                                local locationKey = MakeStaticMarkerLocationKey(categoryName, worldLocation)
                                if skipGenerated and locationKey and state[locationKey] then
                                    skippedCount = skippedCount + 1
                                    AppendStaticMarkersLog("Skipped previously generated location category=" .. tostring(categoryName) .. " key=" .. tostring(key))
                                else
                                    local iconIndex = GetStaticMarkerIconIndex(categoryName, marker)
                                    attempted = attempted + 1

                                    if dryRun then
                                        AppendStaticMarkersLog(string.format(
                                            "DryRun marker category=%s key=%s icon=%d loc=(%.1f, %.1f, %.1f)",
                                            tostring(categoryName),
                                            tostring(key),
                                            iconIndex,
                                            worldLocation.X or 0,
                                            worldLocation.Y or 0,
                                            worldLocation.Z or 0
                                        ))
                                    else
                                        local added, detail = TryCallAddLocalCustomMarker(locationManager, worldLocation, iconIndex)

                                        AppendStaticMarkersLog(string.format(
                                            "Add marker category=%s key=%s icon=%d added=%s detail=%s loc=(%.1f, %.1f, %.1f)",
                                            tostring(categoryName),
                                            tostring(key),
                                            iconIndex,
                                            tostring(added),
                                            tostring(detail),
                                            worldLocation.X or 0,
                                            worldLocation.Y or 0,
                                            worldLocation.Z or 0
                                        ))

                                        if added then
                                            addedCount = addedCount + 1
                                            RememberStaticMarkerKey(key, categoryName, marker, worldLocation, iconIndex, detail)
                                        end
                                    end
                                end
                            else
                                AppendStaticMarkersLog("Skipped invalid location category=" .. tostring(categoryName) .. " key=" .. tostring(key))
                                skippedCount = skippedCount + 1
                            end
                        end
                    end
                end
            else
                skippedCount = skippedCount + #markers
                AppendStaticMarkersLog("Category disabled by filter: " .. tostring(categoryName) .. " count=" .. tostring(#markers))
            end
        end
    end

    if addedCount > 0 then
        pcall(function()
            if mapBase.SetupCustomIcons then mapBase:SetupCustomIcons() end
        end)
    end

    StaticMarkersGeneratedThisSession = true
    AppendStaticMarkersLog(string.format(
        "Static marker generation finished attempted=%d added=%d skipped=%d dryRun=%s",
        attempted,
        addedCount,
        skippedCount,
        tostring(dryRun)
    ))
    print(string.format("[+] [STATIC_MARKERS] attempted=%d added=%d skipped=%d dryRun=%s", attempted, addedCount, skippedCount, tostring(dryRun)))
end

local function IsOverlayMarkerCategoryEnabled(categoryName)
    local overlayConfig = Config.OverlayMarkers or {}
    local filters = overlayConfig.Filters or {}
    return filters[categoryName] == true
end

local function IsOverlayCategoryRuntimeVisible(categoryName)
    if OverlayRuntimeFilterState[categoryName] ~= nil then
        return OverlayRuntimeFilterState[categoryName] == true
    end
    return IsOverlayMarkerCategoryEnabled(categoryName)
end

local function SetOverlayIconRuntimeVisibility(icon, isVisible)
    if not IsValidObject(icon) then return false end

    local visibilityValue = isVisible and 0 or 1
    local ok = pcall(function()
        if icon.SetVisibility then icon:SetVisibility(visibilityValue) end
        if icon.SetRenderOpacity then icon:SetRenderOpacity(isVisible and 1.0 or 0.0) end
    end)
    return ok
end

local function RememberOverlayIcon(categoryName, key, icon)
    if not IsValidObject(icon) then return end

    OverlayIconRecords[#OverlayIconRecords + 1] = {
        Category = categoryName,
        Key = key,
        Icon = icon
    }

    SetOverlayIconRuntimeVisibility(icon, IsOverlayCategoryRuntimeVisible(categoryName))
end

function MapController.CountOverlayLiveIcons()
    local count = 0
    for _, record in ipairs(OverlayIconRecords) do
        if IsValidObject(record.Icon) then count = count + 1 end
    end
    return count
end

function MapController.DestroyOverlayIconsForCategory(categoryName)
    if not categoryName or categoryName == "" then return 0, 0 end

    local destroyed = 0
    local keptRecords = {}
    for _, record in ipairs(OverlayIconRecords) do
        if record.Category == categoryName then
            local icon = record.Icon
            if IsValidObject(icon) then
                local ok = pcall(function()
                    if icon.RemoveFromParent then icon:RemoveFromParent() end
                end)
                if ok then destroyed = destroyed + 1 end
            end
        else
            keptRecords[#keptRecords + 1] = record
        end
    end
    OverlayIconRecords = keptRecords

    local state = OverlayLazyCategoryState[categoryName]
    if state ~= nil then
        state.Paused = true
        state.RunId = nil
        OverlayLazyCategoryState[categoryName] = nil
    end
    if OverlayLazyActiveCategory == categoryName then
        OverlayLazyActiveCategory = nil
    end
    OverlayLazyQueued[categoryName] = nil

    local keptQueue = {}
    local removedQueued = 0
    for _, queuedCategory in ipairs(OverlayLazyQueue) do
        if queuedCategory == categoryName then
            removedQueued = removedQueued + 1
        else
            keptQueue[#keptQueue + 1] = queuedCategory
        end
    end
    OverlayLazyQueue = keptQueue

    AppendOverlayMarkersLog("Destroyed overlay icons category=" .. tostring(categoryName) .. " destroyed=" .. tostring(destroyed) .. " removedQueued=" .. tostring(removedQueued))
    return destroyed, removedQueued
end

function MapController.PauseActiveOverlayLazyCategory(reason)
    local categoryName = OverlayLazyActiveCategory
    if not categoryName then return false end

    local state = OverlayLazyCategoryState[categoryName]
    if state ~= nil then
        state.Paused = true
        state.RunId = nil
    end
    OverlayLazyActiveCategory = nil
    AppendOverlayMarkersLog("Lazy category paused category=" .. tostring(categoryName) .. " reason=" .. tostring(reason or "unspecified"))
    RefreshOverlayFilterPanelCategory(categoryName)
    return true
end

function MapController.ResetOverlayUiState(reason)
    MapController.OverlayLazyRunSerial = (MapController.OverlayLazyRunSerial or 0) + 1

    for _, state in pairs(OverlayLazyCategoryState) do
        if type(state) == "table" then
            state.Paused = true
            state.RunId = nil
        end
    end

    OverlayIconRecords = {}
    OverlayFilterPanelMapAddresses = {}
    OverlayFilterPanelRows = {}
    OverlayFilterPanelRoot = nil
    OverlayFilterPanelHeader = nil
    OverlayFilterPanelBody = nil
    OverlayFilterPanelWidgetTree = nil
    OverlayFilterPanelContainer = nil
    OverlayFilterPanelPanelConfig = nil
    OverlayFilterPanelExpanded = false
    OverlayFilterPanelProgressText = nil
    OverlayLazyContext = nil
    MapController.NormalPalSelector.MenuExpanded = false
    OverlayLazyCategoryState = {}
    OverlayLazyQueue = {}
    OverlayLazyQueued = {}
    OverlayLazyActiveCategory = nil
    OverlayInjectedMapBodyAddresses = {}

    AppendOverlayMarkersLog("Overlay UI state reset reason=" .. tostring(reason or "unspecified"))
end

function MapController.PrepareForMapToggle(reason)
    local hadState = (#OverlayIconRecords > 0)
        or IsValidObject(OverlayFilterPanelRoot)
        or (type(OverlayFilterPanelHeader) == "table" and IsValidObject(OverlayFilterPanelHeader.Button))
        or type(OverlayLazyContext) == "table"

    if not hadState then return false end

    MapController.OverlayLazyRunSerial = (MapController.OverlayLazyRunSerial or 0) + 1

    local removedIcons = 0
    for _, record in ipairs(OverlayIconRecords) do
        local icon = record.Icon
        if IsValidObject(icon) then
            local ok = pcall(function()
                if icon.SetVisibility then icon:SetVisibility(1) end
                if icon.SetRenderOpacity then icon:SetRenderOpacity(0.0) end
                if icon.RemoveFromParent then icon:RemoveFromParent() end
            end)
            if ok then removedIcons = removedIcons + 1 end
        end
    end

    local removedPanel = false
    if IsValidObject(OverlayFilterPanelRoot) then
        local ok = pcall(function()
            if OverlayFilterPanelRoot.RemoveFromParent then OverlayFilterPanelRoot:RemoveFromParent() end
        end)
        removedPanel = ok == true
    end

    AppendOverlayMarkersLog("Map toggle pre-cleanup reason=" .. tostring(reason or "unspecified")
        .. " removedIcons=" .. tostring(removedIcons)
        .. " removedPanel=" .. tostring(removedPanel))
    MapController.ResetOverlayUiState("after-map-toggle-pre-cleanup")
    return true
end

function MapController.ShouldDestroyOverlayIconsOnHide(overlayConfig, lazyConfig)
    overlayConfig = overlayConfig or Config.OverlayMarkers or {}
    lazyConfig = lazyConfig or overlayConfig.LazyCreate or {}
    local profiles = overlayConfig.LimitProfiles
    if type(profiles) == "table" then
        local activeName = OverlayActiveLimitProfileName or overlayConfig.ActiveLimitProfile
        for _, profile in ipairs(profiles) do
            if type(profile) == "table" and tostring(profile.Name or "") == tostring(activeName or "") then
                if type(profile.LazyCreate) == "table" and profile.LazyCreate.DestroyIconsOnHide ~= nil then
                    return profile.LazyCreate.DestroyIconsOnHide == true
                end
                break
            end
        end
    end
    return lazyConfig.DestroyIconsOnHide == true
end

function MapController.SetOverlayCategoryVisibility(categoryName, isVisible)
    if not categoryName or categoryName == "" then return 0, 0 end

    local visible = isVisible == true
    OverlayRuntimeFilterState[categoryName] = visible

    if visible then
        EnsureOverlayCategoryIconsGenerated(categoryName)
    else
        local overlayConfig = Config.OverlayMarkers or {}
        local lazyConfig = overlayConfig.LazyCreate or {}
        if MapController.ShouldDestroyOverlayIconsOnHide(overlayConfig, lazyConfig) == true then
            MapController.DestroyOverlayIconsForCategory(categoryName)
        end
    end

    local changed = 0
    local stale = 0
    for _, record in ipairs(OverlayIconRecords) do
        if record.Category == categoryName then
            if SetOverlayIconRuntimeVisibility(record.Icon, visible) then
                changed = changed + 1
            else
                stale = stale + 1
            end
        end
    end

    AppendOverlayMarkersLog("Runtime filter category=" .. tostring(categoryName) .. " visible=" .. tostring(visible) .. " changed=" .. tostring(changed) .. " stale=" .. tostring(stale))
    RefreshOverlayFilterPanelCategory(categoryName)
    return changed, stale
end

function MapController.ToggleOverlayCategoryVisibility(categoryName)
    local visible = not IsOverlayCategoryRuntimeVisible(categoryName)
    local changed, stale = MapController.SetOverlayCategoryVisibility(categoryName, visible)
    print(string.format("[+] [OVERLAY_FILTER] %s=%s changed=%d stale=%d", tostring(categoryName), visible and "ON" or "OFF", changed or 0, stale or 0))
    return visible, changed, stale
end

function MapController.GetMarkerPrimaryPalId(marker)
    if type(marker) ~= "table" then return nil end
    if type(marker.Pals) == "table" and marker.Pals[1] ~= nil and tostring(marker.Pals[1]) ~= "" then
        return MapController.NormalizePalId(marker.Pals[1])
    end
    if marker.PalId ~= nil and tostring(marker.PalId) ~= "" then return MapController.NormalizePalId(marker.PalId) end
    if marker.Name ~= nil and tostring(marker.Name) ~= "" then return MapController.NormalizePalId(marker.Name) end
    return nil
end

function MapController.NormalizePalId(value)
    if value == nil then return nil end
    local palId = tostring(value)
    if palId == "" then return nil end
    palId = palId:gsub("^BOSS_", "")
    palId = palId:gsub("^GYM_", "")
    palId = palId:gsub("^RAID_", "")
    palId = palId:gsub("^Quest_[^_]+_", "")
    palId = palId:gsub("_Tower$", "")
    palId = palId:gsub("_Oilrig$", "")
    palId = palId:gsub("_Raid$", "")
    if palId == "" then return nil end
    return palId
end

function MapController.FormatNormalPalDisplayName(entry)
    if type(entry) ~= "table" then return "None" end
    local dexKey = tostring(entry.DexKey or "")
    if dexKey == "" then
        local dexNo = tonumber(entry.DexNo) or 0
        if dexNo > 0 and dexNo < 999999 then
            dexKey = string.format("%03d%s", dexNo, tostring(entry.DexSuffix or ""))
        end
    end
    local id = tostring(entry.Id or "")
    local localizedName = tostring(entry.LocalizedName or "")
    if localizedName ~= "" then
        if dexKey ~= "" then return "No." .. dexKey .. " " .. localizedName end
        return localizedName
    end
    if dexKey ~= "" then return "No." .. dexKey .. " " .. id end
    return id
end

function MapController.GetPalDistributionEntry(staticMarkerData, palId)
    if type(staticMarkerData) ~= "table" or not palId then return nil end
    local distributions = staticMarkerData.PalDistributions
    if type(distributions) ~= "table" then return nil end
    return distributions[palId]
end

function MapController.GetNormalPalEntrySourceCount(entry)
    if type(entry) ~= "table" then return 0 end
    local distributionCount = tonumber(entry.DistributionPointCount or entry.PaldexLocationCount)
    if distributionCount and distributionCount > 0 then return distributionCount end
    return tonumber(entry.SpawnPointCount or entry.Count) or 0
end

function MapController.GetSelectedNormalPalSourceCount(staticMarkerData)
    local entry = MapController.GetSelectedNormalPalEntry(staticMarkerData)
    return MapController.GetNormalPalEntrySourceCount(entry)
end

function MapController.BuildNormalPalDistributionMarkers(entry, distribution, maxCount, dataState)
    if type(entry) ~= "table" or type(distribution) ~= "table" then return {} end
    local encoded = tostring(distribution.EncodedPoints or "")
    if encoded == "" then return {} end

    local limit = math.floor(tonumber(maxCount) or 0)
    local shouldSort = limit > 0
        and dataState
        and dataState.PlayerAnchor
        and dataState.PlayerAnchor.Instance
        and tonumber(distribution.PointCount) ~= nil
        and tonumber(distribution.PointCount) > limit
    local playerLocation = nil
    if shouldSort then
        pcall(function()
            playerLocation = dataState.PlayerAnchor.Instance:K2_GetActorLocation()
        end)
        if not playerLocation then shouldSort = false end
    end

    local result = {}
    local sortable = {}
    local palId = tostring(entry.Id or "")
    local iconPath = tostring(entry.IconPath or "")
    local index = 0
    for token in string.gmatch(encoded, "([^;]+)") do
        local x, y, z = token:match("^%s*([^,]+),([^,]+),([^,]+)%s*$")
        if x and y and z then
            index = index + 1
            local marker = {
                Id = "paldex_distribution_" .. palId .. "_" .. tostring(index),
                Name = palId,
                PalId = palId,
                Pals = { palId },
                IconPath = iconPath,
                X = tonumber(x) or 0,
                Y = tonumber(y) or 0,
                Z = tonumber(z) or 0,
                Source = "FModel:DT_PaldexDistributionData"
            }
            if shouldSort then
                local dx = (marker.X or 0.0) - (tonumber(playerLocation.X) or 0.0)
                local dy = (marker.Y or 0.0) - (tonumber(playerLocation.Y) or 0.0)
                local dz = (marker.Z or 0.0) - (tonumber(playerLocation.Z) or 0.0)
                sortable[#sortable + 1] = {
                    Marker = marker,
                    DistanceSq = dx * dx + dy * dy + dz * dz
                }
            else
                result[#result + 1] = marker
                if limit > 0 and #result >= limit then break end
            end
        end
    end

    if shouldSort then
        table.sort(sortable, function(a, b)
            if a.DistanceSq == b.DistanceSq then
                return MakeStaticMarkerKey("", a.Marker) < MakeStaticMarkerKey("", b.Marker)
            end
            return a.DistanceSq < b.DistanceSq
        end)
        for sortedIndex, sorted in ipairs(sortable) do
            if limit > 0 and sortedIndex > limit then break end
            result[#result + 1] = sorted.Marker
        end
    end

    return result
end

function MapController.GetNormalPalIndex(staticMarkerData)
    if type(staticMarkerData) ~= "table" then return {} end
    local source = staticMarkerData.NormalPal
    local catalog = staticMarkerData.PalCatalog
    local distributions = staticMarkerData.PalDistributions
    if type(source) ~= "table" and type(catalog) ~= "table" and type(distributions) ~= "table" then return {} end
    if MapController.NormalPalSelector.IndexCache ~= nil
        and MapController.NormalPalSelector.IndexCacheSource == source
        and MapController.NormalPalSelector.IndexCacheCatalog == catalog
        and MapController.NormalPalSelector.IndexCacheDistributions == distributions then
        return MapController.NormalPalSelector.IndexCache
    end

    local byId = {}
    if type(source) == "table" then
        for _, marker in ipairs(source) do
            local palId = MapController.GetMarkerPrimaryPalId(marker)
            if palId and palId ~= "" then
                local entry = byId[palId]
                if not entry then
                    entry = {
                        Id = palId,
                        Count = 0,
                        SpawnPointCount = 0,
                        DexNo = 999999,
                        DexSuffix = "",
                        DexKey = "",
                        LocalizedName = "",
                        DisplayName = palId
                    }
                    byId[palId] = entry
                end
                entry.Count = entry.Count + 1
                entry.SpawnPointCount = entry.Count
            end
        end
    end

    if type(catalog) == "table" then
        for _, pal in ipairs(catalog) do
            local palId = MapController.NormalizePalId(pal.Id)
            if palId and palId ~= "" then
                local entry = byId[palId]
                if not entry then
                    entry = { Id = palId, Count = 0, SpawnPointCount = 0 }
                    byId[palId] = entry
                end
                entry.DexNo = tonumber(pal.DexNo) or entry.DexNo or 999999
                entry.DexSuffix = tostring(pal.DexSuffix or "")
                entry.DexKey = tostring(pal.DexKey or "")
                entry.NameTextId = tostring(pal.NameTextId or "")
                entry.LocalizedName = tostring(pal.LocalizedName or "")
                entry.IconPath = tostring(pal.IconPath or "")
                entry.PaldexLocationCount = tonumber(pal.PaldexLocationCount) or 0
                entry.HasPaldexDistribution = pal.HasPaldexDistribution == true
                local distribution = MapController.GetPalDistributionEntry(staticMarkerData, palId)
                if type(distribution) == "table" then
                    entry.DistributionPointCount = tonumber(distribution.PointCount) or entry.PaldexLocationCount or 0
                    entry.HasPaldexDistribution = true
                end
                local spawnCount = tonumber(pal.SpawnPointCount)
                if spawnCount ~= nil then
                    entry.SpawnPointCount = spawnCount
                end
                entry.Count = MapController.GetNormalPalEntrySourceCount(entry)
                entry.DisplayName = MapController.FormatNormalPalDisplayName(entry)
            end
        end
    end

    if type(distributions) == "table" then
        for palId, distribution in pairs(distributions) do
            local normalizedPalId = MapController.NormalizePalId(palId)
            if normalizedPalId and normalizedPalId ~= "" then
                local entry = byId[normalizedPalId]
                if entry then
                    entry.DistributionPointCount = tonumber(distribution.PointCount) or entry.DistributionPointCount or 0
                    entry.HasPaldexDistribution = true
                    entry.Count = MapController.GetNormalPalEntrySourceCount(entry)
                    entry.DisplayName = MapController.FormatNormalPalDisplayName(entry)
                end
            end
        end
    end

    local result = {}
    for _, entry in pairs(byId) do
        entry.Count = MapController.GetNormalPalEntrySourceCount(entry)
        entry.DisplayName = MapController.FormatNormalPalDisplayName(entry)
        result[#result + 1] = entry
    end
    table.sort(result, function(a, b)
        local ad = tonumber(a.DexNo) or 999999
        local bd = tonumber(b.DexNo) or 999999
        if ad ~= bd then return ad < bd end
        local as = tostring(a.DexSuffix or "")
        local bs = tostring(b.DexSuffix or "")
        if as ~= bs then return as < bs end
        return tostring(a.Id or "") < tostring(b.Id or "")
    end)

    MapController.NormalPalSelector.IndexCache = result
    MapController.NormalPalSelector.IndexCacheSource = source
    MapController.NormalPalSelector.IndexCacheCatalog = catalog
    MapController.NormalPalSelector.IndexCacheDistributions = distributions
    if MapController.NormalPalSelector.SelectedIndex < 1 then MapController.NormalPalSelector.SelectedIndex = 1 end
    if #result > 0 and MapController.NormalPalSelector.SelectedIndex > #result then MapController.NormalPalSelector.SelectedIndex = #result end
    return result
end

function MapController.GetSelectedNormalPalEntry(staticMarkerData)
    local index = MapController.GetNormalPalIndex(staticMarkerData)
    if #index <= 0 then return nil end
    if MapController.NormalPalSelector.SelectedIndex < 1 then MapController.NormalPalSelector.SelectedIndex = 1 end
    if MapController.NormalPalSelector.SelectedIndex > #index then MapController.NormalPalSelector.SelectedIndex = #index end
    return index[MapController.NormalPalSelector.SelectedIndex]
end

function MapController.FindNormalPalIndexByDexNo(staticMarkerData, dexNo, direction)
    local index = MapController.GetNormalPalIndex(staticMarkerData)
    if #index <= 0 then return nil end

    local targetDexNo = math.floor(tonumber(dexNo) or 0)
    if targetDexNo <= 0 then targetDexNo = 1 end
    local stepDirection = tonumber(direction) or 1

    local minDexNo = nil
    local maxDexNo = nil
    for _, entry in ipairs(index) do
        local entryDexNo = math.floor(tonumber(entry.DexNo) or 0)
        if entryDexNo > 0 then
            if minDexNo == nil or entryDexNo < minDexNo then minDexNo = entryDexNo end
            if maxDexNo == nil or entryDexNo > maxDexNo then maxDexNo = entryDexNo end
        end
    end
    if minDexNo == nil or maxDexNo == nil then return nil end
    local dexRange = maxDexNo - minDexNo + 1
    while targetDexNo < minDexNo do targetDexNo = targetDexNo + dexRange end
    while targetDexNo > maxDexNo do targetDexNo = targetDexNo - dexRange end

    for scan = 1, dexRange do
        for entryIndex, entry in ipairs(index) do
            if math.floor(tonumber(entry.DexNo) or 0) == targetDexNo then
                return entryIndex
            end
        end
        targetDexNo = targetDexNo + (stepDirection >= 0 and 1 or -1)
        if targetDexNo > maxDexNo then targetDexNo = minDexNo end
        if targetDexNo < minDexNo then targetDexNo = maxDexNo end
    end

    return nil
end

function MapController.GetSelectedNormalPalMarkers(staticMarkerData, maxCount, dataState)
    local entry = MapController.GetSelectedNormalPalEntry(staticMarkerData)
    if type(entry) ~= "table" or not entry.Id then return {} end
    local distribution = MapController.GetPalDistributionEntry(staticMarkerData, entry.Id)
    if type(distribution) == "table" then
        return MapController.BuildNormalPalDistributionMarkers(entry, distribution, maxCount, dataState)
    end
    local source = staticMarkerData and staticMarkerData.NormalPal
    if type(source) ~= "table" then return {} end

    local result = {}
    for _, marker in ipairs(source) do
        if MapController.GetMarkerPrimaryPalId(marker) == entry.Id then
            result[#result + 1] = marker
            if tonumber(maxCount) and tonumber(maxCount) > 0 and #result >= tonumber(maxCount) then break end
        end
    end
    return result
end

function MapController.RefreshSelectedNormalPalOverlay()
    local staticMarkerData = OverlayLazyContext and OverlayLazyContext.StaticMarkerData
    if type(staticMarkerData) == "table" then
        OverlaySourceCategoryCounts[MapController.NormalPalSelectedCategory] = MapController.GetSelectedNormalPalSourceCount(staticMarkerData)
    end
    local oldState = OverlayLazyCategoryState[MapController.NormalPalSelectedCategory]
    if type(oldState) == "table" then
        oldState.Paused = true
        oldState.RunId = nil
    end
    if OverlayLazyActiveCategory == MapController.NormalPalSelectedCategory then
        OverlayLazyActiveCategory = nil
    end
    MapController.OverlayLazyRunSerial = (MapController.OverlayLazyRunSerial or 0) + 1
    MapController.DestroyOverlayIconsForCategory(MapController.NormalPalSelectedCategory)
    OverlayLazyCategoryState[MapController.NormalPalSelectedCategory] = nil
    OverlayLazyQueued[MapController.NormalPalSelectedCategory] = nil
    for index = #OverlayLazyQueue, 1, -1 do
        if OverlayLazyQueue[index] == MapController.NormalPalSelectedCategory then
            table.remove(OverlayLazyQueue, index)
        end
    end
    if IsOverlayCategoryRuntimeVisible(MapController.NormalPalSelectedCategory) then
        EnsureOverlayCategoryIconsGenerated(MapController.NormalPalSelectedCategory)
    end
    RefreshOverlayFilterPanelCategory(nil)
end

function MapController.SelectOverlayNormalPal(delta)
    local staticMarkerData = OverlayLazyContext and OverlayLazyContext.StaticMarkerData
    local index = MapController.GetNormalPalIndex(staticMarkerData)
    if #index <= 0 then
        RefreshOverlayFilterPanelCategory(nil)
        return false, "no-normal-pal-index"
    end

    local step = tonumber(delta) or 0
    MapController.NormalPalSelector.SelectedIndex = MapController.NormalPalSelector.SelectedIndex + step
    if MapController.NormalPalSelector.SelectedIndex < 1 then MapController.NormalPalSelector.SelectedIndex = #index end
    if MapController.NormalPalSelector.SelectedIndex > #index then MapController.NormalPalSelector.SelectedIndex = 1 end

    local selected = index[MapController.NormalPalSelector.SelectedIndex]
    MapController.RefreshSelectedNormalPalOverlay()
    AppendOverlayMarkersLog("NormalPal selector changed index=" .. tostring(MapController.NormalPalSelector.SelectedIndex)
        .. "/" .. tostring(#index)
        .. " id=" .. tostring(selected and selected.Id)
        .. " count=" .. tostring(selected and selected.Count))
    return true, selected and selected.Id or nil
end

function MapController.SelectOverlayNormalPalByDexDelta(delta)
    local staticMarkerData = OverlayLazyContext and OverlayLazyContext.StaticMarkerData
    local selected = MapController.GetSelectedNormalPalEntry(staticMarkerData)
    local currentDexNo = tonumber(selected and selected.DexNo) or 1
    local step = math.floor(tonumber(delta) or 0)
    if step == 0 then
        RefreshOverlayFilterPanelCategory(nil)
        return false, "zero-dex-delta"
    end

    local targetIndex = MapController.FindNormalPalIndexByDexNo(staticMarkerData, currentDexNo + step, step)
    if not targetIndex then
        RefreshOverlayFilterPanelCategory(nil)
        return false, "no-dex-target"
    end

    MapController.NormalPalSelector.SelectedIndex = targetIndex
    local index = MapController.GetNormalPalIndex(staticMarkerData)
    local nextSelected = index[targetIndex]
    MapController.RefreshSelectedNormalPalOverlay()
    AppendOverlayMarkersLog("NormalPal selector dex delta=" .. tostring(step)
        .. " index=" .. tostring(targetIndex)
        .. "/" .. tostring(#index)
        .. " dex=" .. tostring(nextSelected and nextSelected.DexKey)
        .. " id=" .. tostring(nextSelected and nextSelected.Id)
        .. " count=" .. tostring(nextSelected and nextSelected.Count))
    return true, nextSelected and nextSelected.Id or nil
end

function MapController.ToggleOverlayNormalPalMenu()
    MapController.NormalPalSelector.MenuExpanded = not MapController.NormalPalSelector.MenuExpanded
    RefreshOverlayFilterPanelCategory(nil)
    AppendOverlayMarkersLog("NormalPal menu expanded=" .. tostring(MapController.NormalPalSelector.MenuExpanded))
    return MapController.NormalPalSelector.MenuExpanded
end

local function BuildOverlayToggleCategoryList(overlayConfig)
    overlayConfig = overlayConfig or Config.OverlayMarkers or {}
    local result = {}
    local touched = {}
    local limits = overlayConfig.MaxPerCategoryByCategory or {}

    local function addCategory(categoryName)
        if not categoryName or categoryName == "" then return end
        if categoryName == "NormalPal" then return end
        if tonumber(limits[categoryName]) == 0 then return end
        if touched[categoryName] then return end
        touched[categoryName] = true
        result[#result + 1] = categoryName
    end

    for _, spec in ipairs(((overlayConfig.FilterPanel or {}).Categories) or {}) do
        addCategory(spec.Category)
    end

    for _, categoryName in ipairs(overlayConfig.CategoryOrder or {}) do
        addCategory(categoryName)
    end

    for _, hotkeySpec in ipairs((overlayConfig.RuntimeFilters and overlayConfig.RuntimeFilters.Hotkeys) or {}) do
        local categories = hotkeySpec.Categories or { hotkeySpec.Category }
        for _, categoryName in ipairs(categories) do
            addCategory(categoryName)
        end
    end

    for _, record in ipairs(OverlayIconRecords) do
        addCategory(record.Category)
    end

    return result
end

function MapController.GetOverlayLimitProfiles(overlayConfig)
    overlayConfig = overlayConfig or Config.OverlayMarkers or {}
    local profiles = overlayConfig.LimitProfiles
    if type(profiles) ~= "table" or #profiles <= 0 then return {} end
    return profiles
end

function MapController.GetOverlayActiveLimitProfile(overlayConfig)
    overlayConfig = overlayConfig or Config.OverlayMarkers or {}
    local profiles = MapController.GetOverlayLimitProfiles(overlayConfig)
    if #profiles <= 0 then return nil, 0 end

    local activeName = OverlayActiveLimitProfileName or overlayConfig.ActiveLimitProfile
    for index, profile in ipairs(profiles) do
        if type(profile) == "table" and tostring(profile.Name or "") == tostring(activeName or "") then
            return profile, index
        end
    end

    return profiles[1], 1
end

function MapController.GetOverlayActiveLimitProfileLabel(overlayConfig)
    local profile = MapController.GetOverlayActiveLimitProfile(overlayConfig)
    if type(profile) ~= "table" then return "默认" end
    return tostring(profile.Label or profile.Name or "默认")
end

function MapController.CycleOverlayLimitProfile()
    local overlayConfig = Config.OverlayMarkers or {}
    local profiles = MapController.GetOverlayLimitProfiles(overlayConfig)
    if #profiles <= 0 then
        return false, "no-profiles"
    end

    local _, activeIndex = MapController.GetOverlayActiveLimitProfile(overlayConfig)
    local nextIndex = activeIndex + 1
    if nextIndex > #profiles then nextIndex = 1 end
    local nextProfile = profiles[nextIndex]
    if type(nextProfile) ~= "table" then return false, "invalid-profile" end

    OverlayActiveLimitProfileName = tostring(nextProfile.Name or "")
    MapController.OverlayLazyRunSerial = (MapController.OverlayLazyRunSerial or 0) + 1
    OverlayLazyQueue = {}
    OverlayLazyQueued = {}
    OverlayLazyActiveCategory = nil
    OverlayLazyCategoryState = {}
    SetOverlayFilterPanelProgress("PalRadar " .. MapController.GetOverlayActiveLimitProfileLabel(overlayConfig))

    local categoriesToRefresh = BuildOverlayToggleCategoryList(overlayConfig)
    for _, categoryName in ipairs(categoriesToRefresh) do
        if IsOverlayCategoryRuntimeVisible(categoryName) then
            MapController.DestroyOverlayIconsForCategory(categoryName)
        end
    end
    for _, categoryName in ipairs(categoriesToRefresh) do
        if IsOverlayCategoryRuntimeVisible(categoryName) then
            EnsureOverlayCategoryIconsGenerated(categoryName)
        end
    end

    RefreshOverlayFilterPanelCategory(nil)
    AppendOverlayMarkersLog("Limit profile switched name=" .. tostring(OverlayActiveLimitProfileName)
        .. " label=" .. MapController.GetOverlayActiveLimitProfileLabel(overlayConfig))
    return true, OverlayActiveLimitProfileName
end

function MapController.ShowAllOverlayCategories()
    local overlayConfig = Config.OverlayMarkers or {}
    local categoriesToTouch = BuildOverlayToggleCategoryList(overlayConfig)

    for _, categoryName in ipairs(categoriesToTouch) do
        MapController.SetOverlayCategoryVisibility(categoryName, true)
    end

    print("[+] [OVERLAY_FILTER] all configured overlay categories ON count=" .. tostring(#categoriesToTouch))
end

function MapController.ToggleAllOverlayCategoriesVisibility()
    local overlayConfig = Config.OverlayMarkers or {}
    local categoriesToTouch = BuildOverlayToggleCategoryList(overlayConfig)
    local allVisible = true
    for _, categoryName in ipairs(categoriesToTouch) do
        if not IsOverlayCategoryRuntimeVisible(categoryName) then
            allVisible = false
            break
        end
    end

    local nextVisible = not allVisible
    local totalChanged = 0
    local totalStale = 0
    for _, categoryName in ipairs(categoriesToTouch) do
        local changed, stale = MapController.SetOverlayCategoryVisibility(categoryName, nextVisible)
        totalChanged = totalChanged + (changed or 0)
        totalStale = totalStale + (stale or 0)
    end

    print(string.format(
        "[+] [OVERLAY_FILTER] all overlay categories=%s changed=%d stale=%d",
        nextVisible and "ON" or "OFF",
        totalChanged,
        totalStale
    ))

    return nextVisible, totalChanged, totalStale
end

local function GetNativeStaticSetupIconType(categoryName)
    local overlayConfig = Config.OverlayMarkers or {}
    local nativeConfig = overlayConfig.NativeStaticMarkers or {}
    local typeByCategory = nativeConfig.SetupIconTypeByCategory or {}
    return tonumber(typeByCategory[categoryName]) or 19
end

local function GetOverlayCategoryLimit(categoryName, overlayConfig, defaultMax)
    local limit = tonumber(defaultMax) or 0
    local limits = overlayConfig.MaxPerCategoryByCategory or {}
    if limits[categoryName] ~= nil then
        local categoryLimit = tonumber(limits[categoryName])
        if categoryLimit then limit = categoryLimit end
    end

    local profile = MapController.GetOverlayActiveLimitProfile(overlayConfig)
    if type(profile) == "table" then
        local profileLimits = profile.MaxPerCategoryByCategory or {}
        if profileLimits[categoryName] ~= nil then
            local profileCategoryLimit = tonumber(profileLimits[categoryName])
            if profileCategoryLimit then limit = profileCategoryLimit end
        elseif profile.MaxPerCategory ~= nil then
            local profileLimit = tonumber(profile.MaxPerCategory)
            if profileLimit then limit = profileLimit end
        end
    end

    if limit < 0 then return 0 end
    return math.floor(limit)
end

local function BuildOverlayCategoryOrder(staticMarkerData, overlayConfig)
    local result = {}
    local included = {}
    local configuredOrder = overlayConfig.CategoryOrder or {}

    for _, categoryName in ipairs(configuredOrder) do
        if MapController.IsOverlayMarkerCategoryName(categoryName) and staticMarkerData[categoryName] ~= nil and not included[categoryName] then
            result[#result + 1] = categoryName
            included[categoryName] = true
        end
    end

    local remaining = {}
    for categoryName, _ in pairs(staticMarkerData) do
        if MapController.IsOverlayMarkerCategoryName(categoryName) and not included[categoryName] then
            remaining[#remaining + 1] = categoryName
        end
    end
    table.sort(remaining, function(a, b) return tostring(a) < tostring(b) end)

    for _, categoryName in ipairs(remaining) do
        result[#result + 1] = categoryName
    end

    return result
end

local function GetOverlayMarkerPreferenceScore(categoryName, marker)
    if type(marker) ~= "table" then return 0 end

    local score = 0
    local id = tostring(marker.Id or "")
    local source = tostring(marker.Source or "")

    if source:find("FModel", 1, true) then score = score + 100 end
    if id:find("^fmodel_") then score = score + 50 end
    if id:find("^validation_") then score = score - 100 end
    if type(marker.Pals) == "table" and #marker.Pals > 0 then score = score + 25 end
    if categoryName == "Boss" and type(marker.Pals) == "table" and #marker.Pals > 0 then score = score + 25 end

    return score
end

local function MakeOverlayLocationDedupeKey(anchor, marker)
    local location = MakeLocationFromStaticMarker(anchor, marker)
    if not location then return nil end

    local grid = 100.0
    local function snap(value)
        return math.floor(((tonumber(value) or 0.0) / grid) + 0.5)
    end

    return tostring(snap(location.X)) .. ":" .. tostring(snap(location.Y)) .. ":" .. tostring(snap(location.Z))
end

local function DeduplicateOverlayMarkersByLocation(categoryName, markers, dataState)
    if type(markers) ~= "table" then return markers end
    if not dataState or not dataState.PlayerAnchor then return markers end

    local orderedKeys = {}
    local bestByKey = {}
    local removed = 0

    for _, marker in ipairs(markers) do
        local key = MakeOverlayLocationDedupeKey(dataState.PlayerAnchor, marker)
        if not key then
            key = "invalid:" .. tostring(#orderedKeys + 1)
        end

        local current = bestByKey[key]
        local markerScore = GetOverlayMarkerPreferenceScore(categoryName, marker)
        if current == nil then
            orderedKeys[#orderedKeys + 1] = key
            bestByKey[key] = {
                Marker = marker,
                Score = markerScore
            }
        elseif markerScore > current.Score then
            bestByKey[key] = {
                Marker = marker,
                Score = markerScore
            }
            removed = removed + 1
        else
            removed = removed + 1
        end
    end

    if removed <= 0 then return markers end

    local result = {}
    for _, key in ipairs(orderedKeys) do
        local entry = bestByKey[key]
        if entry and entry.Marker then
            result[#result + 1] = entry.Marker
        end
    end

    AppendOverlayMarkersLog("Deduped overlay category=" .. tostring(categoryName) .. " before=" .. tostring(#markers) .. " after=" .. tostring(#result) .. " removed=" .. tostring(removed))
    return result
end

local function GetPlayerWorldLocation(dataState)
    if not dataState or not dataState.PlayerAnchor or not dataState.PlayerAnchor.Instance then return nil end

    local playerLocation = nil
    pcall(function()
        playerLocation = dataState.PlayerAnchor.Instance:K2_GetActorLocation()
    end)
    return playerLocation
end

local function SelectOverlayCategoryMarkers(markers, dataState, maxPerCategory, overlayConfig, nativeStaticConfig)
    if type(markers) ~= "table" then return markers end
    local shouldSort = overlayConfig.SortByDistanceToPlayer == true or nativeStaticConfig.ChooseNearestToPlayer == true
    if not shouldSort then return markers end

    local playerLocation = GetPlayerWorldLocation(dataState)
    if not playerLocation then return markers end

    local sortable = {}
    for _, marker in ipairs(markers) do
        local markerLocation = MakeLocationFromStaticMarker(dataState.PlayerAnchor, marker)
        local distanceSq = 999999999999999.0
        if markerLocation then
            local dx = (tonumber(markerLocation.X) or 0.0) - (tonumber(playerLocation.X) or 0.0)
            local dy = (tonumber(markerLocation.Y) or 0.0) - (tonumber(playerLocation.Y) or 0.0)
            local dz = (tonumber(markerLocation.Z) or 0.0) - (tonumber(playerLocation.Z) or 0.0)
            distanceSq = dx * dx + dy * dy + dz * dz
        end
        sortable[#sortable + 1] = {
            Marker = marker,
            DistanceSq = distanceSq
        }
    end

    table.sort(sortable, function(a, b)
        if a.DistanceSq == b.DistanceSq then
            return MakeStaticMarkerKey("", a.Marker) < MakeStaticMarkerKey("", b.Marker)
        end
        return a.DistanceSq < b.DistanceSq
    end)

    local selected = {}
    local limit = tonumber(maxPerCategory) or 0
    if limit <= 0 then limit = #sortable end
    for index, entry in ipairs(sortable) do
        if index > limit then break end
        selected[#selected + 1] = entry.Marker
    end

    if #selected > 0 then
        AppendOverlayMarkersLog("Selected native static markers count=" .. tostring(#selected) .. " nearestDistanceSq=" .. tostring(sortable[1].DistanceSq))
    end
    return selected
end

local function GetOverlayIconWidgetPath(categoryName)
    local overlayConfig = Config.OverlayMarkers or {}
    local paths = overlayConfig.IconWidgetByCategory or {}
    return paths[categoryName] or paths.Boss or (Config.Assets and Config.Assets.TestBossIconWidget)
end

local function GetRelicSubtype(marker)
    if type(marker) ~= "table" then return nil end
    if marker.RelicSubtype and marker.RelicSubtype ~= "" then return tostring(marker.RelicSubtype) end
    if marker.PlacementType and tostring(marker.PlacementType):match("^BP_LevelObject_Relic_") then
        return tostring(marker.PlacementType)
    end
    return nil
end

local function GetBossPalIconIds(marker)
    if type(marker) ~= "table" then return {} end

    local result = {}
    local seen = {}
    local function addPalId(value)
        if not value or value == "" then return end
        local palId = tostring(value)
        local withoutBossPrefix = palId:gsub("^BOSS_", "")

        local candidates = {
            withoutBossPrefix,
            palId
        }
        for _, candidate in ipairs(candidates) do
            if candidate and candidate ~= "" and not seen[candidate] then
                result[#result + 1] = candidate
                seen[candidate] = true
            end
        end
    end

    if type(marker.Pals) == "table" then
        for _, palId in ipairs(marker.Pals) do
            addPalId(palId)
        end
    end
    addPalId(marker.Name)

    return result
end

local function NormalizeAssetObjectPath(assetPath)
    if not assetPath or assetPath == "" then return nil, nil, nil end

    local objectPath = tostring(assetPath)
    local packagePath = objectPath
    if objectPath:find("%.") then
        packagePath = objectPath:match("^(.-)%.[^%.]+$") or objectPath
    else
        local leaf = objectPath:match("([^/]+)$")
        if leaf and leaf ~= "" then
            objectPath = objectPath .. "." .. leaf
        end
    end

    local leafName = objectPath:match("%.([^%.]+)$") or objectPath:match("([^/]+)$")
    return objectPath, packagePath, leafName
end

local function LoadTextureAsset(texturePath)
    local objectPath, packagePath, leafName = NormalizeAssetObjectPath(texturePath)
    if not objectPath then return nil, "empty-path" end

    pcall(function()
        LoadAsset(packagePath)
    end)
    pcall(function()
        LoadAsset(objectPath)
    end)

    local staticFindCandidates = {
        objectPath,
        "Texture2D " .. objectPath
    }
    for _, candidate in ipairs(staticFindCandidates) do
        local obj = nil
        pcall(function()
            obj = StaticFindObject(candidate)
        end)
        if IsValidObject(obj) then return obj, "StaticFindObject:" .. tostring(candidate) end
    end

    if leafName and leafName ~= "" then
        local found = nil
        pcall(function()
            found = FindObject(nil, leafName, EObjectFlags.RF_NoFlags, EObjectFlags.RF_NoFlags)
        end)
        if IsValidObject(found) then return found, "FindObject:" .. tostring(leafName) end
    end

    return nil, "not-found:" .. tostring(objectPath)
end

local function GetOverlayIconTextureCandidates(categoryName, marker)
    local overlayConfig = Config.OverlayMarkers or {}
    local replacement = overlayConfig.TextureReplacement or {}
    if replacement.Enabled ~= true then return {} end

    local subtype = GetRelicSubtype(marker)
    local bossPalIcons = replacement.BossPalIcons or {}
    local packagedByCategory = replacement.TextureByCategory or {}
    local packagedBySubtype = replacement.TextureByRelicSubtype or {}
    local fallbackByCategory = replacement.GameTextureFallbackByCategory or {}
    local fallbackBySubtype = replacement.GameTextureFallbackByRelicSubtype or {}
    local candidates = {}

    local function add(path, source)
        if path and path ~= "" then
            candidates[#candidates + 1] = { Path = path, Source = source }
        end
    end

    local function addBossPalIcons(basePath, source)
        if categoryName ~= "Boss" and categoryName ~= MapController.NormalPalSelectedCategory then return end
        if bossPalIcons.Enabled == false then return end
        if not basePath or basePath == "" then return end

        for _, palId in ipairs(GetBossPalIconIds(marker)) do
            local textureName = "T_" .. tostring(palId) .. "_icon_normal"
            add(tostring(basePath) .. "/" .. textureName .. "." .. textureName, source .. ":" .. tostring(palId))
        end
    end

    local function addPackaged()
        addBossPalIcons(bossPalIcons.PackagedBasePath, "packaged-boss-pal")
        if subtype then add(packagedBySubtype[subtype], "packaged-subtype") end
        add(packagedByCategory[categoryName], "packaged-category")
    end

    local function addFallback()
        if replacement.FallbackToGameTexturesForTesting ~= true then return end
        addBossPalIcons(bossPalIcons.GameBasePath, "game-fallback-boss-pal")
        if subtype then add(fallbackBySubtype[subtype], "game-fallback-subtype") end
        add(fallbackByCategory[categoryName], "game-fallback-category")
    end

    if replacement.PreferPackagedTextures == true then
        addPackaged()
        addFallback()
    else
        addFallback()
        addPackaged()
    end

    return candidates
end

local function GetOverlayImageFieldCandidates()
    local overlayConfig = Config.OverlayMarkers or {}
    local replacement = overlayConfig.TextureReplacement or {}
    local configured = replacement.ImageFieldCandidates or {}
    if type(configured) == "table" and #configured > 0 then return configured end
    return {
        "Icon",
        "Icon_Base",
        "Icon_BaseShadow",
        "Icon_Oilrig",
        "Image",
        "Image_Icon"
    }
end

local function GetNamedWidgetPart(widget, fieldName)
    if not IsValidObject(widget) then return nil end

    local part = nil
    pcall(function()
        part = widget[fieldName]
    end)
    if IsValidObject(part) then return part, "field:" .. tostring(fieldName) end

    pcall(function()
        if widget.GetWidgetFromName then part = widget:GetWidgetFromName(fieldName) end
    end)
    if IsValidObject(part) then return part, "GetWidgetFromName:" .. tostring(fieldName) end

    local widgetTree = nil
    pcall(function()
        widgetTree = widget.WidgetTree
    end)
    if IsValidObject(widgetTree) then
        pcall(function()
            if widgetTree.FindWidget then part = widgetTree:FindWidget(fieldName) end
        end)
        if IsValidObject(part) then return part, "WidgetTree.FindWidget:" .. tostring(fieldName) end
    end

    return nil, "not-found:" .. tostring(fieldName)
end

local function TrySetBrushFromTexture(imageWidget, texture)
    if not IsValidObject(imageWidget) then return false, "invalid-image" end
    if not IsValidObject(texture) then return false, "invalid-texture" end

    local attempts = {
        {
            "SetBrushFromTexture",
            function()
                return imageWidget:SetBrushFromTexture(texture, true)
            end
        },
        {
            "Set Brush From Texture",
            function()
                return imageWidget["Set Brush From Texture"](imageWidget, texture, true)
            end
        },
        {
            "SetBrushResourceObject",
            function()
                return imageWidget:SetBrushResourceObject(texture)
            end
        }
    }

    local errors = {}
    for _, attempt in ipairs(attempts) do
        local label = attempt[1]
        local ok, result = pcall(attempt[2])
        if ok then return true, label .. " result=" .. tostring(result) end
        errors[#errors + 1] = label .. "=" .. tostring(result)
    end

    return false, table.concat(errors, " | ")
end

local function ApplyOverlayIconTexture(categoryName, marker, widget)
    local textureCandidates = GetOverlayIconTextureCandidates(categoryName, marker)
    if #textureCandidates == 0 then return "textureReplacement=disabled-or-unconfigured" end

    local loadErrors = {}
    for _, textureCandidate in ipairs(textureCandidates) do
        local texture, textureSource = LoadTextureAsset(textureCandidate.Path)
        if IsValidObject(texture) then
            local fieldErrors = {}
            for _, fieldName in ipairs(GetOverlayImageFieldCandidates()) do
                local imageWidget, imageSource = GetNamedWidgetPart(widget, fieldName)
                if IsValidObject(imageWidget) then
                    local applied, applyDetail = TrySetBrushFromTexture(imageWidget, texture)
                    if applied then
                        return "texture=" .. tostring(textureCandidate.Source) ..
                            " path=" .. tostring(textureCandidate.Path) ..
                            " textureSource=" .. tostring(textureSource) ..
                            " image=" .. tostring(imageSource) ..
                            " apply=" .. tostring(applyDetail)
                    end
                    fieldErrors[#fieldErrors + 1] = tostring(imageSource) .. ":" .. tostring(applyDetail)
                else
                    fieldErrors[#fieldErrors + 1] = tostring(imageSource)
                end
            end
            loadErrors[#loadErrors + 1] = tostring(textureCandidate.Source) .. " image-failed={" .. table.concat(fieldErrors, "; ") .. "}"
        else
            loadErrors[#loadErrors + 1] = tostring(textureCandidate.Source) .. " load=" .. tostring(textureSource)
        end
    end

    return "textureReplacement=failed " .. table.concat(loadErrors, " || ")
end

local function MakeFTextValue(text)
    if FText == nil then return nil end

    local ok, value = pcall(function()
        return FText(tostring(text or ""))
    end)
    if ok then return value end
    return nil
end

local function ConstructUmgWidget(classPath, outer)
    if StaticFindObject == nil or StaticConstructObject == nil then
        return nil, "construct-api-unavailable"
    end

    local klass = nil
    pcall(function()
        klass = StaticFindObject(classPath)
    end)
    if not IsValidObject(klass) then
        return nil, "class-not-found:" .. tostring(classPath)
    end

    local created = nil
    local ok, err = pcall(function()
        created = StaticConstructObject(klass, outer, 0, 0, 0, nil, false, false, nil)
    end)
    if ok and IsValidObject(created) then
        return created, "created:" .. tostring(classPath)
    end

    return nil, "construct-failed:" .. tostring(classPath) .. " err=" .. tostring(err)
end

local function GetWidgetTreeRoot(widgetTree)
    if not IsValidObject(widgetTree) then return nil end

    local root = nil
    pcall(function()
        root = widgetTree.RootWidget
    end)
    if IsValidObject(root) then return root end

    pcall(function()
        if widgetTree.GetRootWidget then root = widgetTree:GetRootWidget() end
    end)
    if IsValidObject(root) then return root end

    return nil
end

local function FindWidgetDescendantByClassFragment(root, fragment, visited, depth)
    root = UnwrapParam(root)
    if not IsValidObject(root) then return nil end
    visited = visited or {}
    depth = depth or 0
    if depth > 12 then return nil end

    local identity = GetObjectName(root)
    if visited[identity] then return nil end
    visited[identity] = true

    local className = ""
    pcall(function()
        className = tostring(root:GetClass():GetName())
    end)
    if className:lower():find(tostring(fragment):lower(), 1, true) then
        return root
    end

    local count = nil
    pcall(function()
        if root.GetChildrenCount then count = root:GetChildrenCount() end
    end)
    count = tonumber(count)
    if count and count > 0 and count < 300 then
        for index = 0, count - 1 do
            local child = nil
            pcall(function()
                child = root:GetChildAt(index)
            end)
            local found = FindWidgetDescendantByClassFragment(child, fragment, visited, depth + 1)
            if IsValidObject(found) then return found end
        end
    else
        local content = nil
        pcall(function()
            if root.GetContent then content = root:GetContent() end
        end)
        local found = FindWidgetDescendantByClassFragment(content, fragment, visited, depth + 1)
        if IsValidObject(found) then return found end
    end

    return nil
end

local function GetMapBaseRootCanvas(mapBase)
    if not IsValidObject(mapBase) then return nil, "invalid-map-base" end

    local widgetTree = nil
    pcall(function()
        widgetTree = mapBase.WidgetTree
    end)
    if not IsValidObject(widgetTree) then
        return nil, "no-widget-tree"
    end

    local root = GetWidgetTreeRoot(widgetTree)
    if not IsValidObject(root) then
        return nil, "no-root-widget"
    end

    local className = ""
    pcall(function()
        className = tostring(root:GetClass():GetName())
    end)
    local rootName = GetObjectName(root)
    if className:lower():find("canvaspanel", 1, true) or tostring(rootName):lower():find("canvaspanel", 1, true) then
        return root, "root-canvas class=" .. tostring(className) .. " root=" .. tostring(rootName)
    end

    local canvas = FindWidgetDescendantByClassFragment(root, "CanvasPanel")
    if IsValidObject(canvas) then
        return canvas, "descendant-canvas"
    end

    return nil, "canvas-not-found root=" .. GetObjectName(root)
end

local function AddChildToWidget(parent, child)
    if not IsValidObject(parent) or not IsValidObject(child) then return nil, "invalid-parent-or-child" end

    local attempts = {
        {
            "SetContent",
            function()
                if not parent.SetContent then return false, "missing" end
                return true, parent:SetContent(child)
            end
        },
        {
            "Set Content",
            function()
                if not parent["Set Content"] then return false, "missing" end
                return true, parent["Set Content"](parent, child)
            end
        },
        {
            "AddChild",
            function()
                if not parent.AddChild then return false, "missing" end
                return true, parent:AddChild(child)
            end
        },
        {
            "Add Child",
            function()
                if not parent["Add Child"] then return false, "missing" end
                return true, parent["Add Child"](parent, child)
            end
        }
    }

    local errors = {}
    for _, attempt in ipairs(attempts) do
        local ok, called, result = pcall(attempt[2])
        if ok and called == true then return result, attempt[1] end
        errors[#errors + 1] = tostring(attempt[1]) .. "=" .. tostring(ok) .. ":" .. tostring(called) .. ":" .. tostring(result)
    end

    return nil, table.concat(errors, " | ")
end

local function AddChildToCanvasWidget(canvas, child)
    if not IsValidObject(canvas) or not IsValidObject(child) then return nil, "invalid-canvas-or-child" end

    local attempts = {
        {
            "AddChildToCanvas",
            function()
                if canvas.AddChildToCanvas then return canvas:AddChildToCanvas(child) end
                return nil
            end
        },
        {
            "Add Child To Canvas",
            function()
                if canvas["Add Child To Canvas"] then return canvas["Add Child To Canvas"](canvas, child) end
                return nil
            end
        },
        {
            "AddChild",
            function()
                if canvas.AddChild then return canvas:AddChild(child) end
                return nil
            end
        }
    }

    local errors = {}
    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt[2])
        if ok and result then return result, attempt[1] end
        errors[#errors + 1] = tostring(attempt[1]) .. "=" .. tostring(ok) .. ":" .. tostring(result)
    end

    return nil, table.concat(errors, " | ")
end

local function ConfigureFilterPanelSlot(slot, panelConfig)
    if not IsValidObject(slot) then return "no-slot" end

    local position = panelConfig.Position or {}
    local size = panelConfig.Size or {}
    local useAutoSize = panelConfig.AutoSize ~= false
    local details = {}

    local attempts = {
        {
            "SetPosition",
            function()
                if slot.SetPosition then return slot:SetPosition(MakeVector2D(position.X or 1485.0, position.Y or 150.0)) end
                return nil
            end
        },
        {
            "SetSize",
            function()
                if useAutoSize then return nil end
                if slot.SetSize then return slot:SetSize(MakeVector2D(size.X or 230.0, size.Y or 535.0)) end
                return nil
            end
        },
        {
            "SetAlignment",
            function()
                if slot.SetAlignment then return slot:SetAlignment(MakeVector2D(0.0, 0.0)) end
                return nil
            end
        },
        {
            "SetAutoSize",
            function()
                if slot.SetAutoSize then return slot:SetAutoSize(useAutoSize) end
                return nil
            end
        },
        {
            "SetZOrder",
            function()
                if slot.SetZOrder then return slot:SetZOrder(panelConfig.ZOrder or 10050) end
                return nil
            end
        }
    }

    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt[2])
        details[#details + 1] = tostring(attempt[1]) .. "=" .. tostring(ok) .. ":" .. tostring(result)
    end

    return table.concat(details, "; ")
end

local function SetWidgetBrushColor(widget, color)
    if not IsValidObject(widget) then return false end
    local brushColor = color or { R = 0.02, G = 0.05, B = 0.06, A = 0.78 }

    local ok = pcall(function()
        if widget.SetBrushColor then widget:SetBrushColor(brushColor) end
    end)
    if ok then return true end

    ok = pcall(function()
        widget.BrushColor = brushColor
    end)
    return ok
end

local function ConfigureSizeBox(sizeBox, width, height)
    if not IsValidObject(sizeBox) then return end

    pcall(function()
        sizeBox.WidthOverride = tonumber(width) or 0.0
        sizeBox.HeightOverride = tonumber(height) or 0.0
        sizeBox.bOverride_WidthOverride = true
        sizeBox.bOverride_HeightOverride = true
    end)
end

local function SetFilterPanelText(textWidget, text)
    if not IsValidObject(textWidget) then return false end

    local ftext = MakeFTextValue(text)
    if ftext == nil then return false end

    local ok = pcall(function()
        textWidget:SetText(ftext)
    end)
    return ok
end

local function GetFilterPanelCategorySpecs(panelConfig)
    if type(panelConfig.Categories) == "table" and #panelConfig.Categories > 0 then
        return panelConfig.Categories
    end

    local specs = {}
    for _, categoryName in ipairs((Config.OverlayMarkers and Config.OverlayMarkers.CategoryOrder) or {}) do
        specs[#specs + 1] = { Category = categoryName, Label = categoryName }
    end
    return specs
end

local function GetFilterPanelTextureCandidates(categoryName)
    local overlayConfig = Config.OverlayMarkers or {}
    local replacement = overlayConfig.TextureReplacement or {}
    local packagedByCategory = replacement.TextureByCategory or {}
    local fallbackByCategory = replacement.GameTextureFallbackByCategory or {}
    local candidates = {}

    local function add(path, source)
        if path and path ~= "" then
            candidates[#candidates + 1] = { Path = path, Source = source }
        end
    end

    if replacement.PreferPackagedTextures == true then
        add(packagedByCategory[categoryName], "packaged-category")
        if replacement.FallbackToGameTexturesForTesting == true then
            add(fallbackByCategory[categoryName], "game-fallback-category")
        end
    else
        if replacement.FallbackToGameTexturesForTesting == true then
            add(fallbackByCategory[categoryName], "game-fallback-category")
        end
        add(packagedByCategory[categoryName], "packaged-category")
    end

    return candidates
end

local function ApplyFilterPanelIconTexture(categoryName, imageWidget, iconSize)
    if not IsValidObject(imageWidget) then return "invalid-image" end

    for _, candidate in ipairs(GetFilterPanelTextureCandidates(categoryName)) do
        local texture, textureSource = LoadTextureAsset(candidate.Path)
        if IsValidObject(texture) then
            local ok, detail = TrySetBrushFromTexture(imageWidget, texture)
            if ok then
                pcall(function()
                    imageWidget.Brush.ImageSize = MakeVector2D(iconSize or 18.0, iconSize or 18.0)
                end)
                return tostring(candidate.Source) .. " path=" .. tostring(candidate.Path) .. " source=" .. tostring(textureSource) .. " apply=" .. tostring(detail)
            end
        end
    end

    return "texture-not-found"
end

local function FormatFilterPanelRowText(label, isVisible)
    return "[" .. (isVisible and "开" or "关") .. "] " .. tostring(label or "")
end

local function GetOverlayIconRecordCount(categoryName)
    local count = 0
    for _, record in ipairs(OverlayIconRecords) do
        if record.Category == categoryName and IsValidObject(record.Icon) then
            count = count + 1
        end
    end
    return count
end

local function GetSourceCountForFilterPanelRecord(record)
    if type(record) ~= "table" then return nil end

    if record.CountCategory and record.CountCategory ~= "" then
        return OverlaySourceCategoryCounts[record.CountCategory]
    end

    if type(record.CountCategories) == "table" then
        local total = 0
        local hasCount = false
        for _, categoryName in ipairs(record.CountCategories) do
            local count = OverlaySourceCategoryCounts[categoryName]
            if count ~= nil then
                total = total + count
                hasCount = true
            end
        end
        if hasCount then return total end
    end

    if record.Category then
        return OverlaySourceCategoryCounts[record.Category]
    end

    return nil
end

local function FormatFilterPanelRowTextWithCount(label, isVisible, countText)
    if countText == nil or countText == "" then
        return "[" .. (isVisible and "ON" or "OFF") .. "] " .. tostring(label or "")
    end
    return "[" .. (isVisible and "ON" or "OFF") .. "] " .. tostring(label or "") .. "  " .. tostring(countText)
end

function MapController.IsNormalPalSelectorAction(actionName)
    return actionName == "NormalPalMenu"
        or actionName == "NormalPalPrev"
        or actionName == "NormalPalNext"
        or actionName == "NormalPalToggle"
        or actionName == "NormalPalClear"
        or actionName == "NormalPalDexMinus100"
        or actionName == "NormalPalDexMinus10"
        or actionName == "NormalPalDexMinus1"
        or actionName == "NormalPalDexPlus1"
        or actionName == "NormalPalDexPlus10"
        or actionName == "NormalPalDexPlus100"
end

local function RefreshOverlayFilterPanelRow(record)
    if type(record) ~= "table" then return false end
    local visible = true
    local shownCount = nil
    local sourceCount = GetSourceCountForFilterPanelRecord(record)
    local countText = nil

    if record.Action == "LimitProfile" then
        local overlayConfig = Config.OverlayMarkers or {}
        local label = tostring(record.Label or "档位")
        local profileLabel = MapController.GetOverlayActiveLimitProfileLabel(overlayConfig)
        local liveCount = MapController.CountOverlayLiveIcons()
        local profile = MapController.GetOverlayActiveLimitProfile(overlayConfig)
        local maxLiveIcons = 0
        if type(profile) == "table" then
            maxLiveIcons = math.floor(tonumber(profile.MaxLiveIcons) or 0)
        end
        if maxLiveIcons > 0 then
            SetFilterPanelText(record.Text, label .. "  " .. profileLabel .. "  " .. tostring(liveCount) .. "/" .. tostring(maxLiveIcons))
        else
            SetFilterPanelText(record.Text, label .. "  " .. profileLabel .. "  " .. tostring(liveCount) .. "/全部")
        end
        SetWidgetBrushColor(record.Button, { R = 0.00, G = 0.42, B = 0.43, A = 0.90 })
        pcall(function()
            if record.Button and record.Button.SetRenderOpacity then record.Button:SetRenderOpacity(1.0) end
        end)
        return true
    end

    if MapController.IsNormalPalSelectorAction(record.Action) then
        local isMenu = record.Action == "NormalPalMenu"
        local rowVisible = isMenu or MapController.NormalPalSelector.MenuExpanded == true
        pcall(function()
            if record.Button and record.Button.SetVisibility then record.Button:SetVisibility(rowVisible and 0 or 1) end
        end)
        if not rowVisible then return true end

        local staticMarkerData = OverlayLazyContext and OverlayLazyContext.StaticMarkerData
        local index = MapController.GetNormalPalIndex(staticMarkerData)
        local selected = MapController.GetSelectedNormalPalEntry(staticMarkerData)
        local selectedId = tostring((selected and selected.Id) or "None")
        local selectedCount = tonumber((selected and selected.Count) or 0) or 0
        local selectedLabel = tostring((selected and selected.DisplayName) or selectedId)
        local selectedDexKey = tostring((selected and selected.DexKey) or "")
        if selectedDexKey == "" and selected and tonumber(selected.DexNo) then
            selectedDexKey = string.format("%03d%s", tonumber(selected.DexNo) or 0, tostring(selected.DexSuffix or ""))
        end
        local selectedCompact = selectedLabel
        if selectedDexKey ~= "" then
            selectedCompact = "No." .. selectedDexKey
        end
        local selectedText = selectedCompact .. " " .. tostring(MapController.NormalPalSelector.SelectedIndex) .. "/" .. tostring(#index) .. " 点:" .. tostring(selectedCount)

        if record.Action == "NormalPalMenu" then
            SetFilterPanelText(record.Text, "普通帕鲁 " .. (MapController.NormalPalSelector.MenuExpanded and "v " or "> ") .. selectedText)
            SetWidgetBrushColor(record.Button, { R = 0.00, G = 0.42, B = 0.43, A = 0.90 })
            pcall(function()
                if record.Button and record.Button.SetRenderOpacity then record.Button:SetRenderOpacity(1.0) end
            end)
            return true
        elseif record.Action == "NormalPalPrev" then
            SetFilterPanelText(record.Text, "上一只")
        elseif record.Action == "NormalPalNext" then
            SetFilterPanelText(record.Text, "下一只")
        elseif record.Action == "NormalPalClear" then
            SetFilterPanelText(record.Text, "清除分布")
        elseif record.Action == "NormalPalDexMinus100" or record.Action == "NormalPalDexMinus10"
            or record.Action == "NormalPalDexMinus1" or record.Action == "NormalPalDexPlus1"
            or record.Action == "NormalPalDexPlus10" or record.Action == "NormalPalDexPlus100" then
            SetFilterPanelText(record.Text, tostring(record.Label or "编号"))
        else
            visible = IsOverlayCategoryRuntimeVisible(MapController.NormalPalSelectedCategory)
            shownCount = visible and GetOverlayIconRecordCount(MapController.NormalPalSelectedCategory) or 0
            sourceCount = OverlaySourceCategoryCounts[MapController.NormalPalSelectedCategory] or selectedCount
            if shownCount ~= nil and sourceCount ~= nil and sourceCount ~= shownCount then
                countText = tostring(shownCount) .. "/" .. tostring(sourceCount)
            elseif shownCount ~= nil then
                countText = tostring(shownCount)
            elseif sourceCount ~= nil then
                countText = tostring(sourceCount)
            end
            local toggleLabel = "显示分布"
            if selectedDexKey ~= "" then
                toggleLabel = toggleLabel .. " No." .. selectedDexKey
            end
            SetFilterPanelText(record.Text, FormatFilterPanelRowTextWithCount(toggleLabel, visible, countText))
        end

        local opacity = visible and 1.0 or 0.35
        pcall(function()
            if record.Button and record.Button.SetRenderOpacity then record.Button:SetRenderOpacity(opacity) end
        end)
        SetWidgetBrushColor(record.Button, visible
            and { R = 0.02, G = 0.09, B = 0.10, A = 0.76 }
            or { R = 0.03, G = 0.03, B = 0.03, A = 0.58 })
        return true
    end

    if record.NativeFilter then
        visible = IsNativeFilterRuntimeVisible(record.NativeFilter)
    else
        visible = IsOverlayCategoryRuntimeVisible(record.Category)
        shownCount = visible and GetOverlayIconRecordCount(record.Category) or 0
    end

    if shownCount ~= nil and sourceCount ~= nil and sourceCount ~= shownCount then
        countText = tostring(shownCount) .. "/" .. tostring(sourceCount)
    elseif shownCount ~= nil then
        countText = tostring(shownCount)
    elseif sourceCount ~= nil then
        countText = tostring(sourceCount)
    end

    SetFilterPanelText(record.Text, FormatFilterPanelRowTextWithCount(record.Label, visible, countText))

    local opacity = visible and 1.0 or 0.35
    if shownCount ~= nil and shownCount <= 0 and (sourceCount == nil or sourceCount <= 0) then
        opacity = visible and 0.55 or 0.25
    end
    pcall(function()
        if record.Button and record.Button.SetRenderOpacity then record.Button:SetRenderOpacity(opacity) end
    end)
    SetWidgetBrushColor(record.Button, visible
        and { R = 0.02, G = 0.09, B = 0.10, A = 0.76 }
        or { R = 0.03, G = 0.03, B = 0.03, A = 0.58 })
    return true
end

RefreshOverlayFilterPanelCategory = function(categoryName)
    for _, record in ipairs(OverlayFilterPanelRows) do
        if categoryName == nil or record.Category == categoryName or record.NativeFilter == categoryName then
            RefreshOverlayFilterPanelRow(record)
        end
    end
end

local function RefreshOverlayFilterPanelHeaderProgress()
    if type(OverlayFilterPanelHeader) ~= "table" or not IsValidObject(OverlayFilterPanelHeader.Text) then return false end
    if OverlayFilterPanelProgressText == nil or OverlayFilterPanelProgressText == "" then return false end
    return SetFilterPanelText(OverlayFilterPanelHeader.Text, OverlayFilterPanelProgressText)
end

SetOverlayFilterPanelProgress = function(text)
    OverlayFilterPanelProgressText = text
    if OverlayFilterPanelProgressText ~= nil and OverlayFilterPanelProgressText ~= "" then
        RefreshOverlayFilterPanelHeaderProgress()
    elseif type(OverlayFilterPanelHeader) == "table" and IsValidObject(OverlayFilterPanelHeader.Text) then
        SetFilterPanelText(OverlayFilterPanelHeader.Text, OverlayFilterPanelExpanded and "PalRadar Filter v" or "PalRadar Filter >")
    end
end

local function SetOverlayFilterPanelExpanded(expanded)
    OverlayFilterPanelExpanded = expanded == true
    if IsValidObject(OverlayFilterPanelBody) then
        pcall(function()
            OverlayFilterPanelBody:SetVisibility(OverlayFilterPanelExpanded and 0 or 1)
        end)
    end
    if type(OverlayFilterPanelHeader) == "table" and IsValidObject(OverlayFilterPanelHeader.Text) then
        SetFilterPanelText(OverlayFilterPanelHeader.Text, OverlayFilterPanelExpanded and "PalRadar 筛选 v" or "PalRadar 筛选 >")
    end
end

local SetOverlayFilterPanelExpandedRaw = SetOverlayFilterPanelExpanded
SetOverlayFilterPanelExpanded = function(expanded)
    SetOverlayFilterPanelExpandedRaw(expanded)
    SetOverlayFilterPanelProgress(OverlayFilterPanelProgressText)
end

local function GetFilterPanelColumnCount(panelConfig)
    local columnCount = math.floor(tonumber(panelConfig.ColumnCount) or 1)
    if columnCount < 1 then columnCount = 1 end
    if columnCount > 3 then columnCount = 3 end
    return columnCount
end

local function GetFilterPanelColumnWidth(panelConfig)
    local columnCount = GetFilterPanelColumnCount(panelConfig)
    local configuredWidth = tonumber(panelConfig.ColumnWidth)
    if configuredWidth and configuredWidth > 0 then return configuredWidth end

    local panelWidth = tonumber(panelConfig.PanelWidth) or 205.0
    local gap = tonumber(panelConfig.ColumnGap) or 4.0
    return math.max(120.0, (panelWidth - (gap * (columnCount - 1))) / columnCount)
end

local function GetFilterPanelColumnIndex(spec, specIndex, panelConfig)
    local columnCount = GetFilterPanelColumnCount(panelConfig)
    if columnCount <= 1 then return 1 end

    local configuredColumn = math.floor(tonumber(spec and spec.Column) or 0)
    if configuredColumn >= 1 and configuredColumn <= columnCount then
        return configuredColumn
    end

    return ((specIndex - 1) % columnCount) + 1
end

local function CreateFilterPanelRow(widgetTree, spec, panelConfig)
    local categoryName = spec.Category
    local nativeFilterName = spec.NativeFilter
    local actionName = spec.Action
    if (not categoryName or categoryName == "") and (not nativeFilterName or nativeFilterName == "") and (not actionName or actionName == "") then
        return nil, "no-category"
    end

    local rowHeight = tonumber(panelConfig.RowHeight) or 28.0
    local iconSize = tonumber(panelConfig.IconSize) or 18.0
    local fontSize = tonumber(panelConfig.FontSize) or 13
    local textureCategoryName = spec.TextureCategory or categoryName or nativeFilterName or "Debug"

    local button, buttonDetail = ConstructUmgWidget("/Script/UMG.Border", widgetTree)
    local rowBox, rowDetail = ConstructUmgWidget("/Script/UMG.HorizontalBox", widgetTree)
    local iconBox, iconBoxDetail = ConstructUmgWidget("/Script/UMG.SizeBox", widgetTree)
    local image, imageDetail = ConstructUmgWidget("/Script/UMG.Image", widgetTree)
    local text, textDetail = ConstructUmgWidget("/Script/UMG.TextBlock", widgetTree)

    if not IsValidObject(button) or not IsValidObject(rowBox) or not IsValidObject(iconBox)
        or not IsValidObject(image) or not IsValidObject(text) then
        return nil, "construct row failed button=" .. tostring(buttonDetail)
            .. " row=" .. tostring(rowDetail)
            .. " iconBox=" .. tostring(iconBoxDetail)
            .. " image=" .. tostring(imageDetail)
            .. " text=" .. tostring(textDetail)
    end

    pcall(function() button:SetVisibility(0) end)
    pcall(function() rowBox:SetVisibility(4) end)
    pcall(function() iconBox:SetVisibility(4) end)
    pcall(function() image:SetVisibility(4) end)
    pcall(function() text:SetVisibility(4) end)
    pcall(function() text.Font.Size = fontSize end)
    pcall(function() text.Justification = 0 end)
    pcall(function() text.AutoWrapText = false end)
    SetWidgetBrushColor(button, { R = 0.02, G = 0.09, B = 0.10, A = 0.76 })
    pcall(function()
        button.Padding = { Left = 6.0, Top = 2.0, Right = 6.0, Bottom = 2.0 }
        button.MinDesiredWidth = GetFilterPanelColumnWidth(panelConfig)
    end)
    ConfigureSizeBox(iconBox, iconSize + 8.0, rowHeight)
    pcall(function()
        image:SetRenderScale(MakeVector2D(1.0, 1.0))
    end)
    ApplyFilterPanelIconTexture(textureCategoryName, image, iconSize)

    local imageSlot = AddChildToWidget(iconBox, image)
    pcall(function()
        if imageSlot then
            imageSlot.HorizontalAlignment = 2
            imageSlot.VerticalAlignment = 2
        end
    end)
    AddChildToWidget(rowBox, iconBox)
    AddChildToWidget(rowBox, text)
    AddChildToWidget(button, rowBox)

    local record = {
        Action = actionName,
        Category = categoryName,
        NativeFilter = nativeFilterName,
        LocationType = spec.LocationType,
        TextureCategory = textureCategoryName,
        CountCategory = spec.CountCategory,
        CountCategories = spec.CountCategories,
        Label = spec.Label or categoryName or nativeFilterName,
        Column = tonumber(spec.Column),
        Button = button,
        Text = text
    }
    RefreshOverlayFilterPanelRow(record)
    return record, "ok"
end

local function BuildOverlayFilterPanelBody(widgetTree, vertical, panelConfig)
    if IsValidObject(OverlayFilterPanelBody) then
        return true, #OverlayFilterPanelRows, "already-built"
    end
    if not IsValidObject(widgetTree) or not IsValidObject(vertical) then
        return false, 0, "invalid-context"
    end
    panelConfig = panelConfig or {}

    local columnCount = GetFilterPanelColumnCount(panelConfig)
    local columnWidth = GetFilterPanelColumnWidth(panelConfig)
    local columnGap = tonumber(panelConfig.ColumnGap) or 4.0
    local bodyClass = columnCount > 1 and "/Script/UMG.HorizontalBox" or "/Script/UMG.VerticalBox"
    local body, bodyDetail = ConstructUmgWidget(bodyClass, widgetTree)
    if not IsValidObject(body) then
        return false, 0, "body construct failed detail=" .. tostring(bodyDetail)
    end
    pcall(function() body:SetVisibility(OverlayFilterPanelExpanded and 0 or 1) end)
    OverlayFilterPanelBody = body

    local columns = nil
    if columnCount > 1 then
        columns = {}
        for columnIndex = 1, columnCount do
            local columnBox, columnDetail = ConstructUmgWidget("/Script/UMG.VerticalBox", widgetTree)
            if not IsValidObject(columnBox) then
                return false, 0, "column construct failed index=" .. tostring(columnIndex) .. " detail=" .. tostring(columnDetail)
            end
            pcall(function()
                columnBox:SetVisibility(4)
                columnBox.MinDesiredWidth = columnWidth
            end)
            local columnSlot = AddChildToWidget(body, columnBox)
            pcall(function()
                if columnSlot then
                    columnSlot.Padding = { Left = columnIndex > 1 and columnGap or 0.0, Top = 0.0, Right = 0.0, Bottom = 0.0 }
                end
            end)
            columns[columnIndex] = columnBox
        end
    end

    local rowCount = 0
    local errors = {}
    local specs = GetFilterPanelCategorySpecs(panelConfig)
    for specIndex, spec in ipairs(specs) do
        local record, detail = CreateFilterPanelRow(widgetTree, spec, panelConfig)
        if record and IsValidObject(record.Button) then
            local parent = body
            if columns then
                parent = columns[GetFilterPanelColumnIndex(spec, specIndex, panelConfig)] or columns[1]
            end
            local slot = AddChildToWidget(parent, record.Button)
            pcall(function()
                if slot then
                    slot.Padding = { Left = 0.0, Top = 1.0, Right = 0.0, Bottom = 0.0 }
                end
            end)
            OverlayFilterPanelRows[#OverlayFilterPanelRows + 1] = record
            rowCount = rowCount + 1
        else
            errors[#errors + 1] = tostring(spec.Category or spec.NativeFilter) .. "=" .. tostring(detail)
        end
    end

    AddChildToWidget(vertical, body)
    SetOverlayFilterPanelExpanded(OverlayFilterPanelExpanded == true)
    return true, rowCount, (#errors > 0 and ("errors=" .. table.concat(errors, " | ")) or "ok")
end

function MapController.EnsureOverlayFilterPanel(mapBase)
    local overlayConfig = Config.OverlayMarkers or {}
    local panelConfig = overlayConfig.FilterPanel or {}
    if overlayConfig.Enabled ~= true or panelConfig.Enabled ~= true then return false end

    if not IsValidObject(mapBase) then
        mapBase = MapController.FindLiveMapBase()
    end
    if not IsValidObject(mapBase) then
        AppendOverlayMarkersLog("Filter panel skipped: no live map base")
        return false
    end

    local address = GetObjectAddress(mapBase)
    if address and OverlayFilterPanelMapAddresses[address] then return true end

    local widgetTree = nil
    pcall(function()
        widgetTree = mapBase.WidgetTree
    end)
    if not IsValidObject(widgetTree) then
        AppendOverlayMarkersLog("Filter panel skipped: no widget tree mapBase=" .. GetObjectName(mapBase))
        return false
    end

    local canvas, canvasSource = GetMapBaseRootCanvas(mapBase)
    if not IsValidObject(canvas) then
        AppendOverlayMarkersLog("Filter panel skipped: canvas unavailable detail=" .. tostring(canvasSource))
        return false
    end

    local rootBorder, borderDetail = ConstructUmgWidget("/Script/UMG.Border", widgetTree)
    local vertical, verticalDetail = ConstructUmgWidget("/Script/UMG.VerticalBox", widgetTree)
    local rootWidget = rootBorder
    if not IsValidObject(rootWidget) then
        rootWidget = vertical
    end
    if not IsValidObject(rootWidget) or not IsValidObject(vertical) then
        AppendOverlayMarkersLog("Filter panel skipped: construct root failed border=" .. tostring(borderDetail) .. " vertical=" .. tostring(verticalDetail))
        return false
    end

    OverlayFilterPanelRoot = rootWidget
    pcall(function() rootWidget:SetVisibility(0) end)
    pcall(function() vertical:SetVisibility(4) end)
    pcall(function() rootWidget:SetRenderOpacity(0.92) end)
    SetWidgetBrushColor(rootWidget, { R = 0.00, G = 0.06, B = 0.07, A = 0.72 })
    pcall(function()
        rootWidget.Padding = { Left = 4.0, Top = 4.0, Right = 4.0, Bottom = 4.0 }
        rootWidget.MinDesiredWidth = tonumber(panelConfig.PanelWidth) or 205.0
    end)
    if rootWidget ~= vertical then
        AddChildToWidget(rootWidget, vertical)
    end

    local headerBorder, headerBorderDetail = ConstructUmgWidget("/Script/UMG.Border", widgetTree)
    local headerText, headerTextDetail = ConstructUmgWidget("/Script/UMG.TextBlock", widgetTree)
    if IsValidObject(headerBorder) and IsValidObject(headerText) then
        pcall(function() headerBorder:SetVisibility(0) end)
        pcall(function() headerText:SetVisibility(4) end)
        pcall(function()
            headerText.Font.Size = tonumber(panelConfig.FontSize or 12) + 1
            headerText.Justification = 1
        end)
        SetWidgetBrushColor(headerBorder, { R = 0.00, G = 0.17, B = 0.19, A = 0.88 })
        pcall(function()
            headerBorder.Padding = { Left = 8.0, Top = 4.0, Right = 8.0, Bottom = 4.0 }
            headerBorder.MinDesiredWidth = tonumber(panelConfig.PanelWidth) or 205.0
        end)
        AddChildToWidget(headerBorder, headerText)
        AddChildToWidget(vertical, headerBorder)
        OverlayFilterPanelHeader = {
            Button = headerBorder,
            Text = headerText
        }
    else
        AppendOverlayMarkersLog("Filter panel header skipped: border=" .. tostring(headerBorderDetail) .. " text=" .. tostring(headerTextDetail))
    end

    OverlayFilterPanelWidgetTree = widgetTree
    OverlayFilterPanelContainer = vertical
    OverlayFilterPanelPanelConfig = panelConfig
    OverlayFilterPanelExpanded = panelConfig.StartExpanded == true

    local rowCount = 0
    local bodyDetail = "deferred"
    if panelConfig.LazyBuildRows ~= true or OverlayFilterPanelExpanded == true then
        local bodyOk, builtRows, detail = BuildOverlayFilterPanelBody(widgetTree, vertical, panelConfig)
        if bodyOk ~= true then
            AppendOverlayMarkersLog("Filter panel skipped: body build failed detail=" .. tostring(detail))
            return false
        end
        rowCount = builtRows or 0
        bodyDetail = detail
    else
        SetOverlayFilterPanelExpanded(false)
    end

    local slot, addDetail = AddChildToCanvasWidget(canvas, rootWidget)
    if not IsValidObject(slot) then
        AppendOverlayMarkersLog("Filter panel skipped: attach failed canvas=" .. tostring(canvasSource) .. " detail=" .. tostring(addDetail))
        return false
    end

    local slotDetail = ConfigureFilterPanelSlot(slot, panelConfig)
    if address then OverlayFilterPanelMapAddresses[address] = true end
    AppendOverlayMarkersLog("Filter panel added rows=" .. tostring(rowCount)
        .. " mapBase=" .. GetObjectName(mapBase)
        .. " canvas=" .. tostring(canvasSource)
        .. " attach=" .. tostring(addDetail)
        .. " slot=" .. tostring(slotDetail)
        .. " body=" .. tostring(bodyDetail))
    return true
end

function MapController.HandleOverlayFilterPanelClick()
    local panelConfig = (Config.OverlayMarkers and Config.OverlayMarkers.FilterPanel) or {}
    if panelConfig.Enabled ~= true or panelConfig.MouseClickEnabled ~= true then return false end

    if type(OverlayFilterPanelHeader) == "table" and IsValidObject(OverlayFilterPanelHeader.Button) then
        local headerHovered = false
        pcall(function()
            if OverlayFilterPanelHeader.Button.IsHovered then
                headerHovered = OverlayFilterPanelHeader.Button:IsHovered() == true
            end
        end)
        if headerHovered then
            local nextExpanded = not OverlayFilterPanelExpanded
            if nextExpanded and not IsValidObject(OverlayFilterPanelBody) then
                local bodyOk, rowCount, detail = BuildOverlayFilterPanelBody(
                    OverlayFilterPanelWidgetTree,
                    OverlayFilterPanelContainer,
                    OverlayFilterPanelPanelConfig or panelConfig
                )
                AppendOverlayMarkersLog("Filter panel lazy body build ok=" .. tostring(bodyOk)
                    .. " rows=" .. tostring(rowCount)
                    .. " detail=" .. tostring(detail))
                if bodyOk ~= true then
                    return true
                end
            end
            SetOverlayFilterPanelExpanded(nextExpanded)
            AppendOverlayMarkersLog("Filter panel header clicked expanded=" .. tostring(OverlayFilterPanelExpanded))
            return true
        end
    end

    if OverlayFilterPanelExpanded ~= true then return false end

    for _, record in ipairs(OverlayFilterPanelRows) do
        if IsValidObject(record.Button) then
            local hovered = false
            pcall(function()
                if record.Button.IsHovered then hovered = record.Button:IsHovered() == true end
            end)
            if hovered then
                if record.Action == "LimitProfile" then
                    local ok, detail = MapController.CycleOverlayLimitProfile()
                    RefreshOverlayFilterPanelCategory(nil)
                    AppendOverlayMarkersLog("Filter panel clicked action=LimitProfile ok=" .. tostring(ok) .. " detail=" .. tostring(detail))
                elseif record.Action == "NormalPalMenu" then
                    local expanded = MapController.ToggleOverlayNormalPalMenu()
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalMenu expanded=" .. tostring(expanded))
                elseif record.Action == "NormalPalPrev" then
                    local ok, detail = MapController.SelectOverlayNormalPal(-1)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalPrev ok=" .. tostring(ok) .. " detail=" .. tostring(detail))
                elseif record.Action == "NormalPalNext" then
                    local ok, detail = MapController.SelectOverlayNormalPal(1)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalNext ok=" .. tostring(ok) .. " detail=" .. tostring(detail))
                elseif record.Action == "NormalPalDexMinus100" then
                    local ok, detail = MapController.SelectOverlayNormalPalByDexDelta(-100)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalDexMinus100 ok=" .. tostring(ok) .. " detail=" .. tostring(detail))
                elseif record.Action == "NormalPalDexMinus10" then
                    local ok, detail = MapController.SelectOverlayNormalPalByDexDelta(-10)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalDexMinus10 ok=" .. tostring(ok) .. " detail=" .. tostring(detail))
                elseif record.Action == "NormalPalDexMinus1" then
                    local ok, detail = MapController.SelectOverlayNormalPalByDexDelta(-1)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalDexMinus1 ok=" .. tostring(ok) .. " detail=" .. tostring(detail))
                elseif record.Action == "NormalPalDexPlus1" then
                    local ok, detail = MapController.SelectOverlayNormalPalByDexDelta(1)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalDexPlus1 ok=" .. tostring(ok) .. " detail=" .. tostring(detail))
                elseif record.Action == "NormalPalDexPlus10" then
                    local ok, detail = MapController.SelectOverlayNormalPalByDexDelta(10)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalDexPlus10 ok=" .. tostring(ok) .. " detail=" .. tostring(detail))
                elseif record.Action == "NormalPalDexPlus100" then
                    local ok, detail = MapController.SelectOverlayNormalPalByDexDelta(100)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalDexPlus100 ok=" .. tostring(ok) .. " detail=" .. tostring(detail))
                elseif record.Action == "NormalPalToggle" then
                    local visible = MapController.ToggleOverlayCategoryVisibility(MapController.NormalPalSelectedCategory)
                    RefreshOverlayFilterPanelCategory(nil)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalToggle visible=" .. tostring(visible))
                elseif record.Action == "NormalPalClear" then
                    local changed, stale = MapController.SetOverlayCategoryVisibility(MapController.NormalPalSelectedCategory, false)
                    RefreshOverlayFilterPanelCategory(nil)
                    AppendOverlayMarkersLog("Filter panel clicked action=NormalPalClear changed=" .. tostring(changed) .. " stale=" .. tostring(stale))
                elseif record.NativeFilter then
                    local visible, ok, detail = MapController.ToggleNativeMapFilterVisibility(record.NativeFilter, record.LocationType)
                    RefreshOverlayFilterPanelCategory(record.NativeFilter)
                    AppendOverlayMarkersLog("Filter panel clicked nativeFilter=" .. tostring(record.NativeFilter)
                        .. " locationType=" .. tostring(record.LocationType)
                        .. " visible=" .. tostring(visible)
                        .. " ok=" .. tostring(ok)
                        .. " detail=" .. tostring(detail))
                else
                    local visible = MapController.ToggleOverlayCategoryVisibility(record.Category)
                    RefreshOverlayFilterPanelCategory(record.Category)
                    AppendOverlayMarkersLog("Filter panel clicked category=" .. tostring(record.Category) .. " visible=" .. tostring(visible))
                end
                return true
            end
        end
    end

    return false
end

local function ApplyNativeIconPresentation(icon, scale, renderOffset)
    local numericScale = tonumber(scale)
    local offsetX = 0.0
    local offsetY = 0.0
    if type(renderOffset) == "table" then
        offsetX = tonumber(renderOffset.X) or 0.0
        offsetY = tonumber(renderOffset.Y) or 0.0
    end

    if (not numericScale or numericScale <= 0) and offsetX == 0.0 and offsetY == 0.0 then
        return "presentation=skipped"
    end
    if not numericScale or numericScale <= 0 then numericScale = 1.0 end

    local image, imageSource = GetNamedWidgetPart(icon, "Icon")
    if not IsValidObject(image) then
        return "presentation=failed image=" .. tostring(imageSource)
    end

    local ok, err = pcall(function()
        if image.ForceLayoutPrepass then image:ForceLayoutPrepass() end
        if image.SetRenderTransformPivot then image:SetRenderTransformPivot(MakeVector2D(0.5, 0.5)) end
        if image.SetRenderScale then image:SetRenderScale(MakeVector2D(numericScale, numericScale)) end
        if image.SetRenderTranslation then image:SetRenderTranslation(MakeVector2D(offsetX, offsetY)) end
    end)

    if ok then
        return "presentation scale=" .. tostring(numericScale) ..
            " offset=(" .. tostring(offsetX) .. "," .. tostring(offsetY) .. ")" ..
            " image=" .. tostring(imageSource)
    end

    return "presentation=failed image=" .. tostring(imageSource) .. " err=" .. tostring(err)
end

local function ExtractBossCharacterId(marker)
    if type(marker) ~= "table" then return "None" end
    if marker.CharacterId and marker.CharacterId ~= "" then return tostring(marker.CharacterId) end
    if marker.OriginalCharacterId and marker.OriginalCharacterId ~= "" then return tostring(marker.OriginalCharacterId) end

    local name = tostring(marker.Name or marker.Id or "None")
    local id = name:match("BOSS_([^%+%s]+)")
    if id and id ~= "" then return id end

    id = name:match("([^%+%s]+)")
    if id and id ~= "" then return id end
    return "None"
end

local function PrepareOverlayIconWidget(categoryName, marker, widget, worldLocation)
    if not IsValidObject(widget) then return "invalid-widget" end

    local details = {}
    pcall(function()
        if widget.SetVisibility then widget:SetVisibility(0) end
    end)

    details[#details + 1] = ApplyOverlayIconTexture(categoryName, marker, widget)
    details[#details + 1] = "nativeInit=skipped"
    details[#details + 1] = "forcedVisibleParts=" .. tostring(ForceIconWidgetVisible(widget))
    return table.concat(details, " | ")
end

local function MakeLocationNearPlayer(anchor, marker)
    if not anchor or not anchor.Instance then return nil end
    if type(marker) ~= "table" then return nil end

    local worldLocation = nil
    pcall(function()
        worldLocation = anchor.Instance:K2_GetActorLocation()
    end)
    if not worldLocation then return nil end

    local ok = pcall(function()
        worldLocation.X = worldLocation.X + (tonumber(marker.OffsetX) or 0.0)
        worldLocation.Y = worldLocation.Y + (tonumber(marker.OffsetY) or 0.0)
        worldLocation.Z = worldLocation.Z + (tonumber(marker.OffsetZ) or 0.0)
    end)
    if not ok then return nil end

    return worldLocation
end

local function GenerateDebugOverlayMarkers(mapBody, dataState, ignoreMask, toPriority)
    local overlayConfig = Config.OverlayMarkers or {}
    local debugConfig = overlayConfig.DebugNearPlayer or {}
    if debugConfig.Enabled ~= true then return 0, 0, 0 end

    local markers = debugConfig.Markers or {}
    if type(markers) ~= "table" or #markers == 0 then
        markers = {
            {
                Id = "overlay_probe",
                OffsetX = 30000.0,
                OffsetY = 0.0,
                OffsetZ = 0.0,
                WidgetPath = "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_IconDungeon.WBP_Map_IconDungeon_C"
            }
        }
    end

    local attempted = 0
    local addedCount = 0
    local skippedCount = 0

    for index, marker in ipairs(markers) do
        local key = tostring(marker.Id or "overlay_probe")
        local widgetPath = marker.WidgetPath or GetOverlayIconWidgetPath("Boss")
        local worldLocation = MakeLocationNearPlayer(dataState.PlayerAnchor, marker)

        if not worldLocation then
            skippedCount = skippedCount + 1
            AppendOverlayMarkersLog("Skipped debug overlay invalid location key=" .. tostring(key))
        else
            local widget, constructDetail = ConstructIconWidget(mapBody, widgetPath)
            if not IsValidObject(widget) then
                skippedCount = skippedCount + 1
                AppendOverlayMarkersLog("Skipped debug overlay widget construction key=" .. tostring(key) .. " detail=" .. tostring(constructDetail))
            else
                local prepDetail = PrepareOverlayIconWidget("Debug", marker, widget, worldLocation)
                local added = false
                local detail = nil
                if debugConfig.ViewportProbe == true then
                    local screenPositions = {
                        { X = 820.0, Y = 430.0 },
                        { X = 960.0, Y = 430.0 },
                        { X = 1100.0, Y = 430.0 }
                    }
                    local fixed = screenPositions[index] or { X = 960.0, Y = 540.0 }
                    added, detail = TryAddWidgetToViewport(
                        widget,
                        tonumber(marker.ScreenX) or fixed.X,
                        tonumber(marker.ScreenY) or fixed.Y,
                        tonumber(marker.Size) or 96.0,
                        9999
                    )
                elseif debugConfig.CanvasProbe == true then
                    local fixedPositions = {
                        { X = -120.0, Y = -60.0 },
                        { X = 0.0, Y = -60.0 },
                        { X = 120.0, Y = -60.0 }
                    }
                    local fixed = fixedPositions[index] or { X = 0.0, Y = 0.0 }
                    added, detail = TryAttachWidgetToMapCanvas(
                        mapBody,
                        widget,
                        tonumber(marker.LocalX) or fixed.X,
                        tonumber(marker.LocalY) or fixed.Y,
                        tonumber(marker.Size) or 96.0,
                        toPriority
                    )
                else
                    added, detail = TryCallAddIconByLocation(mapBody, widget, worldLocation, ignoreMask, toPriority)
                end
                attempted = attempted + 1
                local postPrepDetail = "post=skipped"
                if added then
                    postPrepDetail = "post=" .. PrepareOverlayIconWidget("Debug", marker, widget, worldLocation)
                end

                AppendOverlayMarkersLog(string.format(
                    "Add debug overlay key=%s mode=%s widget=%s added=%s detail=%s prep=%s %s loc=(%.1f, %.1f, %.1f)",
                    tostring(key),
                    debugConfig.ViewportProbe == true and "viewport-probe" or (debugConfig.CanvasProbe == true and "canvas-probe" or "location"),
                    tostring(widgetPath),
                    tostring(added),
                    tostring(detail),
                    tostring(prepDetail),
                    tostring(postPrepDetail),
                    worldLocation.X or 0,
                    worldLocation.Y or 0,
                    worldLocation.Z or 0
                ))

                if added then
                    addedCount = addedCount + 1
                end
            end
        end
    end

    return attempted, addedCount, skippedCount
end

local function CollectCustomMapIconObjects()
    local icons = {}
    local objects = nil
    pcall(function()
        objects = FindAllOf("WBP_Map_IconCustom_C")
    end)

    if objects then
        for _, obj in ipairs(objects) do
            if IsValidObject(obj) then
                icons[#icons + 1] = obj
            end
        end
    end

    return icons
end

local function DescribeCustomMapIconObjects(label, icons, previousAddresses, mapBody, markerData)
    local details = {}
    local maxInspect = 5
    local startIndex = math.max(1, #icons - maxInspect + 1)

    for index = startIndex, #icons do
        local icon = icons[index]
        local address = GetObjectAddress(icon)
        local isNew = previousAddresses and previousAddresses[address] ~= true
        local forcedVisible = ForceIconWidgetVisible(icon)
        local iconWidget, iconSource = GetNamedWidgetPart(icon, "Icon")
        local planWidget, planSource = GetNamedWidgetPart(icon, "Icon_Plan")
        local landscapeDetail = "landscape=not-called"
        pcall(function()
            if icon.GetLocationOnLandscape then
                local outLocation = {}
                local result = icon:GetLocationOnLandscape(outLocation)
                landscapeDetail = "landscapeResult=" .. tostring(result) .. " out=" .. tostring(outLocation)
            end
        end)

        details[#details + 1] = string.format(
            "%s[%d/%d] new=%s addr=%s name=%s forcedVisible=%s icon=%s plan=%s %s",
            tostring(label),
            index,
            #icons,
            tostring(isNew),
            tostring(address),
            GetObjectName(icon),
            tostring(forcedVisible),
            tostring(iconSource),
            tostring(planSource),
            tostring(landscapeDetail)
        )

        if IsValidObject(iconWidget) then
            pcall(function()
                if iconWidget.SetVisibility then iconWidget:SetVisibility(0) end
                if iconWidget.SetRenderOpacity then iconWidget:SetRenderOpacity(1.0) end
            end)
        end
        if IsValidObject(planWidget) then
            pcall(function()
                if planWidget.SetVisibility then planWidget:SetVisibility(0) end
                if planWidget.SetRenderOpacity then planWidget:SetRenderOpacity(1.0) end
            end)
        end
    end

    return table.concat(details, " || ")
end

local function TryCallRemoveCustomIcon(mapBase, icon)
    if not IsValidObject(mapBase) then return false, "no-map-base" end
    if not IsValidObject(icon) then return false, "no-icon" end

    local ufunc = nil
    pcall(function()
        ufunc = mapBase["RemoveCustomIcon"]
    end)
    if not IsValidObject(ufunc) then
        pcall(function()
            ufunc = mapBase["Remove Custom Icon"]
        end)
    end

    local attempts = {
        {
            "Direct:RemoveCustomIcon",
            function()
                return mapBase:RemoveCustomIcon(icon)
            end
        },
        {
            "Direct:spaced",
            function()
                return mapBase["RemoveCustomIcon"](mapBase, icon)
            end
        },
        {
            "CallFunction",
            function()
                if not IsValidObject(ufunc) then error("ufunction-not-valid") end
                return mapBase:CallFunction(ufunc, icon)
            end
        }
    }

    local errors = {}
    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt[2])
        if ok then return true, tostring(attempt[1]) .. " result=" .. tostring(result) end
        errors[#errors + 1] = tostring(attempt[1]) .. "=" .. tostring(result)
    end

    return false, table.concat(errors, " | ")
end

local function TryRegisterNativeIconCaptureHook()
    if NativeIconCaptureHookRegistered then return true, "already-registered" end
    if RegisterHook == nil then return false, "RegisterHook unavailable" end

    local hookPath = "/Script/Pal.PalUIWorldMapIcon:SetLocationData"
    local ok, result = pcall(function()
        return RegisterHook(hookPath, function() end, function(self)
            if not NativePendingLocationPoint then return end
            local icon = UnwrapParam(self)
            if IsValidObject(icon) then
                NativeCapturedWorldMapIcon = icon
            end
        end)
    end)

    if ok then
        NativeIconCaptureHookRegistered = true
        return true, tostring(result)
    end

    return false, tostring(result)
end

local function GetCurrentMapBodyFromMapBase(mapBase)
    if not IsValidObject(mapBase) then return nil, "no-map-base" end

    local getter = nil
    pcall(function()
        getter = mapBase["GetCurrentMapBody"]
    end)

    if getter then
        local out = {}
        local ok, r1, r2, r3 = pcall(function()
            return getter(mapBase, out)
        end)
        if ok then
            local candidates = { out[1], out.MapBody, out.mapBody, r1, r2, r3 }
            for _, candidate in ipairs(candidates) do
                if IsValidObject(candidate) then return candidate, "GetCurrentMapBody" end
            end
        end
    end

    local fallback = nil
    pcall(function()
        fallback = mapBase.WBP_Map_Body_MW5
    end)
    if IsValidObject(fallback) then return fallback, "WBP_Map_Body_MW5" end

    return nil, "not-found"
end

local function GetMapBodyByWorldLocation(mapBase, worldLocation)
    if not IsValidObject(mapBase) or not worldLocation then return nil, "invalid-input" end

    local getter = nil
    pcall(function()
        getter = mapBase["GetMapBodyByLocation"]
    end)
    if getter == nil then return nil, "GetMapBodyByLocation not found" end

    local out = {}
    local ok, r1, r2, r3 = pcall(function()
        return getter(mapBase, worldLocation, out)
    end)
    if not ok then return nil, "GetMapBodyByLocation error: " .. tostring(r1) end

    local candidates = { out[1], out.MapBody, out.mapBody, r1, r2, r3 }
    for _, candidate in ipairs(candidates) do
        if IsValidObject(candidate) then return candidate, "GetMapBodyByLocation" end
    end

    return nil, "GetMapBodyByLocation returned no valid body"
end

local function TryCallSetupIcon(mapBase, locationType, point)
    if not IsValidObject(mapBase) then return nil, "no-map-base" end
    if not IsValidObject(point) then return nil, "no-location-point" end

    local setupIcon = nil
    pcall(function()
        setupIcon = mapBase["Setup Icon"]
    end)
    if setupIcon == nil then return nil, "Setup Icon not found" end

    NativePendingLocationPoint = point
    NativeCapturedWorldMapIcon = nil

    local outIcon = {}
    local ok, r1, r2, r3 = pcall(function()
        return setupIcon(mapBase, locationType, point, outIcon)
    end)

    NativePendingLocationPoint = nil

    if not ok then return nil, "Setup Icon error: " .. tostring(r1) end

    local candidates = {
        { Label = "captured", Value = NativeCapturedWorldMapIcon },
        { Label = "r1", Value = r1 },
        { Label = "r2", Value = r2 },
        { Label = "r3", Value = r3 },
        { Label = "out1", Value = outIcon[1] },
        { Label = "outIcon", Value = outIcon.Icon },
        { Label = "outIconLower", Value = outIcon.icon }
    }

    local candidateDetails = {}
    local fallbackIcon = nil
    local fallbackDetail = nil
    for _, entry in ipairs(candidates) do
        local candidate = UnwrapParam(entry.Value)
        local valid = IsValidObject(candidate)
        local className = valid and GetObjectClassName(candidate) or "invalid"
        candidateDetails[#candidateDetails + 1] = tostring(entry.Label) .. ":" .. tostring(className)
        if valid then
            if tostring(className):find("PalUIWorldMapIcon", 1, true)
                or tostring(className):find("WBP_Map_Icon", 1, true)
                or tostring(className):find("WBP_WorldMap_IconBase_NoDesign", 1, true) then
                return candidate, "Setup Icon ok " .. tostring(entry.Label) .. " class=" .. tostring(className) .. " candidates=" .. table.concat(candidateDetails, ",")
            end
            if not fallbackIcon then
                fallbackIcon = candidate
                fallbackDetail = tostring(entry.Label) .. " class=" .. tostring(className)
            end
        end
    end

    if fallbackIcon then
        return fallbackIcon, "Setup Icon fallback " .. tostring(fallbackDetail) .. " candidates=" .. table.concat(candidateDetails, ",")
    end

    return nil, "Setup Icon returned no valid map icon candidates=" .. table.concat(candidateDetails, ",")
end

local function TryCreateNativeWorldMapIcon(mapBase, mapBody, worldLocation, setupIconType, options)
    options = options or {}
    local preStepLog = options.PreStepLog == true
    local function logStep(text)
        if preStepLog then AppendOverlayMarkersLog("Native icon step: " .. tostring(text)) end
    end

    logStep("enter mapBase=" .. GetObjectName(mapBase) .. " mapBody=" .. GetObjectName(mapBody) .. " setupIconType=" .. tostring(setupIconType))
    if not IsValidObject(mapBase) then return false, "no-map-base", nil end
    if not IsValidObject(mapBody) then return false, "no-map-body", nil end
    if not worldLocation then return false, "no-location", nil end

    logStep(string.format("location=(%.1f, %.1f, %.1f)", worldLocation.X or 0, worldLocation.Y or 0, worldLocation.Z or 0))
    logStep("register capture hook")
    local hookOk, hookDetail = TryRegisterNativeIconCaptureHook()
    if not hookOk then
        return false, "capture-hook-failed:" .. tostring(hookDetail), nil
    end

    logStep("find PalLocationPoint_LevelObject class")
    local pointClass = nil
    pcall(function()
        pointClass = StaticFindObject("/Script/Pal.PalLocationPoint_LevelObject")
    end)
    if not IsValidObject(pointClass) then
        return false, "PalLocationPoint_LevelObject class not found", nil
    end

    logStep("construct PalLocationPoint_LevelObject")
    local point = nil
    local pointOk, pointErr = pcall(function()
        point = StaticConstructObject(pointClass, mapBase)
    end)
    if not pointOk or not IsValidObject(point) then
        return false, "location point construction failed: " .. tostring(pointErr), nil
    end

    logStep("populate location point")
    pcall(function()
        point.InitialLocationCache = {
            X = worldLocation.X or 0,
            Y = worldLocation.Y or 0,
            Z = worldLocation.Z or 0
        }
        point.Location = {
            X = worldLocation.X or 0,
            Y = worldLocation.Y or 0,
            Z = worldLocation.Z or 0
        }
        point.bShouldDisplay = true
        point.bShowInMap = true
        point.bShowInCompass = false
        point.RelicType = 0
    end)

    logStep("call Setup Icon")
    local icon, setupDetail = TryCallSetupIcon(mapBase, setupIconType, point)
    if not IsValidObject(icon) then
        return false, setupDetail, nil
    end

    logStep("prepare icon " .. GetObjectName(icon))
    pcall(function() icon.bEnableHideOnZoom = false end)
    pcall(function() icon.IgnoreMask = true end)
    pcall(function()
        if icon.SetIgnoreMask then icon:SetIgnoreMask(true) end
    end)
    pcall(function()
        if icon.SetGeneralHiding then icon:SetGeneralHiding(false) end
    end)

    local textureDetail = "textureReplacement=skipped"
    if options.TextureCategoryName then
        logStep("apply texture replacement category=" .. tostring(options.TextureCategoryName))
        textureDetail = ApplyOverlayIconTexture(options.TextureCategoryName, options.TextureMarker, icon)
        logStep("texture replacement detail=" .. tostring(textureDetail))
    end

    logStep("call Add Icon By Location")
    local added, addDetail = TryCallAddIconByLocation(mapBody, icon, worldLocation, true, false)
    logStep("Add Icon By Location returned added=" .. tostring(added) .. " detail=" .. tostring(addDetail))
    if added and options.CallUpdateMapIcon ~= false then
        logStep("call Update Map Icon")
        pcall(function()
            local updateMapIcon = mapBody["Update Map Icon"]
            if updateMapIcon then updateMapIcon(mapBody, icon) end
        end)
    elseif added then
        logStep("skip Update Map Icon")
    end

    local presentationDetail = "presentation=skipped"
    if added and (options.IconScale or options.IconRenderOffset) then
        presentationDetail = ApplyNativeIconPresentation(icon, options.IconScale, options.IconRenderOffset)
        logStep("presentation detail=" .. tostring(presentationDetail))
    end

    return added, tostring(setupDetail) .. " | " .. tostring(textureDetail) .. " | " .. tostring(addDetail) .. " | " .. tostring(presentationDetail), icon
end

local function BuildOverlayCategoryWorkItems(categoryName, context)
    if type(context) ~= "table" then return {}, "no-context" end
    if not MapController.IsOverlayMarkerCategoryName(categoryName) then
        return {}, "not-marker-category"
    end
    local staticMarkerData = context.StaticMarkerData
    local dataState = context.DataState
    local overlayConfig = context.OverlayConfig or {}
    local nativeStaticConfig = context.NativeStaticConfig or {}
    local maxPerCategory = tonumber(overlayConfig.MaxPerCategory) or 100
    local categoryLimit = GetOverlayCategoryLimit(categoryName, overlayConfig, maxPerCategory)
    if categoryLimit <= 0 then
        return {}, "category-limit-zero"
    end
    if nativeStaticConfig.Enabled ~= true then
        return {}, "native-static-disabled"
    end

    local markers = nil
    if categoryName == MapController.NormalPalSelectedCategory then
        markers = MapController.GetSelectedNormalPalMarkers(staticMarkerData, categoryLimit, dataState)
    else
        markers = staticMarkerData and staticMarkerData[categoryName]
    end
    if type(markers) ~= "table" then return {}, "no-markers" end

    local dedupedMarkers = DeduplicateOverlayMarkersByLocation(categoryName, markers, dataState)
    local sourceMarkers = SelectOverlayCategoryMarkers(dedupedMarkers, dataState, categoryLimit, overlayConfig, nativeStaticConfig)
    return sourceMarkers or {}, "source=" .. tostring(#markers) .. " deduped=" .. tostring(#dedupedMarkers) .. " selected=" .. tostring(#(sourceMarkers or {}))
end

local function CreateOverlayNativeStaticIconForMarker(categoryName, marker, context)
    if type(context) ~= "table" then return false, "no-context" end
    local dataState = context.DataState
    local mapBase = context.MapBase
    local mapBody = context.MapBody
    local nativeStaticConfig = context.NativeStaticConfig or {}
    if not dataState or not dataState.PlayerAnchor then return false, "no-player-anchor" end
    if not IsValidObject(mapBase) then return false, "no-map-base" end
    if not IsValidObject(mapBody) then return false, "no-map-body" end

    local key = MakeStaticMarkerKey(categoryName, marker)
    local worldLocation = MakeLocationFromStaticMarker(dataState.PlayerAnchor, marker)
    if not worldLocation then
        AppendOverlayMarkersLog("Skipped invalid location category=" .. tostring(categoryName) .. " key=" .. tostring(key))
        return false, "invalid-location"
    end

    local staticWorldLocation = {
        X = worldLocation.X or 0,
        Y = worldLocation.Y or 0,
        Z = worldLocation.Z or 0
    }
    if nativeStaticConfig.ForcePlayerRelativeLocation == true then
        local forcedLocation = MakeLocationNearPlayer(dataState.PlayerAnchor, nativeStaticConfig.PlayerRelativeLocation or {})
        if forcedLocation then
            worldLocation = forcedLocation
            AppendOverlayMarkersLog(string.format(
                "Native static display location forced near player category=%s key=%s staticLoc=(%.1f, %.1f, %.1f) displayLoc=(%.1f, %.1f, %.1f)",
                tostring(categoryName),
                tostring(key),
                staticWorldLocation.X or 0,
                staticWorldLocation.Y or 0,
                staticWorldLocation.Z or 0,
                worldLocation.X or 0,
                worldLocation.Y or 0,
                worldLocation.Z or 0
            ))
        else
            AppendOverlayMarkersLog("Native static player-relative display override failed category=" .. tostring(categoryName) .. " key=" .. tostring(key))
        end
    end

    local setupIconType = GetNativeStaticSetupIconType(categoryName)
    local targetMapBody = mapBody
    local targetMapBodyDetail = "current-live-map-body"
    if nativeStaticConfig.UseMapBodyRouter == true then
        targetMapBody, targetMapBodyDetail = GetMapBodyByWorldLocation(mapBase, worldLocation)
    end
    if not IsValidObject(targetMapBody) then
        targetMapBody = mapBody
        targetMapBodyDetail = tostring(targetMapBodyDetail) .. " fallback-current-live-map-body"
    end

    local iconOptions = {
        CallUpdateMapIcon = nativeStaticConfig.CallUpdateMapIcon,
        PreStepLog = nativeStaticConfig.PreStepLog == true,
        TextureCategoryName = categoryName,
        TextureMarker = marker
    }
    if type(nativeStaticConfig.IconScaleByCategory) == "table" then
        iconOptions.IconScale = nativeStaticConfig.IconScaleByCategory[categoryName]
    end
    if type(nativeStaticConfig.IconRenderOffsetByCategory) == "table" then
        iconOptions.IconRenderOffset = nativeStaticConfig.IconRenderOffsetByCategory[categoryName]
    end

    local added, detail, icon = TryCreateNativeWorldMapIcon(mapBase, targetMapBody, worldLocation, setupIconType, iconOptions)
    if context.LogEachMarker == true or not added then
        AppendOverlayMarkersLog(string.format(
            "Add native static category=%s key=%s setupIconType=%d added=%s detail=%s icon=%s bodySource=%s body=%s staticLoc=(%.1f, %.1f, %.1f) loc=(%.1f, %.1f, %.1f)",
            tostring(categoryName),
            tostring(key),
            setupIconType,
            tostring(added),
            tostring(detail),
            IsValidObject(icon) and GetObjectName(icon) or "nil",
            tostring(targetMapBodyDetail),
            GetObjectName(targetMapBody),
            staticWorldLocation.X or 0,
            staticWorldLocation.Y or 0,
            staticWorldLocation.Z or 0,
            worldLocation.X or 0,
            worldLocation.Y or 0,
            worldLocation.Z or 0
        ))
    end

    if added then
        RememberOverlayIcon(categoryName, key, icon)
        return true, detail
    end
    return false, detail
end

local function StartNextOverlayLazyCategory()
    if OverlayLazyActiveCategory ~= nil then return end
    if type(OverlayLazyContext) ~= "table" then return end

    local categoryName = table.remove(OverlayLazyQueue, 1)
    if not categoryName then
        SetOverlayFilterPanelProgress(nil)
        return
    end
    OverlayLazyQueued[categoryName] = nil
    if not IsOverlayCategoryRuntimeVisible(categoryName) then
        StartNextOverlayLazyCategory()
        return
    end

    local overlayConfig = OverlayLazyContext.OverlayConfig or {}
    local lazyConfig = overlayConfig.LazyCreate or {}
    local profile = MapController.GetOverlayActiveLimitProfile(overlayConfig)
    local profileLazyConfig = (type(profile) == "table" and type(profile.LazyCreate) == "table") and profile.LazyCreate or {}
    local batchSize = math.floor(tonumber(profileLazyConfig.BatchSize) or tonumber(lazyConfig.BatchSize) or 10)
    local intervalMs = math.floor(tonumber(profileLazyConfig.BatchIntervalMs) or tonumber(lazyConfig.BatchIntervalMs) or 50)
    local maxLiveIcons = math.floor(tonumber(profileLazyConfig.MaxLiveIcons) or tonumber(profile and profile.MaxLiveIcons) or tonumber(lazyConfig.MaxLiveIcons) or 0)
    if batchSize < 1 then batchSize = 1 end
    if intervalMs < 1 then intervalMs = 1 end

    local state = OverlayLazyCategoryState[categoryName]
    if not state then
        local workItems, detail = BuildOverlayCategoryWorkItems(categoryName, OverlayLazyContext)
        state = {
            Items = workItems,
            Index = 1,
            Added = 0,
            Attempted = 0,
            Done = false,
            Detail = detail
        }
        OverlayLazyCategoryState[categoryName] = state
        AppendOverlayMarkersLog("Lazy category prepared category=" .. tostring(categoryName) .. " " .. tostring(detail))
    end

    if state.Done == true then
        StartNextOverlayLazyCategory()
        return
    end

    OverlayLazyActiveCategory = categoryName
    MapController.OverlayLazyRunSerial = (MapController.OverlayLazyRunSerial or 0) + 1
    local runId = MapController.OverlayLazyRunSerial
    state.RunId = runId
    local total = #(state.Items or {})
    if total <= 0 then
        state.Done = true
        OverlayLazyActiveCategory = nil
        RefreshOverlayFilterPanelCategory(categoryName)
        StartNextOverlayLazyCategory()
        return
    end

    local function runBatch()
        if state.Done == true then return true end
        if state.Paused == true then return true end
        if state.RunId ~= runId then return true end

        local function doBatch()
            if state.Done == true then return true end
            if state.Paused == true then return true end
            if state.RunId ~= runId then return true end
            if not IsOverlayCategoryRuntimeVisible(categoryName) then
                state.Paused = true
                state.RunId = nil
                OverlayLazyActiveCategory = nil
                AppendOverlayMarkersLog("Lazy category paused because filter is OFF category=" .. tostring(categoryName))
                StartNextOverlayLazyCategory()
                return true
            end
            if type(OverlayLazyContext) ~= "table" or not IsValidObject(OverlayLazyContext.MapBody) then
                state.Done = true
                state.RunId = nil
                OverlayLazyActiveCategory = nil
                AppendOverlayMarkersLog("Lazy category stopped: map body is no longer valid category=" .. tostring(categoryName))
                return true
            end

            local count = 0
            while count < batchSize and state.Index <= total do
                if maxLiveIcons > 0 and MapController.CountOverlayLiveIcons() >= maxLiveIcons then
                    state.Paused = true
                    state.RunId = nil
                    OverlayLazyActiveCategory = nil
                    OverlayLazyQueue = {}
                    OverlayLazyQueued = {}
                    SetOverlayFilterPanelProgress(string.format("PalRadar limit %d icons", maxLiveIcons))
                    AppendOverlayMarkersLog("Lazy creation paused: live icon limit reached category=" .. tostring(categoryName) .. " live=" .. tostring(MapController.CountOverlayLiveIcons()) .. " limit=" .. tostring(maxLiveIcons))
                    return true
                end
                local marker = state.Items[state.Index]
                state.Index = state.Index + 1
                state.Attempted = state.Attempted + 1
                local ok, added = pcall(function()
                    return CreateOverlayNativeStaticIconForMarker(categoryName, marker, OverlayLazyContext)
                end)
                if ok and added then
                    state.Added = state.Added + 1
                elseif not ok then
                    AppendOverlayMarkersLog("Lazy category marker error category=" .. tostring(categoryName) .. " err=" .. tostring(added))
                end
                count = count + 1
            end

            local processed = state.Index - 1
            if processed > total then processed = total end
            SetOverlayFilterPanelProgress(string.format("PalRadar loading %s %d/%d", tostring(categoryName), processed, total))
            RefreshOverlayFilterPanelCategory(categoryName)

            if state.Index > total then
                state.Done = true
                state.RunId = nil
                OverlayLazyActiveCategory = nil
                AppendOverlayMarkersLog(string.format(
                    "Lazy category finished category=%s attempted=%d added=%d total=%d",
                    tostring(categoryName),
                    state.Attempted or 0,
                    state.Added or 0,
                    total
                ))
                StartNextOverlayLazyCategory()
                return true
            end
            return false
        end

        local finished = false
        if ExecuteInGameThread then
            ExecuteInGameThread(function()
                doBatch()
            end)
        else
            finished = doBatch()
        end
        return finished
    end

    if LoopAsync then
        LoopAsync(intervalMs, function()
            return runBatch()
        end)
    else
        while not runBatch() do end
    end
end

EnsureOverlayCategoryIconsGenerated = function(categoryName)
    if not categoryName or categoryName == "" then return false end
    local overlayConfig = Config.OverlayMarkers or {}
    local lazyConfig = overlayConfig.LazyCreate or {}
    if lazyConfig.Enabled ~= true then return false end
    if type(OverlayLazyContext) ~= "table" then return false end

    local state = OverlayLazyCategoryState[categoryName]
    if state and state.Done == true then return true end
    if state and state.Paused == true then state.Paused = false end
    if OverlayLazyQueued[categoryName] == true or OverlayLazyActiveCategory == categoryName then return true end

    OverlayLazyQueue[#OverlayLazyQueue + 1] = categoryName
    OverlayLazyQueued[categoryName] = true
    AppendOverlayMarkersLog("Lazy category queued category=" .. tostring(categoryName))
    StartNextOverlayLazyCategory()
    return true
end

local function GenerateNativeIconProbe(mapBase, mapBody, dataState)
    local overlayConfig = Config.OverlayMarkers or {}
    local probeConfig = overlayConfig.NativeIconProbe or {}
    if probeConfig.Enabled ~= true then return 0, 0, 0 end

    if not IsValidObject(mapBase) then
        AppendOverlayMarkersLog("Skipped native icon probe: no live map base available")
        return 0, 0, 1
    end

    local currentBody, bodyDetail = GetCurrentMapBodyFromMapBase(mapBase)
    if IsValidObject(currentBody) then
        mapBody = currentBody
    end

    if not IsValidObject(mapBody) then
        AppendOverlayMarkersLog("Skipped native icon probe: no live map body available detail=" .. tostring(bodyDetail))
        return 0, 0, 1
    end

    local worldLocation = MakeLocationNearPlayer(dataState and dataState.PlayerAnchor or nil, probeConfig)
    if not worldLocation then
        AppendOverlayMarkersLog("Skipped native icon probe: invalid player-relative location")
        return 0, 0, 1
    end

    local setupIconType = tonumber(probeConfig.SetupIconType) or 19
    local added, detail, icon = TryCreateNativeWorldMapIcon(mapBase, mapBody, worldLocation, setupIconType)

    AppendOverlayMarkersLog(string.format(
        "Add native icon probe key=%s mapBase=%s mapBody=%s setupIconType=%d added=%s detail=%s icon=%s loc=(%.1f, %.1f, %.1f)",
        tostring(probeConfig.Id or "native_worldmap_probe"),
        GetObjectName(mapBase),
        GetObjectName(mapBody),
        setupIconType,
        tostring(added),
        tostring(detail),
        IsValidObject(icon) and GetObjectName(icon) or "nil",
        worldLocation.X or 0,
        worldLocation.Y or 0,
        worldLocation.Z or 0
    ))

    if added then return 1, 1, 0 end
    return 1, 0, 0
end

local function GenerateLocationManagerProbe(mapBase, dataState)
    local overlayConfig = Config.OverlayMarkers or {}
    local probeConfig = overlayConfig.LocationManagerProbe or {}
    if probeConfig.Enabled ~= true then return 0, 0, 0 end

    if probeConfig.AcknowledgeWritesToSave ~= true then
        AppendOverlayMarkersLog("Skipped location manager probe: AcknowledgeWritesToSave is not true")
        return 0, 0, 1
    end

    if not IsValidObject(mapBase) then
        AppendOverlayMarkersLog("Skipped location manager probe: no live map base available")
        return 0, 0, 1
    end

    local locationManager, locationManagerSource = FindLocationManager()
    if not IsValidObject(locationManager) then
        AppendOverlayMarkersLog("Skipped location manager probe: no location manager source=" .. tostring(locationManagerSource))
        return 0, 0, 1
    end

    local worldLocation = MakeLocationNearPlayer(dataState and dataState.PlayerAnchor or nil, probeConfig)
    if not worldLocation then
        AppendOverlayMarkersLog("Skipped location manager probe: invalid player-relative location")
        return 0, 0, 1
    end

    local iconsBefore = CollectCustomMapIconObjects()
    local beforeAddresses = {}
    for _, icon in ipairs(iconsBefore) do
        beforeAddresses[GetObjectAddress(icon)] = true
    end

    local iconIndex = tonumber(probeConfig.IconIndex) or 0
    local added, detail, resultGuid = TryCallAddLocalCustomMarker(locationManager, worldLocation, iconIndex)

    pcall(function()
        if mapBase.SetupCustomIcons then mapBase:SetupCustomIcons() end
    end)

    local iconsAfter = CollectCustomMapIconObjects()
    local iconScanDetail = DescribeCustomMapIconObjects("locationManagerIconScan", iconsAfter, beforeAddresses, mapBase, nil)

    AppendOverlayMarkersLog(string.format(
        "Add location manager probe key=%s locationManager=%s added=%s detail=%s guid=%s iconIndex=%d iconsBefore=%d iconsAfter=%d loc=(%.1f, %.1f, %.1f)",
        tostring(probeConfig.Id or "location_manager_probe"),
        GetObjectName(locationManager),
        tostring(added),
        tostring(detail),
        DescribeValue(resultGuid),
        iconIndex,
        #iconsBefore,
        #iconsAfter,
        worldLocation.X or 0,
        worldLocation.Y or 0,
        worldLocation.Z or 0
    ))
    if iconScanDetail ~= "" then
        AppendOverlayMarkersLog(iconScanDetail)
    end

    if added and probeConfig.AttemptAutoRemove == true then
        for _, icon in ipairs(iconsAfter) do
            if beforeAddresses[GetObjectAddress(icon)] ~= true then
                local removed, removeDetail = TryCallRemoveCustomIcon(mapBase, icon)
                AppendOverlayMarkersLog("Remove location manager probe icon removed=" .. tostring(removed) .. " detail=" .. tostring(removeDetail) .. " icon=" .. GetObjectName(icon))
            end
        end
    end

    if added then return 1, 1, 0 end
    return 1, 0, 0
end

local function GenerateTempMarkerProbe(mapBase, mapBody, dataState)
    local overlayConfig = Config.OverlayMarkers or {}
    local probeConfig = overlayConfig.TempMarkerProbe or {}
    if probeConfig.Enabled ~= true then return 0, 0, 0 end

    if not IsValidObject(mapBase) then
        AppendOverlayMarkersLog("Skipped temp marker probe: no live map base available")
        return 0, 0, 1
    end

    local worldLocation = MakeLocationNearPlayer(dataState and dataState.PlayerAnchor or nil, probeConfig)
    if not worldLocation then
        AppendOverlayMarkersLog("Skipped temp marker probe: invalid player-relative location")
        return 0, 0, 1
    end

    local entryPoint = tostring(probeConfig.EntryPoint or "AddCustomIcon")
    local iconsBefore = CollectCustomMapIconObjects()
    local beforeAddresses = {}
    for _, icon in ipairs(iconsBefore) do
        beforeAddresses[GetObjectAddress(icon)] = true
    end

    local filterOk, filterDetail = TryCallChangeFilter(mapBase, "EPalLocationType::CustomMarker", true)
    AppendOverlayMarkersLog("Change custom marker filter before probe ok=" .. tostring(filterOk) .. " detail=" .. tostring(filterDetail))

    local added = false
    local detail = nil
    local markerData = nil
    if entryPoint == "AddTempMarker" then
        added, detail = TryCallAddTempMarker(mapBase, worldLocation)
    else
        local locationId = MakeGuidCandidate(math.floor(os.clock() * 1000000))
        markerData = MakeCustomMarkerSaveData(worldLocation, probeConfig.IconType or 0)
        added, detail = TryCallAddCustomIcon(mapBase, locationId, markerData)
    end

    local filterAfterOk, filterAfterDetail = TryCallChangeFilter(mapBase, "EPalLocationType::CustomMarker", true)
    AppendOverlayMarkersLog("Change custom marker filter after probe ok=" .. tostring(filterAfterOk) .. " detail=" .. tostring(filterAfterDetail))

    local iconsAfter = CollectCustomMapIconObjects()
    AppendOverlayMarkersLog(string.format(
        "Add temp marker probe key=%s entry=%s mapBase=%s added=%s detail=%s iconType=%s iconsBefore=%d iconsAfter=%d loc=(%.1f, %.1f, %.1f)",
        tostring(probeConfig.Id or "temp_marker_probe"),
        tostring(entryPoint),
        GetObjectName(mapBase),
        tostring(added),
        tostring(detail),
        tostring(probeConfig.IconType),
        #iconsBefore,
        #iconsAfter,
        worldLocation.X or 0,
        worldLocation.Y or 0,
        worldLocation.Z or 0
    ))

    local iconScanDetail = DescribeCustomMapIconObjects("customIconScan", iconsAfter, beforeAddresses, mapBody, markerData)
    if iconScanDetail ~= "" then
        AppendOverlayMarkersLog(iconScanDetail)
    end

    if added then return 1, 1, 0 end
    return 1, 0, 0
end

function MapController.GenerateOverlayMarkers(staticMarkerData, dataState, mapBaseOverride)
    local overlayConfig = Config.OverlayMarkers or {}
    if not overlayConfig.Enabled then return true end
    if type(staticMarkerData) ~= "table" then return false end
    if not dataState or not dataState.PlayerAnchor then return false end

    RefreshOverlaySourceCategoryCounts(staticMarkerData)

    AppendOverlayMarkersLog("Overlay marker generation requested")
    local mapBase = mapBaseOverride
    if not IsValidObject(mapBase) then
        mapBase = MapController.FindLiveMapBase()
    end
    AppendOverlayMarkersLog("Overlay marker generation live map base=" .. GetObjectName(mapBase))

    local mapBody = nil
    local currentMapBody, currentMapBodyDetail = GetCurrentMapBodyFromMapBase(mapBase)
    if IsValidObject(currentMapBody) then
        mapBody = currentMapBody
        AppendOverlayMarkersLog("Overlay marker generation using current map body from map base: " .. GetObjectName(mapBody))
    else
        AppendOverlayMarkersLog("Overlay marker generation finding live map body")
        mapBody = MapController.FindLiveMapBody()
        AppendOverlayMarkersLog("Overlay marker generation using scanned map body fallback detail=" .. tostring(currentMapBodyDetail))
    end
    if not IsValidObject(mapBody) then
        AppendOverlayMarkersLog("Skipped: no live map body available")
        return false
    end

    local panelOk, panelErr = pcall(function()
        MapController.EnsureOverlayFilterPanel(mapBase)
    end)
    if not panelOk then
        AppendOverlayMarkersLog("Filter panel error: " .. tostring(panelErr))
    end

    local address = GetObjectAddress(mapBody)
    if type(OverlayLazyContext) ~= "table" or OverlayLazyContext.MapBodyAddress ~= address then
        OverlayIconRecords = {}
        OverlayLazyCategoryState = {}
        OverlayLazyQueue = {}
        OverlayLazyQueued = {}
        OverlayLazyActiveCategory = nil
        SetOverlayFilterPanelProgress(nil)
    end

    OverlayLazyContext = {
        StaticMarkerData = staticMarkerData,
        DataState = dataState,
        MapBase = mapBase,
        MapBody = mapBody,
        MapBodyAddress = address,
        OverlayConfig = overlayConfig,
        NativeStaticConfig = overlayConfig.NativeStaticMarkers or {},
        LogEachMarker = ((overlayConfig.LazyCreate or {}).LogEachMarker == true)
    }

    if OverlayInjectedMapBodyAddresses[address] then return true end
    OverlayInjectedMapBodyAddresses[address] = true

    local maxPerCategory = tonumber(overlayConfig.MaxPerCategory) or 100
    local maxTotal = tonumber(overlayConfig.MaxTotal) or 0
    local ignoreMask = overlayConfig.IgnoreMask == true
    local toPriority = overlayConfig.ToPriority == true
    local nativeStaticConfig = overlayConfig.NativeStaticMarkers or {}
    local attempted = 0
    local addedCount = 0
    local skippedCount = 0
    local stopAll = false

    AppendOverlayMarkersLog("Overlay marker generation started for " .. GetObjectName(mapBody))
    AppendOverlayMarkersLog("Options ignoreMask=" .. tostring(ignoreMask) .. " toPriority=" .. tostring(toPriority) .. " maxPerCategory=" .. tostring(maxPerCategory) .. " maxTotal=" .. tostring(maxTotal))

    local lazyConfig = overlayConfig.LazyCreate or {}
    if lazyConfig.Enabled == true then
        RefreshOverlayFilterPanelCategory(nil)
        AppendOverlayMarkersLog("Overlay lazy creation armed for " .. GetObjectName(mapBody))
        local autoShowConfig = overlayConfig.AutoShowOnOpen or {}
        if autoShowConfig.Enabled == true then
            for _, categoryName in ipairs(autoShowConfig.Categories or {}) do
                if type(categoryName) == "string" and categoryName ~= "" then
                    OverlayRuntimeFilterState[categoryName] = true
                    AppendOverlayMarkersLog("Auto-show category on map open category=" .. tostring(categoryName))
                    EnsureOverlayCategoryIconsGenerated(categoryName)
                end
            end
        end
        for categoryName, visible in pairs(OverlayRuntimeFilterState) do
            if visible == true then
                EnsureOverlayCategoryIconsGenerated(categoryName)
            end
        end
        print("[+] [OVERLAY_MARKERS] lazy creation armed")
        return true
    end

    local nativeAttempted, nativeAdded, nativeSkipped = GenerateNativeIconProbe(mapBase, mapBody, dataState)
    attempted = attempted + nativeAttempted
    addedCount = addedCount + nativeAdded
    skippedCount = skippedCount + nativeSkipped

    local lmAttempted, lmAdded, lmSkipped = GenerateLocationManagerProbe(mapBase, dataState)
    attempted = attempted + lmAttempted
    addedCount = addedCount + lmAdded
    skippedCount = skippedCount + lmSkipped

    local tempAttempted, tempAdded, tempSkipped = GenerateTempMarkerProbe(mapBase, mapBody, dataState)
    attempted = attempted + tempAttempted
    addedCount = addedCount + tempAdded
    skippedCount = skippedCount + tempSkipped

    local debugAttempted, debugAdded, debugSkipped = GenerateDebugOverlayMarkers(mapBody, dataState, ignoreMask, toPriority)
    attempted = attempted + debugAttempted
    addedCount = addedCount + debugAdded
    skippedCount = skippedCount + debugSkipped

    local orderedCategories = BuildOverlayCategoryOrder(staticMarkerData, overlayConfig)
    for _, categoryName in ipairs(orderedCategories) do
        local markers = staticMarkerData[categoryName]
        if type(markers) == "table" then
            local shouldGenerateCategory = overlayConfig.GenerateHiddenCategories ~= false or IsOverlayMarkerCategoryEnabled(categoryName)
            if shouldGenerateCategory then
                local categoryCount = 0
                local categoryLimit = GetOverlayCategoryLimit(categoryName, overlayConfig, maxPerCategory)

                if categoryLimit <= 0 then
                    skippedCount = skippedCount + #markers
                    AppendOverlayMarkersLog("Category capped by config: " .. tostring(categoryName) .. " max=0 count=" .. tostring(#markers))
                elseif nativeStaticConfig.Enabled ~= true then
                    skippedCount = skippedCount + #markers
                    AppendOverlayMarkersLog("Category enabled but native static marker route disabled: " .. tostring(categoryName) .. " count=" .. tostring(#markers))
                else
                    local dedupedMarkers = DeduplicateOverlayMarkersByLocation(categoryName, markers, dataState)
                    skippedCount = skippedCount + math.max(0, #markers - #dedupedMarkers)
                    local sourceMarkers = SelectOverlayCategoryMarkers(dedupedMarkers, dataState, categoryLimit, overlayConfig, nativeStaticConfig)
                    for _, marker in ipairs(sourceMarkers) do
                        if maxTotal > 0 and attempted >= maxTotal then
                            AppendOverlayMarkersLog("Overlay total cap reached maxTotal=" .. tostring(maxTotal))
                            stopAll = true
                            break
                        end

                        categoryCount = categoryCount + 1
                        if categoryCount > categoryLimit then
                            AppendOverlayMarkersLog("Category capped: " .. tostring(categoryName) .. " max=" .. tostring(categoryLimit))
                            break
                        end

                        local key = MakeStaticMarkerKey(categoryName, marker)
                        local worldLocation = MakeLocationFromStaticMarker(dataState.PlayerAnchor, marker)
                        if not worldLocation then
                            skippedCount = skippedCount + 1
                            AppendOverlayMarkersLog("Skipped invalid location category=" .. tostring(categoryName) .. " key=" .. tostring(key))
                        else
                            local staticWorldLocation = {
                                X = worldLocation.X or 0,
                                Y = worldLocation.Y or 0,
                                Z = worldLocation.Z or 0
                            }
                            if nativeStaticConfig.ForcePlayerRelativeLocation == true then
                                local forcedLocation = MakeLocationNearPlayer(dataState.PlayerAnchor, nativeStaticConfig.PlayerRelativeLocation or {})
                                if forcedLocation then
                                    worldLocation = forcedLocation
                                    AppendOverlayMarkersLog(string.format(
                                        "Native static display location forced near player category=%s key=%s staticLoc=(%.1f, %.1f, %.1f) displayLoc=(%.1f, %.1f, %.1f)",
                                        tostring(categoryName),
                                        tostring(key),
                                        staticWorldLocation.X or 0,
                                        staticWorldLocation.Y or 0,
                                        staticWorldLocation.Z or 0,
                                        worldLocation.X or 0,
                                        worldLocation.Y or 0,
                                        worldLocation.Z or 0
                                    ))
                                else
                                    AppendOverlayMarkersLog("Native static player-relative display override failed category=" .. tostring(categoryName) .. " key=" .. tostring(key))
                                end
                            end
                            local setupIconType = GetNativeStaticSetupIconType(categoryName)
                            local targetMapBody = mapBody
                            local targetMapBodyDetail = "current-live-map-body"
                            if nativeStaticConfig.UseMapBodyRouter == true then
                                targetMapBody, targetMapBodyDetail = GetMapBodyByWorldLocation(mapBase, worldLocation)
                            end
                            if not IsValidObject(targetMapBody) then
                                targetMapBody = mapBody
                                targetMapBodyDetail = tostring(targetMapBodyDetail) .. " fallback-current-live-map-body"
                            end
                            AppendOverlayMarkersLog(string.format(
                                "Native static about to add category=%s key=%s setupIconType=%d bodySource=%s body=%s loc=(%.1f, %.1f, %.1f)",
                                tostring(categoryName),
                                tostring(key),
                                setupIconType,
                                tostring(targetMapBodyDetail),
                                GetObjectName(targetMapBody),
                                worldLocation.X or 0,
                                worldLocation.Y or 0,
                                worldLocation.Z or 0
                            ))
                            local iconOptions = {
                                CallUpdateMapIcon = nativeStaticConfig.CallUpdateMapIcon,
                                PreStepLog = nativeStaticConfig.PreStepLog == true,
                                TextureCategoryName = categoryName,
                                TextureMarker = marker
                            }
                            if type(nativeStaticConfig.IconScaleByCategory) == "table" then
                                iconOptions.IconScale = nativeStaticConfig.IconScaleByCategory[categoryName]
                            end
                            if type(nativeStaticConfig.IconRenderOffsetByCategory) == "table" then
                                iconOptions.IconRenderOffset = nativeStaticConfig.IconRenderOffsetByCategory[categoryName]
                            end
                            local added, detail, icon = TryCreateNativeWorldMapIcon(mapBase, targetMapBody, worldLocation, setupIconType, iconOptions)
                            attempted = attempted + 1

                            AppendOverlayMarkersLog(string.format(
                                "Add native static category=%s key=%s setupIconType=%d added=%s detail=%s icon=%s bodySource=%s body=%s staticLoc=(%.1f, %.1f, %.1f) loc=(%.1f, %.1f, %.1f)",
                                tostring(categoryName),
                                tostring(key),
                                setupIconType,
                                tostring(added),
                                tostring(detail),
                                IsValidObject(icon) and GetObjectName(icon) or "nil",
                                tostring(targetMapBodyDetail),
                                GetObjectName(targetMapBody),
                                staticWorldLocation.X or 0,
                                staticWorldLocation.Y or 0,
                                staticWorldLocation.Z or 0,
                                worldLocation.X or 0,
                                worldLocation.Y or 0,
                                worldLocation.Z or 0
                            ))

                            if added then
                                addedCount = addedCount + 1
                                RememberOverlayIcon(categoryName, key, icon)
                            else
                                skippedCount = skippedCount + 1
                            end
                        end
                    end
                end
            else
                skippedCount = skippedCount + #markers
                AppendOverlayMarkersLog("Category disabled by filter: " .. tostring(categoryName) .. " count=" .. tostring(#markers))
            end
        end
        if stopAll then break end
    end

    if addedCount > 0 and nativeStaticConfig.CallUpdateMapIconsAtEnd ~= false then
        local updateOk, updateDetail = TryCallUpdateMapIcons(mapBody)
        AppendOverlayMarkersLog("Native static final Update Map Icons ok=" .. tostring(updateOk) .. " detail=" .. tostring(updateDetail))
    end

    RefreshOverlayFilterPanelCategory(nil)

    AppendOverlayMarkersLog(string.format(
        "Overlay marker generation finished attempted=%d added=%d skipped=%d",
        attempted,
        addedCount,
        skippedCount
    ))
    print(string.format("[+] [OVERLAY_MARKERS] attempted=%d added=%d skipped=%d", attempted, addedCount, skippedCount))
    return true
end

function MapController.InjectCustomMarkerTest(characterData)
    if not Config.EnableCustomMarkerInjection then return end
    if not characterData then return end

    local mapBase = MapController.FindLiveMapBase()
    if not IsValidObject(mapBase) then return end

    local locationManager, locationManagerSource = FindLocationManager()
    if not IsValidObject(locationManager) then
        AppendCustomMarkerInjectionLog("Skipped: no location manager available: " .. tostring(locationManagerSource))
        return
    end

    local address = GetObjectAddress(mapBase)
    if CustomMarkerInjectedMapBaseAddresses[address] then return end
    CustomMarkerInjectedMapBaseAddresses[address] = true

    AppendCustomMarkerInjectionLog("Injection attempt for " .. GetObjectName(mapBase))
    AppendCustomMarkerInjectionLog("Location manager: " .. GetObjectName(locationManager) .. " source=" .. tostring(locationManagerSource))

    local anchor = characterData and characterData.PlayerAnchor or nil
    if not anchor then
        AppendCustomMarkerInjectionLog("Skipped: no player anchor available")
        return
    end

    local baseOffset = Config.NativeInjectionOffset or {}
    local markerOffsets = {
        { X = 25000.0, Y = 25000.0, IconIndex = 0 },
        { X = 50000.0, Y = 25000.0, IconIndex = 1 },
        { X = 25000.0, Y = 50000.0, IconIndex = 2 },
        { X = 0.0, Y = 25000.0, IconIndex = 3 },
        { X = 25000.0, Y = 0.0, IconIndex = 4 }
    }

    local injected = 0
    local maxIcons = Config.CustomMarkerInjectionCount or #markerOffsets

    for index, markerOffset in ipairs(markerOffsets) do
        if index > maxIcons then break end

        local worldLocation = nil
        pcall(function()
            worldLocation = anchor.Instance:K2_GetActorLocation()
        end)
        if not worldLocation then
            AppendCustomMarkerInjectionLog("Skipped marker " .. tostring(index) .. ": could not read player location")
            break
        end

        pcall(function()
            worldLocation.X = worldLocation.X + (baseOffset.X or 0) + markerOffset.X
            worldLocation.Y = worldLocation.Y + (baseOffset.Y or 0) + markerOffset.Y
            worldLocation.Z = worldLocation.Z + (baseOffset.Z or 0)
        end)

        local added, detail = TryCallAddLocalCustomMarker(locationManager, worldLocation, markerOffset.IconIndex)
        AppendCustomMarkerInjectionLog(string.format(
            "AddLocalCustomMarker marker=%d IconIndex=%d | added=%s | detail=%s | loc=(%.1f, %.1f, %.1f)",
            index,
            markerOffset.IconIndex,
            tostring(added),
            tostring(detail),
            worldLocation.X or 0,
            worldLocation.Y or 0,
            worldLocation.Z or 0
        ))

        if added then
            injected = injected + 1
        end
    end

    if injected > 0 then
        pcall(function()
            if mapBase.SetupCustomIcons then mapBase:SetupCustomIcons() end
        end)
        print("[+] [CUSTOM_MARKER_INJECT] Custom marker injection attempted successfully: " .. tostring(injected))
    else
        print("[!] [CUSTOM_MARKER_INJECT] Custom marker injection failed.")
    end
end

function MapController.ProbeWorldMapWidgets()
    if not Config.EnableMapWidgetProbe then return end

    local now = os.clock()
    if now - LastProbeTime < Config.MapProbeInterval then return end
    LastProbeTime = now

    for _, className in ipairs(Config.WorldMapWidgetCandidates) do
        local objects = nil
        pcall(function()
            objects = FindAllOf(className)
        end)

        WriteSafeProbeSummary(className, objects)
    end

    MapController.ProbeMapBodyBridge()
end

function MapController.UnleashStaticFilters(nativeMapWidget)
    -- Intentionally empty for now. Deep Widget reflection caused UE4SS native
    -- access violations in Palworld, so the next phase should use console
    -- dump_object manually or FModel data instead of recursive Lua probing.
end

function MapController.InjectDynamicAvatars(nativeMapWidget, characterData)
    if not IsValidObject(nativeMapWidget) then return end
    if not characterData then return end
    if not Config.EnableNativeMapInjection then return end

    local address = GetObjectAddress(nativeMapWidget)
    if InjectedMapBodyAddresses[address] then return end
    InjectedMapBodyAddresses[address] = true

    AppendInjectionLog("Injection attempt for " .. GetObjectName(nativeMapWidget))

    local worldLocation = GetInjectionLocation(characterData)
    if not worldLocation then
        AppendInjectionLog("Skipped: no player anchor available")
        return
    end

    local widget, source = ConstructIconWidget(nativeMapWidget)
    if not IsValidObject(widget) then
        AppendInjectionLog("Skipped: could not construct icon widget: " .. tostring(source))
        print("[!] [MAP_INJECT] Could not construct test icon: " .. tostring(source))
        return
    end

    local added, detail = TryCallAddIconByLocation(nativeMapWidget, widget, worldLocation)
    AppendInjectionLog(string.format(
        "Add Icon By Location | added=%s | detail=%s | loc=(%.1f, %.1f, %.1f)",
        tostring(added),
        tostring(detail),
        worldLocation.X or 0,
        worldLocation.Y or 0,
        worldLocation.Z or 0
    ))

    if added then
        print("[+] [MAP_INJECT] Test map icon injection attempted successfully.")
    else
        print("[!] [MAP_INJECT] Test map icon injection failed: " .. tostring(detail))
    end
end

return MapController
