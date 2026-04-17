--[[
    MNA HUB V11.3 FREE NOT SELL
    UI : Custom UI (v6.0 Style — Crimson Theme)

    CARA KERJA:
    [Ultra Blatant 3N]
      - Setiap cast berhasil → 1 notif masuk antrian (_G.NotifQueue)
      - Processor: kalau notif aktif di layar < 2, tampilkan dari antrian
      - Durasi notif diperpanjang > interval cast → selalu 2 notif di layar

    [amBlantat]
      - Setiap catch REAL dari server → simpan snapshot data ikan
      - Replay: FishCaught 1x + CaughtVisual 1x + Notif Nx
      - TIDAK menggunakan NotifQueue → sistem terpisah, tidak saling ganggu
]]

repeat task.wait(0.5) until game:IsLoaded()
task.wait(2)

-- =============================
--    SERVICES
-- =============================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")
local LocalPlayer       = Players.LocalPlayer
local isMobile          = UserInputService.TouchEnabled

-- =============================
--    NOTIFY HELPER (StarterGui)
-- =============================
local function NotifySuccess(title, msg, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "✅ "..tostring(title), Text = tostring(msg), Duration = dur or 3
        })
    end)
end
local function NotifyError(title, msg, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "❌ "..tostring(title), Text = tostring(msg), Duration = dur or 3
        })
    end)
end
local function NotifyInfo(title, msg, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "ℹ️ "..tostring(title), Text = tostring(msg), Duration = dur or 3
        })
    end)
end
local function NotifyWarning(title, msg, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "⚠️ "..tostring(title), Text = tostring(msg), Duration = dur or 3
        })
    end)
end

-- =============================
--    NET FOLDER
-- =============================
local net = ReplicatedStorage
    :WaitForChild("Packages", 10)
    :WaitForChild("_Index", 10)
    :WaitForChild("sleitnick_net@0.2.0", 10)
    :WaitForChild("net", 10)

print("[MNA HUB] Remotes: " .. #net:GetChildren())

local function GetServerRemote(targetName)
    local allRemotes = net:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            return allRemotes[i + 1]
        end
    end
    return nil
end

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
--    MODULES
-- =============================
local Replion, PlayerData, ItemUtility, TierUtility
local Controllers = {}

pcall(function()
    Replion     = require(ReplicatedStorage.Packages.Replion)
    PlayerData  = Replion.Client:WaitReplion("Data")
    ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
    TierUtility = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TierUtility"))
end)

if isMobile then
    pcall(function()
        local ctrl = ReplicatedStorage:WaitForChild("Controllers", 5)
        Controllers.VFX      = require(ctrl:WaitForChild("VFXController"))
        Controllers.Cutscene = require(ctrl:WaitForChild("CutsceneController"))
        Controllers.Fishing  = require(ctrl:WaitForChild("FishingController"))
    end)
end

-- =============================
--    CONFIG
-- =============================
local Config = {
    AutoCatch           = false,
    CatchDelay          = 0.7,
    UB = {
        Active   = false,
        Settings = { CompleteDelay = 3.7, CancelDelay = 0.3 },
        Remotes  = {},
        Stats    = { castCount = 0, startTime = 0 }
    },
    amblatant           = false,
    antiOKOK            = false,
    autoFishing         = false,
    AutoSellState       = false,
    AutoSellMethod      = "Delay",
    AutoSellValue       = 50,
    AutoFavoriteState   = false,
    AutoUnfavoriteState = false,
    SelectedRarities    = {},
    SelectedMutations   = {},
    AutoTotem           = false,
    SelectedTotemID     = 0,
    CustomWebhook       = false,
    CustomWebhookUrl    = "",
    HookNotif           = false,
    NotifDelay          = 0.1,
    NotifCount          = 3,
    UBNotifDurationMult = 2.0,
    WalkOnWater         = false,
    HideNameTag         = false,
    DisableObtained     = false,
    AutoEggHunt         = false,
    AutoBuyEgg          = false,
    SelectedEggId       = "",
    AutoEvent           = false,
    InstantBobber       = false,
    SkinAnimEnabled     = false,
    SelectedSkinId      = "Eclipse",
}

-- =============================
--    UB NOTIF QUEUE GLOBALS
-- =============================
_G.NotifQueue  = _G.NotifQueue  or {}
_G.NotifActive = _G.NotifActive or 0

local MAX_NOTIF_ONSCREEN = 2
local NOTIF_GAP          = 0.15

local function getNotifDuration()
    return Config.UB.Settings.CompleteDelay * Config.UBNotifDurationMult
end

local Tasks                 = {}
local needCast              = true
local skip                  = false
local isCaught              = false
local lastTimeFishCaught    = nil
local blatantFishCycleCount = 0
local saveCount             = 0

_G.SavedData = _G.SavedData or {
    FishCaught   = {},
    CaughtVisual = {},
    FishNotif    = {}
}

local lastValidFishCaught   = {}
local lastValidCaughtVisual = {}
local lastValidFishNotif    = {}

-- =============================
--    deepCopyArr
-- =============================
local function deepCopyArr(t)
    local out = {}
    for i, v in ipairs(t) do
        if type(v) == "table" then
            local c = {}
            for k, val in pairs(v) do c[k] = val end
            out[i] = c
        else
            out[i] = v
        end
    end
    return out
end

-- =============================
--    HELPER FUNCTIONS
-- =============================
local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local Events = {}

local function equipRod()
    task.wait(0.1)
    if Events.equip then CallRemote(Events.equip, 1) end
    task.wait(0.1)
    if Events.UpdateAutoFishing then
        if Config.autoFishing or Config.AutoCatch then
            CallRemote(Events.UpdateAutoFishing, true)
        end
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

-- =============================
--    HookRemote
-- =============================
local _hookedRemotes = {}
local function HookRemote(humanName, storageKey)
    if _hookedRemotes[humanName] then return true end
    local remote = GetServerRemote(humanName)
    if remote then
        _hookedRemotes[humanName] = true
        remote.OnClientEvent:Connect(function(...)
            _G.SavedData[storageKey] = {...}
            local args = {...}
            if storageKey == "CaughtVisual"
            and tostring(args[1]) == tostring(LocalPlayer.Name) then
                saveCount = saveCount + 1
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
    for _, v in pairs(getconnections(LocalPlayer.Idled)) do
        if v.Disable then v:Disable() elseif v.Disconnect then v:Disconnect() end
    end
end)

-- =============================
--    REMOTES
-- =============================
local function loadRemotes()
    local loaded, failed = 0, 0
    local list = {
        { key="equip",              name="RF/EquipToolFromHotbar"           },
        { key="unequip",            name="RE/UnequipToolFromHotbar"         },
        { key="equipItem",          name="RE/EquipItem"                     },
        { key="CancelFishing",      name="RF/CancelFishingInputs"           },
        { key="charge",             name="RF/ChargeFishingRod"              },
        { key="minigame",           name="RF/RequestFishingMinigameStarted" },
        { key="UpdateAutoFishing",  name="RF/UpdateAutoFishingState"        },
        { key="fishing",            name="RF/CatchFishCompleted"            },
        { key="fishingRE",          name="RE/CatchFishCompleted"            },
        { key="exclaimEvent",       name="RE/ReplicateTextEffect"           },
        { key="sell",               name="RF/SellAllItems"                  },
        { key="favorite",           name="RE/FavoriteItem"                  },
        { key="SpawnTotem",         name="RE/SpawnTotem"                    },
        { key="fishNotif",          name="RE/ObtainedNewFishNotification"   },
        { key="activateAltar",      name="RE/ActivateEnchantingAltar"       },
        { key="searchItemPickedUp", name="RE/SearchItemPickedUp"            },
        { key="gainAccessToMaze",   name="RE/GainAccessToMaze"              },
        { key="claimPirateChest",   name="RE/ClaimPirateChest"              },
        { key="BuyWeather",         name="RF/PurchaseWeatherEvent"          },
        { key="ConsumeCaveCrystal", name="RF/ConsumeCaveCrystal"            },
        { key="CollectEgg",         name="RE/CollectEgg"                    },
        { key="BuyEgg",             name="RF/PurchaseEgg"                   },
        { key="ObtainedNotif",      name="RE/ObtainedItemNotification"      },
    }
    for _, r in ipairs(list) do
        local remote = GetServerRemote(r.name)
        Events[r.key] = remote
        if remote then loaded = loaded + 1
        else failed = failed + 1 end
    end
    print("[MNA HUB] Loaded: " .. loaded .. " | Failed: " .. failed)
    return loaded, failed
end

local loadedCount, failedCount = loadRemotes()

task.spawn(function()
    task.wait(1)
    HookRemote("RE/FishCaught",                  "FishCaught")
    HookRemote("RE/CaughtFishVisual",            "CaughtVisual")
    HookRemote("RE/ObtainedNewFishNotification", "FishNotif")
end)

-- =============================
--    UB NOTIF QUEUE PROCESSOR
--    FIX: guard NotifActive agar tidak drift negatif
-- =============================
local _ubProcessorActive = true
task.spawn(function()
    local cachedNotifRemote = nil
    local function getNotifRemote()
        if not cachedNotifRemote or not cachedNotifRemote.Parent then
            cachedNotifRemote = GetServerRemote("RE/ObtainedNewFishNotification")
        end
        return cachedNotifRemote
    end
    while true do
        task.wait(0.05)
        if not Config.UB.Active then
            -- Reset bersih saat UB tidak aktif
            if _G.NotifActive ~= 0 then _G.NotifActive = 0 end
            if #_G.NotifQueue > 0 then _G.NotifQueue = {} end
        end
        if Config.UB.Active and not Config.amblatant then
            if #_G.NotifQueue > 0 and _G.NotifActive < MAX_NOTIF_ONSCREEN then
                local args = table.remove(_G.NotifQueue, 1)
                local xr_notif = getNotifRemote()
                if xr_notif and type(args) == "table" and #args > 0 then
                    _G.NotifActive = _G.NotifActive + 1
                    FireLocalEvent(xr_notif, unpack(args))
                    local dur = getNotifDuration()
                    -- Simpan referensi UB.Active saat spawn agar tidak drift setelah stop
                    task.spawn(function()
                        task.wait(dur)
                        -- Hanya kurangi kalau UB masih aktif saat ini,
                        -- kalau sudah mati maka processor sudah reset ke 0
                        if Config.UB.Active then
                            _G.NotifActive = math.max(0, _G.NotifActive - 1)
                        end
                    end)
                end
                task.wait(NOTIF_GAP)
            end
        end
    end
end)

-- =============================
--    LOCATIONS
--    FIX teleportTo: gunakan cf.Position agar rotation tidak ganggu offset
-- =============================
local LOCATIONS = {
    ["Fisherman"]             = CFrame.new(-18.065, 9.532, 2734.000),
    ["Sisyphus Statue"]       = CFrame.new(-3754.441, -135.074, -895.376),
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
    ["Easter Cove"]           = CFrame.new(487.230, 4.800, 1183.640),
    ["Easter Island"]         = CFrame.new(520.000, 5.000, 1250.000),
}

-- FIX: pakai cf.Position + offset agar semua teleport benar
local function teleportTo(locationName)
    local cf  = LOCATIONS[locationName]
    local hrp = getHRP()
    if not hrp or not cf then return end
    -- Ambil posisi murni dari CFrame lalu tambahkan offset Y=3
    hrp.CFrame = CFrame.new(cf.Position + Vector3.new(0, 3, 0))
end

-- =============================
--    UB SYSTEM
-- =============================
local function UB_init()
    Config.UB.Remotes.ChargeFishingRod    = GetServerRemote("RF/ChargeFishingRod")
    Config.UB.Remotes.RequestMinigame     = GetServerRemote("RF/RequestFishingMinigameStarted")
    Config.UB.Remotes.CancelFishingInputs = GetServerRemote("RF/CancelFishingInputs")
    Config.UB.Remotes.UpdateAutoFishing   = GetServerRemote("RF/UpdateAutoFishingState")
    Config.UB.Remotes.FishingCompleted    = GetServerRemote("RF/CatchFishCompleted")
    Config.UB.Remotes.FishingCompletedRE  = GetServerRemote("RE/CatchFishCompleted")
    Config.UB.Remotes.equip               = GetServerRemote("RF/EquipToolFromHotbar")
    return true
end

-- =============================
--    amBlantat Replay
--    TIDAK DIUBAH - sistem terpisah dari UB
-- =============================
local function replayAmblatantNotif()
    task.spawn(function()
        local xr_caught = GetServerRemote("RE/FishCaught")
        local xr_visual = GetServerRemote("RE/CaughtFishVisual")
        local xr_notif  = Events.fishNotif

        if xr_caught and #lastValidFishCaught > 0 then
            FireLocalEvent(xr_caught, unpack(lastValidFishCaught))
        end
        task.wait(0.03)

        if xr_visual and #lastValidCaughtVisual > 0 then
            FireLocalEvent(xr_visual, unpack(lastValidCaughtVisual))
        end
        task.wait(0.03)

        if xr_notif and #lastValidFishNotif > 0 then
            for i = 1, Config.NotifCount do
                FireLocalEvent(xr_notif, unpack(lastValidFishNotif))
                if i < Config.NotifCount then
                    task.wait(Config.NotifDelay)
                end
            end
        end
    end)
end

-- =============================
--    UB LOOP
--    FIX: isCaught race condition — reset SETELAH wait loop, bukan sebelum
-- =============================
local function ub_loop()
    while Config.UB.Active do
        local ok, err = pcall(function()
            local currentTime = tick()
            if Config.autoFishing then
                CallRemote(Events.UpdateAutoFishing, true)
            end
            local baseWait = needCast and 0.7 or Config.UB.Settings.CancelDelay
            if Config.antiOKOK then
                baseWait = baseWait + math.random(5, 20) / 100
            end
            task.wait(baseWait)
            needCast = false

            safeFire(function()
                if Config.UB.Remotes.ChargeFishingRod then
                    pcall(function()
                        Config.UB.Remotes.ChargeFishingRod:InvokeServer({ [1] = currentTime })
                    end)
                end
            end)

            if Config.antiOKOK then
                task.wait(math.random(15, 25) / 100)
            else
                task.wait(0.1)
            end

            safeFire(function()
                if Config.UB.Remotes.RequestMinigame then
                    pcall(function()
                        Config.UB.Remotes.RequestMinigame:InvokeServer(1, 0, currentTime)
                    end)
                end
            end)

            local completeDelay = Config.UB.Settings.CompleteDelay
            if Config.antiOKOK then
                completeDelay = completeDelay + math.random(-10, 10) / 100
            end
            task.wait(math.max(completeDelay, 1))

            if not skip then
                pcall(function()
                    if Config.UB.Remotes.FishingCompleted then
                        Config.UB.Remotes.FishingCompleted:InvokeServer()
                    end
                end)
                pcall(function()
                    if Config.UB.Remotes.FishingCompletedRE then
                        Config.UB.Remotes.FishingCompletedRE:FireServer()
                    end
                end)

                if Config.amblatant then
                    -- FIX: reset isCaught DI SINI, tepat sebelum tunggu server reply
                    -- Bukan sebelum InvokeServer, supaya tidak ada race condition
                    isCaught = false
                    local waited = 0
                    while not isCaught and waited < 1.5 do
                        task.wait(0.05)
                        waited = waited + 0.05
                    end

                    if isCaught then
                        isCaught = false
                        if #(_G.SavedData.FishCaught or {}) > 0 then
                            lastValidFishCaught = deepCopyArr(_G.SavedData.FishCaught)
                        end
                        if #(_G.SavedData.CaughtVisual or {}) > 0 then
                            lastValidCaughtVisual = deepCopyArr(_G.SavedData.CaughtVisual)
                        end
                        if #(_G.SavedData.FishNotif or {}) > 0 then
                            lastValidFishNotif = deepCopyArr(_G.SavedData.FishNotif)
                        end
                        if #lastValidFishNotif > 0 then
                            replayAmblatantNotif()
                        end
                    end
                else
                    -- Mode UB biasa: push ke queue
                    if #lastValidFishNotif > 0 then
                        table.insert(_G.NotifQueue, deepCopyArr(lastValidFishNotif))
                    end
                    -- Juga update lastValid kalau isCaught terjadi (dari fishNotif hook)
                    if isCaught then
                        isCaught = false
                        if #(_G.SavedData.FishNotif or {}) > 0 then
                            lastValidFishNotif = deepCopyArr(_G.SavedData.FishNotif)
                        end
                    end
                end
            end
            blatantFishCycleCount = blatantFishCycleCount + 1
        end)
        if not ok then
            warn("[MNA HUB] UB error: " .. tostring(err))
            task.wait(1)
        end
    end
end

local function UB_start()
    if Config.UB.Active then return end
    UB_init()
    Config.UB.Active = true
    needCast = true
    -- FIX: reset bersih saat start
    _G.NotifQueue  = {}
    _G.NotifActive = 0
    isCaught       = false
    Config.UB.Stats.startTime = tick()
    Tasks.ubtask = task.spawn(ub_loop)
    NotifySuccess("Ultra Blatant", "Aktif!")
end

local function UB_stop()
    if not Config.UB.Active then return end
    Config.UB.Active = false
    -- FIX: reset queue dan counter sebelum cancel task
    -- supaya processor loop tidak sempat decrement lagi
    _G.NotifQueue  = {}
    _G.NotifActive = 0
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

-- Anti-stuck
task.spawn(function()
    while true do
        task.wait(5)
        if Config.UB.Active
        and lastTimeFishCaught ~= nil
        and os.clock() - lastTimeFishCaught >= 20
        and blatantFishCycleCount > 1 then
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
                Events.sell = GetServerRemote("RF/SellAllItems")
                if not Events.sell then
                    NotifyError("Auto Sell", "Remote tidak ditemukan!")
                    Config.AutoSellState = false
                    break
                end
            end
            if Config.AutoSellMethod == "Delay" then
                task.wait(math.max(Config.AutoSellValue, 5))
                if Config.AutoSellState then
                    pcall(function() Events.sell:InvokeServer({}) end)
                end
            elseif Config.AutoSellMethod == "Count" then
                local startCount = saveCount
                while Config.AutoSellState and (saveCount - startCount) < Config.AutoSellValue do
                    task.wait(1)
                end
                if Config.AutoSellState then
                    pcall(function() Events.sell:InvokeServer({}) end)
                    NotifySuccess("Auto Sell", "Sell! ("..Config.AutoSellValue.." catch)")
                end
            else
                task.wait(5)
            end
        end
    end)
end

-- =============================
--    AUTO FAV
-- =============================
local function GetPlayerDataReplion()
    local ok, result = pcall(function()
        local m = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Replion", 5)
        return require(m).Client:WaitReplion("Data", 5)
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
            if item.Metadata and item.Metadata.Rarity then rarity = item.Metadata.Rarity end
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
    if not Events.favorite then return end
    local ok, invData = pcall(function() return replion:GetExpect("Inventory") end)
    if not ok or not invData or not invData.Items then return end
    local targets = {}
    for _, item in ipairs(invData.Items) do
        local isAlreadyFav = (item.IsFavorite or item.Favorited)
        local skip_item = (isUnfavorite and not isAlreadyFav) or (not isUnfavorite and isAlreadyFav)
        if not skip_item then
            local _, rarity = GetFishNameAndRarity(item)
            local mutation  = GetItemMutationString(item)
            local match = false
            for _, r in ipairs(Config.SelectedRarities) do
                if string.lower(rarity) == string.lower(r) then match = true; break end
            end
            if not match and table.find(Config.SelectedMutations, mutation) then match = true end
            if match and item.UUID then table.insert(targets, item.UUID) end
        end
    end
    if #targets > 0 then
        for _, uuid in ipairs(targets) do
            if (isUnfavorite and not Config.AutoUnfavoriteState)
            or (not isUnfavorite and not Config.AutoFavoriteState) then break end
            pcall(function() Events.favorite:FireServer(uuid) end)
            task.wait(0.35)
        end
    end
end

-- =============================
--    WALK ON WATER
--    FIX: hapus CFrame math yang salah, optimasi heartbeat
-- =============================
local walkOnWaterConn = nil
local function setWalkOnWater(enabled)
    Config.WalkOnWater = enabled
    if walkOnWaterConn then
        walkOnWaterConn:Disconnect()
        walkOnWaterConn = nil
    end
    if enabled then
        walkOnWaterConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            -- Cegah tenggelam: paksa Y tidak turun di bawah level air
            local waterY = 1.5
            if hrp.Position.Y < waterY then
                -- FIX: CFrame yang benar — pertahankan rotation, hanya ubah Y
                hrp.CFrame = CFrame.new(
                    hrp.Position.X,
                    waterY,
                    hrp.Position.Z
                ) * CFrame.fromEulerAnglesXYZ(
                    0,
                    math.atan2(hrp.CFrame.LookVector.X, hrp.CFrame.LookVector.Z),
                    0
                )
            end
        end)
        NotifySuccess("Walk on Water", "Aktif!")
    else
        NotifyWarning("Walk on Water", "Dimatikan.")
    end
end

-- =============================
--    HIDE NAMETAG
-- =============================
local function setHideNameTag(enabled)
    Config.HideNameTag = enabled
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local head = char:FindFirstChild("Head")
        if head then
            for _, v in pairs(head:GetChildren()) do
                if v:IsA("BillboardGui") then
                    v.Enabled = not enabled
                end
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.DisplayDistanceType = enabled
                and Enum.HumanoidDisplayDistanceType.None
                or  Enum.HumanoidDisplayDistanceType.Viewer
        end
    end)
    if enabled then
        NotifySuccess("Hide NameTag", "Nama disembunyikan!")
    else
        NotifyWarning("Hide NameTag", "Nama ditampilkan kembali.")
    end
