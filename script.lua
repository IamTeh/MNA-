--[[
    ███╗   ███╗███╗   ██╗ █████╗     ██╗  ██╗██╗   ██╗██████╗
    ████╗ ████║████╗  ██║██╔══██╗    ██║  ██║██║   ██║██╔══██╗
    ██╔████╔██║██╔██╗ ██║███████║    ███████║██║   ██║██████╔╝
    ██║╚██╔╝██║██║╚██╗██║██╔══██║    ██╔══██║██║   ██║██╔══██╗
    ██║ ╚═╝ ██║██║ ╚████║██║  ██║    ██║  ██║╚██████╔╝██████╔╝
    ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝
    Hub  : MNA HUB V11.3 (TEHXNICH)
    UI   : Rayfield (Ocean Theme)
    Support : Fishit (Roblox)
]]

-- =============================
--    WAIT GAME LOAD
-- =============================
repeat task.wait(0.5) until game:IsLoaded()
task.wait(2)

-- =============================
--    RAYFIELD LOAD
-- =============================
local Rayfield
local ok_ray, err_ray = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok_ray or not Rayfield then
    warn("Rayfield gagal dimuat: " .. tostring(err_ray))
    return
end

task.wait(1)

local Window = Rayfield:CreateWindow({
    Name            = "MNA HUB V11.3",
    Icon            = 0,
    LoadingTitle    = "MNA HUB",
    LoadingSubtitle = "V11.3 | Fishit Hub",
    Theme           = "Ocean",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = true,
    ConfigurationSaving = {
        Enabled  = true,
        FileName = "MNAHUB_V11",
    },
    KeySystem = false,
})

task.wait(0.5)

-- =============================
--    TABS
-- =============================
local InfoTab      = Window:CreateTab("🧿 Info",      4483362458)
local PlayersTab   = Window:CreateTab("👥 Players",   4483362458)
local MainTab      = Window:CreateTab("🌐 Backpack",      4483362458)
local ExclusiveTab = Window:CreateTab("⚡ Fishing", 4483362458)
local TeleportTab  = Window:CreateTab("🗺️ Teleport",  4483362458)
local ShopTab      = Window:CreateTab("🛒 Shop",      4483362458)
local MiscTab      = Window:CreateTab("🔗 Misc",      4483362458)

task.wait(0.3)

-- =============================
--    SERVICES
-- =============================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local LocalPlayer       = Players.LocalPlayer
local isMobile          = UserInputService.TouchEnabled

-- =============================
--    NOTIFY HELPER
-- =============================
local function Notify(title, msg, dur)
    Rayfield:Notify({ Title = title, Content = msg, Duration = dur or 3, Image = 4483362458 })
end
local function NotifySuccess(title, msg, dur)
    Rayfield:Notify({ Title = "✅ "..title, Content = msg, Duration = dur or 3, Image = 4483362458 })
end
local function NotifyError(title, msg, dur)
    Rayfield:Notify({ Title = "❌ "..title, Content = msg, Duration = dur or 3, Image = 4483362458 })
end
local function NotifyInfo(title, msg, dur)
    Rayfield:Notify({ Title = "ℹ️ "..title, Content = msg, Duration = dur or 3, Image = 4483362458 })
end
local function NotifyWarning(title, msg, dur)
    Rayfield:Notify({ Title = "⚠️ "..title, Content = msg, Duration = dur or 3, Image = 4483362458 })
end

-- =============================
--    NET FOLDER & REMOTES (FIXED)
-- =============================
local net = nil

