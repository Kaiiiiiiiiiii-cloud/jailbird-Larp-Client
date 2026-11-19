-- larp_client.lua · v1.2

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local InsertService     = game:GetService("InsertService")
local LocalPlayer       = Players.LocalPlayer

local CONFIG_FILE = "larp_client_config.json"

-- ============================================================
-- helpers
-- ============================================================
local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local o = {} for k, vv in pairs(v) do o[k] = deepcopy(vv) end return o
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
-- module defs
-- ============================================================
local defs = {
    -- Combat
    {id="aimbot",     tab="Combat", name="Aimbot",        desc="Locks camera to nearest target. Hold RMB.",
        settings={
            {type="slider", id="fov",    label="FOV (deg)",  min=10, max=360, default=120},
            {type="slider", id="smooth", label="Smoothing",  min=1,  max=30,  default=6},
            {type="slider", id="range",  label="Max Range",  min=50, max=2000, default=500},
        }},
    {id="triggerbot", tab="Combat", name="Triggerbot",    desc="Attacks when crosshair on enemy.",
        settings={
            {type="slider", id="delay", label="Delay (ms)", min=0, max=500, default=50},
            {type="slider", id="fov",   label="FOV (px)",   min=10, max=600, default=120},
        }},
    {id="autoclicker",tab="Combat", name="Auto Clicker",  desc="Clicks automatically.",
        settings={{type="slider", id="cps", label="CPS", min=1, max=50, default=15}}},
    {id="hitbox",     tab="Combat", name="Hitbox Expander", desc="Enlarges other players' hitboxes.",
        settings={{type="slider", id="size", label="Extra Size", min=1, max=25, default=6}}},
    {id="autoarrest", tab="Combat", name="Auto Arrest",   desc="Cuffs nearest player in range.",
        settings={{type="slider", id="range", label="Range (studs)", min=5, max=60, default=12}}},
    {id="autopocket", tab="Combat", name="Auto Pickpocket", desc="Steals from nearest player.",
        settings={{type="slider", id="range", label="Range (studs)", min=5, max=60, default=10}}},

    -- Movement
    {id="speed",      tab="Movement", name="Speed",       desc="Overrides walk speed.",
        settings={{type="slider", id="value", label="Walk Speed", min=16, max=250, default=34}}},
    {id="fly",        tab="Movement", name="Fly",         desc="WASD · Space/LCtrl up-down.",
        settings={{type="slider", id="value", label="Fly Speed", min=10, max:250, default=50}}},
    {id="noclip",     tab="Movement", name="NoClip",      desc="Walk through walls."},
    {id="jumppower",  tab="Movement", name="Jump Power",  desc="Sets humanoid jump power.",
        settings={{type="slider", id="value", label="Power", min=50, max=500, default=50}}},
    {id="infinitejump",tab="Movement",name="Infinite Jump",desc="Jump again mid-air."},

    -- Render
    {id="esp",        tab="Render",   name="ESP",         desc="Highlights other players.",
        settings={
            {type="color",  id="color",   label="Color",        default={255,40,40}},
            {type="slider", id="maxdist", label="Max Distance", min=50, max=3000, default=1500},
        }},
    {id="fullbright", tab="Render",   name="Fullbright",  desc="Brightens the map.",
        settings={{type="slider", id="value", label="Brightness", min=1, max=10, default=3}}},
    {id="fov",        tab="Render",   name="FOV",         desc="Changes camera field of view.",
        settings={{type="slider", id="value", label="FOV", min=40, max=120, default=70}}},

    -- Larping
    {id="coinaura",   tab="Larping",  name="Coin Aura",   desc="Spinning LTC coins orbit you.",
        settings={
            {type="slider", id="count",  label="Coin Count",     min=1, max=20, default=5},
            {type="slider", id="radius", label="Radius (studs)", min=2, max=25, default=6},
            {type="slider", id="speed",  label="Spin Speed",     min=1, max=40, default=10},
            {type="slider", id="height", label="Height",         min=0, max=15, default=3},
            {type="color",  id="color",  label="Coin Color",     default={60,180,255}},
        }},
    {id="playertrail",tab="Larping",  name="Blue Trail",  desc="Blue particle trail behind you.",
        settings={
            {type="slider", id="lifetime", label="Lifetime", min=1, max=30, default=15},
            {type="color",  id="color",    label="Color",    default={60,180,255}},
        }},
    {id="glow",       tab="Larping",  name="Player Glow", desc="Blue point light on you.",
        settings={{type="slider", id="brightness", label="Brightness", min=1, max=10, default=3}}},

    -- Player
    {id="antiafk",    tab="Player", name="Anti AFK",      desc="Prevents idle kick."},
    {id="healthhud",  tab="Player", name="Health Overlay",desc="Shows your HP."},
    {id="fpshud",     tab="Player", name="FPS Counter",   desc="Shows frames per second."},
}

local function module_default(id)
    local d = {enabled=false, key=""}
    for _, def in ipairs(defs) do
        if def.id == id then
            for _, s in ipairs(def.settings or {}) do d[s.id] = deepcopy(s.default) end
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
    if not config.modules[id] then config.modules[id] = module_default(id) end
    return config.modules[id]
end

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
    config.notifications = (data.notifications ~= nil) and data.notifications or true
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
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(config)) end)
end

