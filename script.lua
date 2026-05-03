--[[
    ╔══════════════════════════════════════════════════════════╗
    ║         MNA HUB —  Fish It (Fisch)                   ║
    ║         + MNA HUB Features Integration                  ║
    ║                                                         ║
    ║   Base   : MNA HUB (FatehSC)                         ║
    ║   Added  : MNA HUB V11.3 features                       ║
    ║            • Ultra Blatant 3N (NotifQueue system)       ║
    ║            • amBlantat (FishCaught replay)              ║
    ║            • SkinAnimation (FishCaught intercept)       ║
    ║            • Walk on Water                              ║
    ║            • Hide NameTag                               ║
    ║            • Disable Obtained Notification              ║
    ║            • Auto Enchant + Double Enchant              ║
    ║            • Auto Pirate Chest                          ║
    ║            • Cave Crystal                               ║
    ║            • Auto Totem                                 ║
    ║            • Auto Favorite (filter rarity/mutation)     ║
    ║            • Instant Bobber                             ║
    ║            • Ping + Realtime Panel                      ║
    ║            • Webhook Discord                            ║
    ║            • Auto Event TP Platform (Worm/Meg/Shark)    ║
    ║            • Auto Leviathan TP                          ║
    ╚══════════════════════════════════════════════════════════╝
]]

repeat task.wait(0.5) until game:IsLoaded()
task.wait(2)

-- =============================
--    WINDUI LOAD
-- =============================
local WindUI
local ok_ui = pcall(function()
    WindUI = loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
    ))()
end)
if not ok_ui or not WindUI then warn("⚠️ UI failed to load!"); return end

-- =============================
--    SERVICES
-- =============================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera
local isMobile          = UserInputService.TouchEnabled

-- =============================
--    NOTIFY HELPERS
-- =============================
local function NS(t,m,d) WindUI:Notify({Title="✅ "..t,Content=m,Duration=d or 3,Icon="check-circle"}) end
local function NE(t,m,d) WindUI:Notify({Title="❌ "..t,Content=m,Duration=d or 3,Icon="x-circle"}) end
local function NI(t,m,d) WindUI:Notify({Title="ℹ️ "..t,Content=m,Duration=d or 3,Icon="info"}) end
local function NW(t,m,d) WindUI:Notify({Title="⚠️ "..t,Content=m,Duration=d or 3,Icon="alert-triangle"}) end

-- =============================
--    NET FOLDER (sama seperti Stree & MNA)
--    Stree pakai _Index, MNA pakai _index
--    Kita coba dua-duanya
-- =============================
local net
pcall(function()
    net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
end)
if not net then
    pcall(function()
        net = ReplicatedStorage
            :WaitForChild("Packages", 10)
            :WaitForChild("_index", 10)
            :WaitForChild("sleitnick_net@0.2.0", 10)
            :WaitForChild("net", 10)
    end)
end
if not net then warn("[MNA] net folder tidak ditemukan!"); return end

-- =============================
--    REMOTE LOADER (MNA system)
--    GetServerRemote: label di i, remote di i+1
-- =============================
local function GetServerRemote(targetName)
    local all = net:GetChildren()
    for i, r in ipairs(all) do
        if r.Name == targetName then
            return all[i + 1]
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

local function FireLocalEvent(remote, ...)
    if not remote then return end
    local args = {...}
    pcall(function()
        for _, conn in pairs(getconnections(remote.OnClientEvent)) do
            if conn.Function then
                task.spawn(function()
                    conn.Function(unpack(args))
                end)
            end
        end
    end)
end

-- =============================
--    HELPER
-- =============================
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- =============================
--    SAFE CALL (dari Stree)
-- =============================
local lastCall = {}
local function safeCall(k, f)
    local n = os.clock()
    local d = 0.18
    if lastCall[k] and n - lastCall[k] < d then task.wait(d-(n-lastCall[k])) end
    local o, r = pcall(f)
    lastCall[k] = os.clock()
    if not o then
        local m = tostring(r):lower()
        task.wait(m:find("429") or m:find("too many requests") and 1.5 or 0.2)
    end
    return o, r
end

-- =============================
--    REMOTE SHORTCUTS (Stree style)
-- =============================
local function rod()    safeCall("rod",    function() net["RE/EquipToolFromHotbar"]:FireServer(1) end) end
local function sell()   safeCall("sell",   function() net["RF/SellAllItems"]:InvokeServer() end) end
local function autoon() safeCall("autoon", function() net["RF/UpdateAutoFishingState"]:InvokeServer(true) end) end
local function autooff()safeCall("autooff",function() net["RF/UpdateAutoFishingState"]:InvokeServer(false) end) end

-- =============================
--    EVENTS MAP (MNA style)
-- =============================
local Events = {}
local function loadRemotes()
    local list = {
        {key="equip",              name="RF/EquipToolFromHotbar"},
        {key="unequip",            name="RE/UnequipToolFromHotbar"},
        {key="equipItem",          name="RE/EquipItem"},
        {key="CancelFishing",      name="RF/CancelFishingInputs"},
        {key="charge",             name="RF/ChargeFishingRod"},
        {key="minigame",           name="RF/RequestFishingMinigameStarted"},
        {key="UpdateAutoFishing",  name="RF/UpdateAutoFishingState"},
        {key="fishing",            name="RF/CatchFishCompleted"},
        {key="fishingRE",          name="RE/CatchFishCompleted"},
        {key="exclaimEvent",       name="RE/ReplicateTextEffect"},
        {key="sellRF",             name="RF/SellAllItems"},
        {key="favorite",           name="RE/FavoriteItem"},
        {key="SpawnTotem",         name="RE/SpawnTotem"},
        {key="fishNotif",          name="RE/ObtainedNewFishNotification"},
        {key="activateAltar",      name="RE/ActivateEnchantingAltar"},
        {key="searchItemPickedUp", name="RE/SearchItemPickedUp"},
        {key="gainAccessToMaze",   name="RE/GainAccessToMaze"},
        {key="claimPirateChest",   name="RE/ClaimPirateChest"},
        {key="BuyWeather",         name="RF/PurchaseWeatherEvent"},
        {key="ConsumeCaveCrystal", name="RF/ConsumeCaveCrystal"},
    }
    local loaded, failed = 0, 0
    for _, r in ipairs(list) do
        Events[r.key] = GetServerRemote(r.name)
        if Events[r.key] then loaded=loaded+1 else failed=failed+1 end
    end
    return loaded, failed
end
local loadedCount, failedCount = loadRemotes()

-- =============================
--    AFK PREVENT
-- =============================
pcall(function()
    for _, v in pairs(getconnections(LocalPlayer.Idled)) do
        if v.Disable then v:Disable() elseif v.Disconnect then v:Disconnect() end
    end
end)

-- =============================
--    CONFIG
-- =============================
local Config = {
    -- Stree features
    AutoFishing     = false,
    AutoEquipRod    = false,
    AutoSell        = false,
    SellDelay       = 30,
    InstantDelay    = 0.35,
    FishingDelay    = 0.5,
    FishingMode     = "Instant",
    AutoSellFish    = true,

    -- MNA UB
    UB = {
        Active   = false,
        Settings = { CompleteDelay = 3.7, CancelDelay = 0.3 },
        Remotes  = {},
        Stats    = { castCount = 0, startTime = 0 }
    },
    amblatant           = false,
    antiOKOK            = false,
    autoFishing         = false,
    NotifDelay          = 0.1,
    NotifCount          = 3,
    UBNotifDurationMult = 2.0,
    HookNotif           = false,

    -- MNA extras
    WalkOnWater         = false,
    HideNameTag         = false,
    DisableObtained     = false,
    InstantBobber       = false,
    SkinAnimEnabled     = false,
    SelectedSkinId      = "Eclipse",
    AutoFavoriteState   = false,
    AutoUnfavoriteState = false,
    SelectedRarities    = {},
    SelectedMutations   = {},
    AutoSellMethod      = "Delay",
    AutoSellValue       = 50,
    AutoTotem           = false,
    SelectedTotemID     = 0,
    CustomWebhook       = false,
    CustomWebhookUrl    = "",
    AutoEvent           = false,
    AutoBuyEgg          = false,
    SelectedEggId       = "",
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
--    HOOK REMOTE (MNA)
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

task.spawn(function()
    task.wait(1)
    HookRemote("RE/FishCaught",                  "FishCaught")
    HookRemote("RE/CaughtFishVisual",            "CaughtVisual")
    HookRemote("RE/ObtainedNewFishNotification", "FishNotif")
end)

-- =============================
--    UB NOTIF QUEUE PROCESSOR
-- =============================
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
            _G.NotifActive = 0
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
                    task.spawn(function()
                        task.wait(dur)
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
--    amBlantat REPLAY
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
                if i < Config.NotifCount then task.wait(Config.NotifDelay) end
            end
        end
    end)
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
end

local function safeFire(func)
    task.spawn(function() pcall(func) end)
end

local function ub_loop()
    while Config.UB.Active do
        local ok, err = pcall(function()
            local currentTime = tick()
            local baseWait = needCast and 0.7 or Config.UB.Settings.CancelDelay
            if Config.antiOKOK then baseWait = baseWait + math.random(5,20)/100 end
            task.wait(baseWait)
            needCast = false

            safeFire(function()
                if Config.UB.Remotes.ChargeFishingRod then
                    pcall(function()
                        Config.UB.Remotes.ChargeFishingRod:InvokeServer({[1]=currentTime})
                    end)
                end
            end)

            task.wait(Config.antiOKOK and math.random(15,25)/100 or 0.1)

            safeFire(function()
                if Config.UB.Remotes.RequestMinigame then
                    pcall(function()
                        Config.UB.Remotes.RequestMinigame:InvokeServer(1, 0, currentTime)
                    end)
                end
            end)

            local completeDelay = Config.UB.Settings.CompleteDelay
            if Config.antiOKOK then completeDelay = completeDelay + math.random(-10,10)/100 end
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

                -- FIX race condition: reset isCaught SETELAH fire
                isCaught = false

                if Config.amblatant then
                    local waited = 0
                    while not isCaught and waited < 1.5 do
                        task.wait(0.05); waited = waited + 0.05
                    end
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
                    if Config.amblatant then
                        if #lastValidFishNotif > 0 then replayAmblatantNotif() end
                    else
                        if #lastValidFishNotif > 0 then
                            table.insert(_G.NotifQueue, deepCopyArr(lastValidFishNotif))
                        end
                    end
                elseif not Config.amblatant then
                    if #lastValidFishNotif > 0 then
                        table.insert(_G.NotifQueue, deepCopyArr(lastValidFishNotif))
                    end
                end
            end
            blatantFishCycleCount = blatantFishCycleCount + 1
        end)
        if not ok then warn("[STREE+MNA] UB error: "..tostring(err)); task.wait(1) end
    end
end

local function equipRod()
    task.wait(0.1)
    if Events.equip then CallRemote(Events.equip, 1) end
    task.wait(0.1)
    if Events.UpdateAutoFishing and (Config.autoFishing or Config.AutoCatch) then
        CallRemote(Events.UpdateAutoFishing, true)
    end
end

local function UB_start()
    if Config.UB.Active then return end
    UB_init()
    Config.UB.Active = true
    needCast = true; isCaught = false
    _G.NotifQueue = {}; _G.NotifActive = 0
    Config.UB.Stats.startTime = tick()
    Tasks.ubtask = task.spawn(ub_loop)
    NS("Ultra Blatant", "Aktif!")
end

local function UB_stop()
    if not Config.UB.Active then return end
    Config.UB.Active = false
    _G.NotifQueue = {}; _G.NotifActive = 0
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
    NW("Ultra Blatant", "Dimatikan.")
end

local function onToggleUB(v)
    if v then
        Config.HookNotif = true
        equipRod(); task.wait(0.5)
        UB_start()
    else
        UB_stop()
        Config.HookNotif = false
    end
end

UB_init()

-- Anti stuck UB
task.spawn(function()
    while true do
        task.wait(5)
        if Config.UB.Active
        and lastTimeFishCaught ~= nil
        and os.clock() - lastTimeFishCaught >= 20
        and blatantFishCycleCount > 1 then
            needCast = true; saveCount = 0; blatantFishCycleCount = 0
            lastTimeFishCaught = os.clock()
            onToggleUB(false); task.wait(1); onToggleUB(true)
        end
    end
end)

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
                    local payload = HttpService:JSONEncode({
                        username = "MNA HUB",
                        embeds = {{
                            title = "Fish Caught!",
                            color = 0x00aaff,
                            fields = {
                                {name="Fish",   value=tostring(args[1] or "?"), inline=true},
                                {name="Rarity", value=tostring(args[2] and args[2].Rarity or "?"), inline=true},
                            },
                            footer = { text = "MNA HUB" }
                        }}
                    })
                    if typeof(request) == "function" then
                        request({
                            Url=Config.CustomWebhookUrl, Method="POST",
                            Headers={["Content-Type"]="application/json"}, Body=payload
                        })
                    end
                end)
            end
        end)
    end
