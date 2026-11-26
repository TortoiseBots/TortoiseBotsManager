-- TortoiseBotsManager/Armory.lua
-- Gear readiness overview (Armory tab) and the small model that feeds the
-- bot panel's Gear tab dots and stats sheet.
--
-- Everything shown here comes from the server's ARMORY snapshot; the addon
-- keeps no caps or item rules of its own beyond formatting.

local TB = TortoiseBots
local C = TB.C or {}
local COL = C.COLOR or {}

local ROW_H = 24
local ROW_N = 10
local STRIP_W = 9
local STRIP_GAP = 1
local STRIP_TEXT_W = 452

local CAP = "armory"

function TB.HasArmoryCapability()
    return TB.HasServerCapability and TB.HasServerCapability(CAP) or false
end

-- ── protocol model ──────────────────────────────────────────────────────────
local armory = { rows = {}, order = {} }
local requests = {}

function TB.NoteArmoryRequest(name)
    table.insert(requests, { full = not name })
end

-- Pops the oldest request so a full list replaces the view and a one-bot
-- answer only updates that row.
function TB.ArmoryRequestMode()
    local request = table.remove(requests, 1)
    if request then return request.full end
    return true
end

function TB.RequestArmory(name)
    if not TB.HasArmoryCapability() then return false end
    name = name and TB.NormalizeName(name) or nil
    TB.NoteArmoryRequest(name)
    if name then return TB.SendBotCommand("armory " .. name) end
    return TB.SendBotCommand("armory")
end

local function armoryIndex(name)
    for i, row in ipairs(armory.order) do
        if row.name == name then return i end
    end
    return nil
end

function TB.SetArmory(rows, full)
    rows = rows or {}
    if full then
        for key in pairs(armory.rows) do armory.rows[key] = nil end
        armory.order = {}
    end
    local added = 0
    for _, row in ipairs(rows) do
        if row and row.name then
            local at = armoryIndex(row.name)
            if at then
                armory.order[at] = row
            else
                table.insert(armory.order, row)
            end
            armory.rows[row.name] = row
            added = added + 1
        end
    end
    TB.armory = armory
    if full and TB.SetStatus then
        TB.SetStatus("Armory updated · " .. table.getn(armory.order) .. " bots", "ok")
    end
    if TB.RefreshArmoryView then TB.RefreshArmoryView() end
    if TB.RefreshBotPanel then TB.RefreshBotPanel() end
    return added
end

function TB.ResetArmory()
    for key in pairs(armory.rows) do armory.rows[key] = nil end
    armory.order = {}
end

function TB.NoteArmoryCaps()
    if TB.HasArmoryCapability() then return end
    requests = {}
    TB.ResetArmory()
    if TB.RefreshArmoryView then TB.RefreshArmoryView() end
    if TB.UpdateRaidTab then TB.UpdateRaidTab() end
end

function TB.GetArmoryRow(name)
    name = name and TB.NormalizeName(name) or nil
    return name and armory.rows[name] or nil
end

function TB.GetArmoryRows()
    return armory.order
end

local function parseNumber(value)
    local n = tonumber(value)
    if not n then return 0 end
    return n
end

local function parseStats(text)
    local stats = {}
    if not text or text == "-" or text == "" then return stats, false end
    for pair in string.gfind(text, "[^,]+") do
        local _, _, key, value = string.find(pair, "^%s*([%w_]+)=(.-)%s*$")
        if key then stats[string.lower(key)] = parseNumber(value) end
    end
    return stats, true
end

