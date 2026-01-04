local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")


local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "ESP Hub",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "Made by Astraea Team",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)
local ConsoleTab = Window:CreateTab("Console", 4483362458)
local InfoTab = Window:CreateTab("Info", 4483362458)
local HighlightAddedConn, HighlightLoopConn
local ESPV1AddedConn, ESPV1RemovingConn, ESPV1LoopConn

getgenv().ESP = {
    Enabled = false,
    AutoJoin = true,
    TeamColors = true,
    TeamCheck = false,
    Tracers = false,
    TracerThickness = 1,
    Box = false,
    BoxThickness = 2
}

getgenv().Aimbot = {
    Enabled = false,
    TeamCheck = false,
    AimPart = "Head",
    MaxDistance = 1000, -- studs
    ShowFOV = true,
    FOV = 80,
    FOVColor = Color3.fromRGB(255, 0, 0)
}

getgenv().ESPv1 = {
    Enabled = false,
    FillTransparency = 0,
    OutlineTransparency = 0,
    AlwaysOnTop = true,
    TeamColors = true,
}

local consoleLines = {}

local ConsoleLabel = ConsoleTab:CreateParagraph({
    Title = "Output",
    Content = ""
})

local function log(t)
    table.insert(consoleLines, os.date("[%H:%M:%S] ") .. t)
    if #consoleLines > 40 then table.remove(consoleLines, 1) end
    ConsoleLabel:Set({ Title = "Output", Content = table.concat(consoleLines, "\n") })
end

local function getColor(player, useTeamColors)
    local teamColorsEnabled = useTeamColors
    if teamColorsEnabled == nil then
        teamColorsEnabled = getgenv().ESP.TeamColors
    end

    if teamColorsEnabled and player.TeamColor then
        return player.TeamColor.Color
    end
    return Color3.fromRGB(80,170,255)
end

local function passesTeamCheck(player)
    if not getgenv().ESP.TeamCheck then return true end
    if not lp.Team or not player.Team then return true end
    return player.Team ~= lp.Team
end


-- =========================
-- TRACER ESP (Drawing API)
-- =========================

local TracerFolder = {} -- stores Drawing objects

local function createTracer(player)
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = Color3.new(1,1,1)
    line.Thickness = getgenv().ESP.TracerThickness or 1
    line.Transparency = 1
    TracerFolder[player] = line
    return line
end

local function removeTracer(player)
    if TracerFolder[player] then
        TracerFolder[player]:Remove()
        TracerFolder[player] = nil
    end
end

local function updateTracers()
    if not getgenv().ESP.Tracers then
        for _, line in pairs(TracerFolder) do
            line.Visible = false
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 and passesTeamCheck(player) then
                local tracer = TracerFolder[player] or createTracer(player)

                local pos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    tracer.Thickness = getgenv().ESP.TracerThickness or 1
                    tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    tracer.To = Vector2.new(pos.X, pos.Y)
                    tracer.Visible = true
                else
                    tracer.Visible = false
                end
            else
                removeTracer(player)
            end
        end
    end
end

local TracerConn
local function setTracerLoop(on)
    if on and not TracerConn then
        TracerConn = RunService.RenderStepped:Connect(updateTracers)
    elseif not on and TracerConn then
        TracerConn:Disconnect()
        TracerConn = nil
        for _, line in pairs(TracerFolder) do
            line.Visible = false
        end
    end
end

Players.PlayerRemoving:Connect(function(p)
    removeTracer(p)
end)

-- =========================
-- SKELETON ESP (Drawing API)
-- =========================