end

-- =============================
--    DISABLE OBTAINED NOTIFICATIONS 
-- =============================
local obtainedDisabledConns = {}
local function setDisableObtained(enabled)
    Config.DisableObtained = enabled
    if enabled then
        -- Disconnect connections handler asli dari remote ObtainedItemNotification
        local xr = Events.ObtainedNotif
            or GetServerRemote("RE/ObtainedItemNotification")
        if xr then
            pcall(function()
                for _, conn in pairs(getconnections(xr.OnClientEvent)) do
                    if conn.Function then
                        -- Wrap fungsi asli agar bisa di-block
                        local origFn = conn.Function
                        conn:Disable()
                        table.insert(obtainedDisabledConns, {
                            conn = conn,
                            orig = origFn
                        })
                    end
                end
            end)
        end
        NotifySuccess("Disable Obtained", "Notif item disembunyikan!")
    else
        -- Re-enable semua connection yang dimatikan
        for _, entry in ipairs(obtainedDisabledConns) do
            pcall(function()
                if entry.conn and entry.conn.Enable then
                    entry.conn:Enable()
                end
            end)
        end
        obtainedDisabledConns = {}
        NotifyWarning("Disable Obtained", "Notif item kembali normal.")
    end
end

-- =============================
--    AUTO EGG HUNT
-- =============================
local function startAutoEggHunt()
    if Tasks.EggHuntTask then
        pcall(function() task.cancel(Tasks.EggHuntTask) end)
    end
    Tasks.EggHuntTask = task.spawn(function()
        while Config.AutoEggHunt do
            pcall(function()
                local eggFolder = workspace:FindFirstChild("Eggs")
                    or workspace:FindFirstChild("EasterEggs")
                    or workspace:FindFirstChild("EggStorage")
                if not eggFolder then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and obj.Name:lower():find("egg") then
                            local hrp = getHRP()
                            if hrp then
                                hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0))
                                task.wait(0.3)
                                if Events.CollectEgg then
                                    pcall(function() Events.CollectEgg:FireServer(obj.Name) end)
                                end
                                task.wait(0.2)
                            end
                        end
                    end
                else
                    for _, egg in pairs(eggFolder:GetChildren()) do
                        if not Config.AutoEggHunt then break end
                        local hrp = getHRP()
                        if hrp and egg:IsA("BasePart") then
                            hrp.CFrame = CFrame.new(egg.Position + Vector3.new(0, 3, 0))
                            task.wait(0.3)
                            if Events.CollectEgg then
                                pcall(function() Events.CollectEgg:FireServer(egg.Name) end)
                            end
                            task.wait(0.2)
                        end
                    end
                end
            end)
            task.wait(2)
        end
    end)
end

-- =============================
--    AUTO BUY EGG
-- =============================
local EggShopList = {
    ["Basic Egg (Free)"]    = { id = "BasicEgg",     cost = 0     },
    ["Common Egg (500)"]    = { id = "CommonEgg",    cost = 500   },
    ["Rare Egg (2000)"]     = { id = "RareEgg",      cost = 2000  },
    ["Epic Egg (5000)"]     = { id = "EpicEgg",      cost = 5000  },
    ["Legendary Egg (15k)"] = { id = "LegendaryEgg", cost = 15000 },
    ["Easter Egg (500)"]    = { id = "EasterEgg",    cost = 500   },
}

local function startAutoBuyEgg()
    if Tasks.BuyEggTask then
        pcall(function() task.cancel(Tasks.BuyEggTask) end)
    end
    Tasks.BuyEggTask = task.spawn(function()
        while Config.AutoBuyEgg do
            pcall(function()
                if Events.BuyEgg and Config.SelectedEggId ~= "" then
                    Events.BuyEgg:InvokeServer(Config.SelectedEggId)
                end
            end)
            task.wait(1.5)
        end
    end)
end

