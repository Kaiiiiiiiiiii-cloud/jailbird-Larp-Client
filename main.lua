-- larp_client.lua · v1.7
-- combat overhaul · connection fix · optimized loops · enhanced UI

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
    transparency=0, animations=true, modules={}
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
OS: Larp Client 1.7.0 x86_64
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
-- CONNECTION TRACKING (fixes stacking on theme change)
-- ═══════════════════════════════════════════
local main_conns = {}
local function track(c) table.insert(main_conns, c); return c end
local function untrack_all()
    for _, c in ipairs(main_conns) do pcall(function() c:Disconnect() end) end
    main_conns = {}
end

-- ═══════════════════════════════════════════
-- OVERLAY (FOV circle + crosshair)
-- ═══════════════════════════════════════════
local overlay = Instance.new("ScreenGui") overlay.Name="LarpOverlay" overlay.ResetOnSpawn=false overlay.IgnoreGuiInset=true overlay.Parent=LocalPlayer:WaitForChild("PlayerGui")

local fov_circle = Instance.new("Frame")
fov_circle.AnchorPoint=Vector2.new(0.5,0.5)
fov_circle.Position=UDim2.fromScale(0.5,0.5)
fov_circle.Size=UDim2.fromOffset(2,2)
fov_circle.BackgroundTransparency=1
fov_circle.BorderSizePixel=0
fov_circle.Visible=false
local fov_corner=Instance.new("UICorner") fov_corner.CornerRadius=UDim.new(0.5,0) fov_corner.Parent=fov_circle
local fov_stroke=Instance.new("UIStroke") fov_stroke.Color=Color3.fromRGB(255,80,80) fov_stroke.Thickness=2 fov_stroke.Transparency=0.4 fov_stroke.Parent=fov_circle
fov_circle.Parent=overlay