local function initNet()
    local attempts = 0
    repeat
        attempts = attempts + 1
        local ok, result = pcall(function()
            -- Coba metode 1: via _Index
            local packages = ReplicatedStorage:FindFirstChild("Packages")
            if packages then
                local index = packages:FindFirstChild("_Index")
                if index then
                    for _, child in ipairs(index:GetChildren()) do
                        if child.Name:lower():find("net") or child.Name:lower():find("sleitnick") then
                            local n = child:FindFirstChild("net")
                            if n then return n end
                        end
                    end
                end
            end
        end)
        if ok and result then
            net = result
            return true
        end

        -- Coba metode 2: WaitForChild
        local ok2, result2 = pcall(function()
            local packages = ReplicatedStorage:WaitForChild("Packages", 5)
            local index = packages:WaitForChild("_Index", 5)
            for _, child in ipairs(index:GetChildren()) do
                if child.Name:find("sleitnick_net") or child.Name:find("net") then
                    local n = child:FindFirstChild("net")
                    if n then return n end
                end
            end
        end)
        if ok2 and result2 then
            net = result2
            return true
        end

        task.wait(1)
    until attempts >= 5

    warn("[MNA HUB] Net folder tidak ditemukan setelah "..attempts.." percobaan")
    return false
end

initNet()

-- getRemote yang lebih kuat
local remoteCache = {}
local function getRemote(name)
    if remoteCache[name] then return remoteCache[name] end
    if not net then
        -- coba init ulang
        initNet()
        if not net then return nil end
    end

    -- Coba WaitForChild dulu
    local ok, result = pcall(function()
        return net:WaitForChild(name, 3)
    end)
    if ok and result then
        remoteCache[name] = result
        return result
    end

    -- Fallback: cari manual by Name
    for _, child in ipairs(net:GetChildren()) do
        if child.Name == name then
            remoteCache[name] = child
            return child
        end
    end

    -- Fallback 2: cari recursive
    for _, child in ipairs(net:GetDescendants()) do
        if child.Name == name then
            remoteCache[name] = child
            return child
        end
    end

    return nil
end

-- CallRemote yang reliable
local function CallRemote(remote, ...)
    if not remote then return false end
    local ok
    if remote:IsA("RemoteFunction") then
        ok = pcall(function(...) remote:InvokeServer(...) end, ...)
    elseif remote:IsA("RemoteEvent") then
        ok = pcall(function(...) remote:FireServer(...) end, ...)
    end
    return ok
end

-- =============================
--    REMOTES (FIXED)
-- =============================
local Events = {}

local function loadRemotes()
    -- Reset cache dulu
    remoteCache = {}

    -- Tunggu net siap
    if not net then
        initNet()
    end

    -- Load semua remote dengan pcall individual
    local remoteList = {
        { key = "equip",              name = "RF/EquipToolFromHotbar"          },
        { key = "unequip",            name = "RE/UnequipToolFromHotbar"        },
        { key = "equipItem",          name = "RE/EquipItem"                    },
        { key = "CancelFishing",      name = "RF/CancelFishingInputs"          },
        { key = "charge",             name = "RF/ChargeFishingRod"             },
        { key = "minigame",           name = "RF/RequestFishingMinigameStarted"},
        { key = "UpdateAutoFishing",  name = "RF/UpdateAutoFishingState"       },
        { key = "fishing",            name = "RF/CatchFishCompleted"           },
        { key = "fishingRE",          name = "RE/CatchFishCompleted"           },
        { key = "exclaimEvent",       name = "RE/ReplicateTextEffect"          },
        { key = "sell",               name = "RF/SellAllItems"                 },
        { key = "favorite",           name = "RE/FavoriteItem"                 },
        { key = "SpawnTotem",         name = "RE/SpawnTotem"                   },
        { key = "TextNotification",   name = "RE/TextNotification"             },
        { key = "fishNotif",          name = "RE/ObtainedNewFishNotification"  },
        { key = "systemMessage",      name = "RE/DisplaySystemMessage"         },
        { key = "activateAltar",      name = "RE/ActivateEnchantingAltar"      },
        { key = "activateAltar2",     name = "RE/ActivateEnchantingAltar2"     },
        { key = "searchItemPickedUp", name = "RE/SearchItemPickedUp"           },
        { key = "gainAccessToMaze",   name = "RE/GainAccessToMaze"             },
        { key = "claimPirateChest",   name = "RE/ClaimPirateChest"             },
        { key = "BuyWeather",         name = "RF/PurchaseWeatherEvent"         },
        { key = "ConsumeCaveCrystal", name = "RF/ConsumeCaveCrystal"           },
    }

    local loaded = 0
    local failed = 0
    for _, r in ipairs(remoteList) do
        local remote = getRemote(r.name)
        Events[r.key] = remote
        if remote then
            loaded = loaded + 1
        else
            failed = failed + 1
            warn("[MNA HUB] Remote tidak ditemukan: " .. r.name)
        end
    end

    return loaded, failed
