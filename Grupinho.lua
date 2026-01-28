-- 1. CONFIGURAÇÕES E MEMÓRIA
if not Grupinho_Config then Grupinho_Config = {} end
if Grupinho_Config.useYell == nil then Grupinho_Config.useYell = true end
if not Grupinho_Config.recallTime then Grupinho_Config.recallTime = 47 end

local readyList = {}
local run, clk, stp = false, 0, {}

local function SaveConfig()
    local point, _, relPoint, x, y = GrupinhoFrame:GetPoint()
    Grupinho_Config.point, Grupinho_Config.relPoint = point, relPoint
    Grupinho_Config.x, Grupinho_Config.y = x, y
end

-- 2. JANELA PRINCIPAL
local f = CreateFrame("Frame", "GrupinhoFrame", UIParent)
f:SetWidth(200)
f:SetHeight(520) 
f:SetPoint("CENTER", 0, 0)
f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() f:StartMoving() end)
f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); SaveConfig() end)
f:Show()

-- Título e Botão Fechar
local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
t:SetPoint("TOP", 0, -15); t:SetText("Addon Grupinho")
local exit = CreateFrame("Button", nil, f, "UIPanelCloseButton")
exit:SetPoint("TOPRIGHT", -2, -2); exit:SetScript("OnClick", function() f:Hide() end)

-- ==========================================================
-- 3. CAMPO DE INSERIR NOMES E GESTÃO (TOPO)
-- ==========================================================
local eb = CreateFrame("EditBox", "GrupinhoInput", f, "InputBoxTemplate")
eb:SetWidth(160); eb:SetHeight(30); eb:SetPoint("TOP", 0, -45); eb:SetAutoFocus(false)

local bG = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bG:SetWidth(80); bG:SetHeight(22); bG:SetPoint("TOPLEFT", 15, -85); bG:SetText("Capturar")
bG:SetScript("OnClick", function()
    local s = ""
    if GetNumRaidMembers() > 0 then
        for i=1, GetNumRaidMembers() do local n = GetRaidRosterInfo(i); if n and n ~= UnitName("player") then s = s .. n .. " " end end
    else
        for i=1, GetNumPartyMembers() do local n = UnitName("party"..i); if n then s = s .. n .. " " end end
    end
    eb:SetText(s)
end)

local bC = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bC:SetWidth(80); bC:SetHeight(22); bC:SetPoint("TOPRIGHT", -15, -85); bC:SetText("Limpar")
bC:SetScript("OnClick", function() eb:SetText("") end)

-- ==========================================================
-- 4. BOTÕES DE AÇÃO (ORDEM SOLICITADA)
-- ==========================================================

local bForm = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bForm:SetWidth(170); bForm:SetHeight(30); bForm:SetPoint("TOP", 0, -125); bForm:SetText("Formar Grupo")
bForm:SetScript("OnClick", function()
    local c = 0
    for n in string.gfind(eb:GetText(), "([^%s,;]+)") do InviteByName(n); c = c + 1 end
    if c > 5 then ConvertToRaid() end
end)

local bRC = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bRC:SetWidth(170); bRC:SetHeight(30); bRC:SetPoint("TOP", 0, -165); bRC:SetText("Todos Prontos?")
bRC:SetScript("OnClick", function() 
    readyList = {} 
    local chan = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
    SendChatMessage("READY CHECK: Usem /train para confirmar!", chan) 
end)

local bRef = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bRef:SetWidth(170); bRef:SetHeight(30); bRef:SetPoint("TOP", 0, -205); bRef:SetText("Iniciar Protocolo")
bRef:SetScript("OnClick", function() LeaveParty(); run, clk, stp = true, 0, {} end)

-- ==========================================================
-- 5. SLIDER (POSIÇÃO INTERMEDIÁRIA)
-- ==========================================================
local sText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sText:SetPoint("TOP", 0, -245)

local slider = CreateFrame("Slider", "GrupinhoSlider", f, "OptionsSliderTemplate")
slider:SetPoint("TOP", 0, -265); slider:SetWidth(160); slider:SetMinMaxValues(30, 55); slider:SetValueStep(1)
slider:SetScript("OnValueChanged", function()
    local v = slider:GetValue(); sText:SetText("Reconvite em: |cffffffff"..v.."s|r")
    Grupinho_Config.recallTime = v
end)

