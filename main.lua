-- larp_client.lua · v1.8
-- fatal syntax fix · fully resizable main gui · advanced customization · gradients

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local InsertService     = game:GetService("InsertService")
local VirtualUser       = game:GetService("VirtualUser")
local LocalPlayer       = Players.LocalPlayer

local CONFIG_FILE = "larp_client_config.json"

local function deepcopy(v) if type(v) ~= "table" then return v end local o = {} for k, vv in pairs(v) do o[k] = deepcopy(vv) end return o end
local function arrToColor(a) return Color3.fromRGB(a[1] or 0, a[2] or 0, a[3] or 0) end
local function trim_trailing(s) return (s:gsub("[ \t]+$", "")) end
local function trim_ascii(art)
    local lines = {}
    for line in (art .. "\n"):gmatch("([^\n]*)\n") do table.insert(lines, trim_trailing(line)) end
    while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
    return table.concat(lines, "\n")
end

local defs = {
    -- ═══════ COMBAT ═══════
    {id="aimbot", tab="Combat", name="Aimbot", desc="Locks camera to target. Hold RMB.", settings={
        {type="slider", id="fov", label="FOV (px)", min=10, max=1000, default=250},
        {type="slider", id="smooth", label="Smoothing", min=1, max=30, default=6},
        {type="slider", id="range", label="Max Range", min=50, max=2000, default=500},
        {type="slider", id="prediction", label="Prediction (ms)", min=0, max=500, default=0},
        {type="dropdown", id="part", label="Aim Part", options={"Head","HumanoidRootPart","UpperTorso","LowerTorso"}, default="Head"},
        {type="dropdown", id="priority", label="Priority", options={"Nearest","Lowest HP","Crosshair"}, default="Nearest"},
        {type="bool", id="team_check", label="Team Check", default=true},
        {type="bool", id="wall_check", label="Wall Check", default=true},
        {type="bool", id="auto_fire", label="Auto Fire", default=false},
        {type="bool", id="toggle_mode", label="Always On", default=false},
    }},
    {id="triggerbot", tab="Combat", name="Triggerbot", desc="Attacks when crosshair on target.", settings={
        {type="slider", id="delay", label="Delay (ms)", min=0, max=500, default=50},
        {type="slider", id="fov", label="FOV (px)", min=10, max=800, default=120},
        {type="slider", id="range", label="Max Range", min=50, max=2000, default=500},
        {type="dropdown", id="part", label="Aim Part", options={"Head","HumanoidRootPart","UpperTorso"}, default="Head"},
        {type="bool", id="team_check", label="Team Check", default=true},
        {type="bool", id="wall_check", label="Wall Check", default=true},
        {type="bool", id="auto_shoot", label="Auto Shoot", default=true},
        {type="bool", id="require_aim", label="Require RMB", default=true},
    }},
    {id="silentaim", tab="Combat", name="Snap Aim", desc="Instant-snap aim (no smoothing).", settings={
        {type="slider", id="fov", label="FOV (px)", min=10, max=1000, default=200},
        {type="slider", id="range", label="Max Range", min=50, max=2000, default=500},
        {type="dropdown", id="part", label="Aim Part", options={"Head","HumanoidRootPart","UpperTorso"}, default="Head"},
        {type="bool", id="team_check", label="Team Check", default=true},
        {type="bool", id="wall_check", label="Wall Check", default=true},
        {type="bool", id="auto_fire", label="Auto Fire", default=true},
    }},
    {id="autoclicker", tab="Combat", name="Auto Clicker", desc="Clicks automatically.", settings={
        {type="slider", id="cps", label="CPS", min=1, max=50, default=15},
    }},
    {id="hitbox", tab="Combat", name="Hitbox Expander", desc="Enlarges other players' hitboxes.", settings={
        {type="slider", id="size", label="Extra Size", min=1, max=25, default=6},
        {type="bool", id="team_check", label="Team Check", default=true},
    }},
    {id="melee_aura", tab="Combat", name="Melee Aura", desc="Swings tool at nearby players.", settings={
        {type="slider", id="range", label="Range (studs)", min=5, max=50, default=15},
        {type="bool", id="team_check", label="Team Check", default=true},
    }},
    {id="autoarrest", tab="Combat", name="Auto Arrest", desc="Cuffs nearest player in range.", settings={
        {type="slider", id="range", label="Range (studs)", min=5, max=60, default=12},
    }},
    {id="autopocket", tab="Combat", name="Auto Pickpocket", desc="Steals from nearest player.", settings={
        {type="slider", id="range", label="Range (studs)", min=5, max=60, default=10},
    }},
    {id="fov_circle", tab="Combat", name="FOV Circle", desc="Draws aimbot FOV on screen.", settings={
        {type="color", id="color", label="Color", default={255,80,80}},
        {type="slider", id="thickness", label="Thickness", min=1, max=6, default=2},
        {type="slider", id="transparency", label="Transparency %", min=0, max=90, default=40},
    }},
    {id="crosshair", tab="Combat", name="Crosshair", desc="Custom crosshair overlay.", settings={
        {type="color", id="color", label="Color", default={255,255,255}},
        {type="slider", id="size", label="Size", min=2, max=40, default=10},
        {type="slider", id="thickness", label="Thickness", min=1, max=6, default=2},
        {type="slider", id="transparency", label="Transparency %", min=0, max=90, default=0},
    }},
    -- ═══════ MOVEMENT ═══════
    {id="speed", tab="Movement", name="Speed", desc="Overrides walk speed.", settings={{type="slider", id="value", label="Walk Speed", min=16, max=250, default=34}}},
    {id="fly", tab="Movement", name="Fly", desc="WASD · Space/LCtrl up-down.", settings={{type="slider", id="value", label="Fly Speed", min=10, max=250, default=50}}},
    {id="noclip", tab="Movement", name="NoClip", desc="Walk through walls."},
    {id="jumppower", tab="Movement", name="Jump Power", desc="Sets humanoid jump power.", settings={{type="slider", id="value", label="Power", min=50, max=500, default=50}}},
    {id="infinitejump", tab="Movement", name="Infinite Jump", desc="Jump again mid-air."},
    -- ═══════ RENDER ═══════
    {id="esp", tab="Render", name="ESP", desc="Highlights other players.", settings={{type="color", id="color", label="Color", default={255,40,40}},{type="slider", id="maxdist", label="Max Distance", min=50, max=3000, default=1500}}},
    {id="fullbright", tab="Render", name="Fullbright", desc="Brightens the map.", settings={{type="slider", id="value", label="Brightness", min=1, max=10, default=3}}},
    {id="fov", tab="Render", name="FOV", desc="Changes camera field of view.", settings={{type="slider", id="value", label="FOV", min=40, max=120, default=70}}},
    -- ═══════ LARPING ═══════
    {id="coinaura", tab="Larping", name="Coin Aura", desc="Spinning LTC coins orbit you.", settings={{type="slider", id="count", label="Coin Count", min=1, max=20, default=5},{type="slider", id="radius", label="Radius (studs)", min=2, max=25, default=6},{type="slider", id="speed", label="Spin Speed", min=1, max=40, default=10},{type="slider", id="height", label="Height", min=0, max=15, default=3},{type="color", id="color", label="Coin Color", default={60,180,255}}}},
    {id="cointrail", tab="Larping", name="Coin Trail", desc="Trails attached to each coin (needs Coin Aura).", settings={{type="slider", id="lifetime", label="Lifetime", min=1, max=30, default=15},{type="color", id="color", label="Trail Color", default={60,180,255}}}},
    {id="glow", tab="Larping", name="Player Glow", desc="Point light on you.", settings={{type="slider", id="brightness", label="Brightness", min=1, max=10, default=3}}},
    -- ═══════ PLAYER ═══════
    {id="antiafk", tab="Player", name="Anti AFK", desc="Prevents idle kick."},
    {id="healthhud", tab="Player", name="Health Overlay", desc="Shows your HP."},
    {id="fpshud", tab="Player", name="FPS Counter", desc="Shows frames per second."},
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
    menu_key="RightShift", accent={200,50,50}, ui_scale=1, notifications=true,
    theme="terminal_red", title="larp client", font_size=12, corner_radius=6,
    transparency=0, animations=true, sidebar_width=130, topbar_height=34,
    show_search=true, show_status=true, show_watermark=true, modules={}
}
local function get_state(id) if not config.modules[id] then config.modules[id] = module_default(id) end return config.modules[id] end
do local i = 0 for _, def in ipairs(defs) do i += 1 local st = get_state(def.id) if st.key == "" then st.key = "F" .. i end end end

local THEMES = {
    terminal_red={bg={8,4,4},panel={20,10,10},panel2={32,16,16},panel3={42,22,22},stroke={90,30,30},text={240,200,200},text_dim={160,90,90},off={60,30,30},accent={200,50,50}},
    matrix_green={bg={2,8,2},panel={8,20,8},panel2={14,32,14},panel3={20,42,20},stroke={40,90,40},text={200,240,200},text_dim={80,150,80},off={30,60,30},accent={60,220,90}},
    cyber_blue={bg={2,4,10},panel={10,18,32},panel2={16,28,48},panel3={22,38,60},stroke={40,80,140},text={200,220,240},text_dim={90,130,180},off={30,45,70},accent={60,180,255}},
    ghost_purple={bg={6,2,10},panel={20,10,30},panel2={30,15,45},panel3={42,22,60},stroke={90,40,130},text={220,200,240},text_dim={140,100,180},off={50,30,70},accent={170,100,255}},
    monochrome={bg={10,10,10},panel={20,20,20},panel2={32,32,32},panel3={42,42,42},stroke={70,70,70},text={240,240,240},text_dim={140,140,140},off={50,50,50},accent={220,220,220}},
    void_black={bg={0,0,0},panel={10,10,10},panel2={18,18,18},panel3={26,26,26},stroke={40,40,40},text={220,220,220},text_dim={120,120,120},off={40,40,40},accent={255,255,255}},
    blood_moon={bg={10,2,2},panel={24,8,8},panel2={36,12,12},panel3={48,18,18},stroke={100,20,20},text={255,220,220},text_dim={200,100,100},off={60,20,20},accent={255,30,30}},
    ocean_deep={bg={0,4,8},panel={8,16,26},panel2={12,24,38},panel3={18,34,50},stroke={30,70,110},text={200,240,255},text_dim={80,140,180},off={25,50,75},accent={40,200,255}},
    sunset_gold={bg={10,6,2},panel={26,18,8},panel2={40,28,12},panel3={52,38,18},stroke={110,80,30},text={255,240,210},text_dim={200,160,100},off={70,50,20},accent={255,180,40}},
    sakura_pink={bg={12,4,8},panel={28,12,20},panel2={42,20,32},panel3={54,28,42},stroke={120,50,80},text={255,220,235},text_dim={200,130,160},off={70,30,45},accent={255,110,170}},
    forest_dark={bg={4,8,4},panel={12,20,12},panel2={18,30,18},panel3={26,40,26},stroke={50,90,50},text={220,240,220},text_dim={120,160,120},off={40,60,40},accent={120,220,80}},
    retro_amber={bg={8,5,0},panel={22,15,2},panel2={35,25,5},panel3={46,32,8},stroke={120,80,20},text={255,200,120},text_dim={180,130,60},off={60,40,10},accent={255,150,20}},
    neon_cyan={bg={0,4,6},panel={5,20,26},panel2={8,32,42},panel3={12,44,58},stroke={20,90,120},text={200,255,255},text_dim={60,180,200},off={15,60,80},accent={0,255,220}},
}

local C = {}
local function apply_theme(name)
    local t = THEMES[name] or THEMES.terminal_red
    for k, v in pairs(t) do C[k] = arrToColor(v) end
    C.danger = arrToColor({220,70,70})
    C.ok = arrToColor({90,210,120})
end
apply_theme(config.theme or "terminal_red")
local function accent() return arrToColor(config.accent) end

local function load_config()
    if not (isfile and readfile) then return end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw or raw == "" then return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or type(data) ~= "table" then return end
    for k, v in pairs(data) do if k ~= "modules" then config[k] = v end end
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
local function save_config() if not writefile then return end pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(config)) end) end
local save_pending = false
local function schedule_save() if save_pending then return end save_pending = true task.delay(1, function() save_pending = false save_config() end) end
load_config()
apply_theme(config.theme or "terminal_red")

-- ═══════════════════════════════════════════
-- TERMINAL
-- ═══════════════════════════════════════════
local termGui = Instance.new("ScreenGui") termGui.Name="LarpTerminal" termGui.ResetOnSpawn=false termGui.IgnoreGuiInset=true termGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling termGui.Parent=LocalPlayer:WaitForChild("PlayerGui")