local skeletonSegments = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "RightUpperLeg"},
    {"LowerTorso", "LeftUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"UpperTorso", "RightUpperArm"},
    {"UpperTorso", "LeftUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
}

local SkeletonLines = {}
local SkeletonConn

local function getPart(character, name)
    return character and character:FindFirstChild(name)
end

local function getSkeletonLines(player)
    if not SkeletonLines[player] then
        SkeletonLines[player] = {}
        for i = 1, #skeletonSegments do
            local line = Drawing.new("Line")
            line.Thickness = 1.5
            line.Transparency = 1
            line.Color = Color3.fromRGB(255, 255, 255)
            line.Visible = false
            SkeletonLines[player][i] = line
        end
    end
    return SkeletonLines[player]
end

local function clearSkeleton(player)
    local lines = SkeletonLines[player]
    if lines then
        for _, line in ipairs(lines) do
            line:Remove()
        end
        SkeletonLines[player] = nil
    end
end

Players.PlayerRemoving:Connect(clearSkeleton)

local function updateSkeleton()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and passesTeamCheck(player) then
            local character = player.Character
            local lines = getSkeletonLines(player)

            if character then
                for index, pair in ipairs(skeletonSegments) do
                    local a = getPart(character, pair[1])
                    local b = getPart(character, pair[2])
                    local line = lines[index]

                    if a and b then
                        local aPos, aVis = Camera:WorldToViewportPoint(a.Position)
                        local bPos, bVis = Camera:WorldToViewportPoint(b.Position)

                        if aVis and bVis then
                            line.From = Vector2.new(aPos.X, aPos.Y)
                            line.To = Vector2.new(bPos.X, bPos.Y)
                            line.Color = getColor(player)
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    else
                        line.Visible = false
                    end
                end
            else
                for _, line in ipairs(lines) do
                    line.Visible = false
                end
            end
        else
            clearSkeleton(player)
        end
    end
end

local function setSkeleton(on)
    if on and not SkeletonConn then
        SkeletonConn = RunService.RenderStepped:Connect(updateSkeleton)
    elseif not on and SkeletonConn then
        SkeletonConn:Disconnect()
        SkeletonConn = nil
        for _, lines in pairs(SkeletonLines) do
            for _, line in ipairs(lines) do
                line.Visible = false
            end
        end
    end
end


-- =========================
-- BOX ESP (Drawing API)
-- =========================

local BoxObjects = {}
local BoxConn

local function getBox(player)
    if not BoxObjects[player] then
        local sq = Drawing.new("Square")
        sq.Thickness = getgenv().ESP.BoxThickness or 2
        sq.Filled = false
        sq.Color = Color3.fromRGB(255, 255, 255)
        sq.Visible = false
        BoxObjects[player] = sq
    end
    return BoxObjects[player]
end

-- =========================
-- AIMBOT FOV CIRCLE
-- =========================

local FOVCircle
local FOVConn
local lastPointerPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

local function getPointerPosition()
    -- Mobile-friendly: prefer latest touch if available, otherwise mouse location.
    if UserInputService.TouchEnabled then
        local touches = UserInputService:GetTouches()
        if touches[1] then
            lastPointerPos = touches[1].Position
        end
        return lastPointerPos
    end
    local mousePos = UserInputService:GetMouseLocation()
    return Vector2.new(mousePos.X, mousePos.Y)
end

local function applyFOVCircleSettings()
    if FOVCircle then
        FOVCircle.Visible = getgenv().Aimbot.ShowFOV
        FOVCircle.Color = getgenv().Aimbot.FOVColor or Color3.fromRGB(255, 255, 255)
        FOVCircle.Radius = getgenv().Aimbot.FOV or 100
        FOVCircle.Thickness = 2
        FOVCircle.NumSides = 64
        FOVCircle.Filled = false
        FOVCircle.Transparency = 1
    end
end

local function ensureFOVCircle()
    if not FOVCircle then
        FOVCircle = Drawing.new("Circle")
        applyFOVCircleSettings()
    end
end

local function destroyFOVCircle()
    if FOVCircle then
        FOVCircle:Remove()
        FOVCircle = nil
    end
end

local function updateFOVCircle()
    if FOVCircle then
        FOVCircle.Position = getPointerPosition()
        applyFOVCircleSettings()
    end
end

local function setFOVCircle(enabled)
    getgenv().Aimbot.ShowFOV = enabled
    if enabled then
        ensureFOVCircle()
        if not FOVConn then
            FOVConn = RunService.RenderStepped:Connect(updateFOVCircle)
        end
        updateFOVCircle()
    else
        if FOVConn then
            FOVConn:Disconnect()
            FOVConn = nil
        end
        destroyFOVCircle()
    end
end

-- =========================
-- AIMBOT (from aaami.lua)
-- =========================

local AimbotConn
local AimTraceLine

local function aimbotPassesTeam(player)
    if not getgenv().Aimbot.TeamCheck then
        return true
    end
    if not lp.Team or not player.Team then
        return true
    end
    return lp.Team ~= player.Team
end

local function lookAt(target, eye)
    Camera.CFrame = CFrame.new(target, eye)
end

local function getClosestPlayerToCursor(targetPartName, maxDistance)
    local nearestPart = nil
    local nearestDist = math.huge
    local cursorPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local maxDist = maxDistance or 400

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and aimbotPassesTeam(player) then
            local char = player.Character
            local hum = char and char:FindFirstChildWhichIsA("Humanoid")
            if char and hum and hum.Health > 0 then
                local aimPart = char:FindFirstChild(targetPartName) or char:FindFirstChild("UpperTorso")
                if aimPart then
                    local screenPos, visible = Camera:WorldToViewportPoint(aimPart.Position)
                    if visible then
                        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - cursorPos).Magnitude
                        local worldDist = (aimPart.Position - Camera.CFrame.Position).Magnitude
                        if worldDist <= maxDist and screenDist < nearestDist then
                            nearestDist = screenDist
                            nearestPart = aimPart
                        end
                    end
                end
            end
        end
    end

    return nearestPart
