-- GoblinPlates/GoblinPlatesDiagnostics.lua

local addonName, GP = ...

GP = GP or {}
_G.GoblinPlates = GP

GP.Diagnostics = GP.Diagnostics or {}
local D = GP.Diagnostics

D.Interval = 5
D.MaxSavedSessions = 100

local function NewStat()
    return {
        Current = 0,
        Min = nil,
        Max = nil,
        Total = 0,
        Samples = 0,
    }
end

local function UpdateStat(stat, value)
    if value == nil then return end

    stat.Current = value
    stat.Total = stat.Total + value
    stat.Samples = stat.Samples + 1

    if not stat.Min or value < stat.Min then
        stat.Min = value
    end

    if not stat.Max or value > stat.Max then
        stat.Max = value
    end
end

local function Avg(stat)
    if not stat or stat.Samples == 0 then return 0 end
    return stat.Total / stat.Samples
end

local function CopyStat(stat)
    return {
        Current = stat.Current or 0,
        Min = stat.Min or 0,
        Avg = Avg(stat),
        Max = stat.Max or 0,
        Samples = stat.Samples or 0,
    }
end

local function PrintLine(name, stat, suffix)
    suffix = suffix or ""

    GP:Print(string.format(
        "%-20s Cur:%8.2f%s  Min:%8.2f%s  Avg:%8.2f%s  Max:%8.2f%s",
        name,
        stat.Current or 0, suffix,
        stat.Min or 0, suffix,
        Avg(stat), suffix,
        stat.Max or 0, suffix
    ))
end

local function PrintCounter(name, value)
    GP:Print(string.format("%-28s %s", name .. ":", tostring(value or 0)))
end

local function InitDB()
    GoblinPlatesDB = GoblinPlatesDB or {}
    GoblinPlatesDB.Diagnostics = GoblinPlatesDB.Diagnostics or {}
    GoblinPlatesDB.Diagnostics.Sessions = GoblinPlatesDB.Diagnostics.Sessions or {}
    GoblinPlatesDB.Diagnostics.TextLogs = GoblinPlatesDB.Diagnostics.TextLogs or {}
end

local function TrimSessions()
    local sessions = GoblinPlatesDB.Diagnostics.Sessions
    while #sessions > D.MaxSavedSessions do
        table.remove(sessions, 1)
    end

    local logs = GoblinPlatesDB.Diagnostics.TextLogs
    while #logs > D.MaxSavedSessions do
        table.remove(logs, 1)
    end
end

local function ResetStats()
    D.StartTime = GetTime()
    D.SavedThisSession = false

    D.GoblinMemoryKB = NewStat()
    D.TotalAddonMemoryKB = NewStat()

    D.FPS = NewStat()
    D.HomePing = NewStat()
    D.WorldPing = NewStat()
    D.BandwidthIn = NewStat()
    D.BandwidthOut = NewStat()
    D.Nameplates = NewStat()

    D.Counters = {
        RefreshUnit = 0,
        RefreshAll = 0,
        RefreshPlayerResources = 0,

        Health = 0,
        Power = 0,
        Cast = 0,
        Text = 0,
        Threat = 0,
        Target = 0,
        Range = 0,
        Quest = 0,
        Classification = 0,
        ClassPower = 0,
        Auras = 0,

        CreatedNameplates = 0,
        HiddenNameplates = 0,
        ShownNameplates = 0,
    }
end

ResetStats()

function GP:DiagCount(key, amount)
    if not D.Counters then return end
    D.Counters[key] = (D.Counters[key] or 0) + (amount or 1)
end

local function HookMethod(methodName, counterName)
    if type(GP[methodName]) ~= "function" then return end
    if GP["__DiagHooked_" .. methodName] then return end

    local original = GP[methodName]

    GP[methodName] = function(self, ...)
        self:DiagCount(counterName)
        return original(self, ...)
    end

    GP["__DiagHooked_" .. methodName] = true
end

local function InstallHooks()
    HookMethod("RefreshUnit", "RefreshUnit")
    HookMethod("RefreshAll", "RefreshAll")
    HookMethod("RefreshPlayerResources", "RefreshPlayerResources")

    HookMethod("UpdateHealthBar", "Health")
    HookMethod("UpdatePowerBar", "Power")
    HookMethod("UpdateCastBar", "Cast")
    HookMethod("UpdateNameText", "Text")
    HookMethod("UpdateThreat", "Threat")
    HookMethod("UpdateTarget", "Target")
    HookMethod("UpdateRange", "Range")
    HookMethod("UpdateQuest", "Quest")
    HookMethod("UpdateClassification", "Classification")
    HookMethod("UpdateClassPower", "ClassPower")
    HookMethod("UpdateAuras", "Auras")

    HookMethod("CreateNameplate", "CreatedNameplates")
    HookMethod("ShowNameplate", "ShownNameplates")
    HookMethod("HideNameplate", "HiddenNameplates")
end

local function GetTotalAddonMemory()
    local total = 0
    local count = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or GetNumAddOns()

    for i = 1, count do
        total = total + (GetAddOnMemoryUsage(i) or 0)
    end

    return total