-- =============================
--    AUTO EVENT (Easter)
-- =============================
local function startAutoEvent()
    if Tasks.AutoEventTask then
        pcall(function() task.cancel(Tasks.AutoEventTask) end)
    end
    Tasks.AutoEventTask = task.spawn(function()
        while Config.AutoEvent do
            pcall(function()
                local eventFolder = workspace:FindFirstChild("Events")
                    or workspace:FindFirstChild("EventObjects")
                    or workspace:FindFirstChild("ActiveEvents")
                if eventFolder then
                    for _, obj in pairs(eventFolder:GetDescendants()) do
                        if not Config.AutoEvent then break end
                        if obj:IsA("BasePart") or obj:IsA("Model") then
                            local hrp = getHRP()
                            if hrp then
                                local pos
                                if obj:IsA("Model") and obj.PrimaryPart then
                                    pos = obj.PrimaryPart.Position
                                elseif obj:IsA("BasePart") then
                                    pos = obj.Position
                                end
                                if pos then
                                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                                    task.wait(0.5)
                                    for _, remote in pairs(net:GetChildren()) do
                                        if remote.Name:lower():find("event")
                                        or remote.Name:lower():find("interact") then
                                            pcall(function()
                                                if remote:IsA("RemoteEvent") then
                                                    remote:FireServer(obj.Name)
                                                end
                                            end)
                                        end
                                    end
                                    task.wait(0.3)
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(3)
        end
    end)
end

-- =============================
--    PING PANEL (sederhana, pojok kanan atas)
-- =============================
local pingGui  = nil
local pingConn = nil

local function createPingPanel()
    if pingGui then pingGui:Destroy(); pingGui = nil end
    if pingConn then pcall(function() task.cancel(pingConn) end); pingConn = nil end

    pingGui = Instance.new("ScreenGui")
    pingGui.Name           = "MNA_PingPanel"
    pingGui.ResetOnSpawn   = false
    pingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pingGui.Parent         = game:GetService("CoreGui")

    local frame = Instance.new("Frame", pingGui)
    frame.Size                  = UDim2.new(0, 130, 0, 52)
    frame.Position              = UDim2.new(1, -145, 0, 8)
    frame.BackgroundColor3      = Color3.fromRGB(18, 18, 28)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel       = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(200, 50, 50); stroke.Thickness = 1.2

    local lblTitle = Instance.new("TextLabel", frame)
    lblTitle.Size = UDim2.new(1, 0, 0.45, 0)
    lblTitle.BackgroundTransparency = 1
    lblTitle.Text = "MNA HUB — STATS"
    lblTitle.TextColor3 = Color3.fromRGB(200, 50, 50)
    lblTitle.TextSize = 10; lblTitle.Font = Enum.Font.GothamBold
    lblTitle.TextXAlignment = Enum.TextXAlignment.Center

    local lblStats = Instance.new("TextLabel", frame)
    lblStats.Size = UDim2.new(1, 0, 0.55, 0)
    lblStats.Position = UDim2.new(0, 0, 0.45, 0)
    lblStats.BackgroundTransparency = 1
    lblStats.Text = "Ping: -- ms  |  FPS: --"
    lblStats.TextColor3 = Color3.fromRGB(240, 240, 240)
    lblStats.TextSize = 11; lblStats.Font = Enum.Font.Gotham
    lblStats.TextXAlignment = Enum.TextXAlignment.Center

    local fpsCount, fpsAccum = 0, 0
    local fpsConn = RunService.RenderStepped:Connect(function(dt)
        fpsCount = fpsCount + 1
        fpsAccum = fpsAccum + dt
    end)

    pingConn = task.spawn(function()
        while pingGui and pingGui.Parent do
            task.wait(1)
            local ping = 0
            pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
            local fps = math.floor(fpsCount / math.max(fpsAccum, 0.001))
            fpsCount, fpsAccum = 0, 0
            local icon = ping < 80 and "🟢" or ping < 150 and "🟡" or "🔴"
            if lblStats and lblStats.Parent then
                lblStats.Text = icon.." "..ping.."ms  |  "..fps.." FPS"
            end
        end
        fpsConn:Disconnect()
    end)

    frame.Draggable = true
    return pingGui
end

local function destroyPingPanel()
    if pingConn then pcall(function() task.cancel(pingConn) end); pingConn = nil end
    if pingGui then pingGui:Destroy(); pingGui = nil end
end

-- =============================
--    AURA ANIMASI
--    FIX: simpan CharacterAdded connection agar tidak leak
-- =============================
local auraEffect    = nil
local auraConn      = nil
local auraCharConn  = nil  -- FIX: simpan untuk disconnect

local AuraList = {
    ["None"]        = nil,
    ["Fire Aura"]   = { color = Color3.fromRGB(255, 80, 0),    speed = 2   },
    ["Ice Aura"]    = { color = Color3.fromRGB(100, 200, 255),  speed = 1.5 },
    ["Dark Aura"]   = { color = Color3.fromRGB(80, 0, 120),    speed = 3   },
    ["Gold Aura"]   = { color = Color3.fromRGB(255, 200, 0),   speed = 2   },
    ["Nature Aura"] = { color = Color3.fromRGB(50, 200, 50),   speed = 1   },
    ["Rainbow"]     = { color = Color3.fromRGB(255, 0, 128),   speed = 4   },
}

local function applyAura(auraName)
    -- Hapus aura lama
    if auraEffect then auraEffect:Destroy(); auraEffect = nil end
    if auraConn   then auraConn:Disconnect(); auraConn = nil end
    -- FIX: disconnect CharacterAdded sebelumnya agar tidak leak
    if auraCharConn then auraCharConn:Disconnect(); auraCharConn = nil end

    local data = AuraList[auraName]
    if not data then
        NotifyWarning("Aura", "Aura dihapus.")
        return
    end

    local char = LocalPlayer.Character
    if not char then NotifyError("Aura", "Character belum ada!"); return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local attachment = Instance.new("Attachment", hrp)
    local particle   = Instance.new("ParticleEmitter", attachment)

    particle.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   data.color),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1,   data.color),
    })
    particle.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.5),
        NumberSequenceKeypoint.new(0.5, 1.2),
        NumberSequenceKeypoint.new(1,   0),
    })
    particle.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.5, 0.4),
        NumberSequenceKeypoint.new(1,   1),
    })
    particle.LightEmission = 0.8
    particle.LightInfluence = 0.2
    particle.Speed       = NumberRange.new(data.speed, data.speed * 2)
    particle.Rate        = 30
    particle.Lifetime    = NumberRange.new(0.8, 1.5)
    particle.SpreadAngle = Vector2.new(180, 180)
    particle.RotSpeed    = NumberRange.new(-45, 45)
    particle.Rotation    = NumberRange.new(0, 360)

    auraEffect = attachment

    if auraName == "Rainbow" then
        local hue = 0
        auraConn = RunService.Heartbeat:Connect(function(dt)
            hue = (hue + dt * 0.5) % 1
            particle.Color = ColorSequence.new(Color3.fromHSV(hue, 1, 1))
        end)
    end

    -- FIX: satu connection saja, simpan referensinya
    auraCharConn = LocalPlayer.CharacterAdded:Connect(function()
        if auraEffect then auraEffect:Destroy(); auraEffect = nil end
        if auraConn   then auraConn:Disconnect(); auraConn = nil end
        task.wait(1)
        applyAura(auraName)
    end)

    NotifySuccess("Aura", auraName .. " aktif!")
end

-- =============================
--    INSTANT BOBBER 
-- =============================
local InstantBobberState = {
    instantOverrideActive    = false,
    instantOverrideSetupDone = false,
    activeBaitsByUserId      = nil,
    cosmeticFolder           = nil,
    baitCastConn             = nil,
    baitDestroyedConn        = nil,
    renderConn               = nil,
}

local function patchInstantBobber(enabled)
    if not enabled then
        InstantBobberState.instantOverrideActive = false
        if InstantBobberState.activeBaitsByUserId then
            table.clear(InstantBobberState.activeBaitsByUserId)
        end
        if InstantBobberState.renderConn then
            InstantBobberState.renderConn:Disconnect()
            InstantBobberState.renderConn = nil
        end
        return
    end

    InstantBobberState.instantOverrideActive    = true
    InstantBobberState.activeBaitsByUserId       = InstantBobberState.activeBaitsByUserId or {}
    table.clear(InstantBobberState.activeBaitsByUserId)

    if InstantBobberState.instantOverrideSetupDone then return end
    InstantBobberState.instantOverrideSetupDone = true

    local ok, cosmeticFolder = pcall(function()
        return workspace:WaitForChild("CosmeticFolder", 5)
    end)
    if not ok or not cosmeticFolder then
        InstantBobberState.instantOverrideSetupDone = false
        InstantBobberState.instantOverrideActive    = false
        return
    end
    InstantBobberState.cosmeticFolder = cosmeticFolder

    local baitCastVisual = GetServerRemote("RE/BaitCastVisual")
    local baitDestroyed  = GetServerRemote("RE/BaitDestroyed")

    if not baitCastVisual or not baitCastVisual:IsA("RemoteEvent")
    or not baitDestroyed  or not baitDestroyed:IsA("RemoteEvent") then
        InstantBobberState.instantOverrideSetupDone = false
        InstantBobberState.instantOverrideActive    = false
        return
    end

    InstantBobberState.baitCastConn = baitCastVisual.OnClientEvent:Connect(function(player, data)
        if not InstantBobberState.instantOverrideActive then return end
        if not player or not player.UserId then return end
        if not data or not data.CastPosition or typeof(data.CastPosition) ~= "Vector3" then return end
        InstantBobberState.activeBaitsByUserId[player.UserId] = {
            pivot     = CFrame.new(data.CastPosition),
            expiresAt = tick() + 1.5,
        }
    end)

    InstantBobberState.baitDestroyedConn = baitDestroyed.OnClientEvent:Connect(function(player)
        if not InstantBobberState.instantOverrideActive then return end
        if not player or not player.UserId then return end
        InstantBobberState.activeBaitsByUserId[player.UserId] = nil
    end)

    InstantBobberState.renderConn = RunService.RenderStepped:Connect(function()
        if not InstantBobberState.instantOverrideActive then return end
        local now = tick()
        local cf  = InstantBobberState.cosmeticFolder
        if not cf then return end
        for userId, entry in pairs(InstantBobberState.activeBaitsByUserId) do
            if now > entry.expiresAt then
                InstantBobberState.activeBaitsByUserId[userId] = nil
            else
                local model = cf:FindFirstChild(tostring(userId))
                if model and model.PivotTo then
                    model:PivotTo(entry.pivot)
                end
            end
        end
    end)
end

