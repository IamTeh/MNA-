--[[
    MNA HUB V11.3 FREE NOT SELL 
    UI : MNAHUB (Developer)
    Fix : Remote + Bug HookRemote + Amblatant 100x notif
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
local CoreGui           = game:GetService("CoreGui")
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

local remotes = net:GetChildren()
print("[MNA HUB] Remotes: " .. #remotes)

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
    AutoCatch        = false,
    CatchDelay       = 0.7,
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
    AutoMining          = false,
    axeUuid             = "",
    CustomWebhook       = false,
    CustomWebhookUrl    = "",
    HookNotif           = false,
    -- NOTIF DELAY CONFIG
    NotifDelay          = 0.1,  -- jeda antar notif (detik)
    NotifCount          = 3,  -- berapa kali notif per catch
}

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

-- Snapshot data catch terakhir
local lastValidFishCaught   = {}
local lastValidCaughtVisual = {}
local lastValidFishNotif    = {}

-- =============================
--    FIX: deepCopyArr di GLOBAL scope
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

local function equipRod()
    task.wait(0.1)
    CallRemote(Events and Events.equip, 1)
    task.wait(0.1)
    if Config.autoFishing or Config.AutoCatch then
        CallRemote(Events and Events.UpdateAutoFishing, true)
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
--    FIX: HookRemote di GLOBAL scope
--    (sebelum dipanggil manapun)
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
local Events = {}
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
    }
    for _, r in ipairs(list) do
        local remote = GetServerRemote(r.name)
        Events[r.key] = remote
        if remote then loaded += 1 else failed += 1 end
    end
    return loaded, failed
end

local loadedCount, failedCount = loadRemotes()

-- FIX: Hook di sini setelah HookRemote sudah didefinisikan
task.spawn(function()
    task.wait(1)
    HookRemote("RE/FishCaught",                  "FishCaught")
    HookRemote("RE/CaughtFishVisual",            "CaughtVisual")
    HookRemote("RE/ObtainedNewFishNotification", "FishNotif")
end)

-- =============================
--    LOCATIONS
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
    ["Easter Cove"]           = CFrame.new(500.0, 5.0, 1200.0),
}

local function teleportTo(locationName)
    local cf  = LOCATIONS[locationName]
    local hrp = getHRP()
    if not hrp or not cf then return end
    hrp.CFrame = cf + Vector3.new(0, 3, 0)
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
--    AMBLATANT: 3 real + 3 notif
--    dengan delay antar notif
-- =============================
local function replayAmblatantNotif()
    task.spawn(function()
        -- FishCaught & Visual: 1x saja
        local xr_caught = GetServerRemote("RE/FishCaught")
        local xr_visual = GetServerRemote("RE/CaughtFishVisual")
        local xr_notif  = GetServerRemote("RE/ObtainedNewFishNotification")

        if xr_caught and #lastValidFishCaught > 0 then
            FireLocalEvent(xr_caught, unpack(lastValidFishCaught))
        end
        task.wait(0.03)
        if xr_visual and #lastValidCaughtVisual > 0 then
            FireLocalEvent(xr_visual, unpack(lastValidCaughtVisual))
        end
        task.wait(0.03)

        -- Notif popup: Config.NotifCount kali dengan delay Config.NotifDelay
        if xr_notif and #lastValidFishNotif > 0 then
            for i = 1, Config.NotifCount do
                FireLocalEvent(xr_notif, unpack(lastValidFishNotif))
                task.wait(Config.NotifDelay)
            end
        end
    end)