local save_pending = false
local function schedule_save()
    if save_pending then return end
    save_pending = true
    task.delay(1, function() save_pending = false; save_config() end)
end

load_config()

-- ============================================================
-- colors
-- ============================================================
local C = {
    bg       = Color3.fromRGB(16, 16, 20),
    panel    = Color3.fromRGB(24, 24, 30),
    panel2   = Color3.fromRGB(32, 32, 40),
    panel3   = Color3.fromRGB(40, 40, 50),
    stroke   = Color3.fromRGB(58, 58, 70),
    text     = Color3.fromRGB(228, 228, 234),
    text_dim = Color3.fromRGB(140, 140, 152),
    off      = Color3.fromRGB(70, 70, 82),
    danger   = Color3.fromRGB(220, 70, 70),
    ok       = Color3.fromRGB(90, 210, 120),
}
local function accent() return arrToColor(config.accent) end

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
main.Size = UDim2.fromOffset(620, 440)
main.Position = UDim2.new(0.5, -310, 0.5, -220)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Active = true
main.Parent = gui
local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 6) mc.Parent = main
local ms = Instance.new("UIStroke") ms.Color = C.stroke ms.Thickness = 1 ms.Parent = main

local uiScale = Instance.new("UIScale")
uiScale.Scale = config.ui_scale
uiScale.Parent = main

-- title bar
local titlebar = Instance.new("Frame")
titlebar.Size = UDim2.new(1, 0, 0, 34)
titlebar.BackgroundColor3 = C.panel
titlebar.BorderSizePixel = 0
titlebar.Parent = main
local tbc = Instance.new("UICorner") tbc.CornerRadius = UDim.new(0, 6) tbc.Parent = titlebar
local tbm = Instance.new("Frame") tbm.Size = UDim2.new(1, 0, 0, 17) tbm.Position = UDim2.new(0, 0, 1, -17) tbm.BackgroundColor3 = C.panel tbm.BorderSizePixel = 0 tbm.Parent = titlebar

local logo = Instance.new("Frame") logo.Size = UDim2.fromOffset(8, 8) logo.Position = UDim2.fromOffset(12, 13) logo.BackgroundColor3 = accent() logo.BorderSizePixel = 0 logo.Parent = titlebar
local lc = Instance.new("UICorner") lc.CornerRadius = UDim.new(1, 0) lc.Parent = logo

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1 title.Position = UDim2.fromOffset(28, 0) title.Size = UDim2.new(1, -180, 1, 0)
title.Font = Enum.Font.Code title.TextSize = 14 title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = C.text title.Text = "larp client" title.Parent = titlebar

local ver = Instance.new("TextLabel")
ver.BackgroundTransparency = 1 ver.Position = UDim2.new(1, -160, 0, 0) ver.Size = UDim2.fromOffset(80, 34)
ver.Font = Enum.Font.Code ver.TextSize = 11 ver.TextColor3 = C.text_dim ver.TextXAlignment = Enum.TextXAlignment.Right
ver.Text = "v1.2" ver.Parent = titlebar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(22, 22) closeBtn.Position = UDim2.new(1, -32, 0, 6)
closeBtn.BackgroundColor3 = C.panel2 closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.Code closeBtn.TextSize = 14 closeBtn.TextColor3 = C.text_dim closeBtn.Text = "x" closeBtn.AutoButtonColor = false
closeBtn.Parent = titlebar
local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0, 4) cbc.Parent = closeBtn
closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.12), {BackgroundColor3=C.danger, TextColor3=Color3.new(1,1,1)}):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.12), {BackgroundColor3=C.panel2, TextColor3=C.text_dim}):Play() end)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, -60) sidebar.Position = UDim2.new(0, 0, 0, 34)
sidebar.BackgroundColor3 = C.panel sidebar.BorderSizePixel = 0 sidebar.Parent = main
local sbs = Instance.new("UIStroke") sbs.Color = C.stroke sbs.Thickness = 1 sbs.Parent = sidebar

local tabs = {"Combat", "Movement", "Render", "Larping", "Player", "Settings"}
local active_tab = "Combat"
local tab_refs = {}

local tlist = Instance.new("UIListLayout") tlist.SortOrder = Enum.SortOrder.LayoutOrder tlist.Padding = UDim.new(0, 2) tlist.Parent = sidebar
local tpad = Instance.new("UIPadding") tpad.PaddingTop = UDim.new(0, 8) tpad.PaddingLeft = UDim.new(0, 8) tpad.PaddingRight = UDim.new(0, 8) tpad.Parent = sidebar

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30) btn.BackgroundColor3 = (name == active_tab) and C.panel2 or C.panel
    btn.BorderSizePixel = 0 btn.Font = Enum.Font.Code btn.TextSize = 12
    btn.TextColor3 = (name == active_tab) and accent() or C.text_dim
    btn.TextXAlignment = Enum.TextXAlignment.Left btn.Text = "  " .. name btn.AutoButtonColor = false
    btn.LayoutOrder = i btn.Parent = sidebar
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = btn
    local bar = Instance.new("Frame") bar.Size = UDim2.new(0, 2, 1, -10) bar.Position = UDim2.new(0, 0, 0, 5)
    bar.BackgroundColor3 = accent() bar.BorderSizePixel = 0 bar.Visible = (name == active_tab) bar.Parent = btn
    tab_refs[name] = {btn=btn, bar=bar}
    btn.MouseEnter:Connect(function()
        if active_tab ~= name then TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3=C.panel2, TextColor3=C.text}):Play() end
    end)
    btn.MouseLeave:Connect(function()
        if active_tab ~= name then TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3=C.panel, TextColor3=C.text_dim}):Play() end
    end)
