-- data_router.lua
local Config = require("config")
local DataRouter = {}
local UnpackArgs = table.unpack or unpack

local function IsValidObject(obj)
    local ok, result = pcall(function()
        return obj and obj:IsValid()
    end)
    return ok and result
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

local function SafeRead(readFn)
    local ok, result = pcall(readFn)
    if ok then return result end
    return nil
end

local function GetLocation(actor)
    local loc = SafeCall(actor, "K2_GetActorLocation")
    if loc then return loc end

    return SafeRead(function()
        return actor.RootComponent.RelativeLocation
    end)
end

local function GetDisplayName(actor, fallback)
    local name = SafeCall(actor, "GetName")
    if name and name ~= "" then return name end

    local fullName = SafeCall(actor, "GetFullName")
    if fullName and fullName ~= "" then
        local shortName = fullName:match("([^.]+)$") or fullName
        return shortName:gsub("_[0-9]+$", "")
    end

    return fallback or "Unknown"
end

local function ContainsAny(text, needles)
    if not text then return false end
    local lower = string.lower(text)
    for _, needle in ipairs(needles) do
        if string.find(lower, string.lower(needle), 1, true) then
            return true
        end
    end
    return false
end

local function ClassifyCharacter(actor)
    local name = GetDisplayName(actor, "Pal")
    local fullName = SafeCall(actor, "GetFullName") or name
    local isBoss = ContainsAny(fullName, { "boss", "raidboss", "legend" })
    local isNPC = ContainsAny(fullName, { "npc", "villager", "shop", "trader" })
    local isLucky = false

    local rareFlag = SafeRead(function()
        return actor.bIsLucky or actor.bIsRare or actor.IsLucky
    end)
    if rareFlag then isLucky = true end

    local kind = "Pal"
    if isNPC then kind = "NPC" end
    if isBoss then kind = "Boss" end
    if isLucky then kind = "Lucky" end

    local allowed = false
    if isLucky and Config.Filters.Lucky then allowed = true end
    if isBoss and Config.Filters.Boss then allowed = true end
    if isNPC and Config.Filters.NPC then allowed = true end
    if kind == "Pal" and Config.Filters.NormalPal then allowed = true end

    return {
        Name = name,
        Kind = kind,
        IsBoss = isBoss,
        IsLucky = isLucky,
        IsNPC = isNPC,
        Allowed = allowed
    }
end

function DataRouter.GetPlayerAnchor()
    local candidateNames = {
        "BP_PalPlayerCharacter_C",
        "PalPlayerCharacter"
    }

    for _, className in ipairs(candidateNames) do
        local player = nil
        pcall(function()
            player = FindFirstOf(className)
        end)

        if IsValidObject(player) then
            local loc = GetLocation(player)
            if loc then
                local yaw = SafeRead(function()
                    return player.RootComponent.RelativeRotation.Yaw
                end) or 0
                return {
                    Instance = player,
                    X = loc.X,
                    Y = loc.Y,
                    Z = loc.Z,
                    Yaw = yaw
                }
            end
        end
    end

    local players = FindAllOf("PalPlayerCharacter")
    if players then
        for _, player in ipairs(players) do
            if IsValidObject(player) then
                local loc = GetLocation(player)
                if loc then
                    return {
                        Instance = player,
                        X = loc.X,
                        Y = loc.Y,
                        Z = loc.Z,
                        Yaw = 0
                    }
                end
            end
        end
    end

    return nil
end

function DataRouter.GetPlayerLocation()
    local anchor = DataRouter.GetPlayerAnchor()
    if not anchor then return nil end
    return { X = anchor.X, Y = anchor.Y, Z = anchor.Z, Yaw = anchor.Yaw }
end

function DataRouter.GetActivePals()
    local packet = DataRouter.StreamWorldElements(DataRouter.GetPlayerAnchor())
    return packet.Characters
end

function DataRouter.StreamWorldElements(playerAnchor)
    local dataPacket = {
        Characters = {},
        StaticObjects = {},
        ScanStats = {
            CharacterCount = 0,
            AllowedCharacterCount = 0
        }
    }

    if not playerAnchor or not IsValidObject(playerAnchor.Instance) then
        return dataPacket
    end

    local allChars = FindAllOf("PalCharacter")
    if allChars then
        for _, actor in ipairs(allChars) do
            if IsValidObject(actor) then
                local sameAsPlayer = SafeRead(function()
                    return actor:GetAddress() == playerAnchor.Instance:GetAddress()
                end)

                if not sameAsPlayer then
                    dataPacket.ScanStats.CharacterCount = dataPacket.ScanStats.CharacterCount + 1

                    local loc = GetLocation(actor)
                    if loc then
                        local classification = ClassifyCharacter(actor)
                        if classification.Allowed then
                            dataPacket.ScanStats.AllowedCharacterCount = dataPacket.ScanStats.AllowedCharacterCount + 1
                            table.insert(dataPacket.Characters, {
                                Instance = actor,
                                Name = classification.Name,
                                Kind = classification.Kind,
                                X = loc.X,
                                Y = loc.Y,
                                Z = loc.Z,
                                IsBoss = classification.IsBoss,
                                IsLucky = classification.IsLucky,
                                IsNPC = classification.IsNPC
                            })
                        end
                    end
                end
            end
        end
    end

    return dataPacket
end

return DataRouter
