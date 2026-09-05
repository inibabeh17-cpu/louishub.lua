-- ============================================================
--  LOUIS HUB - STEAL AN EGG (Luna Interface Suite Edition)
--  Clean architecture, 100% Full Features in English
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
-- STATE (Hardcoded Default Speeds: 500 to Egg, 1000 Return)
-- ============================================================
local State = {
    -- Farm
    running              = false,
    busy                 = false,
    stealCount           = 0,
    lockedRecord         = nil,
    -- Movement (Hardcoded high-speed values)
    speed                = 500,  -- 500 TPWalk when going to egg
    returnSpeed          = 1000, -- 1000 TPWalk when returning in the air
    antiGuard            = true,
    -- Farm rarity filter
    targetRarities       = {},
    priorityRarity       = true,
    targetAreas          = {},
    minEarningRate       = 0,
    minModelWeight       = 0,
    maxModelWeight       = 999999999,
    -- Float
    floatEnabled         = false,
    floatHeight          = 3,
    -- Animation
    animEnabled          = true,
    -- Auto Place
    placeEnabled         = false,
    placeInterval        = 5,
    placeMinRarity       = "All",
    -- Auto Place Pet
    placePetEnabled      = false,
    placePetInterval     = 5,
    placeBestPetEnabled  = false,
    placeBestPetInterval = 10,
    -- No Knockback
    noKnockback          = false,
    -- Backpack threshold auto place
    _placing             = false,
    placeThreshold       = 50,
    -- Collect Money
    collectEnabled       = false,
    collectInterval      = 60,
    -- Auto Favorite
    favPetEnabled        = false,
    favEggEnabled        = false,
    favoriteInterval     = 30,
    favMinRarities       = {},
    favMutations         = {},
    favMinWeight         = 0,
    favMaxWeight         = 0,
    favMinValue          = 0,
    -- Auto Hatch
    hatchEnabled         = false,
    hatchInterval        = 3,
    -- Auto Sell
    sellEnabled          = false,
    sellAll              = false,
    sellInterval         = 5,
    sellMaxRarities      = {},
    -- Auto Sell Egg
    sellEggEnabled       = false,
    sellEggInterval      = 10,
    sellEggMaxRarities   = {},
    sellEggMaxRarity     = "All",
    -- Auto Sell Pet
    sellPetMaxRarities   = {},
    sellPetInterval      = 5,
    -- Bat Aura
    batAura              = false,
    batInterval          = 0.1,
    -- ESP
    espEnabled           = false,
    -- Mutation filter
    targetMutations      = {},
    -- Monster Parasite
    parasiteMinRarities  = {},
    -- Misc
    reducedMap           = false,
    antiAfk              = false,
}

-- Base teleport coordinates
local START_POS = Vector3.new(519.155, 70.576, -356.103)
local SAFE_POS  = Vector3.new(519.155, 70.576, -356.103)

-- ============================================================
-- HELPERS
-- ============================================================
local function root()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function hum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
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
    "Forest","Lake","Desert","Jungle","Snow","Volcano",
    "Abyss Ocean","Prehistoric","Cosmic","Cherry Blossom","Titan Temple"
}
local AREA_SET = {}
for _, a in ipairs(AREA_NAMES) do AREA_SET[a] = true end

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

-- Check if player holds or carries an egg tool
local function hasEgg()
    local char = LocalPlayer.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and (t:GetAttribute("ItemType") == "AssetEgg" or t:GetAttribute("ItemType") == "PetEgg" or AREA_SET[t.Name]) then
                return true
            end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and (t:GetAttribute("ItemType") == "AssetEgg" or t:GetAttribute("ItemType") == "PetEgg" or AREA_SET[t.Name]) then
                return true
            end
        end
    end
    return false
end

local MUTATIONS = {"Silver", "Bloom", "Golden", "Rainbow", "Spirit Bloom"}

local function isMutationAllowed(record)
    if not next(State.targetMutations) then return true end
    if not record or not record.Mutations then return false end
    if type(record.Mutations) ~= "table" then return false end
    for mutName in pairs(State.targetMutations) do
        for k, v in pairs(record.Mutations) do
            local name = type(k) == "string" and k or tostring(v)
            if name:lower():find(mutName:lower()) then return true end
        end
    end
    return false
end

local function isRarityAllowed(record)
    if not next(State.targetRarities) then return true end
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
    if not next(State.targetAreas) then return true end
    local areaId = tostring(rec.AreaId or "")
    if State.targetAreas[areaId] then return true end
    local cat = tostring(rec.AssetCategory or "")
    for area in pairs(State.targetAreas) do
        if cat:lower():find(area:lower(), 1, true) then return true end
    end
    return false
end

local function applyNoKnockback()
    if type(getconnections) ~= "function" then
        warn("[NoKnockback] getconnections not available"); return
    end
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
-- HUMANOID BYPASS (Spoofer - Clones & Destroys original)
-- ============================================================
local _camConn = nil
local _speedConn = nil