end

-- content
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -130, 1, -60) content.Position = UDim2.new(0, 130, 0, 34)
content.BackgroundColor3 = C.bg content.BorderSizePixel = 0 content.Parent = main

local search_wrap = Instance.new("Frame")
search_wrap.Size = UDim2.new(1, -16, 0, 30) search_wrap.Position = UDim2.fromOffset(8, 8)
search_wrap.BackgroundColor3 = C.panel search_wrap.BorderSizePixel = 0 search_wrap.Parent = content
local swc = Instance.new("UICorner") swc.CornerRadius = UDim.new(0, 4) swc.Parent = search_wrap
local sws = Instance.new("UIStroke") sws.Color = C.stroke sws.Thickness = 1 sws.Parent = search_wrap

local search_icon = Instance.new("TextLabel") search_icon.BackgroundTransparency = 1 search_icon.Position = UDim2.fromOffset(8, 0) search_icon.Size = UDim2.fromOffset(20, 30)
search_icon.Font = Enum.Font.Code search_icon.TextSize = 13 search_icon.TextColor3 = C.text_dim search_icon.Text = "/" search_icon.Parent = search_wrap

local search_box = Instance.new("TextBox")
search_box.BackgroundTransparency = 1 search_box.Position = UDim2.fromOffset(28, 0) search_box.Size = UDim2.new(1, -36, 1, 0)
search_box.Font = Enum.Font.Code search_box.TextSize = 12 search_box.TextColor3 = C.text search_box.TextXAlignment = Enum.TextXAlignment.Left
search_box.PlaceholderText = "search modules..." search_box.PlaceholderColor3 = C.text_dim search_box.Text = "" search_box.ClearTextOnFocus = false
search_box.Parent = search_wrap

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -46) scroll.Position = UDim2.fromOffset(8, 44)
scroll.BackgroundTransparency = 1 scroll.BorderSizePixel = 0 scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = accent() scroll.CanvasSize = UDim2.new(0, 0, 0, 0) scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = content
local sl = Instance.new("UIListLayout") sl.Padding = UDim.new(0, 6) sl.SortOrder = Enum.SortOrder.LayoutOrder sl.Parent = scroll

-- status bar
local statusbar = Instance.new("Frame")
statusbar.Size = UDim2.new(1, 0, 0, 26) statusbar.Position = UDim2.new(0, 0, 1, -26)
statusbar.BackgroundColor3 = C.panel statusbar.BorderSizePixel = 0 statusbar.Parent = main
local sts = Instance.new("UIStroke") sts.Color = C.stroke sts.Thickness = 1 sts.Parent = statusbar

local status_left = Instance.new("TextLabel")
status_left.BackgroundTransparency = 1 status_left.Position = UDim2.fromOffset(10, 0) status_left.Size = UDim2.new(1, -100, 1, 0)
status_left.Font = Enum.Font.Code status_left.TextSize = 11 status_left.TextXAlignment = Enum.TextXAlignment.Left
status_left.TextColor3 = C.text_dim status_left.Text = "user: " .. LocalPlayer.Name status_left.Parent = statusbar

local status_right = Instance.new("TextLabel")
status_right.BackgroundTransparency = 1 status_right.Position = UDim2.new(1, -80, 0, 0) status_right.Size = UDim2.fromOffset(70, 26)
status_right.Font = Enum.Font.Code status_right.TextSize = 11 status_right.TextXAlignment = Enum.TextXAlignment.Right
status_right.TextColor3 = accent() status_right.Text = "ready" status_right.Parent = statusbar

-- ============================================================
-- notifications
-- ============================================================
local toast_holder = Instance.new("Frame")
toast_holder.Size = UDim2.fromOffset(260, 200) toast_holder.Position = UDim2.new(1, -276, 0, 20)
toast_holder.BackgroundTransparency = 1 toast_holder.Parent = gui
local tl = Instance.new("UIListLayout") tl.Padding = UDim.new(0, 6) tl.SortOrder = Enum.SortOrder.LayoutOrder tl.Parent = toast_holder

local toast_order = 0
local function notify(text, col)
    if config.notifications == false then return end
    toast_order += 1
    local t = Instance.new("Frame") t.Size = UDim2.new(1, 0, 0, 30) t.BackgroundColor3 = C.panel2 t.BorderSizePixel = 0 t.LayoutOrder = toast_order t.Parent = toast_holder
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = t
    local s = Instance.new("UIStroke") s.Color = col or accent() s.Thickness = 1 s.Parent = t
    local lab = Instance.new("TextLabel") lab.BackgroundTransparency = 1 lab.Position = UDim2.fromOffset(10, 0) lab.Size = UDim2.new(1, -16, 1, 0)
    lab.Font = Enum.Font.Code lab.TextSize = 11 lab.TextColor3 = C.text lab.TextXAlignment = Enum.TextXAlignment.Left lab.Text = text lab.Parent = t
    task.delay(2.5, function()
        TweenService:Create(t, TweenInfo.new(0.25), {BackgroundTransparency=1}):Play()
        TweenService:Create(s, TweenInfo.new(0.25), {Transparency=1}):Play()
        TweenService:Create(lab, TweenInfo.new(0.25), {TextTransparency=1}):Play()
        task.wait(0.3); t:Destroy()
    end)
