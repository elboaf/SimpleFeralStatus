-- SimpleFeralStatus for Turtle WoW
-- Energy/Rage bar and combo point indicators for Feral Druids

-- ==================== Configuration Variables ====================
local BAR_WIDTH = 120
local BAR_HEIGHT = 6
local MANA_BAR_OFFSET = 0

local COMBO_POINTS_COUNT = 5
local COMBO_WIDTH = BAR_WIDTH / COMBO_POINTS_COUNT
local COMBO_HEIGHT = BAR_HEIGHT

-- ==================== State Variables ====================
local BAR_SCALE        = 1.0
local hideOutOfCombat  = false
local stealthMode      = false   -- Show HUD in stealth; spark always visible in stealth
local inCombat         = false
local inStealth        = false

-- ==================== Energy Tick Variables ====================
local ENERGY_TICK_LENGTH = 2.0
local ENERGY_PER_TICK    = 20
local energyTimerStart   = 0
local energyTimerEnd     = 0
local lastEnergy         = nil
local sparkVisible       = false

-- ==================== SavedVariables ====================
function SaveSettings()
    SimpleFeralStatusDB = SimpleFeralStatusDB or {}
    SimpleFeralStatusDB.scale            = BAR_SCALE
    SimpleFeralStatusDB.hideOutOfCombat  = hideOutOfCombat
    SimpleFeralStatusDB.stealthMode      = stealthMode
end

function LoadSettings()
    if SimpleFeralStatusDB then
        hideOutOfCombat = SimpleFeralStatusDB.hideOutOfCombat or false
        stealthMode     = SimpleFeralStatusDB.stealthMode     or false
        local savedScale = SimpleFeralStatusDB.scale or 1.0
        ApplyScale(savedScale)
    end
end

-- ==================== Main Energy/Rage Bar ====================
local mainBar = CreateFrame("Frame", "FeralMainBar", UIParent)
mainBar:SetWidth(BAR_WIDTH)
mainBar:SetHeight(BAR_HEIGHT)
mainBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "", tile = true, tileSize = 16, edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
mainBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
mainBar:SetMovable(true)
mainBar:EnableMouse(true)
mainBar:RegisterForDrag("LeftButton")
mainBar:SetClampedToScreen(true)

local formBar = CreateFrame("StatusBar", "FeralFormBar", mainBar)
formBar:SetWidth(BAR_WIDTH)
formBar:SetHeight(BAR_HEIGHT)
formBar:SetPoint("CENTER", mainBar, "CENTER", 0, 0)
formBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
formBar:SetStatusBarColor(1, 0.82, 0, 0.9)
formBar:SetMinMaxValues(0, 100)
formBar:SetValue(0)

-- ==================== Mana Bar ====================
local manaBarFrame = CreateFrame("Frame", "FeralManaBarFrame", UIParent)
manaBarFrame:SetWidth(BAR_WIDTH)
manaBarFrame:SetHeight(BAR_HEIGHT)
manaBarFrame:SetPoint("TOP", mainBar, "BOTTOM", 0, MANA_BAR_OFFSET)
manaBarFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "", tile = true, tileSize = 16, edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
manaBarFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
manaBarFrame:SetMovable(false)
manaBarFrame:EnableMouse(false)
manaBarFrame:SetClampedToScreen(true)

local manaBar = CreateFrame("StatusBar", "FeralManaBar", manaBarFrame)
manaBar:SetWidth(BAR_WIDTH)
manaBar:SetHeight(BAR_HEIGHT)
manaBar:SetPoint("CENTER", manaBarFrame, "CENTER", 0, 0)
manaBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
manaBar:SetStatusBarColor(0.1, 0.5, 0.9, 0.9)
manaBar:SetMinMaxValues(0, 100)
manaBar:SetValue(0)

-- ==================== Energy Tick Spark ====================
local sparkFrame = CreateFrame("Frame", "FeralSparkFrame", mainBar)
sparkFrame:SetWidth(2)
sparkFrame:SetHeight(BAR_HEIGHT + 4)
sparkFrame:SetPoint("CENTER", mainBar, "LEFT", 0, 0)