function TB.ParseArmoryRow(fields)
    local name = fields[1] and TB.NormalizeName(fields[1]) or nil
    if not name or name == "" or table.getn(fields) < 16 then return nil end
    local role = fields[6] and string.lower(fields[6]) or "-"
    if role == "-" or role == "" then role = nil end
    local spec = fields[7]
    if not spec or spec == "-" or spec == "" then spec = nil end
    local resists = {}
    local text = fields[13] or ""
    for part in string.gfind(text, "[^+]+") do
        table.insert(resists, parseNumber(part))
    end
    while table.getn(resists) < 5 do table.insert(resists, 0) end
    local stats, hasStats = parseStats(fields[16])
    return {
        name = name,
        classId = parseNumber(fields[2]),
        level = parseNumber(fields[3]),
        online = fields[4] == "1",
        inGroup = fields[5] == "1",
        role = role,
        spec = spec,
        avgIlvl = parseNumber(fields[8]),
        meleeHit = parseNumber(fields[9]),
        rangedHit = parseNumber(fields[10]),
        spellHit = parseNumber(fields[11]),
        defense = parseNumber(fields[12]),
        resists = resists,
        hitCap = parseNumber(fields[14]),
        defCap = parseNumber(fields[15]),
        stats = stats,
        hasStats = hasStats,
        eq = {},
    }
end

function TB.ParseArmoryEquipment(text)
    local slots = {}
    if not text or text == "-" or text == "" then return slots end
    for entry in string.gfind(text, "[^,]+") do
        local _, _, slot, itemId, enchantId, miss = string.find(entry, "^(%d+):(%d+):(%d+):(%d+)$")
        if slot then
            slots[tonumber(slot)] = {
                itemId = tonumber(itemId),
                enchantId = tonumber(enchantId),
                miss = tonumber(miss),
            }
        end
    end
    return slots
end

-- ── slot labels and miss policy ────────────────────────────────────────────
local SLOT_LABELS = {}
local SLOT_ORDER = { 0, 1, 2, 14, 4, 8, 9, 5, 6, 7, 10, 11, 12, 13, 15, 16, 17 }

for _, def in ipairs(C.GEAR_LEFT or {}) do SLOT_LABELS[def.slot] = def.label end
for _, def in ipairs(C.GEAR_RIGHT or {}) do SLOT_LABELS[def.slot] = def.label end
for _, def in ipairs(C.GEAR_BOTTOM or {}) do SLOT_LABELS[def.slot] = def.label end

function TB.ArmorySlotLabel(slot)
    return SLOT_LABELS[slot] or ("Slot " .. tostring(slot))
end

function TB.ArmoryStripSlots()
    return SLOT_ORDER
end

-- A slot with no item and no miss is deliberately unused (two-hander in the
-- main hand, a ranged slot the class cannot fill): it is not drawn.
function TB.ArmorySlotShown(row, slot)
    local entry = row and row.eq and row.eq[slot]
    if not entry then return false end
    return entry.itemId > 0 or (entry.miss or 0) > 0
end

local function slotShortReason(slot, miss)
    local label = TB.ArmorySlotLabel(slot)
    if miss == 2 then return label .. " empty" end
    if slot == 5 then return "Belt enchant" end
    return label .. " enchant"
end

-- The missing-gear list in slot order. Each entry carries the slot for dots
-- and the words the Gear tab and the Armory strip share.
function TB.ArmoryMissing(row)
    local missing = {}
    if not row or not row.online or row.eqKnown == false then return missing end
    for _, slot in ipairs(SLOT_ORDER) do
        local entry = row.eq and row.eq[slot]
        local miss = entry and entry.miss or 0
        if miss > 0 then
            table.insert(missing, {
                slot = slot,
                itemId = entry and entry.itemId or 0,
                miss = miss,
                label = TB.ArmorySlotLabel(slot),
                reason = slotShortReason(slot, miss),
            })
        end
    end
    return missing
end

function TB.ArmoryMissingText(row)
    local missing = TB.ArmoryMissing(row)
    if table.getn(missing) == 0 then return "Nothing missing" end
    local words = {}
    for _, entry in ipairs(missing) do table.insert(words, entry.reason) end
    return "Missing: " .. table.concat(words, ", ")
