local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local FILE_PREFIX = "DT_Macro_"
local STATE_FILE = FILE_PREFIX .. "SystemState.json"

local lastP = nil
local lastCamCF = nil
local CamConnection = nil
local NoclipConnection = nil 
local CurrentTargetCameraCFrame = nil
local run_check = 0
local lastClickTime = 0 

local MacroData = {
    IsRecording = false,
    IsPlaying = false,
    StartTime = 0,
    CurrentIndex = 1,
    OffsetX = 30, 
    OffsetY = 55, 
    ActiveProfileName = "", 
    Profiles = {}
}

local RECORD_KEYS = {
    "E","Z","X","C","V","T","J","R","F","Q","G","H","Space",
    "One","Two","Three","Four","Five"
}

-- [[ สร้างหน้าจอหลักแบบ V16.2 ]]
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DreamTeamMacro_V16_2_Ultimate_Edition"
ScreenGui.ResetOnSpawn = false

local successGui, errGui = pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not successGui then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local function MakeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local AutoMinimizeRegistry = {}

local function AddMinimizeFeature(frame, expandedHeight)
    local minBtn = Instance.new("TextButton", frame)
    minBtn.Size = UDim2.new(0, 24, 0, 20)
    minBtn.Position = UDim2.new(1, -28, 0, 4)
    minBtn.Text = "-"
    minBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.Font = Enum.Font.SourceSansBold
    minBtn.TextSize = 14
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)

    local isMinimized = false
    
    local function ToggleMinimize(forceMinimize)
        if forceMinimize ~= nil then
            isMinimized = forceMinimize
        else
            isMinimized = not isMinimized
        end
        
        if isMinimized then
            for _, child in ipairs(frame:GetChildren()) do
                if child ~= minBtn and not child:IsA("UICorner") and child.Name ~= "Title" then
                    if child:IsA("GuiObject") then child.Visible = false end
                end
            end
            frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 28)
            minBtn.Text = "+"
        else
            frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, expandedHeight)
            for _, child in ipairs(frame:GetChildren()) do
                if child.Name ~= "RenamePopup" then
                    if child:IsA("GuiObject") then child.Visible = true end
                end
            end
            minBtn.Text = "-"
        end
    end

    minBtn.MouseButton1Click:Connect(function()
        ToggleMinimize()
    end)
    
    table.insert(AutoMinimizeRegistry, function()
        ToggleMinimize(true)
    end)
end

-- ส่วนที่ 1: CURRENT (ฝั่งซ้าย)
local PlayFrame = Instance.new("Frame", ScreenGui)
PlayFrame.Size = UDim2.new(0, 170, 0, 175)
PlayFrame.Position = UDim2.new(0, 15, 0, 40)
PlayFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PlayFrame.BackgroundTransparency = 0.1
Instance.new("UICorner", PlayFrame).CornerRadius = UDim.new(0, 10)
MakeDraggable(PlayFrame)
AddMinimizeFeature(PlayFrame, 175)

local TitlePlay = Instance.new("TextLabel", PlayFrame)
TitlePlay.Name = "Title"
TitlePlay.Size = UDim2.new(1, -35, 0, 22)
TitlePlay.Position = UDim2.new(0, 8, 0, 4)
TitlePlay.Text = "CURRENT: NONE"
TitlePlay.TextColor3 = Color3.fromRGB(0, 200, 255)
TitlePlay.Font = Enum.Font.SourceSansBold
TitlePlay.TextSize = 13
TitlePlay.TextXAlignment = Enum.TextXAlignment.Left
TitlePlay.BackgroundTransparency = 1

local ProgressLabel = Instance.new("TextLabel", PlayFrame)
ProgressLabel.Size = UDim2.new(1, 0, 0, 18)
ProgressLabel.Position = UDim2.new(0, 0, 0, 27)
ProgressLabel.Text = "Node: -/-"
ProgressLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
ProgressLabel.Font = Enum.Font.SourceSans
ProgressLabel.TextSize = 12
ProgressLabel.BackgroundTransparency = 1

