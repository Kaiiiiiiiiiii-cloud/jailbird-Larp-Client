-- larp_client.lua · v1.1
-- minecraft-client style gui · per-user config · rebindable keys · adjustable features
-- menu: RightShift (rebindable in Settings) · drag: title bar

local Players        = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local RunService     = game:GetService("RunService")
local HttpService    = game:GetService("HttpService")
local Lighting       = game:GetService("Lighting")
local LocalPlayer    = Players.LocalPlayer

local CONFIG_FILE = "larp_client_config.json"

-- ============================================================
-- helpers
-- ============================================================
local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local o = {}
    for k, vv in pairs(v) do o[k] = deepcopy(vv) end
    return o
end
local function arrToColor(a) return Color3.fromRGB(a[1] or 0, a[2] or 0, a[3] or 0) end
local function scaleColor(a, s)
    return Color3.fromRGB(
        math.clamp(math.floor((a[1] or 0) * s), 0, 255),
        math.clamp(math.floor((a[2] or 0) * s), 0, 255),
        math.clamp(math.floor((a[3] or 0) * s), 0, 255)
    )
end

-- ============================================================
-- module definitions (tab, name, description, settings)
-- ============================================================
local defs = {
    {id="autoarrest", tab="Combat",   name="Auto Arrest",   desc="Cuffs the nearest player in range.",
        settings={{type="slider", id="range", label="Range (studs)", min=5, max=60, default=12}}},
    {id="autopocket", tab="Combat",   name="Auto Pickpocket", desc="Steals from nearest player in range.",
        settings={{type="slider", id="range", label="Range (studs)", min=5, max=60, default=10}}},

    {id="speed",         tab="Movement", name="Speed",         desc="Overrides walk speed.",
        settings={{type="slider", id="value", label="Walk Speed", min=16, max=250, default=34}}},
    {id="fly",           tab="Movement", name="Fly",           desc="WASD to fly · Space / LCtrl up·down.",
        settings={{type="slider", id="value", label="Fly Speed", min=10, max=250, default=50}}},
    {id="noclip",        tab="Movement", name="NoClip",        desc="Walk through walls."},
    {id="jumppower",     tab="Movement", name="Jump Power",    desc="Sets humanoid jump power.",
        settings={{type="slider", id="value", label="Power", min=50, max=500, default=50}}},
    {id="infinitejump",  tab="Movement", name="Infinite Jump", desc="Jump again while airborne."},

    {id="esp",           tab="Render",   name="ESP",           desc="Highlights other players.",
        settings={
            {type="color",  id="color",   label="Color",         default={255,40,40}},
            {type="slider", id="maxdist", label="Max Distance",  min=50, max=3000, default=1500},
        }},
    {id="fullbright",    tab="Render",   name="Fullbright",    desc="Brightens the map.",
        settings={{type="slider", id="value", label="Brightness", min=1, max=10, default=3}}},
    {id="fov",           tab="Render",   name="FOV",           desc="Changes camera field of view.",
        settings={{type="slider", id="value", label="FOV", min=40, max=120, default=70}}},

    {id="antiafk",       tab="Player",   name="Anti AFK",      desc="Prevents idle kick."},
    {id="healthhud",     tab="Player",   name="Health Overlay",desc="Shows your HP on screen."},
    {id="fpshud",        tab="Player",   name="FPS Counter",   desc="Shows frames per second."},
}

local function module_default(id)
    local d = {enabled=false, key=""}
    for _, def in ipairs(defs) do
        if def.id == id then
            for _, s in ipairs(def.settings or {}) do
                d[s.id] = deepcopy(s.default)
            end
            break
        end
    end
    return d
end

local config = {
    menu_key = "RightShift",
    accent = {0, 200, 130},
    ui_scale = 1,
    notifications = true,
    modules = {},
}

local function get_state(id)
    if not config.modules[id] then
        config.modules[id] = module_default(id)
    end
    return config.modules[id]
end

-- default key assignment
do
    local i = 0
    for _, def in ipairs(defs) do
        i += 1
        local st = get_state(def.id)
        if st.key == "" then st.key = "F" .. i end
    end
end

-- ============================================================
-- load / save
-- ============================================================
local function load_config()
    if not (isfile and readfile) then return end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw or raw == "" then return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or type(data) ~= "table" then return end
    config.menu_key      = data.menu_key or config.menu_key
    config.accent        = data.accent or config.accent
    config.ui_scale      = data.ui_scale or config.ui_scale
    config.notifications = data.notifications
    if config.notifications == nil then config.notifications = true end
    if type(data.modules) == "table" then
        for _, def in ipairs(defs) do
            local saved = data.modules[def.id]
            if type(saved) == "table" then
                local st = get_state(def.id)
                for k, v in pairs(saved) do st[k] = v end
            end
        end
    end
end

local function save_config()
    if not writefile then return end
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(config))
    end)
end

local save_pending = false
local function schedule_save()
    if save_pending then return end
    save_pending = true
    task.delay(1, function()
        save_pending = false
        save_config()
    end)
end

load_config()

-- ============================================================
-- colors
-- ============================================================
local C = {
    bg      = Color3.fromRGB(16, 16, 20),
    panel   = Color3.fromRGB(24, 24, 30),
    panel2  = Color3.fromRGB(32, 32, 40),
    panel3  = Color3.fromRGB(40, 40, 50),
    stroke  = Color3.fromRGB(58, 58, 70),
    text    = Color3.fromRGB(228, 228, 234),
    text_dim= Color3.fromRGB(140, 140, 152),
    off     = Color3.fromRGB(70, 70, 82),
    danger  = Color3.fromRGB(220, 70, 70),
    ok      = Color3.fromRGB(90, 210, 120),
}
local function accent() return arrToColor(config.accent) end
local function accent_dim() return scaleColor(config.accent, 0.55) end

-- ============================================================
-- GUI shell
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "LarpClient"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(560, 400)
main.Position = UDim2.new(0.5, -280, 0.5, -200)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Parent = gui

local uiScale = Instance.new("UIScale")
uiScale.Scale = config.ui_scale
uiScale.Parent = main

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 6)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = C.stroke
mainStroke.Thickness = 1
mainStroke.Parent = main

-- title bar
local titlebar = Instance.new("Frame")
titlebar.Name = "Title"
titlebar.Size = UDim2.new(1, 0, 0, 34)
titlebar.BackgroundColor3 = C.panel
titlebar.BorderSizePixel = 0
titlebar.Parent = main

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 6)
tbCorner.Parent = titlebar

