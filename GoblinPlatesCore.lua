-- GoblinPlates/GoblinPlatesCore.lua

local addonName, GP = ...

GP = GP or {}
_G.GoblinPlates = GP

GP.addonName = addonName
GP.version = "0.1.0"

GP.frames = GP.frames or {}
GP.units = GP.units or {}

local Core = CreateFrame("Frame")
GP.Core = Core

GP.debug = true

local RANGE_TICK_IC = 1.50
local RANGE_TICK_OOC = 0.15

local HEALTH_TICK_IC = 0.15
local HEALTH_TICK_OOC = 3.50

local THREAT_TICK_IC = 0.30

------------------------------------------------------------
-- Print / Debug
------------------------------------------------------------

function GP:Print(...)
    print("|cff00ff00GoblinPlates:|r", ...)
end

function GP:Debug(...)
    if self.debug then
        self:Print(...)
    end
end

------------------------------------------------------------
-- Safe Module Calls
------------------------------------------------------------

function GP:Call(methodName, ...)
    if type(self[methodName]) == "function" then
        return self[methodName](self, ...)
    end
end

------------------------------------------------------------
-- Unit Helpers
------------------------------------------------------------

function GP:IsNameplateUnit(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

function GP:GetPlate(unit)
    if not self:IsNameplateUnit(unit) then return nil end

    local plate = self.units[unit] or C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return nil end

    self.units[unit] = plate
    self.frames[plate] = unit

    return plate
end

function GP:ForEachPlate(callback)
    for plate, unit in pairs(self.frames or {}) do
        if plate and unit and UnitExists(unit) then
            callback(plate, unit)
        end
    end
end

------------------------------------------------------------
-- Forbidden Nameplate Debug
------------------------------------------------------------

function GP:DebugForbiddenNameplate(event, unit)
    self:Print(
        event .. ":",
        tostring(unit),
        UnitExists(unit) and (UnitName(unit) or "Unknown") or "No Unit",
        "Player:", UnitExists(unit) and tostring(UnitIsPlayer(unit)) or "nil",
        "Friend:", UnitExists(unit) and tostring(UnitIsFriend("player", unit)) or "nil",
        "Party:", UnitExists(unit) and tostring(UnitInParty(unit)) or "nil",
        "Raid:", UnitExists(unit) and tostring(UnitInRaid(unit)) or "nil",
        "CanAttack:", UnitExists(unit) and tostring(UnitCanAttack("player", unit)) or "nil"
    )
end

------------------------------------------------------------
-- Visual Priority Helpers
------------------------------------------------------------

local function SetTextColor(fs, r, g, b, a)
    if fs then
        fs:SetTextColor(r, g, b, a or 1)
    end
end

local function SetBarColor(bar, r, g, b, a)
    if bar then
        bar:SetStatusBarColor(r, g, b, a or 1)
    end
end

function GP:GetVisualPriorityState(frame)
    if not frame then return "NORMAL" end

    if frame.LineOfSightBlocked then
        return "LOS"
    end

    if frame.OutOfRange then
        return "OOR"
    end

    return "NORMAL"
end

function GP:RestoreBaseVisuals(plate, unit)
    if not plate or not unit then return end

    self:Call("UpdateHealthBar", plate, unit)
    self:Call("UpdatePowerBar", plate, unit)
    self:Call("UpdateCastBar", plate, unit)
end

------------------------------------------------------------
-- Final Visual Priority
-- LoS > OOR > Target > Threat/Class/etc > Base visuals
------------------------------------------------------------

function GP:ApplyVisualPriority(plate, unit)
    if not plate or not unit then return end

    local frame = plate.GoblinPlate
    if not frame then return end

    local oldState = frame.GPVisualPriorityState
    local newState = self:GetVisualPriorityState(frame)

    frame.GPVisualPriorityState = newState
    frame:SetAlpha(1)

    SetTextColor(frame.HealthText, 1, 1, 1, 1)

    if newState == "NORMAL" then
        if oldState and oldState ~= "NORMAL" then
            self:RestoreBaseVisuals(plate, unit)
        end
        return
    end

    if newState == "LOS" then
        frame:SetAlpha(0.35)

        SetBarColor(frame.HealthBar, 0.20, 0.20, 0.20, 1)
        SetBarColor(frame.PowerBar, 0.20, 0.20, 0.20, 1)
        SetBarColor(frame.CastBar, 0.20, 0.20, 0.20, 1)
        SetTextColor(frame.HealthText, 0.55, 0.55, 0.55, 1)

        return
    end

    if newState == "OOR" then
        frame:SetAlpha(0.55)

        SetBarColor(frame.HealthBar, 0.45, 0.45, 0.45, 1)
        SetBarColor(frame.PowerBar, 0.45, 0.45, 0.45, 1)
        SetBarColor(frame.CastBar, 0.45, 0.45, 0.45, 1)
        SetTextColor(frame.HealthText, 0.70, 0.70, 0.70, 1)

        return
    end
end

function GP:ApplyAllVisualPriority()
    self:ForEachPlate(function(plate, unit)
        self:ApplyVisualPriority(plate, unit)
    end)
end

------------------------------------------------------------
-- Static / Dynamic Refresh Groups
------------------------------------------------------------

function GP:RefreshStaticPlate(plate, unit)
    if not plate or not unit then return end

    self:Call("UpdateNameplate", plate, unit)
    self:Call("UpdatePaR", plate, unit)

    self:Call("UpdateNameText", plate, unit)
    self:Call("UpdateClassification", plate, unit)
    self:Call("UpdateQuest", plate, unit)
    self:Call("UpdateIcons", plate, unit)

    self:ApplyVisualPriority(plate, unit)
end

function GP:RefreshHealthPlate(plate, unit)
    if not plate or not unit then return end

    self:Call("UpdateHealthBar", plate, unit)
    self:Call("UpdatePowerBar", plate, unit)
    self:Call("UpdateCastBar", plate, unit)
    self:Call("UpdateClassPower", plate, unit)

    self:ApplyVisualPriority(plate, unit)
end

function GP:RefreshThreatPlate(plate, unit)
    if not plate or not unit then return end

    self:Call("UpdateThreat", plate, unit)
    self:Call("UpdateTarget", plate, unit)

    self:ApplyVisualPriority(plate, unit)
end

function GP:RefreshRangePlate(plate, unit)
    if not plate or not unit then return end

    self:Call("UpdateRange", plate, unit)
    self:Call("UpdateLOS", plate, unit)

    self:ApplyVisualPriority(plate, unit)
end

function GP:RefreshUnit(unit)
    if not self:IsNameplateUnit(unit) then return end
    if not UnitExists(unit) then return end

    local plate = self:GetPlate(unit)
    if not plate then return end

    self:RefreshStaticPlate(plate, unit)
    self:RefreshHealthPlate(plate, unit)
    self:RefreshThreatPlate(plate, unit)
    self:RefreshRangePlate(plate, unit)
end

function GP:RefreshAll()
    local plates = C_NamePlate.GetNamePlates()
    if not plates then return end

    for _, plate in ipairs(plates) do
        local unit = plate.namePlateUnitToken or plate.unitToken

        if self:IsNameplateUnit(unit) and UnitExists(unit) then
            self.units[unit] = plate
            self.frames[plate] = unit
            self:RefreshUnit(unit)
        end
    end
end

function GP:RefreshAllStatic()
    self:ForEachPlate(function(plate, unit)
        self:RefreshStaticPlate(plate, unit)
    end)
end

function GP:RefreshAllHealth()
    self:ForEachPlate(function(plate, unit)
        self:RefreshHealthPlate(plate, unit)
    end)
end

function GP:RefreshAllThreat()
    self:ForEachPlate(function(plate, unit)
        self:RefreshThreatPlate(plate, unit)
    end)
end

function GP:RefreshAllRange()
    self:ForEachPlate(function(plate, unit)
        self:RefreshRangePlate(plate, unit)
    end)
end

function GP:RefreshPlayerResources()
    self:Call("UpdatePlayerResources")
    self:Call("UpdateComboPoints")
    self:Call("UpdateSoulShards")
    self:Call("UpdateHolyPower")
    self:Call("UpdateRunes")
    self:Call("UpdateChi")
    self:Call("UpdateArcaneCharges")
    self:Call("UpdateEssence")
end

------------------------------------------------------------
-- Nameplate Lifecycle
------------------------------------------------------------

function GP:OnNamePlateAdded(unit)
    if not self:IsNameplateUnit(unit) then return end

    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end

    self.units[unit] = plate
    self.frames[plate] = unit

    self:Call("CreateNameplate", plate, unit)

    self:RefreshStaticPlate(plate, unit)
    self:RefreshHealthPlate(plate, unit)
    self:RefreshThreatPlate(plate, unit)
    self:RefreshRangePlate(plate, unit)

    self:Call("ShowNameplate", plate, unit)
    self:ApplyVisualPriority(plate, unit)
end

function GP:OnNamePlateRemoved(unit)
    if not self:IsNameplateUnit(unit) then return end

    local plate = self.units[unit]
    if not plate then return end

    self:Call("HideNameplate", plate, unit)

    self.frames[plate] = nil
    self.units[unit] = nil
end

------------------------------------------------------------
-- Scheduler / Tickers
------------------------------------------------------------

function GP:GetRangeTickRate()
    return InCombatLockdown() and RANGE_TICK_IC or RANGE_TICK_OOC
end

function GP:GetHealthTickRate()
    return InCombatLockdown() and HEALTH_TICK_IC or HEALTH_TICK_OOC
end

function GP:StopRangeTicker()
    if self.rangeTicker then
        self.rangeTicker:Cancel()
        self.rangeTicker = nil
    end
end

function GP:StopHealthTicker()
    if self.healthTicker then
        self.healthTicker:Cancel()
        self.healthTicker = nil
    end
end

function GP:StopThreatTicker()
    if self.threatTicker then
        self.threatTicker:Cancel()
        self.threatTicker = nil
    end
end

function GP:StartRangeTicker()
    self:StopRangeTicker()

    local rate = self:GetRangeTickRate()

    self.rangeTicker = C_Timer.NewTicker(rate, function()
        GP:RefreshAllRange()
    end)
end

function GP:StartHealthTicker()
    self:StopHealthTicker()

    local rate = self:GetHealthTickRate()

    self.healthTicker = C_Timer.NewTicker(rate, function()
        GP:RefreshAllHealth()
    end)
end

function GP:StartThreatTicker()
    self:StopThreatTicker()

    if not InCombatLockdown() then return end

    self.threatTicker = C_Timer.NewTicker(THREAT_TICK_IC, function()
        GP:RefreshAllThreat()
    end)
end

function GP:RestartDynamicTickers()
    self:StartRangeTicker()
    self:StartHealthTicker()
    self:StartThreatTicker()
end

function GP:StartAnimationTicker()
    if self.animationTicker then return end

    self.animationTicker = C_Timer.NewTicker(0.05, function()
        GP:Call("UpdateAnimations")
    end)
end

function GP:StopAnimationTicker()
    if self.animationTicker then
        self.animationTicker:Cancel()
        self.animationTicker = nil
    end
end

------------------------------------------------------------
-- Compatibility
------------------------------------------------------------

function GP:UpdateAllRangeAndLOS()
    self:RefreshAllRange()
end

------------------------------------------------------------
-- Event Lists
------------------------------------------------------------

local staticEvents = {
    UNIT_NAME_UPDATE = true,
    UNIT_LEVEL = true,
    UNIT_CLASSIFICATION_CHANGED = true,
    UNIT_FACTION = true,
    UNIT_FLAGS = true,
    QUEST_LOG_UPDATE = true,
    QUEST_ACCEPTED = true,
    QUEST_REMOVED = true,
    GROUP_ROSTER_UPDATE = true,
    ZONE_CHANGED_NEW_AREA = true,
}

local healthEvents = {
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
    UNIT_ABSORB_AMOUNT_CHANGED = true,
    UNIT_HEAL_ABSORB_AMOUNT_CHANGED = true,
    UNIT_POWER_UPDATE = true,
    UNIT_MAXPOWER = true,
    UNIT_DISPLAYPOWER = true,
    UNIT_POWER_POINT_CHARGE = true,
    RUNE_POWER_UPDATE = true,
    RUNE_TYPE_UPDATE = true,
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_DELAYED = true,
    UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_UPDATE = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_INTERRUPTIBLE = true,
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
}

local threatEvents = {
    UNIT_THREAT_LIST_UPDATE = true,
    UNIT_THREAT_SITUATION_UPDATE = true,
    PLAYER_TARGET_CHANGED = true,
    UPDATE_MOUSEOVER_UNIT = true,
}

local playerResourceEvents = {
    UNIT_POWER_UPDATE = true,
    UNIT_MAXPOWER = true,
    UNIT_DISPLAYPOWER = true,
    UNIT_POWER_POINT_CHARGE = true,
    RUNE_POWER_UPDATE = true,
    RUNE_TYPE_UPDATE = true,
}

------------------------------------------------------------
-- Event Registration
------------------------------------------------------------

local registeredGameplayEvents = false

local function SafeRegister(event)
    if not Core:IsEventRegistered(event) then
        Core:RegisterEvent(event)
    end
end

local function RegisterGameplayEvents()
    if registeredGameplayEvents then return end
    registeredGameplayEvents = true

    SafeRegister("NAME_PLATE_UNIT_ADDED")
    SafeRegister("NAME_PLATE_UNIT_REMOVED")
    SafeRegister("FORBIDDEN_NAME_PLATE_UNIT_ADDED")
    SafeRegister("FORBIDDEN_NAME_PLATE_UNIT_REMOVED")

    SafeRegister("UNIT_HEALTH")
    SafeRegister("UNIT_MAXHEALTH")
    SafeRegister("UNIT_ABSORB_AMOUNT_CHANGED")
    SafeRegister("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
    SafeRegister("UNIT_POWER_UPDATE")
    SafeRegister("UNIT_MAXPOWER")
    SafeRegister("UNIT_DISPLAYPOWER")
    SafeRegister("UNIT_NAME_UPDATE")
    SafeRegister("UNIT_LEVEL")
    SafeRegister("UNIT_FACTION")
    SafeRegister("UNIT_FLAGS")
    SafeRegister("UNIT_CLASSIFICATION_CHANGED")

    SafeRegister("UNIT_THREAT_LIST_UPDATE")
    SafeRegister("UNIT_THREAT_SITUATION_UPDATE")

    SafeRegister("UNIT_SPELLCAST_START")
    SafeRegister("UNIT_SPELLCAST_STOP")
    SafeRegister("UNIT_SPELLCAST_FAILED")
    SafeRegister("UNIT_SPELLCAST_INTERRUPTED")
    SafeRegister("UNIT_SPELLCAST_DELAYED")
    SafeRegister("UNIT_SPELLCAST_CHANNEL_START")
    SafeRegister("UNIT_SPELLCAST_CHANNEL_UPDATE")
    SafeRegister("UNIT_SPELLCAST_CHANNEL_STOP")
    SafeRegister("UNIT_SPELLCAST_INTERRUPTIBLE")
    SafeRegister("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")

    SafeRegister("PLAYER_TARGET_CHANGED")
    SafeRegister("UPDATE_MOUSEOVER_UNIT")

    SafeRegister("PLAYER_REGEN_DISABLED")
    SafeRegister("PLAYER_REGEN_ENABLED")

    SafeRegister("UNIT_POWER_POINT_CHARGE")
    SafeRegister("RUNE_POWER_UPDATE")
    SafeRegister("RUNE_TYPE_UPDATE")

    SafeRegister("UNIT_PET")
    SafeRegister("UNIT_ENTERED_VEHICLE")
    SafeRegister("UNIT_EXITED_VEHICLE")

    SafeRegister("GROUP_ROSTER_UPDATE")
    SafeRegister("QUEST_ACCEPTED")
    SafeRegister("QUEST_REMOVED")
    SafeRegister("QUEST_LOG_UPDATE")
    SafeRegister("ZONE_CHANGED_NEW_AREA")
    SafeRegister("PVP_TIMER_UPDATE")
end

------------------------------------------------------------
-- Event Router
------------------------------------------------------------

local function ApplyNameplateStacking()
    if not SetCVar then return end

    -- Use Blizzard's protected nameplate mover. GoblinPlates draws taller
    -- plates than the default UI, so give each stacked plate more room.
    pcall(SetCVar, "nameplateMotion", "1")
    pcall(SetCVar, "nameplateOverlapV", "1.30")
    pcall(SetCVar, "nameplateOverlapH", "0.80")
end

Core:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then return end

        GP:Debug("Loaded.")

        RegisterGameplayEvents()

        GP:Call("InitializeConfig")
        GP:Call("InitializeColors")
        GP:Call("InitializeMedia")
        ApplyNameplateStacking()

        C_Timer.After(0, function()
            GP:RefreshAll()
            GP:RefreshPlayerResources()
            GP:RestartDynamicTickers()
        end)

        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        ApplyNameplateStacking()

        C_Timer.After(0, function()
            ApplyNameplateStacking()
            GP:RefreshAll()
        end)

        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        GP:OnNamePlateAdded(...)
        return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
        GP:OnNamePlateRemoved(...)
        return
    end

    if event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" then
        GP:DebugForbiddenNameplate("FORBIDDEN ADD", ...)
        return
    end

    if event == "FORBIDDEN_NAME_PLATE_UNIT_REMOVED" then
        GP:DebugForbiddenNameplate("FORBIDDEN REMOVE", ...)
        return
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        GP:RestartDynamicTickers()
        GP:RefreshAll()
        GP:RefreshPlayerResources()
        return
    end

    local unit = ...

    if event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
        GP:RefreshAllThreat()
        GP:ApplyAllVisualPriority()
        return
    end

    if GP:IsNameplateUnit(unit) then
        local plate = GP:GetPlate(unit)
        if plate then
            if staticEvents[event] then
                GP:RefreshStaticPlate(plate, unit)
            end

            if healthEvents[event] then
                GP:RefreshHealthPlate(plate, unit)
            end

            if threatEvents[event] then
                GP:RefreshThreatPlate(plate, unit)
            end

            GP:ApplyVisualPriority(plate, unit)
        end
    elseif staticEvents[event] then
        GP:RefreshAllStatic()
    end

    if unit == "player" or unit == "pet" or playerResourceEvents[event] then
        GP:RefreshPlayerResources()
    end
end)

------------------------------------------------------------
-- Startup Events Only
------------------------------------------------------------

Core:RegisterEvent("ADDON_LOADED")
Core:RegisterEvent("PLAYER_ENTERING_WORLD")

------------------------------------------------------------
-- Slash Commands
------------------------------------------------------------

SLASH_GOBLINPLATES1 = "/gp"
SLASH_GOBLINPLATES2 = "/goblinplates"

SlashCmdList.GOBLINPLATES = function(msg)
    msg = string.lower(msg or "")
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "debug" then
        GP.debug = not GP.debug
        GP:Print("Debug:", GP.debug and "on" or "off")
        return
    end

    if msg == "refresh" then
        GP:RefreshAll()
        GP:RefreshPlayerResources()
        GP:Print("Refreshed nameplates.")
        return
    end

    if msg == "range" then
        GP:Print("Range ticker:", GP.rangeTicker and "ON" or "OFF")
        GP:Print("Range rate:", GP:GetRangeTickRate())
        GP:Print("Mode:", InCombatLockdown() and "combat" or "out of combat")
        GP:Print("Range grey: 40+")
        GP:Print("Range vanish: 50+")
        GP:Print("Priority: LoS > OOR > Target > Threat > Base")
        GP:Print("Name/Level colors: owned by hostility/difficulty, never greyed by Core")
        return
    end

    if msg == "range on" then
        GP:StartRangeTicker()
        GP:Print("Range ticker ON.")
        return
    end

    if msg == "range off" then
        GP:StopRangeTicker()
        GP:Print("Range ticker OFF.")
        return
    end

    if msg == "sched" or msg == "scheduler" then
        GP:Print("Mode:", InCombatLockdown() and "combat" or "out of combat")
        GP:Print("Range:", GP:GetRangeTickRate())
        GP:Print("Health:", GP:GetHealthTickRate())
        GP:Print("Threat:", InCombatLockdown() and THREAT_TICK_IC or "off")
        return
    end

    if msg == "aura" then
        if GP.GetAuraMode then
            GP:Print("Aura mode:", GP:GetAuraMode())
        else
            GP:Print("Aura mode: unavailable")
        end
        return
    end

    if msg == "aura on" then
        if GP.SetAuraMode then
            GP:SetAuraMode("smart")
            GP:Print("Auras ON. Mode: smart.")
        else
            GP:Print("Aura mode function unavailable.")
        end
        return
    end

    if msg == "aura off" then
        if GP.SetAuraMode then
            GP:SetAuraMode("none")
            GP:Print("Auras OFF.")
        else
            GP:Print("Aura mode function unavailable.")
        end
        return
    end

    if msg == "aura smart" then
        if GP.SetAuraMode then
            GP:SetAuraMode("smart")
            GP:Print("Aura mode: smart.")
        else
            GP:Print("Aura mode function unavailable.")
        end
        return
    end

    if msg == "aura all" then
        if GP.SetAuraMode then
            GP:SetAuraMode("all")
            GP:Print("Aura mode: all.")
        else
            GP:Print("Aura mode function unavailable.")
        end
        return
    end

    if msg == "aura buff" or msg == "aura buffs" then
        if GP.SetAuraMode then
            GP:SetAuraMode("buffs")
            GP:Print("Aura mode: buffs.")
        else
            GP:Print("Aura mode function unavailable.")
        end
        return
    end

    if msg == "aura debuff" or msg == "aura debuffs" then
        if GP.SetAuraMode then
            GP:SetAuraMode("debuffs")
            GP:Print("Aura mode: debuffs.")
        else
            GP:Print("Aura mode function unavailable.")
        end
        return
    end

    if msg == "aura hot" or msg == "aura hots" then
        if GP.SetAuraMode then
            GP:SetAuraMode("hots")
            GP:Print("Aura mode: hots.")
        else
            GP:Print("Aura mode function unavailable.")
        end
        return
    end

    if msg == "anim" then
        if GP.animationTicker then
            GP:StopAnimationTicker()
            GP:Print("Animation ticker OFF.")
        else
            GP:StartAnimationTicker()
            GP:Print("Animation ticker ON.")
        end
        return
    end

    if msg == "class" then
        if not UnitExists("target") then
            GP:Print("No target.")
            return
        end

        GP:Print("Classification:", UnitClassification("target") or "Unknown")
        GP:Print("Level:", UnitLevel("target") or "Unknown")
        GP:Print("Creature:", UnitCreatureType("target") or "Unknown")
        return
    end

    GP:Print("========================================")
    GP:Print(" GoblinPlates " .. (GP.version or "Unknown"))
    GP:Print("========================================")
    GP:Print("General")
    GP:Print("  /gp refresh")
    GP:Print("  /gp debug")
    GP:Print("  /gp sched")
    GP:Print("")
    GP:Print("Range")
    GP:Print("  /gp range")
    GP:Print("  /gp range on")
    GP:Print("  /gp range off")
    GP:Print("")
    GP:Print("Auras")
    GP:Print("  /gp aura")
    GP:Print("  /gp aura on")
    GP:Print("  /gp aura off")
    GP:Print("  /gp aura smart")
    GP:Print("  /gp aura all")
    GP:Print("  /gp aura buff")
    GP:Print("  /gp aura debuff")
    GP:Print("  /gp aura hot")
    GP:Print("")
    GP:Print("Other")
    GP:Print("  /gp anim")
    GP:Print("  /gp class")
    GP:Print("========================================")
end
