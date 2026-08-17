--[[
    Script: Auto Aim + ESP (Pro) - FIXED
    Fitur:
        - Auto Aim: mengarahkan kamera ke musuh terdekat (terlihat)
        - ESP: menampilkan box dan nama pemain musuh dalam radius tertentu
    Perbaikan:
        - Auto Aim sekarang berfungsi dengan CFrame.lookAt
        - Line of sight lebih ringan
        - Target diurutkan berdasarkan jarak
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
    ESP_MAX_DISTANCE = 150,
    AIM_MAX_DISTANCE = 300,
    ESP_BOX_COLOR = Color3.new(1, 0, 0),
    ESP_BOX_THICKNESS = 1,
    ESP_TEXT_SIZE = 12,
    ESP_TEXT_COLOR = Color3.new(1, 1, 1),
    SMOOTH_AIM = false,  -- false = instant, true = smooth (belum diimplementasikan)
}

-- ================================================================
-- SETUP VARIABEL
-- ================================================================
local espEnabled = false
local aimEnabled = false
local espObjects = {}

-- ================================================================
-- LINE OF SIGHT CHECK (SIMPLE)
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

    -- Jika kena target, dianggap visible
    local hit = result.Instance
    if hit and (hit:IsDescendantOf(targetPart.Parent) or hit:IsDescendantOf(targetPart)) then
        return true
    end
    return false
end

-- ================================================================
-- GET TARGET PLAYER (TERDEKAT + VISIBLE)
-- ================================================================
local function getBestTarget()
    local bestTarget = nil
    local bestDistance = math.huge
    local playerPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not playerPos then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if head and hrp and humanoid and humanoid.Health > 0 then
                local targetPos = hrp.Position
                local distance = (targetPos - playerPos.Position).Magnitude
                if distance <= CONFIG.AIM_MAX_DISTANCE then
                    if hasLineOfSight(playerPos.Position, hrp) then
                        if distance < bestDistance then
                            bestDistance = distance
                            bestTarget = player
                        end
                    end
                end
            end
        end
    end
    return bestTarget, bestDistance
end

-- ================================================================
-- ESP
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

    return { box = box, name = name }
end

local function updateESP()
    for _, obj in pairs(espObjects) do
        obj.box.Visible = false
        obj.name.Visible = false
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

                        esp.name.Text = player.Name .. " (" .. math.floor(distance) .. "s)"
                        esp.name.Position = Vector2.new(pos.X, top - 15)
                        esp.name.Visible = true

                        table.insert(espObjects, esp)
                    end
                end
            end
        end
    end
end

-- ================================================================
-- AUTO AIM LOOP
-- ================================================================
RunService.RenderStepped:Connect(function()
    if aimEnabled then
        local target, dist = getBestTarget()
        if target and target.Character then
            local hrp = target.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local targetPos = hrp.Position
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
            end
        end
    end
end)

-- ESP Update
RunService.RenderStepped:Connect(function()
    updateESP()
end)

-- ================================================================
-- GUI
-- ================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = LocalPlayer.PlayerGui
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 150)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
frame.BackgroundTransparency = 0.5
frame.Parent = screenGui

local aimButton = Instance.new("TextButton")
aimButton.Size = UDim2.new(0, 180, 0, 30)
aimButton.Position = UDim2.new(0, 10, 0, 10)
aimButton.Text = "Auto Aim: OFF"
aimButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
aimButton.TextColor3 = Color3.new(1, 1, 1)
aimButton.Parent = frame
aimButton.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled
    aimButton.Text = "Auto Aim: " .. (aimEnabled and "ON" or "OFF")
end)

local espButton = Instance.new("TextButton")
espButton.Size = UDim2.new(0, 180, 0, 30)
espButton.Position = UDim2.new(0, 10, 0, 50)
espButton.Text = "ESP: OFF"
espButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
espButton.TextColor3 = Color3.new(1, 1, 1)
espButton.Parent = frame
espButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    espButton.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
    if not espEnabled then
        for _, obj in pairs(espObjects) do
            obj.box.Visible = false
            obj.name.Visible = false
        end
        espObjects = {}
    end
end)

print("[✅] Auto Aim + ESP Pro loaded!")