local function doHumanoidBypass()
    local char = LocalPlayer.Character
    if not char then char = LocalPlayer.CharacterAdded:Wait() end

    local origHum  = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not origHum or not rootPart then return end

    pcall(function()
        local clone = origHum:Clone()
        clone.WalkSpeed   = 16
        clone.JumpPower   = origHum.JumpPower
        clone.MaxHealth   = origHum.MaxHealth
        clone.Health      = origHum.Health
        clone.AutoRotate  = origHum.AutoRotate
        clone.DisplayName = origHum.DisplayName
        clone.Parent      = char
        task.wait(0.05)
        origHum:Destroy()

        if rootPart and rootPart.Parent then
            rootPart.CFrame                  = CFrame.new(START_POS + Vector3.new(0, 3.2, 0))
            rootPart.AssemblyLinearVelocity  = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end

        task.wait(0.05)
        clone.PlatformStand = false
        clone.Sit           = false
        pcall(function() clone:ChangeState(Enum.HumanoidStateType.Running) end)
        workspace.CurrentCamera.CameraSubject = clone
        print("[Louis Hub] Humanoid spoofer bypass OK")
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

LocalPlayer.CharacterAdded:Connect(function()
    if State.running then
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
                r.CFrame = CFrame.new(START_POS + Vector3.new(0, 4, 0))
            end)
            print("[AntiVoid] Prevented falling into void! Safely returned to base.")
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
-- MOVEMENT (500 TPWalk - Smooth & Stutter-Free)
-- ============================================================
local function walkTo(goal, timeout, checkFn)
    local h2 = hum()
    local r  = root()
    if not h2 or not r then return false end
    if typeof(goal) == "Instance" then goal = goal.Position end

    timeout = timeout or 25
    local speed = 500 -- Fixed 500 TPWalk to egg
    local targetDist = 5

    h2.WalkSpeed = 16
    h2:MoveTo(goal)

    local t0 = workspace.DistributedGameTime
    local lastPos = r.Position
    local stuckT = t0
    local shouldContinue = checkFn or function() return State.running end

    while workspace.DistributedGameTime - t0 < timeout do
        if not shouldContinue() then break end
        local dt = RunService.Heartbeat:Wait()
        r = root(); h2 = hum()
        if not r or not h2 then break end

        local toGoal = Vector3.new(goal.X - r.Position.X, 0, goal.Z - r.Position.Z)
        local dist = toGoal.Magnitude

        if dist <= targetDist then
            h2.WalkSpeed = 0
            h2:Move(Vector3.zero, false)
            r.AssemblyLinearVelocity = r.AssemblyLinearVelocity * 0.5
            r.AssemblyAngularVelocity = Vector3.zero
            break
        end

        -- Continuous TPWalk translation towards egg while running
        if State.running and dist > 0.1 then
            local step = math.min(speed * dt, dist)
            r.CFrame = r.CFrame + (toGoal.Unit * step)
        end
        h2:MoveTo(goal)

        local now = workspace.DistributedGameTime
        if now - stuckT >= 2 then
            if (r.Position - lastPos).Magnitude < 0.5 then
                h2:MoveTo(goal)
                h2.Jump = true
            end
            lastPos = r.Position
            stuckT = now
        end
    end

    h2 = hum()
    if h2 then h2.WalkSpeed = 16 end
    return true
end

-- ============================================================
-- AERIAL RETURN (1000 TPWalk - Gliding Above Guardian Reach)
-- ============================================================
local function walkToAir(airGoal, timeout)
    local r = root()
    local h2 = hum()
    if not r or not h2 then return false end
    timeout = timeout or 15
    local speed = 1000 -- Fixed 1000 TPWalk return in the sky
    local t0 = workspace.DistributedGameTime

    while workspace.DistributedGameTime - t0 < timeout do
        if not State.running then break end
        -- Cancel return immediately if egg was knocked out of player possession mid-flight
        if not hasEgg() then
            return false
        end

        local dt = RunService.Heartbeat:Wait()
        r = root(); h2 = hum()
        if not r or not h2 then break end

        local delta = airGoal - r.Position
        local dist = delta.Magnitude

        if dist <= 8 then
            r.AssemblyLinearVelocity = Vector3.zero
            break
        end

        -- Glide rapidly through the sky out of guardian reach
        local step = math.min(speed * dt, dist)
        r.CFrame = r.CFrame + (delta.Unit * step)
        r.AssemblyLinearVelocity = Vector3.new(0, 1, 0)
    end
    return true
end

-- ============================================================
-- EGG FINDER (Enhanced reliable lookup)
-- ============================================================
local function findBestEgg()
    if not loadModules() then return nil, nil end
    local ok, fieldEggs = pcall(function() return EggState.ReadFieldEggs() end)
    if not ok or not fieldEggs or not fieldEggs.Records then return nil, nil end

    local r = root()
    if not r then return nil, nil end

    local clientFolder = Workspace:FindFirstChild("AreaEggSlotsClient", true)

    if State.lockedRecord then
        for _, rec in ipairs(fieldEggs.Records) do
            if rec.Uid == State.lockedRecord.Uid then
                if isRarityAllowed(rec) and isValueAllowed(rec) and isMutationAllowed(rec) and isAreaAllowed(rec) then
                    local model = clientFolder and (clientFolder:FindFirstChild(rec.Uid) or clientFolder:FindFirstChild(rec.Uid, true))
                    if not model then model = Workspace:FindFirstChild(rec.Uid, true) end
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

        local model = clientFolder and (clientFolder:FindFirstChild(rec.Uid) or clientFolder:FindFirstChild(rec.Uid, true))
        if not model then model = Workspace:FindFirstChild(rec.Uid, true) end

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
-- AUTO PLACE
-- ============================================================
local function runAutoPlace()
    if not PlotState then loadModules() end
    if not PlotState then return end
    pcall(function()
        local myPlot = PlotState.ResolvePlot()
        if not myPlot or not myPlot.CenterPoint or not myPlot.PetArea then
            warn("[AutoPlace] ResolvePlot failed"); return
        end

        local plotPos = myPlot.CenterPoint.Position
        local r = root()
        if r and (r.Position - plotPos).Magnitude > 5 then
            walkTo(plotPos, 15, function() return State.placeEnabled end)
        end
        task.wait(0.3)

        local net = ReplicatedStorage:FindFirstChild("Packages")
            and ReplicatedStorage.Packages:FindFirstChild("Networking")
        local placeRemote = net and net:FindFirstChild("RF/EggWorld/AskPlaceEgg")
        local wearRemote  = net and net:FindFirstChild("RF/EggWorld/AskWearTool")
        if not placeRemote then warn("[AutoPlace] AskPlaceEgg not found"); return end

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
            return CFrame.new(localPos) * CFrame.fromMatrix(
                Vector3.zero,
                Vector3.new(0,0,-1),
                Vector3.new(0,1,0),
                Vector3.new(1,0,0)
            )
        end

        if not EggState then
            print("[AutoPlace] EggState nil"); return
        end

        local syncOk, syncErr = pcall(function() EggState.SyncOwnedEggs() end)
        if not syncOk then
            warn("[AutoPlace] SyncOwnedEggs error:", tostring(syncErr))
        end
        task.wait(0.3)

        local ok, owned = pcall(function()
            return EggState.ReadOwnerEggs(LocalPlayer.UserId)
        end)
        if not ok or type(owned) ~= "table" or not next(owned) then
            print("[AutoPlace] owned eggs empty"); return
        end

        local minRarNum = RARITY_ORDER[State.placeMinRarity] or 0
        local placed = 0
        local skippedPlacement = 0
        local MAX_PER_RUN = 10

        for k, rec in pairs(owned) do
            if placed >= MAX_PER_RUN then break end
            local uid
            if type(k) == "string" then
                uid = k
            elseif type(rec) == "table" and rec.Uid then
                uid = rec.Uid
            end
            if not uid or type(k) ~= "string" then continue end

            if rec.Placement ~= nil then
                skippedPlacement += 1
                continue
            end

            if minRarNum > 0 then
                local rarNum = 0
                if rec.Rarity and type(rec.Rarity) == "table" then
                    rarNum = rec.Rarity.RarityNumber or 0
                elseif rec.RarityNumber and type(rec.RarityNumber) == "number" then
                    rarNum = rec.RarityNumber
                end
                if rarNum > 0 and rarNum < minRarNum then continue end
            end

            local eggTool = nil
            for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if t:IsA("Tool") then
                    local itype = t:GetAttribute("ItemType")
                    if itype == "AssetEgg" or itype == "PetEgg" then
                        eggTool = t
                        break
                    end
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
            local ok3, res = pcall(function()
                return placeRemote:InvokeServer({Uid = uid, LocalCFrame = localCFrame})
            end)
            warn(">>>PLACE<<< ok="..tostring(ok3).." res="..tostring(res).." uid="..uid:sub(1,8))
            if ok3 and res == true then placed += 1 end
            task.wait(0.1)
        end
        print(string.format("[AutoPlace] DONE placed=%d skipped=%d", placed, skippedPlacement))
    end)
end

task.spawn(function()
    while true do
        task.wait(State.placeInterval or 5)
        if not State.placeEnabled then continue end
        if State._placing then continue end
        if not EggState then loadModules() end
        State._placing = true
        local wasRunning = State.running
        if wasRunning then State.running = false; State.busy = false end
        pcall(runAutoPlace)
        if wasRunning then
            State.running = true
            task.spawn(function()
                walkTo(START_POS, 10)
                while State.running do farmCycle(); task.wait(0.05) end
            end)
        end
        State._placing = false
    end
end)

-- ============================================================
-- ANTI-STUCK TREADMILL
-- ============================================================
task.spawn(function()
    local lastGoalDist = math.huge
    local stuckTimer   = 0
    while true do
        task.wait(0.5)
        if not State.running and not State.busy then
            stuckTimer = 0; lastGoalDist = math.huge; continue
        end
        local char = LocalPlayer.Character
        local r    = char and char:FindFirstChild("HumanoidRootPart")
        local h    = char and char:FindFirstChildOfClass("Humanoid")
        if not r or not h then stuckTimer = 0; continue end

        local vel   = r.AssemblyLinearVelocity
        local hVel  = Vector3.new(vel.X, 0, vel.Z).Magnitude
        local speed = h.WalkSpeed

        if State.busy then stuckTimer = 0; continue end

        local isTreadmillPush = hVel > (speed * 1.5) and hVel > 20

        if isTreadmillPush then
            stuckTimer += 1
            if stuckTimer >= 2 then
                pcall(function()
                    local opposite = Vector3.new(-vel.X, 60, -vel.Z).Unit * speed * 3
                    r.AssemblyLinearVelocity = opposite
                end)
                h.PlatformStand = false
                h.Sit           = false
                h.Jump          = true
                pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
                pcall(function() h:MoveTo(r.Position + Vector3.new(-vel.X, 0, -vel.Z).Unit * 10) end)
                stuckTimer = 0
                print("[AntiStuck] treadmill escape triggered, hVel=" .. math.floor(hVel))
            end
        else
            stuckTimer = 0
        end
    end
end)

-- ============================================================
-- CYCLE PANEL
-- ============================================================
local _cycleGui = Instance.new("ScreenGui")
_cycleGui.Name = "SAE_CyclePanel"
_cycleGui.ResetOnSpawn = false
_cycleGui.IgnoreGuiInset = true
_cycleGui.DisplayOrder = 99997
_cycleGui.Enabled = false

task.spawn(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 10)
    if pg then _cycleGui.Parent = pg end
end)