-- =============================
--    CUSTOM SKIN ANIMATION
-- =============================
local SkinAnimation = (function()
    local char     = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    local Animator = humanoid:FindFirstChildOfClass("Animator")
                  or Instance.new("Animator", humanoid)

    local SkinDatabase = {
        ["Eclipse"]         = "rbxassetid://107940819382815",
        ["HolyTrident"]     = "rbxassetid://128167068291703",
        ["SoulScythe"]      = "rbxassetid://82259219343456",
        ["OceanicHarpoon"]  = "rbxassetid://76325124055693",
        ["BinaryEdge"]      = "rbxassetid://109653945741202",
        ["Vanquisher"]      = "rbxassetid://93884986836266",
        ["KrampusScythe"]   = "rbxassetid://134934781977605",
        ["BanHammer"]       = "rbxassetid://96285280763544",
        ["CorruptionEdge"]  = "rbxassetid://126613975718573",
        ["PrincessParasol"] = "rbxassetid://99143072029495",
    }

    local CurrentSkin, AnimPool, IsEnabled = nil, {}, false

    local function LoadPool(skinId)
        local animId = SkinDatabase[skinId]
        if not animId then return false end
        for _, t in ipairs(AnimPool) do pcall(function() t:Destroy() end) end
        AnimPool = {}
        local anim = Instance.new("Animation")
        anim.AnimationId = animId
        for _ = 1, 3 do
            local t = Animator:LoadAnimation(anim)
            t.Priority = Enum.AnimationPriority.Action4
            table.insert(AnimPool, t)
        end
        return true
    end

    humanoid.AnimationPlayed:Connect(function(track)
        if not IsEnabled then return end
        local name = string.lower(track.Name or "")
        if name:find("fishcaught") or name:find("caught") then
            local nextTrack = AnimPool[math.random(1, math.max(1, #AnimPool))]
            if nextTrack then
                pcall(function() track:Stop(0); nextTrack:Play(0, 1, 1) end)
            end
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        local h = newChar:WaitForChild("Humanoid")
        local a = h:FindFirstChildOfClass("Animator") or Instance.new("Animator", h)
        Animator = a
        if IsEnabled and CurrentSkin then LoadPool(CurrentSkin) end
    end)

    local API = {}
    function API.Switch(id)  CurrentSkin = id; if IsEnabled then LoadPool(id) end end
    function API.Enable()    if not CurrentSkin then return end; IsEnabled = LoadPool(CurrentSkin) end
    function API.Disable()   IsEnabled = false end
    return API
end)()

-- =============================
--    AUTO EVENT TELEPORT
-- =============================
local autoEventTPEnabled   = false
local autoEventThread      = nil
local createdEventPlatform = nil
local selectedAutoEvents   = {}

local eventTPData = {
    ["Worm Hunt"] = {
        TargetName = "Model",
        Locations  = {
            Vector3.new(2190.85,   -1.4,  97.575),
            Vector3.new(-2450.679, -1.4,  139.731),
            Vector3.new(-267.479,  -1.4, 5188.531),
            Vector3.new(-327,      -1.4,  2422),
        },
        PlatformY = 107, Priority = 1
    },
    ["Megalodon Hunt"] = {
        TargetName = "Megalodon Hunt",
        Locations  = {
            Vector3.new(-1076.3,  -1.4, 1676.2),
            Vector3.new(-1191.8,  -1.4, 3597.3),
            Vector3.new( 412.7,   -1.4, 4134.4),
        },
        PlatformY = 107, Priority = 2
    },
    ["Ghost Shark Hunt"] = {
        TargetName = "Ghost Shark Hunt",
        Locations  = {
            Vector3.new( 489.559,  -1.35,   25.406),
            Vector3.new(-1358.216, -1.35, 4100.556),
            Vector3.new( 627.859,  -1.35, 3798.081),
        },
        PlatformY = 107, Priority = 3
    },
    ["Shark Hunt"] = {
        TargetName = "Shark Hunt",
        Locations  = {
            Vector3.new(   1.65, -1.35, 2095.725),
            Vector3.new(1369.95, -1.35,  930.125),
            Vector3.new(-1585.5, -1.35, 1242.875),
            Vector3.new(-1896.8, -1.35, 2634.375),
        },
        PlatformY = 107, Priority = 4
    },
    ["Thunderzilla Hunt"] = {
        TargetName = "Shocked",
        Locations  = { Vector3.new(2071.847, -2.673, 15.144) },
        PlatformY  = 107, Priority = 5
    },
}

local function destroyEventPlatform()
    if createdEventPlatform then
        createdEventPlatform:Destroy()
        createdEventPlatform = nil
    end
end

local function createAndTPtoPlatform(targetPos, yOffset)
    local hrp = getHRP()
    if not hrp then return end
    local desiredPos = Vector3.new(targetPos.X, yOffset, targetPos.Z)
    if createdEventPlatform and createdEventPlatform.Parent then
        createdEventPlatform.Position = desiredPos
    else
        destroyEventPlatform()
        local p = Instance.new("Part")
        p.Size        = Vector3.new(5, 1, 5)
        p.Position    = desiredPos
        p.Anchored    = true
        p.Transparency = 1
        p.CanCollide  = true
        p.Name        = "MNA_EventPlatform"
        p.Parent      = workspace
        createdEventPlatform = p
    end
    hrp.CFrame = CFrame.new(createdEventPlatform.Position + Vector3.new(0, 3, 0))
end

local megCheckRadius = 150
local function runAutoEventTP()
    while autoEventTPEnabled do
        local sorted = {}
        for _, eName in ipairs(selectedAutoEvents) do
            if eventTPData[eName] then table.insert(sorted, eventTPData[eName]) end
        end
        table.sort(sorted, function(a, b) return a.Priority < b.Priority end)

        for _, cfg in ipairs(sorted) do
            if not autoEventTPEnabled then break end
            local foundPos = nil

            if cfg.TargetName == "Model" then
                local menuRings = workspace:FindFirstChild("!!! MENU RINGS")
                if menuRings then
                    for _, props in ipairs(menuRings:GetChildren()) do
                        if props.Name == "Props" then
                            local model = props:FindFirstChild("Model")
                            if model and model.PrimaryPart then
                                local mPos = model.PrimaryPart.Position
                                for _, loc in ipairs(cfg.Locations) do
                                    if (mPos - loc).Magnitude <= megCheckRadius then
                                        foundPos = mPos; break
                                    end
                                end
                            end
                        end
                        if foundPos then break end
                    end
                end
            else
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d.Name == cfg.TargetName then
                        local pos
                        if d:IsA("BasePart") then pos = d.Position
                        elseif d.PrimaryPart then pos = d.PrimaryPart.Position end
                        if pos then
                            for _, loc in ipairs(cfg.Locations) do
                                if (pos - loc).Magnitude <= megCheckRadius then
                                    foundPos = pos; break
                                end
                            end
                        end
                    end
                    if foundPos then break end
                end
            end

            if foundPos then
                createAndTPtoPlatform(foundPos, cfg.PlatformY)
                break
            end
        end
        task.wait(0.5)
    end
    destroyEventPlatform()
end

-- =============================
--    ENCHANT HELPERS
-- =============================
local enchantIdMap = {
    ["Big Hunter 1"]=3,    ["Cursed 1"]=12,         ["Empowered 1"]=9,
    ["Glistening 1"]=1,    ["Gold Digger 1"]=4,     ["Leprechaun 1"]=5,
    ["Leprechaun 2"]=6,    ["Mutation Hunter 1"]=7, ["Mutation Hunter 2"]=14,
    ["Prismatic 1"]=13,    ["Reeler 1"]=2,           ["Stargazer 1"]=8,
    ["Stormhunter 1"]=11,  ["XPerienced 1"]=10,     ["SECRET Hunter"]=16,
    ["Shark Hunter"]=20,   ["Stargazer II"]=17,      ["Stormhunter II"]=19,
    ["Leprechaun II"]=6,   ["Reeler II"]=21,         ["Mutation Hunter III"]=22,
    ["Fairy Hunter 1"]=15,
}
local STONE_IDS = { ["Enchant Stones"]=10, ["Evolved Enchant Stone"]=558 }

local function getEnchantStoneCount()
    local total = 0
    pcall(function()
        if not PlayerData then return end
        local inv = PlayerData:GetExpect("Inventory")
        if not inv or not inv.Items then return end
        local tid = STONE_IDS[_G.SelectedStoneType or "Enchant Stones"]
        for _, item in ipairs(inv.Items) do
            if item.Id == tid then total = total + (item.Quantity or 1) end
        end
    end)
    return total
end

local function getEquippedRodName()
    local name = "None"
    pcall(function()
        if not PlayerData then return end
        local eq  = PlayerData:Get("EquippedItems")
        if not eq then return end
        local inv = PlayerData:GetExpect("Inventory")
        if not inv or not inv["Fishing Rods"] then return end
        for _, uuid in pairs(eq) do
            for _, rod in ipairs(inv["Fishing Rods"]) do
                if rod.UUID == uuid then
                    local d = ItemUtility and ItemUtility:GetItemData(rod.Id)
                    name = (d and d.Data and d.Data.Name) or "Unknown"
                end
            end
        end
    end)
    return name
end

local function getCurrentRodEnchant()
    local eid = nil
    pcall(function()
        if not PlayerData then return end
        local eq  = PlayerData:Get("EquippedItems")
        if not eq then return end
        local inv = PlayerData:GetExpect("Inventory")
        if not inv or not inv["Fishing Rods"] then return end
        for _, uuid in pairs(eq) do
            for _, rod in ipairs(inv["Fishing Rods"]) do
                if rod.UUID == uuid and rod.Metadata and rod.Metadata.EnchantId then
                    eid = rod.Metadata.EnchantId
                end
            end
        end
    end)
    return eid
end

local function findEnchantStones()
    local stones = {}
    pcall(function()
        if not PlayerData then return end
        local inv = PlayerData:GetExpect("Inventory")
        if not inv or not inv.Items then return end
        local tid = STONE_IDS[_G.SelectedStoneType or "Enchant Stones"]
        for _, item in ipairs(inv.Items) do
            if item.Id == tid then table.insert(stones, item) end
        end
    end)
    return stones
end

local function countHotbarButtons()
    local count = 5
    pcall(function()
        local bp = LocalPlayer.PlayerGui:WaitForChild("Backpack", 3)
        local dp = bp:WaitForChild("Display", 3)
        count = 0
        for _, c in ipairs(dp:GetChildren()) do
            if c:IsA("ImageButton") then count = count + 1 end
        end
    end)
    return count
end

-- =============================
--    REALTIME STATS PANEL 
-- =============================
local realtimePanelGui  = nil
local realtimePanelTask = nil

local function createRealtimePanel()
    if realtimePanelGui then realtimePanelGui:Destroy(); realtimePanelGui = nil end
    if realtimePanelTask then pcall(function() task.cancel(realtimePanelTask) end); realtimePanelTask = nil end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MNA_RealtimePanel"; gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = game:GetService("CoreGui")
    realtimePanelGui = gui

    local main = Instance.new("Frame", gui)
    main.Size = UDim2.new(0, 250, 0, 90)
    main.Position = UDim2.new(0.5, -125, 1, -125)
    main.BackgroundColor3 = Color3.fromRGB(14, 0, 28)
    main.BackgroundTransparency = 0.2; main.BorderSizePixel = 0; main.Active = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", main)
    st.Color = Color3.fromRGB(200, 50, 50); st.Thickness = 1.8

    local header = Instance.new("Frame", main)
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    header.BackgroundTransparency = 0.8; header.BorderSizePixel = 0
    local titleLbl = Instance.new("TextLabel", header)
    titleLbl.Size = UDim2.new(1, -8, 1, 0); titleLbl.Position = UDim2.new(0, 8, 0, 0)
    titleLbl.BackgroundTransparency = 1; titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12; titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = "MNA HUB — REALTIME STATS"
    titleLbl.TextColor3 = Color3.fromRGB(200, 50, 50)

    local statsF = Instance.new("Frame", main)
    statsF.Position = UDim2.new(0, 8, 0, 30); statsF.Size = UDim2.new(1, -16, 1, -36)
    statsF.BackgroundTransparency = 1
    local layout = Instance.new("UIListLayout", statsF)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 6)

    local function makeStat()
        local box = Instance.new("Frame", statsF)
        box.Size = UDim2.new(0, 54, 1, 0)
        box.BackgroundColor3 = Color3.fromRGB(40, 0, 60)
        box.BackgroundTransparency = 0.2; box.BorderSizePixel = 0
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
        local s2 = Instance.new("UIStroke", box)
        s2.Color = Color3.fromRGB(200, 50, 50); s2.Thickness = 1.2
        local lbl = Instance.new("TextLabel", box)
        lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextWrapped = true
        lbl.TextColor3 = Color3.fromRGB(240, 200, 200)
        return lbl
    end

    local pingLbl  = makeStat()
    local fpsLbl   = makeStat()
    local notifLbl = makeStat()
    local timeLbl  = makeStat()

    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = main.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    local fpsFrames, fpsCurrent, fpsLast = 0, 0, tick()
    local fpsConn = RunService.RenderStepped:Connect(function()
        fpsFrames = fpsFrames + 1
        if tick() - fpsLast >= 1 then
            fpsCurrent = fpsFrames; fpsFrames = 0; fpsLast = tick()
        end
    end)

    local function colorStat(lbl, v, y, r)
        lbl.TextColor3 = v >= r and Color3.fromRGB(255,80,80)
            or v >= y and Color3.fromRGB(255,210,50)
            or Color3.fromRGB(80,255,140)
    end

    local function fmtTime(s)
        local h = math.floor(s/3600); local m = math.floor((s%3600)/60); local sc = math.floor(s%60)
        return h > 0 and string.format("%02d:%02d:%02d",h,m,sc) or string.format("%02d:%02d",m,sc)
    end

    local sessionStart = tick()
    realtimePanelTask = task.spawn(function()
        while gui.Parent do
            local ping = 0
            pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
            local notif = 0
            pcall(function()
                local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                if not pg then return end
                local tn = pg:FindFirstChild("Text Notifications") or pg:FindFirstChild("TextNotifications")
                if tn then
                    local fr = tn:FindFirstChildOfClass("Frame")
                    if fr then
                        for _, c in ipairs(fr:GetChildren()) do
                            if c.Name == "Tile" or c:IsA("Frame") then notif = notif + 1 end
                        end
                    end
                end
            end)
            pingLbl.Text  = "PING\n"..ping.."ms"
            fpsLbl.Text   = "FPS\n"..fpsCurrent
            notifLbl.Text = "NOTIF\n"..notif
            timeLbl.Text  = "TIME\n"..fmtTime(tick()-sessionStart)
            colorStat(pingLbl,  ping,        120, 200)
            colorStat(fpsLbl,   fpsCurrent,   40,  90)
            colorStat(notifLbl, notif,          8,  20)
            task.wait(1)
        end
        fpsConn:Disconnect()
    end)
    return gui
end

local function destroyRealtimePanel()
    if realtimePanelTask then pcall(function() task.cancel(realtimePanelTask) end); realtimePanelTask = nil end
    if realtimePanelGui then realtimePanelGui:Destroy(); realtimePanelGui = nil end
end

-- =============================
--    FISH NOTIF HOOK
-- =============================
task.spawn(function()
    task.wait(2)
    if Events.fishNotif then
        Events.fishNotif.OnClientEvent:Connect(function(...)
            local args = {...}
            _G.SavedData.FishNotif = args
            lastValidFishNotif     = deepCopyArr(args)
            lastTimeFishCaught     = os.clock()
            isCaught               = true

            if Config.CustomWebhook and Config.CustomWebhookUrl ~= "" then
                pcall(function()
                    local dummyItem = { Id = args[1], Metadata = args[2] }
                    local fishName, fishRarity = GetFishNameAndRarity(dummyItem)
                    local mutation = GetItemMutationString(dummyItem)
                    local weight   = string.format("%.2fkg", (args[2] and args[2].Weight) or 0)
                    local payload  = HttpService:JSONEncode({
                        username = "MNA HUB",
                        embeds = {{
                            title  = "Caught Fish!",
                            color  = 0x00aaff,
                            fields = {
                                { name="Fish",     value=fishName,   inline=true },
                                { name="Rarity",   value=fishRarity, inline=true },
                                { name="Mutation", value=mutation,   inline=true },
                                { name="Weight",   value=weight,     inline=true },
                            },
                            footer = { text = "MNA HUB V11.3" }
                        }}
                    })
                    if typeof(request) == "function" then
                        request({
                            Url     = Config.CustomWebhookUrl,
                            Method  = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body    = payload
                        })
                    end
                end)
            end
        end)
    end
end)

-- Exclaim (legit fishing)
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
                    pcall(function() Events.fishing:InvokeServer() end)
                end
            end)
        end)
    end
end)

-- ══════════════════════════════════════════
--    MNA HUB V11.3 — UI ENGINE (v6.0 style)
--    Semua connect ke Config & fungsi logika
-- ══════════════════════════════════════════

local TweenService     = game:GetService("TweenService")
local StarterGui       = game:GetService("StarterGui")

-- Notify helper (pakai StarterGui, tidak butuh WindUI)
local function NotifySuccess(title, msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "✅ "..tostring(title), Text = tostring(msg), Duration = 3
        })
    end)
end
local function NotifyError(title, msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "❌ "..tostring(title), Text = tostring(msg), Duration = 3
        })
    end)
end
local function NotifyInfo(title, msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "ℹ️ "..tostring(title), Text = tostring(msg), Duration = 3
        })
    end)
end
local function NotifyWarning(title, msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "⚠️ "..tostring(title), Text = tostring(msg), Duration = 3
        })
    end)
end

-- ══════════════════════════════════════════
--    SCREEN GUI SETUP
-- ══════════════════════════════════════════
pcall(function()
    for _, g in pairs({game:GetService("CoreGui"), LocalPlayer.PlayerGui}) do
        local o = g:FindFirstChild("MNAHUB_V113")
        if o then o:Destroy() end
    end
end)

local SG = Instance.new("ScreenGui")
SG.Name           = "MNAHUB_V113"
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder   = 999
pcall(function() SG.Parent = game:GetService("CoreGui") end)
if not SG.Parent then SG.Parent = LocalPlayer.PlayerGui end

-- ══════════════════════════════════════════
--    WINDOW
-- ══════════════════════════════════════════
local Win = Instance.new("Frame")
Win.Name             = "Win"
Win.Size             = UDim2.new(0, 420, 0, 560)
Win.Position         = UDim2.new(0.5, -210, 0.5, -280)
Win.BackgroundColor3 = Color3.fromRGB(9, 13, 20)
Win.BorderSizePixel  = 0
Win.Active           = true
Win.Draggable        = true
Win.Parent           = SG
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 12)
local WStroke = Instance.new("UIStroke", Win)
WStroke.Color = Color3.fromRGB(160, 30, 30)
WStroke.Thickness = 1.5

-- ── TITLE BAR ──
local TB = Instance.new("Frame", Win)
TB.Size = UDim2.new(1, 0, 0, 52)
TB.BackgroundColor3 = Color3.fromRGB(14, 8, 8)
TB.BorderSizePixel  = 0
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 12)
local TBFix = Instance.new("Frame", TB)
TBFix.Size = UDim2.new(1, 0, 0.5, 0)
TBFix.Position = UDim2.new(0, 0, 0.5, 0)
TBFix.BackgroundColor3 = Color3.fromRGB(14, 8, 8)
TBFix.BorderSizePixel  = 0
local TBLine = Instance.new("Frame", TB)
TBLine.Size = UDim2.new(1, 0, 0, 1)
TBLine.Position = UDim2.new(0, 0, 1, -1)
TBLine.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
TBLine.BorderSizePixel  = 0

