-- ui_manager.lua
local Config = require("config")
local MapController = require("map_controller")
local StaticMarkers = require("static_markers")

local UIManager = {}
local UnpackArgs = table.unpack or unpack

local IsRadarActive = false
local IsMapHookRegistered = false
local IsMapHookRetryLoopActive = false
local CompletedMapStaticPassKeys = {}
local IsOverlayFilterHotkeysRegistered = false
local IsOverlayFilterMouseRegistered = false
local IsMapToggleCleanupRegistered = false
local LastMapHookFailureLogTime = 0
local LastMapHookDisabledLogTime = 0
local LastMapPollingLogTime = 0
local LastObservedMapBaseKey = nil
local LastMapStaticPassAt = 0
local LastMapToggleCleanupAt = 0
local LastTelemetryTime = 0
local LastScanTime = 0
local LastPacket = nil
local DataProvider = nil

local function LogSafeError(label, err)
    print("[!] [UI_MANAGER] " .. tostring(label) .. " failed: " .. tostring(err))
end

local function SafeExecuteInGameThread(label, callback)
    local ok, err = pcall(function()
        ExecuteInGameThread(function()
            local innerOk, innerErr = pcall(callback)
            if not innerOk then
                LogSafeError(label, innerErr)
            end
        end)
    end)

    if not ok then
        LogSafeError(label .. ":schedule", err)
    end
end

local function GetMapWidgetHookMode()
    local overlayConfig = Config.OverlayMarkers or {}
    local cleanupConfig = overlayConfig.Cleanup or {}
    local mode = Config.MapWidgetHookMode or cleanupConfig.MapWidgetHookMode or "polling"
    return string.lower(tostring(mode))
end

local function ShouldRegisterMapWidgetHooks()
    local mode = GetMapWidgetHookMode()
    return mode == "hook" or mode == "hooks" or mode == "registerhook"
end

local function LogPollingProbe(message)
    local interval = Config.MapHookPollingLogInterval or 8.0
    local now = os.clock()
    if now - LastMapPollingLogTime >= interval then
        LastMapPollingLogTime = now
        print("[+] [UI_MANAGER] " .. tostring(message))
    end
end

local function IsValidObject(obj)
    local ok, result = pcall(function()
        return obj and obj:IsValid()
    end)
    return ok and result
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

local function SafeCall(obj, funcName, ...)
    if not IsValidObject(obj) then return nil end
    local args = { ... }
    local ok, result = pcall(function()
        return obj[funcName](obj, UnpackArgs(args))
    end)
    if ok then return result end
    return nil
end

local function GetObjectKey(obj)
    if not IsValidObject(obj) then return nil end

    local ok, fullName = pcall(function()
        if obj.GetFullName then return obj:GetFullName() end
        return nil
    end)
    if ok and fullName and fullName ~= "" then return tostring(fullName) end

    ok, fullName = pcall(function()
        if obj.GetPathName then return obj:GetPathName() end
        return nil
    end)
    if ok and fullName and fullName ~= "" then return tostring(fullName) end

    return tostring(obj)
end

local function GetActiveWorldContext()
    local context = FindFirstOf("BP_PalPlayerCharacter_C")
    if not IsValidObject(context) then
        context = FindFirstOf("PalPlayerCharacter")
    end
    return context
end

local function SetCustomDepth(actor)
    if not Config.DebugCustomDepth then return end

    local mesh = nil
    pcall(function()
        mesh = actor.Mesh
    end)
    if not IsValidObject(mesh) then
        mesh = SafeCall(actor, "GetProperty", "Mesh")
    end

    if IsValidObject(mesh) then
        pcall(function()
            mesh:SetRenderCustomDepth(true)
            mesh:SetCustomDepthStencilValue(1)
        end)
    end
end

