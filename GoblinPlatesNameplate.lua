-- GoblinPlatesNameplate.lua

local addonName, GP = ...
GP = GP or {}
_G.GoblinPlates = GP

local BASE_HEALTH_W = 124
local BASE_HEALTH_H = 12
local BASE_POWER_H = 4
local BASE_FRAME_W = 160
local BASE_FRAME_H = 70

local CLASS_SCALE = {
    minus = 0.75,
    normal = 1.00,
    rare = 1.00,
    elite = 1.50,
    rareelite = 1.50,
    worldboss = 2.00,
    boss = 2.00,
}

local function GetPlateScale(unit)
    local class = UnitClassification(unit) or "normal"

    if class == "worldboss" then
        return 2.00
    end

    return CLASS_SCALE[class] or 1.00
end

local function HideBlizzardNameplateBits(plate)
    if not plate or not plate.UnitFrame then return end
    local uf = plate.UnitFrame

    if uf.healthBar then uf.healthBar:SetAlpha(0) end
    if uf.castBar then uf.castBar:SetAlpha(0) end
    if uf.name then uf.name:SetAlpha(0) end
    if uf.Name then uf.Name:SetAlpha(0) end
    if uf.LevelFrame then uf.LevelFrame:SetAlpha(0) end
    if uf.selectionHighlight then uf.selectionHighlight:SetAlpha(0) end
    if uf.threatGlow then uf.threatGlow:SetAlpha(0) end

    if uf.classificationIndicator then uf.classificationIndicator:SetAlpha(0) end
    if uf.ClassificationFrame then uf.ClassificationFrame:SetAlpha(0) end

    if uf.BuffFrame then uf.BuffFrame:SetAlpha(0) end
    if uf.DebuffFrame then uf.DebuffFrame:SetAlpha(0) end
    if uf.Buffs then uf.Buffs:SetAlpha(0) end
    if uf.Debuffs then uf.Debuffs:SetAlpha(0) end
    if uf.auraFrame then uf.auraFrame:SetAlpha(0) end
    if uf.AuraFrame then uf.AuraFrame:SetAlpha(0) end
end

local function ApplyBlackOutline(fontString, sizeIncrease)
    if not fontString then return end

    local font, size = fontString:GetFont()

    if font and size then
        fontString:SetFont(font, size + (sizeIncrease or 0), "OUTLINE")
    end

    fontString:SetShadowOffset(0, 0)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function AnchorGoblinPlate(frame, plate)
    if not frame or not plate then return false end

    local ok = pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", plate, "CENTER", 0, -12)
    end)

    if not ok then
        frame:Hide()
        return false
    end

    frame:Show()
    return true
end

local function ApplyNameplateLayout(frame, unit)
    if not frame then return end

    local classScale = GetPlateScale(unit)
    frame.GPClassificationScale = classScale

    local targetScale = frame.GPTargetScale or 1.00
    local scale = math.max(classScale, targetScale)

    local healthW = math.floor(BASE_HEALTH_W * scale)
    local healthH = math.floor(BASE_HEALTH_H * scale)
    local powerH = math.floor(BASE_POWER_H * scale)

    if healthH < 9 then healthH = 9 end
    if healthH > 24 then healthH = 24 end
    if powerH < 3 then powerH = 3 end
    if powerH > 10 then powerH = 10 end

    local frameW = math.max(BASE_FRAME_W, healthW + 40)
    local frameH = math.max(BASE_FRAME_H, 62 + healthH + powerH)

    frame:SetSize(frameW, frameH)

    if frame.HealthBG then
        frame.HealthBG:ClearAllPoints()
        frame.HealthBG:SetSize(healthW, healthH)
        frame.HealthBG:SetPoint("TOP", frame, "TOP", 0, -16)
    end

    if frame.HealthBar then
        frame.HealthBar:ClearAllPoints()
        frame.HealthBar:SetSize(healthW, healthH)
        frame.HealthBar:SetPoint("TOP", frame, "TOP", 0, -16)
    end

    if frame.PowerBG and frame.HealthBar then
        frame.PowerBG:ClearAllPoints()
        frame.PowerBG:SetSize(healthW, powerH)
        frame.PowerBG:SetPoint("TOP", frame.HealthBar, "BOTTOM", 0, -1)
    end

    if frame.PowerBar and frame.HealthBar then
        frame.PowerBar:ClearAllPoints()
        frame.PowerBar:SetSize(healthW, powerH)
        frame.PowerBar:SetPoint("TOP", frame.HealthBar, "BOTTOM", 0, -1)
    end

    if frame.HealthTextFrame and frame.HealthBar then
        frame.HealthTextFrame:ClearAllPoints()
        frame.HealthTextFrame:SetAllPoints(frame.HealthBar)
    end

    if frame.Border and frame.HealthBar then
        frame.Border:ClearAllPoints()
        frame.Border:SetPoint("TOPLEFT", frame.HealthBar, "TOPLEFT", -1, 1)
        frame.Border:SetPoint("BOTTOMRIGHT", frame.HealthBar, "BOTTOMRIGHT", 1, -1)
    end

    if frame.NameText and frame.HealthBar then
        frame.NameText:ClearAllPoints()
        frame.NameText:SetPoint("TOP", frame.HealthBar, "BOTTOM", 10, -8 - powerH)
        frame.NameText:SetScale(1.0)
    end

    if frame.LevelText and frame.NameText then
        frame.LevelText:ClearAllPoints()
        frame.LevelText:SetPoint("RIGHT", frame.NameText, "LEFT", -6, 0)
        frame.LevelText:SetScale(1.0)
    end

    if frame.RangeText and frame.HealthBar then
        frame.RangeText:ClearAllPoints()
        frame.RangeText:SetPoint("TOPRIGHT", frame.HealthBar, "BOTTOMRIGHT", 1, -22 - powerH)
        frame.RangeText:SetScale(1.0)
    end