local tbMask = Instance.new("Frame")
tbMask.Size = UDim2.new(1, 0, 0, 17)
tbMask.Position = UDim2.new(0, 0, 1, -17)
tbMask.BackgroundColor3 = C.panel
tbMask.BorderSizePixel = 0
tbMask.Parent = titlebar

local logoDot = Instance.new("Frame")
logoDot.Size = UDim2.fromOffset(8, 8)
logoDot.Position = UDim2.fromOffset(12, 13)
logoDot.BackgroundColor3 = accent()
logoDot.BorderSizePixel = 0
logoDot.Parent = titlebar

local ldCorner = Instance.new("UICorner")
ldCorner.CornerRadius = UDim.new(1, 0)
ldCorner.Parent = logoDot

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(28, 0)
title.Size = UDim2.new(1, -180, 1, 0)
title.Font = Enum.Font.Code
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = C.text
title.Text = "larp client"
title.Parent = titlebar

local versionLbl = Instance.new("TextLabel")
versionLbl.BackgroundTransparency = 1
versionLbl.Position = UDim2.new(1, -160, 0, 0)
versionLbl.Size = UDim2.fromOffset(80, 34)
versionLbl.Font = Enum.Font.Code
versionLbl.TextSize = 11
versionLbl.TextColor3 = C.text_dim
versionLbl.TextXAlignment = Enum.TextXAlignment.Right
versionLbl.Text = "v1.1"
versionLbl.Parent = titlebar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(22, 22)
closeBtn.Position = UDim2.new(1, -32, 0, 6)
closeBtn.BackgroundColor3 = C.panel2
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.Code
closeBtn.TextSize = 14
closeBtn.TextColor3 = C.text_dim
closeBtn.Text = "x"
closeBtn.AutoButtonColor = false
closeBtn.Parent = titlebar
local cbC = Instance.new("UICorner") cbC.CornerRadius = UDim.new(0, 4) cbC.Parent = closeBtn
closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.12), {BackgroundColor3=C.danger, TextColor3=Color3.new(1,1,1)}):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.12), {BackgroundColor3=C.panel2, TextColor3=C.text_dim}):Play() end)

-- sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, -60)
sidebar.Position = UDim2.new(0, 0, 0, 34)
sidebar.BackgroundColor3 = C.panel
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sbStroke = Instance.new("UIStroke")
sbStroke.Color = C.stroke
sbStroke.Thickness = 1
sbStroke.Parent = sidebar

local tabs = {"Combat", "Movement", "Render", "Player", "Settings"}
local active_tab = "Combat"
local tab_refs = {}

local tabList = Instance.new("UIListLayout")
tabList.SortOrder = Enum.SortOrder.LayoutOrder
tabList.Padding = UDim.new(0, 2)
tabList.Parent = sidebar

local tabPad = Instance.new("UIPadding")
tabPad.PaddingTop = UDim.new(0, 8)
tabPad.PaddingLeft = UDim.new(0, 8)
tabPad.PaddingRight = UDim.new(0, 8)
tabPad.Parent = sidebar

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = C.panel
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Code
    btn.TextSize = 12
    btn.TextColor3 = C.text_dim
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = "  " .. name
    btn.AutoButtonColor = false
    btn.LayoutOrder = i
    btn.Parent = sidebar

    local btnC = Instance.new("UICorner") btnC.CornerRadius = UDim.new(0, 4) btnC.Parent = btn

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 2, 1, -10)
    bar.Position = UDim2.new(0, 0, 0, 5)
    bar.BackgroundColor3 = accent()
    bar.BorderSizePixel = 0
    bar.Visible = (name == active_tab)
    bar.Parent = btn

    tab_refs[name] = {btn=btn, bar=bar}

    btn.MouseEnter:Connect(function()
        if name ~= active_tab then
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3=C.panel2, TextColor3=C.text}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if name ~= active_tab then
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3=C.panel, TextColor3=C.text_dim}):Play()
        end
    end)
end

-- content area
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -130, 1, -60)
content.Position = UDim2.new(0, 130, 0, 34)
content.BackgroundColor3 = C.bg
content.BorderSizePixel = 0
content.Parent = main

-- search bar (only for module tabs)
local search_wrap = Instance.new("Frame")
search_wrap.Size = UDim2.new(1, -16, 0, 30)
search_wrap.Position = UDim2.fromOffset(8, 8)
search_wrap.BackgroundColor3 = C.panel
search_wrap.BorderSizePixel = 0
search_wrap.Parent = content
local swC = Instance.new("UICorner") swC.CornerRadius = UDim.new(0, 4) swC.Parent = search_wrap
local swS = Instance.new("UIStroke") swS.Color = C.stroke swS.Thickness = 1 swS.Parent = search_wrap

local search_icon = Instance.new("TextLabel")
search_icon.BackgroundTransparency = 1
search_icon.Position = UDim2.fromOffset(8, 0)
search_icon.Size = UDim2.fromOffset(20, 30)
search_icon.Font = Enum.Font.Code
search_icon.TextSize = 13
search_icon.TextColor3 = C.text_dim
search_icon.Text = "/"
search_icon.Parent = search_wrap

local search_box = Instance.new("TextBox")
search_box.BackgroundTransparency = 1
search_box.Position = UDim2.fromOffset(28, 0)
search_box.Size = UDim2.new(1, -36, 1, 0)
search_box.Font = Enum.Font.Code
search_box.TextSize = 12
search_box.TextColor3 = C.text
search_box.TextXAlignment = Enum.TextXAlignment.Left
search_box.PlaceholderText = "search modules..."
search_box.PlaceholderColor3 = C.text_dim
search_box.Text = ""
search_box.ClearTextOnFocus = false
search_box.Parent = search_wrap

-- scrolling content
local content_scroll = Instance.new("ScrollingFrame")
content_scroll.Size = UDim2.new(1, -16, 1, -46)
content_scroll.Position = UDim2.fromOffset(8, 44)
content_scroll.BackgroundTransparency = 1
content_scroll.BorderSizePixel = 0
content_scroll.ScrollBarThickness = 3
content_scroll.ScrollBarImageColor3 = accent()
content_scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
content_scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
content_scroll.Parent = content