local _cycleFrame = Instance.new("Frame")
_cycleFrame.Size = UDim2.fromOffset(220, 260)
_cycleFrame.Position = UDim2.new(1, -230, 0.5, -130)
_cycleFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
_cycleFrame.BackgroundTransparency = 0.08
_cycleFrame.BorderSizePixel = 0
_cycleFrame.Active = true
_cycleFrame.ClipsDescendants = true
_cycleFrame.Parent = _cycleGui

do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = _cycleFrame
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255,255,255); s.Transparency = 0.88; s.Thickness = 1; s.Parent = _cycleFrame
end

do
    local dragging, dragStart, startPos = false, nil, nil
    _cycleFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = _cycleFrame.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            local d = inp.Position - dragStart
            _cycleFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local _cycleTopBg = Instance.new("Frame")
_cycleTopBg.Size = UDim2.new(1, 0, 0, 86)
_cycleTopBg.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
_cycleTopBg.BackgroundTransparency = 0.3
_cycleTopBg.BorderSizePixel = 0
_cycleTopBg.Parent = _cycleFrame

local _cycleTitle = Instance.new("TextLabel")
_cycleTitle.Size = UDim2.new(1, 0, 0, 20); _cycleTitle.Position = UDim2.new(0, 0, 0, 10)
_cycleTitle.BackgroundTransparency = 1; _cycleTitle.Text = "EGG CYCLE"
_cycleTitle.TextColor3 = Color3.fromRGB(160, 160, 180); _cycleTitle.TextSize = 10
_cycleTitle.Font = Enum.Font.GothamBold; _cycleTitle.TextXAlignment = Enum.TextXAlignment.Center
_cycleTitle.Parent = _cycleTopBg

local _cycleTimer = Instance.new("TextLabel")
_cycleTimer.Size = UDim2.new(1, 0, 0, 44); _cycleTimer.Position = UDim2.new(0, 0, 0, 26)
_cycleTimer.BackgroundTransparency = 1; _cycleTimer.Text = "5:00"
_cycleTimer.TextColor3 = Color3.fromRGB(80, 220, 120); _cycleTimer.TextSize = 36
_cycleTimer.Font = Enum.Font.GothamBold; _cycleTimer.Parent = _cycleTopBg

local _cycleBarBg = Instance.new("Frame")
_cycleBarBg.Size = UDim2.new(1, -20, 0, 4); _cycleBarBg.Position = UDim2.new(0, 10, 0, 76)
_cycleBarBg.BackgroundColor3 = Color3.fromRGB(35, 35, 45); _cycleBarBg.BorderSizePixel = 0
_cycleBarBg.Parent = _cycleTopBg
Instance.new("UICorner", _cycleBarBg).CornerRadius = UDim.new(1, 0)
local _cycleBar = Instance.new("Frame")
_cycleBar.Size = UDim2.new(1, 0, 1, 0); _cycleBar.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
_cycleBar.BorderSizePixel = 0; _cycleBar.Parent = _cycleBarBg
Instance.new("UICorner", _cycleBar).CornerRadius = UDim.new(1, 0)

local _div = Instance.new("Frame")
_div.Size = UDim2.new(1, -20, 0, 1); _div.Position = UDim2.new(0, 10, 0, 92)
_div.BackgroundColor3 = Color3.fromRGB(255, 255, 255); _div.BackgroundTransparency = 0.88
_div.BorderSizePixel = 0; _div.Parent = _cycleFrame

local _cycleEggLabel = Instance.new("TextLabel")
_cycleEggLabel.Size = UDim2.new(1, -16, 0, 14); _cycleEggLabel.Position = UDim2.new(0, 8, 0, 98)
_cycleEggLabel.BackgroundTransparency = 1; _cycleEggLabel.Text = "FIELD EGGS"
_cycleEggLabel.TextColor3 = Color3.fromRGB(100, 100, 120); _cycleEggLabel.TextSize = 9
_cycleEggLabel.Font = Enum.Font.GothamBold; _cycleEggLabel.TextXAlignment = Enum.TextXAlignment.Left
_cycleEggLabel.Parent = _cycleFrame

local _cycleScroll = Instance.new("ScrollingFrame")
_cycleScroll.Size = UDim2.new(1, -8, 0, 138); _cycleScroll.Position = UDim2.new(0, 4, 0, 116)
_cycleScroll.BackgroundTransparency = 1; _cycleScroll.BorderSizePixel = 0
_cycleScroll.ScrollBarThickness = 2; _cycleScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
_cycleScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; _cycleScroll.CanvasSize = UDim2.new(0,0,0,0)
_cycleScroll.Parent = _cycleFrame
local _cycleList = _cycleScroll
local _cycleListLayout = Instance.new("UIListLayout")
_cycleListLayout.SortOrder = Enum.SortOrder.LayoutOrder; _cycleListLayout.Padding = UDim.new(0, 2)
_cycleListLayout.Parent = _cycleList