end

function TB.ArmoryProblemCount(row)
    return table.getn(TB.ArmoryMissing(row))
end

-- ── caps and roles ──────────────────────────────────────────────────────────
function TB.ArmoryRoleLabel(role)
    if role == "tank" then return "Tank" end
    if role == "healer" then return "Healer" end
    if role == "melee" then return "Melee" end
    if role == "ranged" then return "Ranged" end
    if role == "caster" then return "Caster" end
    return "Unknown"
end

local SPEC_SHORT = {
    Protection = "Prot",
    Marksmanship = "MM",
    Restoration = "Resto",
    Affliction = "Affli",
    Discipline = "Disc",
    Retribution = "Ret",
    Enhancement = "Enh",
    Elemental = "Ele",
}

function TB.ArmorySpecText(row)
    if not row then return "" end
    local spec = row.spec and (SPEC_SHORT[row.spec] or row.spec) or "?"
    local role = row.role and TB.ArmoryRoleLabel(row.role) or ""
    if role == "" then return spec end
    return spec .. " " .. role
end

-- The hit value the role actually rolls, matching the server's cap.
function TB.ArmoryHit(row)
    if not row then return 0, 0 end
    if row.role == "healer" then return 0, 0 end
    if row.role == "caster" then return row.spellHit or 0, row.hitCap or 0 end
    if row.role == "ranged" then return row.rangedHit or 0, row.hitCap or 0 end
    return row.meleeHit or 0, row.hitCap or 0
end

function TB.ArmoryHitPass(row)
    local hit, cap = TB.ArmoryHit(row)
    if not row or row.role == "healer" or (cap or 0) <= 0 then return nil end
    return hit >= cap
end

function TB.ArmoryDefensePass(row)
    if not row or row.role ~= "tank" or (row.defCap or 0) <= 0 then return nil end
    return (row.defense or 0) >= row.defCap
end

function TB.ArmoryHasProblems(row)
    if not row or not row.online then return false end
    if TB.ArmoryHitPass(row) == false then return true end
    if TB.ArmoryDefensePass(row) == false then return true end
    return TB.ArmoryProblemCount(row) > 0
end

-- ── filters and summary (pure) ─────────────────────────────────────────────
function TB.FilterArmoryRows(rows, opts)
    opts = opts or {}
    local text = string.lower(opts.search or "")
    local out = {}
    for _, row in ipairs(rows or {}) do
        local keep = true
        if opts.raidOnly and not row.inGroup then keep = false end
        if keep and text ~= "" and not string.find(string.lower(row.name or ""), text, 1, true) then
            keep = false
        end
        if keep and opts.problemsOnly and not TB.ArmoryHasProblems(row) then keep = false end
        if keep then table.insert(out, row) end
    end
    return out
end

function TB.ArmorySummary(rows)
    local summary = { tanks = 0, healers = 0, dps = 0, underHit = 0, underDefense = 0, missing = 0 }
    for _, row in ipairs(rows or {}) do
        if row.role == "tank" then
            summary.tanks = summary.tanks + 1
        elseif row.role == "healer" then
            summary.healers = summary.healers + 1
        else
            summary.dps = summary.dps + 1
        end
        if row.online then
            if TB.ArmoryHitPass(row) == false then summary.underHit = summary.underHit + 1 end
            if TB.ArmoryDefensePass(row) == false then summary.underDefense = summary.underDefense + 1 end
            if TB.ArmoryProblemCount(row) > 0 then summary.missing = summary.missing + 1 end
        end
    end
    return summary
end

-- ── view state ─────────────────────────────────────────────────────────────
TB.armoryRaidOnly = TB.armoryRaidOnly or false
TB.armoryProblemsOnly = TB.armoryProblemsOnly or false
TB.armoryFilterText = TB.armoryFilterText or ""

local function color(name) return COL[name] or { 1, 1, 1 } end