end

-- ============================================================
-- rebind state
-- ============================================================
local rebind_mode = nil

local SWATCHES = {
    {255,40,40},{255,150,30},{255,220,40},{90,210,120},
    {0,200,130},{60,180,255},{140,100,255},{255,100,200},
    {230,230,235},{120,120,130},
}

-- ============================================================
-- row builder (rewritten)
-- ============================================================
local expanded = {}
local row_refs = {}
local settings_visible = {}

local function set_toggle_visual(ref, on)
    TweenService:Create(ref.tog, TweenInfo.new(0.14), {BackgroundColor3 = on and accent() or C.off}):Play()
    local goal = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    TweenService:Create(ref.knob, TweenInfo.new(0.14), {Position = goal}):Play()
end

local function calc_row_height(def)
    local h = 46
    if expanded[def.id] and def.settings and #def.settings > 0 then
        h = h + 8 + #def.settings * 36 + 4
    end
    return h
end

local function build_slider(setting, st, parent, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 36) row.BackgroundColor3 = C.panel3 row.BorderSizePixel = 0
    row.LayoutOrder = order row.Parent = parent
    local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 3) rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1 lbl.Position = UDim2.fromOffset(8, 0) lbl.Size = UDim2.new(1, -60, 0, 16)
    lbl.Font = Enum.Font.Code lbl.TextSize = 10 lbl.TextColor3 = C.text_dim lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = setting.label lbl.Parent = row

    local val = Instance.new("TextLabel")
    val.BackgroundTransparency = 1 val.Position = UDim2.new(1, -56, 0, 0) val.Size = UDim2.fromOffset(48, 16)
    val.Font = Enum.Font.Code val.TextSize = 10 val.TextColor3 = accent() val.TextXAlignment = Enum.TextXAlignment.Right
    val.Text = tostring(st[setting.id]) val.Parent = row

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 8) bar.Position = UDim2.new(0, 8, 0, 22)
    bar.BackgroundColor3 = C.off bar.BorderSizePixel = 0 bar.Parent = row
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1,0) bc.Parent = bar

    local alpha0 = (st[setting.id] - setting.min) / (setting.max - setting.min)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(alpha0, 0, 1, 0) fill.BackgroundColor3 = accent() fill.BorderSizePixel = 0 fill.Parent = bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1,0) fc.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12, 12) knob.Position = UDim2.new(alpha0, -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.new(1,1,1) knob.BorderSizePixel = 0 knob.Parent = bar
    local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1,0) kc.Parent = knob

    local function apply_at(mx)
        local ap = bar.AbsolutePosition.X
        local aw = bar.AbsoluteSize.X
        if aw <= 0 then return end
        local a = math.clamp((mx - ap) / aw, 0, 1)
        local v = math.floor(setting.min + a * (setting.max - setting.min))
        st[setting.id] = v
        val.Text = tostring(v)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, -6, 0.5, -6)
        schedule_save()
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            apply_at(UserInputService:GetMouseLocation().X)
            local c1 = UserInputService.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                    apply_at(UserInputService:GetMouseLocation().X)
                end
            end)
            local c2
            c2 = UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    c1:Disconnect(); c2:Disconnect()
                end
            end)
        end
    end)
    return row
end

local function build_color(setting, st, parent, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 32) row.BackgroundColor3 = C.panel3 row.BorderSizePixel = 0
    row.LayoutOrder = order row.Parent = parent
    local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 3) rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1 lbl.Position = UDim2.fromOffset(8, 0) lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Font = Enum.Font.Code lbl.TextSize = 10 lbl.TextColor3 = C.text_dim lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = setting.label lbl.Parent = row

    local preview = Instance.new("TextButton")
    preview.Size = UDim2.fromOffset(28, 20) preview.Position = UDim2.new(1, -36, 0.5, -10)
    preview.BackgroundColor3 = arrToColor(st[setting.id]) preview.BorderSizePixel = 0 preview.Text = "" preview.AutoButtonColor = false
    preview.Parent = row
    local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 3) pc.Parent = preview
    local ps = Instance.new("UIStroke") ps.Color = C.stroke ps.Thickness = 1 ps.Parent = preview

    preview.MouseButton1Click:Connect(function()
        local popup = Instance.new("Frame")
        popup.Size = UDim2.fromOffset(220, 70)
        popup.Position = UDim2.new(0, math.max(0, preview.AbsolutePosition.X - main.AbsolutePosition.X - 100), 0, preview.AbsolutePosition.Y - main.AbsolutePosition.Y + 26)
        popup.BackgroundColor3 = C.panel2 popup.BorderSizePixel = 0 popup.ZIndex = 20 popup.Parent = main
        local ppc = Instance.new("UICorner") ppc.CornerRadius = UDim.new(0, 4) ppc.Parent = popup
        local pps = Instance.new("UIStroke") pps.Color = C.stroke pps.Thickness = 1 pps.Parent = popup
        local grid = Instance.new("UIGridLayout") grid.CellSize = UDim2.fromOffset(18, 18) grid.CellPadding = UDim2.fromOffset(4, 4) grid.Padding = UDim.new(0, 6) grid.Parent = popup
        for _, sw in ipairs(SWATCHES) do
            local s = Instance.new("TextButton")
            s.BackgroundColor3 = arrToColor(sw) s.BorderSizePixel = 0 s.Text = "" s.AutoButtonColor = false s.ZIndex = 21 s.Parent = popup
            local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, 3) sc.Parent = s
            s.MouseButton1Click:Connect(function()
                st[setting.id] = {sw[1], sw[2], sw[3]}
                preview.BackgroundColor3 = arrToColor(sw)
                popup:Destroy()
                schedule_save()
            end)
        end
        task.delay(4, function() if popup and popup.Parent then popup:Destroy() end end)
    end)
    return row