end

local function setAimbot(state)
    getgenv().Aimbot.Enabled = state
    if state then
        if not AimbotConn then
            AimbotConn = RunService.RenderStepped:Connect(function()
                local part = getClosestPlayerToCursor(getgenv().Aimbot.AimPart or "Head", getgenv().Aimbot.MaxDistance or 400)
                if part then
                    lookAt(Camera.CFrame.Position, part.Position)
                end
            end)
        end
    else
        if AimbotConn then
            AimbotConn:Disconnect()
            AimbotConn = nil
        end
        if AimTraceLine then
            AimTraceLine.Visible = false
        end
    end
end

local function ensureAimTraceLine()
    if not AimTraceLine then
        AimTraceLine = Drawing.new("Line")
        AimTraceLine.Color = Color3.fromRGB(0, 255, 0)
        AimTraceLine.Thickness = 2
        AimTraceLine.Transparency = 1
        AimTraceLine.Visible = false
    end
    return AimTraceLine
end

local function showAimTrace(part)
    local line = ensureAimTraceLine()
    if not part then
        line.Visible = false
        return
    end

    local targetPos, vis = Camera:WorldToViewportPoint(part.Position)
    if vis then
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        line.From = screenCenter
        line.To = Vector2.new(targetPos.X, targetPos.Y)
        line.Visible = true
        task.delay(1, function()
            if line then
                line.Visible = false
            end
        end)
    else
        line.Visible = false
    end
end

local function removeBox(player)
    local sq = BoxObjects[player]
    if sq then
        sq:Remove()
        BoxObjects[player] = nil
    end
end

Players.PlayerRemoving:Connect(removeBox)

local function updateBoxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and passesTeamCheck(player) then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")

            if char and hum and hum.Health > 0 and root and head then
                local sq = getBox(player)
                local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))

                if onScreen then
                    local height = math.abs(headPos.Y - rootPos.Y) * 2
                    local width = height / 2

                    sq.Size = Vector2.new(width, height)
                    sq.Position = Vector2.new(rootPos.X - width / 2, rootPos.Y - height / 2)
                    sq.Color = getColor(player)
                    sq.Thickness = getgenv().ESP.BoxThickness or 2
                    sq.Visible = true
                else
                    sq.Visible = false
                end
            else
                removeBox(player)
            end
        else
            removeBox(player)
        end
    end
end

local function setBox(on)
    if on and not BoxConn then
        BoxConn = RunService.RenderStepped:Connect(updateBoxes)
    elseif not on and BoxConn then
        BoxConn:Disconnect()
        BoxConn = nil
        for _, sq in pairs(BoxObjects) do
            sq.Visible = false
        end
    end
end

-- =========================
-- ESP V1 (Highlight)
-- =========================

local function destroyESPv1(plr)
    local char = plr and plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local h = hrp and hrp:FindFirstChild("ESP_V1_Highlight")
    if h then h:Destroy() end
end

local function ensureESPv1(plr)
    if not getgenv().ESPv1.Enabled or plr == lp or not passesTeamCheck(plr) then
        destroyESPv1(plr)
        return
    end

    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local h = hrp:FindFirstChild("ESP_V1_Highlight")
    if not h then
        h = Instance.new("Highlight")
        h.Name = "ESP_V1_Highlight"
        h.Adornee = char
        h.Parent = hrp
    end

    h.FillTransparency = getgenv().ESPv1.FillTransparency or 0
    h.OutlineTransparency = getgenv().ESPv1.OutlineTransparency or 0
    h.OutlineColor = getColor(plr, getgenv().ESPv1.TeamColors)
    h.DepthMode = getgenv().ESPv1.AlwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
end

