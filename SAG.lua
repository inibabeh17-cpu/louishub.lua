-- ============================================================
--  LOUIS HUB - STEAL AN EGG (Luna Interface Suite Edition)
--  100% Complete Architecture & Features in Full English
-- ============================================================

-- ============================================================
-- SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer

-- ============================================================
-- INSTANT INTERACT (Lutosys/opensrc)
-- ============================================================
pcall(function()
    local PPS = game:GetService("ProximityPromptService")
    PPS.PromptButtonHoldBegan:Connect(function(prompt, player)
        if player == LocalPlayer and tostring(prompt) == "CarryAreaEgg" then
            prompt.HoldDuration = 0
        end
    end)
end)

-- ============================================================
-- SPEED BYPASS (Lutosys/opensrc)
-- ============================================================
local _speedBypassConn   = nil
local _speedBypassActive = false

local function _activeHum()
    local c = LocalPlayer.Character
    if not c then return nil end
    for _, h in ipairs(c:GetChildren()) do
        if h:IsA("Humanoid") and not h.PlatformStand then return h end
    end
    return c:FindFirstChildOfClass("Humanoid")
end

local function initSpeedBypass()
    if type(getgc) ~= "function" or type(hookfunction) ~= "function" or type(islclosure) ~= "function" then
        warn("[SpeedBypass] missing APIs"); return false
    end
    local function findFn(nups, line)
        local ok, r = pcall(function()
            for _, f in next, getgc() do
                if typeof(f) == "function" and islclosure(f) then
                    local upvs = debug.getupvalues(f)
                    if upvs and #upvs == nups and debug.info(f, "l") == line then
                        if nups == 10 then
                            local t = debug.getupvalue(f, 3)
                            if typeof(t) == "table" and rawget(t, "Humanoid") then return f end
                        else return f end
                    end
                end
            end
        end)
        return ok and r or nil
    end
    local func3 = findFn(19, 3)
    if not func3 then warn("[SpeedBypass] func3 not found"); return false end
    local v7 = debug.getupvalue(func3, 2)
    if not v7 then warn("[SpeedBypass] v7 not found"); return false end
    local ok, err = pcall(function()
        local orig
        local function safeSetMeta(t)
            if type(isreadonly) == "function" then
                if not isreadonly(t) then pcall(setmetatable, t, {}) end
            else
                pcall(setmetatable, t, {})
            end
        end
        if type(newlclosure) == "function" then
            orig = hookfunction(v7, newlclosure(function(p1, p2)
                if p2 and typeof(p2) == "table" then safeSetMeta(p2) end
                return orig(p1, p2)
            end))
        else
            orig = hookfunction(v7, function(p1, p2)
                if p2 and typeof(p2) == "table" then safeSetMeta(p2) end
                return orig(p1, p2)
            end)
        end
    end)
    if not ok then warn("[SpeedBypass] failed:", tostring(err)); return false end
    print("[SpeedBypass] OK"); _speedBypassActive = true; return true
end

local function startSpeedBypass(spd)
    if _speedBypassConn then _speedBypassConn:Disconnect(); _speedBypassConn = nil end
    if not _speedBypassActive then return end
    _speedBypassConn = RunService.Heartbeat:Connect(function()
        local h = _activeHum(); if h then h.WalkSpeed = spd end
    end)
end

local function stopSpeedBypass()
    if _speedBypassConn then _speedBypassConn:Disconnect(); _speedBypassConn = nil end
    local h = _activeHum(); if h then h.WalkSpeed = 16 end
end

-- ============================================================
-- REMOTE HELPERS
-- ============================================================
local function getNet()
    local p = ReplicatedStorage:FindFirstChild("Packages")
    return p and p:FindFirstChild("Networking")
end

local function invokeRemote(name, ...)
    local n = getNet(); if not n then return end
    local remote = n:FindFirstChild(name)
    if not remote then warn("[RF] not found: "..name); return end
    local ok, a, b, c = pcall(function(...) return remote:InvokeServer(...) end, ...)
    if not ok then warn("[RF] "..name.." error: "..tostring(a)) end
    return ok and a, b, c
end

local function fireRemote(name, ...)
    local n = getNet(); if not n then return end
    local remote = n:FindFirstChild(name)
    if not remote then warn("[RE] not found: "..name); return end
    pcall(function(...) remote:FireServer(...) end, ...)
end

-- ============================================================
-- MODULE LOADER
-- ============================================================
local EggState, PlotState, Assets, RarityModule, AreaEggSlotIdentity
local ModulesLoaded = false

local function tryRequire(...)
    for _, path in ipairs({...}) do
        local ok, result = pcall(function()
            local cur = ReplicatedStorage
            for seg in string.gmatch(path, "[^.]+") do
                cur = cur:FindFirstChild(seg)
                if not cur then return nil end
            end
            return require(cur)
        end)
        if ok and result then return result end
    end
    return nil
end

local function loadModules()
    if ModulesLoaded then return true end
    EggState            = tryRequire("Client.EggState",  "Shared.EggState")
    PlotState           = tryRequire("Client.PlotState", "Shared.PlotState")
    Assets              = tryRequire("Data.Assets",      "Shared.Assets", "Assets")
    RarityModule        = tryRequire("Data.Rarity",      "Shared.Rarity", "Rarity")
    AreaEggSlotIdentity = tryRequire("Shared.Util.AreaEggSlotIdentity", "Util.AreaEggSlotIdentity")
    ModulesLoaded       = EggState ~= nil and PlotState ~= nil
    return ModulesLoaded
end

-- ============================================================
-- STATE
-- ============================================================
local State = {
    -- Farm
    running           = false,
    instantSteal      = false,
    busy              = false,
    stealCount        = 0,
    lockedRecord      = nil,
    -- Movement
    speed             = 120,
    returnSpeed       = 180,
    antiGuard         = true,
    -- Farm filters (Default: All enabled)
    targetRarities    = { ["All"] = true },
    priorityRarity    = true,
    targetAreas       = { ["All"] = true },
    targetMutations   = { ["All"] = true },
    minEarningRate    = 0,
    minModelWeight    = 0,
    maxModelWeight    = 999999999,
    -- Float
    floatEnabled      = false,
    floatHeight       = 3,
    -- Animation
    animEnabled       = true,
    -- Auto Place
    placeEnabled      = false,
    placeInterval     = 5,
    placeMinRarity    = "All",
    -- Auto Place Pet
    placePetEnabled      = false,
    placePetInterval     = 5,
    placeBestPetEnabled  = false,
    placeBestPetInterval = 10,
    -- No Knockback
    noKnockback       = false,
    -- Backpack threshold auto place
    _placing          = false,
    placeThreshold    = 50,
    -- Collect Money
    collectEnabled    = false,
    collectInterval   = 60,
    -- Auto Favorite
    favPetEnabled     = false,
    favEggEnabled     = false,
    favoriteInterval  = 30,
    favMinRarities    = { ["All"] = true },
    favMutations       = {},
    favMinWeight       = 0,
    favMaxWeight       = 0,
    favMinValue        = 0,
    -- Auto Hatch
    hatchEnabled      = false,
    hatchInterval     = 3,
    -- Auto Sell
    sellEnabled       = false,
    sellAll           = false,
    sellInterval      = 5,
    sellMaxRarities   = {},
    -- Auto Sell Egg
    sellEggEnabled    = false,
    sellEggInterval   = 10,
    sellEggMaxRarities = {},
    sellEggMaxRarity  = "All",
    -- Auto Sell Pet
    sellPetMaxRarities = {},
    sellPetInterval   = 5,
    -- Bat Aura
    batAura           = false,
    batInterval       = 0.1,
    -- ESP
    espEnabled        = false,
    -- Monster Parasite
    parasiteMinRarities = { ["All"] = true },
    -- Misc
    reducedMap        = false,
    antiAfk           = false,
}

-- Base fallback coordinates
local START_POS = Vector3.new(519.155, 70.576, -356.103)

-- ============================================================
-- HELPERS (With Dynamic Base Detection)
-- ============================================================
local function root()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function hum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getBasePos()
    if not PlotState then loadModules() end
    if PlotState then
        local ok, myPlot = pcall(function() return PlotState.ResolvePlot() end)
        if ok and myPlot and myPlot.CenterPoint then
            return myPlot.CenterPoint.Position + Vector3.new(0, 3.2, 0)
        end
    end
    return START_POS + Vector3.new(0, 3.2, 0)
end

local RARITY_ORDER = {
    Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,
    SuperRare=7,Exotic=8,Limited=9,Divine=10,Secret=11,Titan=12,
    Cosmic=13,Celestial=14,Transcendent=15,Prismatic=16,Rainbow=17,
    Eternal=18,Brainrot=19,Mythical=20,Exclusive=21,
}

