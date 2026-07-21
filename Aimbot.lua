-- [[ HYBRID STRICT LOCK V7.6 - MOBILE + FACE LOCK EDITION ]]
local SETTINGS = {
    CENTER_Y = -70,
    FOV_RADIUS = 120,
    LOCK_ENABLED = false,
    TARGET_MODE = "Monster",
    HIGHLIGHT_COLOR = Color3.fromRGB(255, 255, 0),
    FOV_COLOR = Color3.fromRGB(255, 0, 0)
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- [[ 1. Visuals Setup & UI ]]
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HybridAimGui"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local ControlPanel = Instance.new("Frame", ScreenGui)
ControlPanel.Size = UDim2.new(0, 160, 0, 90)
ControlPanel.Position = UDim2.new(0.8, -170, 0.1, 0)
ControlPanel.BackgroundTransparency = 1 
ControlPanel.Active = true

local Toggle = Instance.new("TextButton", ControlPanel)
Toggle.Size = UDim2.new(1, 0, 0, 35)
Toggle.Position = UDim2.new(0, 0, 0, 0)
Toggle.Text = "HYBRID AIM: OFF"; Toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Toggle.TextColor3 = Color3.fromRGB(255, 255, 255); Toggle.Font = Enum.Font.SourceSansBold
Instance.new("UICorner", Toggle)

local ModeBtn = Instance.new("TextButton", ControlPanel)
ModeBtn.Size = UDim2.new(1, 0, 0, 35)
ModeBtn.Position = UDim2.new(0, 0, 0, 45)
ModeBtn.Text = "MODE: MONSTER"; ModeBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
ModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); ModeBtn.Font = Enum.Font.SourceSansBold
Instance.new("UICorner", ModeBtn)

local RedDot = Instance.new("Frame", ScreenGui)
RedDot.Size = UDim2.new(0, 6, 0, 6); RedDot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
RedDot.Position = UDim2.new(0.5, 0, 0.5, SETTINGS.CENTER_Y); RedDot.AnchorPoint = Vector2.new(0.5, 0.5)
Instance.new("UICorner", RedDot)

local MobileFOVCircle = Instance.new("Frame", ScreenGui)
MobileFOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
MobileFOVCircle.BackgroundColor3 = SETTINGS.FOV_COLOR
MobileFOVCircle.BackgroundTransparency = 1 
MobileFOVCircle.Size = UDim2.new(0, SETTINGS.FOV_RADIUS * 2, 0, SETTINGS.FOV_RADIUS * 2)
MobileFOVCircle.Position = UDim2.new(0.5, 0, 0.5, SETTINGS.CENTER_Y)

local FOVStroke = Instance.new("UIStroke", MobileFOVCircle)
FOVStroke.Color = SETTINGS.FOV_COLOR; FOVStroke.Thickness = 1.2
Instance.new("UICorner", MobileFOVCircle).CornerRadius = UDim.new(1, 0)

local TargetHighlight = Instance.new("Highlight")
TargetHighlight.FillTransparency = 1
TargetHighlight.OutlineColor = SETTINGS.HIGHLIGHT_COLOR
TargetHighlight.Enabled = false

-- [[ 2. ระบบ Drag ลากย้ายปุ่ม ]]
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    ControlPanel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

local function TargetDrag(ButtonInstance)
    ButtonInstance.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = ControlPanel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    ButtonInstance.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
end
TargetDrag(Toggle); TargetDrag(ModeBtn)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then update(input) end
end)

-- [[ 3. ฟังก์ชันสแกนหาเป้าหมาย ]]
local GlobalTarget = nil 
local ActivePrediction = nil 

local function GetTargetPart(Character)
    return Character:FindFirstChild("LeftFoot") or 
           Character:FindFirstChild("RightFoot") or 
           Character:FindFirstChild("LowerTorso") or 
           Character:FindFirstChild("HumanoidRootPart")
end

task.spawn(function()
    while true do
        task.wait(0.5) 
        Camera = workspace.CurrentCamera

        if not SETTINGS.LOCK_ENABLED then
            GlobalTarget = nil
        else
            local Char = LocalPlayer.Character
            local KeepCurrent = false
            if GlobalTarget and GlobalTarget.Parent and GlobalTarget.Parent:FindFirstChild("Humanoid") then
                if GlobalTarget.Parent.Humanoid.Health > 0 and GlobalTarget.Parent.Parent ~= nil then KeepCurrent = true end
            end

            if not KeepCurrent then
                local NewTarget = nil
                local MinDist = SETTINGS.FOV_RADIUS 
                local CrosshairPos = Vector2.new(Camera.ViewportSize.X / 2, (Camera.ViewportSize.Y / 2) + SETTINGS.CENTER_Y)

                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("Humanoid") and obj.Health > 0 and obj.Parent then
                        local TargetChar = obj.Parent
                        if TargetChar ~= Char and TargetChar:FindFirstChild("HumanoidRootPart") then
                            local IsPlayer = Players:GetPlayerFromCharacter(TargetChar)
                            local IsValidTarget = (SETTINGS.TARGET_MODE == "Monster" and not IsPlayer) or (SETTINGS.TARGET_MODE == "Player" and IsPlayer)

                            if IsValidTarget then
                                local AimPart = GetTargetPart(TargetChar)
                                if AimPart then
                                    local ScreenPos, OnScreen = Camera:WorldToViewportPoint(AimPart.Position)
                                    if OnScreen then
                                        local Dist = (Vector2.new(ScreenPos.X, ScreenPos.Y) - CrosshairPos).Magnitude
                                        if Dist < MinDist then
                                            MinDist = Dist; NewTarget = AimPart
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                GlobalTarget = NewTarget
            end
        end
    end
end)