local RARITY_COLORS = {
    Common="#9e9e9e", Uncommon="#4caf50", Rare="#2196f3", Epic="#9c27b0",
    Legendary="#ff9800", Mythic="#f44336", Divine="#00bcd4", Secret="#607d8b",
    Cosmic="#e91e63", Eternal="#00e676", Celestial="#ffeb3b", Transcendent="#ff5722",
    Prismatic="#e040fb", Rainbow="#ff4081", Brainrot="#8bc34a", Mythical="#ffc107",
    Exclusive="#ff6d00", Titan="#78909c", SuperRare="#29b6f6", Exotic="#26c6da",
}
local function rarityColor(name)
    local hex = RARITY_COLORS[name] or "#ffffff"
    local r, g, b = hex:match("#(%x%x)(%x%x)(%x%x)")
    if r then return Color3.fromRGB(tonumber(r,16), tonumber(g,16), tonumber(b,16)) end
    return Color3.new(1,1,1)
end

local _cycleStart = tick()
local CYCLE_DURATION = 300

task.spawn(function()
    while true do
        task.wait(0.5)
        if not _cycleGui.Enabled then continue end
        local elapsed = (tick() - _cycleStart) % CYCLE_DURATION
        local remaining = CYCLE_DURATION - elapsed
        _cycleTimer.Text = string.format("%d:%02d", math.floor(remaining/60), math.floor(remaining%60))
        local urgent = remaining < 30
        local col = urgent and Color3.fromRGB(240, 60, 60) or Color3.fromRGB(80, 220, 120)
        _cycleTimer.TextColor3 = col
        _cycleBar.BackgroundColor3 = col
        _cycleBar.Size = UDim2.new(remaining / CYCLE_DURATION, 0, 1, 0)
        for _, c in ipairs(_cycleList:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        if EggState and EggState.ReadFieldEggs then
            local ok, fieldData = pcall(function() return EggState.ReadFieldEggs() end)
            if ok and fieldData and fieldData.Records then
                local shown = 0
                for _, rec in ipairs(fieldData.Records) do
                    if shown >= 12 then break end
                    local rarName = getRarityName(rec)
                    local col2 = rarityColor(rarName)
                    local row = Instance.new("Frame")
                    row.Size = UDim2.new(1, -4, 0, 20); row.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
                    row.BackgroundTransparency = 0.4; row.BorderSizePixel = 0
                    row.LayoutOrder = shown; row.Parent = _cycleList
                    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
                    local bar = Instance.new("Frame")
                    bar.Size = UDim2.new(0, 3, 1, -4); bar.Position = UDim2.new(0, 4, 0, 2)
                    bar.BackgroundColor3 = col2; bar.BorderSizePixel = 0; bar.Parent = row
                    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, -16, 1, 0); lbl.Position = UDim2.new(0, 12, 0, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = (rec.AssetCategory or "?").."  "..rarName
                    lbl.TextColor3 = Color3.fromRGB(220, 220, 230); lbl.TextSize = 10
                    lbl.Font = Enum.Font.Gotham; lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.Parent = row; shown += 1
                end
            end
        end
    end
end)

-- ============================================================
-- AUTO PLACE PET & BEST PET
-- ============================================================
local function runAutoPlacePet()
    if not PlotState then loadModules() end
    if not PlotState then return end
    pcall(function()
        local myPlot = PlotState.ResolvePlot()
        if not myPlot or not myPlot.CenterPoint or not myPlot.PetArea then return end

        local plotPos = myPlot.CenterPoint.Position
        local r = root()
        if r and (r.Position - plotPos).Magnitude > 5 then
            walkTo(plotPos, 15, function() return State.placePetEnabled end)
        end
        task.wait(0.3)

        local net = ReplicatedStorage:FindFirstChild("Packages")
            and ReplicatedStorage.Packages:FindFirstChild("Networking")
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
                print("[AutoPlacePet] placed:", tool.Name)
            else
                pcall(function() tool.Parent = LocalPlayer.Backpack end)
            end
            task.wait(0.1)
        end
        print(string.format("[AutoPlacePet] total placed=%d", placed))
    end)
end

task.spawn(function()
    while true do
        task.wait(State.placePetInterval or 5)
        if not State.placePetEnabled then continue end
        if State._placing then continue end
        State._placing = true
        local wasRunning = State.running
        if wasRunning then State.running = false; State.busy = false end
        pcall(runAutoPlacePet)
        if wasRunning then
            State.running = true
            task.spawn(function()
                walkTo(START_POS, 10)
                while State.running do farmCycle(); task.wait(0.05) end
            end)
        end
        State._placing = false
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
            walkTo(plotPos, 15, function() return State.placeBestPetEnabled end)
        end
        task.wait(0.3)

        local net = ReplicatedStorage:FindFirstChild("Packages")
            and ReplicatedStorage.Packages:FindFirstChild("Networking")
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
            local localCFrame = CFrame.new(localPos) * CFrame.fromMatrix(
                Vector3.zero, Vector3.new(0,0,-1), Vector3.new(0,1,0), Vector3.new(1,0,0)
            )

            pcall(function() pet.tool.Parent = LocalPlayer.Character end)
            task.wait(0.15)

            local uid = pet.tool:GetAttribute("Uid") or pet.tool:GetAttribute("uid") or pet.name
            local ok3, res = pcall(function()
                return placeRemote:InvokeServer({Uid=uid, LocalCFrame=localCFrame})
            end)
            if ok3 and res then
                placed += 1
                print("[PlaceBestPet] placed:", pet.name, "rarity:", tostring(PET_RARITY_MAP[pet.name]))
            end
            task.wait(0.1)
        end
        print("[PlaceBestPet] total placed:", placed)
    end)
end

task.spawn(function()
    while true do
        task.wait(State.placeBestPetInterval or 10)
        if State.placeBestPetEnabled then
            if not PlotState then loadModules() end
            pcall(runAutoPlaceBestPet)
        end
    end
end)

-- ============================================================
-- AUTO HATCH & AUTO SELL
-- ============================================================
local function runAutoHatch()
    if not EggState then return end
    pcall(function()
        local net = ReplicatedStorage:FindFirstChild("Packages")
            and ReplicatedStorage.Packages:FindFirstChild("Networking")
        if not net then return end
        local AskHatch       = net:FindFirstChild("RF/EggWorld/AskHatch")
        local AskFinishHatch = net:FindFirstChild("RF/EggWorld/AskFinishHatch")
        if not AskHatch and not AskFinishHatch then return end

        local owned = EggState.ReadOwnerEggs(LocalPlayer.UserId)
        if type(owned) ~= "table" then return end

        local hatched = 0
        for uid, rec in pairs(owned) do
            if type(uid) ~= "string" then continue end
            if AskHatch then
                pcall(function() AskHatch:InvokeServer(uid) end)
                task.wait(0.05)
            end
            if AskFinishHatch then
                local ok, r1, r2, petUid = pcall(function()
                    return AskFinishHatch:InvokeServer(uid)
                end)
                if ok and r1 == true then
                    hatched += 1
                end
                task.wait(0.05)
            end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.hatchInterval)
        if State.hatchEnabled then
            if not EggState then loadModules() end
            pcall(runAutoHatch)
        end
    end
end)