local PET_BY_RARITY = {
    ["Common"]    = {"Chicken","Dog","Frog","Duckling","Jerboa"},
    ["Uncommon"]  = {"Bird","Catfish","Fennec"},
    ["Rare"]      = {"Owl","Raccoon","Turtle","Camel","Toucan","Chimpanzee","Penguin","Lava Gecko","Parrotfish","Dodo","Tung Tung Sahur"},
    ["Epic"]      = {"Bear","Fox","Trulimero Trulicina","Swan","Tob Tobi Tob Tob","Crocodile","Walrus","Lava Frog","Swordfish","Centapede","Crane","Bananita Dolphinita"},
    ["Legendary"] = {"Brr Brr Patapim","Axolotl","Snake","Gorilla","Orangutini Ananassini","Polar Bear","Flaming Bull","Lava Iguana","Shark","Pterodactyl","Cosmic Gecko","Salamander","Crustacia","Spideron","Scorpio","Mecha Scorpio"},
    ["Mythic"]    = {"Scorpion","Sand Spider","Spider","Tiger","Sabertooth Tiger","Mammoth","Chillin Chilli","Orca","Ankylosaurus","Cosmic Gorilla","Red Panda","Bladehide","Belula Beluga","Froggo","Mecha Froggo"},
    ["Divine"]    = {"Unicorn","Kitsune","Dreadscale","Mecha Dreadscale"},
    ["Secret"]    = {"King Snake","Yeti","Cerberus","Kraken","Tralaledon","TRex","Cosmic Dragon","Cosmic Skeleton Boss","Stag","Mutant Shark","Bomboclat Crocolat","Crocodon","Mecha Crocodon"},
    ["Cosmic"]    = {"Leviathan","Royal Sphinx","King Mammoth","Whale Shark","Beluga Whale","Triceratops","Bronto","Mosasaurus","Koi","Snowy Owl","Mantaris","Rhinotaur","Mangolini Parrochini","Crawler","Mecha Crawler"},
    ["Eternal"]   = {"Ice Dragon","Phoenix","Lava Dragon","El Maja","Eternal Lunar Dragon","Oni Tiger","Gorilla King","Strawberry Elephant","Krakenoid","Mecha Krakenoid"},
}
local PET_RARITY_MAP = {}
for rarity, pets in pairs(PET_BY_RARITY) do
    for _, name in ipairs(pets) do
        PET_RARITY_MAP[name] = rarity
    end
end

local AREA_NAMES = {
    "All", "Forest","Lake","Desert","Jungle","Snow","Volcano",
    "Abyss Ocean","Prehistoric","Cosmic","Cherry Blossom","Titan Temple"
}
local AREA_SET = {}
for _, a in ipairs(AREA_NAMES) do if a ~= "All" then AREA_SET[a] = true end end

local function formatNumber(n)
    n = tonumber(n) or 0
    if n >= 1e9  then return string.format("%.1fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(math.floor(n)) end
end

local function getAssetData(record)
    if not record then return {} end
    if Assets and record.AssetCategory then
        local ok, d = pcall(function()
            return (Assets.Directory or Assets)[record.AssetCategory] or {}
        end)
        if ok and d and next(d) then return d end
    end
    return {
        EarningRate = record.EarningRate,
        ModelWeight = record.ModelWeight,
        DropWeight  = record.DropWeight,
        DisplayName = record.AssetCategory,
        Rarity      = record.Rarity,
        _id         = record.AssetCategory,
    }
end

local function getEarningRate(record)
    if record and record.EarningRate then return tonumber(record.EarningRate) or 0 end
    return tonumber(getAssetData(record).EarningRate) or 0
end

local function getModelWeight(record)
    if record and record.ModelWeight then return tonumber(record.ModelWeight) or 0 end
    return tonumber(getAssetData(record).ModelWeight) or 0
end

local function getRarityName(record)
    if record and record.Rarity then
        if type(record.Rarity) == "table" and record.Rarity._id then
            return record.Rarity._id
        end
        if type(record.Rarity) == "string" then return record.Rarity end
    end
    local d = getAssetData(record)
    return (d.Rarity and d.Rarity._id) or "Unknown"
end

local function getRarityColor(record)
    if record and record.Rarity and type(record.Rarity) == "table" then
        if typeof(record.Rarity.Color) == "Color3" then return record.Rarity.Color end
    end
    local d = getAssetData(record)
    if d.Rarity and typeof(d.Rarity.Color) == "Color3" then return d.Rarity.Color end
    if RarityModule and RarityModule.Rarities then
        local rn = getRarityName(record)
        local rm = RarityModule.Rarities[rn]
        if rm and typeof(rm.Color) == "Color3" then return rm.Color end
    end
    return Color3.fromRGB(255, 255, 255)
end

local MUTATIONS = {"All", "Silver", "Bloom", "Golden", "Rainbow", "Spirit Bloom"}

local function isMutationAllowed(record)
    if not next(State.targetMutations) or State.targetMutations["All"] then return true end
    if not record or not record.Mutations then return false end
    if type(record.Mutations) ~= "table" then return false end
    for mutName in pairs(State.targetMutations) do
        if mutName ~= "All" then
            for k, v in pairs(record.Mutations) do
                local name = type(k) == "string" and k or tostring(v)
                if name:lower():find(mutName:lower()) then return true end
            end
        end
    end
    return false
end

local function isRarityAllowed(record)
    if not next(State.targetRarities) or State.targetRarities["All"] then return true end
    local name = getRarityName(record)
    if not name or name == "Unknown" then return true end
    if State.targetRarities[name] then return true end
    local lower = name:lower()
    for k in pairs(State.targetRarities) do
        if type(k) == "string" and k:lower() == lower then return true end
    end
    return false
end

local function isValueAllowed(record)
    if State.minEarningRate > 0 and getEarningRate(record) < State.minEarningRate then
        return false
    end
    local w = getModelWeight(record)
    if State.minModelWeight > 0 and w < State.minModelWeight then return false end
    if w > State.maxModelWeight then return false end
    return true
end

local function isAreaAllowed(rec)
    if not next(State.targetAreas) or State.targetAreas["All"] then return true end
    local areaId = tostring(rec.AreaId or "")
    if State.targetAreas[areaId] then return true end
    local cat = tostring(rec.AssetCategory or "")
    for area in pairs(State.targetAreas) do
        if area ~= "All" and cat:lower():find(area:lower(), 1, true) then return true end
    end
    return false
end

local function applyNoKnockback()
    if type(getconnections) ~= "function" then return end
    local net = getNet()
    if not net then return end
    local remote = net:FindFirstChild("RE/RigSync/Refresh")
    if not remote then return end
    local ok, conns = pcall(function() return getconnections(remote.OnClientEvent) end)
    if not ok or not conns then return end
    for _, conn in next, conns do
        pcall(function() conn:Disconnect() end)
    end
    print("[NoKnockback] patched")
end

local function upgradeBase()
    fireRemote("RE/Homestead/AskBaseTierRaise")
    print("[UpgradeBase] fired")
end

local function upgradeTreadmill(id)
    invokeRemote("RF/Treadmill/AskTierRaise", id)
    print("[UpgradeTreadmill] fired id:", tostring(id))
end

-- ============================================================
-- HUMANOID BYPASS (Spoofer with Clean Restore)
-- ============================================================
local _camConn = nil
local _savedOrigHum = nil

local function doHumanoidBypass()
    local char = LocalPlayer.Character
    if not char then char = LocalPlayer.CharacterAdded:Wait() end

    local origHum  = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not origHum or not rootPart then return end
    if _savedOrigHum and _savedOrigHum.Parent == nil then return end

    pcall(function()
        local clone = origHum:Clone()
        clone.WalkSpeed   = origHum.WalkSpeed
        clone.JumpPower   = origHum.JumpPower
        clone.MaxHealth   = origHum.MaxHealth
        clone.Health      = origHum.Health
        clone.AutoRotate  = origHum.AutoRotate
        clone.DisplayName = origHum.DisplayName

        _savedOrigHum = origHum
        origHum.Parent = nil -- Detach to sever anti-cheat listeners

        clone.Parent = char

        local targetBase = getBasePos()
        if rootPart and rootPart.Parent then
            rootPart.CFrame                  = CFrame.new(targetBase)
            rootPart.AssemblyLinearVelocity  = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end

        task.wait(0.05)
        clone.PlatformStand = false
        clone.Sit           = false
        pcall(function() clone:ChangeState(Enum.HumanoidStateType.Running) end)
    end)

    if _camConn then _camConn:Disconnect() end
    _camConn = RunService.Heartbeat:Connect(function()
        local c = LocalPlayer.Character
        if not c then return end
        local h2 = c:FindFirstChildOfClass("Humanoid")
        if h2 then
            pcall(function() Workspace.CurrentCamera.CameraSubject = h2 end)
        end
    end)
end

local function restoreHumanoid()
    local char = LocalPlayer.Character
    if not char then return end
    local currentHum = char:FindFirstChildOfClass("Humanoid")

    pcall(function()
        if _savedOrigHum then
            if currentHum and currentHum ~= _savedOrigHum then
                currentHum:Destroy()
            end
            _savedOrigHum.Parent = char
            _savedOrigHum.WalkSpeed = 16
            _savedOrigHum.PlatformStand = false
            _savedOrigHum.Sit = false
            pcall(function() _savedOrigHum:ChangeState(Enum.HumanoidStateType.Running) end)
            workspace.CurrentCamera.CameraSubject = _savedOrigHum
            _savedOrigHum = nil
        elseif currentHum then
            currentHum.WalkSpeed = 16
            currentHum.PlatformStand = false
            currentHum.Sit = false
            pcall(function() currentHum:ChangeState(Enum.HumanoidStateType.Running) end)
            workspace.CurrentCamera.CameraSubject = currentHum
        end
    end)
    if _camConn then _camConn:Disconnect(); _camConn = nil end
end

LocalPlayer.CharacterAdded:Connect(function()
    if State.running or State.instantSteal then
        task.wait(0.3)
        doHumanoidBypass()
    end
end)

-- ============================================================
-- ANTI-VOID GUARDIAN
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.2)
        local r = root()
        if r and r.Position.Y < 20 then
            pcall(function()
                r.AssemblyLinearVelocity  = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
                r.CFrame = CFrame.new(getBasePos() + Vector3.new(0, 1, 0))
            end)
            print("[AntiVoid] Saved from falling into the void! Teleported to base.")
        end
    end
end)