end

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
                isCaught = false

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

                -- Tunggu konfirmasi server maksimal 1.5 detik
                if Config.amblatant then
                    local waited = 0
                    while not isCaught and waited < 1.5 do
                        task.wait(0.05)
                        waited += 0.05
                    end

                    if isCaught then
                        isCaught = false
                        -- Simpan snapshot data terbaru
                        if #(_G.SavedData.FishCaught or {}) > 0 then
                            lastValidFishCaught = deepCopyArr(_G.SavedData.FishCaught)
                        end
                        if #(_G.SavedData.CaughtVisual or {}) > 0 then
                            lastValidCaughtVisual = deepCopyArr(_G.SavedData.CaughtVisual)
                        end
                        if #(_G.SavedData.FishNotif or {}) > 0 then
                            lastValidFishNotif = deepCopyArr(_G.SavedData.FishNotif)
                        end
                    end

                    -- Replay notif 3x dengan delay
                    if #lastValidFishNotif > 0 then
                        replayAmblatantNotif()
                    end
                end
            end
            blatantFishCycleCount += 1
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
    Config.UB.Stats.startTime = tick()
    Tasks.ubtask = task.spawn(ub_loop)
    NotifySuccess("Ultra Blatant", "Aktif! ")
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
            task.wait(math.max(Config.AutoSellValue, 5))
            if Config.AutoSellState then
                pcall(function() Events.sell:InvokeServer({}) end)
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
    local name = item.Identifier or "Unknown"
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
        local skip_item = isUnfavorite and not isAlreadyFav or not isUnfavorite and isAlreadyFav
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
--    FISH NOTIF HOOK
-- =============================
task.spawn(function()
    task.wait(2)
    if Events.fishNotif then
        Events.fishNotif.OnClientEvent:Connect(function(...)
            local args = {...}
            _G.SavedData.FishNotif = args
            lastValidFishNotif = deepCopyArr(args)
            lastTimeFishCaught = os.clock()
            isCaught = true

            local dummyItem = { Id = args[1], Metadata = args[2] }
            local fishName, fishRarity = GetFishNameAndRarity(dummyItem)
            local mutation = GetItemMutationString(dummyItem)
            local weight   = string.format("%.2fkg", (args[2] and args[2].Weight) or 0)

            if Config.CustomWebhook and Config.CustomWebhookUrl ~= "" then
                pcall(function()
                    local payload = HttpService:JSONEncode({
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
                            Url = Config.CustomWebhookUrl,
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = payload
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
    Title       = "MNA HUB (FREE)",
    Icon        = "M",
    Author      = "IamTeh",
    Folder      = "Dev",
    Size        = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme       = "Developer",
    SideBarWidth = 170,
})

-- TOMBOL BUKA/TUTUP (draggable)
local G2L = {}
G2L["ToggleGui"] = Instance.new("ScreenGui")
G2L["ToggleGui"].Parent = game:GetService("CoreGui")
G2L["ToggleGui"].ResetOnSpawn = false
G2L["ToggleGui"].ZIndexBehavior = Enum.ZIndexBehavior.Sibling

G2L["ToggleBtn"] = Instance.new("ImageButton")
G2L["ToggleBtn"].Parent       = G2L["ToggleGui"]
G2L["ToggleBtn"].Size         = UDim2.new(0, 48, 0, 48)
G2L["ToggleBtn"].Position     = UDim2.new(0.05, 0, 0.04, 0)
G2L["ToggleBtn"].BackgroundColor3 = Color3.fromRGB(60, 0, 180)
G2L["ToggleBtn"].Image        = "rbxassetid://7733715400"
G2L["ToggleBtn"].Draggable    = true
G2L["ToggleBtn"].BorderSizePixel = 0

local btnCorner = Instance.new("UICorner", G2L["ToggleBtn"])
btnCorner.CornerRadius = UDim.new(0, 10)

local btnStroke = Instance.new("UIStroke", G2L["ToggleBtn"])
btnStroke.Thickness = 2
btnStroke.Color     = Color3.fromRGB(120, 50, 255)

local windowVisible = true
G2L["ToggleBtn"].MouseButton1Click:Connect(function()
    if windowVisible then
        Window:Close()
    else
        Window:Open()
    end
    windowVisible = not windowVisible
end)

Window:Tag({ Title = "V11.3",  Color = Color3.fromRGB(120, 50, 255), Radius = 17 })
Window:Tag({ Title = "FREE",   Color = Color3.fromRGB(120, 50, 255), Radius = 17 })

WindUI:Notify({
    Title   = "MNA HUB",
    Content = "Loaded! Remotes: " .. loadedCount .. " ",
    Duration = 4,
    Icon    = "M",
})

-- =============================
--    TAB: INFO
-- =============================
local InfoTab = Window:Tab({ Title = "Info", Icon = "" })

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
    Title    = "MNA",
    Desc     = "Shortcut buka/tutup UI",
    Value    = "By@Ella",
    Callback = function(v)
        Window:SetToggleKey(Enum.KeyCode[v])
    end
})

-- =============================
--    TAB: PLAYERS
-- =============================
local PlayersTab = Window:Tab({ Title = "Players", Icon = "" })

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
        _G.CustomJumpPower = val
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = val
            end
        end
    end
})