local contentList = Instance.new("UIListLayout")
contentList.Padding = UDim.new(0, 6)
contentList.SortOrder = Enum.SortOrder.LayoutOrder
contentList.Parent = content_scroll

-- status bar
local statusbar = Instance.new("Frame")
statusbar.Size = UDim2.new(1, 0, 0, 26)
statusbar.Position = UDim2.new(0, 0, 1, -26)
statusbar.BackgroundColor3 = C.panel
statusbar.BorderSizePixel = 0
statusbar.Parent = main

local sbStroke2 = Instance.new("UIStroke")
sbStroke2.Color = C.stroke
sbStroke2.Thickness = 1
sbStroke2.Parent = statusbar

local status_left = Instance.new("TextLabel")
status_left.BackgroundTransparency = 1
status_left.Position = UDim2.fromOffset(10, 0)
status_left.Size = UDim2.new(1, -100, 1, 0)
status_left.Font = Enum.Font.Code
status_left.TextSize = 11
status_left.TextXAlignment = Enum.TextXAlignment.Left
status_left.TextColor3 = C.text_dim
status_left.Text = "connected: " .. LocalPlayer.Name
status_left.Parent = statusbar

local status_right = Instance.new("TextLabel")
status_right.BackgroundTransparency = 1
status_right.Position = UDim2.new(1, -80, 0, 0)
status_right.Size = UDim2.fromOffset(70, 26)
status_right.Font = Enum.Font.Code
status_right.TextSize = 11
status_right.TextXAlignment = Enum.TextXAlignment.Right
status_right.TextColor3 = accent()
status_right.Text = "ready"
status_right.Parent = statusbar

-- ============================================================
-- toast / notification
-- ============================================================
local toast_holder = Instance.new("Frame")
toast_holder.Name = "Toasts"
toast_holder.Size = UDim2.fromOffset(260, 200)
toast_holder.Position = UDim2.new(1, -276, 0, 20)
toast_holder.BackgroundTransparency = 1
toast_holder.Parent = gui

local toast_list = Instance.new("UIListLayout")
toast_list.Padding = UDim.new(0, 6)
toast_list.SortOrder = Enum.SortOrder.LayoutOrder
toast_list.VerticalAlignment = Enum.VerticalAlignment.Top
toast_list.Parent = toast_holder

local toast_order = 0
local function notify(text, col)
    if config.notifications == false then return end
    toast_order += 1
    local t = Instance.new("Frame")
    t.Size = UDim2.new(1, 0, 0, 30)
    t.BackgroundColor3 = C.panel2
    t.BorderSizePixel = 0
    t.LayoutOrder = toast_order
    t.Parent = toast_holder
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = t
    local s = Instance.new("UIStroke") s.Color = col or accent() s.Thickness = 1 s.Parent = t

    local lab = Instance.new("TextLabel")
    lab.BackgroundTransparency = 1
    lab.Position = UDim2.fromOffset(10, 0)
    lab.Size = UDim2.new(1, -16, 1, 0)
    lab.Font = Enum.Font.Code
    lab.TextSize = 11
    lab.TextColor3 = C.text
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.Text = text
    lab.Parent = t

    task.delay(2.5, function()
        TweenService:Create(t, TweenInfo.new(0.25), {BackgroundTransparency=1}):Play()
        TweenService:Create(s, TweenInfo.new(0.25), {Transparency=1}):Play()
        TweenService:Create(lab, TweenInfo.new(0.25), {TextTransparency=1}):Play()
        task.wait(0.3)
        t:Destroy()
    end)
end

-- ============================================================
-- rebind state
-- ============================================================
local rebind_mode = nil  -- {type="module", id=..., label=...} or {type="menu", label=...}

-- ============================================================
-- row builders
-- ============================================================
local expanded = {}       -- [module_id] = bool
local row_refs = {}       -- [module_id] = {row, head, tog, knob, key_lbl, gear, arrow}
local slider_refs = {}    -- [{fill, val, label_ref, mod_id, setting_id}] for live update

local function set_toggle_visual(ref, on)
    TweenService:Create(ref.tog, TweenInfo.new(0.14), {BackgroundColor3 = on and accent() or C.off}):Play()
    local goal = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    TweenService:Create(ref.knob, TweenInfo.new(0.14), {Position = goal}):Play()
end

local function update_key_label(ref, key)
    if rebind_mode and rebind_mode.ref == ref.key_lbl then return end
    ref.key_lbl.Text = "[" .. (key or "?") .. "]"
end

local function refresh_all_key_labels()
    for id, ref in pairs(row_refs) do
        local st = get_state(id)
        ref.key_lbl.Text = "[" .. (st.key ~= "" and st.key or "?") .. "]"
    end
end

-- color swatches for picker
local SWATCHES = {
    {255, 40, 40}, {255, 150, 30}, {255, 220, 40}, {90, 210, 120},
    {0, 200, 130}, {60, 180, 255}, {140, 100, 255}, {255, 100, 200},
    {230, 230, 235}, {120, 120, 130},
}

