-- 1. MEMÓRIA DE POSIÇÃO
if not FGA_Config then FGA_Config = {} end

local function SavePosition()
    local point, _, relativePoint, xOfs, yOfs = FGAMainFrame:GetPoint()
    FGA_Config.point = point
    FGA_Config.relativePoint = relativePoint
    FGA_Config.x = xOfs
    FGA_Config.y = yOfs
end

-- 2. JANELA PRINCIPAL (CONTROLO)
local f = CreateFrame("Frame", "FGAMainFrame", UIParent)
f:SetWidth(200)
f:SetHeight(280)
f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() FGAMainFrame:StartMoving() end)
f:SetScript("OnDragStop", function() FGAMainFrame:StopMovingOrSizing(); SavePosition() end)
f:Hide()

-- 3. BOTÃO DE SAÍDA (EXIT)
local exitBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
exitBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
exitBtn:SetScript("OnClick", function() f:Hide() end)

-- 4. PAINEL LATERAL (LISTA)
local side = CreateFrame("Frame", "FGASidePanel", f)
side:SetWidth(150)
side:SetHeight(280)
side:SetPoint("LEFT", f, "RIGHT", -5, 0)
side:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

local sideTitle = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sideTitle:SetPoint("TOP", 0, -15)
sideTitle:SetText("LISTA (0)")

local listText = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
listText:SetPoint("TOPLEFT", 15, -40)
listText:SetJustifyH("LEFT")
listText:SetText("")

-- 5. CAIXA DE TEXTO E ATUALIZAÇÃO
local eb = CreateFrame("EditBox", "FGAInput", f, "InputBoxTemplate")
eb:SetWidth(160)
eb:SetHeight(30)
eb:SetPoint("TOP", 0, -45)
eb:SetAutoFocus(false)

local function UpdateSideList()
    local text = eb:GetText()
    local display, count = "", 0
    for n in string.gfind(text, "([^%s,;]+)") do
        display = display .. "|cff00ff00>|r " .. n .. "\n"
        count = count + 1
    end
    listText:SetText(display)
    sideTitle:SetText("LISTA ("..count..")")
end

eb:SetScript("OnTextChanged", function() UpdateSideList() end)

-- 6. EVENTOS E CARREGAMENTO
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if FGA_Config.x then
            f:ClearAllPoints()
            f:SetPoint(FGA_Config.point, UIParent, FGA_Config.relativePoint, FGA_Config.x, FGA_Config.y)
        else
            f:SetPoint("CENTER", 0, 0)
        end
        UpdateSideList()
    end
end)

-- 7. BOTÕES DE AÇÃO
local function GetNames()
    local names = {}
    for n in string.gfind(eb:GetText(), "([^%s,;]+)") do table.insert(names, n) end
    return names
end

-- Capturar
local bGrab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bGrab:SetWidth(80); bGrab:SetHeight(22); bGrab:SetPoint("TOPLEFT", 15, -80); bGrab:SetText("Capturar")
bGrab:SetScript("OnClick", function()
    local nStr = ""
    local nR, nP = GetNumRaidMembers(), GetNumPartyMembers()
    if nR > 0 then
        for i=1, nR do
            local n = GetRaidRosterInfo(i)
            if n and n ~= UnitName("player") then nStr = nStr .. n .. " " end
        end
    else
        for i=1, nP do
            local n = UnitName("party"..i)
            if n then nStr = nStr .. n .. " " end
        end
    end
    eb:SetText(nStr)
end)

-- Limpar
local bClear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bClear:SetWidth(80); bClear:SetHeight(22); bClear:SetPoint("TOPRIGHT", -15, -80); bClear:SetText("Limpar")
bClear:SetScript("OnClick", function() eb:SetText("") end)

-- Formar
local bForm = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bForm:SetWidth(170); bForm:SetHeight(28); bForm:SetPoint("TOP", 0, -115); bForm:SetText("Formar Grupo")
bForm:SetScript("OnClick", function()
    local list = GetNames()
    for _, n in ipairs(list) do InviteByName(n) end
    if table.getn(list) > 5 then ConvertToRaid() end
end)

-- Refresh (53s)
local running, clock, steps = false, 0, {}
local bRef = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bRef:SetWidth(170); bRef:SetHeight(28); bRef:SetPoint("TOP", 0, -150); bRef:SetText("Refresh (53s)")
bRef:SetScript("OnClick", function()
    LeaveParty(); running, clock, steps = true, 0, {}
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FGA:|r Refresh em curso.")
end)

bRef:SetScript("OnUpdate", function()
    if running then
        clock = clock + arg1
        if clock >= 45 and not steps[45] then PlaySound("ReadyCheck"); steps[45]=true end
        if clock >= 47 and not steps[47] then
            for _, n in ipairs(GetNames()) do InviteByName(n) end
            SendChatMessage("Reconvidando em: 6...", "YELL"); steps[47]=true
        end
        for i=48, 52 do
            if clock >= i and not steps[i] then SendChatMessage((53-i).."...", "YELL"); steps[i]=true end
        end
        if clock >= 53 then
            SendChatMessage("AVANTE!", "YELL"); DoEmote("CHARGE"); running = false
        end
    end
end)

-- Ready Check
local bReady = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bReady:SetWidth(170); bReady:SetHeight(28); bReady:SetPoint("TOP", 0, -185); bReady:SetText("Ready Check")
bReady:SetScript("OnClick", function() SendChatMessage("FGA: Usem /train!", "PARTY") end)

-- 8. COMANDOS SLASH
SLASH_FGA1 = "/fga"
SLASH_FGA2 = "/apf"
SlashCmdList["FGA"] = function()
    if FGAMainFrame:IsShown() then FGAMainFrame:Hide() else FGAMainFrame:Show() end
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00FGA:|r Comandante Bannion no comando. Use /fga ou /apf.")