-- Logo circle
local LogoF = Instance.new("Frame", TB)
LogoF.Size = UDim2.new(0, 36, 0, 36)
LogoF.Position = UDim2.new(0, 9, 0.5, -18)
LogoF.BackgroundColor3 = Color3.fromRGB(20, 8, 8)
LogoF.BorderSizePixel  = 0
Instance.new("UICorner", LogoF).CornerRadius = UDim.new(1, 0)
local LogoStroke = Instance.new("UIStroke", LogoF)
LogoStroke.Color = Color3.fromRGB(200, 50, 50)
LogoStroke.Thickness = 2
local LogoTxt = Instance.new("TextLabel", LogoF)
LogoTxt.Size = UDim2.new(1, 0, 1, 0)
LogoTxt.BackgroundTransparency = 1
LogoTxt.Text = "M"
LogoTxt.TextColor3 = Color3.fromRGB(220, 80, 80)
LogoTxt.TextSize = 17
LogoTxt.Font = Enum.Font.GothamBold

-- Title text
local TTitle = Instance.new("TextLabel", TB)
TTitle.Size = UDim2.new(0, 180, 0, 18)
TTitle.Position = UDim2.new(0, 53, 0, 8)
TTitle.BackgroundTransparency = 1
TTitle.Text = "MNA HUB — V11.4 FREE"
TTitle.TextColor3 = Color3.fromRGB(240, 180, 180)
TTitle.TextSize = 13
TTitle.Font = Enum.Font.GothamBold
TTitle.TextXAlignment = Enum.TextXAlignment.Left

local TSub = Instance.new("TextLabel", TB)
TSub.Size = UDim2.new(0, 200, 0, 12)
TSub.Position = UDim2.new(0, 53, 0, 30)
TSub.BackgroundTransparency = 1
TSub.Text = "discord.gg/xjqJEnsY2  •  Fish It!"
TSub.TextColor3 = Color3.fromRGB(100, 30, 30)
TSub.TextSize = 10
TSub.Font = Enum.Font.Gotham
TSub.TextXAlignment = Enum.TextXAlignment.Left

-- Window buttons
local function mkWinBtn(xOff, lbl, bg)
    local b = Instance.new("TextButton", TB)
    b.Size = UDim2.new(0, 22, 0, 22)
    b.Position = UDim2.new(1, xOff, 0.5, -11)
    b.BackgroundColor3 = bg or Color3.fromRGB(20, 10, 10)
    b.Text = lbl
    b.TextColor3 = Color3.fromRGB(200, 120, 120)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local BMin = mkWinBtn(-78, "—")
local BCls = mkWinBtn(-52, "✕", Color3.fromRGB(110, 18, 18))
-- Badge
local Bdg = Instance.new("TextLabel", TB)
Bdg.Size = UDim2.new(0, 60, 0, 20)
Bdg.Position = UDim2.new(1, -144, 0.5, -10)
Bdg.BackgroundColor3 = Color3.fromRGB(110, 18, 18)
Bdg.Text = "FREE"
Bdg.TextColor3 = Color3.fromRGB(255, 200, 200)
Bdg.TextSize = 10
Bdg.Font = Enum.Font.GothamBold
Bdg.BorderSizePixel = 0
Instance.new("UICorner", Bdg).CornerRadius = UDim.new(1, 0)

local minimized = false
BCls.MouseButton1Click:Connect(function()
    TweenService:Create(Win, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
    task.wait(0.25)
    SG.Enabled = false
end)
BMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Win, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
        Size = minimized and UDim2.new(0, 420, 0, 52) or UDim2.new(0, 420, 0, 560)
    }):Play()
end)

-- ══════════════════════════════════════════
--    CONTENT AREA
-- ══════════════════════════════════════════
local Cont = Instance.new("Frame", Win)
Cont.Size = UDim2.new(1, -16, 1, -62)
Cont.Position = UDim2.new(0, 8, 0, 56)
Cont.BackgroundTransparency = 1
Cont.BorderSizePixel = 0

-- SIDEBAR
local SBar = Instance.new("ScrollingFrame", Cont)
SBar.Size = UDim2.new(0, 124, 1, 0)
SBar.BackgroundTransparency = 1
SBar.BorderSizePixel = 0
SBar.ScrollBarThickness = 2
SBar.ScrollBarImageColor3 = Color3.fromRGB(120, 20, 20)
SBar.CanvasSize = UDim2.new(0, 0, 0, 0)
SBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UIListLayout", SBar).Padding = UDim.new(0, 2)

-- Divider
local SDivider = Instance.new("Frame", Cont)
SDivider.Size = UDim2.new(0, 1, 1, 0)
SDivider.Position = UDim2.new(0, 126, 0, 0)
SDivider.BackgroundColor3 = Color3.fromRGB(80, 15, 15)
SDivider.BorderSizePixel = 0

-- RIGHT PANEL
local RPan = Instance.new("ScrollingFrame", Cont)
RPan.Size = UDim2.new(1, -134, 1, 0)
RPan.Position = UDim2.new(0, 132, 0, 0)
RPan.BackgroundTransparency = 1
RPan.BorderSizePixel = 0
RPan.ScrollBarThickness = 3
RPan.ScrollBarImageColor3 = Color3.fromRGB(160, 30, 30)
RPan.CanvasSize = UDim2.new(0, 0, 0, 0)
RPan.AutomaticCanvasSize = Enum.AutomaticSize.Y
local RPLayout = Instance.new("UIListLayout", RPan)
RPLayout.Padding = UDim.new(0, 5)
local RPPad = Instance.new("UIPadding", RPan)
RPPad.PaddingTop    = UDim.new(0, 4)
RPPad.PaddingBottom = UDim.new(0, 8)
RPPad.PaddingRight  = UDim.new(0, 4)

-- STATUS BAR
local UBar = Instance.new("Frame", Win)
UBar.Size = UDim2.new(1, -16, 0, 30)
UBar.Position = UDim2.new(0, 8, 1, -36)
UBar.BackgroundColor3 = Color3.fromRGB(12, 6, 6)
UBar.BorderSizePixel  = 0
Instance.new("UICorner", UBar).CornerRadius = UDim.new(0, 7)
Instance.new("UIStroke", UBar).Color = Color3.fromRGB(80, 15, 15)

local UName = Instance.new("TextLabel", UBar)
UName.Size = UDim2.new(0, 180, 1, 0)
UName.Position = UDim2.new(0, 10, 0, 0)
UName.BackgroundTransparency = 1
UName.Text = "👑  " .. LocalPlayer.DisplayName .. "  (@" .. LocalPlayer.Name:lower() .. ")"
UName.TextColor3 = Color3.fromRGB(200, 140, 140)
UName.TextSize = 10
UName.Font = Enum.Font.Gotham
UName.TextXAlignment = Enum.TextXAlignment.Left

local UStatus = Instance.new("TextLabel", UBar)
UStatus.Size = UDim2.new(0, 140, 1, 0)
UStatus.Position = UDim2.new(1, -145, 0, 0)
UStatus.BackgroundTransparency = 1
UStatus.Text = "● Ready"
UStatus.TextColor3 = Color3.fromRGB(120, 40, 40)
UStatus.TextSize = 10
UStatus.Font = Enum.Font.Gotham
UStatus.TextXAlignment = Enum.TextXAlignment.Right

local function setStatus(txt, on)
    UStatus.Text = (on and "🔴 " or "● ") .. txt
    UStatus.TextColor3 = on and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(120, 40, 40)
end

-- ══════════════════════════════════════════
--    PANEL / SIDEBAR SYSTEM
-- ══════════════════════════════════════════
local allPanels = {}
local allSBtns  = {}

local function sideSection(txt)
    local l = Instance.new("TextLabel", SBar)
    l.Size = UDim2.new(1, 0, 0, 20)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(100, 25, 25)
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    local p = Instance.new("UIPadding", l)
    p.PaddingLeft = UDim.new(0, 6)
end

local function sideItem(id, icon, lbl)
    local btn = Instance.new("TextButton", SBar)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local iL = Instance.new("TextLabel", btn)
    iL.Size = UDim2.new(0, 20, 1, 0)
    iL.Position = UDim2.new(0, 6, 0, 0)
    iL.BackgroundTransparency = 1
    iL.Text = icon
    iL.TextSize = 14
    iL.Font = Enum.Font.Gotham

    local nL = Instance.new("TextLabel", btn)
    nL.Size = UDim2.new(1, -28, 1, 0)
    nL.Position = UDim2.new(0, 28, 0, 0)
    nL.BackgroundTransparency = 1
    nL.Text = lbl
    nL.TextColor3 = Color3.fromRGB(130, 60, 60)
    nL.TextSize = 11
    nL.Font = Enum.Font.Gotham
    nL.TextXAlignment = Enum.TextXAlignment.Left

    local panel = Instance.new("Frame", RPan)
    panel.Size = UDim2.new(1, 0, 0, 0)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Visible = false
    Instance.new("UIListLayout", panel).Padding = UDim.new(0, 5)

    allPanels[id] = panel
    allSBtns[id]  = { btn = btn, nL = nL }

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(allPanels) do p.Visible = false end
        for _, sb in pairs(allSBtns) do
            TweenService:Create(sb.btn, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
            sb.nL.TextColor3 = Color3.fromRGB(130, 60, 60)
            sb.nL.Font = Enum.Font.Gotham
        end
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundTransparency = 0,
            BackgroundColor3 = Color3.fromRGB(40, 8, 8)
        }):Play()
        nL.TextColor3 = Color3.fromRGB(240, 160, 160)
        nL.Font = Enum.Font.GothamBold
        panel.Visible = true
        RPan.CanvasPosition = Vector2.new(0, 0)
    end)

    return panel
end

-- ── WIDGETS ──
local function addInfo(parent, txt)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundColor3 = Color3.fromRGB(12, 5, 5)
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -14, 1, 0)
    l.Position = UDim2.new(0, 8, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(120, 50, 50)
    l.TextSize = 10
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
end

local function addSection(parent, txt)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 22)
    f.BackgroundColor3 = Color3.fromRGB(14, 6, 6)
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 5)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -14, 1, 0)
    l.Position = UDim2.new(0, 8, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(200, 70, 70)
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
end

local function addToggle(parent, lbl, getVal, setVal, cb)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(10, 5, 5)
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", row).Color = Color3.fromRGB(50, 12, 12)

    local t = Instance.new("TextLabel", row)
    t.Size = UDim2.new(1, -56, 1, 0)
    t.Position = UDim2.new(0, 10, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = lbl
    t.TextColor3 = Color3.fromRGB(190, 130, 130)
    t.TextSize = 11
    t.Font = Enum.Font.Gotham
    t.TextXAlignment = Enum.TextXAlignment.Left

    local pill = Instance.new("TextButton", row)
    pill.Size = UDim2.new(0, 40, 0, 20)
    pill.Position = UDim2.new(1, -47, 0.5, -10)
    local initOn = getVal()
    pill.BackgroundColor3 = initOn and Color3.fromRGB(160, 25, 25) or Color3.fromRGB(22, 10, 10)
    pill.Text = ""
    pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame", pill)
    circle.Size = UDim2.new(0, 14, 0, 14)
    circle.Position = initOn and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.BorderSizePixel = 0
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local function doToggle()
        setVal(not getVal())
        local on = getVal()
        TweenService:Create(pill,   TweenInfo.new(0.15), { BackgroundColor3 = on and Color3.fromRGB(160, 25, 25) or Color3.fromRGB(22, 10, 10) }):Play()
        TweenService:Create(circle, TweenInfo.new(0.15), { Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) }):Play()
        TweenService:Create(row,    TweenInfo.new(0.15), { BackgroundColor3 = on and Color3.fromRGB(14, 5, 5) or Color3.fromRGB(10, 5, 5) }):Play()
        if cb then pcall(cb, on) end
    end
    pill.MouseButton1Click:Connect(doToggle)
    row.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then doToggle() end
    end)
end

local function addSlider(parent, lbl, mn, mx, def, step, cb)
    step = step or 1
    local sf = Instance.new("Frame", parent)
    sf.Size = UDim2.new(1, 0, 0, 50)
    sf.BackgroundColor3 = Color3.fromRGB(10, 5, 5)
    sf.BorderSizePixel = 0
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", sf).Color = Color3.fromRGB(50, 12, 12)

    local sl = Instance.new("TextLabel", sf)
    sl.Size = UDim2.new(1, -14, 0, 18)
    sl.Position = UDim2.new(0, 9, 0, 5)
    sl.BackgroundTransparency = 1
    sl.Text = lbl .. "   " .. tostring(def)
    sl.TextColor3 = Color3.fromRGB(200, 130, 130)
    sl.TextSize = 11
    sl.Font = Enum.Font.Gotham
    sl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", sf)
    track.Size = UDim2.new(1, -18, 0, 5)
    track.Position = UDim2.new(0, 9, 0, 30)
    track.BackgroundColor3 = Color3.fromRGB(22, 8, 8)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local pct  = math.clamp((def - mn) / (mx - mn), 0, 1)
    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(160, 25, 25)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("TextButton", track)
    knob.Size = UDim2.new(0, 13, 0, 13)
    knob.Position = UDim2.new(pct, -6.5, 0.5, -6.5)
    knob.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
    knob.Text = ""
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local drag = false
    knob.MouseButton1Down:Connect(function() drag = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not drag or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        pcall(function()
            local rel = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor((mn + (mx - mn) * rel) / step + 0.5) * step
            rel = math.clamp((val - mn) / (mx - mn), 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, -6.5, 0.5, -6.5)
            sl.Text = lbl .. "   " .. tostring(val)
            if cb then pcall(cb, val) end
        end)
    end)
end