-- ============================================================
-- FLOAT & ANIMATION
-- ============================================================
local _floatConn = nil
local function updateFloat()
    if _floatConn then _floatConn:Disconnect(); _floatConn = nil end
    if not State.floatEnabled then return end
    _floatConn = RunService.RenderStepped:Connect(function()
        if not State.floatEnabled then return end
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then
            local rot = hrp.CFrame - hrp.CFrame.Position
            hrp.CFrame = CFrame.new(
                hrp.Position.X,
                hrp.Position.Y + State.floatHeight,
                hrp.Position.Z
            ) * rot
        end
    end)
end

local _animTracks = {}
local _animConn   = nil

local function stopAllAnims()
    local c = LocalPlayer.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0) end)
        end
    end
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        pcall(function() track:Stop(0) end)
    end
    for _, obj in ipairs(c:GetDescendants()) do
        if obj:IsA("Motor6D") then
            pcall(function() obj.Transform = CFrame.identity end)
        end
    end
end

local function updateAnim()
    if _animConn then _animConn:Disconnect(); _animConn = nil end
    if State.animEnabled then return end
    stopAllAnims()
    _animConn = RunService.Heartbeat:Connect(function()
        if State.animEnabled then
            if _animConn then _animConn:Disconnect(); _animConn = nil end
            return
        end
        stopAllAnims()
    end)
end

-- ============================================================
-- MOVEMENT (TPWalk inside walkTo only - Smooth Walking, No Snapping)
-- ============================================================
local function walkTo(goal, timeout, isReturning, checkFn)
    local h2 = hum()
    local r  = root()
    if not h2 or not r then return false end
    if typeof(goal) == "Instance" then goal = goal.Position end

    timeout = timeout or 20
    local speed      = isReturning and (State.antiGuard and (State.returnSpeed or 180) or State.speed) or State.speed
    local targetDist = 5

    if (r.Position - goal).Magnitude <= targetDist then
        h2.WalkSpeed = 16; return true
    end

    h2.WalkSpeed = 16
    h2:MoveTo(goal)

    local t0       = workspace.DistributedGameTime
    local lastPos  = r.Position
    local stuckT   = t0
    local shouldContinue = checkFn or function() return (State.running or State.instantSteal) end

    while workspace.DistributedGameTime - t0 < timeout do
        if not shouldContinue() then break end
        local dt = RunService.Heartbeat:Wait()
        r  = root(); h2 = hum()
        if not r or not h2 then break end

        local dist = (r.Position - goal).Magnitude

        if dist <= targetDist then
            h2.WalkSpeed = 0
            h2:Move(Vector3.zero, false)
            r.AssemblyLinearVelocity  = r.AssemblyLinearVelocity * 0.5
            r.AssemblyAngularVelocity = Vector3.zero
            break
        end

        local toGoal = Vector3.new(goal.X - r.Position.X, 0, goal.Z - r.Position.Z)
        if toGoal.Magnitude > 0.1 then
            local step = math.min(speed * dt, toGoal.Magnitude)
            r.CFrame = r.CFrame + (toGoal.Unit * step)
        end

        local brake = math.max(speed * 0.08, 15)
        if dist <= brake then
            speed = math.max(16, speed * (dist/brake)^1.5)
        end
        h2:MoveTo(goal)

        local now = workspace.DistributedGameTime
        if now - stuckT >= 2 then
            if (r.Position - lastPos).Magnitude < 0.5 then
                h2:MoveTo(goal)
                h2.Jump = true
            end
            lastPos = r.Position
            stuckT  = now
        end
    end

    h2 = hum()
    if h2 then h2.WalkSpeed = 16 end
    return true
end

-- ============================================================
-- EGG FINDER & DROPPED EGG RE-PICKUP
-- ============================================================
local function hasEgg()
    local char = LocalPlayer.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and (t:GetAttribute("ItemType") == "AssetEgg" or t:GetAttribute("ItemType") == "PetEgg" or AREA_SET[t.Name] or t.Name:lower():find("egg")) then
                return true
            end
        end
    end
    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") and (t:GetAttribute("ItemType") == "AssetEgg" or t:GetAttribute("ItemType") == "PetEgg" or AREA_SET[t.Name] or t.Name:lower():find("egg")) then
            return true
        end
    end
    return false
end

local function findDroppedEggNearPlayer()
    local r = root()
    if not r then return nil, nil end
    local closestPart, closestPrompt, minDist = nil, nil, 80
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and (obj.Name == "CarryAreaEgg" or tostring(obj) == "CarryAreaEgg" or obj.ActionText:lower():find("carry") or obj.ActionText:lower():find("egg")) then
            local part = obj.Parent
            if part and part:IsA("BasePart") then
                local d = (part.Position - r.Position).Magnitude
                if d < minDist then
                    minDist = d
                    closestPart = part
                    closestPrompt = obj
                end
            end
        end
    end
    return closestPart, closestPrompt
end

local function checkAndRecoverEgg(isInstant)
    if hasEgg() then return true end
    local part, prompt = findDroppedEggNearPlayer()
    if part and prompt then
        local r = root()
        if r then
            if isInstant then
                pcall(function()
                    r.CFrame = CFrame.new(part.Position + Vector3.new(0, 3.2, 0))
                    r.AssemblyLinearVelocity = Vector3.zero
                end)
            else
                walkTo(part.Position, 5, false)
            end
            task.wait(0.05)
            pcall(function()
                prompt.Enabled = true
                prompt.HoldDuration = 0
                if typeof(fireproximityprompt) == "function" then
                    fireproximityprompt(prompt, 0)
                end
                prompt:InputHoldBegin()
                prompt:InputHoldEnd()
            end)
            task.wait(0.15)
        end
    end
    return hasEgg()
end

local function findBestEgg()
    if not EggState then return nil, nil end
    local ok, fieldEggs = pcall(function() return EggState.ReadFieldEggs() end)
    if not ok or not fieldEggs or not fieldEggs.Records then return nil, nil end

    local r = root()
    if not r then return nil, nil end

    if State.lockedRecord then
        for _, rec in ipairs(fieldEggs.Records) do
            if rec.Uid == State.lockedRecord.Uid then
                if isRarityAllowed(rec) and isValueAllowed(rec) then
                    local model = Workspace:FindFirstChild("AreaEggSlotsClient", true)
                        and Workspace.AreaEggSlotsClient:FindFirstChild(rec.Uid)
                        or Workspace:FindFirstChild(rec.Uid, true)
                    if model then return rec, model end
                end
                break
            end
        end
        State.lockedRecord = nil
    end

    local bestRec, bestModel, bestScore = nil, nil, -math.huge

    for _, rec in ipairs(fieldEggs.Records) do
        if not isRarityAllowed(rec) then continue end
        if not isValueAllowed(rec)  then continue end
        if not isMutationAllowed(rec) then continue end
        if not isAreaAllowed(rec) then continue end

        local model = Workspace:FindFirstChild("AreaEggSlotsClient", true)
            and Workspace.AreaEggSlotsClient:FindFirstChild(rec.Uid)
            or Workspace:FindFirstChild(rec.Uid, true)

        if model then
            local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local d = (part.Position - r.Position).Magnitude
                local rarNum = RARITY_ORDER[getRarityName(rec)] or 0
                local score = State.priorityRarity and (rarNum * 10000 - d) or (-d)
                if score > bestScore then
                    bestScore = score
                    bestRec   = rec
                    bestModel = model
                end
            end
        end
    end

    if bestRec then State.lockedRecord = bestRec end
    return bestRec, bestModel
end