local function setESPv1(state)
    getgenv().ESPv1.Enabled = state

    if state then
        for _, plr in ipairs(Players:GetPlayers()) do
            ensureESPv1(plr)
        end

        if not ESPV1AddedConn then
            ESPV1AddedConn = Players.PlayerAdded:Connect(function(plr)
                plr.CharacterAdded:Connect(function()
                    ensureESPv1(plr)
                end)
            end)
        end

        if not ESPV1RemovingConn then
            ESPV1RemovingConn = Players.PlayerRemoving:Connect(destroyESPv1)
        end

        if not ESPV1LoopConn then
            ESPV1LoopConn = RunService.Heartbeat:Connect(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    ensureESPv1(plr)
                end
            end)
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            destroyESPv1(plr)
        end

        if ESPV1AddedConn then ESPV1AddedConn:Disconnect() ESPV1AddedConn = nil end
        if ESPV1RemovingConn then ESPV1RemovingConn:Disconnect() ESPV1RemovingConn = nil end
        if ESPV1LoopConn then ESPV1LoopConn:Disconnect() ESPV1LoopConn = nil end
    end
end

MainTab:CreateToggle({
    Name = "Highlight ESP",
    CurrentValue = false,
    Callback = function(state)
        local function ensureHighlight(plr)
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and passesTeamCheck(plr) then
                local hrp = plr.Character.HumanoidRootPart
                local h = hrp:FindFirstChild("Highlight") or Instance.new("Highlight")
                h.Name = "Highlight"
                h.Adornee = plr.Character
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillTransparency = 1
                h.OutlineColor = getColor(plr)
                h.Parent = hrp
            end
        end

        if state then
            for _, plr in ipairs(Players:GetPlayers()) do
                ensureHighlight(plr)
            end

            HighlightAddedConn = Players.PlayerAdded:Connect(function(plr)
                plr.CharacterAdded:Connect(function(char)
                    char:WaitForChild("HumanoidRootPart")
                    ensureHighlight(plr)
                end)
            end)

            HighlightLoopConn = RunService.Heartbeat:Connect(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = plr.Character.HumanoidRootPart
                        local h = hrp:FindFirstChild("Highlight")
                        if passesTeamCheck(plr) then
                            ensureHighlight(plr)
                            if h then h.OutlineColor = getColor(plr) end
                        elseif h then
                            h:Destroy()
                        end
                    end
                end
            end)
        else
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    local h = plr.Character.HumanoidRootPart:FindFirstChild("Highlight")
                    if h then h:Destroy() end
                end
            end

            if HighlightAddedConn then HighlightAddedConn:Disconnect() HighlightAddedConn = nil end
            if HighlightLoopConn then HighlightLoopConn:Disconnect() HighlightLoopConn = nil end
        end

        log("Highlight ESP: " .. (state and "ON" or "OFF"))
    end
})

MainTab:CreateToggle({
    Name = "ESP V1 (Highlight)",
    CurrentValue = false,
    Callback = function(state)
        setESPv1(state)
        log("ESP V1: " .. (state and "ON" or "OFF"))
    end
})

MainTab:CreateToggle({
    Name = "Skeleton ESP",
    CurrentValue = false,
    Callback = function(state)
        setSkeleton(state)
        log("Skeleton ESP: " .. (state and "ON" or "OFF"))
    end
})

MainTab:CreateToggle({
    Name = "Box ESP",
    CurrentValue = false,
    Callback = function(state)
        getgenv().ESP.Box = state
        setBox(state)
        log("Box ESP: " .. (state and "ON" or "OFF"))
    end
})


MainTab:CreateToggle({
    Name = "Tracer ESP",
    CurrentValue = false,
    Callback = function(v)
        getgenv().ESP.Tracers = v
        setTracerLoop(v)
        log("Tracer ESP: " .. (v and "ON" or "OFF"))
    end
})