end)

-- Exclaim legit
task.spawn(function()
    task.wait(2)
    if Events.exclaimEvent then
        Events.exclaimEvent.OnClientEvent:Connect(function(data)
            if not Config.AutoCatch then return end
            if not data or not data.TextData then return end
            if data.TextData.EffectType ~= "Exclaim" then return end
            local c = LocalPlayer.Character
            if not c or data.Container ~= c:FindFirstChild("Head") then return end
            task.wait(0.5)
            safeFire(function()
                if Events.fishing then
                    pcall(function() Events.fishing:InvokeServer() end)
                end
            end)
        end)
    end
end)

-- =============================
--    WALK ON WATER (MNA)
-- =============================
local walkOnWaterConn = nil
local function setWalkOnWater(enabled)
    Config.WalkOnWater = enabled
    if walkOnWaterConn then walkOnWaterConn:Disconnect(); walkOnWaterConn = nil end
    if enabled then
        walkOnWaterConn = RunService.Heartbeat:Connect(function()
            local hrp = getHRP()
            if not hrp then return end
            local waterY = 1.5
            if hrp.Position.Y < waterY then
                hrp.CFrame = CFrame.new(hrp.Position.X, waterY, hrp.Position.Z)
                    * CFrame.fromEulerAnglesXYZ(0, math.atan2(hrp.CFrame.LookVector.X, hrp.CFrame.LookVector.Z), 0)
            end
        end)
        NS("Walk on Water","Aktif!")
    else NW("Walk on Water","Dimatikan.") end
end

-- =============================
--    HIDE NAMETAG (MNA)
-- =============================
local hideNameTagConn = nil
local function setHideNameTag(enabled)
    Config.HideNameTag = enabled
    local function processChar(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.DisplayDistanceType = enabled
                and Enum.HumanoidDisplayDistanceType.None
                or  Enum.HumanoidDisplayDistanceType.Viewer
        end
        local head = char:FindFirstChild("Head")
        if head then
            for _, v in pairs(head:GetChildren()) do
                if v:IsA("BillboardGui") then v.Enabled = not enabled end
            end
        end
    end
    processChar(LocalPlayer.Character)
    if hideNameTagConn then hideNameTagConn:Disconnect(); hideNameTagConn = nil end
    hideNameTagConn = LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.5); processChar(c) end)
    if enabled then NS("Hide NameTag","Nama disembunyikan!") else NW("Hide NameTag","Nama kembali.") end
end

-- =============================
--    DISABLE OBTAINED (MNA)
-- =============================
local obtainedDisabledConns = {}
local function setDisableObtained(enabled)
    Config.DisableObtained = enabled
    if enabled then
        if #obtainedDisabledConns > 0 then
            for _, c in ipairs(obtainedDisabledConns) do pcall(function() if c.Enable then c:Enable() end end) end
            obtainedDisabledConns = {}
        end
        local xr = Events.fishNotif or GetServerRemote("RE/ObtainedNewFishNotification")
        if xr then
            pcall(function()
                for _, conn in pairs(getconnections(xr.OnClientEvent)) do
                    if conn.Function then conn:Disable(); table.insert(obtainedDisabledConns, conn) end
                end
            end)
        end
        NS("Disable Obtained","Notif item disembunyikan!")
    else
        for _, c in ipairs(obtainedDisabledConns) do
            pcall(function() if c.Enable then c:Enable() end end)
        end
        obtainedDisabledConns = {}
        NW("Disable Obtained","Notif item kembali normal.")
    end
end

-- =============================
--    INSTANT BOBBER (MNA)
-- =============================
local InstantBobberState = {
    active = false, setupDone = false,
    baitsByUserId = nil, cosmeticFolder = nil,
    baitCastConn = nil, baitDestroyedConn = nil, renderConn = nil,
}

local function patchInstantBobber(enabled)
    if not enabled then
        InstantBobberState.active = false
        if InstantBobberState.baitsByUserId then table.clear(InstantBobberState.baitsByUserId) end
        if InstantBobberState.renderConn then InstantBobberState.renderConn:Disconnect(); InstantBobberState.renderConn = nil end
        return
    end
    InstantBobberState.active = true
    InstantBobberState.baitsByUserId = InstantBobberState.baitsByUserId or {}
    table.clear(InstantBobberState.baitsByUserId)
    if InstantBobberState.setupDone then return end
    InstantBobberState.setupDone = true

    local ok, cf = pcall(function() return workspace:WaitForChild("CosmeticFolder",5) end)
    if not ok or not cf then InstantBobberState.setupDone=false; InstantBobberState.active=false; return end
    InstantBobberState.cosmeticFolder = cf

    local baitCast    = GetServerRemote("RE/BaitCastVisual")
    local baitDest    = GetServerRemote("RE/BaitDestroyed")
    if not baitCast or not baitDest then
        InstantBobberState.setupDone=false; InstantBobberState.active=false; return
    end

    InstantBobberState.baitCastConn = baitCast.OnClientEvent:Connect(function(player, data)
        if not InstantBobberState.active then return end
        if not player or not data or typeof(data.CastPosition) ~= "Vector3" then return end
        InstantBobberState.baitsByUserId[player.UserId] = {
            pivot=CFrame.new(data.CastPosition), expiresAt=tick()+1.5
        }
    end)

    InstantBobberState.baitDestroyedConn = baitDest.OnClientEvent:Connect(function(player)
        if not InstantBobberState.active then return end
        if player and player.UserId then InstantBobberState.baitsByUserId[player.UserId] = nil end
    end)

    InstantBobberState.renderConn = RunService.RenderStepped:Connect(function()
        if not InstantBobberState.active then return end
        local now = tick()
        local cosf = InstantBobberState.cosmeticFolder
        if not cosf then return end
        for userId, entry in pairs(InstantBobberState.baitsByUserId) do
            if now > entry.expiresAt then
                InstantBobberState.baitsByUserId[userId] = nil
            else
                local model = cosf:FindFirstChild(tostring(userId))
                if model and model.PivotTo then model:PivotTo(entry.pivot) end
            end
        end
    end)
end