local termFrame = Instance.new("Frame") termFrame.Size=UDim2.fromOffset(860,560) termFrame.Position=UDim2.new(0.5,-430,0.5,-280) termFrame.BackgroundColor3=Color3.new(0,0,0) termFrame.BackgroundTransparency=0.15 termFrame.BorderSizePixel=0 termFrame.ClipsDescendants=true termFrame.Active=true termFrame.Parent=termGui
local termCorner=Instance.new("UICorner") termCorner.CornerRadius=UDim.new(0,6) termCorner.Parent=termFrame
local termStroke=Instance.new("UIStroke") termStroke.Color=Color3.fromRGB(80,20,20) termStroke.Thickness=1 termStroke.Parent=termFrame

local termTitlebar=Instance.new("Frame") termTitlebar.Size=UDim2.new(1,0,0,30) termTitlebar.BackgroundColor3=Color3.fromRGB(20,10,10) termTitlebar.BorderSizePixel=0 termTitlebar.Parent=termFrame
local ttbC=Instance.new("UICorner") ttbC.CornerRadius=UDim.new(0,6) ttbC.Parent=termTitlebar
local ttbMask=Instance.new("Frame") ttbMask.Size=UDim2.new(1,0,0,15) ttbMask.Position=UDim2.new(0,0,1,-15) ttbMask.BackgroundColor3=Color3.fromRGB(20,10,10) ttbMask.BorderSizePixel=0 ttbMask.Parent=termTitlebar

local termTitleText=Instance.new("TextLabel") termTitleText.BackgroundTransparency=1 termTitleText.Position=UDim2.fromOffset(12,0) termTitleText.Size=UDim2.new(1,-40,1,0) termTitleText.Font=Enum.Font.Code termTitleText.TextSize=12 termTitleText.TextColor3=Color3.fromRGB(200,50,50) termTitleText.TextXAlignment=Enum.TextXAlignment.Left termTitleText.Text="root@larpclient:~" termTitleText.Parent=termTitlebar

local termClose=Instance.new("TextButton") termClose.Size=UDim2.fromOffset(20,20) termClose.Position=UDim2.new(1,-26,0,5) termClose.BackgroundColor3=Color3.fromRGB(40,10,10) termClose.BorderSizePixel=0 termClose.Font=Enum.Font.Code termClose.TextSize=12 termClose.TextColor3=Color3.fromRGB(200,100,100) termClose.Text="x" termClose.AutoButtonColor=false termClose.Parent=termTitlebar
local tcC=Instance.new("UICorner") tcC.CornerRadius=UDim.new(0,4) tcC.Parent=termClose
termClose.MouseButton1Click:Connect(function() termGui:Destroy() end)

local termScroll=Instance.new("ScrollingFrame") termScroll.Size=UDim2.new(1,-20,1,-80) termScroll.Position=UDim2.fromOffset(10,40) termScroll.BackgroundTransparency=1 termScroll.BorderSizePixel=0 termScroll.ScrollBarThickness=3 termScroll.ScrollBarImageColor3=Color3.fromRGB(200,50,50) termScroll.CanvasSize=UDim2.new(0,0,0,0) termScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y termScroll.Parent=termFrame

local ffLine=Instance.new("TextLabel") ffLine.Size=UDim2.new(1,0,0,20) ffLine.Position=UDim2.fromOffset(0,0) ffLine.BackgroundTransparency=1 ffLine.Font=Enum.Font.Code ffLine.TextSize=12 ffLine.TextXAlignment=Enum.TextXAlignment.Left ffLine.RichText=true ffLine.Text='<font color="#FF6666">root@larpclient:~#</font> <font color="#FFAA88">fastfetch</font>' ffLine.Parent=termScroll

local asciiArt=[[
                                              @@%%%%%%%%%%%%%%@@                
                                           @%%%%%%%%%%%%%%%%%%%%%%@             
                                         @%%%%%%%%%%%%%%%%%%%%%%%%%%@           
                                       @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@         
                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@       
                                    @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@      
                                   @%%%%%%%%%%%%%%%       @%%%%%%%%%%%%%%%@     
                                   %%%%%%%%%%%%%%%%       %%%%%%%%%%%%%%%%%@    
                                  %%%%%%%%%%%%%%%%@      @%%%%%%%%%%%%%%%%%%    
                                 @%%%%%%%%%%%%%%%%       %%%%%%%%%%%%%%%%%%%%   
                                 %%%%%%%%%%%%%%%%@      @%%%%%%%%%%%%%%%%%%%%   
                                 %%%%%%%%%%%%%%%%          %%%%%%%%%%%%%%%%%%@  
                                @%%%%%%%%%%%%%%%@         @%%%%%%%%%%%%%%%%%%@  
                                @%%%%%%%%%%%%%@        @%%%%%%%%%%%%%%%%%%%%%@  
                                 %%%%%%%%%%%%@         %%%%%%%%%%%%%%%%%%%%%%@  
                                 %%%%%%%%%%%%@@       @%%%%%%%%%%%%%%%%%%%%%%   
                                 @%%%%%%%%%%%%%       @@@@@@@@@@@%%%%%%%%%%%%   
                                  %%%%%%%%%%%%@                  %%%%%%%%%%%    
                                  @%%%%%%%%%%%                  @%%%%%%%%%%@    
                                   @%%%%%%%%%%@@@@@@@@@@@@@@@@@@%%%%%%%%%%%     
                                    @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%      
                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@       
                                       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@        
                                         %%%%%%%%%%%%%%%%%%%%%%%%%%%%@          
                                           @%%%%%%%%%%%%%%%%%%%%%%%@            
                                              @%%%%%%%%%%%%%%%%@                
                                                   @@@@@@@@                     
]]
local asciiTrimmed = trim_ascii(asciiArt)

local termSpecs=[[
OS: Larp Client 1.8.0 x86_64
Host: Larp Station (LARP-1337)
Kernel: 6.9.0-larp-generic
Uptime: 1337 hours, 42 mins
Packages: 1337 (dpkg), 1 (roblox)
Shell: bash 5.2.15
Resolution: 1920x1080 @ 144hz
WM: LarpWM (X11)
Theme: Larp Dark Red
CPU: 13th Gen Intel(R) Core(TM) i7-1360P
GPU: Intel Iris Xe Graphics
Memory: 7.11 GiB / 30.90 GiB (23%)
Disk (/): 276.20 GiB / 914.78 GiB (30%)
Locale: en_US.UTF-8
]]

local bodyRow=Instance.new("Frame") bodyRow.Size=UDim2.new(1,0,0,0) bodyRow.Position=UDim2.fromOffset(0,26) bodyRow.AutomaticSize=Enum.AutomaticSize.Y bodyRow.BackgroundTransparency=1 bodyRow.Parent=termScroll

local asciiLabel=Instance.new("TextLabel") asciiLabel.Size=UDim2.new(0.6,0,0,0) asciiLabel.Position=UDim2.fromOffset(0,0) asciiLabel.AutomaticSize=Enum.AutomaticSize.Y asciiLabel.BackgroundTransparency=1 asciiLabel.Font=Enum.Font.Code asciiLabel.TextSize=9 asciiLabel.TextXAlignment=Enum.TextXAlignment.Left asciiLabel.TextYAlignment=Enum.TextYAlignment.Top asciiLabel.TextWrapped=false asciiLabel.RichText=true asciiLabel.Text=string.format('<font color="#8B0000">%s</font>', asciiTrimmed) asciiLabel.Parent=bodyRow

local specLabel=Instance.new("TextLabel") specLabel.Size=UDim2.new(0.4,-10,0,0) specLabel.Position=UDim2.new(0.6,10,0,0) specLabel.AutomaticSize=Enum.AutomaticSize.Y specLabel.BackgroundTransparency=1 specLabel.Font=Enum.Font.Code specLabel.TextSize=11 specLabel.TextXAlignment=Enum.TextXAlignment.Left specLabel.TextYAlignment=Enum.TextYAlignment.Top specLabel.TextWrapped=true specLabel.RichText=true specLabel.Text=string.format('<font color="#FF6666">%s</font>', termSpecs) specLabel.Parent=bodyRow

local promptRow=Instance.new("Frame") promptRow.Size=UDim2.new(1,-20,0,30) promptRow.Position=UDim2.new(0,10,1,-40) promptRow.BackgroundTransparency=1 promptRow.Parent=termFrame

local termInputPrompt=Instance.new("TextLabel") termInputPrompt.Size=UDim2.fromOffset(400,20) termInputPrompt.Position=UDim2.fromOffset(0,5) termInputPrompt.BackgroundTransparency=1 termInputPrompt.Font=Enum.Font.Code termInputPrompt.TextSize=12 termInputPrompt.TextColor3=Color3.fromRGB(255,100,100) termInputPrompt.TextXAlignment=Enum.TextXAlignment.Left termInputPrompt.Text="root@larpclient:~# Do you want to proceed? (y/n)" termInputPrompt.Parent=promptRow

local termInput=Instance.new("TextBox") termInput.Size=UDim2.new(1,-410,0,20) termInput.Position=UDim2.fromOffset(410,5) termInput.BackgroundTransparency=1 termInput.Font=Enum.Font.Code termInput.TextSize=12 termInput.TextColor3=Color3.fromRGB(255,150,150) termInput.Text="" termInput.TextXAlignment=Enum.TextXAlignment.Left termInput.ClearTextOnFocus=false termInput.PlaceholderText="_" termInput.PlaceholderColor3=Color3.fromRGB(255,150,150) termInput.Parent=promptRow

local termResize=Instance.new("TextButton") termResize.Size=UDim2.fromOffset(16,16) termResize.Position=UDim2.new(1,-16,1,-16) termResize.BackgroundTransparency=1 termResize.Text="//" termResize.TextColor3=Color3.fromRGB(100,50,50) termResize.Font=Enum.Font.Code termResize.TextSize=12 termResize.Parent=termFrame

local termDragging,termDragStart,termStartPos
termTitlebar.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then termDragging=true termDragStart=input.Position termStartPos=termFrame.Position end end)
local termResizing,termResizeStart,termSizeStart
termResize.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then termResizing=true termResizeStart=input.Position termSizeStart=termFrame.Size end end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
        if termDragging then local delta=input.Position-termDragStart termFrame.Position=UDim2.new(termStartPos.X.Scale,termStartPos.X.Offset+delta.X,termStartPos.Y.Scale,termStartPos.Y.Offset+delta.Y)
        elseif termResizing then local delta=input.Position-termResizeStart termFrame.Size=UDim2.fromOffset(math.max(500,termSizeStart.X.Offset+delta.X),math.max(350,termSizeStart.Y.Offset+delta.Y)) end
    end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then termDragging=false termResizing=false end end)

-- ═══════════════════════════════════════════
-- CONNECTION TRACKING
-- ═══════════════════════════════════════════
local main_conns = {}
local function track(c) table.insert(main_conns, c); return c end
local function untrack_all()
    for _, c in ipairs(main_conns) do pcall(function() c:Disconnect() end) end
    main_conns = {}
end

-- ═══════════════════════════════════════════
-- OVERLAYS (FOV + Crosshair + Watermark)
-- ═══════════════════════════════════════════
local overlay = Instance.new("ScreenGui") overlay.Name="LarpOverlay" overlay.ResetOnSpawn=false overlay.IgnoreGuiInset=true overlay.Parent=LocalPlayer:WaitForChild("PlayerGui")

local fov_circle = Instance.new("Frame")
fov_circle.AnchorPoint=Vector2.new(0.5,0.5) fov_circle.Position=UDim2.fromScale(0.5,0.5) fov_circle.Size=UDim2.fromOffset(2,2) fov_circle.BackgroundTransparency=1 fov_circle.BorderSizePixel=0 fov_circle.Visible=false fov_circle.Parent=overlay
local fov_corner=Instance.new("UICorner") fov_corner.CornerRadius=UDim.new(0.5,0) fov_corner.Parent=fov_circle
local fov_stroke=Instance.new("UIStroke") fov_stroke.Color=Color3.fromRGB(255,80,80) fov_stroke.Thickness=2 fov_stroke.Transparency=0.4 fov_stroke.Parent=fov_circle

local ch_h=Instance.new("Frame") ch_h.AnchorPoint=Vector2.new(0.5,0.5) ch_h.Position=UDim2.fromScale(0.5,0.5) ch_h.Size=UDim2.fromOffset(10,2) ch_h.BackgroundColor3=Color3.new(1,1,1) ch_h.BorderSizePixel=0 ch_h.Visible=false ch_h.Parent=overlay
local ch_v=Instance.new("Frame") ch_v.AnchorPoint=Vector2.new(0.5,0.5) ch_v.Position=UDim2.fromScale(0.5,0.5) ch_v.Size=UDim2.fromOffset(2,10) ch_v.BackgroundColor3=Color3.new(1,1,1) ch_v.BorderSizePixel=0 ch_v.Visible=false ch_v.Parent=overlay

local watermark=Instance.new("TextLabel") watermark.Size=UDim2.fromOffset(200,20) watermark.Position=UDim2.fromOffset(20,20) watermark.BackgroundTransparency=1 watermark.Font=Enum.Font.Code watermark.TextSize=14 watermark.TextColor3=Color3.fromRGB(255,255,255) watermark.TextXAlignment=Enum.TextXAlignment.Left watermark.Text="larp client • RightShift" watermark.Visible=false watermark.Parent=overlay

