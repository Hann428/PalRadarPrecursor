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
local LastObservedPlayerContextKey = nil
local SuppressedMapBaseKeys = {}
local SuppressedMapBaseUntil = 0
local LastMapStaticPassAt = 0
local LastMapToggleCleanupAt = 0
local LastOverlayFilterClickAt = 0
local MapProbeUntil = 0
local MapProbeLastFoundAt = 0
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

local function ArmMapProbeWindow(reason, seconds)
    local now = os.clock()
    local probeSeconds = tonumber(seconds) or tonumber(Config.MapHookActiveProbeSeconds) or 8.0
    MapProbeUntil = math.max(MapProbeUntil or 0, now + probeSeconds)
    print("[+] [UI_MANAGER] Map polling armed: " .. tostring(reason) .. " for " .. tostring(probeSeconds) .. "s")
end

local function RememberSuppressedMapBaseKeys(signature, seconds)
    if signature == nil or signature == "" then return end

    local untilTime = os.clock() + (tonumber(seconds) or 6.0)
    SuppressedMapBaseUntil = math.max(SuppressedMapBaseUntil or 0, untilTime)
    local count = 0
    for key in tostring(signature):gmatch("[^|]+") do
        if key ~= nil and key ~= "" then
            SuppressedMapBaseKeys[key] = true
            count = count + 1
        end
    end
    LogPollingProbe("Suppressed stale map widget keys count=" .. tostring(count) .. " seconds=" .. tostring(seconds))
end

local function GetStaleMapWidgetSuppressSeconds()
    return tonumber(Config.MapStaleWidgetSuppressSeconds) or 600.0
end

local function ClearExpiredSuppressedMapBaseKeys()
    if (SuppressedMapBaseUntil or 0) > 0 and os.clock() >= SuppressedMapBaseUntil then
        SuppressedMapBaseKeys = {}
        SuppressedMapBaseUntil = 0
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

