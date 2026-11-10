-- Duplicate Clothing Disassembler (Cyber Engine Tweaks mod)
--
-- Disassembles duplicate clothing in V's backpack. Copies are duplicates only when they are the same TweakDB record:
-- the same item in the same colour (each colour variant is its own record, e.g. Items.Balaclava_02_basic_01 / _02).
-- From each group it keeps the highest-quality copy (one copy if several share the best quality) and disassembles
-- the rest through the game's own path (ItemActionsHelper.DisassembleItem, what "Disassemble junk" uses).
--
-- Never touched: equipped clothing, Quest / IconicWeapon / UnequipBlocked items (the game refuses those too), and the
-- stash (only the backpack is read). Open the CET overlay: Scan first, check the list, then Disassemble.

local MOD = "DuplicateClothingDisassembler"
local QUALITY_NAMES = { [0] = "Common", "Common+", "Uncommon", "Uncommon+", "Rare", "Rare+", "Epic", "Epic+",
                        "Legendary", "Legendary+", "Legendary++" }

local state = { overlay = false, plan = nil, confirm = false, message = "" }
local settings = { linkJunk = true }   -- also disassemble duplicates when you confirm the backpack's "Disassemble junk"

-- print() goes to scripting.log, which CET buffers; spdlog writes this mod's own DuplicateClothingDisassembler.log
local function log(text)
    print("[" .. MOD .. "] " .. tostring(text))
    pcall(function() spdlog.info(tostring(text)) end)
end

-- settings.json lives in this mod's own folder (the only place a CET mod may write)
local function loadSettings()
    local f = io.open("settings.json", "r")
    if not f then return end
    local ok, t = pcall(json.decode, f:read("*a"))
    f:close()
    if ok and type(t) == "table" and type(t.linkJunk) == "boolean" then settings.linkJunk = t.linkJunk end
end

local function saveSettings()
    local f = io.open("settings.json", "w")
    if not f then return end
    f:write(json.encode(settings))
    f:close()
end