-- ═══════════════════════════════════════════
-- MAIN GUI
-- ═══════════════════════════════════════════
local mainGui = nil

local function init_main_gui()
    untrack_all()
    mainGui = Instance.new("ScreenGui") mainGui.Name="LarpClient" mainGui.ResetOnSpawn=false mainGui.IgnoreGuiInset=true mainGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling mainGui.Parent=LocalPlayer:WaitForChild("PlayerGui")

    local main = Instance.new("Frame")
    main.Size=UDim2.fromOffset(640,460) main.Position=UDim2.new(0.5,-320,0.5,-230)
    main.BackgroundColor3=C.bg main.BackgroundTransparency=config.transparency or 0 main.BorderSizePixel=0 main.ClipsDescendants=true main.Active=true main.Parent=mainGui
    local mc=Instance.new("UICorner") mc.CornerRadius=UDim.new(0,config.corner_radius or 6) mc.Parent=main
    local ms=Instance.new("UIStroke") ms.Color=C.stroke ms.Thickness=1 ms.Parent=main
    local mg=Instance.new("UIGradient") mg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C.bg),ColorSequenceKeypoint.new(1,C.panel)}) mg.Parent=main

    local uiScale=Instance.new("UIScale") uiScale.Scale=config.ui_scale uiScale.Parent=main
    local baseFont = config.font_size or 12
    local topH = config.topbar_height or 34
    local sideW = config.sidebar_width or 130

    local titlebar=Instance.new("Frame") titlebar.Size=UDim2.new(1,0,0,topH) titlebar.BackgroundColor3=C.panel titlebar.BorderSizePixel=0 titlebar.Parent=main
    local tbc=Instance.new("UICorner") tbc.CornerRadius=UDim.new(0,config.corner_radius or 6) tbc.Parent=titlebar
    local tbm=Instance.new("Frame") tbm.Size=UDim2.new(1,0,0,topH/2) tbm.Position=UDim2.new(0,0,1,-topH/2) tbm.BackgroundColor3=C.panel tbm.BorderSizePixel=0 tbm.Parent=titlebar
    local tg=Instance.new("UIGradient") tg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C.panel2),ColorSequenceKeypoint.new(1,C.panel)}) tg.Parent=titlebar

    local logo=Instance.new("Frame") logo.Size=UDim2.fromOffset(8,8) logo.Position=UDim2.fromOffset(12,topH/2-4) logo.BackgroundColor3=accent() logo.BorderSizePixel=0 logo.Parent=titlebar
    local lc=Instance.new("UICorner") lc.CornerRadius=UDim.new(1,0) lc.Parent=logo
    local logoGlow=Instance.new("ImageLabel") logoGlow.Size=UDim2.fromOffset(30,30) logoGlow.Position=UDim2.fromOffset(-11,-11) logoGlow.BackgroundTransparency=1 logoGlow.Image="rbxassetid://5028857472" logoGlow.ImageColor3=accent() logoGlow.ImageTransparency=0.3 logoGlow.ZIndex=0 logoGlow.Parent=logo
    if config.animations then
        task.spawn(function()
            while logo.Parent do
                TweenService:Create(logoGlow,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{ImageTransparency=0.7,Size=UDim2.fromOffset(36,36),Position=UDim2.fromOffset(-14,-14)}):Play()
                task.wait(1.5)
                TweenService:Create(logoGlow,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{ImageTransparency=0.2,Size=UDim2.fromOffset(30,30),Position=UDim2.fromOffset(-11,-11)}):Play()
                task.wait(1.5)
            end
        end)
    end

    local title=Instance.new("TextLabel") title.BackgroundTransparency=1 title.Position=UDim2.fromOffset(28,0) title.Size=UDim2.new(1,-180,1,0) title.Font=Enum.Font.Code title.TextSize=baseFont+2 title.TextXAlignment=Enum.TextXAlignment.Left title.TextColor3=accent() title.Text=config.title title.Parent=titlebar

    local ver=Instance.new("TextLabel") ver.BackgroundTransparency=1 ver.Position=UDim2.new(1,-160,0,0) ver.Size=UDim2.fromOffset(80,topH) ver.Font=Enum.Font.Code ver.TextSize=baseFont-1 ver.TextColor3=C.text_dim ver.TextXAlignment=Enum.TextXAlignment.Right ver.Text="v1.8" ver.Parent=titlebar

    local closeBtn=Instance.new("TextButton") closeBtn.Size=UDim2.fromOffset(22,22) closeBtn.Position=UDim2.new(1,-32,0,topH/2-11) closeBtn.BackgroundColor3=C.panel2 closeBtn.BorderSizePixel=0 closeBtn.Font=Enum.Font.Code closeBtn.TextSize=baseFont+2 closeBtn.TextColor3=C.text_dim closeBtn.Text="x" closeBtn.AutoButtonColor=false closeBtn.Parent=titlebar
    local cbc=Instance.new("UICorner") cbc.CornerRadius=UDim.new(0,4) cbc.Parent=closeBtn
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.12),{BackgroundColor3=C.danger,TextColor3=Color3.new(1,1,1)}):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.12),{BackgroundColor3=C.panel2,TextColor3=C.text_dim}):Play() end)
    closeBtn.MouseButton1Click:Connect(function() mainGui.Enabled=false end)

    local sidebar=Instance.new("Frame") sidebar.Size=UDim2.new(0,sideW,1,-topH-(config.show_status and 26 or 0)) sidebar.Position=UDim2.new(0,0,0,topH) sidebar.BackgroundColor3=C.panel sidebar.BorderSizePixel=0 sidebar.Parent=main
    local sbs=Instance.new("UIStroke") sbs.Color=C.stroke sbs.Thickness=1 sbs.Parent=sidebar
    local sg=Instance.new("UIGradient") sg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C.panel2),ColorSequenceKeypoint.new(1,C.panel)}) sg.Rotation=90 sg.Parent=sidebar

    local tabs={"Combat","Movement","Render","Larping","Player","Settings"}
    local active_tab="Combat"
    local tab_refs={}

    local tlist=Instance.new("UIListLayout") tlist.SortOrder=Enum.SortOrder.LayoutOrder tlist.Padding=UDim.new(0,2) tlist.Parent=sidebar
    local tpad=Instance.new("UIPadding") tpad.PaddingTop=UDim.new(0,8) tpad.PaddingLeft=UDim.new(0,8) tpad.PaddingRight=UDim.new(0,8) tpad.Parent=sidebar

    for i,name in ipairs(tabs) do
        local btn=Instance.new("TextButton") btn.Size=UDim2.new(1,0,0,30) btn.BackgroundColor3=(name==active_tab) and C.panel2 or C.panel btn.BackgroundTransparency=(name==active_tab) and 0 or 0.5 btn.BorderSizePixel=0 btn.Font=Enum.Font.Code btn.TextSize=baseFont btn.TextColor3=(name==active_tab) and accent() or C.text_dim btn.TextXAlignment=Enum.TextXAlignment.Left btn.Text="  "..name btn.AutoButtonColor=false btn.LayoutOrder=i btn.Parent=sidebar
        local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(0,4) bc.Parent=btn
        local bar=Instance.new("Frame") bar.Size=UDim2.new(0,2,1,-10) bar.Position=UDim2.new(0,0,0,5) bar.BackgroundColor3=accent() bar.BorderSizePixel=0 bar.Visible=(name==active_tab) bar.Parent=btn
        tab_refs[name]={btn=btn,bar=bar}
        btn.MouseEnter:Connect(function() if active_tab~=name then TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=C.panel2,TextColor3=C.text}):Play() end end)
        btn.MouseLeave:Connect(function() if active_tab~=name then TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=C.panel,TextColor3=C.text_dim}):Play() end end)
    end

    local content=Instance.new("Frame") content.Size=UDim2.new(1,-sideW,1,-topH-(config.show_status and 26 or 0)) content.Position=UDim2.new(0,sideW,0,topH) content.BackgroundColor3=C.bg content.BackgroundTransparency=config.transparency or 0 content.BorderSizePixel=0 content.Parent=main

    local search_wrap=Instance.new("Frame") search_wrap.Size=UDim2.new(1,-16,0,30) search_wrap.Position=UDim2.fromOffset(8,8) search_wrap.BackgroundColor3=C.panel search_wrap.BorderSizePixel=0 search_wrap.Visible=config.show_search search_wrap.Parent=content
    local swc=Instance.new("UICorner") swc.CornerRadius=UDim.new(0,4) swc.Parent=search_wrap
    local sws=Instance.new("UIStroke") sws.Color=C.stroke sws.Thickness=1 sws.Parent=search_wrap
    local search_icon=Instance.new("TextLabel") search_icon.BackgroundTransparency=1 search_icon.Position=UDim2.fromOffset(8,0) search_icon.Size=UDim2.fromOffset(20,30) search_icon.Font=Enum.Font.Code search_icon.TextSize=baseFont+1 search_icon.TextColor3=C.text_dim search_icon.Text="/" search_icon.Parent=search_wrap

    local search_box=Instance.new("TextBox") search_box.BackgroundTransparency=1 search_box.Position=UDim2.fromOffset(28,0) search_box.Size=UDim2.new(1,-36,1,0) search_box.Font=Enum.Font.Code search_box.TextSize=baseFont search_box.TextColor3=C.text search_box.TextXAlignment=Enum.TextXAlignment.Left search_box.PlaceholderText="search modules..." search_box.PlaceholderColor3=C.text_dim search_box.Text="" search_box.ClearTextOnFocus=false search_box.Parent=search_wrap

    local scrollY = config.show_search and 44 or 8
    local scrollH = config.show_search and (1 - (44 + (config.show_status and 26 or 0))/460) or (1 - (8 + (config.show_status and 26 or 0))/460)
    local scroll=Instance.new("ScrollingFrame") scroll.Size=UDim2.new(1,-16,scrollH,config.show_status and -26 or 0) scroll.Position=UDim2.fromOffset(8,scrollY) scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.ScrollBarThickness=3 scroll.ScrollBarImageColor3=accent() scroll.CanvasSize=UDim2.new(0,0,0,0) scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y scroll.Parent=content
    local sl=Instance.new("UIListLayout") sl.Padding=UDim.new(0,6) sl.SortOrder=Enum.SortOrder.LayoutOrder sl.Parent=scroll

    local statusbar=Instance.new("Frame") statusbar.Size=UDim2.new(1,0,0,26) statusbar.Position=UDim2.new(0,0,1,-26) statusbar.BackgroundColor3=C.panel statusbar.BorderSizePixel=0 statusbar.Visible=config.show_status statusbar.Parent=main
    local sts=Instance.new("UIStroke") sts.Color=C.stroke sts.Thickness=1 sts.Parent=statusbar
    local status_left=Instance.new("TextLabel") status_left.BackgroundTransparency=1 status_left.Position=UDim2.fromOffset(10,0) status_left.Size=UDim2.new(1,-100,1,0) status_left.Font=Enum.Font.Code status_left.TextSize=baseFont-1 status_left.TextXAlignment=Enum.TextXAlignment.Left status_left.TextColor3=C.text_dim status_left.Text="user: "..LocalPlayer.Name status_left.Parent=statusbar
    local status_right=Instance.new("TextLabel") status_right.BackgroundTransparency=1 status_right.Position=UDim2.new(1,-80,0,0) status_right.Size=UDim2.fromOffset(70,26) status_right.Font=Enum.Font.Code status_right.TextSize=baseFont-1 status_right.TextXAlignment=Enum.TextXAlignment.Right status_right.TextColor3=accent() status_right.Text="ready" status_right.Parent=statusbar

    local toast_holder=Instance.new("Frame") toast_holder.Size=UDim2.fromOffset(260,200) toast_holder.Position=UDim2.new(1,-276,0,20) toast_holder.BackgroundTransparency=1 toast_holder.Parent=mainGui
    local tl=Instance.new("UIListLayout") tl.Padding=UDim.new(0,6) tl.SortOrder=Enum.SortOrder.LayoutOrder tl.Parent=toast_holder

    local toast_order=0
    local function notify(text,col)
        if config.notifications==false then return end
        toast_order += 1
        local t=Instance.new("Frame") t.Size=UDim2.new(1,0,0,30) t.BackgroundColor3=C.panel2 t.BorderSizePixel=0 t.LayoutOrder=toast_order t.Parent=toast_holder
        local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,4) c.Parent=t
        local s=Instance.new("UIStroke") s.Color=col or accent() s.Thickness=1 s.Parent=t
        local lab=Instance.new("TextLabel") lab.BackgroundTransparency=1 lab.Position=UDim2.fromOffset(10,0) lab.Size=UDim2.new(1,-16,1,0) lab.Font=Enum.Font.Code lab.TextSize=baseFont-1 lab.TextColor3=C.text lab.TextXAlignment=Enum.TextXAlignment.Left lab.Text=text lab.Parent=t
        task.delay(2.5,function()
            TweenService:Create(t,TweenInfo.new(0.25),{BackgroundTransparency=1}):Play()
            TweenService:Create(s,TweenInfo.new(0.25),{Transparency=1}):Play()
            TweenService:Create(lab,TweenInfo.new(0.25),{TextTransparency=1}):Play()
            task.wait(0.3) t:Destroy()
        end)
    end

    local rebind_mode=nil
    local SWATCHES={
        {255,40,40},{255,80,40},{255,150,30},{255,220,40},{220,255,40},
        {140,255,60},{90,210,120},{0,220,140},{0,200,180},{0,200,130},
        {0,180,220},{60,180,255},{40,140,255},{80,100,255},{140,100,255},
        {180,80,255},{220,80,220},{255,100,200},{255,120,160},{255,180,160},
        {240,200,200},{230,230,235},{180,180,200},{120,120,130},{70,70,80},
    }
    local expanded={}
    local row_refs={}

    local function set_toggle_visual(ref,on)
        TweenService:Create(ref.tog,TweenInfo.new(0.14),{BackgroundColor3=on and accent() or C.off}):Play()
        local goal=on and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
        TweenService:Create(ref.knob,TweenInfo.new(0.14),{Position=goal}):Play()
    end

    local function setting_height(s)
        if s.type=="slider" or s.type=="color" then return 36
        elseif s.type=="bool" or s.type=="dropdown" then return 30 end
        return 32
    end

    local function calc_row_height(def)
        local h=46
        if expanded[def.id] and def.settings and #def.settings>0 then
            h=h+8
            for _,s in ipairs(def.settings) do h=h+setting_height(s)+2 end
            h=h+4
        end
        return h
    end

    local function build_slider(setting,st,parent,order)
        local row=Instance.new("Frame") row.Size=UDim2.new(1,-8,0,36) row.BackgroundColor3=C.panel3 row.BorderSizePixel=0 row.LayoutOrder=order row.Parent=parent
        local rc=Instance.new("UICorner") rc.CornerRadius=UDim.new(0,3) rc.Parent=row
        local lbl=Instance.new("TextLabel") lbl.BackgroundTransparency=1 lbl.Position=UDim2.fromOffset(8,0) lbl.Size=UDim2.new(1,-60,0,16) lbl.Font=Enum.Font.Code lbl.TextSize=baseFont-2 lbl.TextColor3=C.text_dim lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Text=setting.label lbl.Parent=row
        local val=Instance.new("TextLabel") val.BackgroundTransparency=1 val.Position=UDim2.new(1,-56,0,0) val.Size=UDim2.fromOffset(48,16) val.Font=Enum.Font.Code val.TextSize=baseFont-2 val.TextColor3=accent() val.TextXAlignment=Enum.TextXAlignment.Right val.Text=tostring(st[setting.id]) val.Parent=row
        local bar=Instance.new("Frame") bar.Size=UDim2.new(1,-16,0,8) bar.Position=UDim2.new(0,8,0,22) bar.BackgroundColor3=C.off bar.BorderSizePixel=0 bar.Parent=row
        local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(1,0) bc.Parent=bar
        local alpha0=(st[setting.id]-setting.min)/(setting.max-setting.min)
        local fill=Instance.new("Frame") fill.Size=UDim2.new(alpha0,0,1,0) fill.BackgroundColor3=accent() fill.BorderSizePixel=0 fill.Parent=bar
        local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(1,0) fc.Parent=fill
        local knob=Instance.new("Frame") knob.Size=UDim2.fromOffset(12,12) knob.Position=UDim2.new(alpha0,-6,0.5,-6) knob.BackgroundColor3=Color3.new(1,1,1) knob.BorderSizePixel=0 knob.Parent=bar
        local kc=Instance.new("UICorner") kc.CornerRadius=UDim.new(1,0) kc.Parent=knob
        local function apply_at(mx)
            local ap,aw=bar.AbsolutePosition.X,bar.AbsoluteSize.X
            if aw<=0 then return end
            local a=math.clamp((mx-ap)/aw,0,1)
            st[setting.id]=math.floor(setting.min+a*(setting.max-setting.min))
            val.Text=tostring(st[setting.id]) fill.Size=UDim2.new(a,0,1,0) knob.Position=UDim2.new(a,-6,0.5,-6)
            schedule_save()
        end
        row.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                apply_at(UserInputService:GetMouseLocation().X)
                local c1=UserInputService.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then apply_at(UserInputService:GetMouseLocation().X) end end)
                local c2; c2=UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then c1:Disconnect() c2:Disconnect() end end)
            end
        end)
    end

    local function build_color(setting,st,parent,order)
        local row=Instance.new("Frame") row.Size=UDim2.new(1,-8,0,32) row.BackgroundColor3=C.panel3 row.BorderSizePixel=0 row.LayoutOrder=order row.Parent=parent
        local rc=Instance.new("UICorner") rc.CornerRadius=UDim.new(0,3) rc.Parent=row
        local lbl=Instance.new("TextLabel") lbl.BackgroundTransparency=1 lbl.Position=UDim2.fromOffset(8,0) lbl.Size=UDim2.new(1,-50,1,0) lbl.Font=Enum.Font.Code lbl.TextSize=baseFont-2 lbl.TextColor3=C.text_dim lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Text=setting.label lbl.Parent=row
        local preview=Instance.new("TextButton") preview.Size=UDim2.fromOffset(28,20) preview.Position=UDim2.new(1,-36,0.5,-10) preview.BackgroundColor3=arrToColor(st[setting.id]) preview.BorderSizePixel=0 preview.Text="" preview.AutoButtonColor=false preview.Parent=row
        local pc=Instance.new("UICorner") pc.CornerRadius=UDim.new(0,3) pc.Parent=preview
        local ps=Instance.new("UIStroke") ps.Color=C.stroke ps.Thickness=1 ps.Parent=preview
        preview.MouseButton1Click:Connect(function()
            local popup=Instance.new("Frame") popup.Size=UDim2.fromOffset(260,90) popup.Position=UDim2.new(0,math.max(0,preview.AbsolutePosition.X-main.AbsolutePosition.X-120),0,preview.AbsolutePosition.Y-main.AbsolutePosition.Y+26) popup.BackgroundColor3=C.panel2 popup.BorderSizePixel=0 popup.ZIndex=20 popup.Parent=main
            local ppc=Instance.new("UICorner") ppc.CornerRadius=UDim.new(0,4) ppc.Parent=popup
            local pps=Instance.new("UIStroke") pps.Color=C.stroke pps.Thickness=1 pps.Parent=popup
            local grid=Instance.new("UIGridLayout") grid.CellSize=UDim2.fromOffset(18,18) grid.CellPadding=UDim2.fromOffset(4,4) grid.Padding=UDim.new(0,6) grid.Parent=popup
            for _,sw in ipairs(SWATCHES) do
                local s=Instance.new("TextButton") s.BackgroundColor3=arrToColor(sw) s.BorderSizePixel=0 s.Text="" s.AutoButtonColor=false s.ZIndex=21 s.Parent=popup
                local sc=Instance.new("UICorner") sc.CornerRadius=UDim.new(0,3) sc.Parent=s
                s.MouseButton1Click:Connect(function() st[setting.id]={sw[1],sw[2],sw[3]} preview.BackgroundColor3=arrToColor(sw) popup:Destroy() schedule_save() end)
            end
            task.delay(4,function() if popup and popup.Parent then popup:Destroy() end end)
        end)
    end

    local function build_bool(setting,st,parent,order)
        local row=Instance.new("Frame") row.Size=UDim2.new(1,-8,0,30) row.BackgroundColor3=C.panel3 row.BorderSizePixel=0 row.LayoutOrder=order row.Parent=parent
        local rc=Instance.new("UICorner") rc.CornerRadius=UDim.new(0,3) rc.Parent=row
        local lbl=Instance.new("TextLabel") lbl.BackgroundTransparency=1 lbl.Position=UDim2.fromOffset(8,0) lbl.Size=UDim2.new(1,-50,1,0) lbl.Font=Enum.Font.Code lbl.TextSize=baseFont-2 lbl.TextColor3=C.text_dim lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Text=setting.label lbl.Parent=row
        local tog=Instance.new("TextButton") tog.Size=UDim2.fromOffset(36,18) tog.Position=UDim2.new(1,-44,0.5,-9) tog.BackgroundColor3=st[setting.id] and accent() or C.off tog.BorderSizePixel=0 tog.Text="" tog.AutoButtonColor=false tog.Parent=row
        local c=Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=tog
        local knob=Instance.new("Frame") knob.Size=UDim2.fromOffset(14,14) knob.Position=st[setting.id] and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7) knob.BackgroundColor3=Color3.new(1,1,1) knob.BorderSizePixel=0 knob.Parent=tog
        local kc=Instance.new("UICorner") kc.CornerRadius=UDim.new(1,0) kc.Parent=knob
        tog.MouseButton1Click:Connect(function()
            st[setting.id]=not st[setting.id]
            TweenService:Create(tog,TweenInfo.new(0.14),{BackgroundColor3=st[setting.id] and accent() or C.off}):Play()
            local g=st[setting.id] and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
            TweenService:Create(knob,TweenInfo.new(0.14),{Position=g}):Play()
            schedule_save()
        end)
    end

    local function build_dropdown(setting,st,parent,order)
        local row=Instance.new("Frame") row.Size=UDim2.new(1,-8,0,30) row.BackgroundColor3=C.panel3 row.BorderSizePixel=0 row.LayoutOrder=order row.Parent=parent
        local rc=Instance.new("UICorner") rc.CornerRadius=UDim.new(0,3) rc.Parent=row
        local lbl=Instance.new("TextLabel") lbl.BackgroundTransparency=1 lbl.Position=UDim2.fromOffset(8,0) lbl.Size=UDim2.new(1,-110,1,0) lbl.Font=Enum.Font.Code lbl.TextSize=baseFont-2 lbl.TextColor3=C.text_dim lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Text=setting.label lbl.Parent=row
        if st[setting.id]==nil then st[setting.id]=setting.default end
        local btn=Instance.new("TextButton") btn.Size=UDim2.fromOffset(95,20) btn.Position=UDim2.new(1,-103,0.5,-10) btn.BackgroundColor3=C.panel2 btn.BorderSizePixel=0 btn.Font=Enum.Font.Code btn.TextSize=baseFont-2 btn.TextColor3=accent() btn.Text=tostring(st[setting.id]) btn.AutoButtonColor=false btn.Parent=row
        local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(0,3) bc.Parent=btn
        local bs=Instance.new("UIStroke") bs.Color=C.stroke bs.Thickness=1 bs.Parent=btn
        btn.MouseButton1Click:Connect(function()
            local cur=st[setting.id] or setting.default
            local idx=1
            for i,opt in ipairs(setting.options) do if opt==cur then idx=i break end end
            idx=(idx%#setting.options)+1
            st[setting.id]=setting.options[idx]
            btn.Text=setting.options[idx]
            schedule_save()
        end)
    end

    local function build_row(def,order)
        local st=get_state(def.id)
        local has_settings=def.settings and #def.settings>0
        local row=Instance.new("Frame") row.Size=UDim2.new(1,-6,0,calc_row_height(def)) row.BackgroundColor3=C.panel row.BorderSizePixel=0 row.LayoutOrder=order row.ClipsDescendants=true row.Parent=scroll
        local rc=Instance.new("UICorner") rc.CornerRadius=UDim.new(0,4) rc.Parent=row
        local rs=Instance.new("UIStroke") rs.Color=C.stroke rs.Thickness=1 rs.Parent=row
        local head=Instance.new("TextButton") head.Size=UDim2.new(1,0,0,46) head.BackgroundTransparency=1 head.Text="" head.AutoButtonColor=false head.Parent=row
        local tog=Instance.new("TextButton") tog.Size=UDim2.fromOffset(36,18) tog.Position=UDim2.new(1,-46,0,14) tog.BackgroundColor3=st.enabled and accent() or C.off tog.BorderSizePixel=0 tog.Text="" tog.AutoButtonColor=false tog.ZIndex=3 tog.Parent=head
        local tgc=Instance.new("UICorner") tgc.CornerRadius=UDim.new(1,0) tgc.Parent=tog
        local knob=Instance.new("Frame") knob.Size=UDim2.fromOffset(14,14) knob.Position=st.enabled and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7) knob.BackgroundColor3=Color3.new(1,1,1) knob.BorderSizePixel=0 knob.ZIndex=4 knob.Parent=tog
        local kc=Instance.new("UICorner") kc.CornerRadius=UDim.new(1,0) kc.Parent=knob
        local gear
        if has_settings then
            gear=Instance.new("TextButton") gear.Size=UDim2.fromOffset(22,22) gear.Position=UDim2.new(1,-78,0,12) gear.BackgroundTransparency=1 gear.Font=Enum.Font.Code gear.TextSize=baseFont+1 gear.TextColor3=C.text_dim gear.Text=expanded[def.id] and "v" or ">" gear.AutoButtonColor=false gear.ZIndex=3 gear.Parent=head
        end
        local key_lbl=Instance.new("TextButton") key_lbl.Size=UDim2.fromOffset(42,18) key_lbl.Position=UDim2.new(1,-130,0,14) key_lbl.BackgroundColor3=C.panel2 key_lbl.BorderSizePixel=0 key_lbl.Font=Enum.Font.Code key_lbl.TextSize=baseFont-2 key_lbl.TextColor3=C.text_dim key_lbl.Text="["..(st.key~="" and st.key or "?").."]" key_lbl.AutoButtonColor=false key_lbl.ZIndex=3 key_lbl.Parent=head
        local klc=Instance.new("UICorner") klc.CornerRadius=UDim.new(0,3) klc.Parent=key_lbl
        local name=Instance.new("TextLabel") name.BackgroundTransparency=1 name.Position=UDim2.fromOffset(12,6) name.Size=UDim2.new(1,-160,0,16) name.Font=Enum.Font.Code name.TextSize=baseFont name.TextColor3=C.text name.TextXAlignment=Enum.TextXAlignment.Left name.Text=def.name name.ZIndex=3 name.Parent=head
        local desc=Instance.new("TextLabel") desc.BackgroundTransparency=1 desc.Position=UDim2.fromOffset(12,24) desc.Size=UDim2.new(1,-160,0,14) desc.Font=Enum.Font.Code desc.TextSize=baseFont-2 desc.TextColor3=C.text_dim desc.TextXAlignment=Enum.TextXAlignment.Left desc.Text=def.desc or "" desc.ZIndex=3 desc.Parent=head
        head.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=C.panel2}):Play() TweenService:Create(rs,TweenInfo.new(0.1),{Color=accent(),Thickness=2}):Play() end)
        head.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=C.panel}):Play() TweenService:Create(rs,TweenInfo.new(0.1),{Color=C.stroke,Thickness=1}):Play() end)
        local ref={row=row,head=head,tog=tog,knob=knob,key_lbl=key_lbl,gear=gear,def=def}
        row_refs[def.id]=ref
        local function do_toggle() st.enabled=not st.enabled set_toggle_visual(ref,st.enabled) notify(def.name..(st.enabled and " on" or " off"),st.enabled and accent() or C.text_dim) schedule_save() end
        tog.MouseButton1Click:Connect(do_toggle)
        head.MouseButton1Click:Connect(do_toggle)
        key_lbl.MouseButton1Click:Connect(function() if rebind_mode and rebind_mode.ref then rebind_mode.ref.Text=rebind_mode.__prev or rebind_mode.ref.Text end rebind_mode={type="module",id=def.id,ref=key_lbl,__prev=key_lbl.Text} key_lbl.Text="[...]" end)
        local settings_frame
        if has_settings then
            local sarea_h=4
            for _,s in ipairs(def.settings) do sarea_h=sarea_h+setting_height(s)+2 end
            settings_frame=Instance.new("Frame") settings_frame.Position=UDim2.fromOffset(4,46) settings_frame.Size=UDim2.new(1,-8,0,sarea_h) settings_frame.BackgroundTransparency=1 settings_frame.Visible=expanded[def.id]==true settings_frame.Parent=row
            local layout=Instance.new("UIListLayout") layout.Padding=UDim.new(0,2) layout.SortOrder=Enum.SortOrder.LayoutOrder layout.Parent=settings_frame
            local i=0
            for _,setting in ipairs(def.settings) do
                i+=1
                if setting.type=="slider" then build_slider(setting,st,settings_frame,i)
                elseif setting.type=="color" then build_color(setting,st,settings_frame,i)
                elseif setting.type=="bool" then build_bool(setting,st,settings_frame,i)
                elseif setting.type=="dropdown" then build_dropdown(setting,st,settings_frame,i) end
            end
            gear.MouseButton1Click:Connect(function() expanded[def.id]=not expanded[def.id] gear.Text=expanded[def.id] and "v" or ">" TweenService:Create(row,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(1,-6,0,calc_row_height(def))}):Play() settings_frame.Visible=expanded[def.id]==true end)
        end
        return ref
    end

    local function build_larping_extras()
        local order=100
        local function mkheader(text) local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-6,0,20) l.BackgroundTransparency=1 l.Font=Enum.Font.Code l.TextSize=baseFont-2 l.TextColor3=accent() l.TextXAlignment=Enum.TextXAlignment.Left l.Text=string.upper(text) l.LayoutOrder=order l.Parent=scroll order+=1 end
        mkheader("limiteds / accessories")
        local row=Instance.new("Frame") row.Size=UDim2.new(1,-6,0,60) row.BackgroundColor3=C.panel row.BorderSizePixel=0 row.LayoutOrder=order row.Parent=scroll order+=1
        local rc=Instance.new("UICorner") rc.CornerRadius=UDim.new(0,4) rc.Parent=row
        local rs=Instance.new("UIStroke") rs.Color=C.stroke rs.Thickness=1 rs.Parent=row
        local lbl=Instance.new("TextLabel") lbl.BackgroundTransparency=1 lbl.Position=UDim2.fromOffset(10,6) lbl.Size=UDim2.new(1,-20,0,14) lbl.Font=Enum.Font.Code lbl.TextSize=baseFont-2 lbl.TextColor3=C.text_dim lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Text="asset ID (limiteds, hats, accessories)" lbl.Parent=row
        local input=Instance.new("TextBox") input.Size=UDim2.new(1,-110,0,24) input.Position=UDim2.fromOffset(10,26) input.BackgroundColor3=C.panel2 input.BorderSizePixel=0 input.Font=Enum.Font.Code input.TextSize=baseFont-1 input.TextColor3=C.text input.PlaceholderText="rbxassetid" input.PlaceholderColor3=C.text_dim input.Text="" input.ClearTextOnFocus=false input.Parent=row
        local ic=Instance.new("UICorner") ic.CornerRadius=UDim.new(0,3) ic.Parent=input
        local is=Instance.new("UIStroke") is.Color=C.stroke is.Thickness=1 is.Parent=input
        local spawn_btn=Instance.new("TextButton") spawn_btn.Size=UDim2.fromOffset(90,24) spawn_btn.Position=UDim2.new(1,-100,0,26) spawn_btn.BackgroundColor3=C.panel2 spawn_btn.BorderSizePixel=0 spawn_btn.Font=Enum.Font.Code spawn_btn.TextSize=baseFont-1 spawn_btn.TextColor3=accent() spawn_btn.Text="spawn" spawn_btn.AutoButtonColor=false spawn_btn.Parent=row
        local sbc=Instance.new("UICorner") sbc.CornerRadius=UDim.new(0,3) sbc.Parent=spawn_btn
        local sbs2=Instance.new("UIStroke") sbs2.Color=C.stroke sbs2.Thickness=1 sbs2.Parent=spawn_btn
        spawn_btn.MouseButton1Click:Connect(function()
            local id=tonumber(input.Text) or tonumber(string.match(input.Text or "","%d+") or "")
            if not id then notify("invalid asset id",C.danger) return end
            give_accessory(id)
        end)
        mkheader("quick accessories")
        local quick_row=Instance.new("Frame") quick_row.Size=UDim2.new(1,-6,0,36) quick_row.BackgroundTransparency=1 quick_row.LayoutOrder=order quick_row.Parent=scroll order+=1
        local qgrid=Instance.new("UIGridLayout") qgrid.CellSize=UDim2.new(0.5,-4,0,26) qgrid.CellPadding=UDim2.fromOffset(6,6) qgrid.SortOrder=Enum.SortOrder.LayoutOrder qgrid.Parent=quick_row
        local presets={{name="top hat",color={30,30,30}},{name="gold crown",color={255,200,0}},{name="blue halo",color={60,180,255}},{name="pink wings",color={255,100,200}}}
        for _,pr in ipairs(presets) do
            local b=Instance.new("TextButton") b.BackgroundColor3=C.panel b.BorderSizePixel=0 b.Font=Enum.Font.Code b.TextSize=baseFont-1 b.TextColor3=C.text b.Text=pr.name b.AutoButtonColor=false b.Parent=quick_row
            local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(0,3) bc.Parent=b
            local bs=Instance.new("UIStroke") bs.Color=C.stroke bs.Thickness=1 bs.Parent=b
            b.MouseButton1Click:Connect(function() spawn_primitive_accessory(pr.name,arrToColor(pr.color)) end)
        end
        mkheader("clear")
        local clear_row=Instance.new("Frame") clear_row.Size=UDim2.new(1,-6,0,30) clear_row.BackgroundTransparency=1 clear_row.LayoutOrder=order clear_row.Parent=scroll order+=1
        local clear_btn2=Instance.new("TextButton") clear_btn2.Size=UDim2.new(1,0,0,28) clear_btn2.BackgroundColor3=C.panel2 clear_btn2.BorderSizePixel=0 clear_btn2.Font=Enum.Font.Code clear_btn2.TextSize=baseFont-1 clear_btn2.TextColor3=C.danger clear_btn2.Text="remove all spawned accessories" clear_btn2.AutoButtonColor=false clear_btn2.Parent=clear_row
        local cbc2=Instance.new("UICorner") cbc2.CornerRadius=UDim.new(0,3) cbc2.Parent=clear_btn2
        local cbs2=Instance.new("UIStroke") cbs2.Color=C.stroke cbs2.Thickness=1 cbs2.Parent=clear_btn2
        clear_btn2.MouseButton1Click:Connect(clear_spawned_accessories)
    end

    local function build_settings_tab()
        local order=0
        local function section(t) order+=1 local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,-6,0,20) lbl.BackgroundTransparency=1 lbl.Font=Enum.Font.Code lbl.TextSize=baseFont-2 lbl.TextColor3=accent() lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Text=string.upper(t) lbl.LayoutOrder=order lbl.Parent=scroll end
        local function simple_row(label,h_builder,height)
            order+=1
            local row=Instance.new("Frame") row.Size=UDim2.new(1,-6,0,height or 34) row.BackgroundColor3=C.panel row.BorderSizePixel=0 row.LayoutOrder=order row.Parent=scroll
            local rc=Instance.new("UICorner") rc.CornerRadius=UDim.new(0,4) rc.Parent=row
            local rs=Instance.new("UIStroke") rs.Color=C.stroke rs.Thickness=1 rs.Parent=row
            local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Position=UDim2.fromOffset(12,0) l.Size=UDim2.new(1,-140,1,0) l.Font=Enum.Font.Code l.TextSize=baseFont l.TextColor3=C.text l.TextXAlignment=Enum.TextXAlignment.Left l.Text=label l.Parent=row
            h_builder(row) return row
        end
        local function mini_slider(row,min_val,max_val,cur,on_change)
            local bar=Instance.new("Frame") bar.Size=UDim2.fromOffset(140,8) bar.Position=UDim2.new(1,-160,0.5,-4) bar.BackgroundColor3=C.off bar.BorderSizePixel=0 bar.Parent=row
            local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(1,0) bc.Parent=bar
            local a0=(cur-min_val)/(max_val-min_val)
            local fill=Instance.new("Frame") fill.Size=UDim2.new(a0,0,1,0) fill.BackgroundColor3=accent() fill.BorderSizePixel=0 fill.Parent=bar
            local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(1,0) fc.Parent=fill
            local val=Instance.new("TextLabel") val.BackgroundTransparency=1 val.Position=UDim2.new(1,-66,0,0) val.Size=UDim2.fromOffset(60,34) val.Font=Enum.Font.Code val.TextSize=baseFont-1 val.TextColor3=accent() val.TextXAlignment=Enum.TextXAlignment.Right val.Text=string.format("%.2f",cur) val.Parent=row
            row.InputBegan:Connect(function(input)
                if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
                local function upd()
                    local mx=UserInputService:GetMouseLocation().X
                    local ap,aw=bar.AbsolutePosition.X,bar.AbsoluteSize.X
                    if aw<=0 then return end
                    local a=math.clamp((mx-ap)/aw,0,1)
                    local v=math.floor((min_val+a*(max_val-min_val))*100+0.5)/100
                    val.Text=string.format("%.2f",v)
                    fill.Size=UDim2.new(a,0,1,0)
                    on_change(v)
                end
                upd()
                local c1=UserInputService.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement then upd() end end)
                local c2; c2=UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then c1:Disconnect() c2:Disconnect() end end)
            end)
        end

        section("interface")
        simple_row("Menu Key",function(row) local btn=Instance.new("TextButton") btn.Size=UDim2.fromOffset(80,22) btn.Position=UDim2.new(1,-92,0.5,-11) btn.BackgroundColor3=C.panel2 btn.BorderSizePixel=0 btn.Font=Enum.Font.Code btn.TextSize=baseFont-1 btn.TextColor3=C.text btn.Text="["..config.menu_key.."]" btn.AutoButtonColor=false btn.Parent=row local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,3) c.Parent=btn local s=Instance.new("UIStroke") s.Color=C.stroke s.Thickness=1 s.Parent=btn btn.MouseButton1Click:Connect(function() if rebind_mode and rebind_mode.ref then rebind_mode.ref.Text=rebind_mode.__prev or rebind_mode.ref.Text end rebind_mode={type="menu",ref=btn,__prev=btn.Text} btn.Text="[...]" end) end)
        simple_row("UI Scale",function(row) mini_slider(row,0.7,1.6,config.ui_scale,function(v) config.ui_scale=v uiScale.Scale=v schedule_save() end) end)
        simple_row("Font Size",function(row) mini_slider(row,0.7,1.6,(config.font_size or 12)/12,function(v) config.font_size=math.floor(12*v) schedule_save() notify("reopen to apply",accent()) end) end)
        simple_row("Corner Radius",function(row) mini_slider(row,0,20,(config.corner_radius or 6)/20,function(v) config.corner_radius=math.floor(v*20) schedule_save() notify("reopen to apply",accent()) end) end)
        simple_row("Transparency",function(row) mini_slider(row,0,0.8,config.transparency or 0,function(v) config.transparency=v main.BackgroundTransparency=v content.BackgroundTransparency=v schedule_save() end) end)
        simple_row("Sidebar Width",function(row) mini_slider(row,80,250,(config.sidebar_width or 130)/250,function(v) config.sidebar_width=math.floor(v*250) schedule_save() notify("reopen to apply",accent()) end) end)
        simple_row("Topbar Height",function(row) mini_slider(row,24,60,(config.topbar_height or 34)/60,function(v) config.topbar_height=math.floor(v*60) schedule_save() notify("reopen to apply",accent()) end) end)

        section("toggles")
        local function toggle_row(label, key, callback)
            simple_row(label, function(row)
                local tog=Instance.new("TextButton") tog.Size=UDim2.fromOffset(36,18) tog.Position=UDim2.new(1,-46,0.5,-9) tog.BackgroundColor3=config[key] and accent() or C.off tog.BorderSizePixel=0 tog.Text="" tog.AutoButtonColor=false tog.Parent=row
                local c=Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=tog
                local knob=Instance.new("Frame") knob.Size=UDim2.fromOffset(14,14) knob.Position=config[key] and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7) knob.BackgroundColor3=Color3.new(1,1,1) knob.BorderSizePixel=0 knob.Parent=tog
                local kc=Instance.new("UICorner") kc.CornerRadius=UDim.new(1,0) kc.Parent=knob
                tog.MouseButton1Click:Connect(function()
                    config[key]=not config[key]
                    TweenService:Create(tog,TweenInfo.new(0.14),{BackgroundColor3=config[key] and accent() or C.off}):Play()
                    local g=config[key] and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
                    TweenService:Create(knob,TweenInfo.new(0.14),{Position=g}):Play()
                    schedule_save()
                    if callback then callback(config[key]) end
                end)
            end)
        end
        toggle_row("Notifications","notifications")
        toggle_row("Animations","animations")
        toggle_row("Show Search Bar","show_search", function(v) notify("reopen to apply",accent()) end)
        toggle_row("Show Status Bar","show_status", function(v) notify("reopen to apply",accent()) end)
        toggle_row("Show Watermark","show_watermark", function(v) watermark.Visible = v and not mainGui.Enabled end)

        section("title text")
        order+=1
        local trow=Instance.new("Frame") trow.Size=UDim2.new(1,-6,0,34) trow.BackgroundColor3=C.panel trow.BorderSizePixel=0 trow.LayoutOrder=order trow.Parent=scroll
        local trc=Instance.new("UICorner") trc.CornerRadius=UDim.new(0,4) trc.Parent=trow
        local trs=Instance.new("UIStroke") trs.Color=C.stroke trs.Thickness=1 trs.Parent=trow
        local tbox=Instance.new("TextBox") tbox.Size=UDim2.new(1,-24,0,24) tbox.Position=UDim2.fromOffset(12,5) tbox.BackgroundColor3=C.panel2 tbox.BorderSizePixel=0 tbox.Font=Enum.Font.Code tbox.TextSize=baseFont tbox.TextColor3=C.text tbox.TextXAlignment=Enum.TextXAlignment.Left tbox.PaddingLeft=UDim.new(0,6) tbox.Text=config.title tbox.ClearTextOnFocus=false tbox.Parent=trow
        local tbc2=Instance.new("UICorner") tbc2.CornerRadius=UDim.new(0,3) tbc2.Parent=tbox
        local tbs2=Instance.new("UIStroke") tbs2.Color=C.stroke tbs2.Thickness=1 tbs2.Parent=tbox
        tbox:GetPropertyChangedSignal("Text"):Connect(function() config.title=tbox.Text title.Text=tbox.Text schedule_save() end)

        section("theme presets")
        order+=1
        local trow2=Instance.new("Frame") trow2.Size=UDim2.new(1,-6,0,34) trow2.BackgroundTransparency=1 trow2.LayoutOrder=order trow2.Parent=scroll
        local tgrid=Instance.new("UIGridLayout") tgrid.CellSize=UDim2.new(0.5,-3,0,28) tgrid.CellPadding=UDim2.fromOffset(6,6) tgrid.SortOrder=Enum.SortOrder.LayoutOrder tgrid.Parent=trow2
        local tpresets={"terminal_red","blood_moon","matrix_green","forest_dark","cyber_blue","ocean_deep","neon_cyan","ghost_purple","sakura_pink","sunset_gold","retro_amber","monochrome","void_black"}
        local cell_count=0
        for _,name in ipairs(tpresets) do
            cell_count+=1
            local t=THEMES[name]
            local b=Instance.new("TextButton") b.BackgroundColor3=arrToColor(t.panel) b.BorderSizePixel=0 b.Font=Enum.Font.Code b.TextSize=baseFont-2 b.TextColor3=arrToColor(t.accent) b.Text=name:gsub("_"," ") b.AutoButtonColor=false b.Parent=trow2 b.LayoutOrder=cell_count
            local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(0,3) bc.Parent=b
            local bs=Instance.new("UIStroke") bs.Color=C.stroke bs.Thickness=1 bs.Parent=b
            if name==config.theme then bs.Color=accent() bs.Thickness=2 end
            b.MouseButton1Click:Connect(function() config.theme=name config.accent=t.accent apply_theme(name) schedule_save() mainGui:Destroy() init_main_gui() end)
        end
        trow2.Size=UDim2.new(1,-6,0,math.ceil(cell_count/2)*34)

        section("custom accent (rgb)")
        order+=1
        local rgbrow=Instance.new("Frame") rgbrow.Size=UDim2.new(1,-6,0,100) rgbrow.BackgroundColor3=C.panel rgbrow.BorderSizePixel=0 rgbrow.LayoutOrder=order rgbrow.Parent=scroll
        local rgc=Instance.new("UICorner") rgc.CornerRadius=UDim.new(0,4) rgc.Parent=rgbrow
        local rgs=Instance.new("UIStroke") rgs.Color=C.stroke rgs.Thickness=1 rgs.Parent=rgbrow
        local preview=Instance.new("Frame") preview.Size=UDim2.fromOffset(40,40) preview.Position=UDim2.new(1,-50,0,5) preview.BackgroundColor3=accent() preview.BorderSizePixel=0 preview.Parent=rgbrow
        local pgc=Instance.new("UICorner") pgc.CornerRadius=UDim.new(0,4) pgc.Parent=preview
        local pgs=Instance.new("UIStroke") pgs.Color=C.stroke pgs.Thickness=1 pgs.Parent=preview
        for ci,ch in ipairs({"R","G","B"}) do
            local r=Instance.new("Frame") r.Size=UDim2.new(1,-60,0,28) r.Position=UDim2.fromOffset(6,6+(ci-1)*30) r.BackgroundTransparency=1 r.Parent=rgbrow
            local l=Instance.new("TextLabel") l.Size=UDim2.fromOffset(20,28) l.BackgroundTransparency=1 l.Font=Enum.Font.Code l.TextSize=baseFont-2 l.TextColor3=C.text_dim l.Text=ch l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=r
            local bar=Instance.new("Frame") bar.Size=UDim2.new(1,-60,0,8) bar.Position=UDim2.fromOffset(30,10) bar.BackgroundColor3=C.off bar.BorderSizePixel=0 bar.Parent=r
            local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(1,0) bc.Parent=bar
            local ch_idx=ci
            local a0=config.accent[ch_idx]/255
            local fill=Instance.new("Frame") fill.Size=UDim2.new(a0,0,1,0) fill.BackgroundColor3=accent() fill.BorderSizePixel=0 fill.Parent=bar
            local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(1,0) fc.Parent=fill
            local val=Instance.new("TextLabel") val.Size=UDim2.fromOffset(30,28) val.Position=UDim2.new(1,-32,0,0) val.BackgroundTransparency=1 val.Font=Enum.Font.Code val.TextSize=baseFont-2 val.TextColor3=accent() val.Text=tostring(config.accent[ch_idx]) val.TextXAlignment=Enum.TextXAlignment.Right val.Parent=r
            r.InputBegan:Connect(function(input)
                if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
                local function upd()
                    local mx=UserInputService:GetMouseLocation().X
                    local ap,aw=bar.AbsolutePosition.X,bar.AbsoluteSize.X
                    if aw<=0 then return end
                    local a=math.clamp((mx-ap)/aw,0,1)
                    local v=math.floor(a*255)
                    config.accent[ch_idx]=v
                    val.Text=tostring(v)
                    fill.Size=UDim2.new(a,0,1,0)
                    preview.BackgroundColor3=accent()
                    schedule_save()
                end
                upd()
                local c1=UserInputService.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement then upd() end end)
                local c2; c2=UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then c1:Disconnect() c2:Disconnect() end end)
            end)
        end

        section("accent swatches")
        order+=1
        local arow=Instance.new("Frame") arow.Size=UDim2.new(1,-6,0,40) arow.BackgroundColor3=C.panel arow.BorderSizePixel=0 arow.LayoutOrder=order arow.Parent=scroll
        local arc=Instance.new("UICorner") arc.CornerRadius=UDim.new(0,4) arc.Parent=arow
        local ars=Instance.new("UIStroke") ars.Color=C.stroke ars.Thickness=1 ars.Parent=arow
        local agrid=Instance.new("UIGridLayout") agrid.CellSize=UDim2.fromOffset(20,20) agrid.CellPadding=UDim2.fromOffset(4,4) agrid.Padding=UDim.new(0,6) agrid.Parent=arow
        for _,sw in ipairs(SWATCHES) do
            local s=Instance.new("TextButton") s.BackgroundColor3=arrToColor(sw) s.BorderSizePixel=0 s.Text="" s.AutoButtonColor=false s.Parent=arow
            local sc=Instance.new("UICorner") sc.CornerRadius=UDim.new(0,4) sc.Parent=s
            if sw[1]==config.accent[1] and sw[2]==config.accent[2] and sw[3]==config.accent[3] then local ss=Instance.new("UIStroke") ss.Color=Color3.new(1,1,1) ss.Thickness=2 ss.Parent=s end
            s.MouseButton1Click:Connect(function() config.accent={sw[1],sw[2],sw[3]} schedule_save() mainGui:Destroy() init_main_gui() end)
        end

        section("actions")
        order+=1
        local brow=Instance.new("Frame") brow.Size=UDim2.new(1,-6,0,34) brow.BackgroundTransparency=1 brow.LayoutOrder=order brow.Parent=scroll
        local sb=Instance.new("TextButton") sb.Size=UDim2.new(0.5,-3,1,0) sb.BackgroundColor3=C.panel sb.BorderSizePixel=0 sb.Font=Enum.Font.Code sb.TextSize=baseFont-1 sb.TextColor3=accent() sb.Text="save config" sb.AutoButtonColor=false sb.Parent=brow
        local sbc=Instance.new("UICorner") sbc.CornerRadius=UDim.new(0,4) sbc.Parent=sb
        local sbs=Instance.new("UIStroke") sbs.Color=C.stroke sbs.Thickness=1 sbs.Parent=sb
        sb.MouseButton1Click:Connect(function() save_config() notify("saved",C.ok) end)
        local rb=Instance.new("TextButton") rb.Size=UDim2.new(0.5,-3,1,0) rb.Position=UDim2.new(0.5,3,0,0) rb.BackgroundColor3=C.panel rb.BorderSizePixel=0 rb.Font=Enum.Font.Code rb.TextSize=baseFont-1 rb.TextColor3=C.danger rb.Text="reset defaults" rb.AutoButtonColor=false rb.Parent=brow
        local rbc=Instance.new("UICorner") rbc.CornerRadius=UDim.new(0,4) rbc.Parent=rb
        local rbs=Instance.new("UIStroke") rbs.Color=C.stroke rbs.Thickness=1 rbs.Parent=rb
        rb.MouseButton1Click:Connect(function()
            config.menu_key="RightShift" config.accent={200,50,50} config.ui_scale=1 config.notifications=true config.theme="terminal_red" config.title="larp client" config.font_size=12 config.corner_radius=6 config.transparency=0 config.animations=true config.sidebar_width=130 config.topbar_height=34 config.show_search=true config.show_status=true config.show_watermark=true config.modules={}
            local i=0 for _,d in ipairs(defs) do i+=1 get_state(d.id).key="F"..i end
            apply_theme(config.theme) save_config() mainGui:Destroy() init_main_gui()
        end)
    end

    local function clear_content()
        for _,child in ipairs(scroll:GetChildren()) do if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end end
        row_refs={}
    end

    local function rebuild_content()
        clear_content()
        search_wrap.Visible=(active_tab~="Settings") and config.show_search
        if active_tab=="Settings" then build_settings_tab() return end
        local query=string.lower(search_box.Text or "")
        local shown={}
        for _,def in ipairs(defs) do
            local matches_tab=(def.tab==active_tab)
            local matches_query=true
            if query~="" then matches_query=string.find(string.lower(def.name),query,1,true)~=nil or string.find(string.lower(def.desc or ""),query,1,true)~=nil matches_tab=true end
            if matches_tab and matches_query then table.insert(shown,def) end
        end
        if #shown==0 then local empty=Instance.new("TextLabel") empty.Size=UDim2.new(1,-6,0,60) empty.BackgroundTransparency=1 empty.Font=Enum.Font.Code empty.TextSize=baseFont-1 empty.TextColor3=C.text_dim empty.Text="no modules match" empty.LayoutOrder=1 empty.Parent=scroll return end
        local order=0
        for _,def in ipairs(shown) do order+=1 build_row(def,order) end
        if active_tab=="Larping" then build_larping_extras() end
    end

    for name,r in pairs(tab_refs) do
        r.btn.MouseButton1Click:Connect(function()
            if active_tab==name then return end
            active_tab=name
            for n,rr in pairs(tab_refs) do local on=(n==name) rr.btn.BackgroundColor3=on and C.panel2 or C.panel rr.btn.TextColor3=on and accent() or C.text_dim rr.bar.Visible=on end
            rebuild_content()
        end)
    end

    local search_debounce=false
    search_box:GetPropertyChangedSignal("Text"):Connect(function()
        if active_tab=="Settings" then return end
        if search_debounce then search_debounce=false return end
        search_debounce=true
        task.delay(0.12,function() if search_debounce then search_debounce=false rebuild_content() end end)
    end)

    local dragging,drag_start,start_pos
    titlebar.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true drag_start=input.Position start_pos=main.Position end end)
    track(UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then local d=input.Position-drag_start main.Position=UDim2.new(start_pos.X.Scale,start_pos.X.Offset+d.X,start_pos.Y.Scale,start_pos.Y.Offset+d.Y) end end))
    track(UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end))

    -- Main GUI Resize Handle
    local main_resize=Instance.new("TextButton")
    main_resize.Size=UDim2.fromOffset(16,16) main_resize.Position=UDim2.new(1,-16,1,-16) main_resize.BackgroundTransparency=1 main_resize.Text="//" main_resize.TextColor3=C.text_dim main_resize.Font=Enum.Font.Code main_resize.TextSize=10 main_resize.Parent=main
    
    local resizing, resize_start, size_start
    main_resize.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then resizing=true resize_start=input.Position size_start=main.Size end end)
    track(UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local d=input.Position-resize_start
            main.Size=UDim2.fromOffset(math.max(400,size_start.X.Offset+d.X), math.max(300,size_start.Y.Offset+d.Y))
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then resizing=false end end))

    local function finish_rebind(keyname)
        if not rebind_mode then return end
        local mode=rebind_mode rebind_mode=nil
        if keyname=="Escape" then if mode.ref and mode.__prev then mode.ref.Text=mode.__prev end return end
        if mode.type=="module" then get_state(mode.id).key=keyname if mode.ref then mode.ref.Text="["..keyname.."]" end notify("bound "..keyname,accent())
        elseif mode.type=="menu" then config.menu_key=keyname if mode.ref then mode.ref.Text="["..keyname.."]" end notify("menu key: "..keyname,accent()) end
        schedule_save()
    end

    track(UserInputService.InputBegan:Connect(function(input,gpe)
        if UserInputService:GetFocusedTextBox() then return end
        if rebind_mode then if input.KeyCode~=Enum.KeyCode.Unknown then finish_rebind(input.KeyCode.Name) end return end
        if gpe then return end
        if input.KeyCode.Name==config.menu_key then 
            mainGui.Enabled=not mainGui.Enabled 
            if config.show_watermark then watermark.Visible = not mainGui.Enabled else watermark.Visible = false end
            return 
        end
        for _,def in ipairs(defs) do
            local st=get_state(def.id)
            if st.key~="" and st.key==input.KeyCode.Name then
                st.enabled=not st.enabled
                local ref=row_refs[def.id]
                if ref then set_toggle_visual(ref,st.enabled) end
                notify(def.name..(st.enabled and " on" or " off"),st.enabled and accent() or C.text_dim)
                schedule_save()
                return
            end
        end
    end))

    rebuild_content()

    function give_accessory(id)
        local ok,model=pcall(function() return InsertService:LoadAsset(id) end)
        if ok and model then local char=LocalPlayer.Character if char then local clone=model:Clone() clone.Parent=char model:Destroy() notify("spawned asset "..id,C.ok) end
        else notify("failed to load asset",C.danger) end
    end
    function spawn_primitive_accessory(name,color)
        local char=LocalPlayer.Character if not char then return end
        local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return end
        local p=Instance.new("Part") p.Name="larp_acc_"..name p.Size=Vector3.new(2,1,2) p.Color=color p.Material=Enum.Material.Neon p.CanCollide=false p.Massless=true
        local weld=Instance.new("WeldConstraint") weld.Part0=hrp weld.Part1=p weld.Parent=p
        p.CFrame=hrp.CFrame*CFrame.new(0,3,0) p.Parent=char
        notify("spawned "..name,C.ok)
    end
    function clear_spawned_accessories()
        local char=LocalPlayer.Character if not char then return end
        for _,v in ipairs(char:GetChildren()) do if string.find(v.Name,"larp_acc_") then v:Destroy() end end
        notify("cleared accessories",C.text_dim)
    end