local ch_h=Instance.new("Frame") ch_h.AnchorPoint=Vector2.new(0.5,0.5) ch_h.Position=UDim2.fromScale(0.5,0.5) ch_h.Size=UDim2.fromOffset(10,2) ch_h.BackgroundColor3=Color3.new(1,1,1) ch_h.BorderSizePixel=0 ch_h.Visible=false ch_h.Parent=overlay
local ch_v=Instance.new("Frame") ch_v.AnchorPoint=Vector2.new(0.5,0.5) ch_v.Position=UDim2.fromScale(0.5,0.5) ch_v.Size=UDim2.fromOffset(2,10) ch_v.BackgroundColor3=Color3.new(1,1,1) ch_v.BorderSizePixel=0 ch_v.Visible=false ch_v.Parent=overlay

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

    local uiScale=Instance.new("UIScale") uiScale.Scale=config.ui_scale uiScale.Parent=main
    local baseFont = config.font_size or 12

    local titlebar=Instance.new("Frame") titlebar.Size=UDim2.new(1,0,0,34) titlebar.BackgroundColor3=C.panel titlebar.BorderSizePixel=0 titlebar.Parent=main
    local tbc=Instance.new("UICorner") tbc.CornerRadius=UDim.new(0,config.corner_radius or 6) tbc.Parent=titlebar
    local tbm=Instance.new("Frame") tbm.Size=UDim2.new(1,0,0,17) tbm.Position=UDim2.new(0,0,1,-17) tbm.BackgroundColor3=C.panel tbm.BorderSizePixel=0 tbm.Parent=titlebar

    local logo=Instance.new("Frame") logo.Size=UDim2.fromOffset(8,8) logo.Position=UDim2.fromOffset(12,13) logo.BackgroundColor3=accent() logo.BorderSizePixel=0 logo.Parent=titlebar
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

    local ver=Instance.new("TextLabel") ver.BackgroundTransparency=1 ver.Position=UDim2.new(1,-160,0,0) ver.Size=UDim2.fromOffset(80,34) ver.Font=Enum.Font.Code ver.TextSize=baseFont-1 ver.TextColor3=C.text_dim ver.TextXAlignment=Enum.TextXAlignment.Right ver.Text="v1.7" ver.Parent=titlebar

    local closeBtn=Instance.new("TextButton") closeBtn.Size=UDim2.fromOffset(22,22) closeBtn.Position=UDim2.new(1,-32,0,6) closeBtn.BackgroundColor3=C.panel2 closeBtn.BorderSizePixel=0 closeBtn.Font=Enum.Font.Code closeBtn.TextSize=baseFont+2 closeBtn.TextColor3=C.text_dim closeBtn.Text="x" closeBtn.AutoButtonColor=false closeBtn.Parent=titlebar
    local cbc=Instance.new("UICorner") cbc.CornerRadius=UDim.new(0,4) cbc.Parent=closeBtn
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.12),{BackgroundColor3=C.danger,TextColor3=Color3.new(1,1,1)}):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.12),{BackgroundColor3=C.panel2,TextColor3=C.text_dim}):Play() end)
    closeBtn.MouseButton1Click:Connect(function() mainGui.Enabled=false end)

    local sidebar=Instance.new("Frame") sidebar.Size=UDim2.new(0,130,1,-60) sidebar.Position=UDim2.new(0,0,0,34) sidebar.BackgroundColor3=C.panel sidebar.BorderSizePixel=0 sidebar.Parent=main
    local sbs=Instance.new("UIStroke") sbs.Color=C.stroke sbs.Thickness=1 sbs.Parent=sidebar

    local tabs={"Combat","Movement","Render","Larping","Player","Settings"}
    local active_tab="Combat"
    local tab_refs={}

    local tlist=Instance.new("UIListLayout") tlist.SortOrder=Enum.SortOrder.LayoutOrder tlist.Padding=UDim.new(0,2) tlist.Parent=sidebar
    local tpad=Instance.new("UIPadding") tpad.PaddingTop=UDim.new(0,8) tpad.PaddingLeft=UDim.new(0,8) tpad.PaddingRight=UDim.new(0,8) tpad.Parent=sidebar

    for i,name in ipairs(tabs) do
        local btn=Instance.new("TextButton") btn.Size=UDim2.new(1,0,0,30) btn.BackgroundColor3=(name==active_tab) and C.panel2 or C.panel btn.BorderSizePixel=0 btn.Font=Enum.Font.Code btn.TextSize=baseFont btn.TextColor3=(name==active_tab) and accent() or C.text_dim btn.TextXAlignment=Enum.TextXAlignment.Left btn.Text="  "..name btn.AutoButtonColor=false btn.LayoutOrder=i btn.Parent=sidebar
        local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(0,4) bc.Parent=btn
        local bar=Instance.new("Frame") bar.Size=UDim2.new(0,2,1,-10) bar.Position=UDim2.new(0,0,0,5) bar.BackgroundColor3=accent() bar.BorderSizePixel=0 bar.Visible=(name==active_tab) bar.Parent=btn
        tab_refs[name]={btn=btn,bar=bar}
        btn.MouseEnter:Connect(function() if active_tab~=name then TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=C.panel2,TextColor3=C.text}):Play() end end)
        btn.MouseLeave:Connect(function() if active_tab~=name then TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=C.panel,TextColor3=C.text_dim}):Play() end end)
    end

    local content=Instance.new("Frame") content.Size=UDim2.new(1,-130,1,-60) content.Position=UDim2.new(0,130,0,34) content.BackgroundColor3=C.bg content.BackgroundTransparency=config.transparency or 0 content.BorderSizePixel=0 content.Parent=main

    local search_wrap=Instance.new("Frame") search_wrap.Size=UDim2.new(1,-16,0,30) search_wrap.Position=UDim2.fromOffset(8,8) search_wrap.BackgroundColor3=C.panel search_wrap.BorderSizePixel=0 search_wrap.Parent=content
    local swc=Instance.new("UICorner") swc.CornerRadius=UDim.new(0,4) swc.Parent=search_wrap
    local sws=Instance.new("UIStroke") sws.Color=C.stroke sws.Thickness=1 sws.Parent=search_wrap
    local search_icon=Instance.new("TextLabel") search_icon.BackgroundTransparency=1 search_icon.Position=UDim2.fromOffset(8,0) search_icon.Size=UDim2.fromOffset(20,30) search_icon.Font=Enum.Font.Code search_icon.TextSize=baseFont+1 search_icon.TextColor3=C.text_dim search_icon.Text="/" search_icon.Parent=search_wrap

    local search_box=Instance.new("TextBox") search_box.BackgroundTransparency=1 search_box.Position=UDim2.fromOffset(28,0) search_box.Size=UDim2.new(1,-36,1,0) search_box.Font=Enum.Font.Code search_box.TextSize=baseFont search_box.TextColor3=C.text search_box.TextXAlignment=Enum.TextXAlignment.Left search_box.PlaceholderText="search modules..." search_box.PlaceholderColor3=C.text_dim search_box.Text="" search_box.ClearTextOnFocus=false search_box.Parent=search_wrap

    local scroll=Instance.new("ScrollingFrame") scroll.Size=UDim2.new(1,-16,1,-46) scroll.Position=UDim2.fromOffset(8,44) scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.ScrollBarThickness=3 scroll.ScrollBarImageColor3=accent() scroll.CanvasSize=UDim2.new(0,0,0,0) scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y scroll.Parent=content
    local sl=Instance.new("UIListLayout") sl.Padding=UDim.new(0,6) sl.SortOrder=Enum.SortOrder.LayoutOrder sl.Parent=scroll

    local statusbar=Instance.new("Frame") statusbar.Size=UDim2.new(1,0,0,26) statusbar.Position=UDim2.new(0,0,1,-26) statusbar.BackgroundColor3=C.panel statusbar.BorderSizePixel=0 statusbar.Parent=main
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
        local