local function CreatePlayBtn(text, pos, color)
    local btn = Instance.new("TextButton", PlayFrame)
    btn.Size = UDim2.new(0.85, 0, 0, 32)
    btn.Position = pos
    btn.Text = text
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 13
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local BtnRecord = CreatePlayBtn("⏺ RECORD", UDim2.new(0.075, 0, 0, 52), Color3.fromRGB(180, 40, 40))
local BtnPlay   = CreatePlayBtn("▶ PLAY",   UDim2.new(0.075, 0, 0, 92), Color3.fromRGB(40, 140, 40))

local DurationLabel = Instance.new("TextLabel", PlayFrame)
DurationLabel.Size = UDim2.new(1, 0, 0, 16)
DurationLabel.Position = UDim2.new(0, 0, 0, 134)
DurationLabel.Text = "Duration: --"
DurationLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
DurationLabel.Font = Enum.Font.SourceSans
DurationLabel.TextSize = 11
DurationLabel.BackgroundTransparency = 1

-- ส่วนที่ 2: CREATE PROFILE (ตรงกลาง)
local CreateFrame = Instance.new("Frame", ScreenGui)
CreateFrame.Size = UDim2.new(0, 170, 0, 110)
CreateFrame.Position = UDim2.new(0, 195, 0, 40)
CreateFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
CreateFrame.BackgroundTransparency = 0.1
Instance.new("UICorner", CreateFrame).CornerRadius = UDim.new(0, 10)
MakeDraggable(CreateFrame)
AddMinimizeFeature(CreateFrame, 110)

local TitleCreate = Instance.new("TextLabel", CreateFrame)
TitleCreate.Name = "Title"
TitleCreate.Size = UDim2.new(1, -35, 0, 22)
TitleCreate.Position = UDim2.new(0, 8, 0, 4)
TitleCreate.Text = "CREATE PROFILE"
TitleCreate.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleCreate.Font = Enum.Font.SourceSansBold
TitleCreate.TextSize = 13
TitleCreate.TextXAlignment = Enum.TextXAlignment.Left
TitleCreate.BackgroundTransparency = 1

local ProfileInput = Instance.new("TextBox", CreateFrame)
ProfileInput.Size = UDim2.new(0.82, 0, 0, 25)
ProfileInput.Position = UDim2.new(0.09, 0, 0, 32)
ProfileInput.PlaceholderText = "ชื่อโปรไฟล์"
ProfileInput.Text = ""
ProfileInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ProfileInput.TextColor3 = Color3.fromRGB(255, 255, 255)
ProfileInput.Font = Enum.Font.SourceSans
ProfileInput.TextSize = 13
Instance.new("UICorner", ProfileInput).CornerRadius = UDim.new(0, 5)

local BtnCreate = Instance.new("TextButton", CreateFrame)
BtnCreate.Size = UDim2.new(0.82, 0, 0, 28)
BtnCreate.Position = UDim2.new(0.09, 0, 0, 65)
BtnCreate.Text = "ADD NEW +"
BtnCreate.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
BtnCreate.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnCreate.Font = Enum.Font.SourceSansBold
BtnCreate.TextSize = 13
Instance.new("UICorner", BtnCreate).CornerRadius = UDim.new(0, 6)

-- ส่วนที่ 3: MACRO STORAGE (ฝั่งขวา)
local StorageFrame = Instance.new("Frame", ScreenGui)
StorageFrame.Size = UDim2.new(0, 195, 0, 175)
StorageFrame.Position = UDim2.new(0, 375, 0, 40)
StorageFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
StorageFrame.BackgroundTransparency = 0.1
Instance.new("UICorner", StorageFrame).CornerRadius = UDim.new(0, 10)
MakeDraggable(StorageFrame)
AddMinimizeFeature(StorageFrame, 175)

local TitleStorage = Instance.new("TextLabel", StorageFrame)
TitleStorage.Name = "Title"
TitleStorage.Size = UDim2.new(1, -35, 0, 22)
TitleStorage.Position = UDim2.new(0, 8, 0, 4)
TitleStorage.Text = "MACRO STORAGE"
TitleStorage.TextColor3 = Color3.fromRGB(0, 255, 150)
TitleStorage.Font = Enum.Font.SourceSansBold
TitleStorage.TextSize = 13
TitleStorage.TextXAlignment = Enum.TextXAlignment.Left
TitleStorage.BackgroundTransparency = 1