end

termInput.FocusLost:Connect(function(enterPressed)
    if not enterPressed then return end
    local txt=string.lower(termInput.Text)
    if txt=="y" then 
        termGui:Destroy() 
        init_main_gui()
        if config.show_watermark then watermark.Visible = false end
    elseif txt=="n" then 
        termGui:Destroy() 
    else
        termInput.Text=""
        ffLine.Text='<font color="#FF6666">root@larpclient:~#</font> <font color="#FFAA88">fastfetch</font> <font color="#FF8888">(invalid - type y or n)</font>'
        task.delay(2,function() if ffLine.Parent then ffLine.Text='<font color="#FF6666">root@larpclient:~#</font> <font color="#FFAA88">fastfetch</font>' end end)
    end
end)
task.wait(0.1)
termInput:CaptureFocus()

-- ═══════════════════════════════════════════
-- SHARED STATE & RUNTIMES
-- ═══════════════════════════════════════════
local esp_folder=Instance.new("Folder") esp_folder.Name="larp_esp" esp_folder.Parent=workspace
local esp_cache={}
local last_esp=0
local function clear_esp() for _,o in pairs(esp_cache) do if o and o.Parent then o:Destroy() end end esp_cache={} end

local fly_conn,fly_objects
local function stop_fly() if fly_conn then fly_conn:Disconnect() fly_conn=nil end if fly_objects then for _,o in ipairs(fly_objects) do if o and o.Parent then o:Destroy() end end fly_objects=nil end end
local function start_fly()
    stop_fly()
    local char=LocalPlayer.Character local hrp=char and char:FindFirstChild("HumanoidRootPart") if not hrp then return end
    local bv=Instance.new("BodyVelocity") bv.Name="larp_fly_v" bv.MaxForce=Vector3.new(1e5,1e5,1e5) bv.Velocity=Vector3.zero bv.Parent=hrp
    local bg=Instance.new("BodyGyro") bg.Name="larp_fly_g" bg.MaxTorque=Vector3.new(1e5,1e5,1e5) bg.P=1e4 bg.Parent=hrp
    fly_objects={bv,bg}
    fly_conn=RunService.RenderStepped:Connect(function()
        local cam=workspace.CurrentCamera local dir=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir+=cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir-=cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir-=cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir+=cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir-=Vector3.yAxis end
        local speed=get_state("fly").value or 50
        if dir.Magnitude>0 then bv.Velocity=dir.Unit*speed else bv.Velocity=Vector3.zero end
        bg.CFrame=cam.CFrame
    end)
