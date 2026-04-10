--[[
    ███╗   ███╗███╗   ██╗ █████╗     ██╗  ██╗██╗   ██╗██████╗
    ████╗ ████║████╗  ██║██╔══██╗    ██║  ██║██║   ██║██╔══██╗
    ██╔████╔██║██╔██╗ ██║███████║    ███████║██║   ██║██████╔╝
    ██║╚██╔╝██║██║╚██╗██║██╔══██║    ██╔══██║██║   ██║██╔══██╗
    ██║ ╚═╝ ██║██║ ╚████║██║  ██║    ██║  ██║╚██████╔╝██████╔╝
    ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝
    Hub  : MNA HUB V11.3 (FIXED)
    UI   : Rayfield (Ocean Theme)
    Game : Fisch (Roblox)
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
    LoadingSubtitle = "V11.3 | Fisch Hub",
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
local ExclusiveTab = Window:CreateTab("🪝 Fishing", 4483362458)
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
        Config.HookNotif = true
        equipRod()
        task.wait(0.5)
        UB_start()
    else
        UB_stop()
        Config.HookNotif = false
    end
end

UB_init()

-- Anti-stuck UB
task.spawn(function()
    while true do
        task.wait(5)
        if Config.UB.Active
            and lastTimeFishCaught ~= nil
            and os.clock() - lastTimeFishCaught >= 10
            and blatantFishCycleCount > 1
        then
            needCast = true
            saveCount = 0
            blatantFishCycleCount = 0
            lastTimeFishCaught = os.clock()
            onToggleUB(false)
            task.wait(1)
            onToggleUB(true)
        end
    end
end)

-- =============================
--    AUTO SELL
-- =============================
local function RunAutoSellLoop()
    if Tasks.AutoSellThread then
        pcall(function() task.cancel(Tasks.AutoSellThread) end)
    end
    Tasks.AutoSellThread = task.spawn(function()
        while Config.AutoSellState do
            if not Events.sell then
                -- Coba reload remote
                Events.sell = getRemote("RF/SellAllItems")
                if not Events.sell then
                    NotifyError("Auto Sell", "Remote SellAllItems tidak ditemukan!")
                    Config.AutoSellState = false
                    break
                end
            end
            if Config.AutoSellMethod == "Delay" then
                task.wait(math.max(Config.AutoSellValue, 5))
                if Config.AutoSellState then
                    pcall(function() Events.sell:InvokeServer({}) end)
                end
            else
                task.wait(2)
            end
        end
    end)
end

-- =============================
--    AUTO FAVOURITE
-- =============================
local function GetPlayerDataReplion()
    local ok, result = pcall(function()
        local ReplionModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Replion", 5)
        return require(ReplionModule).Client:WaitReplion("Data", 5)
    end)
    return ok and result or PlayerData or nil
end

local function GetFishNameAndRarity(item)
    local name   = item.Identifier or "Unknown"
    local rarity = item.Metadata and item.Metadata.Rarity or "COMMON"
    pcall(function()
        if ItemUtility then
            local data = ItemUtility:GetItemData(item.Id)
            if data and data.Data and data.Data.Name then name = data.Data.Name end
            if item.Metadata and item.Metadata.Rarity then
                rarity = item.Metadata.Rarity
            end
        end
    end)
    return name, rarity
end

local function GetItemMutationString(item)
    if item.Metadata and item.Metadata.Shiny == true then return "Shiny" end
    return item.Metadata and item.Metadata.VariantId or ""
end

local function RunAutoFavLoop(isUnfavorite)
    local replion = GetPlayerDataReplion()
    if not replion then return end
    if not Events.favorite then
        Events.favorite = getRemote("RE/FavoriteItem")
        if not Events.favorite then return end
    end
    local ok, invData = pcall(function() return replion:GetExpect("Inventory") end)
    if not ok or not invData or not invData.Items then return end
    local targets = {}
    for _, item in ipairs(invData.Items) do
        local isAlreadyFav = (item.IsFavorite or item.Favorited)
        if isUnfavorite then
            if not isAlreadyFav then continue end
        else
            if isAlreadyFav then continue end
        end
        local _, rarity = GetFishNameAndRarity(item)
        local mutation  = GetItemMutationString(item)
        local match     = false
        for _, r in ipairs(Config.SelectedRarities) do
            if string.lower(rarity) == string.lower(r) then match = true; break end
        end
        if not match then
            if table.find(Config.SelectedMutations, mutation) then match = true end
        end
        if match and item.UUID then table.insert(targets, item.UUID) end
    end
    if #targets > 0 then
        NotifyInfo(isUnfavorite and "Unfavoriting" or "Favoriting", "Memproses " .. #targets .. " ikan...")
        for _, uuid in ipairs(targets) do
            if (isUnfavorite and not Config.AutoUnfavoriteState)
                or (not isUnfavorite and not Config.AutoFavoriteState)
            then break end
            pcall(function() Events.favorite:FireServer(uuid) end)
            task.wait(0.35)
        end
    end
end

-- =============================
--    ENCHANT SYSTEM
-- =============================
local STONE_IDS = { ["Enchant Stones"] = 10, ["Evolved Enchant Stone"] = 558 }
local enchantIdMap = {
    ["Big Hunter 1"] = 3,  ["Cursed 1"] = 12,        ["Empowered 1"] = 9,
    ["Glistening 1"] = 1,  ["Gold Digger 1"] = 4,    ["Leprechaun 1"] = 5,
    ["Leprechaun 2"] = 6,  ["Mutation Hunter 1"] = 7, ["Mutation Hunter 2"] = 14,
    ["Prismatic 1"] = 13,  ["Reeler 1"] = 2,          ["Stargazer 1"] = 8,
    ["Stormhunter 1"] = 11,["XPerienced 1"] = 10,    ["SECRET Hunter"] = 16,
    ["Shark Hunter"] = 20, ["Stargazer II"] = 17,     ["Stormhunter II"] = 19,
    ["Leprechaun II"] = 6, ["Reeler II"] = 21,        ["Mutation Hunter III"] = 22,
    ["Fairy Hunter 1"] = 15
}

_G.SelectedStoneType    = _G.SelectedStoneType    or "Enchant Stones"
_G.TargetEnchantBasic   = _G.TargetEnchantBasic   or "Big Hunter 1"
_G.TargetEnchantEvolved = _G.TargetEnchantEvolved or "Prismatic 1"
_G.AutoEnchant          = _G.AutoEnchant          or false

local function findEnchantStones()
    local stones = {}
    pcall(function()
        local inv = PlayerData:GetExpect("Inventory")
        if not inv or not inv.Items then return end
        local targetId = STONE_IDS[_G.SelectedStoneType]
        for _, item in ipairs(inv.Items) do
            if item.Id == targetId then
                table.insert(stones, { UUID = item.UUID, Id = item.Id })
            end
        end
    end)
    return stones
end

local function countHotbarSlots()
    local ok, count = pcall(function()
        local display = LocalPlayer.PlayerGui:WaitForChild("Backpack", 3):WaitForChild("Display", 3)
        local c = 0
        for _, child in ipairs(display:GetChildren()) do
            if child:IsA("ImageButton") then c += 1 end
        end
        return c
    end)
    return ok and count or 5
end

local function getCurrentRodEnchant()
    local enchantId = nil
    pcall(function()
        local equipped = PlayerData:Get("EquippedItems")
        if not equipped then return end
        local rods = PlayerData:GetExpect("Inventory")
        if not rods or not rods["Fishing Rods"] then return end
        for _, uuid in pairs(equipped) do
            for _, rod in ipairs(rods["Fishing Rods"]) do
                if rod.UUID == uuid and rod.Metadata and rod.Metadata.EnchantId then
                    enchantId = rod.Metadata.EnchantId
                end
            end
        end
    end)
    return enchantId
end

-- =============================
--    WEBHOOK
-- =============================
local function sendWebhook(url, fishName, rarity, mutation, weight)
    if not url or url == "" then return end
    pcall(function()
        local payload = HttpService:JSONEncode({
            username = "MNA HUB V11.3",
            embeds = {{
                title  = "🎣 Fish Caught!",
                color  = 0x00aaff,
                fields = {
                    { name = "Fish",     value = tostring(fishName),  inline = true },
                    { name = "Rarity",   value = tostring(rarity),    inline = true },
                    { name = "Mutation", value = tostring(mutation),  inline = true },
                    { name = "Weight",   value = tostring(weight),    inline = true },
                },
                footer = { text = "MNA HUB V11.3" }
            }}
        })
        if typeof(request) == "function" then
            request({
                Url     = url,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = payload
            })
        elseif typeof(syn) == "table" and syn.request then
            syn.request({
                Url     = url,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = payload
            })
        end
    end)
end

-- =============================
--    FISH NOTIF HOOK
-- =============================
task.spawn(function()
    task.wait(2)
    if Events.fishNotif then
        Events.fishNotif.OnClientEvent:Connect(function(...)
            local args = {...}
            lastTimeFishCaught = os.clock()
            isCaught = true
            local dummyItem    = { Id = args[1], Metadata = args[2] }
            local fishName, fishRarity = GetFishNameAndRarity(dummyItem)
            local mutation     = GetItemMutationString(dummyItem)
            local weight       = string.format("%.2fkg", (args[2] and args[2].Weight) or 0)

            if typeof(args[3]) == "table" and args[3].InventoryItem and args[3].InventoryItem.UUID then
                if Config.CustomWebhook and Config.CustomWebhookUrl ~= "" then
                    sendWebhook(Config.CustomWebhookUrl, fishName, fishRarity, mutation, weight)
                end
            end
        end)
    end
end)

-- Exclaim listener untuk legit fishing
task.spawn(function()
    task.wait(2)
    if Events.exclaimEvent then
        Events.exclaimEvent.OnClientEvent:Connect(function(data)
            if not Config.AutoCatch then return end
            if not data or not data.TextData then return end
            if data.TextData.EffectType ~= "Exclaim" then return end
            local container = data.Container
            if not container then return end
            local char = LocalPlayer.Character
            if not char then return end
            local head = char:FindFirstChild("Head")
            if not head or container ~= head then return end
            task.wait(math.max(Config.CatchDelay - 0.1, 0))
            safeFire(function()
                if Events.fishing then
                    Events.fishing:InvokeServer()
                end
            end)
        end)
    end
end)

-- ======================================================
--    UI BUILD
-- ======================================================

-- ====== INFO TAB ======
task.wait(0.2)
InfoTab:CreateSection("⚡ MNA HUB V11.3 FIXED")
task.wait(0.1)

InfoTab:CreateParagraph({
    Title   = "Tentang MNA HUB",
    Content = "MNA HUB V11.3 FIXED - Script Fisch lengkap dengan fitur Auto Fish, Teleport, Enchant, Mining, Totem, dan banyak lagi! Remote system diperbaiki.",
})

task.wait(0.1)

InfoTab:CreateParagraph({
    Title   = "⚠️ Disclaimer",
    Content = "Risiko penggunaan sepenuhnya tanggung jawab pengguna. Gunakan dengan bijak. Untuk fishing aman gunakan Legit Fishing, bukan Ultra Blatant.",
})

task.wait(0.1)

InfoTab:CreateButton({
    Name     = "🔄 Reload Remotes",
    Callback = function()
        local l, f = loadRemotes()
        UB_init()
        NotifySuccess("Remotes", "Loaded: " .. l .. " | Failed: " .. f)
    end,
})

task.wait(0.1)

InfoTab:CreateButton({
    Name     = "🔎 Cek Status Remote",
    Callback = function()
        local loaded = 0
        local failed = 0
        local failedList = ""
        local checkList = {
            "equip", "fishing", "sell", "favorite",
            "UpdateAutoFishing", "charge", "minigame"
        }
        for _, key in ipairs(checkList) do
            if Events[key] then
                loaded = loaded + 1
            else
                failed = failed + 1
                failedList = failedList .. key .. " "
            end
        end
        if failed > 0 then
            NotifyWarning("Remote Status", "OK: " .. loaded .. " | Gagal: " .. failed .. "\n" .. failedList)
        else
            NotifySuccess("Remote Status", "Semua remote utama OK! ✅")
        end
    end,
})

-- ====== PLAYERS TAB ======
task.wait(0.2)
PlayersTab:CreateSection("Character Controls")
task.wait(0.1)

PlayersTab:CreateSlider({
    Name         = "Walk Speed",
    Range        = {16, 200},
    Increment    = 1,
    Suffix       = " studs/s",
    CurrentValue = 16,
    Flag         = "WalkSpeed",
    Callback     = function(val)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = val end
        end
    end,
})

task.wait(0.1)

PlayersTab:CreateSlider({
    Name         = "Jump Power",
    Range        = {50, 500},
    Increment    = 10,
    Suffix       = " power",
    CurrentValue = 50,
    Flag         = "JumpPower",
    Callback     = function(val)
        _G.CustomJumpPower = val
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower    = val
            end
        end
    end,
})

task.wait(0.1)

PlayersTab:CreateButton({
    Name     = "Reset Speed & Jump",
    Callback = function()
        _G.CustomJumpPower = 50
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed    = 16
                hum.UseJumpPower = true
                hum.JumpPower    = 50
            end
        end
        NotifySuccess("Reset", "Speed & Jump kembali normal!")
    end,
})

task.wait(0.1)
PlayersTab:CreateSection("Special Abilities")
task.wait(0.1)

PlayersTab:CreateToggle({
    Name         = "Infinite Jump",
    CurrentValue = false,
    Flag         = "InfiniteJump",
    Callback     = function(val)
        _G.InfiniteJump = val
        NotifyInfo("Infinite Jump", val and "Aktif!" or "Nonaktif.")
    end,
})

UserInputService.JumpRequest:Connect(function()
    if _G.InfiniteJump then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

task.wait(0.1)

PlayersTab:CreateToggle({
    Name         = "Noclip",
    CurrentValue = false,
    Flag         = "Noclip",
    Callback     = function(val)
        _G.Noclip = val
        if val then
            task.spawn(function()
                while _G.Noclip do
                    task.wait(0.1)
                    local char = LocalPlayer.Character
                    if char then
                        for _, part in pairs(char:GetDescendants()) do
                            if part:IsA("BasePart") and part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end)
            NotifyInfo("Noclip", "Aktif! Bisa tembus dinding.")
        else
            NotifyInfo("Noclip", "Nonaktif.")
        end
    end,
})

task.wait(0.1)

local freezeConn, frozenCFrame
PlayersTab:CreateToggle({
    Name         = "Freeze Character",
    CurrentValue = false,
    Flag         = "Freeze",
    Callback     = function(val)
        if val then
            local hrp = getHRP()
            if hrp then
                frozenCFrame = hrp.CFrame
                freezeConn = RunService.Heartbeat:Connect(function()
                    if _G.FreezeCharacter and hrp then
                        hrp.CFrame = frozenCFrame
                    end
                end)
                _G.FreezeCharacter = true
                NotifyInfo("Freeze", "Karakter dibekukan!")
            end
        else
            _G.FreezeCharacter = false
            if freezeConn then
                freezeConn:Disconnect()
                freezeConn = nil
            end
            NotifyInfo("Freeze", "Karakter bebas kembali.")
        end
    end,
})

-- ====== MAIN TAB ======
task.wait(0.2)
MainTab:CreateSection("Auto Enchant")
task.wait(0.1)

MainTab:CreateDropdown({
    Name          = "Stone Type",
    Options       = {"Enchant Stones", "Evolved Enchant Stone"},
    CurrentOption = {"Enchant Stones"},
    Flag          = "StoneType",
    Callback      = function(val)
        _G.SelectedStoneType = type(val) == "table" and val[1] or val
    end,
})

task.wait(0.1)

MainTab:CreateDropdown({
    Name          = "Target Enchant (Basic)",
    Options       = {"Big Hunter 1","Cursed 1","Empowered 1","Glistening 1","Gold Digger 1","Leprechaun 1","Leprechaun 2","Mutation Hunter 1","Mutation Hunter 2","Prismatic 1","Reeler 1","Stargazer 1","Stormhunter 1","XPerienced 1"},
    CurrentOption = {"Big Hunter 1"},
    Flag          = "EnchantBasic",
    Callback      = function(val)
        _G.TargetEnchantBasic = type(val) == "table" and val[1] or val
    end,
})

task.wait(0.1)

MainTab:CreateDropdown({
    Name          = "Target Enchant (Evolved)",
    Options       = {"Prismatic 1","Cursed 1","Gold Digger 1","Empowered 1","SECRET Hunter","Shark Hunter","Stargazer II","Stormhunter II","Mutation Hunter II","Leprechaun II","Reeler II","Mutation Hunter III","Fairy Hunter 1"},
    CurrentOption = {"Prismatic 1"},
    Flag          = "EnchantEvolved",
    Callback      = function(val)
        _G.TargetEnchantEvolved = type(val) == "table" and val[1] or val
    end,
})

task.wait(0.1)

MainTab:CreateToggle({
    Name         = "Auto Enchant",
    CurrentValue = false,
    Flag         = "AutoEnchant",
    Callback     = function(val)
        _G.AutoEnchant = val
        if val then
            NotifySuccess("Auto Enchant", "Aktif!")
            task.spawn(function()
                while _G.AutoEnchant do
                    pcall(function()
                        local targetEnchant = (_G.SelectedStoneType == "Evolved Enchant Stone")
                            and _G.TargetEnchantEvolved or _G.TargetEnchantBasic
                        local currentId = getCurrentRodEnchant()
                        local targetId  = enchantIdMap[targetEnchant]
                        if currentId == targetId then
                            _G.AutoEnchant = false
                            NotifySuccess("Auto Enchant", "Target tercapai: " .. targetEnchant .. "!")
                            return
                        end
                        local stones = findEnchantStones()
                        if #stones > 0 then
                            if Events.equipItem then
                                pcall(function() Events.equipItem:FireServer(stones[1].UUID, "Enchant Stones") end)
                            end
                            task.wait(1.5)
                            local slot = countHotbarSlots() - 2
                            if slot < 1 then slot = 1 end
                            if Events.equip then
                                pcall(function() Events.equip:InvokeServer(slot) end)
                            end
                            task.wait(1.5)
                            if Events.activateAltar then
                                pcall(function() Events.activateAltar:FireServer() end)
                            end
                        end
                    end)
                    task.wait(2)
                end
            end)
        else
            NotifyWarning("Auto Enchant", "Dimatikan.")
        end
    end,
})

task.wait(0.1)

MainTab:CreateButton({
    Name     = "Teleport ke Altar",
    Callback = function()
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(3234.837, -1302.855, 1398.391)
            NotifySuccess("Teleport", "Berhasil ke Enchanting Altar!")
        end
    end,
})

task.wait(0.1)
MainTab:CreateSection("Cave & Pirate Events")
task.wait(0.1)

MainTab:CreateButton({
    Name     = "Open Mysterious Cave Wall",
    Callback = function()
        task.spawn(function()
            if not Events.searchItemPickedUp then
                Events.searchItemPickedUp = getRemote("RE/SearchItemPickedUp")
            end
            if not Events.gainAccessToMaze then
                Events.gainAccessToMaze = getRemote("RE/GainAccessToMaze")
            end
            if not Events.searchItemPickedUp or not Events.gainAccessToMaze then
                NotifyError("Error", "Remote Cave tidak ditemukan! Coba Reload Remotes.")
                return
            end
            for i = 1, 4 do
                pcall(function() Events.searchItemPickedUp:FireServer("TNT") end)
                task.wait(0.7)
            end
            task.wait(1.5)
            pcall(function() Events.gainAccessToMaze:FireServer() end)
            NotifySuccess("Cave Wall", "Mysterious Cave Wall dibuka!")
        end)
    end,
})

task.wait(0.1)

MainTab:CreateToggle({
    Name         = "Auto Open Pirate Chest",
    CurrentValue = false,
    Flag         = "AutoPirateChest",
    Callback     = function(val)
        _G.AutoOpenPirateChest = val
        if val then
            task.spawn(function()
                while _G.AutoOpenPirateChest do
                    pcall(function()
                        if not Events.claimPirateChest then
                            Events.claimPirateChest = getRemote("RE/ClaimPirateChest")
                        end
                        if not Events.claimPirateChest then return end
                        local storage = workspace:FindFirstChild("PirateChestStorage")
                        if not storage then return end
                        local found = 0
                        for _, chest in ipairs(storage:GetChildren()) do
                            if chest.Name:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") then
                                pcall(function() Events.claimPirateChest:FireServer(chest.Name) end)
                                found += 1
                                task.wait(0.5)
                            end
                        end
                        if found > 0 then
                            NotifySuccess("Pirate Chest", "Claim " .. found .. " chest berhasil!")
                        end
                    end)
                    task.wait(3)
                end
            end)
            NotifySuccess("Pirate Chest", "Auto claim aktif!")
        else
            NotifyWarning("Pirate Chest", "Dimatikan.")
        end
    end,
})

task.wait(0.1)
MainTab:CreateSection("Crystal Mining")
task.wait(0.1)

local function getAxeUUID()
    local uuid = nil
    pcall(function()
        local inv = PlayerData:GetExpect("Inventory")
        if inv and inv.Items then
            for _, item in pairs(inv.Items) do
                local data = ItemUtility and ItemUtility:GetItemData(item.Id)
                if data and data.Data and (
                    data.Data.Name:match("Axe") or
                    data.Data.Name:match("Pickaxe") or
                    data.Data.Name:match("axe")
                ) then
                    uuid = item.UUID
                    Config.axeUuid = uuid
                    break
                end
            end
        end
    end)
    return uuid
end

MainTab:CreateButton({
    Name     = "Manual Mining Crystal",
    Callback = function()
        local axe = getAxeUUID()
        if not axe then
            NotifyError("Mining", "Axe/Pickaxe tidak ditemukan!")
            return
        end
        local hrp = getHRP()
        if not hrp then return end
        local savedCF = hrp.CFrame
        NotifyInfo("Mining", "Otw Crystal Depth...")
        hrp.CFrame = CFrame.new(1645.5, -214, -2630)
        task.wait(2)
        for i = 1, 2 do
            pcall(function()
                if Events.equipItem then Events.equipItem:FireServer(axe, "Gears") end
            end)
            task.wait(3)
        end
        hrp.CFrame = savedCF
        NotifySuccess("Mining", "Selesai! Kembali ke posisi semula.")
    end,
})

task.wait(0.1)

MainTab:CreateToggle({
    Name         = "Auto Mining Crystal",
    CurrentValue = false,
    Flag         = "AutoMining",
    Callback     = function(val)
        Config.AutoMining = val
        if val then
            local axe = getAxeUUID()
            if not axe then
                NotifyWarning("Mining", "Axe tidak ditemukan!")
            else
                pcall(function()
                    if Events.equipItem then Events.equipItem:FireServer(axe, "Gears") end
                end)
                NotifySuccess("Mining", "Auto Mining aktif!")
            end
        else
            NotifyWarning("Mining", "Dimatikan.")
        end
    end,
})

task.wait(0.1)

MainTab:CreateButton({
    Name     = "Consume Cave Crystal",
    Callback = function()
        if not Events.ConsumeCaveCrystal then
            Events.ConsumeCaveCrystal = getRemote("RF/ConsumeCaveCrystal")
        end
        if Events.ConsumeCaveCrystal then
            pcall(function() Events.ConsumeCaveCrystal:InvokeServer() end)
            task.wait(1.5)
            equipRod()
            NotifySuccess("Cave Crystal", "Crystal dikonsumsi & rod di-equip!")
        else
            NotifyError("Error", "Remote tidak ditemukan!")
        end
    end,
})

task.wait(0.1)

MainTab:CreateToggle({
    Name         = "Auto Consume Cave Crystal",
    CurrentValue = false,
    Flag         = "AutoCrystal",
    Callback     = function(val)
        _G.autoConsumeCaveCrystal = val
        if val then
            if not Events.ConsumeCaveCrystal then
                Events.ConsumeCaveCrystal = getRemote("RF/ConsumeCaveCrystal")
            end
            if not Events.ConsumeCaveCrystal then
                NotifyError("Error", "Remote ConsumeCaveCrystal tidak ditemukan!")
                return
            end
            _G.caveCrystalTask = task.spawn(function()
                while _G.autoConsumeCaveCrystal do
                    pcall(function()
                        Events.ConsumeCaveCrystal:InvokeServer()
                        task.wait(1.5)
                        equipRod()
                    end)
                    task.wait(1800)
                end
            end)
            NotifySuccess("Auto Crystal", "Aktif - setiap 30 menit!")
        else
            if _G.caveCrystalTask then
                pcall(function() task.cancel(_G.caveCrystalTask) end)
                _G.caveCrystalTask = nil
            end
            NotifyWarning("Auto Crystal", "Dimatikan.")
        end
    end,
})

-- ====== EXCLUSIVE TAB ======
task.wait(0.2)
ExclusiveTab:CreateSection("Ultra Blatant Fishing")
task.wait(0.1)

local rodSettings = {
    ["0. 3 NOTIF KEDIP"]      = { CompleteDelay = 2.998 },
    ["1. Diamond / Element"]  = { CompleteDelay = 3.7   },
    ["2. 3 NOTIF"]            = { CompleteDelay = 2.890 },
    ["3. GF / Bambu"]         = { CompleteDelay = 3.7   },
    ["4. Ares/Angler/Astral"] = { CompleteDelay = 4.8   },
}
local rodSettingNames = {}
for name in pairs(rodSettings) do table.insert(rodSettingNames, name) end
table.sort(rodSettingNames)

ExclusiveTab:CreateDropdown({
    Name          = "Settings Template",
    Options       = rodSettingNames,
    CurrentOption = {"1. Diamond / Element"},
    Flag          = "UBTemplate",
    Callback      = function(val)
        local chosen = rodSettings[type(val) == "table" and val[1] or val]
        if chosen then Config.UB.Settings.CompleteDelay = chosen.CompleteDelay end
    end,
})

task.wait(0.1)

ExclusiveTab:CreateInput({
    Name                     = "Complete Delay (detik)",
    PlaceholderText          = tostring(Config.UB.Settings.CompleteDelay),
    RemoveTextAfterFocusLost = false,
    Callback                 = function(text)
        local num = tonumber(text)
        if num and num >= 1 then
            Config.UB.Settings.CompleteDelay = num
            NotifySuccess("Delay", "Complete delay: " .. num .. "s")
        else
            NotifyError("Delay", "Minimal 1 detik!")
        end
    end,
})

task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "Ultra Blatant 3N",
    CurrentValue = false,
    Flag         = "UltraBlatant",
    Callback     = function(val)
        needCast = true
        onToggleUB(val)
    end,
})

task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "2N Real + Visual (Amblatant)",
    CurrentValue = false,
    Flag         = "Amblatant",
    Callback     = function(val)
        Config.amblatant = val
        saveCount = 0
        HookRemote("RE/FishCaught",                  "FishCaught")
        HookRemote("RE/CaughtFishVisual",            "CaughtVisual")
        HookRemote("RE/ObtainedNewFishNotification", "FishNotif")
        needCast = true
        onToggleUB(val)
    end,
})