local sparkTexture = sparkFrame:CreateTexture("FeralSparkTexture", "OVERLAY")
sparkTexture:SetAllPoints(sparkFrame)
sparkTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
sparkTexture:SetVertexColor(1, 1, 1, 0.9)
sparkFrame.texture = sparkTexture
sparkFrame:Hide()
sparkFrame:SetMovable(false)
sparkFrame:EnableMouse(false)
sparkFrame:SetClampedToScreen(true)

-- ==================== Combo Point Indicators ====================
local comboFrames = {}
local comboPoints = 0

for i = 1, COMBO_POINTS_COUNT do
    local cf = CreateFrame("Frame", "FeralComboFrame"..i, UIParent)
    cf:SetWidth(COMBO_WIDTH)
    cf:SetHeight(COMBO_HEIGHT)
    local xOff = ((i-1) * COMBO_WIDTH) - (BAR_WIDTH/2) + (COMBO_WIDTH/2)
    cf:SetPoint("BOTTOM", mainBar, "TOP", xOff, 0)
    cf:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "", tile = true, tileSize = 16, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    cf:SetBackdropColor(0.3, 0.3, 0.3, 0.7)
    cf:SetMovable(false)
    cf:EnableMouse(false)
    cf:SetClampedToScreen(true)
    comboFrames[i] = cf
end

-- ==================== Lock State ====================
local framesLocked = true

-- ==================== Scale / Resize ====================
function ApplyScale(scale)
    BAR_SCALE = scale

    local sw  = BAR_WIDTH  * scale
    local sh  = BAR_HEIGHT * scale
    local scw = sw / COMBO_POINTS_COUNT

    mainBar:SetWidth(sw)      ; mainBar:SetHeight(sh)
    formBar:SetWidth(sw)      ; formBar:SetHeight(sh)
    manaBarFrame:SetWidth(sw) ; manaBarFrame:SetHeight(sh)
    manaBar:SetWidth(sw)      ; manaBar:SetHeight(sh)
    sparkFrame:SetWidth(2)    ; sparkFrame:SetHeight(sh + 4)

    for i = 1, COMBO_POINTS_COUNT do
        comboFrames[i]:SetWidth(scw)
        comboFrames[i]:SetHeight(sh)
    end

    UpdateAllPositions()
end

-- ==================== Visibility Logic ====================
function ShouldShowHUD()
    -- Stealth mode overrides hideOutOfCombat
    if stealthMode and inStealth then return true end
    if hideOutOfCombat and not inCombat then return false end
    return true
end

function HideAllFrames()
    mainBar:Hide()
    manaBarFrame:Hide()
    sparkFrame:Hide()
    for i = 1, COMBO_POINTS_COUNT do comboFrames[i]:Hide() end
end

function UpdateVisibility()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then HideAllFrames() ; return end
    if ShouldShowHUD() then
        UpdateAllIndicators()
    else
        HideAllFrames()
    end
end

-- ==================== Lock / Unlock ====================
function ToggleFramesLock(lock)
    framesLocked = lock
    mainBar:EnableMouse(not lock)
    if lock then
        print("SimpleFeralStatus: frames locked")
    else
        print("SimpleFeralStatus: unlocked — drag the energy/rage bar to move")
    end
end

-- ==================== Drag ====================
mainBar:SetScript("OnDragStart", function()
    if not framesLocked then mainBar:StartMoving() end
end)
mainBar:SetScript("OnDragStop", function()
    if not framesLocked then
        mainBar:StopMovingOrSizing()
        UpdateAllPositions()
    end
end)

-- ==================== Position Helpers ====================
function UpdateAllPositions()
    manaBarFrame:ClearAllPoints()
    manaBarFrame:SetPoint("TOP", mainBar, "BOTTOM", 0, MANA_BAR_OFFSET)
    sparkFrame:ClearAllPoints()
    sparkFrame:SetPoint("CENTER", mainBar, "LEFT", 0, 0)
    UpdateComboPositions()
