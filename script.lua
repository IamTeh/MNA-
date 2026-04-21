--[[
    MNA HUB V11.3 FREE NOT SELL
    UI : WindUI (Crimson Theme)

    CARA KERJA:
    [Ultra Blatant 3N]
      - Setiap cast berhasil → 1 notif masuk antrian (_G.NotifQueue)
      - Processor: kalau notif aktif di layar < 2, tampilkan dari antrian
      - Durasi notif diperpanjang > interval cast → selalu 2 notif di layar

    [amBlantat]
      - Setiap catch REAL dari server → simpan snapshot data ikan
      - Replay: FishCaught 1x + CaughtVisual 1x + Notif Nx
      - TIDAK menggunakan NotifQueue → sistem terpisah, tidak saling ganggu

    CHANGELOG FIX:
      - Walk on Water: fix CFrame math yang salah, optimasi heartbeat
      - Teleport: fix offset CFrame untuk semua lokasi
      - Disable Obtained: fix via getconnections() intercept proper
      - amBlantat: fix race condition isCaught
      - UB 3N: fix NotifActive drift saat stop
      - Aura: fix CharacterAdded memory leak
      - Hapus: Emote (tidak jalan), SkinAnimList/applySkinAnim (tidak jalan)
      - Fix: skinNames variable collision di Cosmetic tab
      - Tetap: Custom Skin Animation dari NiCH HUB (SkinAnimation object)
]]

repeat task.wait(0.5) until game:IsLoaded()
task.wait(2)

-- =============================
--    WINDUI LOAD
-- =============================
local WindUI
local ok_ui = pcall(function()
    WindUI = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
    ))()
end)
if not ok_ui or not WindUI then
    warn("[MNA HUB] WindUI gagal dimuat!")
    return
end

-- =============================
--    SERVICES
-- =============================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")
local LocalPlayer       = Players.LocalPlayer
local isMobile          = UserInputService.TouchEnabled

-- =============================
--    NOTIFY HELPER
-- =============================
local function NotifySuccess(title, msg, dur)
    WindUI:Notify({ Title = "✅ "..title, Content = msg, Duration = dur or 3, Icon = "check-circle" })
end
local function NotifyError(title, msg, dur)
    WindUI:Notify({ Title = "❌ "..title, Content = msg, Duration = dur or 3, Icon = "x-circle" })
end
local function NotifyInfo(title, msg, dur)
    WindUI:Notify({ Title = "ℹ️ "..title, Content = msg, Duration = dur or 3, Icon = "info" })
end
local function NotifyWarning(title, msg, dur)
    WindUI:Notify({ Title = "⚠️ "..title, Content = msg, Duration = dur or 3, Icon = "alert-triangle" })
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
--    DISABLE OBTAINED NOTIFICATION
--    FIX: gunakan getconnections() untuk intercept proper
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
--    INSTANT BOBBER SYSTEM (dari NiCH HUB)
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
--    CUSTOM SKIN ANIMATION (dari NiCH HUB)
--    Ini yang dari teman — tetap ada
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
--    AUTO EVENT TELEPORT (dari NiCH HUB — 5 event platform melayang)
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
--    REALTIME STATS PANEL (dari NiCH HUB — draggable)
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

-- =============================
--    WINDUI WINDOW
-- =============================
local Window = WindUI:CreateWindow({
    Title        = "MNA HUB",
    Icon         = "rbxassetid://111326404819563",
    Author       = "https://discord.gg/xjqJEnsY2",
    Folder       = "MNA HUB",
    Size         = UDim2.fromOffset(580, 460),
    Transparent  = true,
    Theme        = "Crimson",
    SideBarWidth = 180,
})

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Parent = game:GetService("CoreGui")
ToggleGui.ResetOnSpawn = false
ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ToggleBtn = Instance.new("ImageButton", ToggleGui)
ToggleBtn.Size             = UDim2.new(0, 48, 0, 48)
ToggleBtn.Position         = UDim2.new(0.05, 0, 0.04, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 10, 180)
ToggleBtn.Image            = "rbxassetid://111326404819563"
ToggleBtn.Draggable        = true
ToggleBtn.BorderSizePixel  = 0
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
local btnStroke = Instance.new("UIStroke", ToggleBtn)
btnStroke.Thickness = 2; btnStroke.Color = Color3.fromRGB(200, 0, 50)

local windowVisible = true
ToggleBtn.MouseButton1Click:Connect(function()
    if windowVisible then Window:Close() else Window:Open() end
    windowVisible = not windowVisible
end)

Window:Tag({ Title = "V11.4", Color = Color3.fromRGB(200, 0, 50), Radius = 17 })
Window:Tag({ Title = "FREE",  Color = Color3.fromRGB(200, 0, 50), Radius = 17 })

WindUI:Notify({
    Title    = "MNA HUB",
    Content  = "Loaded! Remotes: " .. loadedCount,
    Duration = 4,
    Icon     = "rbxassetid://111326404819563",
})