task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "Random Cast (Anti Detection)",
    CurrentValue = false,
    Flag         = "RandomCast",
    Callback     = function(val)
        Config.antiOKOK = val
        NotifyInfo("Random Cast", val and "Aktif - delay random." or "Nonaktif.")
    end,
})

task.wait(0.1)
ExclusiveTab:CreateSection("Legit Fishing")
task.wait(0.1)

local legitSettings = {
    ["0. Default - 0.7"]     = { CatchDelay = 0.7 },
    ["1. DM/ELE/GF - 0.6"]   = { CatchDelay = 0.6 },
    ["2. Ares/Angler - 1.2"] = { CatchDelay = 1.2 },
}
local legitNames = {}
for name in pairs(legitSettings) do table.insert(legitNames, name) end
table.sort(legitNames)

ExclusiveTab:CreateDropdown({
    Name          = "Legit Template",
    Options       = legitNames,
    CurrentOption = {"0. Default - 0.7"},
    Flag          = "LegitTemplate",
    Callback      = function(val)
        local chosen = legitSettings[type(val) == "table" and val[1] or val]
        if chosen then Config.CatchDelay = chosen.CatchDelay end
    end,
})

task.wait(0.1)

ExclusiveTab:CreateInput({
    Name                     = "Catch Delay (detik)",
    PlaceholderText          = "Rekomendasi: 0.7",
    RemoveTextAfterFocusLost = false,
    Callback                 = function(text)
        local num = tonumber(text)
        if num then
            Config.CatchDelay = num
            NotifySuccess("Catch Delay", "Set ke " .. num .. "s")
        end
    end,
})