-- ============================================================
-- AUTO STEAL CYCLE (Smooth TPWalk Return to Real Base)
-- ============================================================
local function farmCycle()
    if State.busy or not State.running then return end
    State.busy = true
    local _busyStart = tick()

    pcall(function()
        if not loadModules() then State.busy = false; return end
        local r = root(); local h2 = hum()
        if not r or not h2 then State.busy = false; return end

        if tick() - _busyStart > 30 then State.busy = false; return end

        local rec, model = findBestEgg()
        if not rec or not model then
            State.lockedRecord = nil
            State.busy = false; return
        end

        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        if not part then State.lockedRecord = nil; State.busy = false; return end

        -- 1. Walk to egg nest
        if not walkTo(part.Position, 15, false) then State.busy = false; return end
        if not State.running then State.busy = false; return end

        r = root()
        if not r then State.busy = false; return end
        local dist = (r.Position - part.Position).Magnitude
        if dist > 10 then State.busy = false; return end

        local slotKey = nil
        pcall(function()
            if AreaEggSlotIdentity and rec.AreaId and rec.NestId then
                slotKey = AreaEggSlotIdentity.SlotKey(rec.AreaId, rec.NestId)
            end
        end)

        local safeClaimY = math.max(part.Position.Y + 3.2, r.Position.Y)
        pcall(function()
            r.CFrame = CFrame.new(part.Position.X, safeClaimY, part.Position.Z) * (r.CFrame - r.CFrame.Position)
            r.AssemblyLinearVelocity  = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)

        -- 2. Claim egg
        local function fireClaim()
            pcall(function() EggState.CarryFieldEgg(rec.Uid, slotKey) end)
            pcall(function() EggState.CarryFieldEgg(rec.Uid) end)
            for _, obj in ipairs(model:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    pcall(function()
                        obj.Enabled = true
                        obj.HoldDuration = 0
                        if typeof(fireproximityprompt) == "function" then
                            fireproximityprompt(obj, 0)
                        end
                        obj:InputHoldBegin()
                        obj:InputHoldEnd()
                    end)
                end
            end
        end

        fireClaim()
        local claimT = tick()
        while tick() - claimT < 0.4 do
            task.wait()
            if hasEgg() then break end
            fireClaim()
        end
        State.lockedRecord = nil

        -- Short rubberband check
        local r3 = root()
        if r3 and Vector3.new(r3.AssemblyLinearVelocity.X, 0, r3.AssemblyLinearVelocity.Z).Magnitude > 25 then
            task.wait(0.2)
        end

        -- 3. Walk smoothly back to the player's dynamic base
        local myBasePos = getBasePos()
        walkTo(myBasePos, 15, true, function()
            -- Continuous dropped egg check while returning to base
            if not hasEgg() then
                checkAndRecoverEgg(false)
            end
            return State.running
        end)

        if not State.running then State.busy = false; return end

        -- Final drop check upon arrival
        if not hasEgg() then
            checkAndRecoverEgg(false)
        end

        -- Unequip egg to backpack
        local charEq = LocalPlayer.Character
        if charEq then
            for _, t in ipairs(charEq:GetChildren()) do
                if t:IsA("Tool") and (t:GetAttribute("ItemType") == "AssetEgg" or t:GetAttribute("ItemType") == "PetEgg" or AREA_SET[t.Name] or t.Name:lower():find("egg")) then
                    pcall(function() t.Parent = LocalPlayer.Backpack end)
                end
            end
        end

        State.stealCount += 1
    end)

    local h2 = hum()
    if h2 then h2.WalkSpeed = 16 end
    State.busy = false
end

-- ============================================================
-- INSTANT STEAL CYCLE (BETA - Instant Teleportation)
-- ============================================================
local function instantStealCycle()
    if State.busy or not State.instantSteal then return end
    State.busy = true
    local _busyStart = tick()

    pcall(function()
        if not loadModules() then State.busy = false; return end
        local r = root()
        if not r then State.busy = false; return end

        if tick() - _busyStart > 15 then State.busy = false; return end

        local rec, model = findBestEgg()
        if not rec or not model then
            State.lockedRecord = nil
            State.busy = false; return
        end

        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        if not part then State.lockedRecord = nil; State.busy = false; return end

        local slotKey = nil
        pcall(function()
            if AreaEggSlotIdentity and rec.AreaId and rec.NestId then
                slotKey = AreaEggSlotIdentity.SlotKey(rec.AreaId, rec.NestId)
            end
        end)

        -- 1. Flash teleport to target egg
        local safeClaimY = math.max(part.Position.Y + 3.2, r.Position.Y)
        pcall(function()
            r.CFrame = CFrame.new(part.Position.X, safeClaimY, part.Position.Z)
            r.AssemblyLinearVelocity  = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.08)

        -- 2. Claim egg
        local function fireClaim()
            pcall(function() EggState.CarryFieldEgg(rec.Uid, slotKey) end)
            pcall(function() EggState.CarryFieldEgg(rec.Uid) end)
            for _, obj in ipairs(model:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    pcall(function()
                        obj.Enabled = true
                        obj.HoldDuration = 0
                        if typeof(fireproximityprompt) == "function" then
                            fireproximityprompt(obj, 0)
                        end
                        obj:InputHoldBegin()
                        obj:InputHoldEnd()
                    end)
                end
            end
        end

        fireClaim()
        local claimT = tick()
        while tick() - claimT < 0.35 do
            task.wait()
            if hasEgg() then break end
            fireClaim()
        end
        State.lockedRecord = nil

        -- 3. Flash teleport back to dynamic base
        local myBasePos = getBasePos()
        pcall(function()
            r.CFrame = CFrame.new(myBasePos)
            r.AssemblyLinearVelocity  = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.08)

        -- 4. Check if dropped & re-pickup instantly
        if not hasEgg() then
            checkAndRecoverEgg(true)
            pcall(function()
                r.CFrame = CFrame.new(myBasePos)
                r.AssemblyLinearVelocity  = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end)
        end

        local charEq = LocalPlayer.Character
        if charEq then
            for _, t in ipairs(charEq:GetChildren()) do
                if t:IsA("Tool") and (t:GetAttribute("ItemType") == "AssetEgg" or t:GetAttribute("ItemType") == "PetEgg" or AREA_SET[t.Name] or t.Name:lower():find("egg")) then
                    pcall(function() t.Parent = LocalPlayer.Backpack end)
                end
            end
        end

        State.stealCount += 1
    end)

    State.busy = false
end

-- ============================================================
-- AUTO PLACE, HATCH & SELL SYSTEMS
-- ============================================================
local function runAutoPlace()
    if not PlotState then loadModules() end
    if not PlotState then return end
    pcall(function()
        local myPlot = PlotState.ResolvePlot()
        if not myPlot or not myPlot.CenterPoint or not myPlot.PetArea then return end

        local plotPos = myPlot.CenterPoint.Position
        local r = root()
        if r and (r.Position - plotPos).Magnitude > 5 then
            walkTo(plotPos, 15, false, function() return State.placeEnabled end)
        end
        task.wait(0.3)

        local net = getNet()
        local placeRemote = net and net:FindFirstChild("RF/EggWorld/AskPlaceEgg")
        local wearRemote  = net and net:FindFirstChild("RF/EggWorld/AskWearTool")
        if not placeRemote then return end

        local petArea = myPlot.PetArea
        local centerCF = myPlot.CenterPoint.CFrame
        local petSize = petArea.Size
        local basePetPos = myPlot.PetArea.Position

        local slotIndex = 0
        local function nextLocalCFrame()
            slotIndex += 1
            local halfX = (petSize.X * 0.4)
            local halfZ = (petSize.Z * 0.4)
            local offsetX = (math.random() * 2 - 1) * halfX
            local offsetZ = (math.random() * 2 - 1) * halfZ
            local worldPos = basePetPos + Vector3.new(offsetX, 0, offsetZ)
            local localPos = centerCF:PointToObjectSpace(worldPos)
            return CFrame.new(localPos) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0,0,-1), Vector3.new(0,1,0), Vector3.new(1,0,0))
        end

        if not EggState then return end
        pcall(function() EggState.SyncOwnedEggs() end)
        task.wait(0.3)

        local ok, owned = pcall(function() return EggState.ReadOwnerEggs(LocalPlayer.UserId) end)
        if not ok or type(owned) ~= "table" or not next(owned) then return end

        local minRarNum = RARITY_ORDER[State.placeMinRarity] or 0
        local placed = 0

        for k, rec in pairs(owned) do
            if placed >= 10 then break end
            local uid = type(k) == "string" and k or (type(rec) == "table" and rec.Uid)
            if not uid or type(k) ~= "string" or rec.Placement ~= nil then continue end

            if minRarNum > 0 then
                local rarNum = rec.Rarity and type(rec.Rarity) == "table" and rec.Rarity.RarityNumber or rec.RarityNumber or 0
                if rarNum > 0 and rarNum < minRarNum then continue end
            end

            local eggTool = nil
            for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if t:IsA("Tool") and (t:GetAttribute("ItemType") == "AssetEgg" or t:GetAttribute("ItemType") == "PetEgg") then
                    eggTool = t; break
                end
            end
            if eggTool then
                pcall(function() eggTool.Parent = LocalPlayer.Character end)
                task.wait(0.2)
            elseif wearRemote then
                pcall(function() wearRemote:InvokeServer(uid) end)
                task.wait(0.25)
            end

            local localCFrame = nextLocalCFrame()
            local ok3, res = pcall(function() return placeRemote:InvokeServer({Uid = uid, LocalCFrame = localCFrame}) end)
            if ok3 and res == true then placed += 1 end
            task.wait(0.1)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.placeInterval or 5)
        if State.placeEnabled and not State._placing then
            State._placing = true
            pcall(runAutoPlace)
            State._placing = false
        end
    end
end)

local function runAutoPlacePet()
    if not PlotState then loadModules() end
    if not PlotState then return end
    pcall(function()
        local myPlot = PlotState.ResolvePlot()
        if not myPlot or not myPlot.CenterPoint or not myPlot.PetArea then return end

        local plotPos = myPlot.CenterPoint.Position
        local r = root()
        if r and (r.Position - plotPos).Magnitude > 5 then
            walkTo(plotPos, 15, false, function() return State.placePetEnabled end)
        end
        task.wait(0.3)

        local net = getNet()
        local placeRemote = net and net:FindFirstChild("RF/EggWorld/AskPlaceEgg")
        if not placeRemote then return end

        local localCFrame = myPlot.CenterPoint.CFrame:ToObjectSpace(myPlot.PetArea.CFrame)

        local placed = 0
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if not tool:IsA("Tool") then continue end
            local itemType = tool:GetAttribute("ItemType")
            if itemType ~= "Asset" and itemType ~= "Phone" then continue end

            pcall(function() tool.Parent = LocalPlayer.Character end)
            task.wait(0.15)

            local uid = tool:GetAttribute("Uid") or tool:GetAttribute("uid") or tool.Name
            local ok3, res = pcall(function()
                return placeRemote:InvokeServer({Uid = uid, LocalCFrame = localCFrame})
            end)
            if ok3 and res then
                placed += 1
            else
                pcall(function() tool.Parent = LocalPlayer.Backpack end)
            end
            task.wait(0.1)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.placePetInterval or 5)
        if State.placePetEnabled and not State._placing then
            State._placing = true
            pcall(runAutoPlacePet)
            State._placing = false
        end
    end
end)