PlayersTab:Button({
    Title    = "Reset Speed & Jump",
    Callback = function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed    = 16
                hum.UseJumpPower = true
                hum.JumpPower    = 50
            end
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

-- =============================
--    TAB: FISHING
-- =============================
local FishTab = Window:Tab({ Title = "Fishing", Icon = "" })

FishTab:Section({ Title = "Ultra Blatant", Icon = "zap" })

local rodSettings = {
    ["1. 3 NOTIF KEDIP"]      = { CompleteDelay = 2.998 },
    ["2. Diamond / Element"]  = { CompleteDelay = 3.7   },
    ["3. (3) NOTIF"]            = { CompleteDelay = 2.890 },
    ["4. GF / Bambu"]         = { CompleteDelay = 3.7   },
    ["5. Ares/Angler/Astral"] = { CompleteDelay = 4.8   },
}
local rodNames = {}
for n in pairs(rodSettings) do table.insert(rodNames, n) end
table.sort(rodNames)

FishTab:Dropdown({
    Title  = "Template Rod",
    Values = rodNames,
    Value  = "1. Diamond / Element",
    Callback = function(v)
        local s = rodSettings[v]
        if s then Config.UB.Settings.CompleteDelay = s.CompleteDelay end
    end
})

FishTab:Input({
    Title       = "Complete Delay",
    Placeholder = "2.7",
    Callback    = function(t)
        local n = tonumber(t)
        if n and n >= 1 then
            Config.UB.Settings.CompleteDelay = n
            NotifySuccess("Delay", "Set: "..n.."s")
        end
    end
})

FishTab:Toggle({
    Title = "Ultra Blatant 3N",
    Desc  = "cari settingannya",
    Value = false,
    Callback = function(v)
        needCast = true
        onToggleUB(v)
    end
})

FishTab:Toggle({
    Title = "amBlantat",
    Desc  = "jangan terlalu berharap",
    Value = false,
    Callback = function(v)
        Config.amblatant = v
        saveCount = 0
        HookRemote("RE/FishCaught",                  "FishCaught")
        HookRemote("RE/CaughtFishVisual",            "CaughtVisual")
        HookRemote("RE/ObtainedNewFishNotification", "FishNotif")
        needCast = true
        onToggleUB(v)
    end
})

FishTab:Toggle({
    Title    = "Random Cast (Anti-Detect)",
    Value    = false,
    Callback = function(v) Config.antiOKOK = v end
})

FishTab:Divider()
FishTab:Section({ Title = "Notif Delay Config", Icon = "bell" })

FishTab:Slider({
    Title = "Catch",
    Desc  = "visual ya?",
    Value = { Min = 1, Max = 200, Default = 100 },
    Step  = 1,
    Callback = function(v)
        Config.NotifCount = v
        NotifyInfo("Notif", "Jumlah: "..v.."x per catch")
    end
})

FishTab:Slider({
    Title = "Delay  Notif",
    Desc  = "0.1s-1s",
    Value = { Min = 0, Max = 100, Default = 10 },
    Step  = 1,
    Callback = function(v)
        Config.NotifDelay = v / 100
        NotifyInfo("Delay", "Delay: "..Config.NotifDelay.."s")
    end
})

FishTab:Divider()
FishTab:Section({ Title = "Legit Fishing", Icon = "shield-check" })

FishTab:Toggle({
    Title    = "Legit Auto Catch",
    Value    = false,
    Callback = function(v)
        Config.AutoCatch = v
        if v then
            equipRod()
            CallRemote(Events.UpdateAutoFishing, true)
            NotifySuccess("Legit", "Aktif!")
        else
            CallRemote(Events.UpdateAutoFishing, false)
        end
    end
})

FishTab:Input({
    Title       = "Catch Delay",
    Placeholder = "0.7",
    Callback    = function(t)
        local n = tonumber(t)
        if n then Config.CatchDelay = n end
    end
})

FishTab:Toggle({
    Title    = "Perfection Enchant",
    Value    = false,
    Callback = function(v)
        Config.autoFishing = v
        CallRemote(Events.UpdateAutoFishing, v)
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
    Title       = "Sell Value (detik/count)",
    Placeholder = "50",
    Callback    = function(t)
        local n = tonumber(t)
        if n and n > 0 then Config.AutoSellValue = n end
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
            if Tasks.AutoSellThread then
                pcall(function() task.cancel(Tasks.AutoSellThread) end)
            end
        end
    end
})

FishTab:Button({
    Title    = "Sell All Now",
    Callback = function()
        if Events.sell then
            pcall(function() Events.sell:InvokeServer({}) end)
            NotifySuccess("Sell", "Semua ikan dijual!")
        end
    end
})

-- =============================
--    TAB: MAIN (Enchant + Cave)
-- =============================
local MainTab = Window:Tab({ Title = "Main", Icon = "" })

MainTab:Section({ Title = "Auto Enchant", Icon = "sparkles" })

MainTab:Dropdown({
    Title  = "Stone Type",
    Values = { "Enchant Stones", "Evolved Enchant Stone" },
    Value  = "Enchant Stones",
    Callback = function(v) _G.SelectedStoneType = v end
})

MainTab:Dropdown({
    Title  = "Target Enchant",
    Values = { "Big Hunter 1","Cursed 1","Empowered 1","Glistening 1","Gold Digger 1",
               "Leprechaun 1","Mutation Hunter 1","Prismatic 1","Reeler 1","Stargazer 1",
               "Stormhunter 1","XPerienced 1","SECRET Hunter","Shark Hunter","Fairy Hunter 1" },
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
                        local stones = {}
                        local inv = PlayerData:GetExpect("Inventory")
                        if inv and inv.Items then
                            local targetId = ({ ["Enchant Stones"]=10, ["Evolved Enchant Stone"]=558 })[_G.SelectedStoneType]
                            for _, item in ipairs(inv.Items) do
                                if item.Id == targetId then
                                    table.insert(stones, item.UUID)
                                end
                            end
                        end
                        if #stones > 0 and Events.equipItem and Events.activateAltar then
                            pcall(function() Events.equipItem:FireServer(stones[1], "Enchant Stones") end)
                            task.wait(1.5)
                            pcall(function() Events.activateAltar:FireServer() end)
                        end
                    end)
                    task.wait(2)
                end
            end)
            NotifySuccess("Auto Enchant", "Aktif!")
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

MainTab:Divider()
MainTab:Section({ Title = "Cave & Pirate", Icon = "map" })

MainTab:Toggle({
    Title    = "Auto Open Cave Wall",
    Value    = false,
    Callback = function(v)
        _G.AutoCaveWall = v
        if v then
            task.spawn(function()
                if not Events.searchItemPickedUp or not Events.gainAccessToMaze then
                    NotifyError("Error", "Remote Cave tidak ditemukan!")
                    return
                end
                for i = 1, 4 do
                    pcall(function() Events.searchItemPickedUp:FireServer("TNT") end)
                    task.wait(0.7)
                end
                task.wait(1.5)
                pcall(function() Events.gainAccessToMaze:FireServer() end)
                NotifySuccess("Cave", "Wall dibuka!")
            end)
        end
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
                        for _, chest in ipairs(storage:GetChildren()) do
                            if chest.Name:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") then
                                pcall(function() Events.claimPirateChest:FireServer(chest.Name) end)
                                task.wait(0.5)
                            end
                        end
                    end)
                    task.wait(3)
                end
            end)
            NotifySuccess("Pirate", "Auto claim aktif!")
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
            task.wait(1.5)
            equipRod()
            NotifySuccess("Crystal", "Dikonsumsi!")
        end
    end
})

