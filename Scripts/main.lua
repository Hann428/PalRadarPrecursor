-- main.lua
print("\n[+] [MAIN] Loading Palworld Map Intel Suite v0.5 custom marker bridge...")

local DataRouter = require("data_router")
local UIManager = require("ui_manager")

local IsSuiteInitialized = false

local function ProvideDataToUI()
    local playerAnchor = DataRouter.GetPlayerAnchor()
    local dataPacket = {
        Characters = {},
        StaticObjects = {},
        ScanStats = {
            CharacterCount = 0,
            AllowedCharacterCount = 0
        }
    }
    return playerAnchor, dataPacket
end

function InitializeModSuite()
    if IsSuiteInitialized then return end

    UIManager.InitializeRadarLoop(ProvideDataToUI)

    IsSuiteInitialized = true
    print("[+] [MAIN] Map Intel is active. Custom marker test injection is disabled by default.\n")
end

InitializeModSuite()
