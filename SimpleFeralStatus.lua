-- SimpleFeralStatus for Turtle WoW
-- Energy/Rage bar and combo point indicators for Feral Druids

-- ==================== Configuration Variables ====================
local BAR_WIDTH = 120
local BAR_HEIGHT = 6
local MANA_BAR_OFFSET = 0  -- No gap between bars

-- Calculate combo point dimensions
local COMBO_POINTS_COUNT = 5
local COMBO_WIDTH = BAR_WIDTH / COMBO_POINTS_COUNT  -- 24 pixels each
local COMBO_HEIGHT = BAR_HEIGHT  -- Same height as bars
local COMBO_SPACING = 0  -- No spacing between combo points

-- ==================== Energy Tick Variables (from EnergyWatch) ====================
local ENERGY_TICK_LENGTH = 2.0
local ENERGY_PER_TICK = 20  -- Natural energy tick amount
local energyTimerStart = 0
local energyTimerEnd = 0
local lastEnergy = nil
local sparkVisible = false

-- ==================== Main Energy/Rage Bar ====================
local mainBar = CreateFrame("Frame", "FeralMainBar", UIParent)
mainBar:SetWidth(BAR_WIDTH)
mainBar:SetHeight(BAR_HEIGHT)
mainBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "",  -- No border
    tile = true, 
    tileSize = 16, 
    edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
mainBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)  -- Dark gray background
mainBar:SetMovable(true)
mainBar:EnableMouse(true)
mainBar:RegisterForDrag("LeftButton")
mainBar:SetClampedToScreen(true)

-- Create actual energy/rage bar (overlay on background)
local formBar = CreateFrame("StatusBar", "FeralFormBar", mainBar)
formBar:SetWidth(BAR_WIDTH)
formBar:SetHeight(BAR_HEIGHT)
formBar:SetPoint("CENTER", mainBar, "CENTER", 0, 0)
formBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
formBar:SetStatusBarColor(1, 0.82, 0, 0.9)  -- Default energy yellow
formBar:SetMinMaxValues(0, 100)
formBar:SetValue(0)

-- ==================== Mana Bar (always shows caster mana) ====================
local manaBarFrame = CreateFrame("Frame", "FeralManaBarFrame", UIParent)
manaBarFrame:SetWidth(BAR_WIDTH)
manaBarFrame:SetHeight(BAR_HEIGHT)
manaBarFrame:SetPoint("TOP", mainBar, "BOTTOM", 0, MANA_BAR_OFFSET)
manaBarFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "",  -- No border
    tile = true, 
    tileSize = 16, 
    edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
manaBarFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)  -- Dark gray background

-- Mana bar is NOT movable - it always follows the main bar
manaBarFrame:SetMovable(false)
manaBarFrame:EnableMouse(false)
manaBarFrame:SetClampedToScreen(true)

-- Create actual mana bar (overlay on background)
local manaBar = CreateFrame("StatusBar", "FeralManaBar", manaBarFrame)
manaBar:SetWidth(BAR_WIDTH)
manaBar:SetHeight(BAR_HEIGHT)
manaBar:SetPoint("CENTER", manaBarFrame, "CENTER", 0, 0)
manaBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
manaBar:SetStatusBarColor(0.1, 0.5, 0.9, 0.9)  -- Mana blue
manaBar:SetMinMaxValues(0, 100)
manaBar:SetValue(0)

-- ==================== Energy Tick Spark (Simple white vertical line) ====================
local sparkFrame = CreateFrame("Frame", "FeralSparkFrame", mainBar)
sparkFrame:SetWidth(2)  -- Thin vertical line
sparkFrame:SetHeight(BAR_HEIGHT + 4)
sparkFrame:SetPoint("CENTER", mainBar, "LEFT", 0, 0)

-- Create Spark as a simple white vertical line (no border, no star texture)
local sparkTexture = sparkFrame:CreateTexture("FeralSparkTexture", "OVERLAY")
sparkTexture:SetAllPoints(sparkFrame)
sparkTexture:SetTexture("Interface\\Buttons\\WHITE8X8")  -- Simple white texture
sparkTexture:SetVertexColor(1, 1, 1, 0.9)  -- Pure white, mostly opaque
sparkFrame.texture = sparkTexture
sparkFrame:Hide()  -- Hidden by default

-- Spark is NOT movable - it always follows the main bar
sparkFrame:SetMovable(false)
sparkFrame:EnableMouse(false)
sparkFrame:SetClampedToScreen(true)

-- ==================== Combo Point Indicators ====================
local comboFrames = {}
local comboPoints = 0