end

function UpdateComboPositions()
    local sw  = BAR_WIDTH * BAR_SCALE
    local scw = sw / COMBO_POINTS_COUNT
    for i = 1, COMBO_POINTS_COUNT do
        local xOff = ((i-1) * scw) - (sw/2) + (scw/2)
        comboFrames[i]:ClearAllPoints()
        comboFrames[i]:SetPoint("BOTTOM", mainBar, "TOP", xOff, 0)
    end
end

-- ==================== Energy Tick ====================
function UpdateEnergyTick()
    local form = GetCurrentForm()
    if form ~= "CAT" then
        sparkFrame:Hide()
        sparkVisible     = false
        lastEnergy       = nil
        energyTimerStart = 0
        energyTimerEnd   = 0
        return
    end

    local formResource = UnitMana("player")
    local currentTime  = GetTime()

    -- Initialise timer on first run
    if lastEnergy == nil then
        lastEnergy       = formResource
        energyTimerStart = currentTime
        energyTimerEnd   = currentTime + ENERGY_TICK_LENGTH
    end

    if currentTime >= energyTimerEnd then
        -- Natural tick window elapsed — reset
        energyTimerStart = currentTime
        energyTimerEnd   = currentTime + ENERGY_TICK_LENGTH
        sparkVisible     = true
        lastEnergy       = formResource
        sparkFrame:SetPoint("CENTER", mainBar, "LEFT", 0, 0)
    elseif formResource > lastEnergy then
        local gain = formResource - lastEnergy
        if math.abs(gain - ENERGY_PER_TICK) <= 1 then
            -- Confirmed natural tick — reset timer
            energyTimerStart = currentTime
            energyTimerEnd   = currentTime + ENERGY_TICK_LENGTH
            sparkVisible     = true
            sparkFrame:SetPoint("CENTER", mainBar, "LEFT", 0, 0)
        end
        lastEnergy = formResource
    elseif formResource < lastEnergy then
        lastEnergy = formResource
    end

    -- In stealth mode: always show spark even at 100 energy so the player
    -- can time their opener off the tick.
    -- Outside stealth: hide at full energy (original behaviour).
    local atFullEnergy = (formResource >= 100)
    if atFullEnergy and not (stealthMode and inStealth) then
        sparkFrame:Hide()
        sparkVisible = false
        return
    end

    if sparkVisible then
        local timeSinceTick = currentTime - energyTimerStart
        if (ENERGY_TICK_LENGTH - timeSinceTick) > 0 then
            local progress = math.min(math.max(timeSinceTick / ENERGY_TICK_LENGTH, 0), 1)
            local sw       = BAR_WIDTH * BAR_SCALE
            -- SetPoint without ClearAllPoints for smooth movement —
            -- clearing anchors every frame causes a recalculation stutter
            sparkFrame:SetPoint("CENTER", mainBar, "LEFT", progress * sw, 0)
            sparkFrame:Show()
        else
            sparkFrame:Hide()
            sparkVisible = false
        end
    else
        sparkFrame:Hide()
    end
end

-- ==================== Form Detection ====================
function GetCurrentForm()
    for i = 1, 3 do
        local _, name, isActive = GetShapeshiftFormInfo(i)
        if isActive then
            if i == 1 then return "BEAR" end
            if i == 2 then return "AQUATIC" end
            if i == 3 then return "CAT" end
        end
    end
    for i = 4, 5 do
        local _, name, isActive = GetShapeshiftFormInfo(i)
        if isActive then
            if string.find(name or "", "Travel")  then return "TRAVEL"  end
            if string.find(name or "", "Moonkin") then return "MOONKIN" end
        end
    end
    return "NONE"
end

function GetFormResource()
    local form = GetCurrentForm()
    local formResource = UnitMana("player")
    if form == "CAT"  then return "ENERGY", formResource, 100 end
    if form == "BEAR" then return "RAGE",   formResource, 100 end
    local formMax = UnitManaMax("player") or 100
    return "MANA", formResource, formMax