local function build_setting_row(parent, def, setting, order)
    local st = get_state(def.id)

    if setting.type == "slider" then
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -16, 0, 34)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.fromOffset(0, 0)
        lbl.Size = UDim2.new(1, -50, 0, 18)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 11
        lbl.TextColor3 = C.text_dim
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = setting.label
        lbl.Parent = row

        local val = Instance.new("TextLabel")
        val.BackgroundTransparency = 1
        val.Position = UDim2.new(1, -50, 0, 0)
        val.Size = UDim2.fromOffset(50, 18)
        val.Font = Enum.Font.Code
        val.TextSize = 11
        val.TextColor3 = accent()
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Text = tostring(st[setting.id])
        val.Parent = row

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 0, 5)
        bar.Position = UDim2.new(0, 0, 0, 24)
        bar.BackgroundColor3 = C.off
        bar.BorderSizePixel = 0
        bar.Parent = row
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1,0) bc.Parent = bar

        local fill = Instance.new("Frame")
        local alpha0 = (st[setting.id] - setting.min) / (setting.max - setting.min)
        fill.Size = UDim2.new(alpha0, 0, 1, 0)
        fill.BackgroundColor3 = accent()
        fill.BorderSizePixel = 0
        fill.Parent = bar
        local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1,0) fc.Parent = fill

        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(10, 10)
        knob.Position = UDim2.new(alpha0, -5, 0.5, -5)
        knob.BackgroundColor3 = Color3.new(1,1,1)
        knob.BorderSizePixel = 0
        knob.Parent = bar
        local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1,0) kc.Parent = knob

        local ref = {fill=fill, val=val, label_ref=lbl, mod_id=def.id, setting_id=setting.id, def=setting, knob=knob}
        table.insert(slider_refs, ref)

        local function apply(alpha)
            alpha = math.clamp(alpha, 0, 1)
            local v = math.floor(setting.min + alpha * (setting.max - setting.min))
            st[setting.id] = v
            val.Text = tostring(v)
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.new(alpha, -5, 0.5, -5)
            schedule_save()
        end

        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local function upd()
                    local mx = UserInputService:GetMouseLocation().X
                    local ap = bar.AbsolutePosition.X
                    local aw = bar.AbsoluteSize.X
                    if aw > 0 then apply((mx - ap) / aw) end
                end
                upd()
                local c1 = UserInputService.InputChanged:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                        upd()
                    end
                end)
                local c2
                c2 = UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        c1:Disconnect() c2:Disconnect()
                    end
                end)
            end
        end)

    elseif setting.type == "color" then
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -16, 0, 34)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.fromOffset(0, 0)
        lbl.Size = UDim2.new(1, -50, 1, 0)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 11
        lbl.TextColor3 = C.text_dim
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = setting.label
        lbl.Parent = row

        local preview = Instance.new("Frame")
        preview.Size = UDim2.fromOffset(22, 22)
        preview.Position = UDim2.new(1, -22, 0.5, -11)
        preview.BackgroundColor3 = arrToColor(st[setting.id])
        preview.BorderSizePixel = 0
        preview.Parent = row
        local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 4) pc.Parent = preview
        local ps = Instance.new("UIStroke") ps.Color = C.stroke ps.Thickness = 1 ps.Parent = preview

        preview.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            -- spawn a swatch popup
            local popup = Instance.new("Frame")
            popup.Size = UDim2.fromOffset(200, 60)
            popup.Position = UDim2.new(0, preview.AbsolutePosition.X - main.AbsolutePosition.X - 90, 0, preview.AbsolutePosition.Y - main.AbsolutePosition.Y + 30)
            popup.BackgroundColor3 = C.panel2
            popup.BorderSizePixel = 0
            popup.ZIndex = 20
            popup.Parent = main
            local ppc = Instance.new("UICorner") ppc.CornerRadius = UDim.new(0, 4) ppc.Parent = popup
            local pps = Instance.new("UIStroke") pps.Color = C.stroke pps.Thickness = 1 pps.Parent = popup
            local grid = Instance.new("UIGridLayout")
            grid.CellSize = UDim2.fromOffset(16, 16)
            grid.CellPadding = UDim2.fromOffset(4, 4)
            grid.Padding = UDim.new(0, 6)
            grid.Parent = popup
            for _, sw in ipairs(SWATCHES) do
                local s = Instance.new("TextButton")
                s.BackgroundColor3 = arrToColor(sw)
                s.BorderSizePixel = 0
                s.Text = ""
                s.AutoButtonColor = false
                s.ZIndex = 21
                s.Parent = popup
                local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, 3) sc.Parent = s
                s.MouseButton1Click:Connect(function()
                    st[setting.id] = {sw[1], sw[2], sw[3]}
                    preview.BackgroundColor3 = arrToColor(sw)
                    popup:Destroy()
                    schedule_save()
                    notify("color updated", accent())
                end)
            end
            task.delay(3, function()
                if popup and popup.Parent then
                    if popup:GetAttribute("keep") ~= true then popup:Destroy() end
                end
            end)
        end)
    end
end

local function row_height(def)
    local h = 44
    if expanded[def.id] and def.settings and #def.settings > 0 then
        h = h + 12 + #def.settings * 34
    end
    return h
end