-- Create 5 combo point frames (24 pixels each, total 120 pixels)
for i = 1, COMBO_POINTS_COUNT do
    local comboFrame = CreateFrame("Frame", "FeralComboFrame"..i, UIParent)
    comboFrame:SetWidth(COMBO_WIDTH)
    comboFrame:SetHeight(COMBO_HEIGHT)
    
    -- Calculate position: above main bar, perfectly aligned
    -- Position each combo point adjacent to the previous one (no spacing)
    local xOffset = ((i - 1) * COMBO_WIDTH) - (BAR_WIDTH / 2) + (COMBO_WIDTH / 2)
    comboFrame:SetPoint("BOTTOM", mainBar, "TOP", xOffset, 0)
    
    comboFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "",  -- No border
        tile = true, 
        tileSize = 16, 
        edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    comboFrame:SetBackdropColor(0.3, 0.3, 0.3, 0.7)  -- Default gray, slightly transparent
    
    -- Combo points are NOT movable - they always follow the main bar
    comboFrame:SetMovable(false)
    comboFrame:EnableMouse(false)
    comboFrame:SetClampedToScreen(true)
    
    -- Store reference
    comboFrames[i] = comboFrame
end

-- ==================== Lock State Variable ====================
local framesLocked = true

-- Lock/unlock all frames
function ToggleFramesLock(lock)
    framesLocked = lock
    
    if lock then
        mainBar:EnableMouse(false)
        -- Mana bar, spark, and combo points are always not movable
        manaBarFrame:EnableMouse(false)
        sparkFrame:EnableMouse(false)
        for i = 1, COMBO_POINTS_COUNT do
            comboFrames[i]:EnableMouse(false)
        end
        print("SimpleFeralStatus frames locked")
    else
        mainBar:EnableMouse(true)
        -- Only main bar is movable, everything else follows it
        manaBarFrame:EnableMouse(false)
        sparkFrame:EnableMouse(false)
        for i = 1, COMBO_POINTS_COUNT do
            comboFrames[i]:EnableMouse(false)
        end
        print("SimpleFeralStatus unlocked - drag the energy/rage bar to move everything")
    end
end

-- ==================== Drag Scripts ====================
-- Main bar drag - moves entire UI
mainBar:SetScript("OnDragStart", function()
    if not framesLocked then
        mainBar:StartMoving()
    end
end)

mainBar:SetScript("OnDragStop", function()
    if not framesLocked then
        mainBar:StopMovingOrSizing()
        -- Update all other elements to follow main bar
        UpdateAllPositions()
    end
end)

-- Mana bar, spark, and combo points have no drag scripts since they're not movable

-- ==================== Utility Functions ====================
-- Update all positions (everything follows main bar)
function UpdateAllPositions()
    -- Update mana bar position (directly below with no gap)
    manaBarFrame:ClearAllPoints()
    manaBarFrame:SetPoint("TOP", mainBar, "BOTTOM", 0, MANA_BAR_OFFSET)
    
    -- Update spark position (relative to main bar)
    sparkFrame:ClearAllPoints()
    sparkFrame:SetPoint("CENTER", mainBar, "LEFT", 0, 0)
    
    -- Update combo point positions
    UpdateComboPositions()
end

-- Update combo point positions (always follow main bar)
function UpdateComboPositions()
    for i = 1, COMBO_POINTS_COUNT do
        -- Calculate position for each combo point
        local xOffset = ((i - 1) * COMBO_WIDTH) - (BAR_WIDTH / 2) + (COMBO_WIDTH / 2)
        comboFrames[i]:ClearAllPoints()
        comboFrames[i]:SetPoint("BOTTOM", mainBar, "TOP", xOffset, 0)
    end
end