end

local function build_settings_area(def, parent, y_offset)
    local settings_frame = Instance.new("Frame")
    settings_frame.Position = UDim2.fromOffset(4, y_offset)
    settings_frame.Size = UDim2.new(1, -8, 0, #def.settings * 36 + 4)
    settings_frame.BackgroundTransparency = 1
    settings_frame.Visible = expanded[def.id] == true
    settings_frame.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = settings_frame

    local st = get_state(def.id)
    local i = 0
    for _, setting in ipairs(def.settings) do
        i += 1
        if setting.type == "slider" then
            build_slider(setting, st, settings_frame, i)
        elseif setting.type == "color" then
            build_color(setting, st, settings_frame, i)
        end
    end
    return settings_frame
end

local function build_row(def, order)
    local st = get_state(def.id)
    local has_settings = def.settings and #def.settings > 0

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, calc_row_height(def))
    row.BackgroundColor3 = C.panel row.BorderSizePixel = 0
    row.LayoutOrder = order row.ClipsDescendants = true row.Parent = scroll
    local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 4) rc.Parent = row
    local rs = Instance.new("UIStroke") rs.Color = C.stroke rs.Thickness = 1 rs.Parent = row

    local head = Instance.new("TextButton")
    head.Size = UDim2.new(1, 0, 0, 46) head.BackgroundTransparency = 1 head.Text = "" head.AutoButtonColor = false head.Parent = row

    local tog = Instance.new("TextButton")
    tog.Size = UDim2.fromOffset(36, 18) tog.Position = UDim2.new(1, -46, 0, 14)
    tog.BackgroundColor3 = st.enabled and accent() or C.off tog.BorderSizePixel = 0 tog.Text = "" tog.AutoButtonColor = false tog.ZIndex = 3 tog.Parent = head
    local tgc = Instance.new("UICorner") tgc.CornerRadius = UDim.new(1,0) tgc.Parent = tog

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = st.enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1,1,1) knob.BorderSizePixel = 0 knob.ZIndex = 4 knob.Parent = tog
    local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1,0) kc.Parent = knob

    local gear
    if has_settings then
        gear = Instance.new("TextButton")
        gear.Size = UDim2.fromOffset(22, 22) gear.Position = UDim2.new(1, -78, 0, 12)
        gear.BackgroundTransparency = 1 gear.Font = Enum.Font.Code gear.TextSize = 13
        gear.TextColor3 = C.text_dim gear.Text = expanded[def.id] and "v" or ">" gear.AutoButtonColor = false gear.ZIndex = 3 gear.Parent = head
    end

    local key_lbl = Instance.new("TextButton")
    key_lbl.Size = UDim2.fromOffset(42, 18) key_lbl.Position = UDim2.new(1, -130, 0, 14)
    key_lbl.BackgroundColor3 = C.panel2 key_lbl.BorderSizePixel = 0
    key_lbl.Font = Enum.Font.Code key_lbl.TextSize = 10 key_lbl.TextColor3 = C.text_dim
    key_lbl.Text = "[" .. (st.key ~= "" and st.key or "?") .. "]" key_lbl.AutoButtonColor = false key_lbl.ZIndex = 3 key_lbl.Parent = head
    local klc = Instance.new("UICorner") klc.CornerRadius = UDim.new(0, 3) klc.Parent = key_lbl

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1 name.Position = UDim2.fromOffset(12, 6) name.Size = UDim2.new(1, -160, 0, 16)
    name.Font = Enum.Font.Code name.TextSize = 12 name.TextColor3 = C.text name.TextXAlignment = Enum.TextXAlignment.Left
    name.Text = def.name name.ZIndex = 3 name.Parent = head

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1 desc.Position = UDim2.fromOffset(12, 24) desc.Size = UDim2.new(1, -160, 0, 14)
    desc.Font = Enum.Font.Code desc.TextSize = 10 desc.TextColor3 = C.text_dim desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Text = def.desc or "" desc.ZIndex = 3 desc.Parent = head

    head.MouseEnter:Connect(function() TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3=C.panel2}):Play() end)
    head.MouseLeave:Connect(function() TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3=C.panel}):Play() end)

    local ref = {row=row, head=head, tog=tog, knob=knob, key_lbl=key_lbl, gear=gear, def=def}
    row_refs[def.id] = ref

    local function do_toggle()
        st.enabled = not st.enabled
        set_toggle_visual(ref, st.enabled)
        notify(def.name .. (st.enabled and " on" or " off"), st.enabled and accent() or C.text_dim)
        schedule_save()
    end
    tog.MouseButton1Click:Connect(do_toggle)
    head.MouseButton1Click:Connect(do_toggle)

    key_lbl.MouseButton1Click:Connect(function()
        if rebind_mode and rebind_mode.ref then rebind_mode.ref.Text = rebind_mode.__prev or rebind_mode.ref.Text end
        rebind_mode = {type="module", id=def.id, ref=key_lbl, __prev=key_lbl.Text}
        key_lbl.Text = "[...]"
    end)

    local settings_frame
    if has_settings then
        settings_frame = build_settings_area(def, row, 46)
        gear.MouseButton1Click:Connect(function()
            expanded[def.id] = not expanded[def.id]
            gear.Text = expanded[def.id] and "v" or ">"
            local h = calc_row_height(def)
            TweenService:Create(row, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -6, 0, h)}):Play()
            settings_frame.Visible = expanded[def.id] == true
        end)
    end

    return ref