local function DrawWorldLabel(kismet, contextObject, actor, entry)
    if not Config.DebugWorldLabels then return end

    local distance = SafeCall(actor, "GetDistanceTo", contextObject)
    if not distance or (distance / 100) > Config.DebugLabelRangeMeters then return end

    local coords = SafeCall(actor, "K2_GetActorLocation")
    if not coords then return end

    pcall(function()
        coords.Z = coords.Z + 100
    end)

    local label = string.format("[%s] %s (%.1fm)", entry.Kind or "Pal", entry.Name or "Unknown", distance / 100)
    pcall(function()
        kismet:DrawDebugString(contextObject, coords, label, nil, { R = 0.0, G = 1.0, B = 1.0, A = 1.0 }, 0.1)
    end)
end

local function RefreshDataPacket(now)
    if now - LastScanTime < Config.ScanInterval and LastPacket then return LastPacket end
    LastScanTime = now

    if type(DataProvider) ~= "function" then return nil end

    local ok, playerAnchor, packet = pcall(DataProvider)
    if ok then
        LastPacket = {
            PlayerAnchor = playerAnchor,
            Packet = packet
        }
    end

    return LastPacket
end

local function BuildDataState()
    if type(DataProvider) ~= "function" then return nil end

    local ok, playerAnchor, packet = pcall(DataProvider)
    if not ok then return nil end

    return {
        PlayerAnchor = playerAnchor,
        Packet = packet
    }
end

local function RunMapStaticPass(mapBase, source)
    mapBase = UnwrapParam(mapBase)
    if not IsValidObject(mapBase) then return end

    local mapKey = GetObjectKey(mapBase)
    if mapKey and CompletedMapStaticPassKeys[mapKey] == true then return end

    local dataState = BuildDataState()
    if not dataState or not dataState.PlayerAnchor then
        print("[MAP_INTEL] Map hook fired but player anchor is not ready: " .. tostring(source))
        return
    end

    MapController.GenerateStaticMarkers(StaticMarkers, dataState, mapBase)
    local overlayComplete = MapController.GenerateOverlayMarkers(StaticMarkers, dataState, mapBase)
    if Config.OverlayMarkers and Config.OverlayMarkers.Enabled and overlayComplete ~= true then
        print("[MAP_INTEL] Map static pass waiting for overlay map body: " .. tostring(source))
        return
    end

    if mapKey then CompletedMapStaticPassKeys[mapKey] = true end
    LastMapStaticPassAt = os.clock()
    print("[+] [UI_MANAGER] Map static pass complete: " .. tostring(source))
end

local function ResetMapInjectionGuards()
    CompletedMapStaticPassKeys = {}
    LastObservedMapBaseKey = nil
end

local function TryRunMapStaticPassFromLiveWidget(source)
    local contextObject = GetActiveWorldContext()
    if not IsValidObject(contextObject) then
        if LastObservedMapBaseKey ~= nil then
            MapController.ResetOverlayUiState("player-context-gone:" .. tostring(source))
            ResetMapInjectionGuards()
        end
        return false
    end

    local mapBase = MapController.FindLiveMapBase()
    if not IsValidObject(mapBase) then
        if LastObservedMapBaseKey ~= nil then
            MapController.ResetOverlayUiState("live-map-gone:" .. tostring(source))
            ResetMapInjectionGuards()
        end
        return false
    end

    local mapKey = GetObjectKey(mapBase)
    if LastObservedMapBaseKey ~= nil and mapKey ~= nil and mapKey ~= LastObservedMapBaseKey then
        MapController.ResetOverlayUiState("live-map-changed:" .. tostring(source))
        ResetMapInjectionGuards()
    end
    LastObservedMapBaseKey = mapKey

    local ok, err = pcall(function()
        RunMapStaticPass(mapBase, source)
    end)
    if not ok then
        LogSafeError("map-static-pass:" .. tostring(source), err)
        return false
    end
    return true
end