local function runAutoPlaceBestPet()
    if not PlotState then loadModules() end
    if not PlotState then return end
    pcall(function()
        local myPlot = PlotState.ResolvePlot()
        if not myPlot or not myPlot.CenterPoint or not myPlot.PetArea then return end

        local plotPos = myPlot.CenterPoint.Position
        local r = root()
        if r and (r.Position - plotPos).Magnitude > 5 then
            walkTo(plotPos, 15, false, function() return State.placeBestPetEnabled end)
        end
        task.wait(0.3)

        local net = getNet()
        local placeRemote = net and net:FindFirstChild("RF/EggWorld/AskPlaceEgg")
        if not placeRemote then return end

        local centerCF = myPlot.CenterPoint.CFrame
        local basePetPos = myPlot.PetArea.Position
        local petSize = myPlot.PetArea.Size

        local pets = {}
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if not tool:IsA("Tool") then continue end
            local itype = tool:GetAttribute("ItemType")
            if itype ~= "Asset" and itype ~= "Phone" then continue end
            local rarity = PET_RARITY_MAP[tool.Name]
            local rarNum = rarity and (RARITY_ORDER[rarity] or 0) or 0
            table.insert(pets, {tool=tool, name=tool.Name, rarNum=rarNum})
        end

        table.sort(pets, function(a, b) return a.rarNum > b.rarNum end)

        local placed = 0
        for _, pet in ipairs(pets) do
            if placed >= 10 then break end
            local ox = (math.random()*2-1) * petSize.X * 0.4
            local oz = (math.random()*2-1) * petSize.Z * 0.4
            local worldPos = basePetPos + Vector3.new(ox, 0, oz)
            local localPos = centerCF:PointToObjectSpace(worldPos)
            local localCFrame = CFrame.new(localPos) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0,0,-1), Vector3.new(0,1,0), Vector3.new(1,0,0))

            pcall(function() pet.tool.Parent = LocalPlayer.Character end)
            task.wait(0.15)

            local uid = pet.tool:GetAttribute("Uid") or pet.tool:GetAttribute("uid") or pet.name
            local ok3, res = pcall(function() return placeRemote:InvokeServer({Uid=uid, LocalCFrame=localCFrame}) end)
            if ok3 and res then placed += 1 end
            task.wait(0.1)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.placeBestPetInterval or 10)
        if State.placeBestPetEnabled then pcall(runAutoPlaceBestPet) end
    end
end)

local function runAutoHatch()
    if not EggState then return end
    pcall(function()
        local net = getNet(); if not net then return end
        local AskHatch = net:FindFirstChild("RF/EggWorld/AskHatch")
        local AskFinishHatch = net:FindFirstChild("RF/EggWorld/AskFinishHatch")
        if not AskHatch and not AskFinishHatch then return end

        local owned = EggState.ReadOwnerEggs(LocalPlayer.UserId)
        if type(owned) ~= "table" then return end

        for uid, rec in pairs(owned) do
            if type(uid) ~= "string" then continue end
            if AskHatch then pcall(function() AskHatch:InvokeServer(uid) end); task.wait(0.05) end
            if AskFinishHatch then pcall(function() AskFinishHatch:InvokeServer(uid) end); task.wait(0.05) end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.hatchInterval)
        if State.hatchEnabled then pcall(runAutoHatch) end
    end
end)

local function runAutoSellEgg()
    if not State.sellEggEnabled then return end
    pcall(function()
        local net = getNet(); if not net then return end
        local sellRemote = net:FindFirstChild("RE/PetSatchel/SellPet")
        local wearRemote = net:FindFirstChild("RF/EggWorld/AskWearTool")
        if not sellRemote then return end

        local owned = EggState.ReadOwnerEggs(LocalPlayer.UserId)
        if type(owned) ~= "table" then return end

        for uid, rec in pairs(owned) do
            if type(uid) ~= "string" then continue end
            local rarName = getRarityName(rec)
            if next(State.sellEggMaxRarities) and not State.sellEggMaxRarities[rarName] then continue end

            if wearRemote then pcall(function() wearRemote:InvokeServer(uid) end); task.wait(0.2) end
            pcall(function() sellRemote:FireServer({uid}) end)
            task.wait(0.1)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.sellEggInterval or 10)
        if State.sellEggEnabled then pcall(runAutoSellEgg) end
    end
end)

local function getToolFromNil(name)
    if type(getnilinstances) ~= "function" then return nil end
    local ok, result = pcall(function()
        for _, obj in ipairs(getnilinstances()) do
            if obj:IsA("Tool") and obj.Name == name then return obj end
        end
        return nil
    end)
    return ok and result or nil
end

local function runAutoSell()
    pcall(function()
        local net = getNet(); if not net then return end

        if State.sellAll then
            local remote = net:FindFirstChild("RE/PetSatchel/SellEveryPet")
            if remote then remote:FireServer() end
            return
        end

        if not EggState then loadModules() end
        if not EggState then return end

        local wearRemote    = net:FindFirstChild("RF/EggWorld/AskWearTool")
        local triggerRemote = net:FindFirstChild("RE/ToolTrigger/Trigger")
        if not wearRemote or not triggerRemote then return end

        local ok, owned = pcall(function() return EggState.ReadOwnerEggs(LocalPlayer.UserId) end)
        if not ok or type(owned) ~= "table" or not next(owned) then return end

        for _, rec in ipairs(owned) do
            if not rec.Uid then continue end
            local rarName = getRarityName(rec)
            if next(State.sellPetMaxRarities) and not State.sellPetMaxRarities[rarName] then continue end

            pcall(function() wearRemote:InvokeServer(rec.Uid) end)
            task.wait(0.2)

            local eggName = rec.AssetCategory or rec.DisplayName or (rec.Rarity and rec._id) or tostring(rec.Uid)
            local tool = getToolFromNil(eggName)
            if not tool and LocalPlayer.Character then tool = LocalPlayer.Character:FindFirstChildOfClass("Tool") end

            if tool then
                pcall(function() triggerRemote:FireServer(tool) end)
            end
            task.wait(0.3)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(5)
        if State.sellEnabled then pcall(runAutoSell) end
    end
end)

local function runAutoSellPet()
    if not State.sellEnabled then return end
    pcall(function()
        local net = getNet(); if not net then return end
        if State.sellAll then
            local remote = net:FindFirstChild("RE/PetSatchel/SellEveryPet")
            if remote then remote:FireServer() end
            return
        end
        local sellRemote = net:FindFirstChild("RE/PetSatchel/SellPet")
        local wearRemote = net:FindFirstChild("RF/EggWorld/AskWearTool")
        if not sellRemote then return end

        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if not tool:IsA("Tool") then continue end
            local itype = tool:GetAttribute("ItemType")
            if itype ~= "Asset" and itype ~= "Phone" then continue end

            local rarity = PET_RARITY_MAP[tool.Name]
            if not rarity or (next(State.sellPetMaxRarities) and not State.sellPetMaxRarities[rarity]) then continue end
            if tool:GetAttribute("IsFavorited") or tool:GetAttribute("Favorited") then continue end

            local uid = tool:GetAttribute("Uid") or tool:GetAttribute("uid")
            if not uid then continue end

            if wearRemote then pcall(function() wearRemote:InvokeServer(uid) end); task.wait(0.2) end
            pcall(function() sellRemote:FireServer({uid}) end)
            task.wait(0.1)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.sellPetInterval or 5)
        if State.sellEnabled then pcall(runAutoSellPet) end
    end
end)

local function runCollectMoney()
    pcall(function()
        local net = getNet(); if not net then return end
        local remote = net:FindFirstChild("RF/AwayEarnings/AskCollect")
        if remote then remote:InvokeServer({Kind = "Claim"}) end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.collectInterval or 60)
        if State.collectEnabled then pcall(runCollectMoney) end
    end
end)

local function shouldFavorite(tool)
    if not tool:IsA("Tool") then return false end
    local itype = tool:GetAttribute("ItemType")
    local isPet = itype == "Asset" or itype == "Phone"
    local isEgg = itype == "AssetEgg" or itype == "PetEgg" or AREA_SET[tool.Name]
    if not isPet and not isEgg then return false end

    if isPet and not State.favPetEnabled then return false end
    if isEgg and not State.favEggEnabled then return false end

    if next(State.favMinRarities) and not State.favMinRarities["All"] then
        local rarity = isPet and PET_RARITY_MAP[tool.Name] or (tool:GetAttribute("Rarity") or tool:GetAttribute("rarity"))
        if not rarity or not State.favMinRarities[rarity] then return false end
    end
    return true
end

local function favoriteTool(tool)
    local uid = tool:GetAttribute("Uid") or tool:GetAttribute("uid")
    if not uid then return false end
    local net = getNet(); if not net then return false end
    local remote     = net:FindFirstChild("RE/PetSatchel/WriteFavourite")
    local wearRemote = net:FindFirstChild("RF/EggWorld/AskWearTool")
    if not remote then return false end
    if wearRemote then pcall(function() wearRemote:InvokeServer(uid) end) end
    pcall(function() remote:FireServer(uid, true) end)
    return true
end

task.spawn(function()
    local bp = LocalPlayer:WaitForChild("Backpack", 10)
    if bp then
        bp.ChildAdded:Connect(function(tool)
            if not State.favPetEnabled and not State.favEggEnabled then return end
            task.wait(0.1)
            if shouldFavorite(tool) then favoriteTool(tool) end
        end)
    end
end)

-- Bat Aura
task.spawn(function()
    while true do
        task.wait(State.batInterval)
        if State.batAura then
            local n = getNet()
            local r = n and n:FindFirstChild("RE/BatSwing/Trigger")
            if r then pcall(function() r:FireServer() end) end
        end
    end
end)

-- Extra Systems (Haul, Codex, Fusery, Bloomery, Parasite)
local function wearBest() invokeRemote("RF/Haul/WearBest") end
local function sellFullSatchel() invokeRemote("RF/Haul/OfferFullSatchelSale") end
local function fetchAutoSell() return invokeRemote("RF/Haul/FetchAutoSell") end
local function writeAutoSell(cfg) invokeRemote("RF/Haul/WriteAutoSell", cfg) end
local function redeemAllCodex() invokeRemote("RF/Codex/AskRedeemAll") end
local function wearFieldBat() return invokeRemote("RF/Codex/AskWearFieldBat") end
local function fuseLoadPet(uid) return invokeRemote("RF/Fusery/LoadPet", uid) end
local function fuseBegin() return invokeRemote("RF/Fusery/BeginFuse") end
local function fuseFinishReveal() invokeRemote("RF/Fusery/FinishReveal") end
local function fuseEjectPet(slot) invokeRemote("RF/Fusery/EjectPet", slot) end