local function build_row(def, order)
    local st = get_state(def.id)
    local ref = {}

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, row_height(def))
    row.BackgroundColor3 = C.panel
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.ClipsDescendants = true
    row.Parent = content_scroll
    local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 4) rc.Parent = row
    local rs = Instance.new("UIStroke") rs.Color = C.stroke rs.Thickness = 1 rs.Parent = row

    local head = Instance.new("TextButton")
    head.Size = UDim2.new(1, 0, 0, 44)
    head.BackgroundTransparency = 1
    head.Text = ""
    head.AutoButtonColor = false
    head.Parent = row

    -- toggle switch
    local tog = Instance.new("TextButton")
    tog.Size = UDim2.fromOffset(36, 18)
    tog.Position = UDim2.new(1, -46, 0, 13)
    tog.BackgroundColor3 = st.enabled and accent() or C.off
    tog.BorderSizePixel = 0
    tog.Text = ""
    tog.AutoButtonColor = false
    tog.ZIndex = 3
    tog.Parent = head
    local tgc = Instance.new("UICorner") tgc.CornerRadius = UDim.new(1,0) tgc.Parent = tog

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = st.enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 4
    knob.Parent = tog
    local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1,0) kc.Parent = knob

    -- gear (expand)
    local has_settings = def.settings and #def.settings > 0
    local gear
    if has_settings then
        gear = Instance.new("TextButton")
        gear.Size = UDim2.fromOffset(20, 20)
        gear.Position = UDim2.new(1, -76, 0, 12)
        gear.BackgroundTransparency = 1
        gear.Font = Enum.Font.Code
        gear.TextSize = 12
        gear.TextColor3 = C.text_dim
        gear.Text = expanded[def.id] and "v" or ">"
        gear.AutoButtonColor = false
        gear.ZIndex = 3
        gear.Parent = head
    end

    -- keybind label
    local key_lbl = Instance.new("TextButton")
    key_lbl.Size = UDim2.fromOffset(42, 18)
    key_lbl.Position = UDim2.new(1, -126, 0, 13)
    key_lbl.BackgroundColor3 = C.panel2
    key_lbl.BorderSizePixel = 0
    key_lbl.Font = Enum.Font.Code
    key_lbl.TextSize = 10
    key_lbl.TextColor3 = C.text_dim
    key_lbl.Text = "[" .. (st.key ~= "" and st.key or "?") .. "]"
    key_lbl.AutoButtonColor = false
    key_lbl.ZIndex = 3
    key_lbl.Parent = head
    local klc = Instance.new("UICorner") klc.CornerRadius = UDim.new(0, 3) klc.Parent = key_lbl
    key_lbl.MouseEnter:Connect(function() TweenService:Create(key_lbl, TweenInfo.new(0.1), {TextColor3=accent()}):Play() end)
    key_lbl.MouseLeave:Connect(function() TweenService:Create(key_lbl, TweenInfo.new(0.1), {TextColor3=C.text_dim}):Play() end)

    -- name + desc
    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Position = UDim2.fromOffset(12, 6)
    name.Size = UDim2.new(1, -150, 0, 16)
    name.Font = Enum.Font.Code
    name.TextSize = 12
    name.TextColor3 = C.text
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Text = def.name
    name.ZIndex = 3
    name.Parent = head

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.fromOffset(12, 24)
    desc.Size = UDim2.new(1, -150, 0, 14)
    desc.Font = Enum.Font.Code
    desc.TextSize = 10
    desc.TextColor3 = C.text_dim
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Text = def.desc or ""
    desc.ZIndex = 3
    desc.Parent = head

    -- hover
    head.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = C.panel2}):Play()
    end)
    head.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = C.panel}):Play()
    end)

    ref = {row=row, head=head, tog=tog, knob=knob, key_lbl=key_lbl, gear=gear, def=def, order=order}
    row_refs[def.id] = ref

    -- toggle handler
    local function do_toggle()
        st.enabled = not st.enabled
        set_toggle_visual(ref, st.enabled)
        notify(def.name .. (st.enabled and " on" or " off"), st.enabled and accent() or C.text_dim)
        schedule_save()
    end
    tog.MouseButton1Click:Connect(do_toggle)
    head.MouseButton1Click:Connect(do_toggle)

    -- keybind handler
    key_lbl.MouseButton1Click:Connect(function()
        -- cancel current rebind
        if rebind_mode and rebind_mode.ref then
            rebind_mode.ref.Text = rebind_mode.ref.__prev or rebind_mode.ref.Text
        end
        rebind_mode = {type="module", id=def.id, ref=key_lbl, __prev=key_lbl.Text}
        key_lbl.Text = "[...]"
    end)

    -- gear handler
    if gear then
        gear.MouseButton1Click:Connect(function()
            expanded[def.id] = not expanded[def.id]
            gear.Text = expanded[def.id] and "v" or ">"
            local target_h = row_height(def)
            local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(row, info, {Size = UDim2.new(1, -6, 0, target_h)}):Play()
            if expanded[def.id] then
                task.wait(0.15)
                if not settings_frame then return end
                -- settings were built already, just toggle visibility
            end
        end)
    end

    -- settings container
    local settings_frame
    if def.settings and #def.settings > 0 then
        settings_frame = Instance.new("Frame")
        settings_frame.Position = UDim2.fromOffset(8, 44)
        settings_frame.Size = UDim2.new(1, -16, 0, #def.settings * 34 + 4)
        settings_frame.BackgroundTransparency = 1
        settings_frame.Visible = expanded[def.id] and true or false
        settings_frame.Parent = row

        local sl = Instance.new("UIListLayout")
        sl.Padding = UDim.new(0, 0)
        sl.SortOrder = Enum.SortOrder.LayoutOrder
        sl.Parent = settings_frame

        local si = 0
        for _, setting in ipairs(def.settings) do
            si += 1
            build_setting_row(settings_frame, def, setting, si)
        end

        -- hook visibility to expansion (attach to gear / head)
        if gear then
            local orig = gear.MouseButton1Click
            gear.MouseButton1Click:Connect(function()
                settings_frame.Visible = expanded[def.id]
            end)
        end
    end

    return ref
end

-- ============================================================
-- settings tab
-- ============================================================
local settings_refs = {}

local function build_settings_tab()
    settings_refs = {}
    local order = 0

    local function section(title)
        order += 1
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 10
        lbl.TextColor3 = accent()
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.upper(title)
        lbl.LayoutOrder = order
        lbl.Parent = content_scroll
    end

    local function simple_row(label, right_builder)
        order += 1
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 34)
        row.BackgroundColor3 = C.panel
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.Parent = content_scroll
        local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 4) rc.Parent = row
        local rs = Instance.new("UIStroke") rs.Color = C.stroke rs.Thickness = 1 rs.Parent = row

        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Position = UDim2.fromOffset(12, 0)
        l.Size = UDim2.new(1, -120, 1, 0)
        l.Font = Enum.Font.Code
        l.TextSize = 12
        l.TextColor3 = C.text
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = label
        l.Parent = row

        right_builder(row)
        return row
    end

    -- menu key
    section("Interface")
    simple_row("Menu Key", function(row)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(70, 22)
        btn.Position = UDim2.new(1, -82, 0.5, -11)
        btn.BackgroundColor3 = C.panel2
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Code
        btn.TextSize = 11
        btn.TextColor3 = C.text
        btn.Text = "[" .. config.menu_key .. "]"
        btn.AutoButtonColor = false
        btn.Parent = row
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 3) c.Parent = btn
        local s = Instance.new("UIStroke") s.Color = C.stroke s.Thickness = 1 s.Parent = btn
        settings_refs.menu_key_btn = btn
        btn.MouseButton1Click:Connect(function()
            rebind_mode = {type="menu", ref=btn, __prev=btn.Text}
            btn.Text = "[...]"
        end)
    end)

    -- ui scale slider (reuse slider builder pattern manually)
    simple_row("UI Scale", function(row)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.fromOffset(120, 5)
        bar.Position = UDim2.new(1, -140, 0.5, -2)
        bar.BackgroundColor3 = C.off
        bar.BorderSizePixel = 0
        bar.Parent = row
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1,0) bc.Parent = bar

        local min, max = 0.8, 1.4
        local alpha0 = (config.ui_scale - min) / (max - min)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(alpha0, 0, 1, 0)
        fill.BackgroundColor3 = accent()
        fill.BorderSizePixel = 0
        fill.Parent = bar
        local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1,0) fc.Parent = fill

        local val = Instance.new("TextLabel")
        val.BackgroundTransparency = 1
        val.Position = UDim2.new(1, -60, 0, 0)
        val.Size = UDim2.fromOffset(50, 34)
        val.Font = Enum.Font.Code
        val.TextSize = 11
        val.TextColor3 = accent()
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Text = string.format("%.2f", config.ui_scale)
        val.Parent = row

        bar.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local function upd()
                local mx = UserInputService:GetMouseLocation().X
                local ap = bar.AbsolutePosition.X
                local aw = bar.AbsoluteSize.X
                if aw <= 0 then return end
                local a = math.clamp((mx - ap) / aw, 0, 1)
                config.ui_scale = math.floor((min + a * (max - min)) * 100 + 0.5) / 100
                val.Text = string.format("%.2f", config.ui_scale)
                fill.Size = UDim2.new(a, 0, 1, 0)
                uiScale.Scale = config.ui_scale
                schedule_save()
            end
            upd()
            local c1 = UserInputService.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement then upd() end
            end)
            local c2
            c2 = UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    c1:Disconnect() c2:Disconnect()
                end
            end)
        end)
    end)

    simple_row("Notifications", function(row)
        local tog = Instance.new("TextButton")
        tog.Size = UDim2.fromOffset(36, 18)
        tog.Position = UDim2.new(1, -46, 0.5, -9)
        tog.BackgroundColor3 = config.notifications and accent() or C.off
        tog.BorderSizePixel = 0
        tog.Text = ""
        tog.AutoButtonColor = false
        tog.Parent = row
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1,0) c.Parent = tog
        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(14, 14)
        knob.Position = config.notifications and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        knob.BackgroundColor3 = Color3.new(1,1,1)
        knob.BorderSizePixel = 0
        knob.Parent = tog
        local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1,0) kc.Parent = knob
        tog.MouseButton1Click:Connect(function()
            config.notifications = not config.notifications
            TweenService:Create(tog, TweenInfo.new(0.14), {BackgroundColor3 = config.notifications and accent() or C.off}):Play()
            local g = config.notifications and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
            TweenService:Create(knob, TweenInfo.new(0.14), {Position = g}):Play()
            schedule_save()
        end)
    end)

    -- accent color
    section("Theme Accent")
    order += 1
    local accent_row = Instance.new("Frame")
    accent_row.Size = UDim2.new(1, -6, 0, 40)
    accent_row.BackgroundColor3 = C.panel
    accent_row.BorderSizePixel = 0
    accent_row.LayoutOrder = order
    accent_row.Parent = content_scroll
    local arc = Instance.new("UICorner") arc.CornerRadius = UDim.new(0, 4) arc.Parent = accent_row
    local ars = Instance.new("UIStroke") ars.Color = C.stroke ars.Thickness = 1 ars.Parent = accent_row

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(24, 24)
    grid.CellPadding = UDim2.fromOffset(6, 6)
    grid.Padding = UDim.new(0, 8)
    grid.Parent = accent_row

    for _, sw in ipairs(SWATCHES) do
        local s = Instance.new("TextButton")
        s.BackgroundColor3 = arrToColor(sw)
        s.BorderSizePixel = 0
        s.Text = ""
        s.AutoButtonColor = false
        s.Parent = accent_row
        local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, 4) sc.Parent = s
        if sw[1] == config.accent[1] and sw[2] == config.accent[2] and sw[3] == config.accent[3] then
            local ss = Instance.new("UIStroke") ss.Color = Color3.new(1,1,1) ss.Thickness = 2 ss.Parent = s
        end
        s.MouseButton1Click:Connect(function()
            config.accent = {sw[1], sw[2], sw[3]}
            apply_accent_everywhere()
            schedule_save()
            rebuild_content()
            notify("accent updated", accent())
        end)
    end

    -- actions
    section("Actions")

    order += 1
    local btnrow = Instance.new("Frame")
    btnrow.Size = UDim2.new(1, -6, 0, 34)
    btnrow.BackgroundTransparency = 1
    btnrow.LayoutOrder = order
    btnrow.Parent = content_scroll

    local save_btn = Instance.new("TextButton")
    save_btn.Size = UDim2.new(0.5, -3, 1, 0)
    save_btn.Position = UDim2.new(0, 0, 0, 0)
    save_btn.BackgroundColor3 = C.panel
    save_btn.BorderSizePixel = 0
    save_btn.Font = Enum.Font.Code
    save_btn.TextSize = 11
    save_btn.TextColor3 = accent()
    save_btn.Text = "save config"
    save_btn.AutoButtonColor = false
    save_btn.Parent = btnrow
    local svc = Instance.new("UICorner") svc.CornerRadius = UDim.new(0, 4) svc.Parent = save_btn
    local svs = Instance.new("UIStroke") svs.Color = C.stroke svs.Thickness = 1 svs.Parent = save_btn
    save_btn.MouseButton1Click:Connect(function()
        save_config()
        notify("config saved", C.ok)
        status_right.Text = "saved"
        task.delay(1.5, function() status_right.Text = "ready" end)
    end)

    local reset_btn = Instance.new("TextButton")
    reset_btn.Size = UDim2.new(0.5, -3, 1, 0)
    reset_btn.Position = UDim2.new(0.5, 3, 0, 0)
    reset_btn.BackgroundColor3 = C.panel
    reset_btn.BorderSizePixel = 0
    reset_btn.Font = Enum.Font.Code
    reset_btn.TextSize = 11
    reset_btn.TextColor3 = C.danger
    reset_btn.Text = "reset defaults"
    reset_btn.AutoButtonColor = false
    reset_btn.Parent = btnrow
    local rbc = Instance.new("UICorner") rbc.CornerRadius = UDim.new(0, 4) rbc.Parent = reset_btn
    local rbs = Instance.new("UIStroke") rbs.Color = C.stroke rbs.Thickness = 1 rbs.Parent = reset_btn
    reset_btn.MouseButton1Click:Connect(function()
        config.menu_key = "RightShift"
        config.accent = {0, 200, 130}
        config.ui_scale = 1
        config.notifications = true
        config.modules = {}
        local i = 0
        for _, def in ipairs(defs) do
            i += 1
            local st = get_state(def.id)
            st.key = "F" .. i
        end
        uiScale.Scale = 1
        apply_accent_everywhere()
        rebuild_content()
        save_config()
        notify("reset to defaults", C.danger)
    end)

    order += 1
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -6, 0, 16)
    info.BackgroundTransparency = 1
    info.Font = Enum.Font.Code
    info.TextSize = 10
    info.TextColor3 = C.text_dim
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Text = "config file: " .. CONFIG_FILE .. "  ·  per-user"
    info.LayoutOrder = order
    info.Parent = content_scroll