local function runAutoSellEgg()
    if not State.sellEggEnabled then return end
    if not EggState then loadModules() end
    pcall(function()
        local net = ReplicatedStorage:FindFirstChild("Packages")
            and ReplicatedStorage.Packages:FindFirstChild("Networking")
        if not net then return end
        local sellRemote = net:FindFirstChild("RE/PetSatchel/SellPet")
        local wearRemote = net:FindFirstChild("RF/EggWorld/AskWearTool")
        if not sellRemote then warn("[SellEgg] SellPet not found"); return end

        local owned = EggState.ReadOwnerEggs(LocalPlayer.UserId)
        if type(owned) ~= "table" then return end

        local maxNum = RARITY_ORDER[State.sellEggMaxRarity] or 0
        local sold = 0

        for uid, rec in pairs(owned) do
            if type(uid) ~= "string" then continue end
            local rarName = getRarityName(rec)
            local rarNum = RARITY_ORDER[rarName] or 0
            if rarNum == 0 then continue end
            if next(State.sellEggMaxRarities) and not State.sellEggMaxRarities[rarName] then continue end

            if wearRemote then
                pcall(function() wearRemote:InvokeServer(uid) end)
                task.wait(0.2)
            end
            pcall(function() sellRemote:FireServer({uid}) end)
            sold += 1
            task.wait(0.1)
        end
        if sold > 0 then print("[SellEgg] sold:", sold) end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.sellEggInterval or 10)
        if not State.sellEggEnabled then continue end
        if not EggState then loadModules() end
        pcall(runAutoSellEgg)
    end
end)

local function getToolFromNil(name)
    if type(getnilinstances) ~= "function" then return nil end
    local ok, result = pcall(function()
        for _, obj in ipairs(getnilinstances()) do
            if obj:IsA("Tool") and obj.Name == name then
                return obj
            end
        end
        return nil
    end)
    return ok and result or nil
end

local function runAutoSell()
    pcall(function()
        local net = ReplicatedStorage:FindFirstChild("Packages")
            and ReplicatedStorage.Packages:FindFirstChild("Networking")
        if not net then return end

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
            if not tool and LocalPlayer.Character then
                tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
            end

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
        if State.sellEnabled then
            if not EggState then loadModules() end
            pcall(runAutoSell)
        end
    end
end)

local function runAutoSellPet()
    if not State.sellEnabled then return end
    pcall(function()
        local net = ReplicatedStorage:FindFirstChild("Packages")
            and ReplicatedStorage.Packages:FindFirstChild("Networking")
        if not net then return end

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
            local rarNum = rarity and (RARITY_ORDER[rarity] or 0) or 0
            if rarNum == 0 then continue end

            if next(State.sellPetMaxRarities) and not State.sellPetMaxRarities[rarity] then continue end

            local isFav = tool:GetAttribute("IsFavorited") or tool:GetAttribute("Favorited")
            if isFav then continue end

            local uid = tool:GetAttribute("Uid") or tool:GetAttribute("uid")
            if not uid then continue end

            if wearRemote then
                pcall(function() wearRemote:InvokeServer(uid) end)
                task.wait(0.2)
            end

            pcall(function() sellRemote:FireServer({uid}) end)
            task.wait(0.1)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(State.sellPetInterval or 5)
        if not State.sellEnabled then
            pcall(runAutoSellPet)
        end
    end
end)

-- ============================================================
-- COLLECT MONEY & AUTO FAVORITE
-- ============================================================
local function runCollectMoney()
    pcall(function()
        local net = ReplicatedStorage:FindFirstChild("Packages")
            and ReplicatedStorage.Packages:FindFirstChild("Networking")
        if not net then return end
        local remote = net:FindFirstChild("RF/AwayEarnings/AskCollect")
        if not remote then return end
        remote:InvokeServer({Kind = "Claim"})
    end)
end

task.spawn(function()
    while true do
        task.wait(State.collectInterval or 60)
        if State.collectEnabled then
            pcall(runCollectMoney)
        end
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

    if next(State.favMinRarities) then
        local rarity = isPet and PET_RARITY_MAP[tool.Name] or (tool:GetAttribute("Rarity") or tool:GetAttribute("rarity"))
        if not rarity or not State.favMinRarities[rarity] then return false end
    end

    if State.favMutations and next(State.favMutations) then
        local mut = tool:GetAttribute("Mutations")
        local hasMut = false
        if type(mut) == "string" then
            for m in pairs(State.favMutations) do
                if mut:lower():find(m:lower()) then hasMut = true; break end
            end
        elseif type(mut) == "table" then
            for _, mv in ipairs(mut) do
                for m in pairs(State.favMutations) do
                    if tostring(mv):lower():find(m:lower()) then hasMut = true; break end
                end
            end
        end
        if not hasMut then return false end
    end

    local weight = tool:GetAttribute("ModelWeight") or tool:GetAttribute("Weight") or 0
    if State.favMinWeight and State.favMinWeight > 0 and weight < State.favMinWeight then return false end
    if State.favMaxWeight and State.favMaxWeight > 0 and weight > State.favMaxWeight then return false end

    local value = tool:GetAttribute("EarningRate") or tool:GetAttribute("Value") or 0
    if State.favMinValue and State.favMinValue > 0 and value < State.favMinValue then return false end

    return true
end

local function favoriteTool(tool)
    local uid = tool:GetAttribute("Uid") or tool:GetAttribute("uid")
    if not uid then return false end
    local net = ReplicatedStorage:FindFirstChild("Packages")
        and ReplicatedStorage.Packages:FindFirstChild("Networking")
    if not net then return false end
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
            if shouldFavorite(tool) then
                favoriteTool(tool)
            end
        end)
    end
end)

-- ============================================================
-- BAT AURA
-- ============================================================
task.spawn(function()
    while true do
        task.wait(State.batInterval)
        if State.batAura then
            local _n = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
            local _r = _n and _n:FindFirstChild("RE/BatSwing/Trigger")
            if _r then pcall(function() _r:FireServer() end) end
        end
    end
end)

-- ============================================================
-- MISC FEATURES
-- ============================================================
local _antiAfkConn = nil
local function setReduceMap(enabled)
    pcall(function()
        local lighting = game:GetService("Lighting")
        if enabled then
            lighting.GlobalShadows = false
            lighting.FogEnd = 9999
            lighting.FogStart = 9998
            for _, obj in ipairs(Workspace:GetDescendants()) do
                pcall(function()
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail")
                    or obj:IsA("Beam") or obj:IsA("SelectionBox") then
                        obj.Enabled = false
                    end
                    if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                        obj.Enabled = false
                    end
                end)
            end
        else
            lighting.GlobalShadows = true
            lighting.FogEnd = 100000
            lighting.FogStart = 0
        end
    end)
end

local function setAntiAfk(enabled)
    if _antiAfkConn then _antiAfkConn:Disconnect(); _antiAfkConn = nil end
    if not enabled then return end
    _antiAfkConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            task.wait(1)
            game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
        end)
    end)
end