task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "Legit Fishing (Auto Catch)",
    CurrentValue = false,
    Flag         = "LegitFishing",
    Callback     = function(val)
        Config.AutoCatch = val
        if val then
            equipRod()
            task.wait(0.3)
            if Events.UpdateAutoFishing then
                pcall(function() Events.UpdateAutoFishing:InvokeServer(true) end)
            end
            NotifySuccess("Legit Fishing", "Aktif! Auto catch saat ikan muncul 🎣")
        else
            if Events.UpdateAutoFishing then
                pcall(function() Events.UpdateAutoFishing:InvokeServer(false) end)
            end
            NotifyWarning("Legit Fishing", "Dimatikan.")
        end
    end,
})

task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "Perfection Enchant (Auto Fishing State)",
    CurrentValue = false,
    Flag         = "PerfectionEnchant",
    Callback     = function(val)
        Config.autoFishing = val
        if val then
            Config.HookNotif = true
            if Events.UpdateAutoFishing then
                pcall(function() Events.UpdateAutoFishing:InvokeServer(true) end)
            end
            NotifySuccess("Perfection", "Aktif!")
        else
            if Events.UpdateAutoFishing then
                pcall(function() Events.UpdateAutoFishing:InvokeServer(false) end)
            end
            Config.HookNotif = false
            NotifyWarning("Perfection", "Dimatikan.")
        end
    end,
})

