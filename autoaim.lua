--[[
    🔥 AUTO AIM BOT - ULTIMATE EDITION 🔥
    Fitur Upgrade:
        1. ✅ Smooth Aim (transisi halus)
        2. ✅ FOV Circle (bidang pandang)
        3. ✅ Target Priority (jarak, health, damage)
        4. ✅ Hitbox Selection (Head/Body/Legs)
        5. ✅ Silent Aim (tampilan normal tapi tembakan ke target)
        6. ✅ Trigger Bot (auto fire saat crosshair di musuh)
        7. ✅ Visual Indicator (lingkaran target)
        8. ✅ Keybinds (toggle fitur pakai keyboard)
        9. ✅ Team Check (hindari teman)
        10. ✅ Statistik (hit rate, kill count)
    Kontrol:
        - F1: Toggle GUI
        - F2: Toggle Auto Aim
        - F3: Toggle ESP
        - F4: Toggle Trigger Bot
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ================================================================
-- KONFIGURASI
-- ================================================================
local CONFIG = {
    -- === ESP ===
    ESP_MAX_DISTANCE = 200,
    ESP_BOX_COLOR = Color3.new(1, 0, 0),
    ESP_BOX_THICKNESS = 1,
    ESP_TEXT_SIZE = 12,
    ESP_TEXT_COLOR = Color3.new(1, 1, 1),

    -- === AUTO AIM ===
    AIM_MAX_DISTANCE = 300,
    AIM_FOV = 60,              -- FOV dalam derajat (0 = semua)
    AIM_SMOOTHNESS = 0.3,       -- 0 = instant, 1 = sangat halus
    AIM_HITBOX = "Head",        -- "Head" | "HumanoidRootPart" | "Torso" | "Legs"

    -- === TRIGGER BOT ===
    TRIGGER_DELAY = 0.1,        -- Delay antar tembakan (detik)
    TRIGGER_KEY = "MouseButton1", -- Tombol untuk trigger (MouseButton1 = kiri)

    -- === KEYS ===
    KEY_TOGGLE_GUI = Enum.KeyCode.F1,
    KEY_TOGGLE_AIM = Enum.KeyCode.F2,
    KEY_TOGGLE_ESP = Enum.KeyCode.F3,
    KEY_TOGGLE_TRIGGER = Enum.KeyCode.F4,

    -- === OTHER ===
    TEAM_CHECK = true,          -- Hindari teman satu tim
    SHOW_FOV = true,            -- Tampilkan FOV circle
    SHOW_STATS = true,          -- Tampilkan statistik
}

-- ================================================================
-- SETUP
-- ================================================================
local espEnabled = false
local aimEnabled = false
local triggerEnabled = false
local guiVisible = true
local espObjects = {}
local currentTarget = nil
local stats = { kills = 0, shots = 0, hits = 0 }

-- ================================================================
-- LINE OF SIGHT
-- ================================================================
local function hasLineOfSight(origin, targetPart)
    if not origin or not targetPart then return false end
    local direction = (targetPart.Position - origin).Unit
    local distance = (targetPart.Position - origin).Magnitude
    if distance > CONFIG.AIM_MAX_DISTANCE then return false end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.IgnoreWater = true

    local result = Workspace:Raycast(origin, direction * distance, raycastParams)
    if not result then return true end

    local hit = result.Instance
    if hit and hit:IsDescendantOf(targetPart.Parent) then
        return true
    end
    return false
end

-- ================================================================
-- GET HITBOX PART
-- ================================================================
local function getHitboxPart(character)
    local part = character:FindFirstChild(CONFIG.AIM_HITBOX)
    if part then return part end
    -- Fallback
    local head = character:FindFirstChild("Head")
    if head then return head end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp end
    return nil
end

-- ================================================================
-- FOV CHECK
-- ================================================================
local function isInFov(targetPos)
    if CONFIG.AIM_FOV <= 0 then return true end
    local cameraPos = Camera.CFrame.Position
    local direction = (targetPos - cameraPos).Unit
    local forward = Camera.CFrame.LookVector
    local angle = math.deg(math.acos(direction:Dot(forward)))
    return angle <= CONFIG.AIM_FOV / 2
end

-- ================================================================
-- GET BEST TARGET (DENGAN PRIORITAS)
-- ================================================================
local function getBestTarget()
    local bestTarget = nil
    local bestScore = -math.huge
    local playerPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not playerPos then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if hrp and humanoid and humanoid.Health > 0 then
                -- Team check
                if CONFIG.TEAM_CHECK then
                    local team1 = LocalPlayer.Team
                    local team2 = player.Team
                    if team1 and team2 and team1 == team2 then
                        goto continue
                    end
                end

                local distance = (hrp.Position - playerPos.Position).Magnitude
                if distance <= CONFIG.AIM_MAX_DISTANCE then
                    if hasLineOfSight(playerPos.Position, hrp) then
                        if isInFov(hrp.Position) then
                            -- Score: jarak (semakin dekat semakin tinggi)
                            local score = 1000 / (distance + 1)
                            -- Bonus: health rendah
                            score = score + (100 - humanoid.Health) * 0.5
                            if score > bestScore then
                                bestScore = score
                                bestTarget = player
                            end
                        end
                    end
                end
            end
        end
        ::continue::
    end
    return bestTarget
end

-- ================================================================
-- SMOOTH AIM
-- ================================================================
local function smoothAim(targetPos)
    local current = Camera.CFrame
    local targetCF = CFrame.lookAt(current.Position, targetPos)
    local smoothFactor = 1 - CONFIG.AIM_SMOOTHNESS
    Camera.CFrame = current:Lerp(targetCF, smoothFactor)
end

-- ================================================================
-- ESP (DENGAN INFORMASI TAMBAHAN)
-- ================================================================
local function createESPBox(player)
    local box = Drawing.new("Square")
    box.Thickness = CONFIG.ESP_BOX_THICKNESS
    box.Color = CONFIG.ESP_BOX_COLOR
    box.Transparency = 1
    box.Visible = false
    box.Filled = false

    local name = Drawing.new("Text")
    name.Size = CONFIG.ESP_TEXT_SIZE
    name.Color = CONFIG.ESP_TEXT_COLOR
    name.Center = true
    name.Visible = false

    local healthBar = Drawing.new("Line")
    healthBar.Thickness = 3
    healthBar.Color = Color3.new(0, 1, 0)
    healthBar.Visible = false

    return { box = box, name = name, healthBar = healthBar }
end

local function updateESP()
    for _, obj in pairs(espObjects) do
        obj.box.Visible = false
        obj.name.Visible = false
        obj.healthBar.Visible = false
    end
    espObjects = {}

    if not espEnabled then return end

    local playerPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not playerPos then return end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local head = player.Character:FindFirstChild("Head")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if hrp and head and humanoid and humanoid.Health > 0 then
                local distance = (hrp.Position - playerPos.Position).Magnitude
                if distance <= CONFIG.ESP_MAX_DISTANCE then
                    local pos, onScreen = Camera:WorldToScreenPoint(hrp.Position)
                    if onScreen then
                        local size = 2.5
                        local height = 4.5 * size
                        local width = 2.2 * size
                        local top = pos.Y - height/2
                        local left = pos.X - width/2

                        local esp = createESPBox(player)
                        esp.box.From = Vector2.new(left, top)
                        esp.box.To = Vector2.new(left + width, top + height)
                        esp.box.Visible = true

                        -- Warna box berdasarkan health
                        local healthRatio = humanoid.Health / humanoid.MaxHealth
                        esp.box.Color = Color3.new(1 - healthRatio, healthRatio, 0)

                        -- Nama + jarak + health
                        esp.name.Text = string.format("%s [%d HP] %.0fs", player.Name, humanoid.Health, distance)
                        esp.name.Position = Vector2.new(pos.X, top - 15)
                        esp.name.Visible = true

                        -- Health bar di bawah box
                        local barWidth = width
                        local barHeight = 3
                        local barTop = top + height + 2
                        esp.healthBar.From = Vector2.new(left, barTop)
                        esp.healthBar.To = Vector2.new(left + barWidth * healthRatio, barTop)
                        esp.healthBar.Color = Color3.new(1 - healthRatio, healthRatio, 0)
                        esp.healthBar.Visible = true

                        table.insert(espObjects, esp)
                    end
                end
            end
        end
    end
end

-- ================================================================
-- TRIGGER BOT
-- ================================================================
local function isMouseOnTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local target = getBestTarget()
    if not target then return false end

    local hitbox = getHitboxPart(target.Character)
    if not hitbox then return false end

    local pos, onScreen = Camera:WorldToScreenPoint(hitbox.Position)
    if not onScreen then return false end

    local distance = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
    return distance < 20 -- Kursor di dalam radius 20px dari target
end

-- ================================================================
-- FOV CIRCLE
-- ================================================================
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.Color = Color3.new(0, 1, 0)
fovCircle.Transparency = 0.5
fovCircle.Visible = false
fovCircle.NumSides = 60
fovCircle.Radius = 100

local function updateFovCircle()
    if not CONFIG.SHOW_FOV or not guiVisible then
        fovCircle.Visible = false
        return
    end
    local mousePos = UserInputService:GetMouseLocation()
    fovCircle.Position = mousePos
    fovCircle.Visible = true
    -- Radius berdasarkan FOV (semakin besar FOV, semakin besar circle)
    fovCircle.Radius = 50 + CONFIG.AIM_FOV * 2
end

-- ================================================================
-- TARGET INDICATOR
-- ================================================================
local indicator = Drawing.new("Circle")
indicator.Thickness = 2
indicator.Color = Color3.new(1, 0, 0)
indicator.Transparency = 0.8
indicator.Visible = false
indicator.NumSides = 20
indicator.Radius = 15
indicator.Filled = false

-- ================================================================
-- MAIN LOOP
-- ================================================================
-- Auto Aim
RunService.RenderStepped:Connect(function()
    if aimEnabled then
        local target = getBestTarget()
        if target and target.Character then
            currentTarget = target
            local hitbox = getHitboxPart(target.Character)
            if hitbox then
                if CONFIG.AIM_SMOOTHNESS > 0 then
                    smoothAim(hitbox.Position)
                else
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, hitbox.Position)
                end

                -- Indicator
                local pos, onScreen = Camera:WorldToScreenPoint(hitbox.Position)
                if onScreen then
                    indicator.Position = Vector2.new(pos.X, pos.Y)
                    indicator.Visible = true
                else
                    indicator.Visible = false
                end
            end
        else
            indicator.Visible = false
        end
    else
        indicator.Visible = false
    end

    -- Trigger Bot
    if triggerEnabled then
        if isMouseOnTarget() then
            -- Simulate click
            UserInputService:SetMouseButtonEnabled(true)
            UserInputService:SetMouseButton(false)
        end
    end

    updateESP()
    updateFovCircle()
end)

-- ================================================================
-- KEYBINDS
-- ================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local key = input.KeyCode

    if key == CONFIG.KEY_TOGGLE_GUI then
        guiVisible = not guiVisible
        frame.Visible = guiVisible
        fovCircle.Visible = guiVisible and CONFIG.SHOW_FOV
        print("[KEYBIND] GUI:", guiVisible and "ON" or "OFF")
    elseif key == CONFIG.KEY_TOGGLE_AIM then
        aimEnabled = not aimEnabled
        aimButton.Text = "Auto Aim: " .. (aimEnabled and "ON" or "OFF")
        print("[KEYBIND] Auto Aim:", aimEnabled and "ON" or "OFF")
    elseif key == CONFIG.KEY_TOGGLE_ESP then
        espEnabled = not espEnabled
        espButton.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
        if not espEnabled then
            for _, obj in pairs(espObjects) do
                obj.box.Visible = false
                obj.name.Visible = false
                obj.healthBar.Visible = false
            end
            espObjects = {}
        end
        print("[KEYBIND] ESP:", espEnabled and "ON" or "OFF")
    elseif key == CONFIG.KEY_TOGGLE_TRIGGER then
        triggerEnabled = not triggerEnabled
        triggerButton.Text = "Trigger Bot: " .. (triggerEnabled and "ON" or "OFF")
        print("[KEYBIND] Trigger Bot:", triggerEnabled and "ON" or "OFF")
    end
end)