end

local fullbright_saved=nil
local function set_fullbright(on,brightness)
    if on then
        if not fullbright_saved then fullbright_saved={Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,FogEnd=Lighting.FogEnd} end
        Lighting.Ambient=Color3.fromRGB(180,180,180) Lighting.OutdoorAmbient=Color3.fromRGB(180,180,180) Lighting.Brightness=brightness or 3 Lighting.ClockTime=12 Lighting.FogEnd=100000
    elseif fullbright_saved then for k,v in pairs(fullbright_saved) do Lighting[k]=v end fullbright_saved=nil end
end

local hud=Instance.new("ScreenGui") hud.Name="LarpHUD" hud.ResetOnSpawn=false hud.IgnoreGuiInset=true hud.Parent=LocalPlayer:WaitForChild("PlayerGui")
local health_lbl=Instance.new("TextLabel") health_lbl.Size=UDim2.fromOffset(200,22) health_lbl.Position=UDim2.fromOffset(20,20) health_lbl.BackgroundTransparency=1 health_lbl.Font=Enum.Font.Code health_lbl.TextSize=14 health_lbl.TextColor3=C.text health_lbl.TextXAlignment=Enum.TextXAlignment.Left health_lbl.Text="" health_lbl.Visible=false health_lbl.Parent=hud
local fps_lbl=Instance.new("TextLabel") fps_lbl.Size=UDim2.fromOffset(200,22) fps_lbl.Position=UDim2.fromOffset(20,42) fps_lbl.BackgroundTransparency=1 fps_lbl.Font=Enum.Font.Code fps_lbl.TextSize=14 fps_lbl.TextColor3=accent() fps_lbl.TextXAlignment=Enum.TextXAlignment.Left fps_lbl.Text="" fps_lbl.Visible=false fps_lbl.Parent=hud
local fps_count,fps_timer=0,0