end

local loadedCount, failedCount = loadRemotes()

-- =============================
--    MODULES (SAFE LOAD)
-- =============================
local Replion, PlayerData, ItemUtility, TierUtility
local Controllers = {}

pcall(function()
    Replion     = require(ReplicatedStorage.Packages.Replion)
    PlayerData  = Replion.Client:WaitReplion("Data")
    ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
    TierUtility = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TierUtility"))
end)

pcall(function()
    local ctrl = ReplicatedStorage:WaitForChild("Controllers", 5)
    if ctrl then
        pcall(function() Controllers.Notification = require(ctrl:WaitForChild("NotificationController", 3)) end)
        pcall(function() Controllers.VFX          = require(ctrl:WaitForChild("VFXController", 3)) end)
        pcall(function() Controllers.Cutscene     = require(ctrl:WaitForChild("CutsceneController", 3)) end)
        pcall(function() Controllers.Fishing      = require(ctrl:WaitForChild("FishingController", 3)) end)
        pcall(function() Controllers.Backpack     = require(ctrl:WaitForChild("BackpackController", 3)) end)
    end
end)

-- =============================
--    CONFIG
-- =============================
local Config = {
    AutoCatch        = false,
    CatchDelay       = 0.7,
    UB = {
        Active   = false,
        Settings = { CompleteDelay = 3.7, CancelDelay = 0.3 },
        Remotes  = {},
        Stats    = { castCount = 0, startTime = 0 }
    },
    mnblantat        = false,
    antiOKOK         = false,
    autoFishing      = false,
    SpeedHackValue   = 60,
    AutoSellState    = false,
    AutoSellMethod   = "Delay",
    AutoSellValue    = 50,
    AutoFavoriteState   = false,
    AutoUnfavoriteState = false,
    SelectedRarities    = {},
    SelectedMutations   = {},
    AutoTotem        = false,
    SelectedTotemID  = 0,
    AutoMixTotem     = false,
    AutoMining       = false,
    axeUuid          = "",
    AutoEnchant      = false,
    AutoSellWeather  = false,
    CustomWebhook    = false,
    CustomWebhookUrl = "",
    DisableAnimations = false,
    HookNotif         = false,
}

local Tasks    = {}
local needCast = false
local skip     = false
local isCaught = false
local lastTimeFishCaught = nil
local blatantFishCycleCount = 0
local saveCount = 0

_G.SavedData = _G.SavedData or {
    FishCaught   = {},
    CaughtVisual = {},
    FishNotif    = {}
}

-- =============================
--    HELPER FUNCTIONS
-- =============================
local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function equipRod()
    task.wait(0.1)
    CallRemote(Events.equip, 1)
    task.wait(0.1)
    if Config.autoFishing or Config.AutoCatch then
        CallRemote(Events.UpdateAutoFishing, true)
    end
end

local function safeFire(func)
    task.spawn(function() pcall(func) end)
end

local function FireLocalEvent(remote, ...)
    local args = {...}
    pcall(function()
        local signal = remote.OnClientEvent
        for _, connection in pairs(getconnections(signal)) do
            if connection.Function then
                task.spawn(function()
                    connection.Function(unpack(args))
                end)
            end
        end
    end)
end