-- ==================== Energy Tick Functions (Fixed EnergyWatch Logic) ====================
function UpdateEnergyTick()
    local form = GetCurrentForm()
    
    if form == "CAT" then
        local formResource, casterMana = UnitMana("player")  -- Get both values
        local currentTime = GetTime()
        
        -- Initialize lastEnergy if nil (first run)
        if lastEnergy == nil then
            lastEnergy = formResource
            energyTimerStart = currentTime
            energyTimerEnd = currentTime + ENERGY_TICK_LENGTH
        end
        
        -- Check if timer has expired (natural tick should have occurred)
        if currentTime >= energyTimerEnd then
            -- Natural tick window expired, start new timer
            energyTimerStart = currentTime
            energyTimerEnd = currentTime + ENERGY_TICK_LENGTH
            
            -- Reset spark to beginning
            local sparkPosition = 0
            sparkFrame:SetPoint("CENTER", mainBar, "LEFT", sparkPosition, 0)
            sparkFrame:Show()
            sparkVisible = true
            
            lastEnergy = formResource
        -- Check if we got a NATURAL energy tick (approx 20 energy)
        elseif formResource > lastEnergy then
            local energyGain = formResource - lastEnergy
            
            -- Check if this is a natural tick (approximately 20 energy)
            -- Using tolerance of ±1 for rounding/display issues
            if math.abs(energyGain - ENERGY_PER_TICK) <= 1 then
                -- This is a natural tick! Reset timer
                energyTimerStart = currentTime
                energyTimerEnd = currentTime + ENERGY_TICK_LENGTH
                
                -- Reset spark to beginning
                local sparkPosition = 0
                sparkFrame:SetPoint("CENTER", mainBar, "LEFT", sparkPosition, 0)
                sparkFrame:Show()
                sparkVisible = true
            end
            -- If energy gain is NOT approx 20, it's from an ability - DON'T reset timer
            
            lastEnergy = formResource
        elseif formResource < lastEnergy then
            -- Energy decreased (used an ability)
            lastEnergy = formResource
        end
        
        -- Calculate and update spark position
        if sparkVisible then
            local timeSinceTick = currentTime - energyTimerStart
            local timeUntilNextTick = ENERGY_TICK_LENGTH - timeSinceTick
            
            -- Only show spark if we're within the tick window
            if timeUntilNextTick > 0 then
                local progress = timeSinceTick / ENERGY_TICK_LENGTH
                progress = math.min(math.max(progress, 0), 1)
                
                -- Calculate spark position (0 to BAR_WIDTH)
                local sparkPosition = progress * BAR_WIDTH
                
                -- Position the spark
                sparkFrame:SetPoint("CENTER", mainBar, "LEFT", sparkPosition, 0)
                sparkFrame:Show()
            else
                -- Should have ticked by now, hide spark
                sparkFrame:Hide()
                sparkVisible = false
            end
        end
        
        -- Hide spark if at full energy
        local maxFormResource = GetFormResourceMax()
        if formResource >= maxFormResource then
            sparkFrame:Hide()
            sparkVisible = false
        end
    else
        -- Not in cat form, hide spark and reset tracking
        sparkFrame:Hide()
        sparkVisible = false
        lastEnergy = nil
        energyTimerStart = 0
        energyTimerEnd = 0
    end
end

-- Detect current form
function GetCurrentForm()
    for i = 1, 3 do
        local texture, name, isActive, isCastable = GetShapeshiftFormInfo(i)
        if isActive then
            if i == 1 then
                return "BEAR"
            elseif i == 2 then
                return "AQUATIC"
            elseif i == 3 then
                return "CAT"
            end
        end
    end
    
    for i = 4, 5 do
        local texture, name, isActive, isCastable = GetShapeshiftFormInfo(i)
        if isActive then
            if string.find(name or "", "Travel") then
                return "TRAVEL"
            elseif string.find(name or "", "Moonkin") then
                return "MOONKIN"
            end
        end
    end
    
    return "NONE"
end

-- Get form resource max value
function GetFormResourceMax()
    local form = GetCurrentForm()
    
    if form == "CAT" then
        return 100  -- Max energy
    elseif form == "BEAR" then
        return 100  -- Max rage
    else
        local casterMana = UnitMana("player")
        -- In caster form, we need to check if this is form mana or caster mana
        -- For now, use the second value from UnitManaMax
        local formMax, casterMax = UnitManaMax("player")
        return formMax or 100
    end
end

-- Get caster mana max value
function GetCasterManaMax()
    local formResource, casterMana = UnitMana("player")
    local formMax, casterMax = UnitManaMax("player")
    
    -- Return the second value which should be caster mana max
    return casterMax or 100
end

-- Get current form resource (energy/rage) - for form bar display
function GetFormResource()
    local form = GetCurrentForm()
    local formResource, casterMana = UnitMana("player")  -- Get both values
    
    if form == "CAT" then
        local maxEnergy = GetFormResourceMax()
        return "ENERGY", formResource, maxEnergy
    elseif form == "BEAR" then
        local maxRage = GetFormResourceMax()
        return "RAGE", formResource, maxRage
    else
        local maxMana = GetFormResourceMax()
        return "MANA", formResource, maxMana
    end
end

-- Get caster mana (always available in Turtle WoW)
function GetCasterMana()
    -- UnitMana("player") returns: (formResource, casterMana)
    local formResource, casterMana = UnitMana("player")
    local casterMax = GetCasterManaMax()
    
    return casterMana or 0, casterMax or 100
end

