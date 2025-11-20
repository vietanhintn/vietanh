--[[ Auto Attack & Move To Cursed Captain ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = ReplicatedStorage.Modules.Net
local RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
local RegisterHit = Net:WaitForChild("RE/RegisterHit")
local LocalPlayer = Players.LocalPlayer

local COMBAT_CONFIG = {
    enabled = true,
    attacksPerTarget = 3,
    maxTargets = 1,
    baseRange = 100,
    minDelay = 0.05,
    maxDelay = 0.1,
    hitDelay = 0.02,
    moveSpeed = 50, -- tốc độ di chuyển tới target
    randomization = {
        range = {min = -2, max = 2},
        timing = {min = -0.05, max = 0.05}
    }
}

local function GetPrimaryPart(model)
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("PrimaryPart")
end

-- kiểm tra target hợp lệ
local function IsValidTarget(target)
    if not target then return false end
    
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    if target.Name ~= "Cursed Captain" then return false end
    
    return true
end

-- lấy target duy nhất và kiểm tra distance
local function GetNearbyTarget()
    local character = LocalPlayer.Character
    if not character or not character.PrimaryPart then return nil end
    
    local charPos = character.PrimaryPart.Position
    local cursed = workspace.Enemies:FindFirstChild("Cursed Captain")
    if not cursed then
        print("Không có Cursed Captain trong server")
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
                return {
                    part = primaryPart,
                    distance = distance
                }
            end
        end
    end
    return nil
end

-- tween đến target
local function MoveToTarget(target)
    if not target then return end
    local character = LocalPlayer.Character
    local root = character.PrimaryPart
    if not root then return end

    local distance = (target.part.Position - root.Position).Magnitude
    local time = distance / COMBAT_CONFIG.moveSpeed

    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = target.part.CFrame * CFrame.new(0,0, -3)})
    tween:Play()
    tween.Completed:Wait() -- chờ di chuyển xong
end

-- tấn công
local function PerformAttackSequence(target)
    if not target then return end
    RegisterAttack:FireServer()
    for _ = 1, COMBAT_CONFIG.attacksPerTarget do
        RegisterHit:FireServer(target.part)
        task.wait(COMBAT_CONFIG.hitDelay + math.random() * COMBAT_CONFIG.randomization.timing.max)
    end
end

local lastAttackTime = 0
local function CombatLoop()
    if not COMBAT_CONFIG.enabled then return end
    
    local now = tick()
    local baseDelay = math.random(
        COMBAT_CONFIG.minDelay * 100,
        COMBAT_CONFIG.maxDelay * 100
    ) / 100
    
    if now - lastAttackTime >= baseDelay then
        local target = GetNearbyTarget()
        if target then
            MoveToTarget(target)
            PerformAttackSequence(target)
        end
        lastAttackTime = now
    end
end

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

characterConnection = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    SetupCombat()
end)

SetupCombat()