local _statsGui = nil
local function updateStatsGui(show)
    if not show then
        if _statsGui then _statsGui:Destroy(); _statsGui = nil end
        return
    end
    if _statsGui then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "SAE_Stats"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 99998

    task.spawn(function()
        local pg = LocalPlayer:WaitForChild("PlayerGui", 10)
        if pg then sg.Parent = pg end
    end)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(120, 36)
    frame.Position = UDim2.new(1, -130, 0, 8)
    frame.BackgroundColor3 = Color3.fromRGB(15,15,20)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(220,220,230)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = "FPS: -- | Ping: --"
    lbl.Parent = frame

    _statsGui = sg

    local lastTime = tick()
    local frameCount = 0
    RunService.RenderStepped:Connect(function()
        if not _statsGui or not _statsGui.Parent then return end
        frameCount += 1
        local now = tick()
        if now - lastTime >= 1 then
            local fps = math.floor(frameCount / (now - lastTime))
            frameCount = 0
            lastTime = now
            local ping = 0
            pcall(function()
                ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            lbl.Text = string.format("FPS: %d | Ping: %dms", fps, ping)
        end
    end)
end

-- ============================================================
-- FARM CYCLE (Anti-Guardian Air Escape & Strict Egg Possession)
-- ============================================================
local function fireClaim(rec, model)
    local slotKey = nil
    pcall(function()
        if AreaEggSlotIdentity and rec.AreaId and rec.NestId then
            slotKey = AreaEggSlotIdentity.SlotKey(rec.AreaId, rec.NestId)
        end
    end)

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

local function farmCycle()
    if State.busy or not State.running then return end
    State.busy = true
    local _busyStart = tick()

    pcall(function()
        if not loadModules() then State.busy = false; return end
        local r = root(); local h2 = hum()
        if not r or not h2 then State.busy = false; return end

        if tick() - _busyStart > 40 then State.busy = false; return end

        local function backpackEggCount()
            local count = 0
            for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if t:IsA("Tool") and (t:GetAttribute("ItemType") == "AssetEgg"
                    or t:GetAttribute("ItemType") == "PetEgg"
                    or AREA_SET[t.Name]) then count += 1 end
            end
            return count
        end

        local function doPlace()
            if not State.placeEnabled then return end
            if not PlotState then return end
            walkTo(START_POS, 10)
            if not State.running then return end
            pcall(runAutoPlace)
        end

        local threshold = State.placeThreshold or 50
        if State.placeEnabled and backpackEggCount() >= threshold then
            doPlace()
            if not State.running then State.busy = false; return end
        end

        -- 1. Acquire target egg
        local rec, model = findBestEgg()
        if not rec or not model then
            State.lockedRecord = nil
            if State.placeEnabled then doPlace() end
            State.busy = false; return
        end

        State.lockedRecord = rec

        -- 2. STRICT EGG CLAIM LOOP: Wait & guarantee egg possession before returning
        local eggPossessed = false
        local acquireTimeout = tick() + 25

        while State.running and tick() < acquireTimeout and not eggPossessed do
            if hasEgg() then
                eggPossessed = true
                break
            end

            -- Re-verify model location in case Guardian pushed us or egg moved
            local clientFolder = Workspace:FindFirstChild("AreaEggSlotsClient", true)
            local currentModel = clientFolder and (clientFolder:FindFirstChild(rec.Uid) or clientFolder:FindFirstChild(rec.Uid, true))
            if not currentModel then currentModel = Workspace:FindFirstChild(rec.Uid, true) end
            if not currentModel then currentModel = model end

            local part = currentModel and (currentModel.PrimaryPart or currentModel:FindFirstChildWhichIsA("BasePart", true))
            if not part then break end

            -- Move to egg using 500 TPWalk without stuttering
            walkTo(part.Position, 10, function() return State.running and not hasEgg() end)
            if not State.running then break end

            local rCurrent = root()
            if rCurrent and (rCurrent.Position - part.Position).Magnitude <= 14 then
                -- Place safely above floor to prevent clipping into void
                local safeClaimY = math.max(part.Position.Y + 3.2, rCurrent.Position.Y)
                pcall(function()
                    rCurrent.CFrame = CFrame.new(part.Position.X, safeClaimY, part.Position.Z) * (rCurrent.CFrame - rCurrent.CFrame.Position)
                    rCurrent.AssemblyLinearVelocity = Vector3.zero
                    rCurrent.AssemblyAngularVelocity = Vector3.zero
                end)

                fireClaim(rec, currentModel)

                -- Quick check without freezing delay
                local claimCheckT = tick()
                while tick() - claimCheckT < 0.25 do
                    task.wait(0.02)
                    if hasEgg() then
                        eggPossessed = true
                        break
                    end
                end
            end
        end

        -- If egg could not be acquired (despawned or taken), unlock record and exit
        if not eggPossessed or not State.running then
            State.lockedRecord = nil
            State.busy = false
            return
        end

        -- 3. INSTANT ZERO-DELAY ANTI-GUARDIAN AIR ESCAPE
        -- Instantly launch 25 studs above ground so Guardian cannot hit
        r = root()
        if r then
            pcall(function()
                local launchPos = r.Position + Vector3.new(0, 25, 0)
                r.CFrame = CFrame.new(launchPos) * (r.CFrame - r.CFrame.Position)
                r.AssemblyLinearVelocity = Vector3.new(0, 15, 0)
                r.AssemblyAngularVelocity = Vector3.zero
            end)
        end

        -- 4. 1000 TPWALK SKY RETURN (Guardian can never reach)
        -- If Guardian hits or egg drops mid-return, loop halts return and re-claims egg
        local safelyReturned = false
        local returnTimeout = tick() + 20

        while State.running and tick() < returnTimeout and not safelyReturned do
            if not hasEgg() then
                -- Egg dropped mid-air/mid-flight! Abort base return and re-acquire immediately
                warn("[Louis Hub] Egg was knocked out! Immediately re-acquiring...")
                break
            end

            r = root()
            local skyAltitude = math.max(START_POS.Y + 25, (r and r.Position.Y or (START_POS.Y + 25)))
            local skyGoal = Vector3.new(START_POS.X, skyAltitude, START_POS.Z)

            local reachedAir = walkToAir(skyGoal, 10)
            if reachedAir and hasEgg() then
                safelyReturned = true
            end
        end

        -- If successfully reached base with egg
        if safelyReturned then
            -- Land safely onto base floor
            r = root()
            if r then
                pcall(function()
                    r.CFrame = CFrame.new(START_POS + Vector3.new(0, 3.2, 0))
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end)
            end
            task.wait(0.3)

            -- Unequip egg to backpack
            local charEq = LocalPlayer.Character
            if charEq then
                for _, t in ipairs(charEq:GetChildren()) do
                    if t:IsA("Tool") and (t:GetAttribute("ItemType") == "AssetEgg" or t:GetAttribute("ItemType") == "PetEgg" or AREA_SET[t.Name]) then
                        pcall(function() t.Parent = LocalPlayer.Backpack end)
                    end
                end
            end

            State.lockedRecord = nil
            State.stealCount += 1
        end
    end)

    local h2 = hum()
    if h2 then h2.WalkSpeed = 16 end
    State.busy = false
end

-- ============================================================
-- ESP SYSTEM (VD Style)
-- ============================================================
local EspHighlights = {}
local EspBillboards = {}

local function clearESP(uid)
    if EspHighlights[uid] then pcall(function() EspHighlights[uid]:Destroy() end); EspHighlights[uid] = nil end
    if EspBillboards[uid] then pcall(function() EspBillboards[uid]:Destroy() end); EspBillboards[uid] = nil end
end

local function createESP(model, uid, rarityCol, dispName, rarityName, earning)
    if not EspHighlights[uid] or not EspHighlights[uid].Parent then
        local h = Instance.new("Highlight")
        h.Name                = "SAE_HL"
        h.FillColor           = rarityCol
        h.OutlineColor        = rarityCol
        h.FillTransparency    = 0.7
        h.OutlineTransparency = 0.2
        h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent              = model
        EspHighlights[uid]    = h
    else
        EspHighlights[uid].FillColor    = rarityCol
        EspHighlights[uid].OutlineColor = rarityCol
    end

    local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not part then return end

    local bb = EspBillboards[uid]
    if not bb or not bb.Parent then
        bb = Instance.new("BillboardGui")
        bb.Name        = "SAE_ESP"
        bb.AlwaysOnTop = true
        bb.Size        = UDim2.new(0, 200, 0, 25)
        bb.StudsOffset = Vector3.new(0, 2, 0)
        bb.Adornee     = part
        bb.Parent      = part

        local box = Instance.new("Frame")
        box.Name                   = "Box"
        box.AutomaticSize          = Enum.AutomaticSize.X
        box.Size                   = UDim2.new(0, 0, 0, 15)
        box.Position               = UDim2.new(0.5, 0, 0, 0)
        box.AnchorPoint            = Vector2.new(0.5, 0)
        box.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
        box.BackgroundTransparency = 0
        box.BorderSizePixel        = 0
        box.ZIndex                 = 2
        box.Parent                 = bb
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)

        local txt = Instance.new("TextLabel", box)
        txt.Name                   = "Text"
        txt.AutomaticSize          = Enum.AutomaticSize.X
        txt.Size                   = UDim2.new(0, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Font                   = Enum.Font.GothamMedium
        txt.TextSize               = 10
        txt.ZIndex                 = 3
        txt.RichText               = true
        txt.TextXAlignment         = Enum.TextXAlignment.Center

        EspBillboards[uid] = bb
    end

    local hex = string.format("#%02X%02X%02X", math.floor(rarityCol.R * 255), math.floor(rarityCol.G * 255), math.floor(rarityCol.B * 255))
    local box2 = bb:FindFirstChild("Box")
    if box2 then
        local txt2 = box2:FindFirstChild("Text")
        if txt2 then
            txt2.Text = string.format("<font color='#FFFFFF'>%s</font> <font color='%s'>%s</font> <font color='#B4FFB4'>$%s</font>", dispName, hex, rarityName, formatNumber(earning))
        end
    end
end

local function updateESP()
    if not State.espEnabled then
        for uid in pairs(EspHighlights) do clearESP(uid) end
        for uid in pairs(EspBillboards) do clearESP(uid) end
        return
    end
    if not EggState then loadModules() end
    if not EggState then return end

    local ok, fieldEggs = pcall(function() return EggState.ReadFieldEggs() end)
    if not ok or not fieldEggs or not fieldEggs.Records then return end

    local active = {}
    for _, rec in ipairs(fieldEggs.Records) do
        local uid = rec.Uid
        if not uid then continue end
        active[uid] = true

        local model = Workspace:FindFirstChild("AreaEggSlotsClient", true)
            and Workspace.AreaEggSlotsClient:FindFirstChild(uid)
            or Workspace:FindFirstChild(uid, true)
        if not model then continue end

        local d        = getAssetData(rec)
        local col      = getRarityColor(rec)
        local name     = getRarityName(rec)
        local earning  = getEarningRate(rec)
        local dispName = d.DisplayName or rec.AssetCategory or uid

        pcall(createESP, model, uid, col, dispName, name, earning)
    end

    for uid in pairs(EspHighlights) do
        if not active[uid] then clearESP(uid) end
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        pcall(updateESP)
    end
end)