-- =============================
--    SKIN ANIMATION (MNA dari teman)
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
            if nextTrack then pcall(function() track:Stop(0); nextTrack:Play(0,1,1) end) end
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
--    PING PANEL (MNA)
-- =============================
local pingGui, pingConn = nil, nil
local function createPingPanel()
    if pingGui then pingGui:Destroy(); pingGui=nil end
    if pingConn then pcall(function() task.cancel(pingConn) end); pingConn=nil end
    pingGui = Instance.new("ScreenGui")
    pingGui.Name="STREEMNA_PingPanel"; pingGui.ResetOnSpawn=false
    pingGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; pingGui.Parent=game:GetService("CoreGui")
    local frame = Instance.new("Frame",pingGui)
    frame.Size=UDim2.new(0,130,0,52); frame.Position=UDim2.new(1,-145,0,8)
    frame.BackgroundColor3=Color3.fromRGB(18,18,28); frame.BackgroundTransparency=0.15
    frame.BorderSizePixel=0; frame.Active=true
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
    local st = Instance.new("UIStroke",frame); st.Color=Color3.fromRGB(0,200,255); st.Thickness=1.2
    local t1=Instance.new("TextLabel",frame); t1.Size=UDim2.new(1,0,0.45,0)
    t1.BackgroundTransparency=1; t1.Text="STREE+MNA — STATS"
    t1.TextColor3=Color3.fromRGB(0,200,255); t1.TextSize=9; t1.Font=Enum.Font.GothamBold
    t1.TextXAlignment=Enum.TextXAlignment.Center
    local t2=Instance.new("TextLabel",frame); t2.Size=UDim2.new(1,0,0.55,0)
    t2.Position=UDim2.new(0,0,0.45,0); t2.BackgroundTransparency=1
    t2.Text="Ping: -- ms | FPS: --"
    t2.TextColor3=Color3.fromRGB(240,240,240); t2.TextSize=11; t2.Font=Enum.Font.Gotham
    t2.TextXAlignment=Enum.TextXAlignment.Center
    local fpsCount,fpsAccum=0,0
    local fpsConn=RunService.RenderStepped:Connect(function(dt) fpsCount=fpsCount+1; fpsAccum=fpsAccum+dt end)
    frame.Draggable=true
    pingConn=task.spawn(function()
        while pingGui and pingGui.Parent do
            task.wait(1)
            local ping=0; pcall(function() ping=math.floor(LocalPlayer:GetNetworkPing()*1000) end)
            local fps=math.floor(fpsCount/math.max(fpsAccum,0.001))
            fpsCount=0; fpsAccum=0
            local icon=ping<80 and "🟢" or ping<150 and "🟡" or "🔴"
            if t2 and t2.Parent then t2.Text=icon.." "..ping.."ms  |  "..fps.." FPS" end
        end
        fpsConn:Disconnect()
    end)
    return pingGui
end
local function destroyPingPanel()
    if pingConn then pcall(function() task.cancel(pingConn) end); pingConn=nil end
    if pingGui then pingGui:Destroy(); pingGui=nil end
end

-- =============================
--    AUTO FAV (MNA)
-- =============================
local function GetItemMutationString(item)
    if item.Metadata and item.Metadata.Shiny == true then return "Shiny" end
    return item.Metadata and item.Metadata.VariantId or ""
end

local function RunAutoFavLoop(isUnfavorite)
    local ok, Replion = pcall(function()
        return require(ReplicatedStorage.Packages.Replion).Client:WaitReplion("Data", 5)
    end)
    if not ok or not Replion then return end
    if not Events.favorite then return end
    local ok2, invData = pcall(function() return Replion:GetExpect("Inventory") end)
    if not ok2 or not invData or not invData.Items then return end
    local targets = {}
    for _, item in ipairs(invData.Items) do
        local isAlreadyFav = (item.IsFavorite or item.Favorited)
        local skip_item = (isUnfavorite and not isAlreadyFav) or (not isUnfavorite and isAlreadyFav)
        if not skip_item then
            local rarity = item.Metadata and item.Metadata.Rarity or "COMMON"
            local mutation = GetItemMutationString(item)
            local match = false
            for _, r in ipairs(Config.SelectedRarities) do
                if string.lower(rarity) == string.lower(r) then match=true; break end
            end
            if not match and table.find(Config.SelectedMutations, mutation) then match=true end
            if match and item.UUID then table.insert(targets, item.UUID) end
        end
    end
    for _, uuid in ipairs(targets) do
        if (isUnfavorite and not Config.AutoUnfavoriteState)
        or (not isUnfavorite and not Config.AutoFavoriteState) then break end
        pcall(function() Events.favorite:FireServer(uuid) end)
        task.wait(0.35)
    end
end

-- =============================
--    AUTO SELL (Count method dari MNA)
-- =============================
local function RunAutoSellLoop()
    if Tasks.AutoSellThread then
        pcall(function() task.cancel(Tasks.AutoSellThread) end)
    end
    Tasks.AutoSellThread = task.spawn(function()
        while Config.AutoSell do
            if not Events.sellRF then
                Events.sellRF = GetServerRemote("RF/SellAllItems")
                if not Events.sellRF then Config.AutoSell=false; break end
            end
            if Config.AutoSellMethod == "Delay" then
                task.wait(math.max(Config.AutoSellValue,5))
                if Config.AutoSell then pcall(function() Events.sellRF:InvokeServer({}) end) end
            elseif Config.AutoSellMethod == "Count" then
                local startCount = saveCount
                while Config.AutoSell and (saveCount-startCount) < Config.AutoSellValue do task.wait(1) end
                if Config.AutoSell then
                    pcall(function() Events.sellRF:InvokeServer({}) end)
                    NS("Auto Sell","Sell! ("..Config.AutoSellValue.." catch)")
                end
            else
                task.wait(5)
            end
        end
    end)
end

-- =============================
--    AUTO EVENT TELEPORT (MNA)
-- =============================
local autoEventTPEnabled   = false
local autoEventThread      = nil
local createdEventPlatform = nil
local selectedAutoEvents   = {}
local megCheckRadius       = 150

local eventTPData = {
    ["Worm Hunt"] = {
        TargetName="Model",
        Locations={Vector3.new(2190.85,-1.4,97.575),Vector3.new(-2450.679,-1.4,139.731),Vector3.new(-267.479,-1.4,5188.531),Vector3.new(-327,-1.4,2422)},
        PlatformY=107, Priority=1
    },
    ["Megalodon Hunt"] = {
        TargetName="Megalodon Hunt",
        Locations={Vector3.new(-1076.3,-1.4,1676.2),Vector3.new(-1191.8,-1.4,3597.3),Vector3.new(412.7,-1.4,4134.4)},
        PlatformY=107, Priority=2
    },
    ["Ghost Shark Hunt"] = {
        TargetName="Ghost Shark Hunt",
        Locations={Vector3.new(489.559,-1.35,25.406),Vector3.new(-1358.216,-1.35,4100.556),Vector3.new(627.859,-1.35,3798.081)},
        PlatformY=107, Priority=3
    },
    ["Shark Hunt"] = {
        TargetName="Shark Hunt",
        Locations={Vector3.new(1.65,-1.35,2095.725),Vector3.new(1369.95,-1.35,930.125),Vector3.new(-1585.5,-1.35,1242.875),Vector3.new(-1896.8,-1.35,2634.375)},
        PlatformY=107, Priority=4
    },
    ["Thunderzilla Hunt"] = {
        TargetName="Shocked",
        Locations={Vector3.new(2071.847,-2.673,15.144)},
        PlatformY=107, Priority=5
    },
}

local function destroyEventPlatform()
    if createdEventPlatform then createdEventPlatform:Destroy(); createdEventPlatform=nil end
end

local function createAndTPtoPlatform(targetPos, yOffset)
    local hrp = getHRP(); if not hrp then return end
    local desiredPos = Vector3.new(targetPos.X, yOffset, targetPos.Z)
    if createdEventPlatform and createdEventPlatform.Parent then
        createdEventPlatform.Position = desiredPos
    else
        destroyEventPlatform()
        local p = Instance.new("Part")
        p.Size=Vector3.new(5,1,5); p.Position=desiredPos
        p.Anchored=true; p.Transparency=1; p.CanCollide=true
        p.Name="STREEMNA_EventPlatform"; p.Parent=workspace
        createdEventPlatform = p
    end
    hrp.CFrame = CFrame.new(createdEventPlatform.Position + Vector3.new(0,3,0))
end

local function runAutoEventTP()
    while autoEventTPEnabled do
        local sorted = {}
        for _, eName in ipairs(selectedAutoEvents) do
            if eventTPData[eName] then table.insert(sorted, eventTPData[eName]) end
        end
        table.sort(sorted, function(a,b) return a.Priority < b.Priority end)
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
                                for _, loc in ipairs(cfg.Locations) do
                                    if (model.PrimaryPart.Position-loc).Magnitude <= megCheckRadius then
                                        foundPos = model.PrimaryPart.Position; break
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
                        local pos = d:IsA("BasePart") and d.Position or (d.PrimaryPart and d.PrimaryPart.Position)
                        if pos then
                            for _, loc in ipairs(cfg.Locations) do
                                if (pos-loc).Magnitude <= megCheckRadius then foundPos=pos; break end
                            end
                        end
                    end
                    if foundPos then break end
                end
            end
            if foundPos then createAndTPtoPlatform(foundPos, cfg.PlatformY); break end
        end
        task.wait(0.5)
    end
    destroyEventPlatform()
end

-- =============================
--    ENCHANT HELPERS (MNA)
-- =============================
local enchantIdMap = {
    ["Big Hunter 1"]=3,["Cursed 1"]=12,["Empowered 1"]=9,["Glistening 1"]=1,
    ["Gold Digger 1"]=4,["Leprechaun 1"]=5,["Mutation Hunter 1"]=7,["Prismatic 1"]=13,
    ["Reeler 1"]=2,["Stargazer 1"]=8,["Stormhunter 1"]=11,["XPerienced 1"]=10,
    ["SECRET Hunter"]=16,["Shark Hunter"]=20,["Fairy Hunter 1"]=15,
}
local STONE_IDS = {["Enchant Stones"]=10,["Evolved Enchant Stone"]=558}

local function findEnchantStones()
    local stones = {}
    pcall(function()
        local Replion = require(ReplicatedStorage.Packages.Replion).Client:WaitReplion("Data",5)
        if not Replion then return end
        local inv = Replion:GetExpect("Inventory")
        if not inv or not inv.Items then return end
        local tid = STONE_IDS[_G.SelectedStoneType or "Enchant Stones"]
        for _, item in ipairs(inv.Items) do
            if item.Id == tid then table.insert(stones, item) end
        end
    end)
    return stones
end

-- =============================
--    STREE KAITUN BACKGROUND
-- =============================
local ScreenGui2, Background2, Saturn2, SpaceSound2