local HEX = {
    green = "|cff4de673",
    red = "|cffff5747",
    muted = "|cff9e998f",
    faint = "|cff6b6963",
    gold = "|cffdbb05c",
    text = "|cffebe6d6",
}

local function qualityRGB(quality)
    if quality and GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    return 0.35, 0.35, 0.35
end

local function itemQuality(id)
    if not id or id <= 0 or not GetItemInfo then return nil end
    local _, _, quality = GetItemInfo(id)
    return quality
end

-- ── row widgets ────────────────────────────────────────────────────────────
local function squareTooltip(button)
    local row = button.armoryRow
    local entry = row and row.eq and row.eq[button.slot]
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if entry and entry.itemId > 0 then
        if GameTooltip.SetHyperlink then
            GameTooltip:SetHyperlink("item:" .. entry.itemId .. ":" .. (entry.enchantId or 0))
        else
            GameTooltip:SetText(TB.ArmorySlotLabel(button.slot))
        end
        if (entry.miss or 0) > 0 then
            GameTooltip:AddLine(button.missReason or "Missing enchant", color("red")[1], color("red")[2], color("red")[3])
        else
            GameTooltip:AddLine(TB.ArmorySlotLabel(button.slot), COL.muted[1], COL.muted[2], COL.muted[3])
        end
    else
        GameTooltip:SetText(TB.ArmorySlotLabel(button.slot))
        GameTooltip:AddLine("Empty slot", color("red")[1], color("red")[2], color("red")[3])
    end
    GameTooltip:Show()
end

local function createSquare(row, slot)
    local button = CreateFrame("Button", nil, row)
    button.slot = slot
    button:SetWidth(STRIP_W)
    button:SetHeight(14)
    button:SetBackdrop(TB.FLAT_BACKDROP)
    button:SetBackdropColor(0.035, 0.038, 0.045, 1)
    button:SetBackdropBorderColor(0.28, 0.28, 0.30, 1)
    button.dot = button:CreateTexture(nil, "OVERLAY")
    button.dot:SetWidth(5); button.dot:SetHeight(5)
    button.dot:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
    button.dot:SetTexture(COL.red[1], COL.red[2], COL.red[3], 1)
    button.dot:Hide()
    button:SetScript("OnEnter", function() squareTooltip(this) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function() squareTooltip(this) end)
    row.squares[slot] = button
    return button
end