end

-- ============================================================
-- larping tab extras (accessory spawner)
-- ============================================================
local function build_larping_extras()
    local order = 100
    local function mkheader(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -6, 0, 20) l.BackgroundTransparency = 1
        l.Font = Enum.Font.Code l.TextSize = 10 l.TextColor3 = accent() l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = string.upper(text) l.LayoutOrder = order l.Parent = scroll
        order += 1
    end

    mkheader("limiteds / accessories")
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 60) row.BackgroundColor3 = C.panel row.BorderSizePixel = 0
    row.LayoutOrder = order row.Parent = scroll
    order += 1
    local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 4) rc.Parent = row
    local rs = Instance.new("UIStroke") rs.Color = C.stroke rs.Thickness = 1 rs.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1 lbl.Position = UDim2.fromOffset(10, 6) lbl.Size = UDim2.new(1, -20, 0, 14)
    lbl.Font = Enum.Font.Code lbl.TextSize = 10 lbl.TextColor3 = C.text_dim lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = "asset ID (limiteds, hats, accessories)" lbl.Parent = row

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -110, 0, 24) input.Position = UDim2.fromOffset(10, 26)
    input.BackgroundColor3 = C.panel2 input.BorderSizePixel = 0
    input.Font = Enum.Font.Code input.TextSize = 11 input.TextColor3 = C.text
    input.PlaceholderText = "rbxassetid" input.PlaceholderColor3 = C.text_dim
    input.Text = "" input.ClearTextOnFocus = false input.Parent = row
    local ic = Instance.new("UICorner") ic.CornerRadius = UDim.new(0, 3) ic.Parent = input
    local is = Instance.new("UIStroke") is.Color = C.stroke is.Thickness = 1 is.Parent = input

    local spawn_btn = Instance.new("TextButton")
    spawn_btn.Size = UDim2.fromOffset(90, 24) spawn_btn.Position = UDim2.new(1, -100, 0, 26)
    spawn_btn.BackgroundColor3 = C.panel2 spawn_btn.BorderSizePixel = 0
    spawn_btn.Font = Enum.Font.Code spawn_btn.TextSize = 11 spawn_btn.TextColor3 = accent()
    spawn_btn.Text = "spawn" spawn_btn.AutoButtonColor = false spawn_btn.Parent = row
    local sbc = Instance.new("UICorner") sbc.CornerRadius = UDim.new(0, 3) sbc.Parent = spawn_btn
    local sbs2 = Instance.new("UIStroke") sbs2.Color = C.stroke sbs2.Thickness = 1 sbs2.Parent = spawn_btn

    spawn_btn.MouseButton1Click:Connect(function()
        local id = tonumber(input.Text) or tonumber(string.match(input.Text or "", "%d+") or "")
        if not id then
            notify("invalid asset id", C.danger); return
        end
        give_accessory(id)
    end)

    local clear_btn = Instance.new("TextButton")
    clear_btn.Size = UDim2.new(1, -20, 0, 24) clear_btn.Position = UDim2.fromOffset(10, 90)
    -- put below the row via separate section, simpler:

    mkheader("quick accessories")
    local quick_row = Instance.new("Frame")
    quick_row.Size = UDim2.new(1, -6, 0, 36) quick_row.BackgroundTransparency = 1
    quick_row.LayoutOrder = order quick_row.Parent = scroll
    order += 1
    local qgrid = Instance.new("UIGridLayout") qgrid.CellSize = UDim2.new(0.5, -4, 0, 26) qgrid.CellPadding = UDim2.fromOffset(6, 6) qgrid.SortOrder = Enum.SortOrder.LayoutOrder qgrid.Parent = quick_row

    local presets = {
        {name="top hat", color={30,30,30}},
        {name="gold crown", color={255,200,0}},
        {name="blue halo", color={60,180,255}},
        {name="pink wings", color={255,100,200}},
    }
    for _, pr in ipairs(presets) do
        local b = Instance.new("TextButton")
        b.BackgroundColor3 = C.panel b.BorderSizePixel = 0
        b.Font = Enum.Font.Code b.TextSize = 11 b.TextColor3 = C.text b.Text = pr.name b.AutoButtonColor = false
        b.Parent = quick_row
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 3) bc.Parent = b
        local bs = Instance.new("UIStroke") bs.Color = C.stroke bs.Thickness = 1 bs.Parent = b
        b.MouseButton1Click:Connect(function() spawn_primitive_accessory(pr.name, arrToColor(pr.color)) end)
    end

    mkheader("clear")
    local clear_row = Instance.new("Frame")
    clear_row.Size = UDim2.new(1, -6, 0, 30) clear_row.BackgroundTransparency = 1
    clear_row.LayoutOrder = order clear_row.Parent = scroll
    order += 1
    local clear_btn2 = Instance.new("TextButton")
    clear_btn2.Size = UDim2.new(1, 0, 0, 28) clear_btn2.BackgroundColor3 = C.panel2 clear_btn2.BorderSizePixel = 0
    clear_btn2.Font = Enum.Font.Code clear_btn2.TextSize = 11 clear_btn2.TextColor3 = C.danger clear_btn2.Text = "remove all spawned accessories" clear_btn2.AutoButtonColor = false
    clear_btn2.Parent = clear_row
    local cbc2 = Instance.new("UICorner") cbc2.CornerRadius = UDim.new(0, 3) cbc2.Parent = clear_btn2
    local cbs2 = Instance.new("UIStroke") cbs2.Color = C.stroke cbs2.Thickness = 1 cbs2.Parent = clear_btn2
    clear_btn2.MouseButton1Click:Connect(clear_spawned_accessories)