end

-- ============================================================
-- apply accent to persistent shell elements
-- ============================================================
local function apply_accent_everywhere()
    local a = accent()
    logoDot.BackgroundColor3 = a
    status_right.TextColor3 = a
    content_scroll.ScrollBarImageColor3 = a
    for _, r in pairs(tab_refs) do
        if r.bar then r.bar.BackgroundColor3 = a end
    end
end
apply_accent_everywhere = apply_accent_everywhere  -- forward ref

-- ============================================================
-- content dispatcher
-- ============================================================
local function clear_content()
    for _, child in ipairs(content_scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    row_refs = {}
    slider_refs = {}
    settings_refs = {}
end

local function rebuild_content()
    clear_content()
    search_wrap.Visible = (active_tab ~= "Settings")

    if active_tab == "Settings" then
        build_settings_tab()
        return
    end

    local query = string.lower(search_box.Text or "")
    local shown = {}
    for _, def in ipairs(defs) do
        local matches_tab = (def.tab == active_tab)
        local matches_query = true
        if query ~= "" then
            matches_query = string.find(string.lower(def.name), query, 1, true) ~= nil
                or string.find(string.lower(def.desc or ""), query, 1, true) ~= nil
            matches_tab = true  -- search spans all tabs
        end
        if matches_tab and matches_query then
            table.insert(shown, def)
        end
    end

    if #shown == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -6, 0, 60)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.Code
        empty.TextSize = 11
        empty.TextColor3 = C.text_dim
        empty.Text = "no modules match"
        empty.LayoutOrder = 1
        empty.Parent = content_scroll
        return
    end

    local order = 0
    for _, def in ipairs(shown) do
        order += 1
        build_row(def, order)
    end
end

-- ============================================================
-- tab wiring
-- ============================================================
for name, r in pairs(tab_refs) do
    r.btn.MouseButton1Click:Connect(function()
        if active_tab == name then return end
        local prev = active_tab
        active_tab = name
        -- update visuals
        for n, rr in pairs(tab_refs) do
            local on = (n == name)
            rr.btn.BackgroundColor3 = on and C.panel2 or C.panel
            rr.btn.TextColor3 = on and accent() or C.text_dim
            rr.bar.Visible = on
        end
        rebuild_content()
        status_right.Text = name:lower()
        task.delay(1.2, function()
            if active_tab == name then status_right.Text = "ready" end
        end)
    end)
end

search_box:GetPropertyChangedSignal("Text"):Connect(function()
    if active_tab == "Settings" then return end
    -- debounce
    if search_box.__debounce then
        search_box.__debounce = false
        return
    end
    search_box.__debounce = true
    task.delay(0.12, function()
        if search_box.__debounce then
            search_box.__debounce = false
            rebuild_content()
        end
    end)
end)

-- ============================================================
-- drag
-- ============================================================
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
        local d = input.Position - drag_start
        main.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + d.X, start_pos.Y.Scale, start_pos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    gui.Enabled = false
end)