local ListScroll = Instance.new("ScrollingFrame", StorageFrame)
ListScroll.Size = UDim2.new(0.92, 0, 0.82, 0)
ListScroll.Position = UDim2.new(0.04, 0, 0.16, 0)
ListScroll.BackgroundTransparency = 1
ListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ListScroll.ScrollBarThickness = 3

local ListLayout = Instance.new("UIListLayout", ListScroll)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 4)

-- Rename Popup Frame
local RenamePopup = Instance.new("Frame", ScreenGui)
RenamePopup.Name = "RenamePopup"
RenamePopup.Size = UDim2.new(0, 200, 0, 90)
RenamePopup.Position = UDim2.new(0.5, -100, 0.4, 0)
RenamePopup.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
RenamePopup.Visible = false
Instance.new("UICorner", RenamePopup).CornerRadius = UDim.new(0, 10)
MakeDraggable(RenamePopup)

local RenameTitle = Instance.new("TextLabel", RenamePopup)
RenameTitle.Size = UDim2.new(1, 0, 0, 22)
RenameTitle.Position = UDim2.new(0, 0, 0, 4)
RenameTitle.Text = "RENAME PROFILE"
RenameTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
RenameTitle.Font = Enum.Font.SourceSansBold
RenameTitle.TextSize = 13
RenameTitle.BackgroundTransparency = 1

local RenameInput = Instance.new("TextBox", RenamePopup)
RenameInput.Size = UDim2.new(0.82, 0, 0, 25)
RenameInput.Position = UDim2.new(0.09, 0, 0, 28)
RenameInput.PlaceholderText = "ชื่อใหม่"
RenameInput.Text = ""
RenameInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
RenameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
RenameInput.Font = Enum.Font.SourceSans
RenameInput.TextSize = 13
Instance.new("UICorner", RenameInput).CornerRadius = UDim.new(0, 5)

local RenameTargetName = ""

local function CreateRenameConfirmBtn(text, pos, color)
    local btn = Instance.new("TextButton", RenamePopup)
    btn.Size = UDim2.new(0.38, 0, 0, 24)
    btn.Position = pos
    btn.Text = text
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local BtnRenameConfirm = CreateRenameConfirmBtn("✔ OK",     UDim2.new(0.09, 0, 0, 60), Color3.fromRGB(0, 150, 80))
local BtnRenameCancel  = CreateRenameConfirmBtn("✖ CANCEL", UDim2.new(0.53, 0, 0, 60), Color3.fromRGB(120, 30, 30))

-- ====================================================================
-- [[ ระบบเซฟ/โหลดสถานะ ]]
-- ====================================================================
local function FormatDataForSave(timeline)
    local formatted = {}
    for _, node in ipairs(timeline) do
        local copy = { Time = node.Time, Type = node.Type }
        if node.Type == "Walk" then
            copy.PosX = node.Position.X
            copy.PosY = node.Position.Y
            copy.PosZ = node.Position.Z
        elseif node.Type == "Click" then
            copy.X = node.X
            copy.Y = node.Y
        elseif node.Type == "CamTrack" then
            copy.CamComps = {node.CFrameValue:GetComponents()}
        elseif node.Type == "KeyPress" then
            copy.Key = node.Key
            copy.State = node.State
        end
        table.insert(formatted, copy)
    end
    return formatted
end

local function ParseLoadedData(timeline)
    local parsed = {}
    for _, node in ipairs(timeline) do
        local copy = { Time = node.Time, Type = node.Type }
        if node.Type == "Walk" then
            copy.Position = Vector3.new(node.PosX, node.PosY, node.PosZ)
        elseif node.Type == "Click" then
            copy.X = node.X
            copy.Y = node.Y
        elseif node.Type == "CamTrack" then
            copy.CFrameValue = CFrame.new(unpack(node.CamComps))
        elseif node.Type == "KeyPress" then
            copy.Key = node.Key
            copy.State = node.State
        end
        table.insert(parsed, copy)
    end
    return parsed
end

local function HardSaveToFile(name, timelineData)
    pcall(function()
        local cleanData = FormatDataForSave(timelineData)
        writefile(FILE_PREFIX .. name .. ".json", HttpService:JSONEncode(cleanData))
    end)