-- =============================
--    TAB: INFO
-- =============================
local InfoTab = Window:Tab({ Title = "Info", Icon = "info" })
InfoTab:Section({ Title = "System Status", Icon = "activity" })
InfoTab:Paragraph({
    Title   = "Remote Status",
    Content = "Loaded: " .. loadedCount .. " | Failed: " .. failedCount
})
InfoTab:Button({
    Title    = "FIX REMOTE",
    Desc     = "Reload semua remote",
    Callback = function()
        local l, f = loadRemotes()
        UB_init()
        NotifySuccess("Remotes", "Loaded: "..l.." | Failed: "..f)
    end
})
InfoTab:Keybind({
    Title    = "Toggle UI",
    Desc     = "buka/tutup UI",
    Value    = "RightShift",
    Callback = function(v)
        pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end)
    end
})

-- =============================
--    TAB: PLAYERS
-- =============================
local PlayersTab = Window:Tab({ Title = "Playing", Icon = "user" })
PlayersTab:Section({ Title = "Character", Icon = "move" })

PlayersTab:Slider({
    Title = "Walk Speed",
    Value = { Min = 16, Max = 200, Default = 16 },
    Step  = 1,
    Callback = function(val)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = val end
        end
    end
})

PlayersTab:Slider({
    Title = "Jump Power",
    Value = { Min = 50, Max = 500, Default = 50 },
    Step  = 10,
    Callback = function(val)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.UseJumpPower = true; hum.JumpPower = val end
        end
    end
})

PlayersTab:Button({
    Title    = "Reset Speed & Jump",
    Callback = function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16; hum.UseJumpPower = true; hum.JumpPower = 50 end
        end
        NotifySuccess("Reset", "Speed & Jump normal!")
    end
})

PlayersTab:Section({ Title = "Abilities", Icon = "zap" })