local function FilterSuppressedMapBaseCandidates(candidates)
    ClearExpiredSuppressedMapBaseKeys()
    if (SuppressedMapBaseUntil or 0) <= 0 then return candidates end

    local filtered = {}
    for _, candidate in ipairs(candidates or {}) do
        local mapBase = candidate.Object or candidate
        local key = GetObjectKey(mapBase)
        if not key or SuppressedMapBaseKeys[key] ~= true then
            filtered[#filtered + 1] = candidate
        end
    end

    return filtered
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
    if mapKey and CompletedMapStaticPassKeys[mapKey] == true then
        if Config.OverlayMarkers and Config.OverlayMarkers.Enabled and MapController.EnsureOverlayFilterPanel then
            local ok, ensured = pcall(function()
                return MapController.EnsureOverlayFilterPanel(mapBase)
            end)
            if not ok or ensured ~= true then
                CompletedMapStaticPassKeys[mapKey] = nil
            end
        end
        if CompletedMapStaticPassKeys[mapKey] == true then return end
    end

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

local function ResetObservedSessionGuards()
    ResetMapInjectionGuards()
    LastObservedPlayerContextKey = nil
end

local function GetLiveMapBaseCandidates()
    if type(MapController.FindLiveMapBases) == "function" then
        local ok, candidates = pcall(MapController.FindLiveMapBases)
        if ok and type(candidates) == "table" then return candidates end
    end

    local mapBase = MapController.FindLiveMapBase()
    if IsValidObject(mapBase) then
        return {
            { Object = mapBase, ClassName = "legacy-single" }
        }
    end

    return {}
end

local function GetMapBaseCandidateSignature(candidates)
    local keys = {}
    for _, candidate in ipairs(candidates or {}) do
        local mapBase = candidate.Object or candidate
        local key = GetObjectKey(mapBase)
        if key then keys[#keys + 1] = key end
    end

    table.sort(keys)
    return table.concat(keys, "|")
end

local function GetMapBaseCandidatesNotInSignature(candidates, previousSignature)
    if not previousSignature or previousSignature == "" then return candidates end

    local filtered = {}
    for _, candidate in ipairs(candidates or {}) do
        local mapBase = candidate.Object or candidate
        local key = GetObjectKey(mapBase)
        if key and not tostring(previousSignature):find(key, 1, true) then
            filtered[#filtered + 1] = candidate
        end
    end

    if #filtered > 0 then return filtered end
    return candidates
end

local function TryRunMapStaticPassFromLiveWidget(source)
    local contextObject = GetActiveWorldContext()
    if not IsValidObject(contextObject) then
        if LastObservedMapBaseKey ~= nil then
            RememberSuppressedMapBaseKeys(LastObservedMapBaseKey, GetStaleMapWidgetSuppressSeconds())
            MapController.ResetOverlayUiState("player-context-gone:" .. tostring(source))
            ResetObservedSessionGuards()
        end
        return false
    end

    local playerContextKey = GetObjectKey(contextObject)
    if playerContextKey and playerContextKey ~= "" then
        if LastObservedPlayerContextKey ~= nil and playerContextKey ~= LastObservedPlayerContextKey then
            RememberSuppressedMapBaseKeys(LastObservedMapBaseKey, GetStaleMapWidgetSuppressSeconds())
            MapController.ResetOverlayUiState("player-context-changed:" .. tostring(source))
            ResetMapInjectionGuards()
            LastPacket = nil
            LastScanTime = 0
            LastObservedPlayerContextKey = playerContextKey
            ArmMapProbeWindow("player-context-changed", 8.0)
            LogPollingProbe("Player context changed; skipped stale map widgets for this probe tick.")
            return false
        end
        LastObservedPlayerContextKey = playerContextKey
    end

    local candidates = GetLiveMapBaseCandidates()
    candidates = FilterSuppressedMapBaseCandidates(candidates)
    if #candidates <= 0 then
        return false
    end

    local mapSignature = GetMapBaseCandidateSignature(candidates)
    local previousSignature = LastObservedMapBaseKey
    local signatureChanged = LastObservedMapBaseKey ~= nil and mapSignature ~= "" and mapSignature ~= LastObservedMapBaseKey
    if signatureChanged then
        MapController.ResetOverlayUiState("live-map-changed:" .. tostring(source))
        ResetMapInjectionGuards()
    end
    LastObservedMapBaseKey = mapSignature

    if #candidates > 1 then
        LogPollingProbe("Polling map detection found " .. tostring(#candidates) .. " live map widget candidates.")
    end

    local attempted = false
    -- When stale map widgets reappear, "new to the signature" can actually be
    -- an old instance. Keep the normal newest-candidate path after resetting.
    local candidatesToRun = candidates
    local maxCandidates = Config.MapHookCandidateLimit or 6
    local startIndex = math.max(1, #candidatesToRun - maxCandidates + 1)
    if #candidatesToRun > 0 then
        startIndex = #candidatesToRun
    end
    for index = startIndex, #candidatesToRun do
        local candidate = candidatesToRun[index]
        local mapBase = candidate.Object or candidate
        if IsValidObject(mapBase) then
            local ok, err = pcall(function()
                RunMapStaticPass(mapBase, tostring(source) .. "#" .. tostring(index))
            end)
            if not ok then
                LogSafeError("map-static-pass:" .. tostring(source) .. "#" .. tostring(index), err)
            else
                attempted = true
                MapProbeUntil = 0
                break
            end
        end
    end

    if not attempted then return false end
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
        local now = os.clock()
        if now > (MapProbeUntil or 0) then return false end

        SafeExecuteInGameThread("map-hook-retry", function()
            if ShouldRegisterMapWidgetHooks() and not IsMapHookRegistered then
                RegisterMapWidgetHooks()
            end

            if not IsMapHookRegistered then
                local found = TryRunMapStaticPassFromLiveWidget("poll-live-map-widget")
                if found then
                    MapProbeLastFoundAt = os.clock()
                    MapProbeUntil = 0
                    LogPollingProbe("Polling map detection found a live map widget.")
                else
                    LogPollingProbe("Polling map detection is waiting for a live map widget.")
                end
            end
        end)

        return false
    end)
end

local function RegisterOverlayFilterMouseClick(force)
    local overlayConfig = Config.OverlayMarkers or {}
    local panelConfig = overlayConfig.FilterPanel or {}
    if panelConfig.Enabled ~= true or panelConfig.MouseClickEnabled ~= true then return 0 end
    if RegisterKeyBind == nil or Key == nil then return 0 end
    if IsOverlayFilterMouseRegistered and force ~= true then return 0 end

    local mouseKey = Key.LEFT_MOUSE_BUTTON or Key.LeftMouseButton or Key.LMB or Key.LeftMouse
    if not mouseKey then
        print("[!] [UI_MANAGER] Overlay filter mouse key unavailable.")
        return 0
    end

    local ok, err = pcall(function()
        RegisterKeyBind(mouseKey, function()
            local now = os.clock()
            if now - LastOverlayFilterClickAt < 0.12 then return end
            LastOverlayFilterClickAt = now

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
        print("[+] [UI_MANAGER] Overlay filter mouse click registered.")
        return 1
    end

    print("[!] [UI_MANAGER] Overlay filter mouse click failed: " .. tostring(err))
    return 0
end

local function RegisterOverlayFilterHotkeys()
    if IsOverlayFilterHotkeysRegistered then
        RegisterOverlayFilterMouseClick(false)
        return
    end

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

    registered = registered + RegisterOverlayFilterMouseClick(false)

    if registered > 0 then
        IsOverlayFilterHotkeysRegistered = true
    end
end

local function RegisterMapToggleCleanupKey()
    if IsMapToggleCleanupRegistered then return end
    local overlayConfig = Config.OverlayMarkers or {}
    local cleanupConfig = overlayConfig.Cleanup or {}
    if RegisterKeyBind == nil or Key == nil then return end
    local doCleanup = cleanupConfig.RegisterMapToggleKey ~= false

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
                LastMapToggleCleanupAt = now

                ArmMapProbeWindow("key-M", Config.MapHookActiveProbeSeconds or 1.2)
                RegisterOverlayFilterMouseClick(false)

                if doCleanup and now - LastMapStaticPassAt >= 0.75 and MapController.PrepareForMapToggle then
                    MapController.PrepareForMapToggle("key-M")
                end
            end)
        end)
    end)

    if ok then
        IsMapToggleCleanupRegistered = true
        print("[+] [UI_MANAGER] Map toggle probe key registered: M")
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