local function createArmoryRow(parent, scroll, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(STRIP_TEXT_W)
    row:SetHeight(ROW_H - 2)
    row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(index - 1) * ROW_H)
    TB.ApplySurface(row, "row")
    row:EnableMouse(true)

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetWidth(2)
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 1)
    row.accent:SetTexture(COL.accent[1], COL.accent[2], COL.accent[3], 0.95)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 7, 0)
    row.name:SetWidth(70); row.name:SetJustifyH("LEFT")

    row.spec = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.spec:SetPoint("LEFT", row, "LEFT", 83, 0)
    row.spec:SetWidth(68); row.spec:SetJustifyH("LEFT")
    TB.SetTextColor(row.spec, color("muted"))

    row.hit = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.hit:SetPoint("LEFT", row, "LEFT", 157, 0)
    row.hit:SetWidth(50); row.hit:SetJustifyH("LEFT")

    row.def = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.def:SetPoint("LEFT", row, "LEFT", 213, 0)
    row.def:SetWidth(30); row.def:SetJustifyH("LEFT")

    row.problems = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.problems:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    row.problems:SetWidth(24); row.problems:SetJustifyH("RIGHT")

    row.squares = {}
    local x = 249
    for _, slot in ipairs(SLOT_ORDER) do
        local button = createSquare(row, slot)
        if slot == 10 or slot == 15 then x = x + 3 end
        button:SetPoint("TOPLEFT", row, "TOPLEFT", x, -4)
        x = x + STRIP_W + STRIP_GAP
    end

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture(1, 1, 1, 0.04)

    row:SetScript("OnMouseUp", function()
        if arg1 == "RightButton" then return end
        local data = this.armoryData
        if data then TB.SetArmorySelection(data.name) end
        if data then TB.OpenBotPanel(data.name, "gear") end
    end)
    row:SetScript("OnEnter", function()
        local data = this.armoryData
        if not data then return end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(data.name)
        local role = data.role and TB.ArmoryRoleLabel(data.role) or "Unknown role"
        if data.spec then role = data.spec .. " · " .. role end
        GameTooltip:AddLine(role .. " · level " .. tostring(data.level or 0), COL.muted[1], COL.muted[2], COL.muted[3])
        if data.online then
            GameTooltip:AddLine(TB.ArmoryMissingText(data), COL.muted[1], COL.muted[2], COL.muted[3])
        else
            GameTooltip:AddLine("Offline", COL.muted[1], COL.muted[2], COL.muted[3])
        end
        GameTooltip:AddLine("Click to open this bot's panel.", COL.muted[1], COL.muted[2], COL.muted[3])
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

function TB.SetArmorySelection(name)
    TB.armorySelected = name and TB.NormalizeName(name) or nil
    if TB.RefreshArmoryView then TB.RefreshArmoryView() end
end

local function paintRow(row, data)
    row.armoryData = data
    local classColor = TB.GetClassColor and TB.GetClassColor(data.classId) or color("gold")
    local offline = not data.online
    row.name:SetText(data.name)
    if offline then
        TB.SetTextColor(row.name, color("faint"))
    else
        TB.SetTextColor(row.name, classColor)
    end
    row.spec:SetText(TB.ArmorySpecText(data))
    row.accent:SetTexture(classColor[1], classColor[2], classColor[3], 0.95)
    row.selected = TB.armorySelected == data.name
    if row.selected then
        row:SetBackdropColor(0.20, 0.155, 0.07, 0.96)
        row:SetBackdropBorderColor(0.70, 0.53, 0.20, 1)
    else
        TB.ApplySurface(row, "row")
    end

    local hitText, defText = "", ""
    if offline then
        hitText = "offline"
        TB.SetTextColor(row.hit, color("faint"))
    else
        local hit, cap = TB.ArmoryHit(data)
        if (cap or 0) <= 0 then
            hitText = "—"
            TB.SetTextColor(row.hit, color("faint"))
        else
            hitText = string.format("%.1f/", hit) .. tostring(cap)
            local pass = TB.ArmoryHitPass(data)
            TB.SetTextColor(row.hit, pass and color("green") or color("red"))
        end
        if data.role == "tank" then
            if (data.defCap or 0) > 0 then
                defText = tostring(data.defense or 0) .. "/" .. tostring(data.defCap)
                TB.SetTextColor(row.def, TB.ArmoryDefensePass(data) and color("green") or color("red"))
            else
                defText = tostring(data.defense or 0)
                TB.SetTextColor(row.def, color("text"))
            end
        else
            defText = "—"
            TB.SetTextColor(row.def, color("faint"))
        end
    end
    row.hit:SetText(hitText)
    row.def:SetText(defText)

    local missingBySlot = {}
    if data.online then
        for _, item in ipairs(TB.ArmoryMissing(data)) do missingBySlot[item.slot] = item.reason end
    end
    for _, slot in ipairs(SLOT_ORDER) do
        local button = row.squares[slot]
        local entry = data.eq and data.eq[slot]
        local shown = data.online and TB.ArmorySlotShown(data, slot)
        if shown then
            local quality = itemQuality(entry.itemId)
            local r, g, b = qualityRGB(quality)
            if entry.itemId > 0 then
                button:SetBackdropColor(0.035, 0.038, 0.045, 1)
                button:SetBackdropBorderColor(r, g, b, quality and 1 or 0.45)
            else
                button:SetBackdropColor(0.05, 0.05, 0.055, 0.55)
                button:SetBackdropBorderColor(0.35, 0.34, 0.32, 1)
            end
            button.missReason = missingBySlot[slot]
            if (entry.miss or 0) > 0 then button.dot:Show() else button.dot:Hide() end
            button.armoryRow = data
            button:Show()
        else
            button.armoryRow = nil
            button:Hide()
        end
    end

    local problems = TB.ArmoryProblemCount(data)
    if offline then
        row.problems:SetText("")
    elseif problems > 0 then
        row.problems:SetText(HEX.red .. tostring(problems) .. "|r")
    else
        row.problems:SetText(HEX.green .. "✓|r")
    end
end

-- ── view ───────────────────────────────────────────────────────────────────
function TB.RefreshArmoryView()
    local frame = TB.armoryFrame
    if not frame then return end
    local all = TB.GetArmoryRows()
    local scopeRows = TB.FilterArmoryRows(all, { raidOnly = TB.armoryRaidOnly })
    local shown = TB.FilterArmoryRows(all, {
        raidOnly = TB.armoryRaidOnly,
        search = TB.armoryFilterText,
        problemsOnly = TB.armoryProblemsOnly,
    })
    local summary = TB.ArmorySummary(scopeRows)

    if frame.summary then
        local function count(value, word)
            local hex = value > 0 and HEX.red or HEX.green
            return hex .. tostring(value) .. " " .. word .. "|r"
        end
        frame.summary:SetText(
            "Tanks " .. HEX.text .. tostring(summary.tanks) .. "|r"
            .. " · Healers " .. HEX.text .. tostring(summary.healers) .. "|r"
            .. " · DPS " .. HEX.text .. tostring(summary.dps) .. "|r"
            .. "   " .. count(summary.underHit, "under hit cap")
            .. " · " .. count(summary.underDefense, "tank under def cap")
            .. " · " .. count(summary.missing, "missing gear/enchants"))
    end

    local offset = frame.scroll and FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(frame.scroll) or 0
    for i = 1, ROW_N do
        local row = frame.rows[i]
        local data = shown[offset + i]
        if data then
            paintRow(row, data)
            row:Show()
        else
            row.armoryData = nil
            row:Hide()
        end
    end
    if frame.scroll and FauxScrollFrame_Update then
        FauxScrollFrame_Update(frame.scroll, table.getn(shown), ROW_N, ROW_H)
    end
    if frame.countLabel then
        frame.countLabel:SetText(tostring(table.getn(shown)) .. " of " .. tostring(table.getn(scopeRows)) .. " shown")
    end
end

local function showButtonState()
    if TB.armoryGuildButton then TB.SetButtonActive(TB.armoryGuildButton, not TB.armoryRaidOnly) end
    if TB.armoryRaidButton then TB.SetButtonActive(TB.armoryRaidButton, TB.armoryRaidOnly) end
    if TB.armoryProblemsButton then TB.SetButtonActive(TB.armoryProblemsButton, TB.armoryProblemsOnly) end
end

function TB.CreateArmoryFrame(parent)
    if TB.armoryFrame then return TB.armoryFrame end
    local width = (C.PANEL_W or 500) - (C.PAD or 10) * 2
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    frame:SetHeight(360)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

    local search = CreateFrame("EditBox", "TortoiseBotsManagerArmorySearch", frame, "InputBoxTemplate")
    search:SetWidth(150); search:SetHeight(20)
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    search:SetAutoFocus(false)
    search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    search:SetScript("OnTextChanged", function()
        TB.armoryFilterText = this:GetText() or ""
        TB.RefreshArmoryView()
    end)
    TB.StyleEditBox(search, "Search bots")
    frame.searchBox = search

    local clear = TB.StyleButton(CreateFrame("Button", nil, frame, "UIPanelButtonTemplate"), "mode")
    clear:SetWidth(42); clear:SetHeight(20)
    clear:SetPoint("LEFT", search, "RIGHT", 4, 0)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function()
        TB.armoryFilterText = ""
        search:SetText("")
        search:ClearFocus()
        TB.RefreshArmoryView()
    end)

    local show = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    show:SetText("Show")
    TB.SetTextColor(show, color("muted"))

    local raid = TB.StyleButton(CreateFrame("Button", nil, frame, "UIPanelButtonTemplate"), "mode")
    raid:SetWidth(62); raid:SetHeight(20)
    raid:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    raid:SetText("This raid")
    raid:SetScript("OnClick", function()
        TB.armoryRaidOnly = true
        showButtonState()
        TB.RefreshArmoryView()
    end)
    TB.armoryRaidButton = raid

    local guild = TB.StyleButton(CreateFrame("Button", nil, frame, "UIPanelButtonTemplate"), "mode")
    guild:SetWidth(70); guild:SetHeight(20)
    guild:SetPoint("RIGHT", raid, "LEFT", -4, 0)
    guild:SetText("Guild bots")
    guild:SetScript("OnClick", function()
        TB.armoryRaidOnly = false
        showButtonState()
        TB.RefreshArmoryView()
    end)
    TB.armoryGuildButton = guild
    show:SetPoint("RIGHT", guild, "LEFT", -6, 0)

    if TB.UI and TB.UI.SetTooltip then
        TB.UI.SetTooltip(raid, "Bots in your group or raid.", "This raid")
        TB.UI.SetTooltip(guild, "Your claimed guild bots and the party bots you control.", "Guild bots")
    end

    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -26)
    summary:SetWidth(width - 8); summary:SetJustifyH("LEFT")
    frame.summary = summary

    local columns = {
        { text = "Name", x = 7, width = 70 },
        { text = "Spec", x = 83, width = 68 },
        { text = "Hit", x = 157, width = 50 },
        { text = "Def", x = 213, width = 30 },
        { text = "Equipped", x = 249, width = 160 },
    }
    for _, column in ipairs(columns) do
        local head = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        head:SetPoint("TOPLEFT", frame, "TOPLEFT", column.x, -46)
        head:SetWidth(column.width); head:SetJustifyH("LEFT")
        head:SetText(string.upper(column.text))
        TB.SetTextColor(head, color("faint"))
    end

    local scroll = CreateFrame("ScrollFrame", "TortoiseBotsManagerArmoryScroll", frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -62)
    scroll:SetWidth(width - 26)
    scroll:SetHeight(ROW_N * ROW_H)
    scroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(ROW_H, TB.RefreshArmoryView)
    end)
    frame.scroll = scroll
    frame.rows = {}
    for i = 1, ROW_N do table.insert(frame.rows, createArmoryRow(frame, scroll, i)) end

    local count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 5)
    count:SetWidth(200); count:SetJustifyH("LEFT")
    TB.SetTextColor(count, color("muted"))
    frame.countLabel = count

    local problems = TB.StyleButton(CreateFrame("Button", nil, frame, "UIPanelButtonTemplate"), "mode")
    problems:SetWidth(96); problems:SetHeight(20)
    problems:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -66, 2)
    problems:SetText("Problems only")
    problems:SetScript("OnClick", function()
        TB.armoryProblemsOnly = not TB.armoryProblemsOnly
        showButtonState()
        TB.RefreshArmoryView()
    end)
    TB.armoryProblemsButton = problems

    local refresh = TB.StyleButton(CreateFrame("Button", nil, frame, "UIPanelButtonTemplate"))
    refresh:SetWidth(60); refresh:SetHeight(20)
    refresh:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        if TB.RequestArmory then TB.RequestArmory() end
    end)
    frame.refreshButton = refresh

    TB.armoryFrame = frame
    showButtonState()
    TB.RefreshArmoryView()
    return frame
end