PlayersTab:Toggle({
    Title    = "Infinite Jump",
    Value    = false,
    Callback = function(v) _G.InfiniteJump = v end
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

PlayersTab:Toggle({
    Title    = "Noclip",
    Value    = false,
    Callback = function(v)
        _G.Noclip = v
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
    end
})

local freezeConn, frozenCF
PlayersTab:Toggle({
    Title    = "Freeze Character",
    Value    = false,
    Callback = function(v)
        _G.FreezeCharacter = v
        if v then
            local hrp = getHRP()
            if hrp then
                frozenCF = hrp.CFrame
                freezeConn = RunService.Heartbeat:Connect(function()
                    if _G.FreezeCharacter and hrp then hrp.CFrame = frozenCF end
                end)
            end
        else
            if freezeConn then freezeConn:Disconnect(); freezeConn = nil end
        end
    end
})

PlayersTab:Section({ Title = "Visual", Icon = "eye" })

PlayersTab:Toggle({
    Title    = "Walk on Water",
    Desc     = "Berjalan di atas air",
    Value    = false,
    Callback = function(v) setWalkOnWater(v) end
})

PlayersTab:Toggle({
    Title    = "Hide NameTag",
    Desc     = "Sembunyikan nama",
    Value    = false,
    Callback = function(v) setHideNameTag(v) end
})

-- =============================
--    TAB: FISHING
-- =============================
local FishTab = Window:Tab({ Title = "FastFishing", Icon = "anchor" })
FishTab:Section({ Title = "Auto Fishing", Icon = "zap" })

local rodSettings = {
    ["1. 2 NOTIF"]      = { CompleteDelay = 2.998 },
    ["2. 3 IS REAL (BETA)"]  = { CompleteDelay = 3.7   },
    ["3. DIAMOND/ELEMENT"]          = { CompleteDelay = 2.890 },
    ["4. GF / Bambu"]         = { CompleteDelay = 3.7   },
    ["5. amblantant 20n"] = { CompleteDelay = 4.8   },
}
local rodNames = {}
for n in pairs(rodSettings) do table.insert(rodNames, n) end
table.sort(rodNames)

FishTab:Dropdown({
    Title  = "Template Rod",
    Values = rodNames,
    Value  = "2. DIAMOND/ELEMENT",
    Callback = function(v)
        local s = rodSettings[v]
        if s then Config.UB.Settings.CompleteDelay = s.CompleteDelay end
    end
})

FishTab:Input({
    Title       = "Complete Delay",
    Placeholder = tostring(Config.UB.Settings.CompleteDelay),
    Callback    = function(t)
        local n = tonumber(t)
        if n and n >= 1 then
            Config.UB.Settings.CompleteDelay = n
            NotifySuccess("Delay", "Set: "..n.."s")
        else
            NotifyError("Delay", "Minimal 1 detik!")
        end
    end
})

FishTab:Slider({
    Title = "UB Blantant",
    Desc  = "Set Sesuai Delay UB",
    Value = { Min = 10, Max = 50, Default = 20 },
    Step  = 1,
    Callback = function(v)
        Config.UBNotifDurationMult = v / 10
        NotifyInfo("UB Notif", "Durasi: "..Config.UBNotifDurationMult.."x delay")
    end
})

FishTab:Toggle({
    Title = "Blantant (YTTA)",
    Value = false,
    Callback = function(v)
        needCast = true
        onToggleUB(v)
    end
})

FishTab:Toggle({
    Title = "amBlantat 20N",
    Desc  = "VisuaL/Have Fun",
    Value = false,
    Callback = function(v)
        Config.amblatant = v
        saveCount = 0
        HookRemote("RE/FishCaught",                  "FishCaught")
        HookRemote("RE/CaughtFishVisual",            "CaughtVisual")
        HookRemote("RE/ObtainedNewFishNotification", "FishNotif")
        needCast = true
        if v then
            onToggleUB(true)
        else
            Config.amblatant = false
            NotifyWarning("amBlantat", "Dimatikan. UB tetap jalan.")
        end
    end
})

FishTab:Toggle({
    Title    = "Random Cast",
    Value    = false,
    Callback = function(v) Config.antiOKOK = v end
})

FishTab:Divider()
FishTab:Section({ Title = "Fishing", Icon = "zap" })

FishTab:Toggle({
    Title    = "Instant Bobber",
    Desc     = "Bobber Di Posisi cast",
    Value    = false,
    Callback = function(v)
        Config.InstantBobber = v
        patchInstantBobber(v)
        if v then NotifySuccess("Instant Bobber", "Aktif!")
        else NotifyWarning("Instant Bobber", "Dimatikan.") end
    end
})

FishTab:Divider()
FishTab:Section({ Title = "Skin Animation", Icon = "sparkles" })

FishTab:Paragraph({
    Title   = "Info",
    Content = "Pilih skin lalu aktifkan."
})

-- FIX: rename agar tidak collision dengan scope lain
local ubSkinNames = {
    "Eclipse","HolyTrident","SoulScythe","OceanicHarpoon","BinaryEdge",
    "Vanquisher","KrampusScythe","BanHammer","CorruptionEdge","PrincessParasol"
}

FishTab:Dropdown({
    Title  = "Pilih Skin Animasi",
    Values = ubSkinNames,
    Value  = "Eclipse",
    Callback = function(v)
        Config.SelectedSkinId = v
        SkinAnimation.Switch(v)
    end
})

FishTab:Toggle({
    Title    = "Enable Skin Animation",
    Desc     = "Aktifin Animasi",
    Value    = false,
    Callback = function(v)
        Config.SkinAnimEnabled = v
        if v then
            SkinAnimation.Switch(Config.SelectedSkinId)
            SkinAnimation.Enable()
            NotifySuccess("Skin Anim", Config.SelectedSkinId.." aktif!")
        else
            SkinAnimation.Disable()
            NotifyWarning("Skin Anim", "Dimatikan.")
        end
    end
})

FishTab:Divider()
FishTab:Section({ Title = "UB amblantant", Icon = "bell" })

FishTab:Slider({
    Title = "Notif amBlantat",
    Desc  = "Default 3",
    Value = { Min = 1, Max = 10, Default = 3 },
    Step  = 1,
    Callback = function(v)
        Config.NotifCount = v
        NotifyInfo("amBlantat Notif", "Jumlah: "..v.."x per catch")
    end
})

FishTab:Slider({
    Title = "Delay UB (Notif)",
    Desc  = "Default: (10)",
    Value = { Min = 0, Max = 100, Default = 10 },
    Step  = 1,
    Callback = function(v)
        Config.NotifDelay = v / 100
        NotifyInfo("amBlantat Delay", "Delay: "..Config.NotifDelay.."s")
    end
})

FishTab:Divider()
FishTab:Section({ Title = "Legit", Icon = "shield-check" })

FishTab:Toggle({
    Title    = "Legit Fishing",
    Value    = false,
    Callback = function(v)
        Config.AutoCatch = v
        if v then
            equipRod()
            CallRemote(Events.UpdateAutoFishing, true)
            NotifySuccess("Legit", "Aktif!")
        else
            CallRemote(Events.UpdateAutoFishing, false)
            NotifyWarning("Legit", "Dimatikan.")
        end
    end
})

FishTab:Input({
    Title       = "Catch Delay",
    Placeholder = "0.7",
    Callback    = function(t)
        local n = tonumber(t)
        if n and n >= 0 then
            Config.CatchDelay = n
            NotifySuccess("Catch Delay", "Set: "..n.."s")
        end
    end
})

FishTab:Toggle({
    Title    = "Perfection Enchant",
    Value    = false,
    Callback = function(v)
        Config.autoFishing = v
        CallRemote(Events.UpdateAutoFishing, v)
        if v then NotifySuccess("Perfection", "Aktif!")
        else NotifyWarning("Perfection", "Dimatikan.") end
    end
})

FishTab:Divider()
FishTab:Section({ Title = "Auto Sell", Icon = "shopping-cart" })

FishTab:Dropdown({
    Title  = "Metode Sell",
    Values = { "Delay", "Count" },
    Value  = "Delay",
    Callback = function(v)
        Config.AutoSellMethod = v
        if Config.AutoSellState then RunAutoSellLoop() end
    end
})

FishTab:Input({
    Title       = "Sell Value",
    Desc        = "Delay = detik/Count Cacht",
    Placeholder = "50",
    Callback    = function(t)
        local n = tonumber(t)
        if n and n > 0 then Config.AutoSellValue = n; NotifySuccess("Sell Value", "Set: "..n) end
    end
})

FishTab:Toggle({
    Title    = "Enable Auto Sell",
    Value    = false,
    Callback = function(v)
        Config.AutoSellState = v
        if v then
            RunAutoSellLoop()
            NotifySuccess("Auto Sell", "Aktif! Mode: "..Config.AutoSellMethod)
        else
            if Tasks.AutoSellThread then pcall(function() task.cancel(Tasks.AutoSellThread) end) end
            NotifyWarning("Auto Sell", "Dimatikan.")
        end
    end
})

FishTab:Button({
    Title    = "Sell All Now",
    Callback = function()
        if Events.sell then
            pcall(function() Events.sell:InvokeServer({}) end)
            NotifySuccess("Sell", "Semua ikan dijual!")
        else
            NotifyError("Sell", "Remote tidak ditemukan!")
        end
    end
})

FishTab:Divider()
FishTab:Section({ Title = "Favorite", Icon = "star" })

FishTab:Dropdown({
    Title  = "Filter Rarity",
    Values = { "Common","Uncommon","Rare","Epic","Legendary","Mythic","SECRET" },
    Multi  = true,
    Callback = function(v)
        Config.SelectedRarities = type(v) == "table" and v or (v ~= "" and {v} or {})
    end
})

FishTab:Dropdown({
    Title  = "Filter Mutation",
    Values = {
        "Galaxy","Corrupt","Gemstone","Fairy Dust","Midnight","Color Burn",
        "Holographic","Lightning","Radioactive","Ghost","Gold","Frozen",
        "1x1x1x1","Stone","Sandy","Noob","Moon Fragment","Festive",
        "Albino","Arctic Frost","Disco","Big","Giant","Sparkling","Crystalized","Shiny"
    },
    Multi  = true,
    Callback = function(v)
        Config.SelectedMutations = type(v) == "table" and v or (v ~= "" and {v} or {})
    end
})

FishTab:Toggle({
    Title    = "Auto Favorite",
    Value    = false,
    Callback = function(v)
        Config.AutoFavoriteState = v
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
})

FishTab:Toggle({
    Title    = "Auto Unfavorite",
    Value    = false,
    Callback = function(v)
        Config.AutoUnfavoriteState = v
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
})

-- =============================
--    TAB: EASTER
-- =============================
local EasterTab = Window:Tab({ Title = "TP Event", Icon = "gift" })
EasterTab:Section({ Title = "Egg Hunt", Icon = "search" })

EasterTab:Paragraph({
    Title   = "Info",
    Content = "Auto cari semua Easter Egg di map."
})

EasterTab:Button({
    Title    = "TP ke Easter Island",
    Callback = function()
        teleportTo("Easter Island")
        NotifySuccess("Teleport", "Berhasil ke Easter Island!")
    end
})

EasterTab:Button({
    Title    = "TP ke Easter Cove",
    Callback = function()
        teleportTo("Easter Cove")
        NotifySuccess("Teleport", "Berhasil ke Easter Cove!")
    end
})

EasterTab:Toggle({
    Title    = "Auto Egg Hunt",
    Desc     = "Auto cari & kumpulkan telur Easter",
    Value    = false,
    Callback = function(v)
        Config.AutoEggHunt = v
        if v then
            startAutoEggHunt()
            NotifySuccess("Auto Egg Hunt", "Aktif!")
        else
            if Tasks.EggHuntTask then pcall(function() task.cancel(Tasks.EggHuntTask) end) end
            NotifyWarning("Auto Egg Hunt", "Dimatikan.")
        end
    end
})

EasterTab:Divider()
EasterTab:Section({ Title = "Buy Egg", Icon = "shopping-bag" })

local eggNames = {}
for n in pairs(EggShopList) do table.insert(eggNames, n) end
table.sort(eggNames)

EasterTab:Dropdown({
    Title  = "Pilih Egg",
    Values = eggNames,
    Value  = eggNames[1],
    Callback = function(v)
        local data = EggShopList[v]
        if data then Config.SelectedEggId = data.id; NotifyInfo("Egg", "Dipilih: "..v) end
    end
})

EasterTab:Toggle({
    Title    = "Auto Buy Egg",
    Desc     = "egg yang dipilih",
    Value    = false,
    Callback = function(v)
        Config.AutoBuyEgg = v
        if v then
            if Config.SelectedEggId == "" then
                NotifyError("Auto Buy Egg", "Pilih egg dulu!")
                Config.AutoBuyEgg = false; return
            end
            startAutoBuyEgg()
            NotifySuccess("Auto Buy Egg", "Aktif!")
        else
            if Tasks.BuyEggTask then pcall(function() task.cancel(Tasks.BuyEggTask) end) end
            NotifyWarning("Auto Buy Egg", "Dimatikan.")
        end
    end
})

EasterTab:Button({
    Title    = "Buy Egg Once",
    Callback = function()
        if Config.SelectedEggId == "" then NotifyError("Buy Egg", "Pilih egg dulu!"); return end
        if Events.BuyEgg then
            pcall(function() Events.BuyEgg:InvokeServer(Config.SelectedEggId) end)
            NotifySuccess("Buy Egg", "Egg dibeli!")
        else
            NotifyError("Buy Egg", "Remote tidak ditemukan!")
        end
    end
})

EasterTab:Divider()
EasterTab:Section({ Title = "Auto Event", Icon = "calendar" })

EasterTab:Toggle({
    Title    = "Auto Event",
    Desc     = "Auto interact event",
    Value    = false,
    Callback = function(v)
        Config.AutoEvent = v
        if v then
            startAutoEvent()
            NotifySuccess("Auto Event", "Aktif!")
        else
            if Tasks.AutoEventTask then pcall(function() task.cancel(Tasks.AutoEventTask) end) end
            NotifyWarning("Auto Event", "Dimatikan.")
        end
    end
})

-- =============================
--    TAB: MAIN
-- =============================
local MainTab = Window:Tab({ Title = "Main", Icon = "settings-2" })
MainTab:Section({ Title = "Auto Stone Enchant", Icon = "sparkles" })

local enchantStatusPara = MainTab:Paragraph({
    Title   = "Enchant Status",
    Content = "Rod: - | Enchant: - | Stone: 0"
})

task.spawn(function()
    local lastRod, lastEnchant, lastStone = "", "", -1
    while true do
        task.wait(2)
        pcall(function()
            local stones    = getEnchantStoneCount()
            local rod       = getEquippedRodName()
            local enchantId = getCurrentRodEnchant()
            local enchantName = "None"
            if enchantId then
                for n, id in pairs(enchantIdMap) do
                    if id == enchantId then enchantName = n; break end
                end
            end
            if rod ~= lastRod or enchantName ~= lastEnchant or stones ~= lastStone then
                enchantStatusPara:SetDesc(string.format(
                    "Rod = <font color='#00aaff'>%s</font> | Enchant = <font color='#ff66ff'>%s</font> | Stone = <font color='#ffdd00'>%d</font>",
                    rod, enchantName, stones
                ))
                lastRod, lastEnchant, lastStone = rod, enchantName, stones
            end
        end)
    end
end)

MainTab:Dropdown({
    Title  = "Stone Type",
    Values = { "Enchant Stones", "Evolved Enchant Stone" },
    Value  = "Enchant Stones",
    Callback = function(v) _G.SelectedStoneType = v end
})

MainTab:Dropdown({
    Title  = "Target Enchant",
    Values = {
        "Big Hunter 1","Cursed 1","Empowered 1","Glistening 1","Gold Digger 1",
        "Leprechaun 1","Mutation Hunter 1","Prismatic 1","Reeler 1","Stargazer 1",
        "Stormhunter 1","XPerienced 1","SECRET Hunter","Shark Hunter","Fairy Hunter 1"
    },
    Value  = "Big Hunter 1",
    Callback = function(v) _G.TargetEnchantBasic = v end
})

MainTab:Toggle({
    Title    = "Auto Enchant",
    Value    = false,
    Callback = function(v)
        _G.AutoEnchant = v
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
})

MainTab:Button({
    Title    = "Teleport ke Altar",
    Callback = function()
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(3234.837, -1302.855, 1398.391)
            NotifySuccess("Teleport", "Berhasil ke Altar!")
        end
    end
})

MainTab:Button({
    Title    = "Double Enchant (Sekali)",
    Desc     = "Equip stone → slot hotbar → activate altar",
    Callback = function()
        task.spawn(function()
            if not Events.activateAltar then
                NotifyError("Double Enchant", "Remote altar tidak ditemukan!"); return
            end
            local stones = findEnchantStones()
            if #stones == 0 then
                NotifyError("Double Enchant", "Stone tidak ada di inventory!"); return
            end
            if Events.equipItem then
                pcall(function() Events.equipItem:FireServer(stones[1].UUID, "Enchant Stones") end)
            end
            task.wait(1.2)
            local slot = countHotbarButtons() - 1
            if slot < 1 then slot = 1 end
            if Events.equip then pcall(function() CallRemote(Events.equip, slot) end) end
            task.wait(0.8)
            pcall(function() Events.activateAltar:FireServer() end)
            NotifySuccess("Double Enchant", "Selesai!")
        end)
    end
})

MainTab:Button({
    Title    = "Fix Rod",
    Desc     = "Gunakan jika bug rod/ganti skin",
    Callback = function()
        local done = false
        if Events.CancelFishing then
            pcall(function() CallRemote(Events.CancelFishing) end)
            done = true
        elseif Config.UB.Remotes.CancelFishingInputs then
            pcall(function() CallRemote(Config.UB.Remotes.CancelFishingInputs) end)
            done = true
        end
        if done then NotifySuccess("Fix Rod", "Rod di-reset!")
        else NotifyError("Fix Rod", "Remote tidak ditemukan!") end
    end
})

MainTab:Divider()
MainTab:Section({ Title = "Pirate Event", Icon = "map" })

MainTab:Button({
    Title    = "Open Cave Wall",
    Desc     = "Plant TNT",
    Callback = function()
        task.spawn(function()
            if not Events.searchItemPickedUp or not Events.gainAccessToMaze then
                NotifyError("Error", "Remote Cave tidak ditemukan!"); return
            end
            NotifyInfo("Cave", "Menanam TNT...")
            for i = 1, 4 do
                pcall(function() Events.searchItemPickedUp:FireServer("TNT") end)
                task.wait(0.7)
            end
            task.wait(1.5)
            pcall(function() Events.gainAccessToMaze:FireServer() end)
            NotifySuccess("Cave", "Wall dibuka!")
        end)
    end
})

MainTab:Toggle({
    Title    = "Auto Open Pirate Chest",
    Value    = false,
    Callback = function(v)
        _G.AutoPirateChest = v
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
                        if found > 0 then NotifySuccess("Pirate", "Claim "..found.." chest!") end
                    end)
                    task.wait(3)
                end
            end)
            NotifySuccess("Pirate", "Auto claim aktif!")
        else
            NotifyWarning("Pirate", "Dimatikan.")
        end
    end
})