task.wait(0.1)
ExclusiveTab:CreateSection("Auto Sell Fish")
task.wait(0.1)

ExclusiveTab:CreateDropdown({
    Name          = "Metode Sell",
    Options       = {"Delay", "Count"},
    CurrentOption = {"Delay"},
    Flag          = "SellMethod",
    Callback      = function(val)
        Config.AutoSellMethod = type(val) == "table" and val[1] or val
        if Config.AutoSellState then RunAutoSellLoop() end
    end,
})

task.wait(0.1)

ExclusiveTab:CreateInput({
    Name                     = "Sell Value (detik/jumlah)",
    PlaceholderText          = "50",
    RemoveTextAfterFocusLost = false,
    Callback                 = function(text)
        local num = tonumber(text)
        if num and num > 0 then
            Config.AutoSellValue = num
            NotifySuccess("Sell Value", "Set ke " .. num)
        end
    end,
})

task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "Enable Auto Sell",
    CurrentValue = false,
    Flag         = "AutoSell",
    Callback     = function(val)
        Config.AutoSellState = val
        if val then
            RunAutoSellLoop()
            NotifySuccess("Auto Sell", "Aktif! Mode: " .. Config.AutoSellMethod)
        else
            if Tasks.AutoSellThread then
                pcall(function() task.cancel(Tasks.AutoSellThread) end)
            end
            NotifyWarning("Auto Sell", "Dimatikan.")
        end
    end,
})