MainTab:Toggle({
    Title = "Auto Consume Crystal (30 menit)",
    Value = false,
    Callback = function(v)
        _G.AutoCrystal = v
        if v then
            _G.crystalTask = task.spawn(function()
                while _G.AutoCrystal do
                    pcall(function()
                        Events.ConsumeCaveCrystal:InvokeServer()
                        task.wait(1.5)
                        equipRod()
                    end)
                    task.wait(1800)
                end
            end)
            NotifySuccess("Crystal", "Auto setiap 30 menit!")
        else
            if _G.crystalTask then
                pcall(function() task.cancel(_G.crystalTask) end)
            end
        end
    end
})

-- =============================
--    TAB: TELEPORT
-- =============================
local TpTab = Window:Tab({ Title = "Teleport", Icon = "" })

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
local playerDropdown = TpTab:Dropdown({
    Title  = "Pilih Player",
    Values = getPlayerList(),
    Callback = function(v) selectedPlayer = v end
})

TpTab:Button({
    Title    = "Teleport ke Player",
    Callback = function()
        if not selectedPlayer then
            NotifyError("Error", "Pilih player dulu!")
            return
        end
        local target = Players:FindFirstChild(selectedPlayer)
        if target and target.Character then
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local hrp  = getHRP()
            if hrp and tHRP then
                hrp.CFrame = tHRP.CFrame + Vector3.new(0, 3, 0)
                NotifySuccess("Teleport", "Berhasil ke "..selectedPlayer)
            end
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
        else
            if Tasks.levTask then
                pcall(function() task.cancel(Tasks.levTask) end)
            end
        end
    end
})