MainTab:Divider()
MainTab:Section({ Title = "Cave Crystal", Icon = "gem" })

MainTab:Button({
    Title    = "Consume Crystal Now",
    Callback = function()
        if Events.ConsumeCaveCrystal then
            pcall(function() Events.ConsumeCaveCrystal:InvokeServer() end)
            task.wait(1.5); equipRod()
            NotifySuccess("Crystal", "Dikonsumsi!")
        else
            NotifyError("Crystal", "Remote tidak ditemukan!")
        end
    end
})

MainTab:Toggle({
    Title = "Auto Consume Crystal (30 menit)",
    Value = false,
    Callback = function(v)
        _G.AutoCrystal = v
        if v then
            if not Events.ConsumeCaveCrystal then
                NotifyError("Crystal", "Remote tidak ditemukan!"); return
            end
            _G.crystalTask = task.spawn(function()
                while _G.AutoCrystal do
                    pcall(function()
                        Events.ConsumeCaveCrystal:InvokeServer()
                        task.wait(1.5); equipRod()
                    end)
                    task.wait(1800)
                end
            end)
            NotifySuccess("Crystal", "Auto setiap 30 menit!")
        else
            if _G.crystalTask then pcall(function() task.cancel(_G.crystalTask) end); _G.crystalTask = nil end
            NotifyWarning("Crystal", "Dimatikan.")
        end
    end
})

