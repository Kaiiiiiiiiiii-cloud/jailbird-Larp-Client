-- larp_client.lua
-- minecraft-client style gui for roblox
-- toggle: RightShift
-- drag: title bar

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local theme = {
    bg = Color3.fromRGB(18, 18, 22),
    panel = Color3.fromRGB(26, 26, 32),
    panel2 = Color3.fromRGB(32, 32, 40),
    stroke = Color3.fromRGB(58, 58, 70),
    accent = Color3.fromRGB(0, 200, 130),
    accent_dim = Color3.fromRGB(0, 140, 95),
    text = Color3.fromRGB(230, 230, 235),
    text_dim = Color3.fromRGB(140, 140, 150),
    off = Color3.fromRGB(70, 70, 80),
}

local modules = {
    { name = "Speed",     enabled = false, key = "F1", type = "toggle" },
    { name = "Fly",       enabled = false, key = "F2", type = "toggle" },
    { name = "ESP",       enabled = false, key = "F3", type = "toggle" },
    { name = "NoClip",    enabled = false, key = "F4", type = "toggle" },
    { name = "Fullbright",enabled = false, key = "F5", type = "toggle" },
    { name = "Speed Value", value = 34, min = 16, max = 120, key = "F6", type = "slider" },
}

local keymap = {}
for _, m in ipairs(modules) do keymap[m.key] = m end

local gui = Instance.new("ScreenGui")
gui.Name = "LarpClient"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(420, 300)
main.Position = UDim2.new(0.5, -210, 0.5, -150)
main.BackgroundColor3 = theme.bg
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = theme.stroke
stroke.Thickness = 1
stroke.Parent = main

-- title bar
local titlebar = Instance.new("Frame")
titlebar.Size = UDim2.new(1, 0, 0, 30)
titlebar.BackgroundColor3 = theme.panel
titlebar.BorderSizePixel = 0
titlebar.Parent = main

local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 6)
tc.Parent = titlebar

local tmask = Instance.new("Frame")
tmask.Size = UDim2.new(1, 0, 0, 15)
tmask.Position = UDim2.new(0, 0, 1, -15)
tmask.BackgroundColor3 = theme.panel
tmask.BorderSizePixel = 0
tmask.Parent = titlebar

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 0)
title.Size = UDim2.new(1, -60, 1, 0)
title.Font = Enum.Font.Code
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = theme.accent
title.Text = "larp client // v1.0"
title.Parent = titlebar

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(20, 20)
close.Position = UDim2.new(1, -28, 0, 5)
close.BackgroundColor3 = theme.panel2
close.BorderSizePixel = 0
close.Font = Enum.Font.Code
close.TextSize = 14
close.TextColor3 = theme.text_dim
close.Text = "x"
close.AutoButtonColor = false
close.Parent = titlebar

local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 4)
cc.Parent = close

-- sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 110, 1, -30)
sidebar.Position = UDim2.new(0, 0, 0, 30)
sidebar.BackgroundColor3 = theme.panel
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sstroke = Instance.new("UIStroke")
sstroke.Color = theme.stroke
sstroke.Thickness = 1
sstroke.Parent = sidebar

local tabs = { "Combat", "Movement", "Render", "Player" }
local active_tab = "Combat"
local tab_buttons = {}

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, 28)
    btn.Position = UDim2.new(0, 6, 0, 6 + (i - 1) * 32)
    btn.BackgroundColor3 = name == active_tab and theme.panel2 or theme.panel
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Code
    btn.TextSize = 12
    btn.TextColor3 = name == active_tab and theme.accent or theme.text_dim
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = "  " .. name
    btn.AutoButtonColor = false
    btn.Parent = sidebar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn

    local accentbar = Instance.new("Frame")
    accentbar.Size = UDim2.new(0, 2, 1, -10)
    accentbar.Position = UDim2.new(0, 0, 0, 5)
    accentbar.BackgroundColor3 = theme.accent
    accentbar.BorderSizePixel = 0
    accentbar.Visible = name == active_tab
    accentbar.Parent = btn

    tab_buttons[name] = { btn = btn, bar = accentbar }
end

-- content
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -110, 1, -30)
content.Position = UDim2.new(0, 110, 0, 30)
content.BackgroundColor3 = theme.bg
content.BorderSizePixel = 0
content.Parent = main

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -16)
scroll.Position = UDim2.fromOffset(8, 8)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = theme.accent
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = content

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

local row_refs = {}