local function HookRemote(remoteName, storageKey)
    local remote = getRemote(remoteName)
    if remote then
        remote.OnClientEvent:Connect(function(...)
            if saveCount < 7 then
                _G.SavedData[storageKey] = {...}
                local args = {...}
                if storageKey == "CaughtVisual" and tostring(args[1]) == tostring(LocalPlayer.Name) then
                    saveCount = saveCount + 5
                end
            end
        end)
        return true
    end
    return false
end

-- =============================
--    AFK PREVENT
-- =============================
pcall(function()
    for i, v in pairs(getconnections(LocalPlayer.Idled)) do
        if v.Disable then v:Disable() elseif v.Disconnect then v:Disconnect() end
    end
end)

-- =============================
--    LOCATIONS
-- =============================
local LOCATIONS = {
    ["Fisherman"]             = CFrame.new(-18.065, 9.532, 2734.000, -0.113811, 0, -0.993502, 0, 1, 0, 0.993502, 0, -0.113811),
    ["Sisyphus Statue"]       = CFrame.new(-3754.441, -135.074, -895.376, 0.943844, 0, -0.330393, 0, 1, 0, 0.330393, 0, 0.943844),
    ["Coral Reefs"]           = CFrame.new(-3030.043, 2.509, 2271.429),
    ["Esoteric Depths"]       = CFrame.new(3271.979, -1301.530, 1402.762),
    ["Crater Island 1"]       = CFrame.new(990.610, 21.142, 5060.255),
    ["Crater Island 2"]       = CFrame.new(1040.036, 55.714, 5131.443),
    ["Lost Isle"]             = CFrame.new(-3618.157, 240.837, -1317.458),
    ["Weather Machine"]       = CFrame.new(-1488.512, 83.173, 1876.303),
    ["Tropical Grove"]        = CFrame.new(-2132.597, 53.488, 3631.235),
    ["Treasure Room"]         = CFrame.new(-3630, -279.074, -1599.287),
    ["Kohana"]                = CFrame.new(-663.904, 3.046, 718.797),
    ["Kohana Volcano"]        = CFrame.new(-549.192, 20.019, 125.802),
    ["Underground Cellar"]    = CFrame.new(2110.109, -91.199, -699.790),
    ["Ancient Jungle"]        = CFrame.new(1837.352, 5.894, -297.224),
    ["Sacred Temple"]         = CFrame.new(1459.217, -22.375, -637.787),
    ["Ancient Ruins"]         = CFrame.new(6097.176, -585.924, 4644.443),
    ["Megalodon"]             = CFrame.new(-1172.987, 7.924, 3620.589),
    ["Pirate Cove"]           = CFrame.new(3396.730, 4.192, 3469.213),
    ["Pirate Treasure Room"]  = CFrame.new(3324.074, -306.476, 3087.999),
    ["Crystal Depth"]         = CFrame.new(5752.219, -907.148, 15343.468),
    ["Lava Basin"]            = CFrame.new(950.876, 85.282, -10199.427),
    ["Planetary Observatory"] = CFrame.new(420.373, 3.673, 2183.675),
    ["Underwater City"]       = CFrame.new(-3142.406, -643.484, -10409.403),
}

local function teleportTo(locationName)
    local cf  = LOCATIONS[locationName]
    local hrp = getHRP()
    if not hrp or not cf then return end
    hrp.CFrame = cf + Vector3.new(0, 3, 0)
end

-- =============================
--    UB SYSTEM (FIXED)
-- =============================
local function UB_init()
    Config.UB.Remotes.ChargeFishingRod    = getRemote("RF/ChargeFishingRod")
    Config.UB.Remotes.RequestMinigame     = getRemote("RF/RequestFishingMinigameStarted")
    Config.UB.Remotes.CancelFishingInputs = getRemote("RF/CancelFishingInputs")
    Config.UB.Remotes.UpdateAutoFishing   = getRemote("RF/UpdateAutoFishingState")
    Config.UB.Remotes.FishingCompleted    = getRemote("RF/CatchFishCompleted")
    Config.UB.Remotes.FishingCompletedRE  = getRemote("RE/CatchFishCompleted")
    Config.UB.Remotes.equip               = getRemote("RF/EquipToolFromHotbar")
    return true