end

local function SaveCurrentSystemState(isPlaying)
    pcall(function()
        writefile(STATE_FILE, HttpService:JSONEncode({
            IsActiveBeforeLeave = isPlaying,
            LastActiveProfile = MacroData.ActiveProfileName
        }))
    end)
end

local function ForceEmergencySave()
    if MacroData.IsRecording and MacroData.ActiveProfileName ~= "" then
        MacroData.IsRecording = false
        table.insert(MacroData.Profiles[MacroData.ActiveProfileName], {
            Time = tick() - MacroData.StartTime,
            Type = "EndTime"
        })
        HardSaveToFile(MacroData.ActiveProfileName, MacroData.Profiles[MacroData.ActiveProfileName])
    end
    SaveCurrentSystemState(MacroData.IsPlaying)
end

pcall(function()
    GuiService.ErrorMessageChanged:Connect(function() ForceEmergencySave() end)
    NetworkClient.ChildRemoved:Connect(function() ForceEmergencySave() end)
end)

-- ====================================================================
-- [[ ระบบความเสถียร ]]
-- ====================================================================
local UpdateStorageUI
local StartPlaybackEngine

function GetCharacterElements()
    local Char = LocalPlayer.Character
    local Root = Char and Char:FindFirstChild("HumanoidRootPart")
    local Hum  = Char and Char:FindFirstChildOfClass("Humanoid")
    return Root, Hum
end

function SetControlsEnabled(enabled)
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if PlayerGui and PlayerGui:FindFirstChild("TouchGui") then
        PlayerGui.TouchGui.Enabled = enabled
    end
end

local function SetCameraEngineActive(active)
    if CamConnection then CamConnection:Disconnect() end
    if active then
        Camera.CameraType = Enum.CameraType.Scriptable
        CamConnection = RunService.RenderStepped:Connect(function()
            if MacroData.IsPlaying and CurrentTargetCameraCFrame then
                Camera.CameraType = Enum.CameraType.Scriptable
                Camera.CFrame = CurrentTargetCameraCFrame
            else
                if CamConnection then CamConnection:Disconnect() CamConnection = nil end
            end
        end)
    else
        if CamConnection then CamConnection:Disconnect() CamConnection = nil end
        Camera.CameraType = Enum.CameraType.Custom
    end
end