-- Update form bar (energy/rage/caster mana)
function UpdateFormBar()
    local form = GetCurrentForm()
    local resourceType, current, max = GetFormResource()
    
    formBar:SetMinMaxValues(0, max)
    formBar:SetValue(current)
    
    if resourceType == "ENERGY" then
        formBar:SetStatusBarColor(1, 0.82, 0, 0.9)  -- Energy yellow
        mainBar:Show()
    elseif resourceType == "RAGE" then
        formBar:SetStatusBarColor(0.9, 0.1, 0.1, 0.9)  -- Rage red
        mainBar:Show()
    elseif resourceType == "MANA" then
        formBar:SetStatusBarColor(0.1, 0.5, 0.9, 0.9)  -- Mana blue
        mainBar:Show()
    end
end

-- Update mana bar (always shows caster mana, except in non-combat forms)
function UpdateManaBar()
    local form = GetCurrentForm()
    
    -- Hide mana bar in non-combat forms (since top bar shows mana already)
    -- Combat forms: CAT, BEAR
    -- Non-combat forms: NONE, MOONKIN, TRAVEL, AQUATIC
    if form == "NONE" or form == "MOONKIN" or form == "TRAVEL" or form == "AQUATIC" then
        manaBarFrame:Hide()
        return
    end
    
    local casterMana, casterMax = GetCasterMana()
    
    manaBar:SetMinMaxValues(0, casterMax)
    manaBar:SetValue(casterMana)
    
    -- Show mana bar when in combat forms (cat, bear)
    manaBarFrame:Show()
end

-- Update combo points (changed to red)
function UpdateComboPoints()
    local form = GetCurrentForm()
    
    if form == "CAT" then
        comboPoints = GetComboPoints()
        
        for i = 1, COMBO_POINTS_COUNT do
            if i <= comboPoints then
                -- Active combo point: bright red
                comboFrames[i]:SetBackdropColor(0.9, 0.1, 0.1, 1.0)  -- Changed to red
            else
                -- Inactive combo point: dark gray
                comboFrames[i]:SetBackdropColor(0.3, 0.3, 0.3, 0.7)
            end
            comboFrames[i]:Show()
        end
    else
        for i = 1, COMBO_POINTS_COUNT do
            comboFrames[i]:Hide()
        end
    end
end

-- Update all indicators
function UpdateAllIndicators()
    UpdateFormBar()
    UpdateManaBar()
    UpdateComboPoints()
    UpdateEnergyTick()
end

-- ==================== Event Handling ====================
local function OnEvent()
    if event == "PLAYER_ENTERING_WORLD" or 
       event == "PLAYER_LOGIN" or
       event == "UNIT_ENERGY" or
       event == "UNIT_RAGE" or
       event == "UNIT_MANA" or
       event == "UNIT_MAXENERGY" or
       event == "UNIT_MAXRAGE" or
       event == "UNIT_MAXMANA" or
       event == "PLAYER_COMBO_POINTS" or
       event == "PLAYER_AURAS_CHANGED" or 
       event == "UPDATE_SHAPESHIFT_FORMS" or
       event == "UPDATE_SHAPESHIFT_USABLE" or
       event == "UPDATE_SHAPESHIFT_COOLDOWN" or
       event == "SPELL_UPDATE_COOLDOWN" then
        
        local _, class = UnitClass("player")
        if class == "DRUID" then
            UpdateAllIndicators()
        else
            mainBar:Hide()
            manaBarFrame:Hide()
            sparkFrame:Hide()
            for i = 1, COMBO_POINTS_COUNT do
                comboFrames[i]:Hide()
            end
        end
    end
end

-- Register events
local events = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGIN", 
    "UNIT_ENERGY",
    "UNIT_RAGE",
    "UNIT_MANA",
    "UNIT_MAXENERGY",
    "UNIT_MAXRAGE",
    "UNIT_MAXMANA",
    "PLAYER_COMBO_POINTS",
    "PLAYER_AURAS_CHANGED",
    "UPDATE_SHAPESHIFT_FORMS",
    "UPDATE_SHAPESHIFT_USABLE",
    "UPDATE_SHAPESHIFT_COOLDOWN",
    "SPELL_UPDATE_COOLDOWN"
}

for _, event in pairs(events) do
    mainBar:RegisterEvent(event)
    manaBarFrame:RegisterEvent(event)
    sparkFrame:RegisterEvent(event)
    for i = 1, COMBO_POINTS_COUNT do
        comboFrames[i]:RegisterEvent(event)
    end
end

