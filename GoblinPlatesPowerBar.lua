-- GoblinPlates/GoblinPlatesPowerBar.lua

local addonName, GP = ...
GP = GP or {}
_G.GoblinPlates = GP

local POWER_COLORS = {
    MANA = {0.00, 0.45, 1.00},
    RAGE = {1.00, 0.00, 0.00},
    FOCUS = {1.00, 0.50, 0.00},
    ENERGY = {1.00, 1.00, 0.00},
    RUNIC_POWER = {0.00, 0.82, 1.00},

    FURY = {0.75, 0.00, 1.00},
    PAIN = {1.00, 0.55, 0.00},
    MAELSTROM = {0.00, 0.70, 1.00},
    INSANITY = {0.55, 0.00, 1.00},
    LUNAR_POWER = {0.20, 0.60, 1.00},
}

function GP:CreatePowerBar(frame)
    if not frame or frame.PowerBar then return end
    if not frame.HealthBar then return end

    local power = CreateFrame("StatusBar", nil, frame)
    power:SetSize(120, 3)
    power:SetPoint("TOP", frame.HealthBar, "BOTTOM", 0, -1)
    power:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    power:SetMinMaxValues(0, 100)
    power:SetValue(100)
    power:SetFrameLevel(frame.HealthBar:GetFrameLevel())

    frame.PowerBar = power

    local bg = power:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.08, 0.08, 0.08, 0.90)
    power.bg = bg
end

function GP:UpdatePowerBar(plate, unit)
    if not plate or not unit then return end

    local frame = plate.GoblinPlate
    if not frame then return end

    if not frame.PowerBar then
        self:CreatePowerBar(frame)
    end

    local bar = frame.PowerBar
    if not bar then return end

    local powerType, token = UnitPowerType(unit)

    local color = POWER_COLORS[token]
    if not color then
        bar:Hide()
        return
    end

    local percent = UnitPowerPercent(
        unit,
        powerType,
        false,
        CurveConstants and CurveConstants.ScaleTo100
    )

    if not percent then
        bar:Hide()
        return
    end

    bar:SetMinMaxValues(0, 100)
    bar:SetValue(percent)
    bar:SetStatusBarColor(color[1], color[2], color[3])
    bar:Show()
end