local function SetNoclipActive(active)
    if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
    if active then
        NoclipConnection = RunService.Stepped:Connect(function()
            if MacroData.IsPlaying then
                local Char = LocalPlayer.Character
                if Char then
                    for _, part in ipairs(Char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            else
                if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
            end
        end)
    end
end

local function StopPlayback()
    MacroData.IsPlaying = false
    MacroData.CurrentIndex = 1
    SaveCurrentSystemState(false)
    SetCameraEngineActive(false)
    SetNoclipActive(false) 
    local _, Hum = GetCharacterElements()
    if Hum then Hum:Move(Vector3.new(0,0,0)) end
    SetControlsEnabled(true)
    BtnPlay.Text = "▶ PLAY"
    BtnPlay.BackgroundColor3 = Color3.fromRGB(40, 140, 40)
    ProgressLabel.Text = "Node: -/-"
end

local function UpdateDurationLabel(profileName)
    if profileName == "" then DurationLabel.Text = "Duration: --" return end
    local profile = MacroData.Profiles[profileName]
    if not profile or #profile == 0 then DurationLabel.Text = "Duration: 0s" return end
    
    local lastTime = 0
    for i = #profile, 1, -1 do
        if profile[i].Type == "EndTime" or profile[i].Time then lastTime = profile[i].Time or 0 break end
    end
    
    local mins = math.floor(lastTime / 60)
    local secs = math.floor(lastTime % 60)
    if mins > 0 then
        DurationLabel.Text = string.format("Duration: %dm %ds | %d nodes", mins, secs, #profile)
    else
        DurationLabel.Text = string.format("Duration: %ds | %d nodes", secs, #profile)
    end
end

local function UpdateProgressLabel()
    local profile = MacroData.Profiles[MacroData.ActiveProfileName]
    if MacroData.IsPlaying and profile then
        ProgressLabel.Text = string.format("Node: %d/%d", MacroData.CurrentIndex, #profile)
    else
        ProgressLabel.Text = "Node: -/-"
    end
end

UpdateStorageUI = function()
    for _, child in ipairs(ListScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for name, profileData in pairs(MacroData.Profiles) do
        local durationStr = "0s"
        if #profileData > 0 then
            local t = 0
            for i = #profileData, 1, -1 do
                if profileData[i].Type == "EndTime" or profileData[i].Time then t = profileData[i].Time or 0 break end
            end
            local m = math.floor(t/60)
            local s = math.floor(t%60)
            durationStr = m > 0 and string.format("%dm%ds", m, s) or string.format("%ds", s)
        end

        local ItemRow = Instance.new("Frame", ListScroll)
        ItemRow.Size = UDim2.new(1, 0, 0, 38)
        ItemRow.BackgroundTransparency = 1

        local SelectBtn = Instance.new("TextButton", ItemRow)
        SelectBtn.Size = UDim2.new(0.52, 0, 0, 38)
        SelectBtn.Text = "📁 " .. name .. "\n⏱ " .. durationStr
        SelectBtn.BackgroundColor3 = (MacroData.ActiveProfileName == name) and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(45, 45, 45)
        SelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        SelectBtn.Font = Enum.Font.SourceSansBold
        SelectBtn.TextSize = 11
        SelectBtn.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", SelectBtn).CornerRadius = UDim.new(0, 5)

        local RenBtn = Instance.new("TextButton", ItemRow)
        RenBtn.Size = UDim2.new(0.21, 0, 0.85, 0)
        RenBtn.Position = UDim2.new(0.54, 0, 0.075, 0)
        RenBtn.Text = "REN"
        RenBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 160)
        RenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        RenBtn.Font = Enum.Font.SourceSansBold
        RenBtn.TextSize = 11
        Instance.new("UICorner", RenBtn).CornerRadius = UDim.new(0, 5)

        local DeleteBtn = Instance.new("TextButton", ItemRow)
        DeleteBtn.Size = UDim2.new(0.21, 0, 0.85, 0)
        DeleteBtn.Position = UDim2.new(0.77, 0, 0.075, 0)
        DeleteBtn.Text = "DEL"
        DeleteBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
        DeleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        DeleteBtn.Font = Enum.Font.SourceSansBold
        DeleteBtn.TextSize = 11
        Instance.new("UICorner", DeleteBtn).CornerRadius = UDim.new(0, 5)

        SelectBtn.MouseButton1Click:Connect(function()
            if MacroData.IsRecording or MacroData.IsPlaying then return end
            MacroData.ActiveProfileName = name
            TitlePlay.Text = "CURRENT: " .. string.upper(name)
            UpdateDurationLabel(name)
            UpdateStorageUI()
            SaveCurrentSystemState(false)
        end)

        RenBtn.MouseButton1Click:Connect(function()
            if MacroData.IsRecording or MacroData.IsPlaying then return end
            RenameTargetName = name
            RenameInput.Text = name
            RenamePopup.Visible = true
        end)

        DeleteBtn.MouseButton1Click:Connect(function()
            if MacroData.IsRecording or MacroData.IsPlaying then return end
            pcall(function()
                if isfile(FILE_PREFIX .. name .. ".json") then delfile(FILE_PREFIX .. name .. ".json") end
            end)
            MacroData.Profiles[name] = nil
            if MacroData.ActiveProfileName == name then
                MacroData.ActiveProfileName = ""
                TitlePlay.Text = "CURRENT: NONE"
                DurationLabel.Text = "Duration: --"
                SaveCurrentSystemState(false)
            end
            UpdateStorageUI()
        end)
    end
    ListScroll.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y)
end

BtnRenameConfirm.MouseButton1Click:Connect(function()
    local newName = RenameInput.Text:gsub("%s+", "")
    if newName == "" or newName == RenameTargetName then RenamePopup.Visible = false return end
    if MacroData.Profiles[newName] then return end

    MacroData.Profiles[newName] = MacroData.Profiles[RenameTargetName]
    MacroData.Profiles[RenameTargetName] = nil

    pcall(function()
        HardSaveToFile(newName, MacroData.Profiles[newName])
        if isfile(FILE_PREFIX .. RenameTargetName .. ".json") then delfile(FILE_PREFIX .. RenameTargetName .. ".json") end
    end)

    if MacroData.ActiveProfileName == RenameTargetName then
        MacroData.ActiveProfileName = newName
        TitlePlay.Text = "CURRENT: " .. string.upper(newName)
        UpdateDurationLabel(newName)
        SaveCurrentSystemState(MacroData.IsPlaying)
    end

    RenamePopup.Visible = false
    UpdateStorageUI()
end)

BtnRenameCancel.MouseButton1Click:Connect(function() RenamePopup.Visible = false end)

-- ====================================================================
-- [[ ตัวประมวลผลการจำลองทัช V16.2 ]]
-- ====================================================================
StartPlaybackEngine = function()
    local activeProfile = MacroData.Profiles[MacroData.ActiveProfileName]
    if not activeProfile or #activeProfile == 0 then StopPlayback() return end

    task.spawn(function()
        local Root, Hum = nil, nil
        while not Root or not Hum do Root, Hum = GetCharacterElements() task.wait(0.5) end

        local firstCameraCFrame = nil
        local startPosition = nil
        for _, node in ipairs(activeProfile) do
            if node.Type == "CamTrack" and not firstCameraCFrame then firstCameraCFrame = node.CFrameValue end
            if node.Type == "Walk"     and not startPosition     then startPosition     = node.Position     end
            if firstCameraCFrame and startPosition then break end
        end

        if firstCameraCFrame then CurrentTargetCameraCFrame = firstCameraCFrame SetCameraEngineActive(true) end

        SetNoclipActive(true)

        if startPosition then
            BtnPlay.Text = "PREPARING..."
            BtnPlay.BackgroundColor3 = Color3.fromRGB(240, 140, 0)
            Hum:MoveTo(startPosition)
            while MacroData.IsPlaying and Root and Hum and Hum.Health > 0 do
                if (Root.Position - startPosition).Magnitude <= 2.2 then break end
                Hum:MoveTo(startPosition)
                task.wait(0.1)
            end
        end

        if not MacroData.IsPlaying then return end
        BtnPlay.Text = "⏹ STOP"
        BtnPlay.BackgroundColor3 = Color3.fromRGB(200, 60, 0)

        MacroData.CurrentIndex = 1
        while MacroData.IsPlaying do
            if MacroData.CurrentIndex > #activeProfile then MacroData.CurrentIndex = 1 end

            local Node     = activeProfile[MacroData.CurrentIndex]
            local NextNode = activeProfile[MacroData.CurrentIndex + 1]
            local WaitTime = NextNode and math.max(0.01, NextNode.Time - Node.Time) or 0.05

            UpdateProgressLabel()

            if Node.Type == "CamTrack" then
                CurrentTargetCameraCFrame = Node.CFrameValue
                task.wait(WaitTime)

            elseif Node.Type == "Walk" then
                Root, Hum = GetCharacterElements()
                if Root and Hum and Hum.Health > 0 then
                    if Root.Position.Y < -500 then 
                        Root.CFrame = CFrame.new(Node.Position + Vector3.new(0, 3, 0))
                    end

                    Hum:MoveTo(Node.Position)
                    while MacroData.IsPlaying and Root and Hum and Hum.Health > 0 do
                        if (Root.Position - Node.Position).Magnitude <= 2.5 then break end
                        Hum:MoveTo(Node.Position)
                        task.wait(0.05)
                    end
                end
                task.wait(WaitTime)

            elseif Node.Type == "Click" then
                local cx = Node.X
                local cy = Node.Y
                
                if Node.Y < 40 then 
                    cx = cx + MacroData.OffsetX
                    cy = cy + 22 
                else
                    cx = cx + MacroData.OffsetX
                    cy = cy + MacroData.OffsetY
                end
                
                local viewSize = Camera.ViewportSize
                local minSafe = 15
                
                if cx < minSafe then cx = minSafe end
                if cy < minSafe then cy = minSafe end
                if cx > (viewSize.X - minSafe) then cx = viewSize.X - minSafe end
                if cy > (viewSize.Y - minSafe) then cy = viewSize.Y - minSafe end
                
                -- [[ ⚡ ปรับแต่งความนิ่งในการกดสั่งรันมาโครเพื่อแก้ปัญหาตัวละครออกเกิน ]]
                pcall(function()
                    VirtualInputManager:SendMouseMoveEvent(cx, cy, game)
                    task.wait(0.02)
                    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1) -- กดลง
                    task.wait(0.08) -- ⚡ ยืดเวลาแช่นิ้วขึ้นอีกเล็กน้อยให้เซิร์ฟเวอร์เกมล็อกเป้าและตอบสนองทัน
                    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1) -- ปล่อยนิ้วทันที ณ จุดเดิม ไม่สะบัด
                end)
                
                -- ⚡ บังคับหน่วงเวลาจบคำสั่งคลิก 0.18 วินาที เพื่อล้างดีเลย์ไม่ให้ประมวลผลคำสั่งถัดไปไวเกินไป
                task.wait(0.18)
                task.wait(math.max(0.01, WaitTime - 0.28))

            elseif Node.Type == "KeyPress" then
                local ok, keyCode = pcall(function()
                    return Node.Key == "Space" and Enum.KeyCode.Space or Enum.KeyCode[Node.Key]
                end)
                if ok and keyCode then
                    local inputState = Node.State and Enum.UserInputState.Begin or Enum.UserInputState.End
                    VirtualInputManager:SendKeyEvent(inputState, keyCode, false, game)
                end
                task.wait(WaitTime)
                
            elseif Node.Type == "EndTime" then
                task.wait(WaitTime)
            end

            MacroData.CurrentIndex = MacroData.CurrentIndex + 1
            run_check = run_check + 1
            if run_check % 5 == 0 then task.wait(0.01) end
        end
    end)
end

-- ====================================================================
-- [[ Auto-Resume Engine ]]
-- ====================================================================
local function AutoLoadAndResumeEngine()
    pcall(function()
        local allFiles = listfiles("")
        for _, fullPath in ipairs(allFiles) do
            if string.find(fullPath, FILE_PREFIX) and not string.find(fullPath, "SystemState.json") then
                local filename = string.sub(fullPath, #FILE_PREFIX + 1, #fullPath - 5)
                local rawTimeline = HttpService:JSONDecode(readfile(fullPath))
                if rawTimeline then MacroData.Profiles[filename] = ParseLoadedData(rawTimeline) end
            end
        end
        UpdateStorageUI()

        if isfile(STATE_FILE) then
            local stateData = HttpService:JSONDecode(readfile(STATE_FILE))
            if stateData and stateData.LastActiveProfile and stateData.LastActiveProfile ~= "" then
                if MacroData.Profiles[stateData.LastActiveProfile] then
                    MacroData.ActiveProfileName = stateData.LastActiveProfile
                    TitlePlay.Text = "CURRENT: " .. string.upper(stateData.LastActiveProfile)
                    UpdateDurationLabel(stateData.LastActiveProfile)
                    UpdateStorageUI()
                    
                    if stateData.IsActiveBeforeLeave then
                        MacroData.IsPlaying = true
                        SetControlsEnabled(false)
                        StartPlaybackEngine()
                    end
                end
            end
        end
    end)
end

AutoLoadAndResumeEngine()

for _, minimizeFunc in ipairs(AutoMinimizeRegistry) do
    pcall(minimizeFunc)
end

-- ====================================================================
-- [[ ปุ่มควบคุมต่างๆ ]]
-- ====================================================================
BtnCreate.MouseButton1Click:Connect(function()
    local name = ProfileInput.Text:gsub("%s+", "")
    if name == "" or MacroData.Profiles[name] then return end
    MacroData.Profiles[name] = {}
    HardSaveToFile(name, {})
    ProfileInput.Text = ""
    UpdateStorageUI()
end)

BtnRecord.MouseButton1Click:Connect(function()
    if MacroData.ActiveProfileName == "" or MacroData.IsPlaying then return end
    if not MacroData.IsRecording then
        MacroData.Profiles[MacroData.ActiveProfileName] = {}
        MacroData.IsRecording = true
        MacroData.StartTime = tick()
        lastP = nil
        lastCamCF = nil
        BtnRecord.Text = "⏹ STOP REC"
        BtnRecord.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    else
        MacroData.IsRecording = false
        BtnRecord.Text = "⏺ RECORD"
        BtnRecord.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        
        table.insert(MacroData.Profiles[MacroData.ActiveProfileName], {
            Time = tick() - MacroData.StartTime,
            Type = "EndTime"
        })
        
        HardSaveToFile(MacroData.ActiveProfileName, MacroData.Profiles[MacroData.ActiveProfileName])
        UpdateDurationLabel(MacroData.ActiveProfileName)
        UpdateStorageUI()
        SaveCurrentSystemState(false)
    end
end)

BtnPlay.MouseButton1Click:Connect(function()
    if MacroData.ActiveProfileName == "" or MacroData.IsRecording then return end
    local activeProfile = MacroData.Profiles[MacroData.ActiveProfileName]
    if not activeProfile or #activeProfile == 0 then return end

    if not MacroData.IsPlaying then
        MacroData.IsPlaying = true
        SaveCurrentSystemState(true)
        SetControlsEnabled(false)
        StartPlaybackEngine()
    else
        StopPlayback()
    end
end)

-- ====================================================================
-- [[ ⚡ ปรับจังหวะป้องกันนิ้วลั่นขณะบันทึกมาโคร (ขยายกรงดัก Cooldown) ]]
-- ====================================================================
UserInputService.TouchStarted:Connect(function(touch, processed)
    if not MacroData.IsRecording or MacroData.ActiveProfileName == "" then return end
    
    local objs = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(touch.Position.X, touch.Position.Y)
    for _, obj in ipairs(objs) do
        if obj:IsDescendantOf(PlayFrame) or obj:IsDescendantOf(CreateFrame) or obj:IsDescendantOf(StorageFrame) or obj:IsDescendantOf(RenamePopup) then return end
    end
    
    local currentTime = tick()
    -- ⚡ ขยายคูลดาวน์เป็น 0.2 วินาที เพื่อกรองการคลิกเบิ้ล/ลั่นโดยไม่ตั้งใจจากจอมือถือ
    if (currentTime - lastClickTime) > 0.20 then
        lastClickTime = currentTime
        table.insert(MacroData.Profiles[MacroData.ActiveProfileName], {
            Time = currentTime - MacroData.StartTime,
            Type = "Click",
            X = touch.Position.X,
            Y = touch.Position.Y
        })
    end
end)

local function HandleKeyEvent(input, isBegan)
    if not MacroData.IsRecording or MacroData.ActiveProfileName == "" then return end
    
    local keyName = input.KeyCode.Name
    if input.KeyCode == Enum.KeyCode.Space then keyName = "Space" end
    
    for _, k in ipairs(RECORD_KEYS) do
        if keyName == k then
            table.insert(MacroData.Profiles[MacroData.ActiveProfileName], {
                Time = tick() - MacroData.StartTime,
                Type = "KeyPress",
                Key  = keyName,
                State = isBegan
            })
            break
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Keyboard then HandleKeyEvent(input, true) end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Keyboard then HandleKeyEvent(input, false) end
end)

RunService.Heartbeat:Connect(function()
    if not MacroData.IsRecording or MacroData.ActiveProfileName == "" then return end
    local TimeStamp = tick() - MacroData.StartTime
    local Root, Hum = GetCharacterElements()

    local currentCamCF = Camera.CFrame
    local camMoved = not lastCamCF
        or (currentCamCF.Position - lastCamCF.Position).Magnitude > 0.1
        or math.acos(math.clamp(currentCamCF.LookVector:Dot(lastCamCF.LookVector), -1, 1)) > math.rad(1)

    if camMoved then
        table.insert(MacroData.Profiles[MacroData.ActiveProfileName], {
            Time = TimeStamp, Type = "CamTrack", CFrameValue = currentCamCF
        })
        lastCamCF = currentCamCF
    end

    if Root and Hum and Hum.Health > 0 then
        if not lastP or (Root.Position - lastP).Magnitude > 2.5 then
            table.insert(MacroData.Profiles[MacroData.ActiveProfileName], {
                Time = TimeStamp, Type = "Walk", Position = Root.Position
            })
            lastP = Root.Position
        end
    end
end)