local infjump_conn
local function update_infinitejump(on)
    if on and not infjump_conn then infjump_conn=UserInputService.JumpRequest:Connect(function() local char=LocalPlayer.Character local hum=char and char:FindFirstChildOfClass("Humanoid") if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end)
    elseif not on and infjump_conn then infjump_conn:Disconnect() infjump_conn=nil end
end

pcall(function() LocalPlayer.Idled:Connect(function() if get_state("antiafk").enabled then VirtualUser:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame) task.wait(1) VirtualUser:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame) end end) end)

-- ═══════════════════════════════════════════
-- COMBAT HELPERS
-- ═══════════════════════════════════════════
local rmb_down=false
UserInputService.InputBegan:Connect(function(input,gpe) if input.UserInputType==Enum.UserInputType.MouseButton2 then rmb_down=true end end)
UserInputService.InputEnded:Connect(function(input,gpe) if input.UserInputType==Enum.UserInputType.MouseButton2 then rmb_down=false end end)

local ray_params=RaycastParams.new()
ray_params.FilterType=Enum.RaycastFilterType.Exclude

local function same_team(p)
    return p.Team~=nil and LocalPlayer.Team~=nil and p.Team==LocalPlayer.Team
end

local function get_aim_part(character,part_name)
    if not part_name then return character:FindFirstChild("HumanoidRootPart") end
    return character:FindFirstChild(part_name) or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