end

local function ub_loop()
    while Config.UB.Active do
        local ok, err = pcall(function()
            local currentTime = tick()

            if Config.autoFishing then
                CallRemote(Events.UpdateAutoFishing, true)
            end

            -- Random delay kecil untuk anti-detection
            local baseWait = needCast and 0.7 or Config.UB.Settings.CancelDelay
            if Config.antiOKOK then
                baseWait = baseWait + math.random(5, 20) / 100
            end
            task.wait(baseWait)
            needCast = false

            -- Charge rod
            safeFire(function()
                if Config.UB.Remotes.ChargeFishingRod then
                    Config.UB.Remotes.ChargeFishingRod:InvokeServer({ [1] = currentTime })
                end
            end)

            if Config.antiOKOK then
                task.wait(math.random(15, 25) / 100)
            else
                task.wait(0.1)
            end

            -- Request minigame
            safeFire(function()
                if Config.UB.Remotes.RequestMinigame then
                    Config.UB.Remotes.RequestMinigame:InvokeServer(1, 0, currentTime)
                end
            end)

            -- Tunggu sesuai delay
            local completeDelay = Config.UB.Settings.CompleteDelay
            if Config.antiOKOK then
                completeDelay = completeDelay + math.random(-10, 10) / 100
            end
            task.wait(math.max(completeDelay, 1))

            if not skip then
                safeFire(function()
                    if Config.UB.Remotes.FishingCompleted then
                        Config.UB.Remotes.FishingCompleted:InvokeServer()
                    end
                    pcall(function()
                        if Config.UB.Remotes.FishingCompletedRE then
                            Config.UB.Remotes.FishingCompletedRE:FireServer()
                        end
                    end)

                    if Config.amblatant and isCaught then
                        task.spawn(function()
                            task.wait(0.05)
                            local xr = getRemote("RE/FishCaught")
                            if xr and _G.SavedData.FishCaught and #_G.SavedData.FishCaught > 0 then
                                FireLocalEvent(xr, unpack(_G.SavedData.FishCaught))
                            end
                            xr = getRemote("RE/CaughtFishVisual")
                            if xr and _G.SavedData.CaughtVisual and #_G.SavedData.CaughtVisual > 0 then
                                FireLocalEvent(xr, unpack(_G.SavedData.CaughtVisual))
                            end
                            xr = getRemote("RE/ObtainedNewFishNotification")
                            if xr and _G.SavedData.FishNotif and #_G.SavedData.FishNotif > 0 then
                                FireLocalEvent(xr, unpack(_G.SavedData.FishNotif))
                            end
                        end)
                        isCaught = false
                    end
                end)
            end

            blatantFishCycleCount += 1
        end)

        if not ok then
            warn("[MNA HUB] UB loop error: " .. tostring(err))
            task.wait(1)
        end
    end
end

local function UB_start()
    if Config.UB.Active then return end
    UB_init()
    Config.UB.Active = true
    needCast = true
    Config.UB.Stats.castCount = 0
    Config.UB.Stats.startTime = tick()
    Tasks.ubtask = task.spawn(ub_loop)
    NotifySuccess("Ultra Blatant", "Aktif! Memancing ultra cepat ⚡")
end

local function UB_stop()
    if not Config.UB.Active then return end
    Config.UB.Active = false
    safeFire(function()
        if Config.UB.Remotes.CancelFishingInputs then
            CallRemote(Config.UB.Remotes.CancelFishingInputs)
        end
    end)
    task.wait(0.3)
    if Tasks.ubtask then
        pcall(function() task.cancel(Tasks.ubtask) end)
        Tasks.ubtask = nil
    end
    NotifyWarning("Ultra Blatant", "Dimatikan.")
end

local function onToggleUB(value)
    if value then
        Config.Hoo
