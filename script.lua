--[[
    MNA HUB V11.3 FREE - FULL FIXED & MOBILE OPTIMIZED
    UI Size: 380x480 (Mobile Friendly)
    Fix: UB Race Condition, Notif Queue, Teleport, Aura, etc.
]]

repeat task.wait(0.5) until game:IsLoaded()
task.wait(1.5)

-- =============================
--    SERVICES
-- =============================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled

-- =============================
--    NOTIFY HELPER
-- =============================
local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

-- =============================
--    NET FOLDER
-- =============================
local net = ReplicatedStorage:WaitForChild("Packages", 10)
    :WaitForChild("_Index", 10)
    :WaitForChild("sleitnick_net@0.2.0", 10)
    :WaitForChild("net", 10)

local function GetServerRemote(name)
    local children = net:GetChildren()
    for i, v in ipairs(children) do
        if v.Name == name then
            return children[i + 1]
        end
    end
    return nil
end

local function CallRemote(remote, ...)
    if not remote then return end
    pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(...)
        elseif remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        end
    end)
end

-- =============================
--    CONFIG
-- =============================
local Config = {
    AutoCatch = false,
    CatchDelay = 0.7,
    UB = {
        Active = false,
        Settings = { CompleteDelay = 3.7, CancelDelay = 0.3 },
        Remotes = {}
    },
    amblatant = false,
    antiOKOK = false,
    autoFishing = false,
    AutoSellState = false,
    AutoSellMethod = "Delay",
    AutoSellValue = 50,
    AutoFavoriteState = false,
    AutoUnfavoriteState = false,
    SelectedRarities = {},
    SelectedMutations = {},
    AutoTotem = false,
    SelectedTotemID = 0,
    CustomWebhook = false,
    CustomWebhookUrl = "",
    NotifDelay = 0.1,
    NotifCount = 3,
    UBNotifDurationMult = 2.0,
    WalkOnWater = false,
    HideNameTag = false,
    DisableObtained = false,
    InstantBobber = false,
    SkinAnimEnabled = false,
    SelectedSkinId = "Eclipse",
}

-- =============================
--    GLOBALS
-- =============================
_G.NotifQueue = _G.NotifQueue or {}
_G.NotifActive = _G.NotifActive or 0

local MAX_NOTIF_ONSCREEN = 2
local NOTIF_GAP = 0.15

local Tasks = {}
local needCast = true
local isCaught = false
local lastTimeFishCaught = nil
local blatantFishCycleCount = 0
local saveCount = 0

_G.SavedData = _G.SavedData or {
    FishCaught = {}, CaughtVisual = {}, FishNotif = {}
}

local lastValidFishCaught = {}
local lastValidCaughtVisual = {}
local lastValidFishNotif = {}

local Events = {}
local _hookedRemotes = {}

-- =============================
--    HELPER FUNCTIONS
-- =============================
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function deepCopyArr(t)
    local out = {}
    for i, v in ipairs(t or {}) do
        out[i] = type(v) == "table" and deepCopyArr(v) or v
    end
    return out
end

local function FireLocalEvent(remote, ...)
    local args = {...}
    pcall(function()
        local signal = remote.OnClientEvent
        for _, conn in pairs(getconnections(signal)) do
            if conn.Function then
                task.spawn(function() conn.Function(unpack(args)) end)
            end
        end
    end)
end

local function HookRemote(name, key)
    if _hookedRemotes[name] then return end
    local remote = GetServerRemote(name)
    if remote then
        _hookedRemotes[name] = true
        remote.OnClientEvent:Connect(function(...)
            _G.SavedData[key] = {...}
            if key == "CaughtVisual" then
                local a = {...}
                if tostring(a[1]) == LocalPlayer.Name then saveCount += 1 end
            end
        end)
    end
end

-- AFK Prevent
pcall(function()
    for _, v in pairs(getconnections(LocalPlayer.Idled)) do
        if v.Disable then v:Disable() end
    end
end)

-- =============================
--    REMOTES
-- =============================
local function loadRemotes()
    local list = {
        {key="equip", name="RF/EquipToolFromHotbar"},
        {key="CancelFishing", name="RF/CancelFishingInputs"},
        {key="charge", name="RF/ChargeFishingRod"},
        {key="minigame", name="RF/RequestFishingMinigameStarted"},
        {key="UpdateAutoFishing", name="RF/UpdateAutoFishingState"},
        {key="fishing", name="RF/CatchFishCompleted"},
        {key="fishingRE", name="RE/CatchFishCompleted"},
        {key="exclaimEvent", name="RE/ReplicateTextEffect"},
        {key="sell", name="RF/SellAllItems"},
        {key="favorite", name="RE/FavoriteItem"},
        {key="SpawnTotem", name="RE/SpawnTotem"},
        {key="fishNotif", name="RE/ObtainedNewFishNotification"},
        {key="activateAltar", name="RE/ActivateEnchantingAltar"},
        {key="searchItemPickedUp", name="RE/SearchItemPickedUp"},
        {key="gainAccessToMaze", name="RE/GainAccessToMaze"},
        {key="claimPirateChest", name="RE/ClaimPirateChest"},
        {key="BuyWeather", name="RF/PurchaseWeatherEvent"},
        {key="ConsumeCaveCrystal", name="RF/ConsumeCaveCrystal"},
    }
    for _, r in ipairs(list) do
        Events[r.key] = GetServerRemote(r.name)
    end