-- ============================================================
-- keybind / rebind handling
-- ============================================================
local function begin_rebind_module(id, ref)
    rebind_mode = {type="module", id=id, ref=ref, __prev=ref.Text}
    ref.Text = "[...]"
end

local function finish_rebind(keyname)
    if not rebind_mode then return end
    local mode = rebind_mode
    rebind_mode = nil
    if keyname == "Escape" then
        -- cancel
        if mode.ref and mode.__prev then mode.ref.Text = mode.__prev end
        return
    end
    if mode.type == "module" then
        get_state(mode.id).key = keyname
        if mode.ref then mode.ref.Text = "[" .. keyname .. "]" end
        notify("bound " .. keyname, accent())
    elseif mode.type == "menu" then
        config.menu_key = keyname
        if mode.ref then mode.ref.Text = "[" .. keyname .. "]" end
        notify("menu key: " .. keyname, accent())
    end
    schedule_save()
end

local menu_open = true
UserInputService.InputBegan:Connect(function(input, gpe)
    -- ignore while typing in a textbox
    if UserInputService:GetFocusedTextBox() then return end

    -- rebind capture takes priority
    if rebind_mode then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            finish_rebind(input.KeyCode.Name)
        end
        return
    end

    if gpe then return end

    -- menu toggle
    if input.KeyCode.Name == config.menu_key then
        menu_open = not menu_open
        gui.Enabled = menu_open
        return
    end

    -- module hotkeys
    if not gui.Enabled then
        -- still allow module toggles when menu closed
    end
    for _, def in ipairs(defs) do
        local st = get_state(def.id)
        if st.key ~= "" and st.key == input.KeyCode.Name then
            st.enabled = not st.enabled
            local ref = row_refs[def.id]
            if ref then set_toggle_visual(ref, st.enabled) end
            notify(def.name .. (st.enabled and " on" or " off"), st.enabled and accent() or C.text_dim)
            schedule_save()
            return
        end
    end
end)

-- ============================================================
-- feature runtime
-- ============================================================
local esp_folder = Instance.new("Folder")
esp_folder.Name = "larp_esp"
esp_folder.Parent = workspace
local esp_cache = {}

local function clear_esp()
    for _, o in pairs(esp_cache) do
        if o and o.Parent then o:Destroy() end
    end
    esp_cache = {}
end

-- fly state
local fly_conn, fly_objects

local function stop_fly()
    if fly_conn then fly_conn:Disconnect() fly_conn = nil end
    if fly_objects then
        for _, o in ipairs(fly_objects) do if o and o.Parent then o:Destroy() end end
        fly_objects = nil
    end
end

local function start_fly()
    stop_fly()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "larp_fly_v"
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    local bg = Instance.new("BodyGyro")
    bg.Name = "larp_fly_g"
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 1e4
    bg.Parent = hrp
    fly_objects = {bv, bg}

    fly_conn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        local speed = get_state("fly").value or 50
        if dir.Magnitude > 0 then
            bv.Velocity = dir.Unit * speed
        else
            bv.Velocity = Vector3.zero
        end
        bg.CFrame = cam.CFrame
    end)
end

-- fullbright
local fullbright_saved = nil
local function set_fullbright(on, brightness)
    if on then
        if not fullbright_saved then
            fullbright_saved = {
                Ambient        = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Brightness     = Lighting.Brightness,
                ClockTime      = Lighting.ClockTime,
                FogEnd         = Lighting.FogEnd,
            }
        end
        Lighting.Ambient        = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.Brightness     = brightness or 3
        Lighting.ClockTime      = 12
        Lighting.FogEnd         = 100000
    elseif fullbright_saved then
        for k, v in pairs(fullbright_saved) do Lighting[k] = v end
        fullbright_saved = nil
    end
