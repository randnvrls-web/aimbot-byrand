-- Auto Aim + Team Check (Line of Sight)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

local aimEnabled = false
local DISTANCE = 500
local TEAM_CHECK = true -- true = hindari teman, false = semua target

local function hasLineOfSight(origin, target)
    local dir = (target.Position - origin).Unit
    local dist = (target.Position - origin).Magnitude
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true
    return Workspace:Raycast(origin, dir * dist, params) == nil
end

local function getTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    local myPos = char:FindFirstChild("HumanoidRootPart")
    if not myPos then return nil end

    local best, bestDist = nil, math.huge

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local c = p.Character
            if c then
                local hrp = c:FindFirstChild("HumanoidRootPart")
                local hum = c:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    -- TEAM CHECK
                    if TEAM_CHECK then
                        local t1, t2 = LocalPlayer.Team, p.Team
                        if t1 and t2 and t1 == t2 then
                            goto skip
                        end
                    end
                    local dist = (hrp.Position - myPos.Position).Magnitude
                    if dist <= DISTANCE and hasLineOfSight(myPos.Position, hrp) then
                        if dist < bestDist then
                            bestDist = dist
                            best = p
                        end
                    end
                end
            end
        end
        ::skip::
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if aimEnabled then
        local target = getTarget()
        if target then
            local head = target.Character and target.Character:FindFirstChild("Head")
            if head then
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, head.Position)
            end
        end
    end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Parent = LocalPlayer.PlayerGui
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 120, 0, 50)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
frame.BackgroundTransparency = 0.3
frame.Parent = screenGui

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, 0, 1, 0)
btn.Text = "AIM: OFF"
btn.BackgroundColor3 = Color3.new(0.2, 0.2, 0.3)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.TextScaled = true
btn.Parent = frame
btn.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled
    btn.Text = "AIM: " .. (aimEnabled and "ON" or "OFF")
end)

UserInputService.InputBegan:Connect(function(input, g)
    if g then return end
    if input.KeyCode == Enum.KeyCode.F2 then
        aimEnabled = not aimEnabled
        btn.Text = "AIM: " .. (aimEnabled and "ON" or "OFF")
    end
end)