-- ============================================================
-- FULL NEW FEATURES (Haul, Codex, Fusery, Bloomery, Parasite)
-- ============================================================

-- HAUL
local function wearBest() invokeRemote("RF/Haul/WearBest"); print("[WearBest] fired") end
local function sellFullSatchel() invokeRemote("RF/Haul/OfferFullSatchelSale"); print("[SellSatchel] fired") end
local function fetchAutoSell() local r = invokeRemote("RF/Haul/FetchAutoSell"); print("[FetchAutoSell]", r); return r end
local function writeAutoSell(cfg) invokeRemote("RF/Haul/WriteAutoSell", cfg) end

-- CODEX
local function redeemAllCodex() invokeRemote("RF/Codex/AskRedeemAll"); print("[RedeemAll] fired") end
local function wearFieldBat()
    local ok, r = invokeRemote("RF/Codex/AskWearFieldBat")
    print("[WearFieldBat] ok=", ok, "result=", tostring(r)); return r
end

-- FUSE MACHINE
local function fuseLoadPet(uid)
    local ok, r, err = invokeRemote("RF/Fusery/LoadPet", uid)
    print("[FuseLoad]", tostring(uid):sub(1,8), "ok=", tostring(r), tostring(err)); return r
end
local function fuseBegin()
    local ok, r, msg = invokeRemote("RF/Fusery/BeginFuse")
    print("[BeginFuse] ok=", tostring(r), tostring(msg)); return r
end
local function fuseFinishReveal()
    local ok, r = invokeRemote("RF/Fusery/FinishReveal")
    print("[FinishReveal] ok=", tostring(r))
end
local function fuseEjectPet(slot) invokeRemote("RF/Fusery/EjectPet", slot) end

local function autoFuse(uid1, uid2, uid3)
    print("[AutoFuse] starting...")
    pcall(function() invokeRemote("RF/Fusery/ConfirmBriefing") end)
    task.wait(0.2)
    local ok1 = fuseLoadPet(uid1); task.wait(0.2)
    local ok2 = fuseLoadPet(uid2); task.wait(0.2)
    local ok3 = fuseLoadPet(uid3); task.wait(0.3)
    if ok1 ~= false and ok2 ~= false and ok3 ~= false then
        local success = fuseBegin()
        if success then task.wait(0.5); fuseFinishReveal(); print("[AutoFuse] DONE") end
    else
        print("[AutoFuse] failed to load all pets")
    end
end

-- BLOOMERY (Cherry Blossom)
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
local function gatherPetal() invokeRemote("RF/Bloomery/AskGatherPetal"); print("[GatherPetal] fired") end
local function mutateEgg() invokeRemote("RF/Bloomery/AskMutate"); print("[MutateEgg] fired") end

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
        if not hrp then return end
        if (obj.Position - hrp.Position).Magnitude > 100 then return end

        print("[AutoBloomery] tree detected:", obj.Name, obj:GetFullName())

        local wasRunning = State.running
        if wasRunning then
            State.running = false
            State.busy = false
        end

        wearFieldBat()
        task.wait(0.3)

        local h = char and char:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = State.speed end
        if h then h:MoveTo(obj.Position) end

        local t0 = tick()
        while tick() - t0 < 5 do
            local r2 = hrp
            if not r2 or not r2.Parent then break end
            if (r2.Position - obj.Position).Magnitude <= 10 then break end
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
                walkTo(START_POS, 10)
                while State.running do farmCycle(); task.wait(0.05) end
            end)
        end
        print("[AutoBloomery] done")
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isTreeObject(obj) then
            task.spawn(function() handleTree(obj) end)
        end
    end

    _bloomEventConn = Workspace.DescendantAdded:Connect(function(obj)
        if _bloomActive then
            task.spawn(function() handleTree(obj) end)
        end
    end)