end

-- HUDs
local hud = Instance.new("ScreenGui")
hud.Name = "LarpHUD"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.Parent = LocalPlayer:WaitForChild("PlayerGui")

local health_lbl = Instance.new("TextLabel")
health_lbl.Size = UDim2.fromOffset(200, 22)
health_lbl.Position = UDim2.fromOffset(20, 20)
health_lbl.BackgroundTransparency = 1
health_lbl.Font = Enum.Font.Code
health_lbl.TextSize = 14
health_lbl.TextColor3 = C.text
health_lbl.TextXAlignment = Enum.TextXAlignment.Left
health_lbl.Text = ""
health_lbl.Visible = false
health_lbl.Parent = hud

local fps_lbl = Instance.new("TextLabel")
fps_lbl.Size = UDim2.fromOffset(200, 22)
fps_lbl.Position = UDim2.fromOffset(20, 42)
fps_lbl.BackgroundTransparency = 1
fps_lbl.Font = Enum.Font.Code
fps_lbl.TextSize = 14
fps_lbl.TextColor3 = accent()
fps_lbl.TextXAlignment = Enum.TextXAlignment.Left
fps_lbl.Text = ""
fps_lbl.Visible = false
fps_lbl.Parent = hud

local fps_count, fps_timer = 0, 0
RunService.Heartbeat:Connect(function(dt)
    fps_count += 1
    fps_timer += dt
    if fps_timer >= 1 then
        fps_count = 0
        fps_timer = 0
    end
end)

-- auto arrest / pickpocket
local function nearest_player(range)
    local char = LocalPlayer.Character
    local my_hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not my_hrp then return nil end
    local best, best_d = nil, range
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - my_hrp.Position).Magnitude
                if d < best_d then best, best_d = p, d end
            end
        end
    end
    return best
end

local function try_arrest()
    local target = nearest_player(get_state("autoarrest").range or 12)
    if not target then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and string.find(string.lower(tool.Name), "cuff") then
            pcall(function()
                tool:Activate()
            end)
            return
        end
    end
end

local function try_pickpocket()
    local target = nearest_player(get_state("autopocket").range or 10)
    if not target then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and (string.find(string.lower(tool.Name), "pick") or string.find(string.lower(tool.Name), "steal")) then
            pcall(function() tool:Activate() end)
            return
        end
    end
end

-- infinite jump
local infjump_conn
local function update_infinitejump(on)
    if on and not infjump_conn then
        infjump_conn = UserInputService.JumpRequest:Connect(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    elseif not on and infjump_conn then
        infjump_conn:Disconnect()
        infjump_conn = nil
    end
end

-- anti afk
pcall(function()
    LocalPlayer.Idled:Connect(function()
        if get_state("antiafk").enabled then
            local vu = game:GetService("VirtualUser")
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end
    end)
end)

-- ============================================================
-- main loop
-- ============================================================
local last_esp_check = 0

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local st

    -- speed
    st = get_state("speed")
    if st.enabled then
        hum.WalkSpeed = st.value or 34
    end

    -- fly
    st = get_state("fly")
    if st.enabled and not fly_conn then
        start_fly()
    elseif not st.enabled and fly_conn then
        stop_fly()
    end

    -- noclip
    st = get_state("noclip")
    local want_noclip = st.enabled
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide ~= not want_noclip then
            if want_noclip or (part.Name ~= "HumanoidRootPart") then
                part.CanCollide = not want_noclip
            end
        end
    end

    -- jumppower
    st = get_state("jumppower")
    if st.enabled then
        hum.UseJumpPower = true
        hum.JumpPower = st.value or 50
    end

    -- infinite jump
    update_infinitejump(get_state("infinitejump").enabled)

    -- fov
    st = get_state("fov")
    local cam = workspace.CurrentCamera
    if st.enabled then
        cam.FieldOfView = st.value or 70
    end

    -- fullbright
    st = get_state("fullbright")
    set_fullbright(st.enabled, st.value)

    -- esp
    st = get_state("esp")
    if st.enabled and (tick() - last_esp_check) > 0.2 then
        last_esp_check = tick()
        local col = arrToColor(st.color or {255, 40, 40})
        local maxd = st.maxdist or 1500
        local my_hrp = hrp
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local phrp = p.Character:FindFirstChild("HumanoidRootPart")
                if phrp then
                    local d = (phrp.Position - my_hrp.Position).Magnitude
                    if d <= maxd then
                        local ad = esp_cache[p]
                        if not ad or not ad.Parent then
                            ad = Instance.new("BoxHandleAdornment")
                            ad.Name = "larp_esp_box"
                            ad.Adornee = phrp
                            ad.AlwaysOnTop = true
                            ad.ZIndex = 10
                            ad.Size = Vector3.new(4, 5, 4)
                            ad.Transparency = 0.4
                            ad.Color3 = col
                            ad.Parent = esp_folder
                            esp_cache[p] = ad
                        else
                            ad.Adornee = phrp
                            ad.Color3 = col
                        end
                    else
                        local ad = esp_cache[p]
                        if ad then ad:Destroy() esp_cache[p] = nil end
                    end
                end
            end
        end
    elseif not st.enabled and next(esp_cache) then
        clear_esp()
    end

    -- health hud
    st = get_state("healthhud")
    health_lbl.Visible = st.enabled
    if st.enabled then
        health_lbl.TextColor3 = accent()
        health_lbl.Text = string.format("HP: %d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth))
    end

    -- fps hud
    st = get_state("fpshud")
    fps_lbl.Visible = st.enabled
    if st.enabled then
        fps_lbl.TextColor3 = accent()
        fps_lbl.Text = "FPS: " .. fps_count
    end
end)

-- arrest / pickpocket loop (separate, slower)
task.spawn(function()
    while task.wait(0.15) do
        if get_state("autoarrest").enabled then try_arrest() end
        if get_state("autopocket").enabled then try_pickpocket() end
    end
end)

-- cleanup on character removal
LocalPlayer.CharacterRemoving:Connect(function()
    stop_fly()
    clear_esp()
end)

-- ============================================================
-- init
-- ============================================================
rebuild_content()
apply_accent_everywhere()
status_right.Text = "ready"
