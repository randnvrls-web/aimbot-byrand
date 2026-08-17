--[[
    🔥 AUTO AIM + ESP (AGGRESSIVE + DRAGGABLE) 🔥
    Fitur:
        1. Auto Aim INSTANT (nempel, agresif)
        2. ESP (box + nama + jarak)
        3. GUI bisa digeser
    Kontrol:
        - F2: Toggle Auto Aim
        - F3: Toggle ESP
        - Geser title untuk pindah UI
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- ================================================================
-- KONFIGURASI
-- ================================================================
local CONFIG = {
    AIM_DISTANCE = 350,
    ESP_DISTANCE = 200,
    TEAM_CHECK = true,
}

local aimEnabled = false
local espEnabled = false
local espObjects = {}

-- ================================================================
-- LINE OF SIGHT
-- ================================================================
local function hasLineOfSight(origin, target)
    local dir = (target.Position - origin).Unit
    local dist = (target.Position - origin).Magnitude
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true
    local result = Workspace:Raycast(origin, dir * dist, params)
    return result == nil
end

-- ================================================================
-- GET TARGET TERDEKAT (UNTUK AUTO AIM)
-- ================================================================
local function getTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    local myPos = char:FindFirstChild("HumanoidRootPart")
    if not myPos then return nil end

    local best, bestDist = nil, math.huge

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local enemyChar = p.Character
            if enemyChar then
                local hrp = enemyChar:FindFirstChild("HumanoidRootPart")
                local hum = enemyChar:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    if CONFIG.TEAM_CHECK then
                        local t1, t2 = LocalPlayer.Team, p.Team
                        if t1 and t2 and t1 == t2 then goto skip end
                    end
                    local dist = (hrp.Position - myPos.Position).Magnitude
                    if dist <= CONFIG.AIM_DISTANCE and hasLineOfSight(myPos.Position, hrp) then
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

-- ================================================================
-- AUTO AIM LOOP (AGGRESSIVE / INSTANT)
-- ================================================================
RunService.RenderStepped:Connect(function()
    if aimEnabled then
        local target = getTarget()
        if target then
            local char = target.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, head.Position)
                end
            end
        end
    end
end)

-- ================================================================
-- ESP (DRAWING)
-- ================================================================
local function clearESP()
    for _, obj in pairs(espObjects) do
        pcall(function()
            obj.box.Visible = false
            obj.name.Visible = false
        end)
    end
    espObjects = {}
end

local function updateESP()
    clearESP()
    if not espEnabled then return end

    local char = LocalPlayer.Character
    if not char then return end
    local myPos = char:FindFirstChild("HumanoidRootPart")
    if not myPos then return end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local enemyChar = p.Character
            if enemyChar then
                local hrp = enemyChar:FindFirstChild("HumanoidRootPart")
                local hum = enemyChar:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    if CONFIG.TEAM_CHECK then
                        local t1, t2 = LocalPlayer.Team, p.Team
                        if t1 and t2 and t1 == t2 then goto skip2 end
                    end
                    local dist = (hrp.Position - myPos.Position).Magnitude
                    if dist <= CONFIG.ESP_DISTANCE then
                        local pos, onScreen = Camera:WorldToScreenPoint(hrp.Position)
                        if onScreen then
                            -- Ukuran box
                            local size = 2.5
                            local h = 4.5 * size
                            local w = 2.2 * size
                            local top = pos.Y - h/2
                            local left = pos.X - w/2

                            -- Box
                            local box = Drawing.new("Square")
                            box.Thickness = 1
                            box.Color = Color3.new(1, 0, 0)
                            box.Transparency = 1
                            box.Visible = true
                            box.Filled = false
                            box.From = Vector2.new(left, top)
                            box.To = Vector2.new(left + w, top + h)

                            -- Nama + Jarak
                            local name = Drawing.new("Text")
                            name.Size = 12
                            name.Color = Color3.new(1, 1, 1)
                            name.Center = true
                            name.Visible = true
                            name.Text = string.format("%s [%.0fs]", p.Name, dist)
                            name.Position = Vector2.new(pos.X, top - 15)

                            table.insert(espObjects, { box = box, name = name })
                        end
                    end
                end
            end
        end
        ::skip2::
    end
end

RunService.RenderStepped:Connect(updateESP)

-- ================================================================
-- GUI DRAGGABLE (dengan 2 tombol: Aim + ESP)
-- ================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = LocalPlayer.PlayerGui
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 180, 0, 120)
frame.Position = UDim2.new(0.5, -90, 0.5, -60)
frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
frame.BackgroundTransparency = 0.5
frame.Parent = screenGui

-- Title (drag handle)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "🎯 AIM + ESP"
title.BackgroundTransparency = 0.5
title.BackgroundColor3 = Color3.new(0.2, 0.2, 0.3)
title.TextColor3 = Color3.new(1, 0.5, 0)
title.TextScaled = true
title.Parent = frame

-- Auto Aim Button
local aimBtn = Instance.new("TextButton")
aimBtn.Size = UDim2.new(0.8, 0, 0, 28)
aimBtn.Position = UDim2.new(0.1, 0, 0.35, 0)
aimBtn.Text = "Auto Aim: OFF"
aimBtn.BackgroundColor3 = Color3.new(0.2, 0.2, 0.3)
aimBtn.TextColor3 = Color3.new(1, 1, 1)
aimBtn.Parent = frame
aimBtn.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled
    aimBtn.Text = "Auto Aim: " .. (aimEnabled and "ON" or "OFF")
end)

-- ESP Button
local espBtn = Instance.new("TextButton")
espBtn.Size = UDim2.new(0.8, 0, 0, 28)
espBtn.Position = UDim2.new(0.1, 0, 0.7, 0)
espBtn.Text = "ESP: OFF"
espBtn.BackgroundColor3 = Color3.new(0.2, 0.2, 0.3)
espBtn.TextColor3 = Color3.new(1, 1, 1)
espBtn.Parent = frame
espBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    espBtn.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
    if not espEnabled then clearESP() end
end)

-- ================================================================
-- DRAG LOGIC
-- ================================================================
local dragging = false
local dragStart = nil
local frameStart = nil

local function startDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        frameStart = frame.Position
    end
end

local function moveDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(0, frameStart.X.Offset + delta.X, 0, frameStart.Y.Offset + delta.Y)
    end
end

local function endDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end

frame.InputBegan:Connect(startDrag)
frame.InputChanged:Connect(moveDrag)
frame.InputEnded:Connect(endDrag)
title.InputBegan:Connect(startDrag)
title.InputChanged:Connect(moveDrag)
title.InputEnded:Connect(endDrag)

-- ================================================================
-- KEYBINDS
-- ================================================================
UserInputService.InputBegan:Connect(function(input, g)
    if g then return end
    if input.KeyCode == Enum.KeyCode.F2 then
        aimEnabled = not aimEnabled
        aimBtn.Text = "Auto Aim: " .. (aimEnabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.F3 then
        espEnabled = not espEnabled
        espBtn.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
        if not espEnabled then clearESP() end
    end
end)

print("✅ Auto Aim + ESP loaded!")
print("   F2: Toggle Aim | F3: Toggle ESP")
print("   Geser GUI dengan menahan title.")