MainTab:Divider()
MainTab:Section({ Title = "Auto Totem", Icon = "triangle" })

local totemData = {
    ["Pilih Totem"]=0, ["Luck Totem"]=1, ["Mutation Totem"]=2, ["Shiny Totem"]=3, ["Love Totem"]=5
}

MainTab:Dropdown({
    Title  = "Pilih Totem",
    Values = { "Pilih Totem","Luck Totem","Mutation Totem","Shiny Totem","Love Totem" },
    Value  = "Pilih Totem",
    Callback = function(v)
        Config.SelectedTotemID = totemData[v] or 0
        NotifyInfo("Totem", "Dipilih: "..v)
    end
})

MainTab:Toggle({
    Title = "Auto Spawn Totem (1 jam)",
    Value = false,
    Callback = function(v)
        Config.AutoTotem = v
        if v then
            Tasks.totemTask = task.spawn(function()
                while Config.AutoTotem do
                    pcall(function()
                        local hrp = getHRP()
                        if not hrp then return end
                        local totemUUID = nil
                        pcall(function()
                            local replion = GetPlayerDataReplion()
                            if not replion then return end
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
                            NotifySuccess("Totem", "Spawn! Cooldown 1 jam.")
                        end
                    end)
                    task.wait(3600)
                end
            end)
            NotifySuccess("Auto Totem", "Aktif!")
        else
            if Tasks.totemTask then pcall(function() task.cancel(Tasks.totemTask) end); Tasks.totemTask = nil end
            NotifyWarning("Auto Totem", "Dimatikan.")
        end
    end
})

-- =============================
--    TAB: COSMETIC
--    FIX: hapus SkinAnimList (tidak jalan), hapus Emote (tidak jalan)
--    Tetap: Aura (client-side, berfungsi)
-- =============================
local CosmeticTab = Window:Tab({ Title = "Cosmetic", Icon = "sparkles" })

CosmeticTab:Section({ Title = "Aura Animasi", Icon = "star" })

CosmeticTab:Paragraph({
    Title   = "Info",
    Content = "Efek partikel aura di sekitar karakter. Berjalan di client-side."
})

-- FIX: rename agar tidak collision dengan ubSkinNames
local auraNames = {}
for n in pairs(AuraList) do table.insert(auraNames, n) end
table.sort(auraNames)

local selectedAura = "None"
CosmeticTab:Dropdown({
    Title  = "Pilih Aura",
    Values = auraNames,
    Value  = "None",
    Callback = function(v) selectedAura = v end
})

CosmeticTab:Button({
    Title    = "Apply Aura",
    Desc     = "Terapkan efek aura pada karakter",
    Callback = function() applyAura(selectedAura) end
})

CosmeticTab:Button({
    Title    = "Remove Aura",
    Callback = function() applyAura("None") end
})

-- =============================
--    TAB: TELEPORT
-- =============================
local TpTab = Window:Tab({ Title = "Teleport", Icon = "map-pin" })
TpTab:Section({ Title = "Map Locations", Icon = "navigation" })

local locNames = {}
for n in pairs(LOCATIONS) do table.insert(locNames, n) end
table.sort(locNames)

local selectedLoc = locNames[1]
TpTab:Dropdown({
    Title  = "Pilih Lokasi",
    Values = locNames,
    Value  = locNames[1],
    Callback = function(v) selectedLoc = v end
})

TpTab:Button({
    Title    = "Teleport!",
    Callback = function()
        teleportTo(selectedLoc)
        NotifySuccess("Teleport", "Berhasil ke "..selectedLoc)
    end
})

TpTab:Divider()
TpTab:Section({ Title = "Player Teleport", Icon = "users" })

local function getPlayerList()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(list, p.Name) end
    end
    table.sort(list)
    return #list > 0 and list or {"-- Tidak ada --"}
end

local selectedPlayer = nil
TpTab:Dropdown({
    Title    = "Pilih Player",
    Values   = getPlayerList(),
    Callback = function(v) selectedPlayer = v end
})

TpTab:Button({
    Title    = "Teleport ke Player",
    Callback = function()
        if not selectedPlayer then NotifyError("Error", "Pilih player dulu!"); return end
        local target = Players:FindFirstChild(selectedPlayer)
        if target and target.Character then
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local hrp  = getHRP()
            if hrp and tHRP then
                hrp.CFrame = CFrame.new(tHRP.Position + Vector3.new(0, 3, 0))
                NotifySuccess("Teleport", "Berhasil ke "..selectedPlayer)
            end
        else
            NotifyError("Error", "Character tidak ditemukan!")
        end
    end
})

TpTab:Divider()
TpTab:Section({ Title = "Event Teleport", Icon = "zap" })

TpTab:Toggle({
    Title    = "Auto Leviathan Hunt TP",
    Value    = false,
    Callback = function(v)
        _G.AutoLev = v
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
                                    hrp.CFrame = CFrame.new(3474.053, -287.775, 3472.634)
                                    hasTP = true
                                    NotifySuccess("Leviathan", "TP ke Den!")
                                end
                            elseif not den then
                                hasTP = false
                            end
                        end
                    end)
                    task.wait(5)
                end
            end)
            NotifySuccess("Leviathan", "Mencari zona...")
        else
            if Tasks.levTask then pcall(function() task.cancel(Tasks.levTask) end) end
            NotifyWarning("Leviathan", "Dimatikan.")
        end
    end
})