task.wait(0.1)

ExclusiveTab:CreateButton({
    Name     = "Sell All Now",
    Callback = function()
        if not Events.sell then Events.sell = getRemote("RF/SellAllItems") end
        if Events.sell then
            pcall(function() Events.sell:InvokeServer({}) end)
            NotifySuccess("Sell", "Semua ikan dijual!")
        else
            NotifyError("Error", "Remote Sell tidak ditemukan! Coba Reload Remotes.")
        end
    end,
})

task.wait(0.1)
ExclusiveTab:CreateSection("Auto Favorite")
task.wait(0.1)

ExclusiveTab:CreateDropdown({
    Name          = "Filter Rarity",
    Options       = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","SECRET"},
    CurrentOption = {},
    Flag          = "FavRarity",
    Callback      = function(val)
        Config.SelectedRarities = type(val) == "table" and val or {val}
    end,
})

task.wait(0.1)

ExclusiveTab:CreateDropdown({
    Name          = "Filter Mutation",
    Options       = {"Galaxy","Corrupt","Gemstone","Fairy Dust","Midnight","Color Burn","Holographic","Lightning","Radioactive","Ghost","Gold","Frozen","1x1x1x1","Stone","Sandy","Noob","Moon Fragment","Festive","Albino","Arctic Frost","Disco","Big","Giant","Sparkling","Crystalized","Shiny"},
    CurrentOption = {},
    Flag          = "FavMutation",
    Callback      = function(val)
        Config.SelectedMutations = type(val) == "table" and val or {val}
    end,
})