local function autoFuse(uid1, uid2, uid3)
    pcall(function() invokeRemote("RF/Fusery/ConfirmBriefing") end)
    task.wait(0.2)
    fuseLoadPet(uid1); task.wait(0.2)
    fuseLoadPet(uid2); task.wait(0.2)
    fuseLoadPet(uid3); task.wait(0.3)
    local success = fuseBegin()
    if success then task.wait(0.5); fuseFinishReveal() end
end

local _batTreeConn = nil
local _bloomEventConn = nil
local _bloomActive = false

local function startBatTree(target)
    if _batTreeConn then _batTreeConn:Disconnect(); _batTreeConn = nil end
    _batTreeConn = RunService.Heartbeat:Connect(function()
        local n = getNet(); if not n then return end
        local remote = n:FindFirstChild("RE/BatSwing/Trigger"); if not remote then return end
        local char = LocalPlayer.Character; if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool or tool:GetAttribute("ItemType") ~= "Gear" then return end
        local seed = ("%s:100:%s"):format(tostring(LocalPlayer.UserId), tostring(math.floor(Workspace:GetServerTimeNow() * 1000)))
        pcall(function() remote:FireServer(target, seed) end)
    end)
end
local function stopBatTree() if _batTreeConn then _batTreeConn:Disconnect(); _batTreeConn = nil end end

local function strikeTree(ref)
    if ref then fireRemote("RE/Bloomery/AskStrikeTree", ref)
    else fireRemote("RE/Bloomery/AskStrikeTree") end
end
local function gatherPetal() invokeRemote("RF/Bloomery/AskGatherPetal") end
local function mutateEgg() invokeRemote("RF/Bloomery/AskMutate") end

local function isTreeObject(obj)
    local n = obj.Name:lower()
    return obj:IsA("BasePart") and (n:find("tree") or n:find("blossom") or n:find("cherry") or n:find("bloom"))
end

local function startAutoBloomery()
    if _bloomEventConn then _bloomEventConn:Disconnect() end
    _bloomActive = true
    print("[AutoBloomery] listening for tree event...")

    local function handleTree(obj)
        if not _bloomActive then return end
        if not isTreeObject(obj) then return end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or (obj.Position - hrp.Position).Magnitude > 100 then return end

        local wasRunning = State.running
        if wasRunning then State.running = false; State.busy = false end

        wearFieldBat()
        task.wait(0.3)

        local h = char and char:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = State.speed; h:MoveTo(obj.Position) end

        local t0 = tick()
        while tick() - t0 < 5 do
            local r2 = hrp
            if not r2 or not r2.Parent or (r2.Position - obj.Position).Magnitude <= 10 then break end
            task.wait(0.1)
        end

        startBatTree(obj)
        for _ = 1, 10 do
            if not obj.Parent then break end
            strikeTree(obj)
            gatherPetal()
            task.wait(0.3)
        end
        stopBatTree()

        if wasRunning then
            State.running = true
            task.spawn(function()
                walkTo(getBasePos(), 10, false)
                while State.running do farmCycle(); task.wait(0.05) end
            end)
        end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isTreeObject(obj) then task.spawn(function() handleTree(obj) end) end
    end
    _bloomEventConn = Workspace.DescendantAdded:Connect(function(obj)
        if _bloomActive then task.spawn(function() handleTree(obj) end) end
    end)
end

local function stopAutoBloomery()
    _bloomActive = false
    stopBatTree()
    if _bloomEventConn then _bloomEventConn:Disconnect(); _bloomEventConn = nil end
end

local _parasiteConn = nil
local function startAutoFeedParasite()
    if _parasiteConn then _parasiteConn:Disconnect() end
    _parasiteConn = RunService.Heartbeat:Connect(function()
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart"); if not myHRP then return end

        local net = getNet()
        local wearRemote = net and net:FindFirstChild("RF/EggWorld/AskWearTool")
        if EggState then
            local ok, owned = pcall(function() return EggState.ReadOwnerEggs(LocalPlayer.UserId) end)
            if ok and type(owned) == "table" then
                for uid, rec in pairs(owned) do
                    if type(uid) ~= "string" or not rec.HasParasite then continue end
                    if next(State.parasiteMinRarities) and not State.parasiteMinRarities["All"] then
                        local rarName = getRarityName(rec)
                        if not State.parasiteMinRarities[rarName] then continue end
                    end
                    if wearRemote then pcall(function() wearRemote:InvokeServer(uid) end) end
                end
            end
        end

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - myHRP.Position).Magnitude <= 15 then
                    for _, obj in ipairs(p.Character:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.ActionText:lower():find("parasite") then
                            pcall(function()
                                obj.HoldDuration = 0
                                if typeof(fireproximityprompt) == "function" then fireproximityprompt(obj, 0) end
                            end)
                            invokeRemote("RF/MonsterParasite/AskFeed", p); return
                        end
                    end
                end
            end
        end
    end)
end

local function stopAutoFeedParasite()
    if _parasiteConn then _parasiteConn:Disconnect(); _parasiteConn = nil end
end

local function claimParasiteChest()
    invokeRemote("RF/MonsterParasite/AskChestClaim"); task.wait(0.2)
    invokeRemote("RF/MonsterParasite/AskChestTake"); task.wait(0.2)
    invokeRemote("RF/MonsterParasite/AskChestRevealComplete")
end

local _guardWarnConn = nil
local function listenGuardWarning(cb)
    local n = getNet(); if not n then return end
    local remote = n:FindFirstChild("RE/GuardPatrol/SpeedTollWarning")
    if not remote then return end
    if _guardWarnConn then _guardWarnConn:Disconnect() end
    _guardWarnConn = remote.OnClientEvent:Connect(function(...)
        if cb then cb(...) end
    end)
end

-- ============================================================
-- LUNA INTERFACE SUITE (Louis Hub - Full Structure)
-- ============================================================
local Luna = nil
local lunaUrls = {
    "https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua",
    "https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/main/source.lua",
    "https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/main/source.lua"
}

for _, url in ipairs(lunaUrls) do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    if ok and res then
        Luna = res
        break
    end
end

if not Luna then
    warn("[Louis Hub] Failed to load Luna Interface Suite!")
    return
end

local function Notify(title, text)
    pcall(function()
        Luna:Notification({
            Title       = title,
            Icon        = "notifications_active",
            ImageSource = "Material",
            Content     = text
        })
    end)
end

local Window = Luna:CreateWindow({
    Name            = "Louis Hub",
    Subtitle        = "Steal An Egg",
    LogoID          = "82795327169782",
    LoadingEnabled  = true,
    LoadingTitle    = "Louis Hub",
    LoadingSubtitle = "Steal An Egg Script",
    ConfigSettings  = {
        RootFolder   = nil,
        ConfigFolder = "LouisHub"
    },
    KeySystem   = false,
    KeySettings = {
        Title       = "Louis Hub",
        Subtitle    = "Key System",
        Note        = "Keyless",
        SaveInRoot  = false,
        SaveKey     = false,
        Key         = {"1234"}
    }
})

Window:CreateHomeTab({
    SupportedExecutors = { "Synapse X", "Krnl", "Fluxus", "Delta", "Codex", "Wave", "Hydrogen", "Arceus X" },
    DiscordInvite      = "1234",
    Icon               = 1
})

-- ============================================================
-- TAB: FARM
-- ============================================================
local TabFarm = Window:CreateTab({
    Name        = "Farm",
    Icon        = "view_in_ar",
    ImageSource = "Material",
    ShowTitle   = true
})

TabFarm:CreateSection("Auto Steal")

TabFarm:CreateToggle({
    Name         = "Auto Steal",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v)
        State.running = v
        if v then
            State.instantSteal = false
            if not _speedBypassActive then pcall(initSpeedBypass) end
            loadModules()
            doHumanoidBypass()
            Notify("Louis Hub", "Auto Steal started!")
            task.spawn(function()
                while State.running do farmCycle(); task.wait(0.05) end
            end)
        else
            State.running = false; State.busy = false; State.lockedRecord = nil
            restoreHumanoid()
            Notify("Louis Hub", "Auto Steal stopped.")
        end
    end
}, "AutoSteal")

TabFarm:CreateToggle({
    Name         = "Instant Steal [BETA]",
    Description  = "Teleport to egg and back to base instantly (Under Development)",
    CurrentValue = false,
    Callback     = function(v)
        State.instantSteal = v
        if v then
            State.running = false
            if not _speedBypassActive then pcall(initSpeedBypass) end
            loadModules()
            doHumanoidBypass()
            Notify("Louis Hub", "Instant Steal [BETA] started!")
            task.spawn(function()
                while State.instantSteal do instantStealCycle(); task.wait(0.1) end
            end)
        else
            State.instantSteal = false; State.busy = false; State.lockedRecord = nil
            restoreHumanoid()
            Notify("Louis Hub", "Instant Steal [BETA] stopped.")
        end
    end
}, "InstantSteal")

TabFarm:CreateToggle({
    Name         = "Anti-Guard",
    Description  = nil,
    CurrentValue = true,
    Callback     = function(v) State.antiGuard = v end
}, "AntiGuard")

TabFarm:CreateToggle({
    Name         = "Bat Aura",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.batAura = v end
}, "BatAura")