end

function GetCasterMana()
    local _, casterMana = UnitMana("player")
    local _, casterMax  = UnitManaMax("player")
    return casterMana or 0, casterMax or 100
end

-- ==================== Bar Updates ====================
function UpdateFormBar()
    local resourceType, current, max = GetFormResource()
    formBar:SetMinMaxValues(0, max)
    formBar:SetValue(current)
    if resourceType == "ENERGY" then
        formBar:SetStatusBarColor(1, 0.82, 0, 0.9)
    elseif resourceType == "RAGE" then
        formBar:SetStatusBarColor(0.9, 0.1, 0.1, 0.9)
    else
        formBar:SetStatusBarColor(0.1, 0.5, 0.9, 0.9)
    end
    mainBar:Show()
end

function UpdateManaBar()
    local form = GetCurrentForm()
    if form == "NONE" or form == "MOONKIN" or form == "TRAVEL" or form == "AQUATIC" then
        manaBarFrame:Hide() ; return
    end
    local cur, max = GetCasterMana()
    manaBar:SetMinMaxValues(0, max)
    manaBar:SetValue(cur)
    manaBarFrame:Show()
end

function UpdateComboPoints()
    local form = GetCurrentForm()
    if form == "CAT" then
        comboPoints = GetComboPoints()
        for i = 1, COMBO_POINTS_COUNT do
            if i <= comboPoints then
                comboFrames[i]:SetBackdropColor(0.9, 0.1, 0.1, 1.0)
            else
                comboFrames[i]:SetBackdropColor(0.3, 0.3, 0.3, 0.7)
            end
            comboFrames[i]:Show()
        end
    else
        for i = 1, COMBO_POINTS_COUNT do comboFrames[i]:Hide() end
    end
end

function UpdateAllIndicators()
    UpdateFormBar()
    UpdateManaBar()
    UpdateComboPoints()
    UpdateEnergyTick()
end

-- ==================== Stealth Detection Helper ====================
function CheckStealth()
    -- Prowl uses "Ability_Ambush" icon on Turtle WoW / 1.12 clients
    for i = 1, 40 do
        local tex = GetPlayerBuffTexture(i)
        if not tex then break end
        if string.find(tex, "Ability_Ambush") then
            return true
        end
    end
    return false
end

-- ==================== Event Handling ====================
local function OnEvent()
    if event == "VARIABLES_LOADED" then
        LoadSettings()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        UpdateVisibility()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        UpdateVisibility()
        return
    end

    if event == "PLAYER_AURAS_CHANGED" then
        local wasStealthed = inStealth
        inStealth = CheckStealth()
        if wasStealthed ~= inStealth then
            UpdateVisibility()
            return   -- UpdateVisibility already calls UpdateAllIndicators if needed
        end
    end

    if event == "PLAYER_ENTERING_WORLD" or
       event == "PLAYER_LOGIN"          or
       event == "UNIT_ENERGY"           or
       event == "UNIT_RAGE"             or
       event == "UNIT_MANA"             or
       event == "UNIT_MAXENERGY"        or
       event == "UNIT_MAXRAGE"          or
       event == "UNIT_MAXMANA"          or
       event == "PLAYER_COMBO_POINTS"   or
       event == "PLAYER_AURAS_CHANGED"  or
       event == "UPDATE_SHAPESHIFT_FORMS"    or
       event == "UPDATE_SHAPESHIFT_USABLE"   or
       event == "UPDATE_SHAPESHIFT_COOLDOWN" or
       event == "SPELL_UPDATE_COOLDOWN" then

        local _, class = UnitClass("player")
        if class == "DRUID" then
            if ShouldShowHUD() then
                UpdateAllIndicators()
            else
                HideAllFrames()
            end
        else
            HideAllFrames()
        end
    end
end