task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "Auto Favorite",
    CurrentValue = false,
    Flag         = "AutoFav",
    Callback     = function(val)
        Config.AutoFavoriteState = val
        if val then
            Tasks.AutoFavoriteThread = task.spawn(function()
                while Config.AutoFavoriteState do
                    RunAutoFavLoop(false)
                    task.wait(5)
                end
            end)
            NotifySuccess("Auto Favorite", "Aktif! ⭐")
        else
            if Tasks.AutoFavoriteThread then
                pcall(function() task.cancel(Tasks.AutoFavoriteThread) end)
            end
            NotifyWarning("Auto Favorite", "Dimatikan.")
        end
    end,
})

task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "Auto Unfavorite",
    CurrentValue = false,
    Flag         = "AutoUnfav",
    Callback     = function(val)
        Config.AutoUnfavoriteState = val
        if val then
            Tasks.AutoUnfavoriteThread = task.spawn(function()
                while Config.AutoUnfavoriteState do
                    RunAutoFavLoop(true)
                    task.wait(5)
                end
            end)
            NotifySuccess("Auto Unfavorite", "Aktif!")
        else
            if Tasks.AutoUnfavoriteThread then
                pcall(function() task.cancel(Tasks.AutoUnfavoriteThread) end)
            end
            NotifyWarning("Auto Unfavorite", "Dimatikan.")
        end
    end,
})

task.wait(0.1)
ExclusiveTab:CreateSection("Totem Controls")
task.wait(0.1)

local totemData = {
    ["Pilih Totem"] = 0, ["Luck Totem"] = 1,
    ["Mutation Totem"] = 2, ["Shiny Totem"] = 3, ["Love Totem"] = 5
}

ExclusiveTab:CreateDropdown({
    Name          = "Pilih Totem",
    Options       = {"Pilih Totem","Luck Totem","Mutation Totem","Shiny Totem","Love Totem"},
    CurrentOption = {"Pilih Totem"},
    Flag          = "TotemSelect",
    Callback      = function(val)
        local name = type(val) == "table" and val[1] or val
        Config.SelectedTotemID = totemData[name] or 0
        NotifyInfo("Totem", "Dipilih: " .. name)
    end,
})