TpTab:Divider()
TpTab:Section({ Title = "Auto Event TP", Icon = "crosshair" })

TpTab:Paragraph({
    Title   = "Info",
    Content = "Pilih event → aktifkan. Script scan map & TP ke platform melayang di atas event."
})

local eventTPNames = {}
for n in pairs(eventTPData) do table.insert(eventTPNames, n) end
table.sort(eventTPNames)

TpTab:Dropdown({
    Title    = "Pilih Event",
    Values   = eventTPNames,
    Multi    = true,
    Callback = function(v)
        selectedAutoEvents = type(v) == "table" and v or (v ~= "" and {v} or {})
    end
})

TpTab:Toggle({
    Title    = "Auto Event Teleport",
    Desc     = "(Worm/Megalodon/Shark/Thunderzilla)",
    Value    = false,
    Callback = function(v)
        autoEventTPEnabled = v
        if v then
            if #selectedAutoEvents == 0 then
                NotifyError("Auto Event TP", "Pilih minimal 1 event dulu!")
                autoEventTPEnabled = false; return
            end
            if autoEventThread then pcall(function() task.cancel(autoEventThread) end) end
            autoEventThread = task.spawn(runAutoEventTP)
            NotifySuccess("Auto Event TP", "Aktif! Mencari event...")
        else
            destroyEventPlatform()
            if autoEventThread then
                pcall(function() task.cancel(autoEventThread) end)
                autoEventThread = nil
            end
            NotifyWarning("Auto Event TP", "Dimatikan.")
        end
    end
})