local function is_visible(origin,aim_part,target_char)
    ray_params.FilterDescendantsInstances={LocalPlayer.Character}
    local dir=aim_part.Position-origin
    local result=workspace:Raycast(origin,dir,ray_params)
    if not result then return true end
    return result.Instance:IsDescendantOf(target_char)
end

local function find_target(st,cfg_require_aim,cam)
    local char=LocalPlayer.Character
    local my_hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not my_hrp then return nil end
    if cfg_require_aim and not rmb_down then return nil end
    local origin=cam.CFrame.Position
    local center=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
    local best=nil
    local best_score=math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local skip=false
            if st.team_check and same_team(p) then skip=true end
            if not skip then
                local phum=p.Character:FindFirstChildOfClass("Humanoid")
                local phrp=p.Character:FindFirstChild("HumanoidRootPart")
                if phum and phum.Health>0 and phrp then
                    local aim_part=get_aim_part(p.Character,st.part)
                    if aim_part then
                        local dist=(aim_part.Position-my_hrp.Position).Magnitude
                        if dist <= (st.range or 500) then
                            local aim_pos=aim_part.Position
                            if st.prediction and st.prediction>0 then
                                local vel=aim_part.AssemblyLinearVelocity or Vector3.zero
                                aim_pos=aim_pos+vel*(st.prediction/1000)
                            end
                            local screen_pos,on_screen=cam:WorldToViewportPoint(aim_pos)
                            if on_screen then
                                local dist_px=(Vector2.new(screen_pos.X,screen_pos.Y)-center).Magnitude
                                if dist_px<=(st.fov or 250) then
                                    local visible=true
                                    if st.wall_check then visible=is_visible(origin,aim_part,p.Character) end
                                    if visible then
                                        local score
                                        if st.priority=="Lowest HP" then score=phum.Health
                                        elseif st.priority=="Crosshair" then score=dist_px
                                        else score=dist end
                                        if score<best_score then
                                            best={part=aim_part,player=p,dist=dist,screen_dist=dist_px,aim_pos=aim_pos}
                                            best_score=score
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ═══════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════
local larp_coins={}
local larp_light=nil
local noclip_parts={}
local noclip_prev=false
local speed_applied=false
local jp_applied=false
local last_fire=0
local last_esp_time=0
local last_hitbox_time=0