mainBar:SetScript("OnEvent", OnEvent)
manaBarFrame:SetScript("OnEvent", OnEvent)
sparkFrame:SetScript("OnEvent", OnEvent)
for i = 1, COMBO_POINTS_COUNT do
    comboFrames[i]:SetScript("OnEvent", OnEvent)
end

-- ==================== Update Loop ====================
local updateCounter = 0
local function OnUpdate()
    updateCounter = updateCounter + arg1
    if updateCounter > 0.05 then  -- Update every 0.05 seconds for smooth spark movement
        updateCounter = 0
        local _, class = UnitClass("player")
        if class == "DRUID" then
            UpdateAllIndicators()
        end
    end
end

mainBar:SetScript("OnUpdate", OnUpdate)
manaBarFrame:SetScript("OnUpdate", OnUpdate)
sparkFrame:SetScript("OnUpdate", OnUpdate)
for i = 1, COMBO_POINTS_COUNT do
    comboFrames[i]:SetScript("OnUpdate", OnUpdate)
end

-- ==================== Slash Commands ====================
SLASH_SIMPLEFERAL1 = "/sfs"
SLASH_SIMPLEFERAL2 = "/simpleferal"

SlashCmdList["SIMPLEFERAL"] = function(msg)
    if msg == "reset" then
        -- Reset main bar position
        mainBar:ClearAllPoints()
        mainBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        
        -- Update all other elements to follow main bar
        UpdateAllPositions()
        
        print("SimpleFeralStatus positions reset")
        print("Note: All elements move together as one unit")
    elseif msg == "lock" then
        ToggleFramesLock(true)
    elseif msg == "unlock" then
        ToggleFramesLock(false)
    elseif msg == "spark" then
        -- Toggle spark display
        if sparkFrame:IsVisible() then
            sparkFrame:Hide()
            print("Energy spark hidden")
        else
            sparkFrame:Show()
            print("Energy spark shown")
        end
    elseif msg == "debug" then
        local _, class = UnitClass("player")
        print("Debug - Class:", class)
        
        local form = GetCurrentForm()
        print("Current Form:", form)
        
        for i = 1, 5 do
            local texture, name, isActive, isCastable = GetShapeshiftFormInfo(i)
            if name then
                print("Form Slot", i, "- Name:", name, "- Active:", isActive)
            end
        end
        
        -- Test UnitMana returns
        local formResource, casterMana = UnitMana("player")
        local formMax, casterMax = UnitManaMax("player")
        print("UnitMana returns:", formResource, casterMana)
        print("UnitManaMax returns:", formMax, casterMax)
        
        print("Form Resource:", formResource)
        print("Caster Mana:", casterMana)
        
        local comboPoints = GetComboPoints()
        print("Combo Points:", comboPoints)
        
        if form == "CAT" then
            local currentTime = GetTime()
            print("Energy tick info:")
            print("  Timer start:", string.format("%.2f", energyTimerStart))
            print("  Timer end:", string.format("%.2f", energyTimerEnd))
            print("  Current time:", string.format("%.2f", currentTime))
            print("  Time to next tick:", string.format("%.2f", math.max(0, energyTimerEnd - currentTime)))
            print("  Last energy:", lastEnergy)
            print("  Current energy:", formResource)
            if lastEnergy then
                print("  Energy difference:", formResource - lastEnergy)
            end
        end
        
        UpdateAllIndicators()
    else
        print("SimpleFeralStatus commands:")
        print("/sfs reset - Reset all frame positions")
        print("/sfs lock - Lock frames in place")
        print("/sfs unlock - Unlock frames for moving")
        print("/sfs spark - Toggle energy spark visibility")
        print("/sfs debug - Show debug information")
        print("")
        print("Top row: 5 Combo Points (Cat form only, 24px each, total 120px) - RED")
        print("Middle row: Energy (Cat) / Rage (Bear) / Mana (Non-combat forms) - 120px wide")
        print("Bottom row: Caster Mana (shown in combat forms only: Cat, Bear) - 120px wide")
        print("Spark: White vertical line showing next energy tick (Cat form only)")
        print("")
        print("All rows are 6px tall and 120px wide")
        print("All elements move together as one unit - drag the energy/rage bar to reposition")
    end
end

-- ==================== Initial Check ====================
local _, class = UnitClass("player")
if class == "DRUID" then
    mainBar:Show()
    manaBarFrame:Show()
    UpdateAllIndicators()
    UpdateAllPositions()  -- Ensure all elements are properly positioned
else
    mainBar:Hide()
    manaBarFrame:Hide()
    sparkFrame:Hide()
    for i = 1, COMBO_POINTS_COUNT do
        comboFrames[i]:Hide()
    end
end