-- quality as a sortable number: Common 0 ... Legendary++ 10 (the game's own tier order)
local function qualityRank(itemData)
    local ok, rank = pcall(function()
        return RPGManager.ConvertQualityToCombinedValue(RPGManager.GetItemDataQuality(itemData))
    end)
    if ok and type(rank) == "number" then return rank end
    local ok2, q = pcall(function() return itemData:GetStatValueByType(gamedataStatType.Quality) end)
    return (ok2 and type(q) == "number") and math.floor(q) * 2 or 0
end

local function recordName(tdbid)
    local ok, s = pcall(function() return TDBID.ToStringDEBUG(tdbid) end)
    return ok and s or tostring(tdbid)
end

local function displayName(itemID, tdbid)
    local ok, s = pcall(function() return Game.GetLocalizedItemNameByItemID(itemID) end)
    if ok and type(s) == "string" and s ~= "" then return s end
    ok, s = pcall(function() return Game.GetLocalizedTextByKey(TweakDB:GetRecord(tdbid):DisplayName()) end)
    if ok and type(s) == "string" and s ~= "" then return s end
    return recordName(tdbid)
end

-- an item the game would never let us disassemble, or one we keep on purpose
local function protected(player, itemData, itemID)
    for _, tag in ipairs({ "Quest", "IconicWeapon", "UnequipBlocked" }) do
        local ok, has = pcall(function() return itemData:HasTag(tag) end)
        if ok and has then return true end
    end
    local ok, equipped = pcall(function() return RPGManager.IsItemEquipped(player, itemID) end)
    return ok and equipped
end

-- The rules, kept apart from the game calls. copies = list of { quality, protected, quantity, ... } for ONE record.
-- Returns the copies to disassemble, each with the quantity to take.
local function pickDuplicates(copies)
    table.sort(copies, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.protected ~= b.protected then return a.protected end  -- on a tie, the equipped/protected copy is the one kept
        return a.order < b.order
    end)
    local out = {}
    for i, c in ipairs(copies) do
        local keep = (i == 1) and 1 or 0                -- the best copy keeps one unit
        local spare = c.quantity - keep
        if spare > 0 and not c.protected then
            table.insert(out, { copy = c, amount = spare })
        end
    end
    return out
end

local function scan()
    local player = Game.GetPlayer()
    if not player then return nil, "No player yet: load a save first." end
    local ok, list = Game.GetTransactionSystem():GetItemList(player)
    if not ok or not list then return nil, "Couldn't read the backpack." end

    local groups, order = {}, {}
    for idx, itemData in ipairs(list) do
        local itemID = itemData:GetID()
        local isClothing = false
        pcall(function() isClothing = RPGManager.IsItemClothing(itemID) end)
        if isClothing then
            local tdbid = ItemID.GetTDBID(itemID)
            local key = recordName(tdbid)
            if not groups[key] then
                groups[key] = { record = key, name = displayName(itemID, tdbid), copies = {} }
                table.insert(order, key)
            end
            local qty = 1
            pcall(function() qty = itemData:GetQuantity() end)
            table.insert(groups[key].copies, {
                itemID = itemID, quality = qualityRank(itemData), quantity = math.max(1, qty or 1),
                protected = protected(player, itemData, itemID), order = idx })
        end
    end

    local plan = { groups = {}, total = 0, clothing = 0 }
    for _, key in ipairs(order) do
        local g = groups[key]
        plan.clothing = plan.clothing + #g.copies
        if #g.copies > 1 then
            local drop = pickDuplicates(g.copies)
            if #drop > 0 then
                g.drop = drop
                g.keep = g.copies[1]
                for _, d in ipairs(drop) do plan.total = plan.total + d.amount end
                table.insert(plan.groups, g)
            end
        end
    end
    table.sort(plan.groups, function(a, b) return a.name < b.name end)
    return plan
end

local function disassemble(plan)
    local player = Game.GetPlayer()
    local done, failed = 0, 0
    for _, g in ipairs(plan.groups) do
        for _, d in ipairs(g.drop) do
            local ok = pcall(function() ItemActionsHelper.DisassembleItem(player, d.copy.itemID, d.amount) end)
            if ok then done = done + d.amount else failed = failed + 1 end
        end
    end
    log(("disassembled %d item(s), %d call(s) failed"):format(done, failed))
    return done, failed
end

local function qualityName(rank)
    return QUALITY_NAMES[rank] or tostring(rank)
end

-- The backpack's "Disassemble junk" button (BackpackMainGameController, see backpack_main.script):
--   click   -> OnDisassembleJunkButtonClick: with no junk it only says "no junk"; we open the popup if there are duplicates
--   popup   -> OpenDisassembleJunkConfirmation: the vanilla popup, with the count = junk + duplicate clothing copies
--   confirm -> OnDisassembleJunkPopupClosed: vanilla disassembles the junk; afterwards we disassemble the duplicates
-- Every hook falls back to the vanilla code if anything goes wrong (and logs why), so the button keeps working.

-- CET can't read the backpack controller's private fields (m_junkItems came back nil in game), so the junk is counted
-- here with the game's own rule (UIInventoryItem.IsJunk): item type Gen_Junk or Gen_Jewellery.
local function junkCount()
    local ok, list = Game.GetTransactionSystem():GetItemList(Game.GetPlayer())
    if not ok or not list then return 0 end
    local junk, jewel = EnumInt(gamedataItemType.Gen_Junk), EnumInt(gamedataItemType.Gen_Jewellery)
    local n = 0
    for _, d in ipairs(list) do
        local t = EnumInt(d:GetItemType())
        if t == junk or t == jewel then n = n + d:GetQuantity() end
    end
    return n
end

-- the vanilla "Disassemble junk" confirmation (backpack_main.script, OpenDisassembleJunkConfirmation), with the count
-- = junk + duplicate clothing copies. Only public calls; the token is kept here so the popup's listener stays alive.
local function openJunkPopup(this, junk, duplicates)
    local data = VendorSellJunkPopupData.new()
    data.notificationName = CName.new("base\\gameplay\\gui\\widgets\\notifications\\vendor_sell_junk_confirmation.inkwidget")
    data.isBlocking = true
    data.useCursor = true
    data.queueName = CName.new("modal_popup")
    data.itemsQuantity = junk + duplicates
    data.actionType = VendorSellJunkActionType.Disassemble
    state.junkToken = this:ShowGameNotification(data)
    state.junkToken:RegisterListener(this, "OnDisassembleJunkPopupClosed")
    log(("junk popup: %d junk + %d duplicate clothing"):format(junk, duplicates))
end

local function releaseJunkToken()
    if state.junkToken then
        state.junkToken = nil
        collectgarbage()        -- free the handle now, so the game sees the popup's token released
    end
end

local function duplicateCount()
    local plan = scan()
    return (plan and plan.total) or 0
end

local function hookJunkButton()
    Override("BackpackMainGameController", "OnDisassembleJunkButtonClick", function(this, e, wrappedMethod)
        if settings.linkJunk then
            local ok, res = pcall(function()
                if not (e:IsAction("click") or e:IsAction("tap")) then return "skip" end
                if junkCount() > 0 then return "skip" end   -- with junk, vanilla opens the popup (hooked below)
                local n = duplicateCount()
                if n == 0 then return "skip" end            -- neither: vanilla says "no junk to disassemble"
                openJunkPopup(this, 0, n)
                return "opened"
            end)
            if ok and res == "opened" then return true end
            if not ok then log("junk click: falling back to vanilla (" .. tostring(res) .. ")") end
        end
        return wrappedMethod(e)
    end)

    Override("BackpackMainGameController", "OpenDisassembleJunkConfirmation", function(this, wrappedMethod)
        if not settings.linkJunk then return wrappedMethod() end
        local ok, err = pcall(function() openJunkPopup(this, junkCount(), duplicateCount()) end)
        if not ok then
            log("junk popup: falling back to vanilla (" .. tostring(err) .. ")")
            return wrappedMethod()
        end
    end)

    ObserveAfter("BackpackMainGameController", "OnDisassembleJunkPopupClosed", function(this, data)
        -- The popup lives as long as someone holds its token (the popup itself only has a weak ref, see
        -- gameNotificationsUtilities.script). Vanilla drops its reference here (m_disassembleJunkPopupToken = NULL);
        -- ours must go too, or the dimmed blocking layer stays up and soft-locks the menu.
        releaseJunkToken()
        if not settings.linkJunk then return end
        local ok, err = pcall(function()
            if not data.confirm then log("junk popup: cancelled") return end
            local plan = scan()          -- fresh scan: what's in the backpack right now
            if plan and plan.total > 0 then disassemble(plan) else log("junk confirm: no duplicates to disassemble") end
        end)
        if not ok then log("junk confirm: " .. tostring(err)) end
    end)
end

registerForEvent("onInit", function()
    loadSettings()
    local ok, err = pcall(hookJunkButton)
    log(ok and ("loaded (Disassemble junk link " .. (settings.linkJunk and "on" or "off") .. ")") or ("loaded, but the junk button hook failed: " .. tostring(err)))
end)
registerForEvent("onShutdown", function() releaseJunkToken() end)   -- also on "Reload All Mods"
registerForEvent("onOverlayOpen", function() state.overlay = true end)
registerForEvent("onOverlayClose", function() state.overlay = false; state.confirm = false end)

-- console use (the console can't see a mod's globals, so go through GetMod):
--   GetMod("DuplicateClothingDisassembler").scan()   -- lists what would go, to scripting.log
--   GetMod("DuplicateClothingDisassembler").run()    -- disassembles the last scan's list
local DuplicateClothing = {
    scan = function()
        local plan, err = scan()
        if not plan then log(err) return end
        state.plan = plan
        log(("%d clothing items, %d duplicate(s) to disassemble in %d group(s)"):format(plan.clothing, plan.total, #plan.groups))
        for _, g in ipairs(plan.groups) do
            local q = {}
            for _, d in ipairs(g.drop) do table.insert(q, qualityName(d.copy.quality) .. " x" .. d.amount) end
            log(("  %s (%s): keep %s, disassemble %s"):format(g.name, g.record, qualityName(g.keep.quality), table.concat(q, ", ")))
        end
    end,
    run = function()
        if not state.plan then log('scan first: GetMod("DuplicateClothingDisassembler").scan()') return end
        disassemble(state.plan)
        state.plan = nil
    end,
    -- safety valve: if a popup this mod opened ever stays stuck, release it from the console
    unlock = function()
        local had = state.junkToken ~= nil
        releaseJunkToken()
        log(had and "unlock: released the popup" or "unlock: no popup held")
    end,
}

registerForEvent("onDraw", function()
    if not state.overlay then return end
    ImGui.SetNextWindowSize(520, 460, ImGuiCond.FirstUseEver)
    if not ImGui.Begin("Duplicate Clothing Disassembler") then ImGui.End() return end

    ImGui.TextWrapped("Keeps the best copy of each clothing item (same item, same colour) and disassembles the "
        .. "other copies in V's backpack. Equipped, quest and iconic items and the stash are never touched.")
    local linked, changed = ImGui.Checkbox("Also run with the backpack's Disassemble Junk button", settings.linkJunk)
    if changed then settings.linkJunk = linked; saveSettings() end
    if ImGui.Button("Scan backpack") then
        local plan, err = scan()
        state.plan, state.confirm = plan, false
        state.message = plan and ("%d clothing items: %d duplicate(s) in %d group(s)."):format(plan.clothing, plan.total, #plan.groups) or err
    end
    ImGui.Text(state.message)

    local plan = state.plan
    if plan and plan.total > 0 then
        ImGui.Separator()
        if ImGui.BeginChild("dupes", 0, -40, true) then
            for _, g in ipairs(plan.groups) do
                ImGui.TextWrapped(g.name .. "  (" .. g.record .. ")")
                local q = {}
                for _, d in ipairs(g.drop) do table.insert(q, qualityName(d.copy.quality) .. (d.amount > 1 and (" x" .. d.amount) or "")) end
                ImGui.TextDisabled("   keep " .. qualityName(g.keep.quality) .. "   |   disassemble " .. table.concat(q, ", "))
            end
        end
        ImGui.EndChild()
        if not state.confirm then
            if ImGui.Button(("Disassemble %d item(s)..."):format(plan.total)) then state.confirm = true end
        else
            ImGui.Text("Can't be undone. Make a manual save first.")
            ImGui.SameLine()
            if ImGui.Button("Yes, disassemble") then
                local done, failed = disassemble(plan)
                state.message = ("Disassembled %d item(s)%s. Scan again to check."):format(done, failed > 0 and (", " .. failed .. " failed") or "")
                state.plan, state.confirm = nil, false
            end
            ImGui.SameLine()
            if ImGui.Button("Cancel") then state.confirm = false end
        end
    end
    ImGui.End()
end)

return DuplicateClothing