task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "Auto Spawn Totem (1 jam cooldown)",
    CurrentValue = false,
    Flag         = "AutoTotem",
    Callback     = function(val)
        Config.AutoTotem = val
        if val then
            Tasks.totemTask = task.spawn(function()
                while Config.AutoTotem do
                    pcall(function()
                        local hrp = getHRP()
                        if not hrp then return end
                        local totemUUID = nil
                        pcall(function()
                            local replion = GetPlayerDataReplion()
                            local inv = replion:GetExpect("Inventory")
                            if inv and inv.Totems then
                                for _, item in ipairs(inv.Totems) do
                                    if Config.SelectedTotemID == 0 or item.Id == Config.SelectedTotemID then
                                        totemUUID = item.UUID
                                        break
                                    end
                                end
                            end
                        end)
                        if totemUUID and Events.SpawnTotem then
                            pcall(function() Events.SpawnTotem:FireServer(totemUUID) end)
                            task.wait(3)
                            equipRod()
                            NotifySuccess("Totem", "Berhasil spawn! Cooldown 1 jam.")
                        end
                    end)
                    task.wait(3600)
                end
            end)
            NotifySuccess("Auto Totem", "Aktif!")
        else
            if Tasks.totemTask then
                pcall(function() task.cancel(Tasks.totemTask) end)
                Tasks.totemTask = nil
            end
            NotifyWarning("Auto Totem", "Dimatikan.")
        end
    end,
})

task.wait(0.1)
ExclusiveTab:CreateSection("Webhook (Custom)")
task.wait(0.1)

ExclusiveTab:CreateToggle({
    Name         = "Enable Custom Webhook",
    CurrentValue = false,
    Flag         = "CustomWebhook",
    Callback     = function(val)
        Config.CustomWebhook = val
        NotifyInfo("Webhook", val and "Custom webhook aktif." or "Nonaktif.")
    end,
})

task.wait(0.1)

ExclusiveTab:CreateInput({
    Name                     = "Webhook URL",
    PlaceholderText          = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Callback                 = function(text)
        Config.CustomWebhookUrl = text
        NotifySuccess("Webhook", "URL disimpan!")
    end,
})

-- ====== TELEPORT TAB ======
task.wait(0.2)
TeleportTab:CreateSection("Map Locations")
task.wait(0.1)

local locationNames = {}
for name in pairs(LOCATIONS) do table.insert(locationNames, name) end
table.sort(locationNames)

local selectedLocation = locationNames[1]
TeleportTab:CreateDropdown({
    Name          = "Pilih Lokasi",
    Options       = locationNames,
    CurrentOption = {locationNames[1]},
    Flag          = "LocationSelect",
    Callback      = function(val)
        selectedLocation = type(val) == "table" and val[1] or val
    end,
})

task.wait(0.1)

TeleportTab:CreateButton({
    Name     = "Teleport ke Lokasi",
    Callback = function()
        if selectedLocation and LOCATIONS[selectedLocation] then
            teleportTo(selectedLocation)
            NotifySuccess("Teleport", "Berhasil ke " .. selectedLocation .. "! 🗺️")
        else
            NotifyError("Teleport", "Lokasi tidak ditemukan!")
        end
    end,
})

task.wait(0.1)
TeleportTab:CreateSection("Player Teleport")
task.wait(0.1)

local selectedPlayer = nil
local function getPlayerList()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(list, p.Name) end
    end
    table.sort(list)
    return #list > 0 and list or {"Tidak ada player lain"}
end

TeleportTab:CreateDropdown({
    Name          = "Pilih Player",
    Options       = getPlayerList(),
    CurrentOption = {},
    Flag          = "PlayerSelect",
    Callback      = function(val)
        selectedPlayer = type(val) == "table" and val[1] or val
    end,
})

task.wait(0.1)

TeleportTab:CreateButton({
    Name     = "Teleport ke Player",
    Callback = function()
        if not selectedPlayer then NotifyError("Error", "Pilih player dulu!") return end
        local target = Players:FindFirstChild(selectedPlayer)
        if target and target.Character then
            local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local hrp       = getHRP()
            if hrp and targetHRP then
                hrp.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0)
                NotifySuccess("Teleport", "Berhasil ke " .. selectedPlayer .. "!")
            end
        else
            NotifyError("Error", "Character player tidak ditemukan!")
        end
    end,
})

task.wait(0.1)
TeleportTab:CreateSection("Event Teleport")
task.wait(0.1)

TeleportTab:CreateToggle({
    Name         = "Auto Leviathan Hunt TP",
    CurrentValue = false,
    Flag         = "LeviathanTP",
    Callback     = function(val)
        _G.AutoLeviathanHunt = val
        if val then
            local hasTeleported = false
            Tasks.LeviathanThread = task.spawn(function()
                while _G.AutoLeviathanHunt do
                    pcall(function()
                        local zones = workspace:FindFirstChild("Zones")
                        if zones then
                            local den = zones:FindFirstChild("Leviathan's Den")
                            if den and not hasTeleported then
                                local hrp = getHRP()
                                if hrp then
                                    hrp.CFrame = CFrame.new(3474.053, -287.775, 3472.634)
                                    hasTeleported = true
                                    NotifySuccess("Leviathan", "Berhasil TP ke Leviathan's Den!")
                                end
                            elseif not den then
                                hasTeleported = false
                            end
                        end
                    end)
                    task.wait(5)
                end
            end)
            NotifySuccess("Leviathan Hunt", "Mencari zona Leviathan...")
        else
            if Tasks.LeviathanThread then
                pcall(function() task.cancel(Tasks.LeviathanThread) end)
            end
            NotifyWarning("Leviathan Hunt", "Dimatikan.")
        end
    end,
})

-- ====== SHOP TAB ======
task.wait(0.2)
ShopTab:CreateSection("Buy Weather Event")
task.wait(0.1)

local weatherMap = {
    ["Windy (10k)"]       = "Wind",
    ["Cloudy (20k)"]      = "Cloudy",
    ["Snow (15k)"]        = "Snow",
    ["Stormy (35k)"]      = "Storm",
    ["Radiant (50k)"]     = "Radiant",
    ["Shark Hunt (300k)"] = "Shark Hunt",
}
local weatherNames = {}
for name in pairs(weatherMap) do table.insert(weatherNames, name) end
table.sort(weatherNames)