-- ==========================================================
-- 6. BOTÕES FINAIS E CONTROLE
-- ==========================================================

local bMine = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bMine:SetWidth(170); bMine:SetHeight(30); bMine:SetPoint("TOP", 0, -310); bMine:SetText("READY!")
bMine:SetScript("OnClick", function() DoEmote("TRAIN") end)

local cb = CreateFrame("CheckButton", "GrupinhoCheckYell", f, "UICheckButtonTemplate")
cb:SetPoint("TOPLEFT", 20, -350)
getglobal(cb:GetName().."Text"):SetText("Contagem Gritada")
cb:SetScript("OnClick", function() Grupinho_Config.useYell = cb:GetChecked() end)

local bReset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
bReset:SetWidth(170); bReset:SetHeight(30); bReset:SetPoint("TOP", 0, -400); bReset:SetText("RESET")
bReset:SetScript("OnClick", function()
    run, clk, stp = false, 0, {}
    readyList = {}
    if GetNumRaidMembers() > 0 then
        for i=1, 40 do local n = GetRaidRosterInfo(i); if n and n ~= UnitName("player") then UninviteUnit(n) end end
    else
        for i=1, 4 do local n = UnitName("party"..i); if n then UninviteUnit(n) end end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Grupinho:|r Grupo limpo e cronómetro resetado.")
end)

-- ==========================================================
-- 7. ASSINATURA (CANTO INFERIOR DIREITO)
-- ==========================================================
local sig = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
sig:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
sig:SetText("ThePeregris(c)")

-- ==========================================================
-- 8. PAINEL LATERAL E LÓGICA
-- ==========================================================
local side = CreateFrame("Frame", "GrupinhoSide", f)
side:SetWidth(160); side:SetHeight(520); side:SetPoint("LEFT", f, "RIGHT", -5, 0)
side:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
local sList = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sList:SetPoint("TOPLEFT", 12, -40); sList:SetJustifyH("LEFT")

local function UpdateStatusUI()
    local d = ""
    if GetNumRaidMembers() > 0 then
        for i=1, GetNumRaidMembers() do
            local name = GetRaidRosterInfo(i)
            if name then d = d .. (readyList[name] and "|cff00ff00[OK] |r" or "|cffff0000[..] |r") .. name .. "\n" end
        end
    else
        local myN = UnitName("player")
        d = d .. (readyList[myN] and "|cff00ff00[OK] |r" or "|cffff0000[..] |r") .. myN .. "\n"
        for i=1, GetNumPartyMembers() do
            local n = UnitName("party"..i)
            if n then d = d .. (readyList[n] and "|cff00ff00[OK] |r" or "|cffff0000[..] |r") .. n .. "\n" end
        end
    end
    sList:SetText(d)
end

f:SetScript("OnUpdate", function()
    if run then
        clk = clk + arg1
        local target = Grupinho_Config.recallTime
        local chan = (not Grupinho_Config.useYell) and (GetNumRaidMembers() > 0 and "RAID" or "PARTY") or "YELL"
        if clk >= (target - 2) and not stp["ding"] then PlaySound("ReadyCheck"); stp["ding"]=true end
        if clk >= target and not stp["inv"] then
            for n in string.gfind(eb:GetText(), "([^%s,;]+)") do InviteByName(n) end
            SendChatMessage("Reconvidando em: 6...", chan); stp["inv"]=true
        end
        for i=1, 5 do if clk >= (target + i) and not stp[i] then SendChatMessage((6-i).."...", chan); stp[i]=true end end
        if clk >= (target + 6) then SendChatMessage("AVANTE!", chan); DoEmote("CHARGE"); run = false end
    end
    UpdateStatusUI()
end)

f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
f:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if Grupinho_Config.x then f:ClearAllPoints(); f:SetPoint(Grupinho_Config.point, UIParent, Grupinho_Config.relPoint, Grupinho_Config.x, Grupinho_Config.y) end
        slider:SetValue(Grupinho_Config.recallTime)
        cb:SetChecked(Grupinho_Config.useYell)
    elseif event == "CHAT_MSG_TEXT_EMOTE" then
        if arg1 and (string.find(arg1, "train") or string.find(arg1, "comboio")) then readyList[arg2] = true end
    end
end)

SLASH_GRUPINHO1 = "/grupinho"
SlashCmdList["GRUPINHO"] = function() if GrupinhoFrame:IsShown() then f:Hide() else f:Show() end end