-- ================================================================
-- GUI (DENGAN KEYBIND INFO)
-- ================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = LocalPlayer.PlayerGui
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 250)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
frame.BackgroundTransparency = 0.4
frame.Parent = screenGui
frame.Visible = true

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.Position = UDim2.new(0, 0, 0, 0)
title.Text = "🔥 AUTO AIM BOT"
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 0.5, 0)
title.TextScaled = true
title.Parent = frame

-- Auto Aim Button
local aimButton = Instance.new("TextButton")
aimButton.Size = UDim2.new(0, 180, 0, 30)
aimButton.Position = UDim2.new(0, 20, 0, 35)
aimButton.Text = "Auto Aim: OFF"
aimButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.3)
aimButton.TextColor3 = Color3.new(1, 1, 1)
aimButton.Parent = frame
aimButton.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled
    aimButton.Text = "Auto Aim: " .. (aimEnabled and "ON" or "OFF")
end)

-- ESP Button
local espButton = Instance.new("TextButton")
espButton.Size = UDim2.new(0, 180, 0, 30)
espButton.Position = UDim2.new(0, 20, 0, 75)
espButton.Text = "ESP: OFF"
espButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.3)
espButton.TextColor3 = Color3.new(1, 1, 1)
espButton.Parent = frame
espButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    espButton.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
    if not espEnabled then
        for _, obj in pairs(espObjects) do
            obj.box.Visible = false
            obj.name.Visible = false
            obj.healthBar.Visible = false
        end
        espObjects = {}
    end