local function CreateKaitunBackground()
    if ScreenGui2 then ScreenGui2:Destroy() end
    ScreenGui2 = Instance.new("ScreenGui")
    ScreenGui2.IgnoreGuiInset=true; ScreenGui2.ResetOnSpawn=false
    ScreenGui2.Name="STREE_KAITUN_BG"; ScreenGui2.Parent=game:GetService("CoreGui")
    Background2 = Instance.new("Frame",ScreenGui2)
    Background2.BackgroundColor3=Color3.new(0,0,0)
    Background2.BackgroundTransparency=0.5; Background2.Size=UDim2.new(1,0,1,0)
    for i=1,80 do
        local star=Instance.new("Frame"); star.Size=UDim2.new(0,math.random(3,5),0,math.random(3,5))
        star.Position=UDim2.new(math.random(),0,math.random(),0)
        star.BackgroundTransparency=1; star.Parent=Background2
        Instance.new("UICorner",star).CornerRadius=UDim.new(1,0)
        local glow=Instance.new("UIStroke",star); glow.Thickness=1
        glow.Color=Color3.fromRGB(0,255,0); glow.Transparency=math.random(40,80)/100
        task.spawn(function()
            TweenService:Create(glow,TweenInfo.new(math.random(2,4),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
                {Transparency=math.random(0,60)/100}):Play()
        end)
    end
    Saturn2=Instance.new("ImageLabel"); Saturn2.Image="rbxassetid://122683047852451"
    Saturn2.BackgroundTransparency=1; Saturn2.Size=UDim2.new(0,320,0,320)
    Saturn2.Position=UDim2.new(0.7,0,0.15,0); Saturn2.ImageTransparency=0.05; Saturn2.Parent=Background2
    task.spawn(function()
        while ScreenGui2 and _G.AutoFishingEnabled do
            for i=0,180,2 do if not ScreenGui2 then break end; Saturn2.Rotation=i; task.wait(0.02) end
            for i=180,0,-2 do if not ScreenGui2 then break end; Saturn2.Rotation=i; task.wait(0.02) end
        end
    end)
    SpaceSound2=Instance.new("Sound"); SpaceSound2.SoundId="rbxassetid://1846351427"
    SpaceSound2.Volume=0.2; SpaceSound2.Looped=true; SpaceSound2.Parent=SoundService; SpaceSound2:Play()
end

local function RemoveKaitunBackground()
    if SpaceSound2 then SpaceSound2:Stop(); SpaceSound2:Destroy(); SpaceSound2=nil end
    if ScreenGui2 then
        TweenService:Create(Background2,TweenInfo.new(1),{BackgroundTransparency=1}):Play()
        task.wait(1); ScreenGui2:Destroy(); ScreenGui2=nil
    end
end

-- =============================
--    NOCLIP (global loop)
-- =============================
task.spawn(function()
    while true do
        task.wait(0.05)
        if not _G.Noclip then continue end
        local c = LocalPlayer.Character
        if not c then continue end
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

-- =============================
--    INFINITE JUMP
-- =============================
UserInputService.JumpRequest:Connect(function()
    if _G.InfiniteJump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- =============================
--    WINDUI WINDOW
-- =============================
local Window = WindUI:CreateWindow({
    Title       = "MNA HUB",
    Icon        = "rbxassetid://111326404819563",
    Author      = "TehUniversal | MNA HUB",
    Folder      = "MNA HUB",
    Size        = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme       = "Dark",
    SideBarWidth= 170,
    HasOutline  = true,
})

Window:Tag({Title="V11.7", Color=Color3.fromRGB(0,255,0),   Radius=17})
Window:Tag({Title="Free",  Color=Color3.fromRGB(138,43,226), Radius=17})

WindUI:Notify({Title="MNA HUB",Content="UI loaded! & Script Redy.",Duration=4,Icon="anchor"})

-- ═══════════════════════════════════
--   TAB 1 — INFO
-- ═══════════════════════════════════
local Tab1 = Window:Tab({Title="Info", Icon="info"})
Tab1:Section({Title="Community Support", Icon="chevrons-left-right-ellipsis", TextXAlignment="Left", TextSize=17})
Tab1:Divider()
Tab1:Button({Title="Discord",Desc="click to copy link",Callback=function() if setclipboard then setclipboard("https://discord.gg/3gYxCfNTk") end end})
Tab1:Button({Title="WhatsApp",Desc="click to copy link",Callback=function() if setclipboard then setclipboard("https://chat.whatsapp.com/Cwmpd82iwOvJD5efDqqddg") end end})
Tab1:Button({Title="Telegram",Desc="click to copy link",Callback=function() if setclipboard then setclipboard("https://iamteh.github.io/TehUniversal.hub/") end end})
Tab1:Button({Title="Website",Desc="click to copy link",Callback=function() if setclipboard then setclipboard("https://iamteh.github.io/TehUniversal.hub/") end end})
Tab1:Divider()
Tab1:Paragraph({Title="Info Remote",Content="Loaded: "..loadedCount.." | Failed: "..failedCount})
Tab1:Button({
    Title=" Reload Remote",
    Callback=function()
        local l,f = loadRemotes()
        UB_init()
        NS("Remotes","Loaded: "..l.." | Failed: "..f)
    end
})
Tab1:Keybind({Title="Close/Open UI",Desc="Keybind Close/Open UI",Value="G",Callback=function(v) Window:SetToggleKey(Enum.KeyCode[v]) end})

-- ═══════════════════════════════════
--   TAB 2 — PLAYERS
-- ═══════════════════════════════════
local Tab2 = Window:Tab({Title="Players", Icon="user"})
Tab2:Slider({Title="Speed",Step=1,Value={Min=18,Max=300,Default=18},Callback=function(v)
    local hum=getHum(); if hum then hum.WalkSpeed=v end
end})
Tab2:Slider({Title="Jump",Step=1,Value={Min=50,Max=500,Default=50},Callback=function(v)
    local hum=getHum(); if hum then hum.UseJumpPower=true; hum.JumpPower=v end
end})
Tab2:Divider()
Tab2:Button({Title="Reset Jump Power",Desc="Kembali ke 50",Callback=function()
    _G.CustomJumpPower=50
    local hum=getHum(); if hum then hum.UseJumpPower=true; hum.JumpPower=50 end
    NS("Reset","Jump Power reset ke 50")
end})
Tab2:Button({Title="Reset Speed",Desc="Kembali ke 18",Callback=function()
    local hum=getHum(); if hum then hum.WalkSpeed=18 end
    NS("Reset","Speed reset ke 18")
end})
Tab2:Divider()
Tab2:Toggle({Title="Infinite Jump",Desc="Lompat tanpa batas",Default=false,Callback=function(v) _G.InfiniteJump=v end})
Tab2:Toggle({Title="Noclip",Desc="Tembus semua dinding",Default=false,Callback=function(v)
    _G.Noclip=v
    if not v then
        local c=LocalPlayer.Character
        if c then for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end end
    end
end})
Tab2:Toggle({Title="Freeze Character",Default=false,Callback=function(state)
    _G.FreezeCharacter=state
    local freezeConn2
    if state then
        local hrp=getHRP()
        if hrp then
            local frozenCF=hrp.CFrame
            freezeConn2=RunService.Heartbeat:Connect(function()
                if _G.FreezeCharacter and hrp then hrp.CFrame=frozenCF end
            end)
        end
    else
        if freezeConn2 then freezeConn2:Disconnect() end
    end
end})
Tab2:Divider()
-- MNA extras di Players
Tab2:Toggle({Title=" Walk on Water",Desc="Jalan di atas air",Default=false,Callback=function(v) setWalkOnWater(v) end})
Tab2:Toggle({Title=" Hide NameTag",Desc="Sembunyikan nama di atas kepala",Default=false,Callback=function(v) setHideNameTag(v) end})

-- ═══════════════════════════════════
--   TAB 3 — MAIN (FISHING)
-- ═══════════════════════════════════
local Tab3 = Window:Tab({Title="Main", Icon="anchor"})

-- === Section: Stree Auto Fishing ===
Tab3:Section({Title="Fishing (Stree Mode)", Icon="anchor", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
Tab3:Toggle({Title="Auto Equip Rod",Value=false,Callback=function(v) _G.AutoEquipRod=v; if v then rod() end end})

local fishMode = "Instant"
local fishThread, sellThread2

Tab3:Dropdown({Title="Mode",Values={"Instant","Legit"},Value="Instant",Callback=function(v)
    fishMode=v; WindUI:Notify({Title="Mode",Content="Mode: "..v,Duration=3})
end})

Tab3:Toggle({Title="Auto Fishing ",Value=false,Callback=function(v)
    _G.AutoFishing=v
    if v then
        if fishMode=="Instant" then
            if fishThread then fishThread=nil end
            fishThread=task.spawn(function()
                while _G.AutoFishing and fishMode=="Instant" do
                    safeCall("charge",function() net["RF/ChargeFishingRod"]:InvokeServer() end)
                    safeCall("lempar",function() net["RF/RequestFishingMinigameStarted"]:InvokeServer(-1.233,0.996,1761532005.497) end)
                    task.wait(_G.InstantDelay or 0.35)
                    safeCall("catch",function() net["RE/FishingCompleted"]:FireServer() end)
                    task.wait(_G.InstantDelay or 0.35)
                end
            end)
        else
            fishThread=task.spawn(function()
                while _G.AutoFishing and fishMode=="Legit" do autoon(); task.wait(1) end
            end)
        end
        WindUI:Notify({Title="Auto Fishing",Content=fishMode.." ON",Duration=3})
    else
        autooff(); _G.AutoFishing=false
        if fishThread then task.cancel(fishThread); fishThread=nil end
        WindUI:Notify({Title="Auto Fishing",Content="OFF",Duration=3})
    end
end})

Tab3:Slider({Title="Instant Fishing Delay",Step=0.01,Value={Min=0.2,Max=1,Default=0.35},Callback=function(v)
    _G.InstantDelay=v
end})

Tab3:Divider()
Tab3:Section({Title="Auto Sell", Icon="coins", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
Tab3:Toggle({Title="Auto Sell",Value=false,Callback=function(v)
    _G.AutoSell=v
    if v then
        if sellThread2 then task.cancel(sellThread2) end
        sellThread2=task.spawn(function()
            while _G.AutoSell do
                sell()
                local d=tonumber(_G.SellDelay) or 30
                local w=0; while w<d and _G.AutoSell do task.wait(0.25); w=w+0.25 end
            end
        end)
    else
        if sellThread2 then task.cancel(sellThread2); sellThread2=nil end
    end
end})
Tab3:Slider({Title="Sell Delay (detik)",Step=1,Value={Min=1,Max=120,Default=30},Callback=function(v) _G.SellDelay=v end})

Tab3:Divider()

-- === Section: MNA Ultra Blatant ===
Tab3:Section({Title="Blatant 3N", Icon="zap", TextXAlignment="Left", TextSize=17})
Tab3:Divider()

local rodSettings = {
    ["1. 3 Is real"]        = {CompleteDelay=2.7998},
    ["2. Blantant 3N"]       = {CompleteDelay=2.7988},
    ["3. DM/Element"]     = {CompleteDelay=2.890},
    ["4. GF/Bambu"]       = {CompleteDelay=3.7},
    ["5. 20Notif (Visual)"]= {CompleteDelay=4.8},
}
local rodNames = {}
for n in pairs(rodSettings) do table.insert(rodNames,n) end
table.sort(rodNames)

Tab3:Dropdown({Title="Template Rod",Values=rodNames,Value="2. Ultra 3N",Callback=function(v)
    local s=rodSettings[v]; if s then Config.UB.Settings.CompleteDelay=s.CompleteDelay end
end})

Tab3:Input({Title="Complete Delay",Placeholder=tostring(Config.UB.Settings.CompleteDelay),Callback=function(t)
    local n=tonumber(t)
    if n and n>=1 then Config.UB.Settings.CompleteDelay=n; NS("Delay","Set: "..n.."s")
    else NE("Delay","Minimal 1 detik!") end
end})

Tab3:Slider({Title="UB Notif",Value={Min=10,Max=50,Default=20},Step=1,Callback=function(v)
    Config.UBNotifDurationMult=v/10
end})

Tab3:Toggle({Title="Blatant ON/OFF",Desc="Ultra Blantant",Value=false,Callback=function(v)
    needCast=true; onToggleUB(v)
end})

Tab3:Toggle({Title="amBlantat (20N)",Desc="Replay visual",Value=false,Callback=function(v)
    Config.amblatant=v
    saveCount=0
    HookRemote("RE/FishCaught","FishCaught")
    HookRemote("RE/CaughtFishVisual","CaughtVisual")
    HookRemote("RE/ObtainedNewFishNotification","FishNotif")
    needCast=true
    if v then onToggleUB(true)
    else Config.amblatant=false; NW("amBlantat","Dimatikan.") end
end})

Tab3:Toggle({Title="Anti-Detect",Value=false,Callback=function(v) Config.antiOKOK=v end})

Tab3:Divider()
Tab3:Section({Title="Ub Config (amBlantat)", Icon="bell", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
Tab3:Slider({Title="Jumlah Notif per Catch",Value={Min=1,Max=20,Default=3},Step=1,Callback=function(v) Config.NotifCount=v end})
Tab3:Slider({Title="Delay Antar Notif (x0.01s)",Value={Min=0,Max=100,Default=10},Step=1,Callback=function(v) Config.NotifDelay=v/100 end})

Tab3:Divider()
Tab3:Section({Title="Legit Fishing", Icon="fish", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
Tab3:Toggle({Title="Legit Auto Catch",Value=false,Callback=function(v)
    Config.AutoCatch=v
    if v then equipRod(); CallRemote(Events.UpdateAutoFishing,true); NS("Legit","Aktif!")
    else CallRemote(Events.UpdateAutoFishing,false); NW("Legit","Dimatikan.") end
end})

Tab3:Divider()
Tab3:Section({Title="Auto Sell", Icon="coins", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
Tab3:Dropdown({Title="Metode Sell",Values={"Delay","Count"},Value="Delay",Callback=function(v)
    Config.AutoSellMethod=v; if Config.AutoSell then RunAutoSellLoop() end
end})
Tab3:Input({Title="Sell Value",Desc="Delay=detik | Count=jumlah catch",Placeholder="50",Callback=function(t)
    local n=tonumber(t); if n and n>0 then Config.AutoSellValue=n end
end})
Tab3:Toggle({Title="Auto Sell ON/OFF",Value=false,Callback=function(v)
    Config.AutoSell=v
    if v then RunAutoSellLoop(); NS("Auto Sell","Aktif! Mode: "..Config.AutoSellMethod)
    else if Tasks.AutoSellThread then pcall(function() task.cancel(Tasks.AutoSellThread) end) end
         NW("Auto Sell","Dimatikan.") end
end})
Tab3:Button({Title="Jual Semua Sekarang",Callback=function()
    if Events.sellRF then
        pcall(function() Events.sellRF:InvokeServer({}) end)
        NS("Sell","Semua ikan dijual!")
    else NE("Sell","Remote tidak ditemukan!") end
end})

Tab3:Divider()
Tab3:Section({Title="Auto Favorite", Icon="star", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
Tab3:Dropdown({Title="Filter Rarity",Values={"Common","Uncommon","Rare","Epic","Legendary","Mythic","SECRET"},Multi=true,Callback=function(v)
    Config.SelectedRarities=type(v)=="table" and v or (v~="" and {v} or {})
end})
Tab3:Dropdown({Title="Filter Mutation",Values={"Galaxy","Corrupt","Gemstone","Fairy Dust","Midnight","Holographic","Lightning","Radioactive","Ghost","Gold","Frozen","Shiny"},Multi=true,Callback=function(v)
    Config.SelectedMutations=type(v)=="table" and v or (v~="" and {v} or {})
end})
Tab3:Toggle({Title="Auto Favorite Ikan",Value=false,Callback=function(v)
    Config.AutoFavoriteState=v
    if v then
        Tasks.AutoFavoriteThread=task.spawn(function()
            while Config.AutoFavoriteState do RunAutoFavLoop(false); task.wait(5) end
        end)
        NS("Auto Favorite","Aktif!")
    else
        if Tasks.AutoFavoriteThread then pcall(function() task.cancel(Tasks.AutoFavoriteThread) end) end
        NW("Auto Favorite","Dimatikan.")
    end
end})

Tab3:Divider()
Tab3:Section({Title="Instant Bobber", Icon="zap", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
Tab3:Toggle({Title="Instant Bobber",Desc="Bobber langsung muncul saat cast",Value=false,Callback=function(v)
    Config.InstantBobber=v; patchInstantBobber(v)
    if v then NS("Instant Bobber","Aktif!") else NW("Instant Bobber","Dimatikan.") end
end})

Tab3:Divider()
Tab3:Section({Title="Item", Icon="grid-2x2-check", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
Tab3:Toggle({Title="Radar",Value=false,Callback=function(state)
    local RS2=game:GetService("ReplicatedStorage")
    local Lighting=game:GetService("Lighting")
    local ok2,Replion=pcall(function() return require(RS2.Packages.Replion).Client:GetReplion("Data") end)
    local ok3,NetFunction=pcall(function() return require(RS2.Packages.Net):RemoteFunction("UpdateFishingRadar") end)
    if ok2 and ok3 and Replion and NetFunction:InvokeServer(state) then
        local colorEffect=Lighting:FindFirstChildWhichIsA("ColorCorrectionEffect")
        if colorEffect then
            if state then colorEffect.TintColor=Color3.fromRGB(42,226,118); colorEffect.Brightness=0.4
            else colorEffect.TintColor=Color3.fromRGB(255,0,0); colorEffect.Brightness=0.2 end
        end
    end
end})
Tab3:Toggle({Title="Diving Gear",Desc="Oxygen Tank",Default=false,Callback=function(state)
    _G.DivingGear=state
    if state then pcall(function() net["RF/EquipOxygenTank"]:InvokeServer(105) end)
    else pcall(function() net["RF/UnequipOxygenTank"]:InvokeServer() end) end
end})

Tab3:Divider()
Tab3:Section({Title="Quest", Icon="scroll-text", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
-- Quest dari Stree (pertahankan utuh)
Tab3:Toggle({Title="Auto Notify Element Jungle",Default=false,Callback=function(v) _G.AutoNotifyEJ=v end})
Tab3:Toggle({Title="Auto Notify Quest",Default=false,Callback=function(v) _G.AutoNotifyQuest=v end})
Tab3:Button({Title="Element Jungle Quest",Desc="Check Progress",Callback=function()
    if _G.CheckEJ then _G.CheckEJ() end
end})
Tab3:Button({Title="Deep Sea Quest",Desc="Check Progress",Callback=function()
    if _G.CheckQuestProgress then _G.CheckQuestProgress() end
end})

task.spawn(function()
    local rs2=game:GetService("ReplicatedStorage")
    local ok1,QuestList=pcall(function() return require(rs2.Shared.Quests.QuestList) end)
    local ok2,QuestUtility=pcall(function() return require(rs2.Shared.Quests.QuestUtility) end)
    local ok3,Replion2=pcall(function() return require(rs2.Packages.Replion) end)
    if not (ok1 and ok2 and ok3) then return end
    local repl2=nil
    task.spawn(function() repl2=Replion2.Client:WaitReplion("Data") end)
    task.wait(3)
    _G.CheckEJ=function()
        if not repl2 then return end
        local data=repl2:Get(QuestList.ElementJungle.ReplionPath)
        if not data or not data.Available then WindUI:Notify({Title="EJ",Content="Data tidak ditemukan",Duration=4}); return end
        local quests=data.Available.Forever and data.Available.Forever.Quests or {}
        local done,total,list=0,#quests,""
        for _,q in ipairs(quests) do
            local info=QuestUtility:GetQuestData("ElementJungle","Forever",q.QuestId)
            if info then
                local maxVal=QuestUtility.GetQuestValue(repl2,info)
                local pct=math.floor(math.clamp(q.Progress/maxVal,0,1)*100)
                if pct>=100 then done=done+1 end
                list=list..info.DisplayName.." - "..pct.."%\n"
            end
        end
        WindUI:Notify({Title="Element Jungle",Content="Total: "..math.floor((done/math.max(total,1))*100).."%\n\n"..list,Duration=7,Icon="leaf"})
    end
    _G.CheckQuestProgress=function()
        if not repl2 then return end
        local data=repl2:Get(QuestList.DeepSea.ReplionPath)
        if not data or not data.Available then WindUI:Notify({Title="Deep Sea",Content="Data tidak ditemukan",Duration=4}); return end
        local quests=data.Available.Forever and data.Available.Forever.Quests or {}
        local done,total,list=0,#quests,""
        for _,q in ipairs(quests) do
            local info=QuestUtility:GetQuestData("DeepSea","Forever",q.QuestId)
            if info then
                local maxVal=QuestUtility.GetQuestValue(repl2,info)
                local pct=math.floor(math.clamp(q.Progress/maxVal,0,1)*100)
                if pct>=100 then done=done+1 end
                list=list..info.DisplayName.." - "..pct.."%\n"
            end
        end
        WindUI:Notify({Title="Deep Sea",Content="Total: "..math.floor((done/math.max(total,1))*100).."%\n\n"..list,Duration=7,Icon="check-circle"})
    end
    task.spawn(function()
        while task.wait(5) do
            if _G.AutoNotifyEJ and _G.CheckEJ then _G.CheckEJ() end
            if _G.AutoNotifyQuest and _G.CheckQuestProgress then _G.CheckQuestProgress() end
        end
    end)
end)

Tab3:Divider()
Tab3:Section({Title="Gameplay", Icon="gamepad", TextXAlignment="Left", TextSize=17})
Tab3:Divider()
Tab3:Toggle({Title="FPS Boost",Default=false,Callback=function(state)
    local Lighting=game:GetService("Lighting")
    local Terrain=workspace:FindFirstChildOfClass("Terrain")
    if state then
        if not _G.OldSettings then
            _G.OldSettings={GlobalShadows=Lighting.GlobalShadows,FogEnd=Lighting.FogEnd,
                Brightness=Lighting.Brightness,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient}
        end
        Lighting.GlobalShadows=false; Lighting.FogEnd=1e10; Lighting.Brightness=1
        Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then v.CastShadow=false
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=false end
        end
    else
        if _G.OldSettings then
            Lighting.GlobalShadows=_G.OldSettings.GlobalShadows; Lighting.FogEnd=_G.OldSettings.FogEnd
            Lighting.Brightness=_G.OldSettings.Brightness; Lighting.Ambient=_G.OldSettings.Ambient
            Lighting.OutdoorAmbient=_G.OldSettings.OutdoorAmbient
        end
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=true
            elseif v:IsA("BasePart") then v.CastShadow=true end
        end
    end
end})

Tab3:Toggle({Title="Disable Obtained",Desc="",Value=false,Callback=function(v) setDisableObtained(v) end})

-- ═══════════════════════════════════
--   TAB 4 — MNA EXTRAS (BARU)
-- ═══════════════════════════════════
local Tab4 = Window:Tab({Title="Animation", Icon="sparkles"})

Tab4:Section({Title="Custom Skin Animation", Icon="sparkles", TextXAlignment="Left", TextSize=17})
Tab4:Divider()
Tab4:Paragraph({Title="Info",Content="Override animasi saat FishCaught dengan skin rod custom."})

local ubSkinNames={"Eclipse","HolyTrident","SoulScythe","OceanicHarpoon","BinaryEdge","Vanquisher","KrampusScythe","BanHammer","CorruptionEdge","PrincessParasol"}

Tab4:Dropdown({Title="Pilih Skin Animation",Values=ubSkinNames,Value="Eclipse",Callback=function(v)
    Config.SelectedSkinId=v; SkinAnimation.Switch(v)
end})
Tab4:Toggle({Title="Enable Skin Animation",Value=false,Callback=function(v)
    Config.SkinAnimEnabled=v
    if v then SkinAnimation.Switch(Config.SelectedSkinId); SkinAnimation.Enable(); NS("Skin Anim",Config.SelectedSkinId.." aktif!")
    else SkinAnimation.Disable(); NW("Skin Anim","Dimatikan.") end
end})

Tab4:Divider()
Tab4:Section({Title="Auto Enchant", Icon="sparkles", TextXAlignment="Left", TextSize=17})
Tab4:Divider()
Tab4:Dropdown({Title="Stone Type",Values={"Enchant Stones","Evolved Enchant Stone"},Value="Enchant Stones",Callback=function(v) _G.SelectedStoneType=v end})
Tab4:Toggle({Title="Auto Enchant",Desc="Auto equip stone + aktifkan altar",Value=false,Callback=function(v)
    _G.AutoEnchant=v
    if v then
        task.spawn(function()
            while _G.AutoEnchant do
                pcall(function()
                    local stones=findEnchantStones()
                    if #stones>0 and Events.equipItem and Events.activateAltar then
                        pcall(function() Events.equipItem:FireServer(stones[1].UUID,"Enchant Stones") end)
                        task.wait(1.5)
                        pcall(function() Events.activateAltar:FireServer() end)
                    end
                end)
                task.wait(2)
            end
        end)
        NS("Auto Enchant","Aktif!")
    else NW("Auto Enchant","Dimatikan.") end
end})
Tab4:Button({Title="Double Enchant (1x)",Desc="Equip stone → hotbar → altar",Callback=function()
    task.spawn(function()
        if not Events.activateAltar then NE("Double Enchant","Remote altar tidak ditemukan!"); return end
        local stones=findEnchantStones()
        if #stones==0 then NE("Double Enchant","Stone tidak ada!"); return end
        if Events.equipItem then pcall(function() Events.equipItem:FireServer(stones[1].UUID,"Enchant Stones") end) end
        task.wait(1.2)
        if Events.equip then pcall(function() CallRemote(Events.equip,1) end) end
        task.wait(0.8)
        pcall(function() Events.activateAltar:FireServer() end)
        NS("Double Enchant","Selesai!")
    end)
end})
Tab4:Button({Title="Fix Rod",Desc="Reset rod jika tidak bisa ganti",Callback=function()
    if Events.CancelFishing then pcall(function() CallRemote(Events.CancelFishing) end); NS("Fix Rod","Reset!") end
end})

Tab4:Divider()
Tab4:Section({Title="Cave & Pirate", Icon="map", TextXAlignment="Left", TextSize=17})
Tab4:Divider()
Tab4:Button({Title="Buka Cave Wall",Desc="TNT x4 + GainAccessToMaze",Callback=function()
    task.spawn(function()
        if not Events.searchItemPickedUp or not Events.gainAccessToMaze then NE("Cave","Remote tidak ditemukan!"); return end
        for i=1,4 do pcall(function() Events.searchItemPickedUp:FireServer("TNT") end); task.wait(0.7) end
        task.wait(1.5)
        pcall(function() Events.gainAccessToMaze:FireServer() end)
        NS("Cave","Wall dibuka!")
    end)
end})
Tab4:Toggle({Title="Auto Claim Pirate Chest",Value=false,Callback=function(v)
    _G.AutoPirateChest=v
    if v then
        task.spawn(function()
            while _G.AutoPirateChest do
                pcall(function()
                    if not Events.claimPirateChest then return end
                    local storage=workspace:FindFirstChild("PirateChestStorage")
                    if not storage then return end
                    local found=0
                    for _, chest in ipairs(storage:GetChildren()) do
                        if chest.Name:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") then
                            pcall(function() Events.claimPirateChest:FireServer(chest.Name) end)
                            found=found+1; task.wait(0.5)
                        end
                    end
                    if found>0 then NS("Pirate","Claim "..found.." chest!") end
                end)
                task.wait(3)
            end
        end)
        NS("Pirate","Auto claim aktif!")
    else NW("Pirate","Dimatikan.") end
end})

Tab4:Divider()
Tab4:Section({Title="Cave Crystal", Icon="gem", TextXAlignment="Left", TextSize=17})
Tab4:Divider()
Tab4:Button({Title="Konsumsi Crystal",Callback=function()
    if Events.ConsumeCaveCrystal then
        pcall(function() Events.ConsumeCaveCrystal:InvokeServer() end)
        task.wait(1.5); equipRod()
        NS("Crystal","Dikonsumsi!")
    else NE("Crystal","Remote tidak ditemukan!") end
end})
Tab4:Toggle({Title="Auto Crystal (tiap 30 menit)",Value=false,Callback=function(v)
    _G.AutoCrystal=v
    if v then
        if not Events.ConsumeCaveCrystal then NE("Crystal","Remote tidak ditemukan!"); return end
        _G.crystalTask=task.spawn(function()
            while _G.AutoCrystal do
                pcall(function() Events.ConsumeCaveCrystal:InvokeServer(); task.wait(1.5); equipRod() end)
                task.wait(1800)
            end
        end)
        NS("Crystal","Auto setiap 30 menit!")
    else
        if _G.crystalTask then pcall(function() task.cancel(_G.crystalTask) end) end
        NW("Crystal","Dimatikan.")
    end
end})

Tab4:Divider()
Tab4:Section({Title="Totem", Icon="triangle", TextXAlignment="Left", TextSize=17})
Tab4:Divider()
local totemData2={["Luck Totem"]=1,["Mutation Totem"]=2,["Shiny Totem"]=3,["Love Totem"]=5}
Tab4:Dropdown({Title="Pilih Totem",Values={"Luck Totem","Mutation Totem","Shiny Totem","Love Totem"},Value="Luck Totem",Callback=function(v)
    Config.SelectedTotemID=totemData2[v] or 0
end})
Tab4:Toggle({Title="Auto Spawn Totem (1 jam)",Value=false,Callback=function(v)
    Config.AutoTotem=v
    if v then
        Tasks.totemTask=task.spawn(function()
            while Config.AutoTotem do
                pcall(function()
                    local totemUUID=nil
                    pcall(function()
                        local Replion3=require(ReplicatedStorage.Packages.Replion).Client:WaitReplion("Data",5)
                        if not Replion3 then return end
                        local inv=Replion3:GetExpect("Inventory")
                        if inv and inv.Totems then
                            for _,item in ipairs(inv.Totems) do
                                if Config.SelectedTotemID==0 or item.Id==Config.SelectedTotemID then
                                    totemUUID=item.UUID; break
                                end
                            end
                        end
                    end)
                    if totemUUID and Events.SpawnTotem then
                        pcall(function() Events.SpawnTotem:FireServer(totemUUID) end)
                        task.wait(3); equipRod()
                        NS("Totem","Spawn! Cooldown 1 jam.")
                    end
                end)
                task.wait(3600)
            end
        end)
        NS("Auto Totem","Aktif!")
    else
        if Tasks.totemTask then pcall(function() task.cancel(Tasks.totemTask) end) end
        NW("Auto Totem","Dimatikan.")
    end
end})

-- ═══════════════════════════════════
--   TAB 5 — EXCLUSIVE (Kaitun)
-- ═══════════════════════════════════
local Tab5 = Window:Tab({Title="Exclusive", Icon="star"})
Tab5:Section({Title="Kaitun System", Icon="antenna", TextXAlignment="Left", TextSize=17})
Tab5:Divider()

local REEquipTool2   = net["RE/EquipToolFromHotbar"]
local REFishComplete = net["RE/FishingCompleted"]
_G.AutoFishingEnabled=false

Tab5:Toggle({Title="Enable Kaitun",Desc="Auto fishing system visual",Default=false,Callback=function(state)
    _G.AutoFishingEnabled=state
    if state then
        CreateKaitunBackground()
        NS("Kaitun","Activated!")
        task.spawn(function()
            while _G.AutoFishingEnabled do
                pcall(function()
                    REEquipTool2:FireServer(1)
                    local clickX=5; local clickY=Camera.ViewportSize.Y-5
                    VirtualInputManager:SendMouseButtonEvent(clickX,clickY,0,true,game,0)
                    task.wait(Config.FishingDelay or 0.5)
                    VirtualInputManager:SendMouseButtonEvent(clickX,clickY,0,false,game,0)
                    REFishComplete:FireServer()
                    if _G.AutoSellFish then
                        for _,v in pairs(ReplicatedStorage:GetDescendants()) do
                            if v:IsA("RemoteEvent") and v.Name:lower():find("sell") then
                                pcall(function() v:FireServer() end)
                            end
                        end
                    end
                end)
                task.wait(Config.FishingDelay or 0.5)
                RunService.Heartbeat:Wait()
            end
        end)
    else
        RemoveKaitunBackground()
        NW("Kaitun","Stopped.")
    end
end})
Tab5:Toggle({Title="Auto Sell Fish",Default=true,Callback=function(v) _G.AutoSellFish=v end})
Tab5:Slider({Title="Fishing Delay",Min=0.2,Max=2,Default=0.5,Callback=function(v) Config.FishingDelay=v end})

-- ═══════════════════════════════════
--   TAB 6 — SHOP
-- ═══════════════════════════════════
local Tab6 = Window:Tab({Title="Shop", Icon="badge-dollar-sign"})

Tab6:Section({Title="Buy Rod", Icon="shrimp", TextXAlignment="Left", TextSize=17})
Tab6:Divider()

local RFRod = net["RF/PurchaseFishingRod"]
local rods={["Luck Rod"]=79,["Carbon Rod"]=76,["Grass Rod"]=85,["Demascus Rod"]=77,["Ice Rod"]=78,["Lucky Rod"]=4,["Midnight Rod"]=80,["Steampunk Rod"]=6,["Chrome Rod"]=7,["Astral Rod"]=5,["Ares Rod"]=126,["Angler Rod"]=168,["Bamboo Rod"]=258}
local rodDisplayNames={"Luck Rod (350)","Carbon Rod (900)","Grass Rod (1.5k)","Demascus Rod (3k)","Ice Rod (5k)","Lucky Rod (15k)","Midnight Rod (50k)","Steampunk Rod (215k)","Chrome Rod (437k)","Astral Rod (1M)","Ares Rod (3M)","Angler Rod (8M)","Bamboo Rod (12M)"}
local rodKeyMap2={["Luck Rod (350)"]="Luck Rod",["Carbon Rod (900)"]="Carbon Rod",["Grass Rod (1.5k)"]="Grass Rod",["Demascus Rod (3k)"]="Demascus Rod",["Ice Rod (5k)"]="Ice Rod",["Lucky Rod (15k)"]="Lucky Rod",["Midnight Rod (50k)"]="Midnight Rod",["Steampunk Rod (215k)"]="Steampunk Rod",["Chrome Rod (437k)"]="Chrome Rod",["Astral Rod (1M)"]="Astral Rod",["Ares Rod (3M)"]="Ares Rod",["Angler Rod (8M)"]="Angler Rod",["Bamboo Rod (12M)"]="Bamboo Rod"}
local selRod=rodDisplayNames[1]
Tab6:Dropdown({Title="Select Rod",Values=rodDisplayNames,Value=selRod,Callback=function(v) selRod=v end})
Tab6:Button({Title="Buy Rod",Callback=function()
    local key=rodKeyMap2[selRod]
    if key and rods[key] then
        local ok2,err=pcall(function() RFRod:InvokeServer(rods[key]) end)
        if ok2 then NS("Rod","Purchased "..selRod) else NE("Rod",tostring(err)) end
    end
end})

Tab6:Divider()
Tab6:Section({Title="Buy Bait", Icon="compass", TextXAlignment="Left", TextSize=17})
Tab6:Divider()
local RFBait=net["RF/PurchaseBait"]
local baits={["Luck Bait"]=2,["Midnight Bait"]=3,["Chroma Bait"]=6,["Dark Matter Bait"]=8,["Corrupt Bait"]=15,["Aether Bait"]=16,["Floral Bait"]=20}
local baitDisplay={"Luck Bait (1k)","Midnight Bait (3k)","Chroma Bait (290k)","Dark Matter Bait (630k)","Corrupt Bait (1.15M)","Aether Bait (3.7M)","Floral Bait (4M)"}
local baitKeyMap2={["Luck Bait (1k)"]="Luck Bait",["Midnight Bait (3k)"]="Midnight Bait",["Chroma Bait (290k)"]="Chroma Bait",["Dark Matter Bait (630k)"]="Dark Matter Bait",["Corrupt Bait (1.15M)"]="Corrupt Bait",["Aether Bait (3.7M)"]="Aether Bait",["Floral Bait (4M)"]="Floral Bait"}
local selBait=baitDisplay[1]
Tab6:Dropdown({Title="Select Bait",Values=baitDisplay,Value=selBait,Callback=function(v) selBait=v end})
Tab6:Button({Title="Buy Bait",Callback=function()
    local key=baitKeyMap2[selBait]
    if key and baits[key] then
        local ok2,err=pcall(function() RFBait:InvokeServer(baits[key]) end)
        if ok2 then NS("Bait","Purchased "..selBait) else NE("Bait",tostring(err)) end
    end
end})

Tab6:Divider()
Tab6:Section({Title="Buy Weather", Icon="cloud-rain", TextXAlignment="Left", TextSize=17})
Tab6:Divider()
local RFWeather=net["RF/PurchaseWeatherEvent"]
local weatherMap2={["Wind (10k)"]="Wind",["Snow (15k)"]="Snow",["Cloudy (20k)"]="Cloudy",["Storm (35k)"]="Storm",["Radiant (50k)"]="Radiant",["Shark Hunt (300k)"]="Shark Hunt"}
local weatherDisplay2={"Wind (10k)","Snow (15k)","Cloudy (20k)","Storm (35k)","Radiant (50k)","Shark Hunt (300k)"}
local selWeathers2={}
local autoBuyWx=false
Tab6:Dropdown({Title="Select Weather",Values=weatherDisplay2,Multi=true,Callback=function(v) selWeathers2=v end})
Tab6:Toggle({Title="Buy Weather Event",Value=false,Callback=function(v)
    autoBuyWx=v
    if v then
        task.spawn(function()
            while autoBuyWx do
                for _,name in ipairs(selWeathers2) do
                    local key=weatherMap2[name]
                    if key then pcall(function() RFWeather:InvokeServer(key) end); task.wait(0.5) end
                end
                task.wait(0.1)
            end
        end)
    end
end})

-- ═══════════════════════════════════
--   TAB 7 — TELEPORT
-- ═══════════════════════════════════
local Tab7 = Window:Tab({Title="Teleport", Icon="map-pin"})

Tab7:Section({Title="Island", Icon="tree-palm", TextXAlignment="Left", TextSize=17})
Tab7:Divider()

local IslandLocations={
    ["Admin Event"]=Vector3.new(-1981,-442,7428),["Ancient Jungle"]=Vector3.new(1518,1,-186),
    ["Coral Refs"]=Vector3.new(-2855,47,1996),["Crater Island"]=Vector3.new(997,1,5012),
    ["Crystal Cavern"]=Vector3.new(-1841,-456,7186),["Enchant Room"]=Vector3.new(3221,-1303,1406),
    ["Enchant Room 2"]=Vector3.new(1480,126,-585),["Esoteric Island"]=Vector3.new(1990,5,1398),
    ["Fisherman Island"]=Vector3.new(-175,3,2772),["Halloween"]=Vector3.new(2106,81,3295),
    ["Kohana Volcano"]=Vector3.new(-545,17,118),["Konoha"]=Vector3.new(-603,3,719),
    ["Lost Isle"]=Vector3.new(-3643,1,-1061),["Sacred Temple"]=Vector3.new(1498,-23,-644),
    ["Sisyphus Statue"]=Vector3.new(-3783,-135,-949),["Treasure Room"]=Vector3.new(-3600,-267,-1575),
    ["Tropical Grove"]=Vector3.new(-2091,6,3703),["Underground Cellar"]=Vector3.new(2135,-93,-701),
    ["Weather Machine"]=Vector3.new(-1508,6,1895),
    ["Megalodon"]=Vector3.new(-1172,7,3620),["Pirate Cove"]=Vector3.new(3396,4,3469),
    ["Pirate Treasure Room"]=Vector3.new(3324,-306,3087),["Planetary Observatory"]=Vector3.new(420,3,2183),
    ["Easter Cove"]=Vector3.new(487,4,1183),["Easter Island"]=Vector3.new(520,5,1250),
}

local islandKeys={}
for n in pairs(IslandLocations) do table.insert(islandKeys,n) end
table.sort(islandKeys)

local selIsland=islandKeys[1]
Tab7:Dropdown({Title="Select Island",Values=islandKeys,Callback=function(v) selIsland=v end})
Tab7:Button({Title="Teleport to Island",Callback=function()
    if selIsland and IslandLocations[selIsland] then
        local hrp=getHRP()
        if hrp then hrp.CFrame=CFrame.new(IslandLocations[selIsland]+Vector3.new(0,3,0)); NS("TP","Berhasil ke "..selIsland) end
    end
end})

Tab7:Divider()
Tab7:Section({Title="Fishing Spot", Icon="spotlight", TextXAlignment="Left", TextSize=17})
Tab7:Divider()
local FishingLocations={
    ["Coral Refs"]=Vector3.new(-2855,47,1996),["Konoha"]=Vector3.new(-603,3,719),
    ["Levers 1"]=Vector3.new(1475,4,-847),["Levers 2"]=Vector3.new(882,5,-321),
    ["levers 3"]=Vector3.new(1425,6,126),["levers 4"]=Vector3.new(1837,4,-309),
    ["Sacred Temple"]=Vector3.new(1475,-22,-632),["Spawn"]=Vector3.new(33,9,2810),
    ["Sisyphus Statue"]=Vector3.new(-3693,-136,-1045),["Underground Cellar"]=Vector3.new(2135,-92,-695),
    ["Volcano"]=Vector3.new(-632,55,197),
}
local fishKeys={}
for n in pairs(FishingLocations) do table.insert(fishKeys,n) end
table.sort(fishKeys)
local selFish=fishKeys[1]
Tab7:Dropdown({Title="Select Spot",Values=fishKeys,Callback=function(v) selFish=v end})
Tab7:Button({Title=" TP to Fishing Spot",Callback=function()
    if selFish and FishingLocations[selFish] then
        local hrp=getHRP(); if hrp then hrp.CFrame=CFrame.new(FishingLocations[selFish]); NS("TP","Berhasil ke "..selFish) end
    end
end})

Tab7:Divider()
Tab7:Section({Title="NPC Location", Icon="bot", TextXAlignment="Left", TextSize=17})
Tab7:Divider()
local NPC_Loc={
    ["Alex"]=Vector3.new(43,17,2876),["Aura kid"]=Vector3.new(70,17,2835),
    ["Billy Bob"]=Vector3.new(84,17,2876),["Boat Expert"]=Vector3.new(32,9,2789),
    ["Jeffery"]=Vector3.new(-2771,4,2132),["Joe"]=Vector3.new(144,20,2856),
    ["Jones"]=Vector3.new(-671,16,596),["Lava Fisherman"]=Vector3.new(-593,59,130),
    ["Ron"]=Vector3.new(-48,17,2856),["Scott"]=Vector3.new(-19,9,2709),
    ["Seth"]=Vector3.new(107,17,2877),["Tim"]=Vector3.new(-604,16,609),
}
local npcKeys={}
for n in pairs(NPC_Loc) do table.insert(npcKeys,n) end
table.sort(npcKeys)
local selNPC=npcKeys[1]
Tab7:Dropdown({Title="Select NPC",Values=npcKeys,Callback=function(v) selNPC=v end})
Tab7:Button({Title="TP to NPC",Callback=function()
    if selNPC and NPC_Loc[selNPC] then
        local hrp=getHRP(); if hrp then hrp.CFrame=CFrame.new(NPC_Loc[selNPC]); NS("TP","Berhasil ke "..selNPC) end
    end
end})

Tab7:Divider()
Tab7:Section({Title="Event Teleporter", Icon="calendar", TextXAlignment="Left", TextSize=17})
Tab7:Divider()

local eventNames2={}
for n in pairs(eventTPData) do table.insert(eventNames2,n) end
table.sort(eventNames2)

Tab7:Dropdown({Title="Select Events",Values=eventNames2,Multi=true,AllowNone=true,Callback=function(v)
    selectedAutoEvents=v
end})
Tab7:Toggle({Title="Auto Event Teleport",Desc="TP otomatis ke event platform (Worm/Meg/Shark/Thunder)",Value=false,Callback=function(v)
    autoEventTPEnabled=v
    if v then
        if #selectedAutoEvents==0 then NE("Event TP","Pilih event dulu!"); autoEventTPEnabled=false; return end
        if autoEventThread then pcall(function() task.cancel(autoEventThread) end) end
        autoEventThread=task.spawn(runAutoEventTP)
        NS("Event TP","Aktif! Mencari event...")
    else
        destroyEventPlatform()
        if autoEventThread then pcall(function() task.cancel(autoEventThread) end); autoEventThread=nil end
        NW("Event TP","Dimatikan.")
    end
end})

Tab7:Divider()
Tab7:Toggle({Title="Auto Leviathan Hunt TP",Value=false,Callback=function(v)
    _G.AutoLev=v
    if v then
        local hasTP=false
        Tasks.levTask=task.spawn(function()
            while _G.AutoLev do
                pcall(function()
                    local zones=workspace:FindFirstChild("Zones")
                    if zones then
                        local den=zones:FindFirstChild("Leviathan's Den")
                        if den and not hasTP then
                            local hrp=getHRP()
                            if hrp then hrp.CFrame=CFrame.new(3474.053,-287.775,3472.634); hasTP=true; NS("Leviathan","TP ke Den!") end
                        elseif not den then hasTP=false end
                    end
                end)
                task.wait(5)
            end
        end)
        NS("Leviathan","Mencari zona...")
    else
        if Tasks.levTask then pcall(function() task.cancel(Tasks.levTask) end) end
        NW("Leviathan","Dimatikan.")
    end
end})

-- ═══════════════════════════════════
--   TAB 8 — SETTINGS
-- ═══════════════════════════════════
local Tab8 = Window:Tab({Title="Settings", Icon="settings"})

Tab8:Toggle({Title="AntiAFK",Desc="Prevent kick saat idle",Default=false,Callback=function(state)
    _G.AntiAFK=state
    local VU=game:GetService("VirtualUser")
    if state then
        task.spawn(function()
            while _G.AntiAFK do
                task.wait(60)
                pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end)
            end
        end)
    end
end})

Tab8:Toggle({Title="Auto Reconnect",Desc="Auto reconnect jika disconnect",Default=false,Callback=function(state)
    _G.AutoReconnect=state
    if state then
        task.spawn(function()
            while _G.AutoReconnect do
                task.wait(2)
                local reconnectUI=game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui")
                if reconnectUI then
                    local prompt=reconnectUI:FindFirstChild("promptOverlay")
                    if prompt then
                        local btn=prompt:FindFirstChild("ButtonPrimary")
                        if btn and btn.Visible then pcall(function() firesignal(btn.MouseButton1Click) end) end
                    end
                end
            end
        end)
    end
end})

Tab8:Divider()
Tab8:Section({Title="Ping Panel", Icon="bar-chart", TextXAlignment="Left", TextSize=17})
Tab8:Divider()
Tab8:Toggle({Title="Ping Panel",Desc="Ping + FPS realtime di pojok kanan atas",Value=false,Callback=function(v)
    if v then createPingPanel(); NS("Ping Panel","Aktif!") else destroyPingPanel(); NW("Ping Panel","Disembunyikan.") end
end})
Tab8:Button({Title="Cek FPS & Ping",Callback=function()
    local frames=0; local conn
    conn=RunService.RenderStepped:Connect(function() frames=frames+1 end)
    task.wait(1); conn:Disconnect()
    local ping=0; pcall(function() ping=math.floor(LocalPlayer:GetNetworkPing()*1000) end)
    local icon=ping<80 and "🟢" or ping<150 and "🟡" or "🔴"
    NI("Stats",icon.." Ping: "..ping.."ms | FPS: "..frames)
end})

Tab8:Divider()
Tab8:Section({Title="Webhook Discord", Icon="webhook", TextXAlignment="Left", TextSize=17})
Tab8:Divider()
Tab8:Toggle({Title="Aktifkan Webhook",Value=false,Callback=function(v) Config.CustomWebhook=v end})
Tab8:Input({Title="URL Webhook",Placeholder="https://discord.com/api/webhooks/...",Callback=function(v)
    if not v or v=="" then NE("Webhook","URL kosong!"); return end
    Config.CustomWebhookUrl=v; NS("Webhook","URL disimpan!")
end})

Tab8:Divider()
Tab8:Section({Title="Server", Icon="server", TextXAlignment="Left", TextSize=17})
Tab8:Divider()
Tab8:Button({Title="Rejoin Server",Callback=function()
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId,LocalPlayer)
end})
Tab8:Button({Title="Server Hop",Callback=function()
    local ok2,servers=pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100"))
    end)
    if not ok2 or not servers or not servers.data then NE("Hop","Gagal!"); return end
    for _,s in ipairs(servers.data) do
        if s.playing<s.maxPlayers and s.id~=game.JobId then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,s.id,LocalPlayer)
            return
        end
    end
    NW("Hop","Tidak ada server lain.")
end})

Tab8:Divider()
Tab8:Section({Title="Other Scripts", Icon="file-code-2", TextXAlignment="Left", TextSize=17})
Tab8:Divider()
Tab8:Button({Title="FLY",Callback=function() loadstring(game:HttpGet("https://raw.githubusercontent.com/XNEOFF/FlyGuiV3/main/FlyGuiV3.txt"))() end})
Tab8:Button({Title="Simple Shader",Callback=function() loadstring(game:HttpGet("https://raw.githubusercontent.com/p0e1/1/refs/heads/main/SimpleShader.lua"))() end})
Tab8:Button({Title="Infinite Yield",Callback=function() loadstring(game:HttpGet("https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua"))() end})

-- =============================
--    NOTIF AKHIR
-- =============================
task.wait(0.5)
WindUI:Notify({
    Title   = "MNA HUB",
    Content = "MNA COMUNITY.",
    Duration = 5,
    Icon    = "check-circle",
})
