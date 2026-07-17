-- GoblinPlates/GoblinPlatesThreat.lua

local addonName, GP = ...
GP = GP or {}
_G.GoblinPlates = GP

------------------------------------------------------------
-- Threat Configuration
------------------------------------------------------------

local GLOW_X = 10
local GLOW_Y = 5
local FLASH_SPEED = 0.35

local GLOW_TEXTURE =
    "Interface\\AddOns\\GoblinPlates\\Media\\Textures\\glow_horizontal_256"

local THREAT_COLORS = {
    [0] = {0.00, 0.45, 1.00, 0.60},
    [1] = {1.00, 0.45, 0.00, 0.75},
    [2] = {1.00, 0.00, 0.00, 0.85},
    [3] = {1.00, 0.00, 0.00, 0.85},
}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

local function GetThreatGlowScale(frame)
    if not frame then
        return 1.00
    end

    if frame.IsGoblinTarget then
        return frame.GPTargetScale or 1.50
    end

    return 1.00
end

local function SetTargetMarkerThreatColor(frame, r, g, b)
    if not frame or not GP.SetTargetMarkerColor then
        return
    end

    GP.SetTargetMarkerColor(frame, r, g, b, 1.00)
end

local function ResetTargetMarkerThreatColor(frame)
    if not frame or not GP.ResetTargetMarkerColor then
        return
    end

    GP.ResetTargetMarkerColor(frame)
end

------------------------------------------------------------
-- Threat Glow Creation
------------------------------------------------------------

local function EnsureThreatGlow(frame)
    if not frame or frame.ThreatGlow or not frame.HealthBar then
        return
    end

    local glowFrame = CreateFrame("Frame", nil, frame)
    glowFrame:SetFrameStrata(frame:GetFrameStrata())
    glowFrame:SetFrameLevel(frame.HealthBar:GetFrameLevel() + 15)
    glowFrame:EnableMouse(false)
    glowFrame:Hide()

    local tex = glowFrame:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(glowFrame)
    tex:SetTexture(GLOW_TEXTURE)
    tex:SetBlendMode("ADD")
    tex:SetAlpha(0)

    glowFrame.tex = tex
    glowFrame.flashTimer = 0
    glowFrame.flashOn = true
    glowFrame.baseAlpha = 0.75
    glowFrame.flashing = false

    glowFrame:SetScript("OnUpdate", function(self, elapsed)
        if not self.flashing then
            return
        end

        self.flashTimer = self.flashTimer + elapsed

        if self.flashTimer >= FLASH_SPEED then
            self.flashTimer = 0
            self.flashOn = not self.flashOn
            self.tex:SetAlpha(
                self.flashOn and self.baseAlpha or 0.25
            )
        end
    end)

    frame.ThreatGlow = glowFrame
end

------------------------------------------------------------
-- Threat Glow Layout
------------------------------------------------------------

local function AnchorGlow(frame)
    if not frame or not frame.ThreatGlow or not frame.HealthBar then
        return
    end

    local scale = GetThreatGlowScale(frame)
    local glowX = GLOW_X * scale
    local glowY = GLOW_Y * scale
    local topFrame = frame.CastBar or frame.HealthBar

    frame.ThreatGlow:ClearAllPoints()
    frame.ThreatGlow:SetPoint(
        "TOPLEFT",
        topFrame,
        "TOPLEFT",
        -glowX,
        glowY
    )
    frame.ThreatGlow:SetPoint(
        "BOTTOMRIGHT",
        frame.HealthBar,
        "BOTTOMRIGHT",
        glowX,
        -glowY
    )
end

function GP.RefreshThreatGlowLayout(frame)
    if not frame or not frame.ThreatGlow then
        return
    end

    AnchorGlow(frame)
end

------------------------------------------------------------
-- Threat Glow State
------------------------------------------------------------

local function SetGlow(frame, r, g, b, alpha, flashing)
    if not frame then
        return
    end

    EnsureThreatGlow(frame)
    AnchorGlow(frame)

    local glow = frame.ThreatGlow

    if not glow then
        return
    end

    local a = alpha or 0.75

    glow.tex:SetVertexColor(r, g, b, 1)
    glow.tex:SetAlpha(a)

    glow.baseAlpha = a
    glow.flashing = flashing or false
    glow.flashTimer = 0
    glow.flashOn = true

    glow:Show()

    SetTargetMarkerThreatColor(frame, r, g, b)
end

local function HideGlow(frame)
    if not frame then
        return
    end

    if frame.ThreatGlow then
        frame.ThreatGlow.flashing = false
        frame.ThreatGlow.flashTimer = 0
        frame.ThreatGlow.flashOn = true
        frame.ThreatGlow.tex:SetAlpha(0)
        frame.ThreatGlow:Hide()
    end

    ResetTargetMarkerThreatColor(frame)
end

------------------------------------------------------------
-- Threat Update
------------------------------------------------------------

function GP:UpdateThreat(plate, unit)
    if not plate or not unit then
        return
    end

    local frame = plate.GoblinPlate

    if not frame then
        return
    end

    if not UnitCanAttack("player", unit) then
        HideGlow(frame)
        return
    end

    if not InCombatLockdown() then
        HideGlow(frame)
        return
    end

    local status = UnitThreatSituation("player", unit)

    if status == nil then
        status = 0
    end

    local color = THREAT_COLORS[status] or THREAT_COLORS[0]
    local flashing = status == 2

    SetGlow(
        frame,
        color[1],
        color[2],
        color[3],
        color[4],
        flashing
    )
end