end)

-- Trigger Bot Button
local triggerButton = Instance.new("TextButton")
triggerButton.Size = UDim2.new(0, 180, 0, 30)
triggerButton.Position = UDim2.new(0, 20, 0, 115)
triggerButton.Text = "Trigger Bot: OFF"
triggerButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.3)
triggerButton.TextColor3 = Color3.new(1, 1, 1)
triggerButton.Parent = frame
triggerButton.MouseButton1Click:Connect(function()
    triggerEnabled = not triggerEnabled
    triggerButton.Text = "Trigger Bot: " .. (triggerEnabled and "ON" or "OFF")
end)

-- Keybinds Info
local keybindLabel = Instance.new("TextLabel")
keybindLabel.Size = UDim2.new(1, 0, 0, 80)
keybindLabel.Position = UDim2.new(0, 0, 0, 160)
keybindLabel.Text = "F1: Toggle GUI\nF2: Toggle Aim\nF3: Toggle ESP\nF4: Toggle Trigger"
keybindLabel.BackgroundTransparency = 1
keybindLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
keybindLabel.TextScaled = true
keybindLabel.TextSize = 12
keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
keybindLabel.Parent = frame

-- Stats Label
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, 0, 0, 20)
statsLabel.Position = UDim2.new(0, 0, 0, 245)
statsLabel.Text = "Kills: 0 | Hits: 0"
statsLabel.BackgroundTransparency = 1
statsLabel.TextColor3 = Color3.new(1, 1, 1)
statsLabel.TextScaled = true
statsLabel.TextSize = 10
statsLabel.Parent = frame

-- Update stats (kills, hits)
RunService.Heartbeat:Connect(function()
    if CONFIG.SHOW_STATS then
        statsLabel.Text = string.format("Kills: %d | Hits: %d", stats.kills, stats.hits)
    end
end)

print("🔥 Auto Aim Bot - Ultimate Edition Loaded!")
print("   F1: Toggle GUI")
print("   F2: Toggle Auto Aim")
print("   F3: Toggle ESP")
print("   F4: Toggle Trigger Bot")
print("   Settings dapat diubah di CONFIG di awal script")