SettingsTab:CreateToggle({Name="Auto ESP on join",CurrentValue=true,Callback=function(v) getgenv().ESP.AutoJoin=v end})
SettingsTab:CreateToggle({Name="Team colors",CurrentValue=true,Callback=function(v) getgenv().ESP.TeamColors=v end})
SettingsTab:CreateToggle({Name="Team Check",CurrentValue=false,Callback=function(v) getgenv().ESP.TeamCheck=v end})
SettingsTab:CreateSlider({
    Name = "Tracer Thickness",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = getgenv().ESP.TracerThickness or 1,
    Callback = function(v)
        getgenv().ESP.TracerThickness = v
        for _, line in pairs(TracerFolder) do
            line.Thickness = v
        end
    end
})
SettingsTab:CreateSlider({
    Name = "Box Thickness",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = getgenv().ESP.BoxThickness or 2,
    Callback = function(v)
        getgenv().ESP.BoxThickness = v
        for _, sq in pairs(BoxObjects) do
            sq.Thickness = v
        end
    end
})
SettingsTab:CreateToggle({Name="ESP V1 Team Colors",CurrentValue=true,Callback=function(v)
    getgenv().ESPv1.TeamColors = v
    if getgenv().ESPv1.Enabled then
        for _, plr in ipairs(Players:GetPlayers()) do ensureESPv1(plr) end
    end
end})
SettingsTab:CreateToggle({Name="ESP V1 Always On Top",CurrentValue=true,Callback=function(v)
    getgenv().ESPv1.AlwaysOnTop = v
    if getgenv().ESPv1.Enabled then
        for _, plr in ipairs(Players:GetPlayers()) do ensureESPv1(plr) end
    end
end})
SettingsTab:CreateSlider({
    Name = "ESP V1 Fill Transparency",
    Range = {0, 1},
    Increment = 0.05,
    CurrentValue = getgenv().ESPv1.FillTransparency or 0,
    Callback = function(v)
        getgenv().ESPv1.FillTransparency = v
        if getgenv().ESPv1.Enabled then
            for _, plr in ipairs(Players:GetPlayers()) do ensureESPv1(plr) end
        end
    end
})
SettingsTab:CreateSlider({
    Name = "ESP V1 Outline Transparency",
    Range = {0, 1},
    Increment = 0.05,
    CurrentValue = getgenv().ESPv1.OutlineTransparency or 0,
    Callback = function(v)
        getgenv().ESPv1.OutlineTransparency = v
        if getgenv().ESPv1.Enabled then
            for _, plr in ipairs(Players:GetPlayers()) do ensureESPv1(plr) end
        end
    end
})

ConsoleTab:CreateButton({Name="Clear Console",Callback=function() consoleLines={} ConsoleLabel:Set({Title="Output",Content=""}) end})

InfoTab:CreateLabel("Made by Astraea Team")
log("ESP Hub loaded")

-- Aimbot tab controls
AimbotTab:CreateToggle({
    Name = "Aimbot",
    CurrentValue = getgenv().Aimbot.Enabled,
    Callback = function(v)
        setAimbot(v)
        log("Aimbot: " .. (v and "ON" or "OFF"))
    end
})

AimbotTab:CreateDropdown({
    Name = "Aim Part",
    Options = {"Head", "Torso"},
    CurrentOption = {getgenv().Aimbot.AimPart or "Head"},
    Callback = function(option)
        if type(option) == "table" then
            option = option[1]
        end
        getgenv().Aimbot.AimPart = option
    end
})

AimbotTab:CreateSlider({
    Name = "Max Distance (studs)",
    Range = {50, 5000},
    Increment = 10,
    CurrentValue = getgenv().Aimbot.MaxDistance or 400,
    Callback = function(v)
        getgenv().Aimbot.MaxDistance = v
    end
})

AimbotTab:CreateToggle({
    Name = "Aimbot Team Check",
    CurrentValue = getgenv().Aimbot.TeamCheck,
    Callback = function(v)
        getgenv().Aimbot.TeamCheck = v
    end
})

AimbotTab:CreateButton({
    Name = "Test Aim Trace",
    Callback = function()
        if not getgenv().Aimbot.Enabled then
            log("Aimbot must be ON to test trace.")
            return
        end
        local part = getClosestPlayerToCursor(getgenv().Aimbot.AimPart or "Head", getgenv().Aimbot.MaxDistance or 400)
        if part then
            showAimTrace(part)
            log("Aim trace shown.")
        else
            log("No target to trace.")
        end
    end
})

AimbotTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = getgenv().Aimbot.ShowFOV,
    Callback = function(v)
        setFOVCircle(v)
        log("Aimbot FOV: " .. (v and "ON" or "OFF"))
    end
})

AimbotTab:CreateSlider({
    Name = "FOV Radius",
    Range = {25, 500},
    Increment = 5,
    CurrentValue = getgenv().Aimbot.FOV or 100,
    Callback = function(v)
        getgenv().Aimbot.FOV = v
        if FOVCircle then
            FOVCircle.Radius = v
        end
    end
})

-- Initialize FOV circle based on current setting
ensureFOVCircle()
setFOVCircle(getgenv().Aimbot.ShowFOV)
