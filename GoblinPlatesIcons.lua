-- GoblinPlates/GoblinPlatesIcons.lua

local addonName, GP = ...
GP = GP or {}
_G.GoblinPlates = GP

local PVP_ICON_SIZE = 40
local HONOR_ICON_SIZE = 25
local CLASS_ICON_SIZE = 16

local PVP_TEXTURES = {
    Horde = "Interface\\AddOns\\GoblinPlates\\media\\faction\\Horde.tga",
    Alliance = "Interface\\AddOns\\GoblinPlates\\media\\faction\\Alliance.tga",
}

local CLASS_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

------------------------------------------------------------
-- Honor Badge Helper
------------------------------------------------------------

local function GetHonorBadgeTexture(honorLevel)
    if not honorLevel then return nil end

    if C_PvP and C_PvP.GetHonorRewardInfo then
        local ok, a, b, c, d = pcall(C_PvP.GetHonorRewardInfo, honorLevel)

        if ok then
            if type(a) == "table" then
                return a.badgeFileDataID
                    or a.iconFileDataID
                    or a.texture
                    or a.icon
            end

            local values = {a, b, c, d}
            for _, value in ipairs(values) do
                if type(value) == "number" and value > 1000 then
                    return value
                elseif type(value) == "string" then
                    return value
                end
            end
        end
    end

    if GetPVPHonorRewardInfo then
        local ok, a, b, c, d = pcall(GetPVPHonorRewardInfo, honorLevel)

        if ok then
            local values = {a, b, c, d}
            for _, value in ipairs(values) do
                if type(value) == "number" and value > 1000 then
                    return value
                elseif type(value) == "string" then
                    return value
                end
            end
        end
    end

    return nil
end

------------------------------------------------------------
-- Create
------------------------------------------------------------

function GP:CreateIcons(frame)
    if not frame then return end
    if not frame.HealthBar then return end

    if not frame.PvPIcon then
        local pvp = frame:CreateTexture(nil, "OVERLAY")
        pvp:SetSize(PVP_ICON_SIZE, PVP_ICON_SIZE)
        pvp:SetPoint("RIGHT", frame.HealthBar, "LEFT", -2, -10)
        pvp:Hide()

        frame.PvPIcon = pvp
    end

    if not frame.HonorIcon then
        local honor = frame:CreateTexture(nil, "OVERLAY")
        honor:SetSize(HONOR_ICON_SIZE, HONOR_ICON_SIZE)
        honor:SetPoint("LEFT", frame.HealthBar, "RIGHT", 0, -4)
        honor:Hide()

        frame.HonorIcon = honor
    end

    if not frame.ClassIcon and frame.NameText then
        local classIcon = frame:CreateTexture(nil, "OVERLAY")
        classIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
        classIcon:SetPoint("LEFT", frame.NameText, "RIGHT", 5, 0)
        classIcon:SetTexture(CLASS_TEXTURE)
        classIcon:Hide()

        frame.ClassIcon = classIcon
    end
end

------------------------------------------------------------
-- Update
------------------------------------------------------------

function GP:UpdateIcons(plate, unit)
    if not plate or not unit then return end

    local frame = plate.GoblinPlate
    if not frame then return end

    if not frame.PvPIcon or not frame.HonorIcon or not frame.ClassIcon then
        self:CreateIcons(frame)
    end

    local pvpIcon = frame.PvPIcon
    local honorIcon = frame.HonorIcon
    local classIcon = frame.ClassIcon

    if pvpIcon then pvpIcon:Hide() end
    if honorIcon then honorIcon:Hide() end
    if classIcon then classIcon:Hide() end

    if not UnitIsPlayer(unit) then return end

    --------------------------------------------------------
    -- Class Icon: players only
    --------------------------------------------------------

    if classIcon then
        local _, classFile = UnitClass(unit)
        local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]

        if coords then
            classIcon:SetTexture(CLASS_TEXTURE)
            classIcon:SetTexCoord(unpack(coords))
            classIcon:Show()
        end
    end

    --------------------------------------------------------
    -- PvP + Honor: only if PvP flagged
    --------------------------------------------------------

    if not UnitIsPVP(unit) then return end

    local faction = UnitFactionGroup(unit)

    if pvpIcon and faction and PVP_TEXTURES[faction] then
        pvpIcon:SetTexture(PVP_TEXTURES[faction])
        pvpIcon:Show()
    end

    if honorIcon and UnitHonorLevel then
        local honorLevel = UnitHonorLevel(unit)
        local texture = GetHonorBadgeTexture(honorLevel)

        if texture then
            honorIcon:SetTexture(texture)
            honorIcon:Show()
        end
    end
end