-- =============================
--    TAB: SHOP
-- =============================
local ShopTab = Window:Tab({ Title = "Shop", Icon = "store" })

ShopTab:Section({ Title = "Weather Event", Icon = "cloud-rain" })

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
    Callback = function(v) selectedWeathers = v or {} end
})

ShopTab:Button({
    Title    = "Buy Selected Weather",
    Callback = function()
        if #selectedWeathers == 0 then
            NotifyError("Error", "Pilih weather dulu!")
            return
        end
        for _, name in ipairs(selectedWeathers) do
            local key = weatherMap[name]
            if key and Events.BuyWeather then
                pcall(function() Events.BuyWeather:InvokeServer(key) end)
                task.wait(0.5)
            end
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
            task.spawn(function()
                while _G.AutoWeather do
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
        end
    end
})

-- =============================
--    TAB: MISC
-- =============================
local MiscTab = Window:Tab({ Title = "Misc", Icon = "arrangement" })

MiscTab:Section({ Title = "Visual & Performance", Icon = "eye" })

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
                local anim = char:FindFirstChildOfClass("Humanoid") and
                             char:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
                if anim then
                    for _, t in ipairs(anim:GetPlayingAnimationTracks()) do t:Stop(0) end
                    local c = anim.AnimationPlayed:Connect(function(t) t:Stop(0) end)
                    table.insert(stopAnimConns, c)
                end
            end
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
                        obj.Reflectance = 0
                        obj.CastShadow  = false
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                        obj.Enabled = false
                    end
                end)
            end
            local L = game:GetService("Lighting")
            L.GlobalShadows = false
            L.FogEnd = 1e10
            for _, e in pairs(L:GetChildren()) do
                if e:IsA("PostEffect") then e.Enabled = false end
            end
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            NotifySuccess("FPS", "Aktif! Shadows dimatikan 🚀")
        else
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        end
    end
})

local _backup = setmetatable({}, {__mode="k"})
local function DisableCtrl(ctrl)
    if _backup[ctrl] then return end
    local d = { functions = {} }
    for k, v in pairs(ctrl) do
        if type(v) == "function" then
            d.functions[k] = v
            ctrl[k] = function() end
        end
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
        Config.CustomWebhookUrl = t
        NotifySuccess("Webhook", "URL disimpan!")
    end
})

MiscTab:Divider()
MiscTab:Section({ Title = "Stats", Icon = "activity" })

MiscTab:Button({
    Title    = "Show FPS & Ping",
    Callback = function()
        local frames = 0
        local conn
        conn = RunService.RenderStepped:Connect(function() frames += 1 end)
        task.wait(1)
        local fps = frames
        conn:Disconnect()
        local ping = 0
        pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
        NotifyInfo("Stats", "FPS: "..fps.." | Ping: "..ping.."ms")
    end
})

-- =============================
--    NOTIF AWAL
-- =============================
task.wait(0.5)
WindUI:Notify({
    Title    = " MNA HUB",
    Content  = "Semua fitur loaded! Notif: "..Config.NotifCount.."x per catch 🎣",
    Duration = 5,
    Icon     = "check-circle",
})