TabFarm:CreateToggle({
    Name         = "No Knockback",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v)
        State.noKnockback = v
        if v then applyNoKnockback() end
    end
}, "NoKnockback")

TabFarm:CreateSlider({
    Name         = "Walk Speed (TPWalk)",
    Range        = {16, 500},
    Increment    = 1,
    CurrentValue = 120,
    Callback     = function(v) State.speed = v end
}, "SpeedSlider")

TabFarm:CreateSlider({
    Name         = "Return Speed",
    Range        = {16, 1000},
    Increment    = 1,
    CurrentValue = 180,
    Callback     = function(v) State.returnSpeed = v end
}, "ReturnSpeedSlider")

TabFarm:CreateDropdown({
    Name            = "Target Rarities",
    Description     = nil,
    Options         = RARITIES,
    CurrentOption   = { "All" },
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.targetRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.targetRarities[s] = true end
        elseif type(opts) == "string" then
            State.targetRarities[opts] = true
        end
    end
}, "TargetRarities")

TabFarm:CreateDropdown({
    Name            = "Target Areas",
    Description     = nil,
    Options         = AREA_NAMES,
    CurrentOption   = { "All" },
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.targetAreas = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.targetAreas[s] = true end
        elseif type(opts) == "string" then
            State.targetAreas[opts] = true
        end
    end
}, "TargetAreas")

TabFarm:CreateToggle({
    Name         = "Priority Rarity",
    Description  = nil,
    CurrentValue = true,
    Callback     = function(v) State.priorityRarity = v end
}, "PriorityRarity")

TabFarm:CreateDropdown({
    Name            = "Target Mutations",
    Description     = nil,
    Options         = MUTATIONS,
    CurrentOption   = { "All" },
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.targetMutations = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.targetMutations[s] = true end
        elseif type(opts) == "string" then
            State.targetMutations[opts] = true
        end
    end
}, "TargetMutations")

TabFarm:CreateInput({
    Name            = "Min Earning Rate",
    Description     = nil,
    PlaceholderText = "0 = Off",
    CurrentValue    = "0",
    Numeric         = true,
    MaxCharacters   = nil,
    Enter           = false,
    Callback        = function(v) State.minEarningRate = tonumber(v) or 0 end
}, "MinEarningRate")

TabFarm:CreateInput({
    Name            = "Min Weight (kg)",
    Description     = nil,
    PlaceholderText = "0 = Off",
    CurrentValue    = "0",
    Numeric         = true,
    MaxCharacters   = nil,
    Enter           = false,
    Callback        = function(v) State.minModelWeight = tonumber(v) or 0 end
}, "MinWeight")

TabFarm:CreateInput({
    Name            = "Max Weight (kg)",
    Description     = nil,
    PlaceholderText = "0 = Off",
    CurrentValue    = "0",
    Numeric         = true,
    MaxCharacters   = nil,
    Enter           = false,
    Callback        = function(v)
        local n = tonumber(v) or 0
        State.maxModelWeight = n == 0 and 999999999 or n
    end
}, "MaxWeight")

TabFarm:CreateToggle({
    Name         = "Cycle Panel",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) _cycleGui.Enabled = v end
}, "CyclePanel")

TabFarm:CreateSection("Auto Bloomery")

TabFarm:CreateToggle({
    Name         = "Auto Bloomery",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v)
        if v then task.spawn(startAutoBloomery) else stopAutoBloomery() end
    end
}, "AutoBloomery")

TabFarm:CreateButton({
    Name        = "Equip Field Bat",
    Description = nil,
    Callback    = function() pcall(wearFieldBat) end
})

TabFarm:CreateButton({
    Name        = "Gather Petal",
    Description = nil,
    Callback    = function() pcall(gatherPetal) end
})

TabFarm:CreateButton({
    Name        = "Mutate Egg",
    Description = nil,
    Callback    = function() pcall(mutateEgg) end
})

TabFarm:CreateSection("Monster Parasite")

TabFarm:CreateToggle({
    Name         = "Auto Feed Parasite",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v)
        if v then startAutoFeedParasite() else stopAutoFeedParasite() end
    end
}, "AutoFeedParasite")

TabFarm:CreateDropdown({
    Name            = "Min Rarity (Parasite Egg)",
    Description     = nil,
    Options         = RARITIES,
    CurrentOption   = { "All" },
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.parasiteMinRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.parasiteMinRarities[s] = true end
        elseif type(opts) == "string" then
            State.parasiteMinRarities[opts] = true
        end
    end
}, "ParasiteMinRarities")

TabFarm:CreateButton({
    Name        = "Claim Parasite Chest",
    Description = nil,
    Callback    = function()
        task.spawn(claimParasiteChest)
        Notify("Louis Hub", "Chest claimed!")
    end
})

-- ============================================================
-- TAB: AUTO
-- ============================================================
local TabAuto = Window:CreateTab({
    Name        = "Auto",
    Icon        = "dashboard",
    ImageSource = "Material",
    ShowTitle   = true
})

TabAuto:CreateSection("Auto Place Egg")

TabAuto:CreateToggle({
    Name         = "Enable Auto Place Egg",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.placeEnabled = v; if v then loadModules() end end
}, "PlaceEgg")

TabAuto:CreateSlider({
    Name         = "Place Interval (s)",
    Range        = {1, 120},
    Increment    = 1,
    CurrentValue = 5,
    Callback     = function(v) State.placeInterval = v end
}, "PlaceInterval")

TabAuto:CreateDropdown({
    Name            = "Min Rarity Egg",
    Description     = nil,
    Options         = RARITIES,
    CurrentOption   = { "All" },
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        local minNum = 999
        if type(opts) == "table" then
            for _, k in ipairs(opts) do
                if RARITY_ORDER[k] then minNum = math.min(minNum, RARITY_ORDER[k]) end
            end
        elseif type(opts) == "string" and RARITY_ORDER[opts] then
            minNum = RARITY_ORDER[opts]
        end
        State.placeMinRarity = minNum < 999 and (function()
            for k in pairs(RARITY_ORDER) do
                if RARITY_ORDER[k] == minNum then return k end
            end
            return "All"
        end)() or "All"
    end
}, "PlaceMinRarity")

TabAuto:CreateButton({
    Name        = "Place Now",
    Description = nil,
    Callback    = function()
        loadModules(); pcall(runAutoPlace); Notify("Louis Hub", "Place Triggered!")
    end
})

TabAuto:CreateSection("Auto Place Pet")

TabAuto:CreateToggle({
    Name         = "Enable Auto Place Pet",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.placePetEnabled = v; if v then loadModules() end end
}, "PlacePet")

TabAuto:CreateSlider({
    Name         = "Place Pet Interval (s)",
    Range        = {1, 120},
    Increment    = 1,
    CurrentValue = 5,
    Callback     = function(v) State.placePetInterval = v end
}, "PlacePetInterval")

TabAuto:CreateButton({
    Name        = "Place Pet Now",
    Description = nil,
    Callback    = function()
        loadModules(); pcall(runAutoPlacePet); Notify("Louis Hub", "Place Pet Triggered!")
    end
})

TabAuto:CreateSection("Auto Place Best Pet")

TabAuto:CreateToggle({
    Name         = "Enable Best Pet Place",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.placeBestPetEnabled = v; if v then loadModules() end end
}, "PlaceBestPet")

TabAuto:CreateSlider({
    Name         = "Place Best Interval (s)",
    Range        = {5, 60},
    Increment    = 1,
    CurrentValue = 10,
    Callback     = function(v) State.placeBestPetInterval = v end
}, "PlaceBestInterval")

TabAuto:CreateButton({
    Name        = "Place Best Now",
    Description = nil,
    Callback    = function()
        loadModules(); pcall(runAutoPlaceBestPet); Notify("Louis Hub", "Place Best Triggered!")
    end
})

TabAuto:CreateSection("Auto Hatch")

TabAuto:CreateToggle({
    Name         = "Enable Auto Hatch",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.hatchEnabled = v; if v then loadModules() end end
}, "HatchEgg")

TabAuto:CreateSlider({
    Name         = "Hatch Interval (s)",
    Range        = {1, 30},
    Increment    = 1,
    CurrentValue = 3,
    Callback     = function(v) State.hatchInterval = v end
}, "HatchInterval")

TabAuto:CreateButton({
    Name        = "Hatch Now",
    Description = nil,
    Callback    = function()
        loadModules(); pcall(runAutoHatch); Notify("Louis Hub", "Hatch Triggered!")
    end
})

TabAuto:CreateSection("Auto Favorite")

TabAuto:CreateToggle({
    Name         = "Auto Favorite Pet",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.favPetEnabled = v end
}, "FavPet")

TabAuto:CreateToggle({
    Name         = "Auto Favorite Egg",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.favEggEnabled = v end
}, "FavEgg")

TabAuto:CreateDropdown({
    Name            = "Target Rarities",
    Description     = nil,
    Options         = RARITIES,
    CurrentOption   = { "All" },
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.favMinRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.favMinRarities[s] = true end
        elseif type(opts) == "string" then
            State.favMinRarities[opts] = true
        end
    end
}, "FavRarities")

TabAuto:CreateButton({
    Name        = "Favorite Now",
    Description = nil,
    Callback    = function()
        pcall(runAutoFavorite); Notify("Louis Hub", "Favorite Done!")
    end
})

-- ============================================================
-- TAB: STORE
-- ============================================================
local TabStore = Window:CreateTab({
    Name        = "Store",
    Icon        = "directions_run",
    ImageSource = "Material",
    ShowTitle   = true
})

TabStore:CreateSection("Auto Sell Pet")

TabStore:CreateToggle({
    Name         = "Enable Auto Sell Pet",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.sellEnabled = v; if v then loadModules() end end
}, "SellPetEnable")