local function make_row(mod, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 34)
    row.BackgroundColor3 = theme.panel
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = scroll

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 4)
    rc.Parent = row

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Position = UDim2.fromOffset(10, 0)
    name.Size = UDim2.new(1, -100, 1, 0)
    name.Font = Enum.Font.Code
    name.TextSize = 12
    name.TextColor3 = theme.text
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Text = mod.name
    name.Parent = row

    local keylbl = Instance.new("TextLabel")
    keylbl.BackgroundTransparency = 1
    keylbl.Position = UDim2.new(1, -70, 0, 0)
    keylbl.Size = UDim2.fromOffset(30, 34)
    keylbl.Font = Enum.Font.Code
    keylbl.TextSize = 11
    keylbl.TextColor3 = theme.text_dim
    keylbl.TextXAlignment = Enum.TextXAlignment.Center
    keylbl.Text = mod.key
    keylbl.Parent = row

    if mod.type == "toggle" then
        local tog = Instance.new("TextButton")
        tog.Size = UDim2.fromOffset(36, 18)
        tog.Position = UDim2.new(1, -42, 0.5, -9)
        tog.BackgroundColor3 = mod.enabled and theme.accent or theme.off
        tog.BorderSizePixel = 0
        tog.AutoButtonColor = false
        tog.Text = ""
        tog.Parent = row

        local tgc = Instance.new("UICorner")
        tgc.CornerRadius = UDim.new(1, 0)
        tgc.Parent = tog

        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(14, 14)
        knob.Position = mod.enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        knob.BackgroundColor3 = theme.text
        knob.BorderSizePixel = 0
        knob.Parent = tog

        local kc = Instance.new("UICorner")
        kc.CornerRadius = UDim.new(1, 0)
        kc.Parent = knob

        row_refs[mod.name] = { mod = mod, tog = tog, knob = knob, row = row }
    elseif mod.type == "slider" then
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, -100, 0, 4)
        bar.Position = UDim2.new(0, 10, 0, 22)
        bar.BackgroundColor3 = theme.off
        bar.BorderSizePixel = 0
        bar.Parent = row

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(1, 0)
        bc.Parent = bar

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((mod.value - mod.min) / (mod.max - mod.min), 0, 1, 0)
        fill.BackgroundColor3 = theme.accent
        fill.BorderSizePixel = 0
        fill.Parent = bar

        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(1, 0)
        fc.Parent = fill

        local val = Instance.new("TextLabel")
        val.BackgroundTransparency = 1
        val.Position = UDim2.new(1, -70, 0, 0)
        val.Size = UDim2.fromOffset(30, 20)
        val.Font = Enum.Font.Code
        val.TextSize = 11
        val.TextColor3 = theme.accent
        val.Text = tostring(mod.value)
        val.Parent = row

        row_refs[mod.name] = { mod = mod, bar = bar, fill = fill, val = val, row = row }
    end
end

local function refresh_rows()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    row_refs = {}
    local order = 0
    for _, mod in ipairs(modules) do
        order += 1
        make_row(mod, order)
    end
end

refresh_rows()

-- toggle handler
local function set_toggle(mod)
    mod.enabled = not mod.enabled
    local r = row_refs[mod.name]
    if not r then return end
    local goal = mod.enabled and theme.accent or theme.off
    TweenService:Create(r.tog, TweenInfo.new(0.15), { BackgroundColor3 = goal }):Play()
    local knob_goal = mod.enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    TweenService:Create(r.knob, TweenInfo.new(0.15), { Position = knob_goal }):Play()
end

-- slider logic
for name, r in pairs(row_refs) do
    if r.bar then
        r.bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local dragging = true
                local function update()
                    local mx = UserInputService:GetMouseLocation().X
                    local pos = r.bar.AbsolutePosition.X
                    local width = r.bar.AbsoluteSize.X
                    local alpha = math.clamp((mx - pos) / width, 0, 1)
                    r.mod.value = math.floor(r.mod.min + alpha * (r.mod.max - r.mod.min))
                    r.val.Text = tostring(r.mod.value)
                    r.fill.Size = UDim2.new(alpha, 0, 1, 0)
                end
                local conn
                conn = UserInputService.InputChanged:Connect(function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        update()
                    end
                end)
                local endconn
                endconn = UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                        conn:Disconnect()
                        endconn:Disconnect()
                    end
                end)
            end
        end)
    end
end

-- tab switching
for name, ref in pairs(tab_buttons) do
    ref.btn.MouseButton1Click:Connect(function()
        active_tab = name
        for n, r in pairs(tab_buttons) do
            local on = n == name
            r.btn.TextColor3 = on and theme.accent or theme.text_dim
            r.bar.Visible = on
        end
    end)
end

-- drag
local dragging, drag_start, start_pos
titlebar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        drag_start = input.Position
        start_pos = main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - drag_start
        main.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- close
close.MouseButton1Click:Connect(function()
    gui.Enabled = false
end)

-- keybind toggle gui
local open = true
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        open = not open
        gui.Enabled = open
        return
    end
    local mod = keymap[input.KeyCode.Name]
    if mod and mod.type == "toggle" and gui.Enabled then
        set_toggle(mod)
    end
end)

-- hooks (basic, wire to your own logic)
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if modules[1].enabled then
        local s = 34
        for _, m in ipairs(modules) do if m.name == "Speed Value" then s = m.value end end
        hum.WalkSpeed = s
    else
        hum.WalkSpeed = 16
    end

    if modules[3].enabled and not char:FindFirstChild("larp_light") then
        local l = Instance.new("PointLight")
        l.Name = "larp_light"
        l.Brightness = 3
        l.Range = 60
        l.Parent = hrp
    elseif not modules[3].enabled and char:FindFirstChild("larp_light") then
        char.larp_light:Destroy()
    end

    if modules[4].enabled then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)