-- =============================
--    TAB: SHOP
-- =============================
local ShopTab = Window:Tab({ Title = "Shop", Icon = "store" })
ShopTab:Section({ Title = "Weather (Cuaca)", Icon = "cloud-rain" })

local weatherMap = {
    ["Windy (10k)"]       = "Wind",
    ["Cloudy (20k)"]      = "Cloudy",
    ["Snow (15k)"]        = "Snow",
    ["Stormy (35k)"]      = "Storm",
    ["Radiant (50k)"]     = "Radiant",
    ["Shark Hunt (300k)"] = "Shark Hunt",
}
local wxNames = {}
for n in pairs(weatherMap) do table.insert(wxNames, n) end
table.sort(wxNames)

local selectedWeathers = {}
ShopTab:Dropdown({
    Title    = "Pilih Weather",
    Values   = wxNames,
    Multi    = true,
    Callback = function(v)
        selectedWeathers = type(v) == "table" and v or (v ~= "" and {v} or {})
    end
})

ShopTab:Button({
    Title    = "Buy Selected Weather",
    Callback = function()
        if #selectedWeathers == 0 then NotifyError("Error", "Pilih weather dulu!"); return end
        if not Events.BuyWeather then NotifyError("Error", "Remote tidak ditemukan!"); return end
        for _, name in ipairs(selectedWeathers) do
            local key = weatherMap[name]
            if key then pcall(function() Events.BuyWeather:InvokeServer(key) end); task.wait(0.5) end
        end
        NotifySuccess("Weather", "Purchased!")
    end
})

ShopTab:Toggle({
    Title    = "Auto Buy Weather",
    Value    = false,
    Callback = function(v)
        _G.AutoWeather = v
        if v then
            if #selectedWeathers == 0 then
                NotifyError("Error", "Pilih weather dulu!")
                _G.AutoWeather = false; return
            end
            task.spawn(function()
                while _G.AutoWeather do
                    if Events.BuyWeather then
                        for _, name in ipairs(selectedWeathers) do
                            local key = weatherMap[name]
                            if key then pcall(function() Events.BuyWeather:InvokeServer(key) end) end
                            task.wait(0.5)
                        end
                    end
                    task.wait(5)
                end
            end)
            NotifySuccess("Weather", "Aktif!")
        else
            NotifyWarning("Weather", "Dimatikan.")
        end
    end
})