end

local function Sample()
    UpdateStat(D.FPS, GetFramerate())

    UpdateAddOnMemoryUsage()
    UpdateStat(D.GoblinMemoryKB, GetAddOnMemoryUsage(addonName))
    UpdateStat(D.TotalAddonMemoryKB, GetTotalAddonMemory())

    local inKB, outKB, home, world = GetNetStats()
    UpdateStat(D.BandwidthIn, inKB)
    UpdateStat(D.BandwidthOut, outKB)
    UpdateStat(D.HomePing, home)
    UpdateStat(D.WorldPing, world)

    local plates = C_NamePlate.GetNamePlates()
    UpdateStat(D.Nameplates, plates and #plates or 0)
end

local function BuildTextLog(session)
    local lines = {}

    local function add(line)
        table.insert(lines, line)
    end

    add("========================================")
    add(" GoblinPlates Diagnostics")
    add("========================================")
    add("Date: " .. tostring(session.Date))
    add("Addon Version: " .. tostring(session.AddonVersion))
    add("WoW Build: " .. tostring(session.WoWBuild))
    add(string.format("Duration: %.1f minutes", (session.DurationSeconds or 0) / 60))
    add("")

    add("Performance")
    add("----------------------------------------")
    add(string.format("FPS Avg: %.2f | Min: %.2f | Max: %.2f", session.FPS.Avg, session.FPS.Min, session.FPS.Max))
    add(string.format("GoblinPlates Memory Avg: %.2f KB | Max: %.2f KB", session.GoblinMemoryKB.Avg, session.GoblinMemoryKB.Max))
    add(string.format("Total Addon Memory Avg: %.2f KB | Max: %.2f KB", session.TotalAddonMemoryKB.Avg, session.TotalAddonMemoryKB.Max))
    add(string.format("Nameplates Avg: %.2f | Max: %.2f", session.Nameplates.Avg, session.Nameplates.Max))
    add(string.format("Home Ping Avg: %.2f ms | World Ping Avg: %.2f ms", session.HomePingMS.Avg, session.WorldPingMS.Avg))
    add("")

    add("Work Counters")
    add("----------------------------------------")

    for k, v in pairs(session.Counters or {}) do
        add(k .. ": " .. tostring(v))
    end

    add("========================================")

    return table.concat(lines, "\n")
end

function GP:SaveDiagnosticsSession(manual)
    InitDB()

    if D.SavedThisSession and not manual then
        return
    end

    Sample()

    local _, _, _, build = GetBuildInfo()

    local session = {
        Date = date("%Y-%m-%d %H:%M:%S"),
        Manual = manual and true or false,

        AddonVersion = GP.version or "unknown",
        WoWBuild = build or "unknown",

        DurationSeconds = GetTime() - D.StartTime,

        FPS = CopyStat(D.FPS),
        GoblinMemoryKB = CopyStat(D.GoblinMemoryKB),
        TotalAddonMemoryKB = CopyStat(D.TotalAddonMemoryKB),

        HomePingMS = CopyStat(D.HomePing),
        WorldPingMS = CopyStat(D.WorldPing),
        BandwidthInKBs = CopyStat(D.BandwidthIn),
        BandwidthOutKBs = CopyStat(D.BandwidthOut),
        Nameplates = CopyStat(D.Nameplates),

        Counters = {
            RefreshUnit = D.Counters.RefreshUnit or 0,
            RefreshAll = D.Counters.RefreshAll or 0,
            RefreshPlayerResources = D.Counters.RefreshPlayerResources or 0,

            UpdateHealthBar = D.Counters.Health or 0,
            UpdatePowerBar = D.Counters.Power or 0,
            UpdateCastBar = D.Counters.Cast or 0,
            UpdateNameText = D.Counters.Text or 0,
            UpdateThreat = D.Counters.Threat or 0,
            UpdateTarget = D.Counters.Target or 0,
            UpdateRange = D.Counters.Range or 0,
            UpdateQuest = D.Counters.Quest or 0,
            UpdateClassification = D.Counters.Classification or 0,
            UpdateClassPower = D.Counters.ClassPower or 0,
            UpdateAuras = D.Counters.Auras or 0,

            CreatedNameplates = D.Counters.CreatedNameplates or 0,
            ShownNameplates = D.Counters.ShownNameplates or 0,
            HiddenNameplates = D.Counters.HiddenNameplates or 0,
        },
    }

    session.TextLog = BuildTextLog(session)

    table.insert(GoblinPlatesDB.Diagnostics.Sessions, session)
    table.insert(GoblinPlatesDB.Diagnostics.TextLogs, session.TextLog)

    TrimSessions()

    D.SavedThisSession = true

    if manual then
        GP:Print("Diagnostics session saved to SavedVariables.")
        GP:Print("Review after reload/logout in WTF/Account/.../SavedVariables/GoblinPlates.lua")
    end
end

function GP:PrintDiagnostics()
    Sample()

    GP:Print("------------------------------------")
    GP:Print(" GoblinPlates Diagnostics")
    GP:Print("------------------------------------")

    GP:Print(string.format(
        "Session: %.1f minutes",
        (GetTime() - D.StartTime) / 60
    ))

    PrintLine("FPS", D.FPS)
    PrintLine("Goblin Memory", D.GoblinMemoryKB, " KB")
    PrintLine("Total Addon Mem", D.TotalAddonMemoryKB, " KB")
    PrintLine("Home Ping", D.HomePing, " ms")
    PrintLine("World Ping", D.WorldPing, " ms")
    PrintLine("Bandwidth In", D.BandwidthIn, " KB/s")
    PrintLine("Bandwidth Out", D.BandwidthOut, " KB/s")
    PrintLine("Nameplates", D.Nameplates)

    GP:Print("------------------------------------")
    GP:Print(" GoblinPlates Work Counters")
    GP:Print("------------------------------------")

    PrintCounter("RefreshUnit", D.Counters.RefreshUnit)
    PrintCounter("RefreshAll", D.Counters.RefreshAll)
    PrintCounter("RefreshPlayerResources", D.Counters.RefreshPlayerResources)

    GP:Print("")

    PrintCounter("UpdateHealthBar", D.Counters.Health)
    PrintCounter("UpdatePowerBar", D.Counters.Power)
    PrintCounter("UpdateCastBar", D.Counters.Cast)
    PrintCounter("UpdateNameText", D.Counters.Text)
    PrintCounter("UpdateThreat", D.Counters.Threat)
    PrintCounter("UpdateTarget", D.Counters.Target)
    PrintCounter("UpdateRange", D.Counters.Range)
    PrintCounter("UpdateQuest", D.Counters.Quest)
    PrintCounter("UpdateClassification", D.Counters.Classification)
    PrintCounter("UpdateClassPower", D.Counters.ClassPower)
    PrintCounter("UpdateAuras", D.Counters.Auras)

    GP:Print("")

    PrintCounter("CreatedNameplates", D.Counters.CreatedNameplates)
    PrintCounter("ShownNameplates", D.Counters.ShownNameplates)
    PrintCounter("HiddenNameplates", D.Counters.HiddenNameplates)

    GP:Print("------------------------------------")
end

function GP:PrintDiagnosticsHistory()
    InitDB()

    local sessions = GoblinPlatesDB.Diagnostics.Sessions
    local count = #sessions

    GP:Print("------------------------------------")
    GP:Print(" GoblinPlates Saved Sessions:", count)
    GP:Print("------------------------------------")

    if count == 0 then
        GP:Print("No saved diagnostic sessions yet.")
        GP:Print("------------------------------------")
        return
    end

    local startIndex = math.max(1, count - 4)

    for i = startIndex, count do
        local s = sessions[i]

        GP:Print(string.format(
            "#%d %s | v%s | %.1f min | FPS %.1f avg / %.1f min | GP Mem %.1f KB avg / %.1f KB max | Addon Mem %.1f KB max | Plates %.0f max",
            i,
            s.Date or "?",
            s.AddonVersion or "?",
            (s.DurationSeconds or 0) / 60,
            s.FPS and s.FPS.Avg or 0,
            s.FPS and s.FPS.Min or 0,
            s.GoblinMemoryKB and s.GoblinMemoryKB.Avg or 0,
            s.GoblinMemoryKB and s.GoblinMemoryKB.Max or 0,
            s.TotalAddonMemoryKB and s.TotalAddonMemoryKB.Max or 0,
            s.Nameplates and s.Nameplates.Max or 0
        ))
    end

    GP:Print("------------------------------------")
end

function GP:PrintLastDiagnosticsTextLog()
    InitDB()

    local logs = GoblinPlatesDB.Diagnostics.TextLogs
    local last = logs and logs[#logs]

    if not last then
        GP:Print("No diagnostics text log saved yet.")
        return
    end

    for line in string.gmatch(last, "([^\n]*)\n?") do
        if line and line ~= "" then
            GP:Print(line)
        end
    end
end

function GP:ResetDiagnostics()
    ResetStats()
    Sample()
    GP:Print("Diagnostics reset.")
end

local f = CreateFrame("Frame")
local ticker

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        InitDB()
        InstallHooks()

        if not ticker then
            Sample()
            ticker = C_Timer.NewTicker(D.Interval, function()
                Sample()
            end)
        end

    elseif event == "PLAYER_LOGOUT" then
        GP:SaveDiagnosticsSession(false)
    end
end)

local OldSlash = SlashCmdList.GOBLINPLATES

SlashCmdList.GOBLINPLATES = function(msg)
    msg = string.lower(msg or "")

    if msg == "diag" then
        GP:PrintDiagnostics()
        return

    elseif msg == "diag reset" then
        GP:ResetDiagnostics()
        return

    elseif msg == "diag save" then
        GP:SaveDiagnosticsSession(true)
        return

    elseif msg == "diag history" then
        GP:PrintDiagnosticsHistory()
        return

    elseif msg == "diag text" then
        GP:PrintLastDiagnosticsTextLog()
        return
    end

    if OldSlash then
        OldSlash(msg)
    end
end