-- ==================== Event Registration ====================
-- Register all events on mainBar only — one event handler is enough
local events = {
    "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN",
    "UNIT_ENERGY", "UNIT_RAGE", "UNIT_MANA",
    "UNIT_MAXENERGY", "UNIT_MAXRAGE", "UNIT_MAXMANA",
    "PLAYER_COMBO_POINTS", "PLAYER_AURAS_CHANGED",
    "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_USABLE",
    "UPDATE_SHAPESHIFT_COOLDOWN", "SPELL_UPDATE_COOLDOWN",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "VARIABLES_LOADED",
}
for _, ev in pairs(events) do
    mainBar:RegisterEvent(ev)
end
mainBar:SetScript("OnEvent", OnEvent)

-- ==================== Update Loop ====================
local updateCounter = 0
mainBar:SetScript("OnUpdate", function()
    updateCounter = updateCounter + arg1
    if updateCounter > 0.05 then
        updateCounter = 0
        local _, class = UnitClass("player")
        if class == "DRUID" and ShouldShowHUD() then
            UpdateAllIndicators()
        end
    end
end)

-- ==================== Settings GUI ====================
local settingsFrame = CreateFrame("Frame", "SFSSettingsFrame", UIParent)
settingsFrame:SetWidth(230)
settingsFrame:SetHeight(210)
settingsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
settingsFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", function() settingsFrame:StartMoving() end)
settingsFrame:SetScript("OnDragStop",  function() settingsFrame:StopMovingOrSizing() end)
settingsFrame:Hide()

-- Title
local guiTitle = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
guiTitle:SetPoint("TOP", settingsFrame, "TOP", 0, -16)
guiTitle:SetText("SimpleFeralStatus")

-- Close button
local closeBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() settingsFrame:Hide() end)

-- Checkbox helper
local function MakeCheckbox(parent, label, yOff, getVal, setVal)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOff)
    cb:SetWidth(24) ; cb:SetHeight(24)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    lbl:SetText(label)
    cb:SetChecked(getVal())
    cb:SetScript("OnClick", function()
        setVal(cb:GetChecked() == 1)
        SaveSettings()
        UpdateVisibility()
    end)
    cb.Sync = function() cb:SetChecked(getVal()) end
    return cb
end

local cbCombat = MakeCheckbox(settingsFrame, "Hide when out of combat", -48,
    function() return hideOutOfCombat end,
    function(v) hideOutOfCombat = v   end)

local cbStealth = MakeCheckbox(settingsFrame, "Show in stealth (spark at 100 energy)", -76,
    function() return stealthMode end,
    function(v) stealthMode = v   end)

-- Scale label + slider
local scaleLbl = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
scaleLbl:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 16, -108)
scaleLbl:SetText("Scale: 1.0x")

local slider = CreateFrame("Slider", "SFSScaleSlider", settingsFrame, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -128)
slider:SetWidth(190)
slider:SetMinMaxValues(0.5, 3.0)
slider:SetValueStep(0.1)
slider:SetValue(BAR_SCALE)
getglobal(slider:GetName().."Low"):SetText("0.5")
getglobal(slider:GetName().."High"):SetText("3.0")
getglobal(slider:GetName().."Text"):SetText("")
slider:SetScript("OnValueChanged", function()
    local v = math.floor(slider:GetValue() * 10 + 0.5) / 10
    scaleLbl:SetText(string.format("Scale: %.1fx", v))
    ApplyScale(v)
    SaveSettings()
end)

-- Reset position button
local resetBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
resetBtn:SetPoint("BOTTOM", settingsFrame, "BOTTOM", 0, 14)
resetBtn:SetWidth(150) ; resetBtn:SetHeight(22)
resetBtn:SetText("Reset Position")
resetBtn:SetScript("OnClick", function()
    mainBar:ClearAllPoints()
    mainBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    UpdateAllPositions()
end)

-- Sync all controls when the GUI opens
settingsFrame:SetScript("OnShow", function()
    cbCombat.Sync()
    cbStealth.Sync()
    slider:SetValue(BAR_SCALE)
    scaleLbl:SetText(string.format("Scale: %.1fx", BAR_SCALE))
end)