-- =============================
--    TAB: MISC
-- =============================
local MiscTab = Window:Tab({ Title = "Misc", Icon = "wrench" })
MiscTab:Section({ Title = "Performance", Icon = "eye" })

local stopAnimConns = {}
MiscTab:Toggle({
    Title    = "No Animation",
    Value    = false,
    Callback = function(v)
        for _, c in ipairs(stopAnimConns) do c:Disconnect() end
        stopAnimConns = {}
        if v then
            local char = LocalPlayer.Character
            if char then
                local hum  = char:FindFirstChildOfClass("Humanoid")
                local anim = hum and hum:FindFirstChildOfClass("Animator")
                if anim then
                    for _, t in ipairs(anim:GetPlayingAnimationTracks()) do t:Stop(0) end
                    table.insert(stopAnimConns, anim.AnimationPlayed:Connect(function(t) t:Stop(0) end))
                end
            end
            NotifyInfo("Anim", "Dimatikan.")
        else
            NotifyInfo("Anim", "Normal.")
        end
    end
})

MiscTab:Toggle({
    Title    = "FPS Booster",
    Value    = false,
    Callback = function(v)
        if v then
            for _, obj in pairs(workspace:GetDescendants()) do
                pcall(function()
                    if obj:IsA("BasePart") then
                        obj.Reflectance = 0; obj.CastShadow = false
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                        obj.Enabled = false
                    end
                end)
            end
            local L = game:GetService("Lighting")
            L.GlobalShadows = false; L.FogEnd = 1e10
            for _, e in pairs(L:GetChildren()) do
                if e:IsA("PostEffect") then e.Enabled = false end
            end
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            NotifySuccess("FPS", "Aktif!")
        else
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
            NotifyInfo("FPS", "Normal.")
        end
    end
})

MiscTab:Toggle({
    Title    = "Disable Obtained",
    Desc     = "Sembunyikan notif Fish",
    Value    = false,
    Callback = function(v) setDisableObtained(v) end
})

local _backup = setmetatable({}, {__mode="k"})
local function DisableCtrl(ctrl)
    if _backup[ctrl] then return end
    local d = { functions = {} }
    for k, v in pairs(ctrl) do
        if type(v) == "function" then d.functions[k] = v; ctrl[k] = function() end end
    end
    _backup[ctrl] = d
end
local function EnableCtrl(ctrl)
    local d = _backup[ctrl]
    if not d then return end
    for k, v in pairs(d.functions) do ctrl[k] = v end
    _backup[ctrl] = nil
end

MiscTab:Toggle({
    Title    = "Disable VFX",
    Value    = false,
    Callback = function(v)
        if Controllers.VFX then
            if v then DisableCtrl(Controllers.VFX) else EnableCtrl(Controllers.VFX) end
        end
    end
})

MiscTab:Toggle({
    Title    = "Disable Cutscene",
    Value    = false,
    Callback = function(v)
        if Controllers.Cutscene then
            if v then DisableCtrl(Controllers.Cutscene) else EnableCtrl(Controllers.Cutscene) end
        end
    end
})

MiscTab:Divider()
MiscTab:Section({ Title = "Ping Panel", Icon = "bar-chart" })

MiscTab:Toggle({
    Title    = "Ping Panel (pojok kanan atas)",
    Desc     = "Ping + FPS",
    Value    = false,
    Callback = function(v)
        if v then createPingPanel(); NotifySuccess("Ping Panel", "Aktif!")
        else destroyPingPanel(); NotifyWarning("Ping Panel", "Disembunyikan.") end
    end
})

MiscTab:Divider()
MiscTab:Section({ Title = "Realtime Stats", Icon = "bar-chart-2" })

MiscTab:Toggle({
    Title    = "Realtime Stats",
    Desc     = "Panel draggable",
    Value    = false,
    Callback = function(v)
        if v then
            createRealtimePanel()
            NotifySuccess("Realtime Panel", "Aktif! Drag header untuk pindah.")
        else
            destroyRealtimePanel()
            NotifyWarning("Realtime Panel", "Dimatikan.")
        end
    end
})

MiscTab:Button({
    Title    = "Show FPS & Ping (sekali)",
    Callback = function()
        local frames, conn = 0, nil
        conn = RunService.RenderStepped:Connect(function() frames = frames + 1 end)
        task.wait(1)
        local fps = frames; conn:Disconnect()
        local ping = 0
        pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
        NotifyInfo("Stats", "FPS: "..fps.." | Ping: "..ping.."ms")
    end
})

MiscTab:Divider()
MiscTab:Section({ Title = "Webhook", Icon = "send" })

MiscTab:Toggle({
    Title    = "Enable Custom Webhook",
    Value    = false,
    Callback = function(v) Config.CustomWebhook = v end
})

MiscTab:Input({
    Title       = "Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback    = function(t)
        if not t or t == "" then NotifyError("Webhook", "URL kosong!"); return end
        Config.CustomWebhookUrl = t
        NotifySuccess("Webhook", "URL disimpan!")
    end
})

-- =============================
--    NOTIF AKHIR
-- =============================
task.wait(0.5)
WindUI:Notify({
    Title    = "MNA HUB",
    Content  = "Selamat Menikmati"..Config.NotifCount.."Script KAmi",
    Duration = 5,
    Icon     = "check-circle",
})