local function setup_coin_trail(coin,col,lifetime)
    local old=coin:FindFirstChild("larp_trail") if old then old:Destroy() end
    local a0=coin:FindFirstChild("larp_a0") or Instance.new("Attachment",coin)
    a0.Name="larp_a0" a0.Position=Vector3.new(0,1,0)
    local a1=coin:FindFirstChild("larp_a1") or Instance.new("Attachment",coin)
    a1.Name="larp_a1" a1.Position=Vector3.new(0,-1,0)
    local trail=Instance.new("Trail")
    trail.Name="larp_trail"
    trail.Attachment0=a0 trail.Attachment1=a1
    trail.Lifetime=lifetime or 15
    trail.MinLength=0.1
    trail.Color=ColorSequence.new(col)
    trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(1,1)})
    trail.Parent=coin
end

local function fire_tool()
    local char=LocalPlayer.Character if not char then return end
    local tool=char:FindFirstChildOfClass("Tool")
    if tool and tick()-last_fire>0.05 then
        pcall(function() tool:Activate() end)
        last_fire=tick()
    end
end

RunService.Heartbeat:Connect(function(dt)
    local char=LocalPlayer.Character if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid") local hrp=char:FindFirstChild("HumanoidRootPart") if not hum or not hrp then return end
    local cam=workspace.CurrentCamera if not cam then return end

    -- SPEED
    local st=get_state("speed")
    if st.enabled then hum.WalkSpeed=st.value or 34 speed_applied=true
    elseif speed_applied then hum.WalkSpeed=16 speed_applied=false end

    -- FLY
    st=get_state("fly")
    if st.enabled and not fly_conn then start_fly() elseif not st.enabled and fly_conn then stop_fly() end

    -- NOCLIP
    st=get_state("noclip")
    if st.enabled and not noclip_prev then
        for _,part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then table.insert(noclip_parts,part) part.CanCollide=false end
        end
        noclip_prev=true
    elseif not st.enabled and noclip_prev then
        for _,part in ipairs(noclip_parts) do if part and part.Parent then part.CanCollide=true end end
        noclip_parts={} noclip_prev=false
    end

    -- JUMP POWER
    st=get_state("jumppower")
    if st.enabled then hum.UseJumpPower=true hum.JumpPower=st.value or 50 jp_applied=true
    elseif jp_applied then if hum.UseJumpPower then hum.JumpPower=50 end jp_applied=false end

    update_infinitejump(get_state("infinitejump").enabled)

    -- FOV
    st=get_state("fov")
    if st.enabled then cam.FieldOfView=st.value or 70 end

    -- FULLBRIGHT
    st=get_state("fullbright")
    set_fullbright(st.enabled,st.value)

    -- ESP (throttled to 10Hz)
    st=get_state("esp")
    if st.enabled and tick()-last_esp_time>0.1 then
        last_esp_time=tick()
        local col=arrToColor(st.color or {255,40,40}) local maxd=st.maxdist or 1500
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local phrp=p.Character:FindFirstChild("HumanoidRootPart")
                if phrp then
                    local d=(phrp.Position-hrp.Position).Magnitude
                    if d<=maxd then
                        local ad=esp_cache[p]
                        if not ad or not ad.Parent then
                            ad=Instance.new("BoxHandleAdornment") ad.Name="larp_esp_box" ad.Adornee=phrp ad.AlwaysOnTop=true ad.ZIndex=10 ad.Size=Vector3.new(4,5,4) ad.Transparency=0.4 ad.Color3=col ad.Parent=esp_folder esp_cache[p]=ad
                        else ad.Adornee=phrp ad.Color3=col end
                    else local ad=esp_cache[p] if ad then ad:Destroy() esp_cache[p]=nil end end
                end
            end
        end
    elseif not st.enabled and next(esp_cache) then clear_esp() end

    -- HUDs
    st=get_state("healthhud") health_lbl.Visible=st.enabled if st.enabled then health_lbl.TextColor3=accent() health_lbl.Text=string.format("HP: %d / %d",math.floor(hum.Health),math.floor(hum.MaxHealth)) end
    st=get_state("fpshud") fps_lbl.Visible=st.enabled if st.enabled then fps_lbl.TextColor3=accent() fps_lbl.Text="FPS: "..fps_count end

    -- AIMBOT
    st=get_state("aimbot")
    if st.enabled then
        local require_aim=not st.toggle_mode
        local target=find_target(st,require_aim,cam)
        if target then
            local smooth=st.smooth or 6
            local goal=CFrame.new(cam.CFrame.Position,target.aim_pos)
            if smooth<=1 then cam.CFrame=goal
            else cam.CFrame=cam.CFrame:Lerp(goal,math.clamp(1/smooth,0,1)) end
            if st.auto_fire then fire_tool() end
        end
    end

    -- SNAP AIM (silent-ish)
    st=get_state("silentaim")
    if st.enabled then
        local target=find_target(st,true,cam)
        if target then
            cam.CFrame=CFrame.new(cam.CFrame.Position,target.aim_pos)
            if st.auto_fire then fire_tool() end
        end
    end

    -- TRIGGERBOT
    st=get_state("triggerbot")
    if st.enabled then
        local require_aim=st.require_aim~=false
        local target=find_target(st,require_aim,cam)
        if target and st.auto_shoot~=false then
            task.wait((st.delay or 50)/1000)
            fire_tool()
        end
    end

    -- FOV CIRCLE
    st=get_state("fov_circle")
    if st.enabled then
        fov_circle.Visible=true
        local aim_st=get_state("aimbot")
        local radius=aim_st.fov or 250
        fov_circle.Size=UDim2.fromOffset(radius*2,radius*2)
        fov_stroke.Color=arrToColor(st.color or {255,80,80})
        fov_stroke.Thickness=st.thickness or 2
        fov_stroke.Transparency=(st.transparency or 40)/100
    else fov_circle.Visible=false end

    -- CROSSHAIR
    st=get_state("crosshair")
    if st.enabled then
        ch_h.Visible=true ch_v.Visible=true
        local col=arrToColor(st.color or {255,255,255})
        local sz=st.size or 10 local th=st.thickness or 2 local tr=(st.transparency or 0)/100
        ch_h.BackgroundColor3=col ch_v.BackgroundColor3=col
        ch_h.BackgroundTransparency=tr ch_v.BackgroundTransparency=tr
        ch_h.Size=UDim2.fromOffset(sz,th) ch_v.Size=UDim2.fromOffset(th,sz)
    else ch_h.Visible=false ch_v.Visible=false end

    -- COIN AURA
    st=get_state("coinaura")
    local trail_st=get_state("cointrail")
    if st.enabled then
        local count=st.count or 5 local radius=st.radius or 6 local speed=st.speed or 10 local height=st.height or 3
        local col=arrToColor(st.color or {60,180,255})
        local trail_col=arrToColor(trail_st.color or {60,180,255})
        local time=tick()*speed
        while #larp_coins<count do
            local c=Instance.new("Part") c.Name="larp_coin" c.Shape=Enum.PartType.Cylinder c.Size=Vector3.new(0.2,2,2) c.Color=col c.Material=Enum.Material.Neon c.Anchored=true c.CanCollide=false c.Parent=workspace
            table.insert(larp_coins,c)
        end
        for i,c in ipairs(larp_coins) do
            if i<=count then
                c.Transparency=0 c.Color=col
                local angle=time+(i*math.pi*2/count)
                local offset=Vector3.new(math.cos(angle)*radius,height,math.sin(angle)*radius)
                local pos=hrp.Position+offset
                c.CFrame=CFrame.lookAt(pos,cam.CFrame.Position)*CFrame.Angles(math.pi/2,0,0)
                if trail_st.enabled then
                    if not c:FindFirstChild("larp_trail") then setup_coin_trail(c,trail_col,trail_st.lifetime) end
                    local tr=c:FindFirstChild("larp_trail")
                    if tr then tr.Lifetime=trail_st.lifetime or 15 tr.Color=ColorSequence.new(trail_col) end
                else local tr=c:FindFirstChild("larp_trail") if tr then tr:Destroy() end end
            else c.Transparency=1 end
        end
    else
        for _,c in ipairs(larp_coins) do c:Destroy() end
        larp_coins={}
    end

    -- GLOW
    st=get_state("glow")
    if st.enabled and not larp_light then
        larp_light=Instance.new("PointLight") larp_light.Color=accent() larp_light.Range=20 larp_light.Brightness=st.brightness or 3 larp_light.Parent=hrp
    elseif not st.enabled and larp_light then larp_light:Destroy() larp_light=nil end
    if larp_light then larp_light.Brightness=st.brightness or 3 larp_light.Color=accent() end
end)

-- FPS counter
RunService.Heartbeat:Connect(function(dt) fps_count+=1 fps_timer+=dt if fps_timer>=1 then fps_count=0 fps_timer=0 end end)

-- ═══════════════════════════════════════════
-- SLOW COMBAT LOOP (0.15s)
-- ═══════════════════════════════════════════
local function nearest_player(range)
    local char=LocalPlayer.Character local my_hrp=char and char:FindFirstChild("HumanoidRootPart") if not my_hrp then return nil end
    local best,best_d=nil,range
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local hrp=p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then local d=(hrp.Position-my_hrp.Position).Magnitude if d<best_d then best,best_d=p,d end end
        end
    end
    return best
end

task.spawn(function()
    while task.wait(0.15) do
        if get_state("autoarrest").enabled then
            local target=nearest_player(get_state("autoarrest").range or 12)
            if target then
                local char=LocalPlayer.Character
                if char then for _,tool in ipairs(char:GetChildren()) do if tool:IsA("Tool") and string.find(string.lower(tool.Name),"cuff") then pcall(function() tool:Activate() end) break end end end
            end
        end
        if get_state("autopocket").enabled then
            local target=nearest_player(get_state("autopocket").range or 10)
            if target then
                local char=LocalPlayer.Character
                if char then for _,tool in ipairs(char:GetChildren()) do if tool:IsA("Tool") and (string.find(string.lower(tool.Name),"pick") or string.find(string.lower(tool.Name),"steal")) then pcall(function() tool:Activate() end) break end end end
            end
        end
        if get_state("autoclicker").enabled then
            VirtualUser:ClickButton1(UserInputService:GetMouseLocation())
            task.wait(1/(get_state("autoclicker").cps or 15))
        end
        -- MELEE AURA
        local st=get_state("melee_aura")
        if st.enabled then
            local char=LocalPlayer.Character
            local my_hrp=char and char:FindFirstChild("HumanoidRootPart")
            local tool=char and char:FindFirstChildOfClass("Tool")
            if my_hrp and tool then
                local range=st.range or 15
                for _,p in ipairs(Players:GetPlayers()) do
                    if p~=LocalPlayer and p.Character then
                        if not (st.team_check and same_team(p)) then
                            local phrp=p.Character:FindFirstChild("HumanoidRootPart")
                            if phrp and (phrp.Position-my_hrp.Position).Magnitude<=range then
                                pcall(function() tool:Activate() end)
                                break
                            end
                        end
                    end
                end
            end
        end
        -- HITBOX (throttled 5Hz by outer loop)
        local hb=get_state("hitbox")
        if hb.enabled then
            local size=hb.size or 6
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character then
                    if not (hb.team_check and same_team(p)) then
                        local phrp=p.Character:FindFirstChild("HumanoidRootPart")
                        if phrp then phrp.Size=Vector3.new(4+size,5+size,4+size) phrp.Transparency=0.5 end
                    end
                end
            end
        else
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character then
                    local phrp=p.Character:FindFirstChild("HumanoidRootPart")
                    if phrp and phrp.Size~=Vector3.new(4,5,4) then phrp.Size=Vector3.new(4,5,4) phrp.Transparency=0 end
                end
            end
        end
    end
end)

LocalPlayer.CharacterRemoving:Connect(function() stop_fly() clear_esp() for _, c in ipairs(larp_coins) do c:Destroy() end larp_coins = {} if larp_light then larp_light:Destroy() larp_light = nil end end)