-- ==================== Slash Commands ====================
SLASH_SIMPLEFERAL1 = "/sfs"
SLASH_SIMPLEFERAL2 = "/simpleferal"

SlashCmdList["SIMPLEFERAL"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "" or msg == "config" or msg == "gui" then
        if settingsFrame:IsVisible() then
            settingsFrame:Hide()
        else
            settingsFrame:Show()
        end

    elseif msg == "reset" then
        mainBar:ClearAllPoints()
        mainBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        UpdateAllPositions()
        print("SimpleFeralStatus: position reset")

    elseif msg == "lock" then
        ToggleFramesLock(true)

    elseif msg == "unlock" then
        ToggleFramesLock(false)

    elseif msg == "spark" then
        if sparkFrame:IsVisible() then
            sparkFrame:Hide()
            print("SimpleFeralStatus: spark hidden")
        else
            sparkFrame:Show()
            print("SimpleFeralStatus: spark shown")
        end

    elseif msg == "combat" then
        hideOutOfCombat = not hideOutOfCombat
        print("SimpleFeralStatus: hide out of combat = " .. tostring(hideOutOfCombat))
        SaveSettings()
        UpdateVisibility()

    elseif msg == "stealth" then
        stealthMode = not stealthMode
        print("SimpleFeralStatus: stealth mode = " .. tostring(stealthMode))
        SaveSettings()
        UpdateVisibility()

    elseif string.sub(msg, 1, 5) == "scale" then
        local v = tonumber(string.sub(msg, 7))
        if v and v >= 0.1 and v <= 5.0 then
            ApplyScale(v)
            SaveSettings()
        else
            print("Usage: /sfs scale <0.1-5.0>  e.g. /sfs scale 1.5")
            print("Current scale: " .. BAR_SCALE .. "x")
        end

    elseif msg == "debug" then
        local _, class = UnitClass("player")
        local form = GetCurrentForm()
        local formResource, casterMana = UnitMana("player")
        local formMax, casterMax = UnitManaMax("player")
        print("=== SimpleFeralStatus Debug ===")
        print("Class:", class, "| Form:", form)
        print("UnitMana:", formResource, casterMana)
        print("UnitManaMax:", formMax, casterMax)
        print("Combo Points:", GetComboPoints())
        print("Scale:", BAR_SCALE .. "x")
        print("Hide OOC:", tostring(hideOutOfCombat), "| In Combat:", tostring(inCombat))
        print("Stealth Mode:", tostring(stealthMode), "| In Stealth:", tostring(inStealth))
        if form == "CAT" then
            local t = GetTime()
            print("Tick timer:", string.format("%.2f / %.2f", energyTimerStart, energyTimerEnd))
            print("Time to next tick:", string.format("%.2fs", math.max(0, energyTimerEnd - t)))
            print("Last energy:", lastEnergy, "| Current:", formResource)
        end

    else
        print("SimpleFeralStatus  /sfs <command>")
        print("  (no args)  — Open/close settings GUI")
        print("  reset      — Reset position to center screen")
        print("  lock       — Lock HUD position")
        print("  unlock     — Unlock HUD for dragging")
        print("  spark      — Toggle energy tick spark")
        print("  combat     — Toggle hide when out of combat")
        print("  stealth    — Toggle stealth mode")
        print("  scale <n>  — Resize HUD  e.g. /sfs scale 2.0")
        print("  debug      — Print debug info")
        print("Scale: " .. BAR_SCALE .. "x  |  hide OOC: " .. tostring(hideOutOfCombat) .. "  |  stealth mode: " .. tostring(stealthMode))
    end
end

-- ==================== Initial Setup ====================
local _, class = UnitClass("player")
if class == "DRUID" then
    mainBar:Show()
    manaBarFrame:Show()
    UpdateAllIndicators()
    UpdateAllPositions()
else
    HideAllFrames()
end