local function addInput(parent, lbl, placeholder, cb)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 50)
    f.BackgroundColor3 = Color3.fromRGB(10, 5, 5)
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", f).Color = Color3.fromRGB(50, 12, 12)

    local lL = Instance.new("TextLabel", f)
    lL.Size = UDim2.new(1, -10, 0, 18)
    lL.Position = UDim2.new(0, 8, 0, 4)
    lL.BackgroundTransparency = 1
    lL.Text = lbl
    lL.TextColor3 = Color3.fromRGB(180, 100, 100)
    lL.TextSize = 10
    lL.Font = Enum.Font.Gotham
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", f)
    box.Size = UDim2.new(1, -16, 0, 20)
    box.Position = UDim2.new(0, 8, 0, 24)
    box.BackgroundColor3 = Color3.fromRGB(16, 8, 8)
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = placeholder or "..."
    box.PlaceholderColor3 = Color3.fromRGB(80, 30, 30)
    box.TextColor3 = Color3.fromRGB(220, 160, 160)
    box.TextSize = 11
    box.Font = Enum.Font.Gotham
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)

    box.FocusLost:Connect(function(enter)
        if enter and cb then pcall(cb, box.Text) end
    end)
end

local function addButton(parent, lbl, col, cb)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, 0, 0, 32)
    b.BackgroundColor3 = col or Color3.fromRGB(110, 18, 18)
    b.Text = lbl
    b.TextColor3 = Color3.fromRGB(255, 200, 200)
    b.TextSize = 11.5
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    b.MouseButton1Click:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), { BackgroundColor3 = Color3.fromRGB(180, 40, 40) }):Play()
        task.wait(0.12)
        TweenService:Create(b, TweenInfo.new(0.08), { BackgroundColor3 = col or Color3.fromRGB(110, 18, 18) }):Play()
        if cb then pcall(cb) end
    end)
end