end

-- ============================================================
-- settings tab
-- ============================================================
local function build_settings_tab()
    local order = 0
    local function section(title)
        order += 1
        local lbl = Instance.new("TextLabel") lbl.Size = UDim2.new(1, -6, 0, 20) lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Code lbl.TextSize = 10 lbl.TextColor3 = accent() lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.upper(title) lbl.LayoutOrder = order lbl.Parent = scroll
    end
    local function simple_row(label, h_builder, height)
        order += 1
        local row = Instance.new("Frame") row.Size = UDim2.new(1, -6, 0, height or 34) row.BackgroundColor3 = C.panel row.BorderSizePixel = 0
        row.LayoutOrder = order row.Parent = scroll
        local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 4) rc.Parent = row
        local rs = Instance.new("UIStroke") rs.Color = C.stroke rs.Thickness = 1 rs.Parent = row
        local l = Instance.new("TextLabel") l.BackgroundTransparency = 1 l.Position = UDim2.fromOffset(12, 0) l.Size = UDim2.new(1, -140, 1, 0)
        l.Font = Enum.Font.Code l.TextSize = 12 l.TextColor3 = C.text l.TextXAlignment = Enum.TextXAlignment.Left l.Text = label l.Parent = row
        h_builder(row)
        return row
    end

    section("interface")
    simple_row("Menu Key", function(row)
        local btn = Instance.new("TextButton") btn.Size = UDim2.fromOffset(80, 22) btn.Position = UDim2.new(1, -92, 0.5, -11)
        btn.BackgroundColor3 = C.panel2 btn.BorderSizePixel = 0 btn.Font = Enum.Font.Code btn.TextSize = 11 btn.TextColor3 = C.text
        btn.Text = "[" .. config.menu_key .. "]" btn.AutoButtonColor = false btn.Parent = row
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 3) c.Parent = btn
        local s = Instance.new("UIStroke") s.Color = C.stroke s.Thickness = 1 s.Parent = btn
        btn.MouseButton1Click:Connect(function()
            if rebind_mode and rebind_mode.ref then rebind_mode.ref.Text = rebind_mode.__prev or rebind_mode.ref.Text end
            rebind_mode = {type="menu", ref=btn, __prev=btn.Text}
            btn.Text = "[...]"
        end)
    end)

    simple_row("UI Scale", function(row)
        local bar = Instance.new("Frame") bar.Size = UDim2.fromOffset(140, 8) bar.Position = UDim2.new(1, -160, 0.5, -4)
        bar.BackgroundColor3 = C.off bar.BorderSizePixel = 0 bar.Parent = row
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1,0) bc.Parent = bar
        local min, max = 0.8, 1.4
        local a0 = (config.ui_scale - min) / (max - min)
        local fill = Instance.new("Frame") fill.Size = UDim2.new(a0, 0, 1, 0) fill.BackgroundColor3 = accent() fill.BorderSizePixel = 0 fill.Parent = bar
        local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1,0) fc.Parent = fill
        local val = Instance.new("TextLabel") val.BackgroundTransparency = 1 val.Position = UDim2.new(1, -66, 0, 0) val.Size = UDim2.fromOffset(60, 34)
        val.Font = Enum.Font.Code val.TextSize = 11 val.TextColor3 = accent() val.TextXAlignment = Enum.TextXAlignment.Right
        val.Text = string.format("%.2f", config.ui_scale) val.Parent = row
        row.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local function upd()
                local mx = UserInputService:GetMouseLocation().X
                local ap, aw = bar.AbsolutePosition.X, bar.AbsoluteSize.X
                if aw <= 0 then return end
                local a = math.clamp((mx - ap) / aw, 0, 1)
                config.ui_scale = math.floor((min + a * (max - min)) * 100 + 0.5) / 100
                val.Text = string.format("%.2f", config.ui_scale)
                fill.Size = UDim2.new(a, 0, 1, 0)
                uiScale.Scale = config.ui_scale
                schedule_save()
            end
            upd()
            local c1 = UserInputService.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement then upd() end end)
            local c2; c2 = UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then c1:Disconnect() c2:Disconnect() end end)
        end)
    end)

    simple_row("Notifications", function(row)
        local tog = Instance.new("TextButton") tog.Size = UDim2.fromOffset(36, 18) tog.Position = UDim2.new(1, -46, 0.5, -9)
        tog.BackgroundColor3 = config.notifications and accent() or C.off tog.BorderSizePixel = 0 tog.Text = "" tog.AutoButtonColor = false tog.Parent = row
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1,0) c.Parent = tog
        local knob = Instance.new("Frame") knob.Size = UDim2.fromOffset(14, 14)
        knob.Position = config.notifications and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        knob.BackgroundColor3 = Color3.new(1,1,1) knob.BorderSizePixel = 0 knob.Parent = tog
        local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1,0) kc.Parent = knob
        tog.MouseButton1Click:Connect(function()
            config.notifications = not config.notifications
            TweenService:Create(tog, TweenInfo.new(0.14), {BackgroundColor3 = config.notifications and accent() or C.off}):Play()
            local g = config.notifications and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
            TweenService:Create(knob, TweenInfo.new(0.14), {Position = g}):Play()
            schedule_save()
        end)
    end)

    section("theme accent")
    order += 1
    local arow = Instance.new("Frame") arow.Size = UDim2.new(1, -6, 0, 40) arow.BackgroundColor3 = C.panel arow.BorderSizePixel = 0 arow.LayoutOrder = order arow.Parent = scroll
    local arc = Instance.new("UICorner") arc.CornerRadius = UDim.new(0, 4) arc.Parent = arow
    local ars = Instance.new("UIStroke") ars.Color = C.stroke ars.Thickness = 1 ars.Parent = arow
    local agrid = Instance.new("UIGridLayout") agrid.CellSize = UDim2.fromOffset(24, 24) agrid.CellPadding = UDim2.fromOffset(6, 6) agrid.Padding = UDim.new(0, 8) agrid.Parent = arow
    for _, sw in ipairs(SWATCHES) do
        local s = Instance.new("TextButton") s.BackgroundColor3 = arrToColor(sw) s.BorderSizePixel = 0 s.Text = "" s.AutoButtonColor = false s.Parent = arow
        local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, 4) sc.Parent = s
        if sw[1]==config.accent[1] and sw[2]==config.accent[2] and sw[3]==config.accent[3] then
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

    section("actions")
    order += 1
    local brow = Instance.new("Frame") brow.Size = UDim2.new(1, -6, 0, 34) brow.BackgroundTransparency = 1 brow.LayoutOrder = order brow.Parent = scroll
    local sb = Instance.new("TextButton") sb.Size = UDim2.new(0.5, -3, 1, 0) sb.BackgroundColor3 = C.panel sb.BorderSizePixel = 0
    sb.Font = Enum.Font.Code sb.TextSize = 11 sb.TextColor3 = accent() sb.Text = "save config" sb.AutoButtonColor = false sb.Parent = brow
    local sbc = Instance.new("UICorner") sbc.CornerRadius = UDim.new(0, 4) sbc.Parent = sb
    local sbs = Instance.new("UIStroke") sbs.Color = C.stroke sbs.Thickness = 1 sbs.Parent = sb
    sb.MouseButton1Click:Connect(function() save_config(); notify("saved", C.ok) end)

    local rb = Instance.new("TextButton") rb.Size = UDim2.new(0.5, -3, 1, 0) rb.Position = UDim2.new(0.5, 3, 0, 0)
    rb.BackgroundColor3 = C.panel rb.BorderSizePixel = 0 rb.Font = Enum.Font.Code rb.TextSize = 11 rb.TextColor3 = C.danger
    rb.Text = "reset defaults" rb.AutoButtonColor = false rb.Parent = brow
    local rbc = Instance.new("UICorner") rbc.CornerRadius = UDim.new(0, 4) rbc.Parent = rb
    local rbs = Instance.new("UIStroke") rbs.Color = C.stroke rbs.Thickness = 1 rbs.Parent = rb
    rb.MouseButton1Click:Connect(function()
        config.menu_key = "RightShift" config.accent = {0, 200, 130} config.ui_scale = 1 config.notifications = true config.modules = {}
        local i = 0 for _, d in ipairs(defs) do i += 1; get_state(d.id).key = "F" .. i end
        uiScale.Scale = 1
        apply_accent_everywhere(); rebuild_content(); save_config(); notify("reset", C.danger)
    end)
end

-- ============================================================
-- content dispatcher
-- ============================================================
local function clear_content()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    row_refs = {}
end

local function rebuild_content()
    clear_content()
    search_wrap.Visible = (active_tab ~= "Settings")

    if active_tab == "Settings" then build_settings_tab(); return end

    local query = string.lower(search_box.Text or "")
    local shown = {}
    for _, def in ipairs(defs) do
        local matches_tab = (def.tab == active_tab)
        local matches_query = true
        if query ~= "" then
            matches_query = string.find(string.lower(def.name), query, 1, true) ~= nil
                or string.find(string.lower(def.desc or ""), query, 1, true) ~= nil
            matches_tab = true
        end
        if matches_tab and matches_query then table.insert(shown, def) end
    end

    if #shown == 0 then
        local empty = Instance.new("TextLabel")