local function RegisterMapWidgetHooks()
    if IsMapHookRegistered then return end
    if not ShouldRegisterMapWidgetHooks() then
        local now = os.clock()
        if now - LastMapHookDisabledLogTime >= 10.0 then
            LastMapHookDisabledLogTime = now
            print("[+] [UI_MANAGER] Map widget RegisterHook disabled; using polling detection.")
        end
        return
    end

    local overlayConfig = Config.OverlayMarkers or {}
    local cleanupConfig = overlayConfig.Cleanup or {}
    local registerDestructHook = cleanupConfig.RegisterMapDestructHook ~= false

    local openHookPaths = {
        "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:OnInitialized",
        "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:OnInitialized",
        "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:OnInitialized",
        "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:OnInitialized",
        "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:Construct",
        "Function /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:Construct",
        "Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:Construct",
        "Function Pal/Content/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:Construct"
    }

    local closeHookPaths = {}
    if registerDestructHook then
        closeHookPaths = {
            "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:Destruct"
        }
    end

    local openRegistered = 0
    local closeRegistered = 0
    local errors = {}
    for _, hookPath in ipairs(openHookPaths) do
        local ok, err = pcall(function()
            local preId, postId = RegisterHook(hookPath, function(self)
                SafeExecuteInGameThread("map-open:" .. tostring(hookPath), function()
                    RunMapStaticPass(self, hookPath)
                end)
            end)
            return preId, postId
        end)

        if ok then
            openRegistered = openRegistered + 1
        else
            errors[#errors + 1] = tostring(hookPath) .. " => " .. tostring(err)
        end
    end

    for _, hookPath in ipairs(closeHookPaths) do
        local ok, err = pcall(function()
            local preId, postId = RegisterHook(hookPath, function()
                pcall(function()
                    ResetMapInjectionGuards()
                    MapController.ResetOverlayUiState("map-widget-close:" .. tostring(hookPath))
                end)
            end)
            return preId, postId
        end)

        if ok then
            closeRegistered = closeRegistered + 1
        else
            errors[#errors + 1] = tostring(hookPath) .. " => " .. tostring(err)
        end
    end

    if openRegistered > 0 then
        IsMapHookRegistered = true
        print("[+] [UI_MANAGER] Map widget hooks registered: open=" .. tostring(openRegistered) .. " close=" .. tostring(closeRegistered))
    else
        local now = os.clock()
        if now - LastMapHookFailureLogTime >= 10.0 then
            LastMapHookFailureLogTime = now
            print("[!] [UI_MANAGER] Could not register map widget hooks. First error: " .. tostring(errors[1]))
        end
    end
end

local function StartMapHookRetryLoop()
    if IsMapHookRetryLoopActive then return end

    IsMapHookRetryLoopActive = true
    LoopAsync(Config.MapHookRetryMs or 2000, function()
        if not IsRadarActive then return true end

        SafeExecuteInGameThread("map-hook-retry", function()
            if ShouldRegisterMapWidgetHooks() and not IsMapHookRegistered then
                RegisterMapWidgetHooks()
            end

            if not IsMapHookRegistered then
                local found = TryRunMapStaticPassFromLiveWidget("poll-live-map-widget")
                if found then
                    LogPollingProbe("Polling map detection found a live map widget.")
                else
                    LogPollingProbe("Polling map detection is waiting for a live map widget.")
                end
            end
        end)

        return false
    end)
end

local function RegisterOverlayFilterHotkeys()
    if IsOverlayFilterHotkeysRegistered then return end

    local overlayConfig = Config.OverlayMarkers or {}
    local runtimeFilters = overlayConfig.RuntimeFilters or {}
    if runtimeFilters.Enabled ~= true then return end
    if RegisterKeyBind == nil or Key == nil then
        print("[!] [UI_MANAGER] Overlay filter hotkeys unavailable.")
        return
    end

    local registered = 0
    local function registerOne(keyName, callback, label)
        if not keyName or keyName == "" then return end

        local normalized = string.upper(tostring(keyName))
        local keyValue = Key[normalized]
        if not keyValue then
            print("[!] [UI_MANAGER] Overlay filter key not found: " .. tostring(normalized) .. " for " .. tostring(label))
            return
        end

        local ok, err = pcall(function()
            RegisterKeyBind(keyValue, callback)
        end)
        if ok then
            registered = registered + 1
            print("[+] [UI_MANAGER] Overlay filter key registered: " .. tostring(normalized) .. " => " .. tostring(label))
        else
            print("[!] [UI_MANAGER] Overlay filter key failed: " .. tostring(normalized) .. " => " .. tostring(err))
        end
    end

    for _, hotkeySpec in ipairs(runtimeFilters.Hotkeys or {}) do
        local categories = hotkeySpec.Categories or { hotkeySpec.Category }
        local label = hotkeySpec.Label or hotkeySpec.Category
        local boundCategories = categories
        local boundLabel = label
        registerOne(hotkeySpec.Key, function()
            SafeExecuteInGameThread("filter-hotkey:" .. tostring(boundLabel), function()
                local firstCategory = boundCategories[1]
                local visible = nil
                if firstCategory then
                    visible = MapController.ToggleOverlayCategoryVisibility(firstCategory)
                end
                for index = 2, #boundCategories do
                    MapController.SetOverlayCategoryVisibility(boundCategories[index], visible == true)
                end
                print("[+] [OVERLAY_FILTER] hotkey group " .. tostring(boundLabel) .. "=" .. tostring(visible == true and "ON" or "OFF"))
            end)
        end, label)
    end

    registerOne(runtimeFilters.ShowAllKey, function()
        SafeExecuteInGameThread("filter-toggle-all", function()
            if MapController.ToggleAllOverlayCategoriesVisibility then
                MapController.ToggleAllOverlayCategoriesVisibility()
            else
                MapController.ShowAllOverlayCategories()
            end
        end)
    end, "ToggleAll")

    local panelConfig = overlayConfig.FilterPanel or {}
    if panelConfig.Enabled == true and panelConfig.MouseClickEnabled == true and not IsOverlayFilterMouseRegistered then
        local mouseKey = Key.LEFT_MOUSE_BUTTON or Key.LeftMouseButton or Key.LMB or Key.LeftMouse
        if mouseKey then
            local ok, err = pcall(function()
                RegisterKeyBind(mouseKey, function()
                    local clickOk, clickErr = pcall(function()
                        if MapController.HandleOverlayFilterPanelClick then
                            MapController.HandleOverlayFilterPanelClick()
                        end
                    end)
                    if not clickOk then
                        LogSafeError("filter-panel-click", clickErr)
                    end
                end)
            end)
            if ok then
                IsOverlayFilterMouseRegistered = true
                registered = registered + 1
                print("[+] [UI_MANAGER] Overlay filter mouse click registered.")
            else
                print("[!] [UI_MANAGER] Overlay filter mouse click failed: " .. tostring(err))
            end
        else
            print("[!] [UI_MANAGER] Overlay filter mouse key unavailable.")
        end
    end

    if registered > 0 then
        IsOverlayFilterHotkeysRegistered = true
    end
end

local function RegisterMapToggleCleanupKey()
    if IsMapToggleCleanupRegistered then return end
    local overlayConfig = Config.OverlayMarkers or {}
    local cleanupConfig = overlayConfig.Cleanup or {}
    if cleanupConfig.RegisterMapToggleKey == false then return end
    if RegisterKeyBind == nil or Key == nil then return end

    local keyValue = Key.M
    if not keyValue then
        print("[!] [UI_MANAGER] Map toggle cleanup key unavailable: M")
        return
    end

    local ok, err = pcall(function()
        RegisterKeyBind(keyValue, function()
            SafeExecuteInGameThread("map-toggle-cleanup", function()
                local now = os.clock()
                if now - LastMapToggleCleanupAt < 0.5 then return end
                if now - LastMapStaticPassAt < 0.75 then return end
                LastMapToggleCleanupAt = now

                ResetMapInjectionGuards()
                if MapController.PrepareForMapToggle then
                    MapController.PrepareForMapToggle("key-M")
                end
            end)
        end)
    end)

    if ok then
        IsMapToggleCleanupRegistered = true
        print("[+] [UI_MANAGER] Map toggle cleanup key registered: M")
    else
        print("[!] [UI_MANAGER] Map toggle cleanup key failed: " .. tostring(err))
    end
end

local function ShouldStartDynamicLoop()
    return Config.EnableMapWidgetProbe == true
        or Config.EnableNativeMapInjection == true
        or Config.EnableNativeMapHookTrace == true
        or Config.EnableCustomMarkerHookTrace == true
        or Config.EnableCustomMarkerInjection == true
        or Config.DebugWorldLabels == true
        or Config.DebugCustomDepth == true
end

local function ExecuteTacticalRenderFrame()
    local now = os.clock()
    local contextObject = GetActiveWorldContext()
    if not IsValidObject(contextObject) then return end

    MapController.ProbeWorldMapWidgets()
    MapController.TryRegisterNativeMapHookTrace()
    MapController.TryRegisterCustomMarkerHookTrace()

    local kismet = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    local dataState = RefreshDataPacket(now)
    local packet = dataState and dataState.Packet or nil

    if Config.EnableNativeMapInjection then
        local mapBody = MapController.FindLiveMapBody()
        if IsValidObject(mapBody) then
            MapController.InjectDynamicAvatars(mapBody, dataState)
        end
    end

    MapController.InjectCustomMarkerTest(dataState)
    local mapBase = MapController.FindLiveMapBase()
    MapController.GenerateStaticMarkers(StaticMarkers, dataState, mapBase)
    MapController.GenerateOverlayMarkers(StaticMarkers, dataState, mapBase)

    if packet and type(packet.Characters) == "table" then
        for _, entry in ipairs(packet.Characters) do
            local actor = entry.Instance
            if IsValidObject(actor) then
                SetCustomDepth(actor)
                if kismet then
                    DrawWorldLabel(kismet, contextObject, actor, entry)
                end
            end
        end
    end

    if now - LastTelemetryTime >= Config.TelemetryInterval then
        LastTelemetryTime = now
        local count = 0
        if packet and packet.ScanStats then
            count = packet.ScanStats.AllowedCharacterCount or 0
        end
        local probeState = Config.EnableMapWidgetProbe and "probe:on" or "probe:off"
        print(string.format("[MAP_INTEL] Stable | filtered dynamic actors: %d | %s", count, probeState))
    end
end

function UIManager.InitializeRadarLoop(dataProvider)
    if IsRadarActive then return end

    DataProvider = dataProvider
    IsRadarActive = true
    local overlayConfig = Config.OverlayMarkers or {}
    local cleanupConfig = overlayConfig.Cleanup or {}
    print("[+] [UI_MANAGER] Cleanup config: destructHook="
        .. tostring(cleanupConfig.RegisterMapDestructHook ~= false)
        .. " mapToggleKey=" .. tostring(cleanupConfig.RegisterMapToggleKey ~= false)
        .. " removeWidgetsOnMapClose=" .. tostring(cleanupConfig.RemoveWidgetsOnMapClose ~= false))
    print("[+] [UI_MANAGER] Map widget hook mode=" .. tostring(GetMapWidgetHookMode()))
    RegisterMapWidgetHooks()
    RegisterOverlayFilterHotkeys()
    RegisterMapToggleCleanupKey()
    StartMapHookRetryLoop()

    if not ShouldStartDynamicLoop() then
        print("[+] [UI_MANAGER] Dynamic scan loop is disabled; map hook retry loop is active.")
        return
    end

    print("[+] [UI_MANAGER] Dynamic scan loop armed.")

    LoopAsync(Config.RefreshRateMs, function()
        if not IsRadarActive then return true end
        SafeExecuteInGameThread("dynamic-render-frame", function()
            ExecuteTacticalRenderFrame()
        end)
        return false
    end)
end

return UIManager