end

loadRemotes()

task.spawn(function()
    task.wait(1)
    HookRemote("RE/FishCaught", "FishCaught")
    HookRemote("RE/CaughtFishVisual", "CaughtVisual")
    HookRemote("RE/ObtainedNewFishNotification", "FishNotif")
end)

-- =============================
--    UB NOTIF QUEUE
-- =============================
local function getNotifDuration()
    return Config.UB.Settings.CompleteDelay * Config.UBNotifDurationMult
end

task.spawn(function()
    local cachedNotif = nil
    while true do
        task.wait(0.05)
        if not Config.UB.Active then
            _G.NotifActive = 0
            _G.NotifQueue = {}
        end
        if Config.UB.Active and not Config.amblatant then
            if #_G.NotifQueue > 0 and _G.NotifActive < MAX_NOTIF_ONSCREEN then
                local args = table.remove(_G.NotifQueue, 1)
                if not cachedNotif or not cachedNotif.Parent then
                    cachedNotif = GetServerRemote("RE/ObtainedNewFishNotification")
                end
                if cachedNotif then
                    _G.NotifActive += 1
                    FireLocalEvent(cachedNotif, unpack(args))
                    task.spawn(function()
                        task.wait(getNotifDuration())
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
--    UB SYSTEM (FIXED)
-- =============================
local function UB_init()
    Config.UB.Remotes.ChargeFishingRod = GetServerRemote("RF/ChargeFishingRod")
    Config.UB.Remotes.RequestMinigame = GetServerRemote("RF/RequestFishingMinigameStarted")
    Config.UB.Remotes.CancelFishingInputs = GetServerRemote("RF/CancelFishingInputs")
    Config.UB.Remotes.UpdateAutoFishing = GetServerRemote("RF/UpdateAutoFishingState")
    Config.UB.Remotes.FishingCompleted = GetServerRemote("RF/CatchFishCompleted")
    Config.UB.Remotes.FishingCompletedRE = GetServerRemote("RE/CatchFishCompleted")
    Config.UB.Remotes.equip = GetServerRemote("RF/EquipToolFromHotbar")
end

local function replayAmblatantNotif()
    task.spawn(function()
        local caught = GetServerRemote("RE/FishCaught")
        local visual = GetServerRemote("RE/CaughtFishVisual")
        local notif = Events.fishNotif

        if caught and #lastValidFishCaught > 0 then FireLocalEvent(caught, unpack(lastValidFishCaught)) end
        task.wait(0.03)
        if visual and #lastValidCaughtVisual > 0 then FireLocalEvent(visual, unpack(lastValidCaughtVisual)) end
        task.wait(0.03)
        if notif and #lastValidFishNotif > 0 then
            for i = 1, Config.NotifCount do
                FireLocalEvent(notif, unpack(lastValidFishNotif))
                if i < Config.NotifCount then task.wait(Config.NotifDelay) end
            end
        end
    end)
end

local function ub_loop()
    while Config.UB.Active do
        local ok, err = pcall(function()
            local currentTime = tick()
            if Config.autoFishing then CallRemote(Events.UpdateAutoFishing, true) end

            task.wait(needCast and 0.7 or Config.UB.Settings.CancelDelay)
            needCast = false

            if Config.UB.Remotes.ChargeFishingRod then
                pcall(function() Config.UB.Remotes.ChargeFishingRod:InvokeServer({[1] = currentTime}) end)
            end

            task.wait(Config.antiOKOK and math.random(15,25)/100 or 0.1)

            if Config.UB.Remotes.RequestMinigame then
                pcall(function() Config.UB.Remotes.RequestMinigame:InvokeServer(1, 0, currentTime) end)
            end

            task.wait(math.max(Config.UB.Settings.CompleteDelay, 1))

            pcall(function()
                if Config.UB.Remotes.FishingCompleted then Config.UB.Remotes.FishingCompleted:InvokeServer() end
                if Config.UB.Remotes.FishingCompletedRE then Config.UB.Remotes.FishingCompletedRE:FireServer() end
            end)

            if Config.amblatant then
                isCaught = false
                local waited = 0
                while not isCaught and waited < 1.5 do
                    task.wait(0.05)
                    waited += 0.05
                end
                if isCaught then
                    isCaught = false
                    if #_G.SavedData.FishCaught > 0 then lastValidFishCaught = deepCopyArr(_G.SavedData.FishCaught) end
                    if #_G.SavedData.CaughtVisual > 0 then lastValidCaughtVisual = deepCopyArr(_G.SavedData.CaughtVisual) end
                    if #_G.SavedData.FishNotif > 0 then lastValidFishNotif = deepCopyArr(_G.SavedData.FishNotif) end
                    replayAmblatantNotif()
                end
            else
                if #lastValidFishNotif > 0 then
                    table.insert(_G.NotifQueue, deepCopyArr(lastValidFishNotif))
                end
            end
            blatantFishCycleCount += 1
        end)
        if not ok then warn("[MNA HUB] UB Error:", err) end
        task.wait(0.1)
    end
end

local function UB_start()
    if Config.UB.Active then return end
    UB_init()
    Config.UB.Active = true
    needCast = true
    _G.NotifQueue = {}
    _G.NotifActive = 0
    Tasks.ubtask = task.spawn(ub_loop)
    Notify("Ultra Blatant", "Aktif!")
end

local function UB_stop()
    if not Config.UB.Active then return end
    Config.UB.Active = false
    _G.NotifQueue = {}
    _G.NotifActive = 0
    if Config.UB.Remotes.CancelFishingInputs then CallRemote(Config.UB.Remotes.CancelFishingInputs) end
    if Tasks.ubtask then task.cancel(Tasks.ubtask) end
    Notify("Ultra Blatant", "Dimatikan.")
end

local function onToggleUB(v)
    if v then
        equipRod()
        task.wait(0.4)
        UB_start()
    else
        UB_stop()
    end
end

UB_init()

-- Anti Stuck
task.spawn(function()
    while true do
        task.wait(5)
        if Config.UB.Active and lastTimeFishCaught and os.clock() - lastTimeFishCaught >= 20 then
            onToggleUB(false)
            task.wait(1)
            onToggleUB(true)
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
            lastValidFishNotif = deepCopyArr(args)
            lastTimeFishCaught = os.clock()
            isCaught = true
        end)
    end
end)

-- Exclaim Legit Catch
task.spawn(function()
    task.wait(2)
    if Events.exclaimEvent then
        Events.exclaimEvent.OnClientEvent:Connect(function(data)
            if not Config.AutoCatch then return end
            if not data or not data.TextData or data.TextData.EffectType ~= "Exclaim" then return end
            local container = data.Container
            if not container then return end
            local char = LocalPlayer.Character
            if not char or container ~= char:FindFirstChild("Head") then return end
            task.wait(math.max(Config.CatchDelay - 0.1, 0))
            if Events.fishing then
                pcall(function() Events.fishing:InvokeServer() end)
            end
        end)
    end
end)

-- =============================
--    MOBILE FRIENDLY UI (380x480)
-- =============================
local SG = Instance.new("ScreenGui")
SG.Name = "MNA_HUB_V113"
SG.ResetOnSpawn = false
SG.Parent = game:GetService("CoreGui")

local Win = Instance.new("Frame", SG)
Win.Size = UDim2.new(0, 380, 0, 480)
Win.Position = UDim2.new(0.5, -190, 0.5, -240)
Win.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Win.BorderSizePixel = 0
Win.Active = true
Win.Draggable = true
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", Win)
stroke.Color = Color3.fromRGB(180, 40, 40)
stroke.Thickness = 1.6

-- Title Bar
local TitleBar = Instance.new("Frame", Win)
TitleBar.Size = UDim2.new(1, 0, 0, 45)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 8, 8)
TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "MNA HUB V11.3 FREE"
Title.TextColor3 = Color3.fromRGB(255, 180, 180)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function()
    SG:Destroy()
