-- GoblinPlates/CastBar.lua

local addonName, GP = ...
GP = GP or {}
_G.GoblinPlates = GP

local CastEvents = CreateFrame("Frame")
GP.CastCache = GP.CastCache or {}

local function IsNameplateUnit(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$")
end

local function CanAccess(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    if canaccessvalue then return canaccessvalue(v) end
    return true
end

local function UseSpellID(apiSpellID, eventSpellID)
    if type(eventSpellID) == "number" then return eventSpellID end
    if eventSpellID and CanAccess(eventSpellID) then return eventSpellID end
    if type(apiSpellID) == "number" then return apiSpellID end
    if apiSpellID and CanAccess(apiSpellID) then return apiSpellID end
    return nil
end

local function SafeSpellName(spellID, name, text)
    if spellID then
        if C_Spell and C_Spell.GetSpellName then
            local n = C_Spell.GetSpellName(spellID)
            if n then return n end
        end

        if GetSpellInfo then
            local n = GetSpellInfo(spellID)
            if n then return n end
        end

        return "spell:" .. tostring(spellID)
    end

    if text and CanAccess(text) then return tostring(text) end
    if name and CanAccess(name) then return tostring(name) end

    return "???"
end

local function HideBlizzardCastBar(plate)
    local cb = plate and plate.UnitFrame and plate.UnitFrame.castBar
    if not cb then return end

    cb:SetAlpha(0)

    for i = 1, cb:GetNumRegions() do
        local r = select(i, cb:GetRegions())
        if r then
            r:SetAlpha(0)
        end
    end
end

local function ClearCast(frame)
    if not frame then return end

    if frame.CastBar then frame.CastBar:Hide() end
    if frame.CastLockOverlay then
        frame.CastLockOverlay:SetAlpha(0)
        frame.CastLockOverlay:Hide()
    end
    if frame.CastTextFrame then frame.CastTextFrame:Hide() end
    if frame.CastBorder then frame.CastBorder:Hide() end
    if frame.CastSpellText then frame.CastSpellText:SetText("") end
end

local function GetUnitCastInfo(unit, eventSpellID, forceChannel)
    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID =
        UnitCastingInfo(unit)

    if name then
        return {
            unit = unit,
            name = name,
            text = text,
            spellID = UseSpellID(spellID, eventSpellID),
            castID = castID,
            isChannel = false,
            notInterruptibleSecret = notInterruptible,
        }
    end

    name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID =
        UnitChannelInfo(unit)

    if name then
        return {
            unit = unit,
            name = name,
            text = text,
            spellID = UseSpellID(spellID, eventSpellID),
            castID = nil,
            isChannel = true,
            notInterruptibleSecret = notInterruptible,
        }
    end

    if eventSpellID then
        return {
            unit = unit,
            name = nil,
            text = nil,
            spellID = eventSpellID,
            castID = nil,
            isChannel = forceChannel or false,
            notInterruptibleSecret = nil,
        }
    end

    return nil
end

local function ApplyCastColor(frame, info)
    if not frame or not frame.CastBar or not info then return end

    local r, g, b = 1.00, 0.60, 0.00
    if GP.GetCastColor then
        r, g, b = GP:GetCastColor("unknown")
    end

    frame.CastBar:SetStatusBarColor(r, g, b, 1)

    if frame.CastLockOverlay then
        local nr, ng, nb = 0.45, 0.45, 0.45
        if GP.GetCastColor then
            nr, ng, nb = GP:GetCastColor("nonInterruptible")
        end

        frame.CastLockOverlay:SetStatusBarColor(nr, ng, nb, 1)

        local ok = pcall(function()
            frame.CastLockOverlay:SetAlphaFromBoolean(info.notInterruptibleSecret, 1, 0)
        end)

        if ok then
            frame.CastLockOverlay:Show()
        else
            frame.CastLockOverlay:SetAlpha(0)
            frame.CastLockOverlay:Hide()
        end
    end
end

local function ApplyCastTimer(frame, unit, info)
    if not frame or not frame.CastBar or not info then return end

    local duration

    if info.isChannel and UnitChannelDuration then
        duration = UnitChannelDuration(unit)
    elseif UnitCastingDuration then
        duration = UnitCastingDuration(unit)
    end

    frame.CastBar:SetMinMaxValues(0, 1)

    if frame.CastLockOverlay then
        frame.CastLockOverlay:SetMinMaxValues(0, 1)
    end

    if duration
        and frame.CastBar.SetTimerDuration
        and Enum
        and Enum.StatusBarInterpolation
        and Enum.StatusBarTimerDirection then

        local startValue = info.isChannel and 1 or 0
        local direction = info.isChannel
            and Enum.StatusBarTimerDirection.RemainingTime
            or Enum.StatusBarTimerDirection.ElapsedTime

        frame.CastBar:SetValue(startValue)
        frame.CastBar:SetTimerDuration(
            duration,
            Enum.StatusBarInterpolation.Immediate,
            direction
        )

        if frame.CastLockOverlay and frame.CastLockOverlay.SetTimerDuration then
            frame.CastLockOverlay:SetValue(startValue)
            frame.CastLockOverlay:SetTimerDuration(
                duration,
                Enum.StatusBarInterpolation.Immediate,
                direction
            )
        end
    else
        frame.CastBar:SetValue(1)

        if frame.CastLockOverlay then
            frame.CastLockOverlay:SetValue(1)
        end
    end
end

local function DrawCastForPlate(plate, unit)
    if not plate or not plate.GoblinPlate or not unit then return end

    HideBlizzardCastBar(plate)

    local frame = plate.GoblinPlate
    if not frame or not frame.CastBar then return end

    local info = GP.CastCache[unit] or GetUnitCastInfo(unit)

    if not info then
        ClearCast(frame)
        return
    end

    frame.CastBar.spellID = info.spellID
    frame.CastBar.castID = info.castID
    frame.CastBar.isChannel = info.isChannel

    ApplyCastColor(frame, info)
    ApplyCastTimer(frame, unit, info)

    if frame.CastSpellText then
        frame.CastSpellText:SetText(SafeSpellName(info.spellID, info.name, info.text))
    end

    frame.CastBar:Show()
    if frame.CastTextFrame then frame.CastTextFrame:Show() end
    if frame.CastBorder then frame.CastBorder:Show() end
end

local function RefreshUnitPlate(unit)
    if not IsNameplateUnit(unit) then return end
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end

    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if plate then
        DrawCastForPlate(plate, unit)
    end
end

local function StoreCast(unit, isChannel, eventSpellID)
    if not IsNameplateUnit(unit) then return end

    local info = GetUnitCastInfo(unit, eventSpellID, isChannel)

    if not info then
        GP.CastCache[unit] = nil
        RefreshUnitPlate(unit)
        return
    end

    info.isChannel = isChannel or info.isChannel
    info.spellID = UseSpellID(info.spellID, eventSpellID)

    GP.CastCache[unit] = info
    RefreshUnitPlate(unit)
end

local function ClearUnitCast(unit)
    if not IsNameplateUnit(unit) then return end

    GP.CastCache[unit] = nil
    RefreshUnitPlate(unit)
end

CastEvents:RegisterEvent("UNIT_SPELLCAST_START")
CastEvents:RegisterEvent("UNIT_SPELLCAST_STOP")
CastEvents:RegisterEvent("UNIT_SPELLCAST_FAILED")
CastEvents:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
CastEvents:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
CastEvents:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
CastEvents:RegisterEvent("UNIT_SPELLCAST_DELAYED")
CastEvents:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
CastEvents:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
CastEvents:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
CastEvents:RegisterEvent("NAME_PLATE_UNIT_ADDED")
CastEvents:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

if GetUnitEmpowerHoldAtMaxTime then
    CastEvents:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    CastEvents:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
    CastEvents:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
end

CastEvents:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        RefreshUnitPlate(unit)
        return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
        if IsNameplateUnit(unit) then
            GP.CastCache[unit] = nil
        end
        return
    end

    if not IsNameplateUnit(unit) then return end

    local castGUID, spellID = ...

    if event == "UNIT_SPELLCAST_START" then
        StoreCast(unit, false, spellID)

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        StoreCast(unit, true, spellID)

    elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
        StoreCast(unit, true, spellID)

    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_DELAYED"
        or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then

        local old = GP.CastCache[unit]
        StoreCast(unit, old and old.isChannel, spellID or (old and old.spellID))

    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_EMPOWER_STOP" then

        ClearUnitCast(unit)
    end
end)

function GP:CreateCastBar(frame)
    if not frame or frame.CastBar then return end
    if not frame.HealthBar then return end

    local cast = CreateFrame("StatusBar", nil, frame)
    cast:SetSize(124, 10)
    cast:SetPoint("BOTTOM", frame.HealthBar, "TOP", 0, 3)
    cast:SetMinMaxValues(0, 1)
    cast:SetValue(1)
    cast:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    cast:SetStatusBarColor(1.0, 0.60, 0.00, 1)
    cast:SetFrameLevel(frame:GetFrameLevel() + 2)
    cast:Hide()
    frame.CastBar = cast

    local bg = cast:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(cast)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.85)
    frame.CastBG = bg

    local lockOverlay = CreateFrame("StatusBar", nil, frame)
    lockOverlay:SetAllPoints(cast)
    lockOverlay:SetMinMaxValues(0, 1)
    lockOverlay:SetValue(1)
    lockOverlay:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    lockOverlay:SetStatusBarColor(0.45, 0.45, 0.45, 1)
    lockOverlay:SetFrameLevel(cast:GetFrameLevel() + 1)
    lockOverlay:SetAlpha(0)
    lockOverlay:Hide()
    frame.CastLockOverlay = lockOverlay

    local textFrame = CreateFrame("Frame", nil, frame)
    textFrame:SetAllPoints(cast)
    textFrame:SetFrameLevel(lockOverlay:GetFrameLevel() + 10)
    textFrame:Hide()
    frame.CastTextFrame = textFrame

    local spellText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellText:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
    spellText:SetTextColor(1, 1, 1, 1)
    spellText:SetShadowOffset(1, -1)
    spellText:SetShadowColor(0, 0, 0, 1)
    spellText:SetText("")
    frame.CastSpellText = spellText

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", cast, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", 1, -1)
    border:SetFrameLevel(textFrame:GetFrameLevel() + 1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    border:Hide()
    frame.CastBorder = border
end

function GP:UpdateCastBar(plate, unit)
    if not plate or not unit then return end
    if not UnitExists(unit) then return end

    DrawCastForPlate(plate, unit)
end