end

GP.ApplyNameplateLayout = ApplyNameplateLayout

function GP:CreateNameplate(plate, unit)
    if not plate or plate.GoblinPlate then return end

    HideBlizzardNameplateBits(plate)

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(BASE_FRAME_W, BASE_FRAME_H)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(50)

    plate.GoblinPlate = frame
    frame.sourcePlate = plate
    frame.unit = unit

    AnchorGoblinPlate(frame, plate)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.85)
    frame.HealthBG = bg

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetFrameLevel(frame:GetFrameLevel() + 1)
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    health:SetStatusBarColor(0, 0.9, 0)
    frame.HealthBar = health

    local absorbWash = CreateFrame("StatusBar", nil, health)
    absorbWash:SetAllPoints(health)
    absorbWash:SetFrameLevel(health:GetFrameLevel() + 2)
    absorbWash:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    absorbWash:SetStatusBarColor(0.18, 0.72, 1.00, 0.80)
    absorbWash:GetStatusBarTexture():SetBlendMode("BLEND")
    absorbWash:SetReverseFill(true)
    absorbWash:SetMinMaxValues(0, 1)
    absorbWash:SetValue(0)
    frame.AbsorbWash = absorbWash

    local absorbBar = CreateFrame("StatusBar", nil, health)
    absorbBar:SetAllPoints(health)
    absorbBar:SetFrameLevel(health:GetFrameLevel() + 3)
    absorbBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    absorbBar:SetStatusBarColor(0.18, 0.72, 1.00, 0.48)
    absorbBar:GetStatusBarTexture():SetBlendMode("BLEND")
    absorbBar:SetReverseFill(true)
    absorbBar:SetMinMaxValues(0, 1)
    absorbBar:SetValue(0)
    frame.AbsorbBar = absorbBar

    self:Call("CreateCastBar", frame)
    self:Call("CreatePowerBar", frame)

    local textFrame = CreateFrame("Frame", nil, frame)
    textFrame:SetFrameLevel(health:GetFrameLevel() + 10)
    frame.HealthTextFrame = textFrame

    local healthText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthText:SetPoint("RIGHT", textFrame, "RIGHT", -4, 0)
    healthText:SetText("")
    healthText:SetJustifyH("RIGHT")
    healthText:SetTextColor(1, 1, 1, 1)
    ApplyBlackOutline(healthText, 1)
    frame.HealthText = healthText

    local absorbText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    absorbText:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
    absorbText:SetText("")
    absorbText:SetJustifyH("CENTER")
    absorbText:SetTextColor(0.65, 0.92, 1.00, 1)
    ApplyBlackOutline(absorbText, 1)
    frame.AbsorbText = absorbText

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetFrameLevel(textFrame:GetFrameLevel() + 1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    frame.Border = border

    local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetText("")
    name:SetJustifyH("CENTER")
    name:SetTextColor(1, 1, 1, 1)
    name:SetScale(1.0)
    ApplyBlackOutline(name, 2)
    frame.NameText = name

    local level = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    level:SetText("")
    level:SetJustifyH("RIGHT")
    level:SetTextColor(1, 1, 1, 1)
    level:SetScale(1.0)
    ApplyBlackOutline(level, 1)
    frame.LevelText = level

    ApplyNameplateLayout(frame, unit)

    frame:Show()
end

function GP:UpdateNameplate(plate, unit)
    if not plate then return end

    HideBlizzardNameplateBits(plate)

    if not plate.GoblinPlate then
        self:CreateNameplate(plate, unit)
    end

    local frame = plate.GoblinPlate
    if not frame then return end

    frame.unit = unit
    frame.sourcePlate = plate

    if not AnchorGoblinPlate(frame, plate) then
        return
    end

    ApplyNameplateLayout(frame, unit)

    self:Call("UpdateHealthBar", plate, unit)
    self:Call("UpdatePowerBar", plate, unit)
    self:Call("UpdateNameText", plate, unit)
    self:Call("UpdateCastBar", plate, unit)
end

function GP:ShowNameplate(plate, unit)
    if not plate then return end

    if not plate.GoblinPlate then
        self:CreateNameplate(plate, unit)
    end

    if plate.GoblinPlate then
        plate.GoblinPlate.unit = unit
        plate.GoblinPlate.sourcePlate = plate
        AnchorGoblinPlate(plate.GoblinPlate, plate)
        ApplyNameplateLayout(plate.GoblinPlate, unit)
        plate.GoblinPlate:Show()
    end
end

function GP:HideNameplate(plate, unit)
    if plate and plate.GoblinPlate then
        plate.GoblinPlate:Hide()
    end
end