TabStore:CreateToggle({
    Name         = "Sell Every Pet",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.sellAll = v end
}, "SellEveryPet")

TabStore:CreateSlider({
    Name         = "Sell Pet Interval (s)",
    Range        = {1, 120},
    Increment    = 1,
    CurrentValue = 5,
    Callback     = function(v) State.sellInterval = v end
}, "SellPetInterval")

TabStore:CreateDropdown({
    Name            = "Sell Pet Rarities",
    Description     = nil,
    Options         = RARITIES,
    CurrentOption   = { "Common" },
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.sellPetMaxRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.sellPetMaxRarities[s] = true end
        elseif type(opts) == "string" then
            State.sellPetMaxRarities[opts] = true
        end
    end
}, "SellPetRarities")

TabStore:CreateButton({
    Name        = "Sell Pet Now",
    Description = nil,
    Callback    = function()
        loadModules(); pcall(runAutoSellPet); Notify("Louis Hub", "Sell Pet Triggered!")
    end
})

TabStore:CreateSection("Auto Sell Egg")

TabStore:CreateToggle({
    Name         = "Enable Auto Sell Egg",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.sellEggEnabled = v; if v then loadModules() end end
}, "SellEggEnable")

TabStore:CreateSlider({
    Name         = "Sell Egg Interval (s)",
    Range        = {1, 120},
    Increment    = 1,
    CurrentValue = 10,
    Callback     = function(v) State.sellEggInterval = v end
}, "SellEggInterval")

TabStore:CreateDropdown({
    Name            = "Sell Egg Rarities",
    Description     = nil,
    Options         = RARITIES,
    CurrentOption   = { "Common" },
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.sellEggMaxRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.sellEggMaxRarities[s] = true end
        elseif type(opts) == "string" then
            State.sellEggMaxRarities[opts] = true
        end
    end
}, "SellEggRarities")

TabStore:CreateButton({
    Name        = "Sell Egg Now",
    Description = nil,
    Callback    = function()
        loadModules(); pcall(runAutoSellEgg); Notify("Louis Hub", "Sell Egg Triggered!")
    end
})

TabStore:CreateSection("Collect Money")

TabStore:CreateToggle({
    Name         = "Auto Collect Offline Earnings",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.collectEnabled = v end
}, "CollectEnable")

TabStore:CreateSlider({
    Name         = "Collect Interval (s)",
    Range        = {10, 300},
    Increment    = 1,
    CurrentValue = 60,
    Callback     = function(v) State.collectInterval = v end
}, "CollectInterval")

TabStore:CreateButton({
    Name        = "Collect Now",
    Description = nil,
    Callback    = function()
        pcall(runCollectMoney); Notify("Louis Hub", "Collected!")
    end
})

TabStore:CreateSection("Haul & Codex")

TabStore:CreateButton({
    Name        = "Wear Best Pet",
    Description = nil,
    Callback    = function() pcall(wearBest) end
})

TabStore:CreateButton({
    Name        = "Sell Full Satchel",
    Description = nil,
    Callback    = function() pcall(sellFullSatchel) end
})

TabStore:CreateButton({
    Name        = "Redeem All Codex",
    Description = nil,
    Callback    = function() pcall(redeemAllCodex) end
})

TabStore:CreateSection("Fuse Machine")

local _fuseUids = {}
TabStore:CreateInput({
    Name            = "Pet UID 1",
    Description     = nil,
    PlaceholderText = "Paste Pet UID 1",
    CurrentValue    = "",
    Numeric         = false,
    MaxCharacters   = nil,
    Enter           = false,
    Callback        = function(v) _fuseUids[1] = v end
}, "FuseUID1")

TabStore:CreateInput({
    Name            = "Pet UID 2",
    Description     = nil,
    PlaceholderText = "Paste Pet UID 2",
    CurrentValue    = "",
    Numeric         = false,
    MaxCharacters   = nil,
    Enter           = false,
    Callback        = function(v) _fuseUids[2] = v end
}, "FuseUID2")

TabStore:CreateInput({
    Name            = "Pet UID 3",
    Description     = nil,
    PlaceholderText = "Paste Pet UID 3",
    CurrentValue    = "",
    Numeric         = false,
    MaxCharacters   = nil,
    Enter           = false,
    Callback        = function(v) _fuseUids[3] = v end
}, "FuseUID3")

TabStore:CreateButton({
    Name        = "Auto Fuse Pets",
    Description = nil,
    Callback    = function()
        if _fuseUids[1] and _fuseUids[2] and _fuseUids[3] then
            task.spawn(function() autoFuse(_fuseUids[1], _fuseUids[2], _fuseUids[3]) end)
            Notify("Louis Hub", "Fuse Started!")
        else
            Notify("Louis Hub", "Fill all 3 UIDs first!")
        end
    end
})

-- ============================================================
-- TAB: MISC
-- ============================================================
local TabMisc = Window:CreateTab({
    Name        = "Misc",
    Icon        = "settings",
    ImageSource = "Material",
    ShowTitle   = true
})

TabMisc:CreateSection("Visual")

TabMisc:CreateToggle({
    Name         = "Egg ESP",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v)
        State.espEnabled = v
        if not v then for uid in pairs(EspHighlights) do clearESP(uid) end end
    end
}, "EggESP")

TabMisc:CreateToggle({
    Name         = "Float (Visual)",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.floatEnabled = v; updateFloat() end
}, "FloatToggle")

TabMisc:CreateSlider({
    Name         = "Float Height",
    Range        = {1, 10},
    Increment    = 1,
    CurrentValue = 3,
    Callback     = function(v) State.floatHeight = v end
}, "FloatHeight")

TabMisc:CreateToggle({
    Name         = "Character Animation",
    Description  = nil,
    CurrentValue = true,
    Callback     = function(v) State.animEnabled = v; updateAnim() end
}, "CharAnim")

TabMisc:CreateToggle({
    Name         = "FPS & Ping Counter",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) updateStatsGui(v) end
}, "StatsGuiToggle")

TabMisc:CreateToggle({
    Name         = "Reduce Map (Boost FPS)",
    Description  = nil,
    CurrentValue = false,
    Callback     = function(v) State.reducedMap = v; setReduceMap(v) end
}, "ReduceMapToggle")

TabMisc:CreateButton({
    Name        = "Upgrade Base",
    Description = nil,
    Callback    = function() upgradeBase() end
})

TabMisc:CreateButton({
    Name        = "Upgrade Treadmill",
    Description = nil,
    Callback    = function() upgradeTreadmill(1) end
})

TabMisc:CreateSection("Utility")

TabMisc:CreateToggle({
    Name         = "Anti AFK",
    Description  = nil,
    CurrentValue = true,
    Callback     = function(v) State.antiAfk = v; setAntiAfk(v) end
}, "AntiAFK")

TabMisc:CreateToggle({
    Name         = "Anti Staff",
    Description  = nil,
    CurrentValue = true,
    Callback     = function(v)
        if v then
            task.spawn(function()
                while v do
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer then
                            local badge = p:GetAttribute("IsStaff") or p:GetAttribute("Staff")
                            if badge then
                                State.running = false
                                State.instantSteal = false
                                Notify("Louis Hub", "Staff detected: " .. p.Name)
                            end
                        end
                    end
                    task.wait(3)
                end
            end)
        end
    end
}, "AntiStaff")

TabMisc:CreateButton({
    Name        = "Rejoin Server",
    Description = nil,
    Callback    = function()
        pcall(function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end
})

TabMisc:CreateButton({
    Name        = "Server Hop",
    Description = nil,
    Callback    = function()
        pcall(function()
            local HS = game:GetService("HttpService")
            local TPS = game:GetService("TeleportService")
            local result = HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
            local servers = {}
            for _, s in ipairs(result.data or {}) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    table.insert(servers, s)
                end
            end
            if #servers > 0 then
                TPS:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)].id, LocalPlayer)
            else
                Notify("Louis Hub", "No servers found")
            end
        end)
    end
})

TabMisc:CreateButton({
    Name        = "Listen Guard Warning",
    Description = nil,
    Callback    = function()
        listenGuardWarning(function(...) Notify("Louis Hub", "Guard Warning!") end)
    end
})

TabMisc:CreateSection("Keybinds")

TabMisc:CreateBind({
    Name              = "Toggle UI",
    Description       = nil,
    CurrentBind       = "F3",
    HoldToInteract    = false,
    Callback          = function()
        pcall(function()
            if Window and Window.Toggle then
                Window:Toggle()
            end
        end)
    end,
    OnChangedCallback = function() end
}, "ToggleUIBind")

-- ============================================================
-- TAB: CONFIG
-- ============================================================
local TabConfig = Window:CreateTab({
    Name        = "Config",
    Icon        = "palette",
    ImageSource = "Material",
    ShowTitle   = true
})

TabConfig:CreateSection("Config")

TabConfig:CreateButton({
    Name        = "Save Config",
    Description = nil,
    Callback    = function() Notify("Louis Hub", "Config Saved!") end
})

TabConfig:CreateSection("Theme")
TabConfig:BuildThemeSection()

-- ============================================================
-- AUTO STARTUP
-- ============================================================
Notify("Louis Hub", "Steal An Egg v2.0 loaded successfully!")

task.spawn(function()
    task.wait(2)
    setAntiAfk(true)
    task.spawn(function()
        while true do
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local badge = p:GetAttribute("IsStaff") or p:GetAttribute("Staff")
                    if badge then
                        State.running = false
                        State.instantSteal = false
                        Notify("Louis Hub", "Staff in server: " .. p.Name)
                    end
                end
            end
            task.wait(3)
        end
    end)
end)
