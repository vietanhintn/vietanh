--[[ Auto Attack & Server Hop Cursed Captain ]]
-- Dựa trên script AutoChest + Tween & AutoAttack
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Modules
local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
local RegisterAttack = Net:WaitForChild("RE"):WaitForChild("RegisterAttack")
local RegisterHit = Net:WaitForChild("RE"):WaitForChild("RegisterHit")
local LocalPlayer = Players.LocalPlayer

-- Config
local COMBAT_CONFIG = {
    enabled = true,
    attacksPerTarget = 3,
    maxTargets = 1,
    baseRange = 100,
    minDelay = 0.05,
    maxDelay = 0.1,
    hitDelay = 0.02,
    moveSpeed = 50,
    randomization = {
        range = {min = -2, max = 2},
        timing = {min = -0.05, max = 0.05}
    }
}

-- Load NotSameServers.json
local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour
pcall(function()
    AllIDs = HttpService:JSONDecode(readfile("NotSameServers.json"))
end)

-- Tween đến target
local function GetPrimaryPart(model)
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("PrimaryPart")
end

-- Kiểm tra target hợp lệ
local function IsValidTarget(target)
    if not target then return false end
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if target.Name ~= "Cursed Captain" then return false end
    return true
end

-- Hop server
local function TPReturner()
    local placeId = game.PlaceId
    local Site
    if foundAnything == "" then
        Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/'..placeId..'/servers/Public?sortOrder=Asc&limit=100'))
    else
        Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/'..placeId..'/servers/Public?sortOrder=Asc&limit=100&cursor='..foundAnything))
    end

    if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
        foundAnything = Site.nextPageCursor
    end

    for i,v in pairs(Site.data) do
        local Possible = true
        local ID = tostring(v.id)
        if tonumber(v.maxPlayers) > tonumber(v.playing) then
            for _, Existing in pairs(AllIDs) do
                if ID == tostring(Existing) then
                    Possible = false
                end
            end
            if Possible then
                table.insert(AllIDs, ID)
                pcall(function()
                    writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
                    task.wait()
                    TeleportService:TeleportToPlaceInstance(placeId, ID, LocalPlayer)
                end)
                task.wait(4)
                break
            end
        end
    end
end

-- Lấy target gần nhất
local function GetNearbyTarget()
    local character = LocalPlayer.Character
    if not character or not character.PrimaryPart then return nil end
    local charPos = character.PrimaryPart.Position
    local cursed = workspace:FindFirstChild("Enemies") and workspace.Enemies:FindFirstChild("Cursed Captain")

    if not cursed then
        print("Không có Cursed Captain, hop server...")
        TPReturner()
        return nil
    end

    if IsValidTarget(cursed) then
        local primaryPart = GetPrimaryPart(cursed)
        if primaryPart then
            local distance = (primaryPart.Position - charPos).Magnitude
            local range = COMBAT_CONFIG.baseRange + math.random(
                COMBAT_CONFIG.randomization.range.min,
                COMBAT_CONFIG.randomization.range.max
            )
            if distance <= range then
                return {part = primaryPart, distance = distance}
            end
        end
    end
    return nil
end

-- Tween đến target
local function MoveToTarget(target)
    if not target then return end
    local character = LocalPlayer.Character
    local root = character.PrimaryPart
    if not root then return end

    local distance = (target.part.Position - root.Position).Magnitude
    local time = distance / COMBAT_CONFIG.moveSpeed
    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = target.part.CFrame * CFrame.new(0,0,-3)})
    tween:Play()
    tween.Completed:Wait()
end

-- Tấn công
local function PerformAttackSequence(target)
    if not target then return end
    RegisterAttack:FireServer()
    for _ = 1, COMBAT_CONFIG.attacksPerTarget do
        RegisterHit:FireServer(target.part)
        task.wait(COMBAT_CONFIG.hitDelay + math.random() * COMBAT_CONFIG.randomization.timing.max)
    end
end

-- Loop chính
local lastAttackTime = 0
local function CombatLoop()
    if not COMBAT_CONFIG.enabled then return end
    local now = tick()
    local baseDelay = math.random(
        COMBAT_CONFIG.minDelay * 100,
        COMBAT_CONFIG.maxDelay * 100
    ) / 100

    if now - lastAttackTime >= baseDelay then
        local target = GetNearbyTarget() -- Nếu nil -> tự hop server
        if target then
            MoveToTarget(target)
            PerformAttackSequence(target)
        end
        lastAttackTime = now
    end
end

-- Kết nối RunService
local combatConnection
local characterConnection

local function Cleanup()
    if combatConnection then
        combatConnection:Disconnect()
        combatConnection = nil
    end
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end
end

local function SetupCombat()
    Cleanup()
    combatConnection = RunService.Heartbeat:Connect(CombatLoop)
end

-- Thiết lập khi respawn
characterConnection = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    SetupCombat()
end)

SetupCombat()