local function UpdatePrediction()
    if not GlobalTarget or not GlobalTarget.Parent then return nil end
    local Char = LocalPlayer.Character
    local MyRoot = Char and Char:FindFirstChild("HumanoidRootPart")
    local TargetRoot = GlobalTarget.Parent:FindFirstChild("HumanoidRootPart")
    
    if MyRoot and TargetRoot then
        local targetVelocity = TargetRoot.Velocity
        local distance = (MyRoot.Position - TargetRoot.Position).Magnitude
        
        local predictionTime = 0
        if distance >= 100 and distance <= 200 then predictionTime = 0.3
        elseif distance > 200 then predictionTime = 0.6 end
        
        return GlobalTarget.Position + (targetVelocity * predictionTime)
    end
    return GlobalTarget.Position
end

-- [[ 4. ระบบอัปเดตหน้าจอหลัก (RenderStepped) + ⚡ ระบบ FACE LOCK ⚡ ]]
RunService.RenderStepped:Connect(function()
    Camera = workspace.CurrentCamera
    MobileFOVCircle.Position = UDim2.new(0.5, 0, 0.5, SETTINGS.CENTER_Y)
    MobileFOVCircle.Size = UDim2.new(0, SETTINGS.FOV_RADIUS * 2, 0, SETTINGS.FOV_RADIUS * 2)

    if SETTINGS.LOCK_ENABLED and GlobalTarget and GlobalTarget.Parent then
        ActivePrediction = UpdatePrediction()
        
        -- [ระบบ Face Lock ทำงานตรงนี้]
        local Char = LocalPlayer.Character
        local MyRoot = Char and Char:FindFirstChild("HumanoidRootPart")
        if MyRoot then
            -- ใช้ CFrame.lookAt ล็อคเป้าหมาย โดยล็อคแกน Y ของตัวเราไว้กันตัวละครเอียง/มุดดิน
            local targetPos = GlobalTarget.Position
            local lookAtPos = Vector3.new(targetPos.X, MyRoot.Position.Y, targetPos.Z)
            MyRoot.CFrame = CFrame.lookAt(MyRoot.Position, lookAtPos)
        end
        
        -- จัดการ Highlight ESP
        local _, OnScreen = Camera:WorldToViewportPoint(GlobalTarget.Position)
        if OnScreen then
            if TargetHighlight.Parent ~= GlobalTarget.Parent then TargetHighlight.Parent = GlobalTarget.Parent end
            TargetHighlight.Enabled = true
        else
            TargetHighlight.Enabled = false 
        end
    else
        ActivePrediction = nil
        TargetHighlight.Enabled = false
    end
end)

-- [[ 5. METATABLE ENGINE ]]
local mt = getrawmetatable(game)
local oldIndex = mt.__index
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__index = newcclosure(function(self, index)
    if not checkcaller() and SETTINGS.LOCK_ENABLED and ActivePrediction then
        if self == Mouse and (index == "Hit" or index == "TargetPoint") then
            return (index == "Hit" and CFrame.new(ActivePrediction) or ActivePrediction)
        end
    end
    return oldIndex(self, index)
end)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    if not checkcaller() and SETTINGS.LOCK_ENABLED and ActivePrediction then
        if self == UserInputService and (method == "GetMouseLocation" or method == "GetMousePosition") then
            local ScreenPos, _ = Camera:WorldToViewportPoint(ActivePrediction)
            return Vector2.new(ScreenPos.X, ScreenPos.Y)
        end

        if method == "Raycast" and self == workspace then
            local args = {...}
            local origin = args[1]
            if typeof(origin) == "Vector3" then
                local direction = (ActivePrediction - origin).Unit * 1000 
                args[2] = direction
                return oldNamecall(self, unpack(args))
            end
        end

        if (method == "ViewportPointToRay" or method == "ScreenPointToRay") and self == workspace.CurrentCamera then
            local origin = self.CFrame.Position
            local direction = (ActivePrediction - origin).Unit
            return Ray.new(origin, direction)
        end
    end
    
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

-- [[ 6. ควบคุมปุ่ม ]]
Toggle.MouseButton1Click:Connect(function()
    if dragging then return end
    SETTINGS.LOCK_ENABLED = not SETTINGS.LOCK_ENABLED
    GlobalTarget = nil
    if SETTINGS.LOCK_ENABLED then
        Toggle.Text = "HYBRID AIM: ON"; Toggle.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    else
        Toggle.Text = "HYBRID AIM: OFF"; Toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        TargetHighlight.Enabled = false; TargetHighlight.Parent = nil
    end
end)

ModeBtn.MouseButton1Click:Connect(function()
    if dragging then return end
    GlobalTarget = nil 
    if SETTINGS.TARGET_MODE == "Monster" then
        SETTINGS.TARGET_MODE = "Player"
        ModeBtn.Text = "MODE: PLAYER"; ModeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    else
        SETTINGS.TARGET_MODE = "Monster"
        ModeBtn.Text = "MODE: MONSTER"; ModeBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
    end
    TargetHighlight.Enabled = false; TargetHighlight.Parent = nil
end)