local function addDropdown(parent, lbl, values, defaultVal, cb)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 50)
    f.BackgroundColor3 = Color3.fromRGB(10, 5, 5)
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", f).Color = Color3.fromRGB(50, 12, 12)

    local lL = Instance.new("TextLabel", f)
    lL.Size = UDim2.new(1, -10, 0, 18)
    lL.Position = UDim2.new(0, 8, 0, 3)
    lL.BackgroundTransparency = 1
    lL.Text = lbl
    lL.TextColor3 = Color3.fromRGB(180, 100, 100)
    lL.TextSize = 10
    lL.Font = Enum.Font.Gotham
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local current = defaultVal or values[1]
    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(1, -16, 0, 22)
    btn.Position = UDim2.new(0, 8, 0, 23)
    btn.BackgroundColor3 = Color3.fromRGB(16, 8, 8)
    btn.Text = "▾  " .. tostring(current)
    btn.TextColor3 = Color3.fromRGB(220, 150, 150)
    btn.TextSize = 11
    btn.Font = Enum.Font.Gotham
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    -- Dropdown list
    local listOpen = false
    local listFrame = nil

    btn.MouseButton1Click:Connect(function()
        if listOpen then
            if listFrame then listFrame:Destroy(); listFrame = nil end
            listOpen = false
            return
        end
        listOpen = true
        listFrame = Instance.new("Frame", SG)
        local absPos = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize
        listFrame.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
        listFrame.Size = UDim2.new(0, absSize.X, 0, math.min(#values * 26, 160))
        listFrame.BackgroundColor3 = Color3.fromRGB(14, 6, 6)
        listFrame.BorderSizePixel = 0
        listFrame.ZIndex = 20
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 6)
        Instance.new("UIStroke", listFrame).Color = Color3.fromRGB(80, 15, 15)

        local sf2 = Instance.new("ScrollingFrame", listFrame)
        sf2.Size = UDim2.new(1, 0, 1, 0)
        sf2.BackgroundTransparency = 1
        sf2.BorderSizePixel = 0
        sf2.ScrollBarThickness = 2
        sf2.ScrollBarImageColor3 = Color3.fromRGB(120, 20, 20)
        sf2.CanvasSize = UDim2.new(0, 0, 0, 0)
        sf2.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf2.ZIndex = 20
        Instance.new("UIListLayout", sf2).Padding = UDim.new(0, 1)

        for _, v in ipairs(values) do
            local item = Instance.new("TextButton", sf2)
            item.Size = UDim2.new(1, 0, 0, 25)
            item.BackgroundColor3 = tostring(v) == tostring(current)
                and Color3.fromRGB(40, 10, 10)
                or  Color3.fromRGB(14, 6, 6)
            item.Text = "  " .. tostring(v)
            item.TextColor3 = Color3.fromRGB(220, 150, 150)
            item.TextSize = 11
            item.Font = Enum.Font.Gotham
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.BorderSizePixel = 0
            item.ZIndex = 21
            item.MouseButton1Click:Connect(function()
                current = v
                btn.Text = "▾  " .. tostring(v)
                listFrame:Destroy(); listFrame = nil; listOpen = false
                if cb then pcall(cb, v) end
            end)
        end
    end)
end

-- ══════════════════════════════════════════
--    BUILD PANELS
-- ══════════════════════════════════════════

-- ── INFO ──
sideSection("MENU")
local pInfo = sideItem("info", "", "Info")

addInfo(pInfo, "MNA HUB V11.3 — Fish It! | FreeScript")
addInfo(pInfo, " [RightShift] = Toggle GUI buka/tutup")
addInfo(pInfo, " FREE — Tidak butuh key apapun!")

addSection(pInfo, "System Status")
addInfo(pInfo, "Loaded: " .. loadedCount .. " | Failed: " .. failedCount)

addButton(pInfo, "  FIX REMOTE — Reload semua remote", Color3.fromRGB(50, 10, 10), function()
    local l, f = loadRemotes()
    UB_init()
    NotifySuccess("Remotes", "Loaded: "..l.." | Failed: "..f)
end)

-- ── FISHING ──
sideSection("FITUR")
local pFish = sideItem("fishing", "🎣", "Fishing")

addSection(pFish, "Ultra Blatant 3N")

-- Rod template dropdown
addDropdown(pFish, "Template Rod", {
    "1. 3 NOTIF (BETA) (2.998s)",
    "2. 3 Is Real UB(15) (3.7s)",
    "3. Dm/Element (2.890s)",
    "4. GF / Bambu (3.7s)",
    "5. Ares/Angler/Astral (4.8s)"
}, "2. Diamond / Element (3.7s)", function(v)
    local map = {
        ["1. 3 NOTIF (BETA) (2.998s)"]     = 2.998,
        ["2. 3 Is Real UB(15) (3.7s)"]   = 3.7,
        ["3. Dm/Element (2.890s)"]         = 2.890,
        ["4. GF / Bambu (3.7s)"]          = 3.7,
        ["5. Ares/Angler/Astral (4.8s)"]  = 4.8,
    }
    if map[v] then Config.UB.Settings.CompleteDelay = map[v] end
end)

addInput(pFish, "Complete Delay (detik)", tostring(Config.UB.Settings.CompleteDelay), function(t)
    local n = tonumber(t)
    if n and n >= 1 then
        Config.UB.Settings.CompleteDelay = n
        NotifySuccess("Delay", "Set: "..n.."s")
    else
        NotifyError("Delay", "Minimal 1 detik!")
    end
end)

addSlider(pFish, "UB Notif Duration (x Delay)", 10, 50, 20, 1, function(v)
    Config.UBNotifDurationMult = v / 10
    NotifyInfo("UB Notif", "Durasi: "..Config.UBNotifDurationMult.."x delay")
end)

addToggle(pFish, "  Blatant 3N",
    function() return Config.UB.Active and not Config.amblatant end,
    function(v)
        if v then Config.amblatant = false end
    end,
    function(v)
        needCast = true
        onToggleUB(v)
        setStatus(v and "UB 3N AKTIF 🔴" or "Ready", v)
        NotifyInfo("Ultra Blatant", v and "Aktif!" or "Dimatikan.")
    end
)

addToggle(pFish, "  amBlantat (Visual + N Notif/catch)",
    function() return Config.amblatant end,
    function(v) Config.amblatant = v end,
    function(v)
        saveCount = 0
        HookRemote("RE/FishCaught",                  "FishCaught")
        HookRemote("RE/CaughtFishVisual",            "CaughtVisual")
        HookRemote("RE/ObtainedNewFishNotification", "FishNotif")
        needCast = true
        if v then
            onToggleUB(true)
            setStatus("amBlantat AKTIF ✨", true)
        else
            Config.amblatant = false
            setStatus("Ready", false)
            NotifyWarning("amBlantat", "Dimatikan. UB tetap jalan.")
        end
    end
)

addToggle(pFish, "  Random Cast (Anti-Detect)",
    function() return Config.antiOKOK end,
    function(v) Config.antiOKOK = v end,
    function(v) NotifyInfo("Random Cast", v and "Aktif!" or "Dimatikan.") end
)

addSection(pFish, "Notif Config (amBlantat)")

addSlider(pFish, "Jumlah Notif amBlantat", 1, 10, 3, 1, function(v)
    Config.NotifCount = v
    NotifyInfo("amBlantat Notif", "Jumlah: "..v.."x per catch")
end)

addSlider(pFish, "Delay Notif (x0.01s)", 0, 100, 10, 1, function(v)
    Config.NotifDelay = v / 100
    NotifyInfo("amBlantat Delay", "Delay: "..Config.NotifDelay.."s")
end)

addSection(pFish, "Instant Bobber")

addToggle(pFish, "  Instant Bobber",
    function() return Config.InstantBobber end,
    function(v) Config.InstantBobber = v end,
    function(v)
        patchInstantBobber(v)
        NotifyInfo("Instant Bobber", v and "Aktif!" or "Dimatikan.")
    end
)

addSection(pFish, "Custom Skin Animation")

addDropdown(pFish, "Pilih Skin Animasi", {
    "Eclipse","HolyTrident","SoulScythe","OceanicHarpoon","BinaryEdge",
    "Vanquisher","KrampusScythe","BanHammer","CorruptionEdge","PrincessParasol"
}, "Eclipse", function(v)
    Config.SelectedSkinId = v
    SkinAnimation.Switch(v)
end)

addToggle(pFish, "  Enable Skin Animation",
    function() return Config.SkinAnimEnabled end,
    function(v) Config.SkinAnimEnabled = v end,
    function(v)
        if v then
            SkinAnimation.Switch(Config.SelectedSkinId)
            SkinAnimation.Enable()
            NotifySuccess("Skin Anim", Config.SelectedSkinId.." aktif!")
        else
            SkinAnimation.Disable()
            NotifyWarning("Skin Anim", "Dimatikan.")
        end
    end
)

addSection(pFish, "Legit Fishing")

addToggle(pFish, "  Legit Auto Catch",
    function() return Config.AutoCatch end,
    function(v) Config.AutoCatch = v end,
    function(v)
        if v then
            equipRod()
            CallRemote(Events.UpdateAutoFishing, true)
            NotifySuccess("Legit", "Aktif!")
        else
            CallRemote(Events.UpdateAutoFishing, false)
            NotifyWarning("Legit", "Dimatikan.")
        end
    end
)

addInput(pFish, "Catch Delay (detik)", "0.7", function(t)
    local n = tonumber(t)
    if n and n >= 0 then
        Config.CatchDelay = n
        NotifySuccess("Catch Delay", "Set: "..n.."s")
    end
end)

addToggle(pFish, "  Perfection Enchant",
    function() return Config.autoFishing end,
    function(v) Config.autoFishing = v end,
    function(v)
        CallRemote(Events.UpdateAutoFishing, v)
        if v then NotifySuccess("Perfection", "Aktif!")
        else NotifyWarning("Perfection", "Dimatikan.") end
    end
)

addSection(pFish, "Auto Sell")

addDropdown(pFish, "Metode Sell", {"Delay", "Count"}, "Delay", function(v)
    Config.AutoSellMethod = v
    if Config.AutoSellState then RunAutoSellLoop() end
end)

addInput(pFish, "Sell Value (detik atau jumlah catch)", "50", function(t)
    local n = tonumber(t)
    if n and n > 0 then Config.AutoSellValue = n; NotifySuccess("Sell Value", "Set: "..n) end
end)

addToggle(pFish, "  Enable Auto Sell",
    function() return Config.AutoSellState end,
    function(v) Config.AutoSellState = v end,
    function(v)
        if v then
            RunAutoSellLoop()
            NotifySuccess("Auto Sell", "Aktif! Mode: "..Config.AutoSellMethod)
        else
            if Tasks.AutoSellThread then pcall(function() task.cancel(Tasks.AutoSellThread) end) end
            NotifyWarning("Auto Sell", "Dimatikan.")
        end
    end
)

addButton(pFish, "  Sell All Now", Color3.fromRGB(80, 15, 15), function()
    if Events.sell then
        pcall(function() Events.sell:InvokeServer({}) end)
        NotifySuccess("Sell", "Semua ikan dijual!")
    else
        NotifyError("Sell", "Remote tidak ditemukan!")
    end
end)

addSection(pFish, "Auto Favorite")

addDropdown(pFish, "Filter Rarity", {
    "Common","Uncommon","Rare","Epic","Legendary","Mythic","SECRET"
}, "Legendary", function(v)
    -- Multi: simpan sebagai tabel 1 item; user bisa adjust lewat input
    -- (dropdown single karena sistem v6.0 tidak punya multi-select native)
    Config.SelectedRarities = {v}
end)

addToggle(pFish, "  Auto Favorite",
    function() return Config.AutoFavoriteState end,
    function(v) Config.AutoFavoriteState = v end,
    function(v)
        if v then
            Tasks.AutoFavoriteThread = task.spawn(function()
                while Config.AutoFavoriteState do RunAutoFavLoop(false); task.wait(5) end
            end)
            NotifySuccess("Auto Favorite", "Aktif!")
        else
            if Tasks.AutoFavoriteThread then pcall(function() task.cancel(Tasks.AutoFavoriteThread) end) end
            NotifyWarning("Auto Favorite", "Dimatikan.")
        end
    end
)

addToggle(pFish, "☆  Auto Unfavorite",
    function() return Config.AutoUnfavoriteState end,
    function(v) Config.AutoUnfavoriteState = v end,
    function(v)
        if v then
            Tasks.AutoUnfavoriteThread = task.spawn(function()
                while Config.AutoUnfavoriteState do RunAutoFavLoop(true); task.wait(5) end
            end)
            NotifySuccess("Auto Unfavorite", "Aktif!")
        else
            if Tasks.AutoUnfavoriteThread then pcall(function() task.cancel(Tasks.AutoUnfavoriteThread) end) end
            NotifyWarning("Auto Unfavorite", "Dimatikan.")
        end
    end
)

-- ── PLAYERS ──
local pPlayer = sideItem("player", "", "Players")

addSection(pPlayer, "Character")

addSlider(pPlayer, "Walk Speed", 16, 200, 16, 1, function(v)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
end)

addSlider(pPlayer, "Jump Power", 50, 500, 50, 10, function(v)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.UseJumpPower = true; hum.JumpPower = v end
    end
end)

addButton(pPlayer, "  Reset Speed & Jump", Color3.fromRGB(40, 10, 10), function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16; hum.UseJumpPower = true; hum.JumpPower = 50 end
    end
    NotifySuccess("Reset", "Speed & Jump normal!")
end)

addSection(pPlayer, "Abilities")

addToggle(pPlayer, "  Infinite Jump",
    function() return _G.InfiniteJump or false end,
    function(v) _G.InfiniteJump = v end,
    function(v) NotifyInfo("Infinite Jump", v and "Aktif!" or "Dimatikan.") end
)

addToggle(pPlayer, "  Noclip",
    function() return _G.Noclip or false end,
    function(v) _G.Noclip = v end,
    function(v)
        if v then
            task.spawn(function()
                while _G.Noclip do
                    task.wait(0.1)
                    local char = LocalPlayer.Character
                    if char then
                        for _, p in pairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide = false end
                        end
                    end
                end
            end)
        end
        NotifyInfo("Noclip", v and "Aktif!" or "Dimatikan.")
    end
)

addToggle(pPlayer, "  Freeze Character",
    function() return _G.FreezeCharacter or false end,
    function(v) _G.FreezeCharacter = v end,
    function(v)
        if v then
            local hrp = getHRP()
            if hrp then
                local frozenCF = hrp.CFrame
                local conn
                conn = RunService.Heartbeat:Connect(function()
                    if not _G.FreezeCharacter then conn:Disconnect() return end
                    if hrp then hrp.CFrame = frozenCF end
                end)
            end
        end
        NotifyInfo("Freeze", v and "Dibekukan!" or "Bebas.")
    end
)

addSection(pPlayer, "Visual Abilities")

addToggle(pPlayer, "  Walk on Water",
    function() return Config.WalkOnWater end,
    function(v) Config.WalkOnWater = v end,
    function(v) setWalkOnWater(v) end
)

addToggle(pPlayer, "  Hide NameTag",
    function() return Config.HideNameTag end,
    function(v) Config.HideNameTag = v end,
    function(v) setHideNameTag(v) end
)

-- ── MAIN (Enchant dll) ──
local pMain = sideItem("main", "⚙️", "Main")

addSection(pMain, "Enchant Status")

-- Paragraph enchant status (update setiap 2 detik)
local enchStatFrame = Instance.new("Frame", pMain)
enchStatFrame.Size = UDim2.new(1, 0, 0, 50)
enchStatFrame.BackgroundColor3 = Color3.fromRGB(10, 5, 5)
enchStatFrame.BorderSizePixel = 0
Instance.new("UICorner", enchStatFrame).CornerRadius = UDim.new(0, 7)
Instance.new("UIStroke", enchStatFrame).Color = Color3.fromRGB(50, 12, 12)
local enchStatLbl = Instance.new("TextLabel", enchStatFrame)
enchStatLbl.Size = UDim2.new(1, -12, 1, 0)
enchStatLbl.Position = UDim2.new(0, 7, 0, 0)
enchStatLbl.BackgroundTransparency = 1
enchStatLbl.Text = "Rod: - | Enchant: - | Stone: 0"
enchStatLbl.TextColor3 = Color3.fromRGB(180, 110, 110)
enchStatLbl.TextSize = 10
enchStatLbl.Font = Enum.Font.Gotham
enchStatLbl.TextXAlignment = Enum.TextXAlignment.Left
enchStatLbl.TextWrapped = true

task.spawn(function()
    local lastR, lastE, lastS = "", "", -1
    while true do
        task.wait(2)
        pcall(function()
            local s   = getEnchantStoneCount()
            local r   = getEquippedRodName()
            local eid = getCurrentRodEnchant()
            local en  = "None"
            if eid then
                for n, id in pairs(enchantIdMap) do
                    if id == eid then en = n; break end
                end
            end
            if r ~= lastR or en ~= lastE or s ~= lastS then
                enchStatLbl.Text = "Rod: "..r.." | Enchant: "..en.." | Stone: "..s
                lastR, lastE, lastS = r, en, s
            end
        end)
    end
end)

addDropdown(pMain, "Stone Type", {"Enchant Stones","Evolved Enchant Stone"}, "Enchant Stones", function(v)
    _G.SelectedStoneType = v
end)

addDropdown(pMain, "Target Enchant", {
    "Big Hunter 1","Cursed 1","Empowered 1","Glistening 1","Gold Digger 1",
    "Leprechaun 1","Mutation Hunter 1","Prismatic 1","Reeler 1","Stargazer 1",
    "Stormhunter 1","XPerienced 1","SECRET Hunter","Shark Hunter","Fairy Hunter 1"
}, "Big Hunter 1", function(v)
    _G.TargetEnchantBasic = v
end)

addToggle(pMain, "  Auto Enchant",
    function() return _G.AutoEnchant or false end,
    function(v) _G.AutoEnchant = v end,
    function(v)
        if v then
            task.spawn(function()
                while _G.AutoEnchant do
                    pcall(function()
                        if not PlayerData then return end
                        local inv = PlayerData:GetExpect("Inventory")
                        if not inv or not inv.Items then return end
                        local stoneIds = { ["Enchant Stones"]=10, ["Evolved Enchant Stone"]=558 }
                        local targetId = stoneIds[_G.SelectedStoneType or "Enchant Stones"]
                        local stoneUUID = nil
                        for _, item in ipairs(inv.Items) do
                            if item.Id == targetId then stoneUUID = item.UUID; break end
                        end
                        if stoneUUID and Events.equipItem and Events.activateAltar then
                            pcall(function() Events.equipItem:FireServer(stoneUUID, "Enchant Stones") end)
                            task.wait(1.5)
                            pcall(function() Events.activateAltar:FireServer() end)
                        end
                    end)
                    task.wait(2)
                end
            end)
            NotifySuccess("Auto Enchant", "Aktif!")
        else
            NotifyWarning("Auto Enchant", "Dimatikan.")
        end
    end
)

addButton(pMain, "  Teleport ke Altar", Color3.fromRGB(50, 10, 10), function()
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = CFrame.new(3234.837, -1302.855, 1398.391)
        NotifySuccess("Teleport", "Berhasil ke Altar!")
    end
end)

addButton(pMain, "  Double Enchant (Sekali)", Color3.fromRGB(40, 10, 40), function()
    task.spawn(function()
        if not Events.activateAltar then NotifyError("Double Enchant","Remote tidak ditemukan!"); return end
        local stones = findEnchantStones()
        if #stones == 0 then NotifyError("Double Enchant","Stone tidak ada!"); return end
        if Events.equipItem then pcall(function() Events.equipItem:FireServer(stones[1].UUID,"Enchant Stones") end) end
        task.wait(1.2)
        local slot = countHotbarButtons() - 1
        if slot < 1 then slot = 1 end
        if Events.equip then pcall(function() CallRemote(Events.equip, slot) end) end
        task.wait(0.8)
        pcall(function() Events.activateAltar:FireServer() end)
        NotifySuccess("Double Enchant", "Selesai!")
    end)
end)

addButton(pMain, "  Fix Rod", Color3.fromRGB(30, 8, 8), function()
    if Events.CancelFishing then
        pcall(function() CallRemote(Events.CancelFishing) end)
        NotifySuccess("Fix Rod", "Rod di-reset!")
    elseif Config.UB.Remotes.CancelFishingInputs then
        pcall(function() CallRemote(Config.UB.Remotes.CancelFishingInputs) end)
        NotifySuccess("Fix Rod", "Rod di-reset!")
    else
        NotifyError("Fix Rod", "Remote tidak ditemukan!")
    end
end)

addSection(pMain, "Cave & Pirate")

addButton(pMain, "  Open Cave Wall (TNT 4x)", Color3.fromRGB(50, 25, 5), function()
    task.spawn(function()
        if not Events.searchItemPickedUp or not Events.gainAccessToMaze then
            NotifyError("Cave","Remote tidak ditemukan!"); return
        end
        NotifyInfo("Cave","Menanam TNT...")
        for i = 1, 4 do
            pcall(function() Events.searchItemPickedUp:FireServer("TNT") end)
            task.wait(0.7)
        end
        task.wait(1.5)
        pcall(function() Events.gainAccessToMaze:FireServer() end)
        NotifySuccess("Cave","Wall dibuka!")
    end)
end)

addToggle(pMain, "  Auto Open Pirate Chest",
    function() return _G.AutoPirateChest or false end,
    function(v) _G.AutoPirateChest = v end,
    function(v)
        if v then
            task.spawn(function()
                while _G.AutoPirateChest do
                    pcall(function()
                        if not Events.claimPirateChest then return end
                        local storage = workspace:FindFirstChild("PirateChestStorage")
                        if not storage then return end
                        local found = 0
                        for _, chest in ipairs(storage:GetChildren()) do
                            if chest.Name:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") then
                                pcall(function() Events.claimPirateChest:FireServer(chest.Name) end)
                                found = found + 1; task.wait(0.5)
                            end
                        end
                        if found > 0 then NotifySuccess("Pirate","Claim "..found.." chest!") end
                    end)
                    task.wait(3)
                end
            end)
            NotifySuccess("Pirate","Auto claim aktif!")
        else NotifyWarning("Pirate","Dimatikan.") end
    end
)

addSection(pMain, "Cave Crystal")

addButton(pMain, "  Consume Crystal Now", Color3.fromRGB(10, 30, 50), function()
    if Events.ConsumeCaveCrystal then
        pcall(function() Events.ConsumeCaveCrystal:InvokeServer() end)
        task.wait(1.5); equipRod()
        NotifySuccess("Crystal","Dikonsumsi!")
    else NotifyError("Crystal","Remote tidak ditemukan!") end
end)

addToggle(pMain, " Auto Consume Crystal (30 mnt)",
    function() return _G.AutoCrystal or false end,
    function(v) _G.AutoCrystal = v end,
    function(v)
        if v then
            if not Events.ConsumeCaveCrystal then NotifyError("Crystal","Remote tidak ditemukan!"); return end
            _G.crystalTask = task.spawn(function()
                while _G.AutoCrystal do
                    pcall(function() Events.ConsumeCaveCrystal:InvokeServer(); task.wait(1.5); equipRod() end)
                    task.wait(1800)
                end
            end)
            NotifySuccess("Crystal","Auto setiap 30 menit!")
        else
            if _G.crystalTask then pcall(function() task.cancel(_G.crystalTask) end); _G.crystalTask = nil end
            NotifyWarning("Crystal","Dimatikan.")
        end
    end
)

addSection(pMain, "Totem")

addDropdown(pMain, "Pilih Totem", {
    "Pilih Totem","Luck Totem","Mutation Totem","Shiny Totem","Love Totem"
}, "Pilih Totem", function(v)
    local totemMap = { ["Pilih Totem"]=0,["Luck Totem"]=1,["Mutation Totem"]=2,["Shiny Totem"]=3,["Love Totem"]=5 }
    Config.SelectedTotemID = totemMap[v] or 0
    NotifyInfo("Totem","Dipilih: "..v)
end)

addToggle(pMain, "  Auto Spawn Totem (1 jam)",
    function() return Config.AutoTotem end,
    function(v) Config.AutoTotem = v end,
    function(v)
        if v then
            Tasks.totemTask = task.spawn(function()
                while Config.AutoTotem do
                    pcall(function()
                        local hrp = getHRP(); if not hrp then return end
                        local totemUUID = nil
                        pcall(function()
                            local replion = GetPlayerDataReplion(); if not replion then return end
                            local inv = replion:GetExpect("Inventory")
                            if inv and inv.Totems then
                                for _, item in ipairs(inv.Totems) do
                                    if Config.SelectedTotemID == 0 or item.Id == Config.SelectedTotemID then
                                        totemUUID = item.UUID; break
                                    end
                                end
                            end
                        end)
                        if totemUUID and Events.SpawnTotem then
                            pcall(function() Events.SpawnTotem:FireServer(totemUUID) end)
                            task.wait(3); equipRod()
                            NotifySuccess("Totem","Spawn! Cooldown 1 jam.")
                        end
                    end)
                    task.wait(3600)
                end
            end)
            NotifySuccess("Auto Totem","Aktif!")
        else
            if Tasks.totemTask then pcall(function() task.cancel(Tasks.totemTask) end); Tasks.totemTask = nil end
            NotifyWarning("Auto Totem","Dimatikan.")
        end
    end
)

-- ── TELEPORT ──
local pTp = sideItem("teleport", "", "Teleport")

addSection(pTp, "Map Locations")

local locList = {}
for n in pairs(LOCATIONS) do table.insert(locList, n) end
table.sort(locList)

local selectedLoc = locList[1]
addDropdown(pTp, "Pilih Lokasi", locList, locList[1], function(v)
    selectedLoc = v
end)

addButton(pTp, "  Teleport ke Lokasi!", Color3.fromRGB(50, 10, 10), function()
    teleportTo(selectedLoc)
    NotifySuccess("Teleport","Berhasil ke "..selectedLoc)
end)

addSection(pTp, "Player Teleport")

local playerList = {}
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then table.insert(playerList, p.Name) end
end
table.sort(playerList)
if #playerList == 0 then playerList = {"-- Tidak ada --"} end

local selectedPlayer = playerList[1]
addDropdown(pTp, "Pilih Player", playerList, playerList[1], function(v)
    selectedPlayer = v
end)

addButton(pTp, "  Teleport ke Player", Color3.fromRGB(40, 10, 10), function()
    if not selectedPlayer or selectedPlayer == "-- Tidak ada --" then
        NotifyError("Error","Pilih player dulu!"); return
    end
    local target = Players:FindFirstChild(selectedPlayer)
    if target and target.Character then
        local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
        local hrp  = getHRP()
        if hrp and tHRP then
            hrp.CFrame = CFrame.new(tHRP.Position + Vector3.new(0,3,0))
            NotifySuccess("Teleport","Berhasil ke "..selectedPlayer)
        end
    else
        NotifyError("Error","Character tidak ditemukan!")
    end
end)

addSection(pTp, "Event Teleport")

addToggle(pTp, "  Auto Leviathan Hunt TP",
    function() return _G.AutoLev or false end,
    function(v) _G.AutoLev = v end,
    function(v)
        if v then
            local hasTP = false
            Tasks.levTask = task.spawn(function()
                while _G.AutoLev do
                    pcall(function()
                        local zones = workspace:FindFirstChild("Zones")
                        if zones then
                            local den = zones:FindFirstChild("Leviathan's Den")
                            if den and not hasTP then
                                local hrp = getHRP()
                                if hrp then
                                    hrp.CFrame = CFrame.new(3474.053,-287.775,3472.634)
                                    hasTP = true; NotifySuccess("Leviathan","TP ke Den!")
                                end
                            elseif not den then hasTP = false end
                        end
                    end)
                    task.wait(5)
                end
            end)
            NotifySuccess("Leviathan","Mencari zona...")
        else
            if Tasks.levTask then pcall(function() task.cancel(Tasks.levTask) end) end
            NotifyWarning("Leviathan","Dimatikan.")
        end
    end
)

addSection(pTp, "Auto Event TP (Platform)")

addInfo(pTp, "Pilih event → aktifkan. Script scan map & TP ke platform melayang.")

local eventTPNames = {}
for n in pairs(eventTPData) do table.insert(eventTPNames, n) end
table.sort(eventTPNames)

local selectedAutoEvent = eventTPNames[1]
addDropdown(pTp, "Pilih Event", eventTPNames, eventTPNames[1], function(v)
    selectedAutoEvents = {v}
end)

addToggle(pTp, "  Auto Event Teleport",
    function() return autoEventTPEnabled end,
    function(v) autoEventTPEnabled = v end,
    function(v)
        if v then
            if #selectedAutoEvents == 0 then
                NotifyError("Auto Event TP","Pilih event dulu!")
                autoEventTPEnabled = false; return
            end
            if autoEventThread then pcall(function() task.cancel(autoEventThread) end) end
            autoEventThread = task.spawn(runAutoEventTP)
            NotifySuccess("Auto Event TP","Aktif!")
        else
            destroyEventPlatform()
            if autoEventThread then pcall(function() task.cancel(autoEventThread) end); autoEventThread = nil end
            NotifyWarning("Auto Event TP","Dimatikan.")
        end
    end
)

-- ── EASTER ──
local pEaster = sideItem("easter", "", "Easter")

addSection(pEaster, "Easter Teleport")

addButton(pEaster, "  TP ke Easter Island", Color3.fromRGB(40, 25, 5), function()
    teleportTo("Easter Island")
    NotifySuccess("Teleport","Berhasil ke Easter Island!")
end)

addButton(pEaster, "  TP ke Easter Cove", Color3.fromRGB(5, 25, 40), function()
    teleportTo("Easter Cove")
    NotifySuccess("Teleport","Berhasil ke Easter Cove!")
end)

addSection(pEaster, "Auto Egg Hunt")

addToggle(pEaster, "  Auto Egg Hunt",
    function() return Config.AutoEggHunt end,
    function(v) Config.AutoEggHunt = v end,
    function(v)
        if v then startAutoEggHunt(); NotifySuccess("Auto Egg Hunt","Aktif! Mencari telur...")
        else
            if Tasks.EggHuntTask then pcall(function() task.cancel(Tasks.EggHuntTask) end) end
            NotifyWarning("Auto Egg Hunt","Dimatikan.")
        end
    end
)

addSection(pEaster, "Auto Buy Egg")

local eggNameList = {}
for n in pairs(EggShopList) do table.insert(eggNameList, n) end
table.sort(eggNameList)

addDropdown(pEaster, "Pilih Egg", eggNameList, eggNameList[1], function(v)
    local data = EggShopList[v]
    if data then Config.SelectedEggId = data.id; NotifyInfo("Egg","Dipilih: "..v) end
end)

addToggle(pEaster, "  Auto Buy Egg",
    function() return Config.AutoBuyEgg end,
    function(v) Config.AutoBuyEgg = v end,
    function(v)
        if v then
            if Config.SelectedEggId == "" then NotifyError("Auto Buy Egg","Pilih egg dulu!"); Config.AutoBuyEgg = false; return end
            startAutoBuyEgg(); NotifySuccess("Auto Buy Egg","Aktif!")
        else
            if Tasks.BuyEggTask then pcall(function() task.cancel(Tasks.BuyEggTask) end) end
            NotifyWarning("Auto Buy Egg","Dimatikan.")
        end
    end
)

addButton(pEaster, "  Buy Egg Once", Color3.fromRGB(40, 20, 5), function()
    if Config.SelectedEggId == "" then NotifyError("Buy Egg","Pilih egg dulu!"); return end
    if Events.BuyEgg then
        pcall(function() Events.BuyEgg:InvokeServer(Config.SelectedEggId) end)
        NotifySuccess("Buy Egg","Egg dibeli!")
    else NotifyError("Buy Egg","Remote tidak ditemukan!") end
end)

addSection(pEaster, "Auto Event (Easter)")

addToggle(pEaster, "  Auto Event",
    function() return Config.AutoEvent end,
    function(v) Config.AutoEvent = v end,
    function(v)
        if v then startAutoEvent(); NotifySuccess("Auto Event","Aktif!")
        else
            if Tasks.AutoEventTask then pcall(function() task.cancel(Tasks.AutoEventTask) end) end
            NotifyWarning("Auto Event","Dimatikan.")
        end
    end
)

-- ── SHOP ──
local pShop = sideItem("shop", "", "Shop")

addSection(pShop, "Weather Event")

local wxNames2 = {}
for n in pairs(weatherMap) do table.insert(wxNames2, n) end
table.sort(wxNames2)

local selectedWeather = wxNames2[1]
addDropdown(pShop, "Pilih Weather", wxNames2, wxNames2[1], function(v)
    selectedWeather = v
end)

addButton(pShop, "  Buy Selected Weather", Color3.fromRGB(10, 20, 50), function()
    if not selectedWeather then NotifyError("Error","Pilih weather dulu!"); return end
    if not Events.BuyWeather then NotifyError("Error","Remote tidak ditemukan!"); return end
    local key = weatherMap[selectedWeather]
    if key then
        pcall(function() Events.BuyWeather:InvokeServer(key) end)
        NotifySuccess("Weather","Purchased: "..selectedWeather)
    end
end)

addToggle(pShop, "  Auto Buy Weather",
    function() return _G.AutoWeather or false end,
    function(v) _G.AutoWeather = v end,
    function(v)
        if v then
            task.spawn(function()
                while _G.AutoWeather do
                    if Events.BuyWeather and selectedWeather then
                        local key = weatherMap[selectedWeather]
                        if key then pcall(function() Events.BuyWeather:InvokeServer(key) end) end
                    end
                    task.wait(5)
                end
            end)
            NotifySuccess("Weather","Aktif!")
        else NotifyWarning("Weather","Dimatikan.") end
    end
)

-- ── COSMETIC ──
local pCosmetic = sideItem("cosmetic", "", "Cosmetic")

addSection(pCosmetic, "Aura Animasi")

addInfo(pCosmetic, "Efek partikel aura di sekitar karakter. Berjalan di client-side.")

local auraNameList = {}
for n in pairs(AuraList) do table.insert(auraNameList, n) end
table.sort(auraNameList)

local selectedAuraName = "None"
addDropdown(pCosmetic, "Pilih Aura", auraNameList, "None", function(v)
    selectedAuraName = v
end)

addButton(pCosmetic, "  Apply Aura", Color3.fromRGB(50, 25, 5), function()
    applyAura(selectedAuraName)
end)

addButton(pCosmetic, "✕  Remove Aura", Color3.fromRGB(40, 8, 8), function()
    applyAura("None")
end)

-- ── MISC ──
local pMisc = sideItem("misc", "🔧", "Misc")

addSection(pMisc, "Visual & Performance")

addToggle(pMisc, "  No Animation",
    function() return false end,
    function(v) end,
    function(v)
        local char = LocalPlayer.Character
        if char then
            local hum  = char:FindFirstChildOfClass("Humanoid")
            local anim = hum and hum:FindFirstChildOfClass("Animator")
            if anim then
                if v then
                    for _, t in ipairs(anim:GetPlayingAnimationTracks()) do t:Stop(0) end
                    anim.AnimationPlayed:Connect(function(t) t:Stop(0) end)
                end
            end
        end
        NotifyInfo("Anim", v and "Dimatikan." or "Normal.")
    end
)

addToggle(pMisc, "  FPS Booster",
    function() return false end,
    function(v) end,
    function(v)
        if v then
            for _, obj in pairs(workspace:GetDescendants()) do
                pcall(function()
                    if obj:IsA("BasePart") then obj.Reflectance = 0; obj.CastShadow = false
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then obj.Enabled = false end
                end)
            end
            local L = game:GetService("Lighting")
            L.GlobalShadows = false; L.FogEnd = 1e10
            for _, e in pairs(L:GetChildren()) do if e:IsA("PostEffect") then e.Enabled = false end end
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            NotifySuccess("FPS","Aktif!")
        else
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
            NotifyInfo("FPS","Normal.")
        end
    end
)

addToggle(pMisc, "  Disable Obtained Notification",
    function() return Config.DisableObtained end,
    function(v) Config.DisableObtained = v end,
    function(v) setDisableObtained(v) end
)

addToggle(pMisc, "  Disable VFX",
    function() return false end,
    function(v) end,
    function(v)
        if Controllers.VFX then
            local _b = setmetatable({},  {__mode="k"})
            if v then
                if not _b[Controllers.VFX] then
                    local d = {functions={}}
                    for k, fn in pairs(Controllers.VFX) do
                        if type(fn) == "function" then d.functions[k]=fn; Controllers.VFX[k]=function()end end
                    end
                    _b[Controllers.VFX]=d
                end
            else
                local d = _b[Controllers.VFX]
                if d then for k, fn in pairs(d.functions) do Controllers.VFX[k]=fn end; _b[Controllers.VFX]=nil end
            end
        end
    end
)

addSection(pMisc, "Ping Panel")

addToggle(pMisc, "  Ping Panel (pojok kanan atas)",
    function() return pingGui ~= nil end,
    function(v) end,
    function(v)
        if v then createPingPanel(); NotifySuccess("Ping Panel","Aktif!")
        else destroyPingPanel(); NotifyWarning("Ping Panel","Disembunyikan.") end
    end
)

addToggle(pMisc, "  Realtime Stats Panel",
    function() return realtimePanelGui ~= nil end,
    function(v) end,
    function(v)
        if v then createRealtimePanel(); NotifySuccess("Realtime Panel","Aktif! Drag header untuk pindah.")
        else destroyRealtimePanel(); NotifyWarning("Realtime Panel","Dimatikan.") end
    end
)

addButton(pMisc, "  Show FPS & Ping (sekali)", Color3.fromRGB(20, 10, 10), function()
    local frames, conn = 0, nil
    conn = RunService.RenderStepped:Connect(function() frames = frames + 1 end)
    task.wait(1); local fps = frames; conn:Disconnect()
    local ping = 0
    pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
    NotifyInfo("Stats","FPS: "..fps.." | Ping: "..ping.."ms")
end)

addSection(pMisc, "Webhook")

addToggle(pMisc, "  Enable Custom Webhook",
    function() return Config.CustomWebhook end,
    function(v) Config.CustomWebhook = v end,
    function(v) NotifyInfo("Webhook", v and "Aktif." or "Nonaktif.") end
)

addInput(pMisc, "Webhook URL", "https://discord.com/api/webhooks/...", function(t)
    if not t or t == "" then NotifyError("Webhook","URL kosong!"); return end
    Config.CustomWebhookUrl = t
    NotifySuccess("Webhook","URL disimpan!")
end)

-- ══════════════════════════════════════════
--    KEYBIND [RightShift] TOGGLE GUI
-- ══════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        SG.Enabled = not SG.Enabled
        if SG.Enabled then
            Win.Size = UDim2.new(0, 0, 0, 0)
            Win.Position = UDim2.new(0.5, 0, 0.5, 0)
            TweenService:Create(Win, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size     = UDim2.new(0, 420, 0, 560),
                Position = UDim2.new(0.5, -210, 0.5, -280)
            }):Play()
        end
    end
end)

-- Default tab = Info
if allSBtns["info"] then
    allSBtns["info"].btn.MouseButton1Click:Fire()
end

-- Startup animation
Win.Size = UDim2.new(0, 0, 0, 0)
Win.Position = UDim2.new(0.5, 0, 0.5, 0)
TweenService:Create(Win, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size     = UDim2.new(0, 420, 0, 560),
    Position = UDim2.new(0.5, -210, 0.5, -280)
}):Play()

NotifySuccess("MNA HUB V11.3","Loaded! Remotes: "..loadedCount.." ✅")
print("╔══════════════════════════════════════════╗")
print("║     MNA HUB V11.3 — FREE NOT SELL       ║")
print("║  amBlantat + UB 3N | All Fitur Ready    ║")
print("║  [RightShift] Toggle  |  Crimson UI     ║")
print("╚══════════════════════════════════════════╝")
