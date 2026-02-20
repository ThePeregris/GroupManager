-- ==========================================================
-- ADDON: InviteManager
-- VERSION: 1.0 (Release)
-- AUTHORS: Bannion & ThePeregris
-- TARGET: Turtle WoW 1.12.1 / Lua 5.0
-- ==========================================================

-- =========================
-- SAVED CONFIG
-- =========================
if not InviteManager_Config then InviteManager_Config = {} end
if InviteManager_Config.useYell == nil then InviteManager_Config.useYell = false end
if not InviteManager_Config.recallTime then InviteManager_Config.recallTime = 47 end

-- =========================
-- STATE MACHINE
-- =========================
local STATE = "IDLE"          -- IDLE / COUNTDOWN / INVITING
local timer = 0
local steps = {}

-- =========================
-- DATA
-- =========================
local InviteQueue = {}
local inviteTicker = 0
local readyList = {}

-- =========================
-- UTIL
-- =========================
local function IsLeader()
    if GetNumRaidMembers() > 0 then
        return IsRaidLeader()
    end
    return UnitIsPartyLeader("player")
end

local function Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00InviteManager:|r "..text)
end

-- =========================
-- QUEUE SYSTEM
-- =========================
local function Queue_Clear()
    InviteQueue = {}
end

local function Queue_Fill(text)
    local n
    for n in string.gfind(text, "([^%s,;]+)") do
        table.insert(InviteQueue, n)
    end
end

local function Queue_Update(elapsed)
    if table.getn(InviteQueue) == 0 then return end

    inviteTicker = inviteTicker + elapsed
    if inviteTicker >= 0.25 then
        local name = table.remove(InviteQueue, 1)
        InviteByName(name)
        inviteTicker = 0
    end
end

-- =========================
-- GROUP HELPERS
-- =========================
local function MassKick()
    local i, n
    if GetNumRaidMembers() > 0 then
        for i=1,40 do
            n = GetRaidRosterInfo(i)
            if n and n ~= UnitName("player") then
                UninviteByName(n)
            end
        end
    else
        for i=1,4 do
            n = UnitName("party"..i)
            if n then UninviteByName(n) end
        end
    end
end

-- =========================
-- CORE ACTIONS
-- =========================
function InviteManager_StartInvite()
    if not IsLeader() then
        Msg("Only the leader can invite.")
        return
    end
    if STATE ~= "IDLE" then return end

    Queue_Clear()
    Queue_Fill(InviteManagerInput:GetText())
    STATE = "INVITING"
    Msg("Sending invites...")
end

function InviteManager_StartProtocol()
    if not IsLeader() then
        Msg("Only the leader can start protocol.")
        return
    end
    if STATE ~= "IDLE" then return end

    MassKick()
    LeaveParty()

    Queue_Clear()
    readyList = {}
    steps = {}
    timer = 0

    STATE = "COUNTDOWN"
    Msg("Protocol started.")
end

function InviteManager_Reset()
    STATE = "IDLE"
    timer = 0
    steps = {}
    Queue_Clear()
    readyList = {}
    Msg("Reset complete.")
end

-- =========================
-- UI
-- =========================
local f = CreateFrame("Frame", "InviteManagerFrame", UIParent)
f:SetWidth(200); f:SetHeight(520)
f:SetPoint("CENTER", 0, 0)
f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
f:SetMovable(true); f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() f:StartMoving() end)
f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
f:Show()

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -14)
title:SetText("InviteManager")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

local eb = CreateFrame("EditBox", "InviteManagerInput", f, "InputBoxTemplate")
eb:SetWidth(160); eb:SetHeight(30)
eb:SetPoint("TOP", 0, -45)
eb:SetAutoFocus(false)

local bInvite = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bInvite:SetWidth(170); bInvite:SetHeight(30)
bInvite:SetPoint("TOP", 0, -90)
bInvite:SetText("Invite")
bInvite:SetScript("OnClick", InviteManager_StartInvite)

local bStart = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bStart:SetWidth(170); bStart:SetHeight(30)
bStart:SetPoint("TOP", 0, -130)
bStart:SetText("Start Protocol")
bStart:SetScript("OnClick", InviteManager_StartProtocol)

local bReset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bReset:SetWidth(170); bReset:SetHeight(30)
bReset:SetPoint("TOP", 0, -170)
bReset:SetText("Reset")
bReset:SetScript("OnClick", InviteManager_Reset)

-- =========================
-- ONUPDATE (FSM)
-- =========================
f:SetScript("OnUpdate", function()
    local e = arg1

    if STATE == "INVITING" then
        Queue_Update(e)
        if table.getn(InviteQueue) == 0 then
            if GetNumPartyMembers() > 0 and GetNumRaidMembers() == 0 then
                ConvertToRaid()
            end
            STATE = "IDLE"
        end

    elseif STATE == "COUNTDOWN" then
        timer = timer + e
        local t = InviteManager_Config.recallTime
        local chan = InviteManager_Config.useYell and "YELL" or ((GetNumRaidMembers() > 0) and "RAID" or "PARTY")

        if timer >= t and not steps.fire then
            Queue_Fill(InviteManagerInput:GetText())
            SendChatMessage("Re-inviting...", chan)
            STATE = "INVITING"
            steps.fire = true
        end
    end
end)

-- =========================
-- READY CHECK
-- =========================
f:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
f:SetScript("OnEvent", function()
    if event == "CHAT_MSG_TEXT_EMOTE" then
        if arg1 and string.find(arg1, "train") then
            readyList[arg2] = true
        end
    end
end)

-- =========================
-- SLASH COMMAND
-- =========================
SLASH_INVITEMANAGER1 = "/imap"
SlashCmdList["INVITEMANAGER"] = function(msg)
    if msg == "invite" then
        InviteManager_StartInvite()
    elseif msg == "start" then
        InviteManager_StartProtocol()
    elseif msg == "reset" then
        InviteManager_Reset()
    else
        if f:IsShown() then f:Hide() else f:Show() end
    end
end