end

local function stopAutoBloomery()
    _bloomActive = false
    stopBatTree()
    if _bloomEventConn then _bloomEventConn:Disconnect(); _bloomEventConn = nil end
    print("[AutoBloomery] stopped")
end

-- MONSTER PARASITE
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
                    if type(uid) ~= "string" then continue end
                    if not rec.HasParasite then continue end
                    if next(State.parasiteMinRarities) then
                        local rarName = getRarityName(rec)
                        if not State.parasiteMinRarities[rarName] then continue end
                    end
                    if wearRemote then
                        pcall(function() wearRemote:InvokeServer(uid) end)
                    end
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
    print("[AutoFeedParasite] started")
end
local function stopAutoFeedParasite()
    if _parasiteConn then _parasiteConn:Disconnect(); _parasiteConn = nil end
    print("[AutoFeedParasite] stopped")
end
local function claimParasiteChest()
    invokeRemote("RF/MonsterParasite/AskChestClaim"); task.wait(0.2)
    invokeRemote("RF/MonsterParasite/AskChestTake"); task.wait(0.2)
    invokeRemote("RF/MonsterParasite/AskChestRevealComplete")
    print("[ParasiteChest] claimed")
end

-- GUARD WARNING LISTENER
local _guardWarnConn = nil
local function listenGuardWarning(cb)
    local n = getNet(); if not n then return end
    local remote = n:FindFirstChild("RE/GuardPatrol/SpeedTollWarning")
    if not remote then warn("[Guard] SpeedTollWarning not found"); return end
    if _guardWarnConn then _guardWarnConn:Disconnect() end
    _guardWarnConn = remote.OnClientEvent:Connect(function(...)
        print("[GuardWarning]", ...); if cb then cb(...) end
    end)
    print("[Guard] listening")
end

-- ============================================================
-- LUNA INTERFACE SUITE (Auto-Fallback Loader)
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

local RARITIES = {
    "Common","Uncommon","Rare","Epic","Legendary","Mythic",
    "SuperRare","Exotic","Limited","Divine","Secret","Titan",
    "Cosmic","Celestial","Transcendent","Prismatic","Rainbow",
    "Eternal","Brainrot","Mythical","Exclusive"
}

-- Window Definition with complete KeySettings to prevent internal nil indexing
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
-- TAB 1: FARM (Using verified icon "view_in_ar")
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
            if not _speedBypassActive then pcall(initSpeedBypass) end
            loadModules()
            doHumanoidBypass()
            Notify("Louis Hub", "Auto Steal Started! (500/1000 TPWalk)")
            task.spawn(function()
                walkTo(START_POS, 10)
                while State.running do
                    farmCycle()
                    task.wait(0.05)
                end
            end)
        else
            State.running = false
            State.busy = false
            State.lockedRecord = nil
            if _camConn then _camConn:Disconnect(); _camConn = nil end
            if _speedConn then _speedConn:Disconnect(); _speedConn = nil end
            stopSpeedBypass()

            -- Restore normal character & humanoid walk
            local char = LocalPlayer.Character
            local h = char and char:FindFirstChildOfClass("Humanoid")
            if h then
                h.WalkSpeed = 16
                h.PlatformStand = false
                h.Sit = false
                pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
                workspace.CurrentCamera.CameraSubject = h
            end
            local r = char and char:FindFirstChild("HumanoidRootPart")
            if r then
                r.AssemblyLinearVelocity  = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end
            Notify("Louis Hub", "Auto Steal Stopped. Normal walking restored.")
        end
    end
}, "AutoSteal")

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

-- Default to empty table so all eggs are stolen by default
TabFarm:CreateDropdown({
    Name            = "Target Rarities",
    Description     = nil,
    Options         = RARITIES,
    CurrentOption   = {},
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.targetRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.targetRarities[s] = true end
        elseif type(opts) == "string" and opts ~= "" then
            State.targetRarities[opts] = true
        end
    end
}, "TargetRarities")

TabFarm:CreateDropdown({
    Name            = "Target Areas",
    Description     = nil,
    Options         = AREA_NAMES,
    CurrentOption   = {},
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.targetAreas = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.targetAreas[s] = true end
        elseif type(opts) == "string" and opts ~= "" then
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
    CurrentOption   = {},
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.targetMutations = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.targetMutations[s] = true end
        elseif type(opts) == "string" and opts ~= "" then
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
    CurrentOption   = {},
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.parasiteMinRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.parasiteMinRarities[s] = true end
        elseif type(opts) == "string" and opts ~= "" then
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
-- TAB 2: AUTO (Using verified icon "view_in_ar")
-- ============================================================
local TabAuto = Window:CreateTab({
    Name        = "Auto",
    Icon        = "view_in_ar",
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
    CurrentOption   = {},
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
    CurrentOption   = {},
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.favMinRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.favMinRarities[s] = true end
        elseif type(opts) == "string" and opts ~= "" then
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
-- TAB 3: STORE (Using verified icon "view_in_ar")
-- ============================================================
local TabStore = Window:CreateTab({
    Name        = "Store",
    Icon        = "view_in_ar",
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
    CurrentOption   = {},
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.sellPetMaxRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.sellPetMaxRarities[s] = true end
        elseif type(opts) == "string" and opts ~= "" then
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
    CurrentOption   = {},
    MultipleOptions = true,
    SpecialType     = nil,
    Callback        = function(opts)
        State.sellEggMaxRarities = {}
        if type(opts) == "table" then
            for _, s in ipairs(opts) do State.sellEggMaxRarities[s] = true end
        elseif type(opts) == "string" and opts ~= "" then
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
-- TAB 4: MISC (Using verified icon "view_in_ar")
-- ============================================================
local TabMisc = Window:CreateTab({
    Name        = "Misc",
    Icon        = "view_in_ar",
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
    Callback          = function() end,
    OnChangedCallback = function() end
}, "ToggleUIBind")

-- ============================================================
-- TAB 5 & 6: THEME & CONFIG
-- ============================================================
local ThemeTab = Window:CreateTab({
    Name        = "Theme",
    Icon        = "palette",
    ImageSource = "Material",
    ShowTitle   = true
})
ThemeTab:BuildThemeSection()

local ConfigTab = Window:CreateTab({
    Name        = "Config",
    Icon        = "settings",
    ImageSource = "Material",
    ShowTitle   = true
})
ConfigTab:BuildConfigSection()

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
                        Notify("Louis Hub", "Staff in server: " .. p.Name)
                    end
                end
            end
            task.wait(3)
        end
    end)
end)