local selectedWeathers = {}
ShopTab:CreateDropdown({
    Name          = "Pilih Weather",
    Options       = weatherNames,
    CurrentOption = {},
    Flag          = "WeatherSelect",
    Callback      = function(val)
        selectedWeathers = type(val) == "table" and val or {val}
    end,
})

task.wait(0.1)

ShopTab:CreateButton({
    Name     = "Buy Selected Weather",
    Callback = function()
        if #selectedWeathers == 0 then
            NotifyError("Error", "Pilih weather dulu!")
            return
        end
        if not Events.BuyWeather then
            Events.BuyWeather = getRemote("RF/PurchaseWeatherEvent")
        end
        for _, name in ipairs(selectedWeathers) do
            local key = weatherMap[name]
            if key and Events.BuyWeather then
                pcall(function() Events.BuyWeather:InvokeServer(key) end)
                NotifySuccess("Weather", "Purchased: " .. name)
                task.wait(0.5)
            end
        end
    end,
})

task.wait(0.1)

ShopTab:CreateToggle({
    Name         = "Auto Buy Weather",
    CurrentValue = false,
    Flag         = "AutoWeather",
    Callback     = function(val)
        _G.AutoBuyWeather = val
        if val then
            if #selectedWeathers == 0 then
                NotifyError("Error", "Pilih weather dulu!")
                _G.AutoBuyWeather = false
                return
            end
            task.spawn(function()
                while _G.AutoBuyWeather do
                    if not Events.BuyWeather then
                        Events.BuyWeather = getRemote("RF/PurchaseWeatherEvent")
                    end
                    for _, name in ipairs(selectedWeathers) do
                        local key = weatherMap[name]
                        if key and Events.BuyWeather then
                            pcall(function() Events.BuyWeather:InvokeServer(key) end)
                        end
                        task.wait(0.5)
                    end
                    task.wait(5)
                end
            end)
            NotifySuccess("Auto Weather", "Aktif!")
        else
            NotifyWarning("Auto Weather", "Dimatikan.")
        end
    end,
})

-- ====== MISC TAB ======
task.wait(0.2)
MiscTab:CreateSection("Visual & Performance")
task.wait(0.1)

MiscTab:CreateToggle({
    Name         = "No Animation",
    CurrentValue = false,
    Flag         = "NoAnim",
    Callback     = function(val)
        Config.DisableAnimations = val
        local char = LocalPlayer.Character
        if not char then return end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local anim = hum:FindFirstChildOfClass("Animator")
        if not anim then return end
        if val then
            for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
            NotifyInfo("No Animation", "Semua animasi dimatikan.")
        else
            NotifyInfo("No Animation", "Animasi kembali normal.")
        end
    end,
})

task.wait(0.1)

MiscTab:CreateToggle({
    Name         = "FPS Booster",
    CurrentValue = false,
    Flag         = "FPSBooster",
    Callback     = function(val)
        if val then
            for _, v in pairs(workspace:GetDescendants()) do
                pcall(function()
                    if v:IsA("BasePart") then
                        v.Reflectance = 0
                        v.CastShadow  = false
                    elseif v:IsA("Decal") or v:IsA("Texture") then
                        v.Transparency = 1
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                        v.Enabled = false
                    end
                end)
            end
            local Lighting = game:GetService("Lighting")
            Lighting.GlobalShadows = false
            Lighting.FogEnd        = 1e10
            for _, e in pairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then e.Enabled = false end
            end
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            NotifySuccess("FPS Booster", "Aktif! 🚀")
        else
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
            NotifyInfo("FPS Booster", "Grafik kembali normal.")
        end
    end,
})

task.wait(0.1)

local _backup = setmetatable({}, { __mode = "k" })
local function DisableController(ctrl)
    if _backup[ctrl] then return end
    local data = { functions = {} }
    for k, v in pairs(ctrl) do
        if type(v) == "function" then
            data.functions[k] = v
            ctrl[k] = function() end
        end
    end
    _backup[ctrl] = data
end
local function EnableController(ctrl)
    local data = _backup[ctrl]
    if not data then return end
    for k, v in pairs(data.functions) do ctrl[k] = v end
    _backup[ctrl] = nil
end

MiscTab:CreateToggle({
    Name         = "Disable VFX",
    CurrentValue = false,
    Flag         = "DisableVFX",
    Callback     = function(val)
        if Controllers.VFX then
            if val then DisableController(Controllers.VFX) else EnableController(Controllers.VFX) end
            NotifyInfo("VFX", val and "Dimatikan." or "Kembali normal.")
        else
            NotifyWarning("VFX", "VFXController tidak tersedia.")
        end
    end,
})

task.wait(0.1)

MiscTab:CreateToggle({
    Name         = "Disable Cutscene",
    CurrentValue = false,
    Flag         = "DisableCutscene",
    Callback     = function(val)
        if Controllers.Cutscene then
            if val then DisableController(Controllers.Cutscene) else EnableController(Controllers.Cutscene) end
            NotifyInfo("Cutscene", val and "Dimatikan." or "Kembali normal.")
        else
            NotifyWarning("Cutscene", "CutsceneController tidak tersedia.")
        end
    end,
})

task.wait(0.1)
MiscTab:CreateSection("Realtime Stats")
task.wait(0.1)

MiscTab:CreateButton({
    Name     = "Show Stats",
    Callback = function()
        local frames = 0
        local fps    = 0
        local conn
        conn = RunService.RenderStepped:Connect(function()
            frames += 1
        end)
        task.wait(1)
        fps = frames
        conn:Disconnect()
        local ping = 0
        pcall(function()
            ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        end)
        NotifyInfo("Stats", "FPS: " .. fps .. " | Ping: " .. ping .. "ms")
    end,
})

-- ================================================
--    NOTIFIKASI AWAL
-- ================================================
task.wait(0.5)

Rayfield:Notify({
    Title    = "⚡ MNA HUB V11.3 FIXED",
    Content  = "Remote loaded: " .. loadedCount .. " | Semua fitur siap! 🎣",
    Duration = 5,
    Image    = 4483362458,
})