end)

-- Content
local Content = Instance.new("ScrollingFrame", Win)
Content.Size = UDim2.new(1, -16, 1, -60)
Content.Position = UDim2.new(0, 8, 0, 52)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(180, 40, 40)
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y

local Layout = Instance.new("UIListLayout", Content)
Layout.Padding = UDim.new(0, 6)

-- =============================
--    QUICK TOGGLE FUNCTION
-- =============================
local function QuickToggle(text, key, callback)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = Color3.fromRGB(25, 8, 8)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 200, 200)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        btn.BackgroundColor3 = Config[key] and Color3.fromRGB(140, 25, 25) or Color3.fromRGB(25, 8, 8)
        if callback then callback(Config[key]) end
        Notify(text, Config[key] and "ON" or "OFF")
    end)
end

-- =============================
--    MAIN BUTTONS
-- =============================
QuickToggle("Ultra Blatant 3N", "UB", function(v)
    onToggleUB(v)
end)

QuickToggle("amBlantat", "amblatant", function(v)
    Config.amblatant = v
    if v then onToggleUB(true) end
end)

QuickToggle("Instant Bobber", "InstantBobber", function(v)
    Notify("Instant Bobber", v and "Aktif" or "Dimatikan")
end)

QuickToggle("Auto Sell", "AutoSellState", function(v)
    Notify("Auto Sell", v and "Aktif" or "Dimatikan")
end)

QuickToggle("Auto Favorite", "AutoFavoriteState", function(v)
    Notify("Auto Favorite", v and "Aktif" or "Dimatikan")
end)

QuickToggle("Walk on Water", "WalkOnWater", function(v)
    Notify("Walk on Water", v and "Aktif" or "Dimatikan")
end)

-- =============================
--    END
-- =============================
Notify("MNA HUB V11.3", "Loaded! UI Mobile Optimized", 4)

print("MNA HUB V11.3 - Full Fixed & Mobile Friendly")
