--[[
    YUEN | +1 Stone Skipping Research + Automation Helper
    Version: 3.0
    Research snapshot: 2026-10-19

    What this script does:
      * Rayfield UI, guide, HUD/world diagnostics and a read-only HUD change watcher
      * Smart Auto Throw using only a visible, active in-game THROW button
      * Cautious auto-claim for visible, exact-label reward buttons with cooldowns
      * Optional visible "Equip Best" helper with a long cooldown
      * Conservative rebirth readiness alert based on a single visible label
      * Research-based progression notes and time-sensitive code list

    What it deliberately does NOT do:
      * Call hidden game remotes or imitate server requests
      * Change Skill/Wins or other server-owned stats
      * Automatically rebirth (it resets progress)
      * Automatically purchase eggs, stones, passes, boosts, or Robux items
      * Teleport the character or bypass server checks

    Public research is community-reported and can become stale after updates.
    The game's own UI is the authority for current requirements, prices, and codes.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    warn("[YUEN] LocalPlayer not found. Run this from the client.")
    return
end

-- Rayfield UI
local Rayfield
local loaded, result = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if loaded then
    Rayfield = result
else
    warn("[YUEN] Could not load Rayfield: " .. tostring(result))
    return
end

local Window = Rayfield:CreateWindow({
    Name = "YUEN | +1 Stone Skipping",
    LoadingTitle = "YUEN Stone Skipping Helper",
    LoadingSubtitle = "Research • Automation • Diagnostics",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "YUEN",
        FileName = "StoneSkippingHelper"
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

local function notify(title, content, duration)
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration or 5,
            Image = 4483362458,
        })
    end)
end

local function safeFullName(obj)
    local ok, value = pcall(function() return obj:GetFullName() end)
    return ok and value or tostring(obj)
end

local function textOf(obj)
    local ok, value = pcall(function() return obj.Text end)
    return ok and tostring(value or "") or ""
end

local function normalizeGuiText(value)
    local normalized = string.lower(tostring(value or ""))
    normalized = normalized:gsub("[%p%c]", " ")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:match("^%s*(.-)%s*$") or ""
    return normalized
end

local function isActuallyVisible(guiObject, playerGui)
    local current = guiObject
    while current and current ~= playerGui do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("ScreenGui") and not current.Enabled then
            return false
        end
        current = current.Parent
    end
    return current == playerGui
end

local function getPlayerGui()
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

-- ============================================================================
-- READ-ONLY HUD AND WORLD SCANNERS
-- ============================================================================

local keywords = {
    "skill", "wins", "level", "rebirth", "throw", "auto", "stone",
    "training", "train", "pet", "egg", "shop", "zone", "gift", "relic",
    "claim", "reward", "boost", "world", "daily", "halloween"
}

local function matchesKeywords(value)
    local lower = string.lower(tostring(value or ""))
    for _, word in ipairs(keywords) do
        if string.find(lower, word, 1, true) then return true end
    end
    return false
end

local function scanHud()
    local playerGui = getPlayerGui()
    if not playerGui then
        notify("HUD Scan", "PlayerGui is not available yet.")
        return 0
    end

    local count = 0
    print("========== YUEN HUD SCAN ==========")
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local text = textOf(obj)
            local combined = obj.Name .. " " .. text
            if matchesKeywords(combined) then
                count += 1
                if count <= 250 then
                    print(string.format(
                        "[HUD %03d] %s | Class=%s | Visible=%s | Text=%s",
                        count, safeFullName(obj), obj.ClassName,
                        tostring(isActuallyVisible(obj, playerGui)), text
                    ))
                end
            end
        end
    end
    print("[YUEN] HUD entries matched:", count, "(printed maximum 250)")
    print("===================================")
    notify("HUD Scan Complete", string.format("Found %d matching UI items. Check F9 console.", count))
    return count
end

local worldKeywords = {
    "training", "throw", "stone", "skill", "rebirth", "egg", "pet", "shop",
    "gift", "relic", "zone", "water", "lane", "spawn", "palm", "cactus",
    "autumn", "mushroom", "frost", "world", "halloween", "claim"
}

local function worldNameMatches(value)
    local lower = string.lower(tostring(value or ""))
    for _, word in ipairs(worldKeywords) do
        if string.find(lower, word, 1, true) then return true end
    end
    return false
end

local function scanWorldNames()
    local count, printed = 0, 0
    print("========== YUEN WORLD NAME SCAN ==========")
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if worldNameMatches(obj.Name) then
            count += 1
            if printed < 150 then
                printed += 1
                local details = ""
                if obj:IsA("BasePart") then
                    details = string.format(" | Position=(%.1f, %.1f, %.1f)", obj.Position.X, obj.Position.Y, obj.Position.Z)
                end
                print(string.format("[WORLD %03d] %s | Class=%s%s", count, safeFullName(obj), obj.ClassName, details))
            end
        end
    end
    print(string.format("[YUEN] Total name matches: %d (printed up to 150)", count))
    print("==========================================")
    notify("World Scan Complete", string.format("Found %d names matching gameplay keywords. See F9 console.", count))
    return count
end

-- ============================================================================
-- BUTTON FINDERS: VISIBLE PLAYERGUI CONTROLS ONLY; NO DIRECT REMOTE CALLS
-- ============================================================================

local function getVisibleTextButtons()
    local playerGui = getPlayerGui()
    local found = {}
    if not playerGui then return found end
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextButton") and isActuallyVisible(obj, playerGui) then
            table.insert(found, obj)
        end
    end
    return found
end

-- Visible is not enough: ignore disabled/inactive controls where the client API exposes state.
local function isButtonInteractable(button)
    if not button or not button:IsA("GuiButton") then return false end
    local playerGui = getPlayerGui()
    if not playerGui or not isActuallyVisible(button, playerGui) then return false end

    local okActive, active = pcall(function() return button.Active end)
    if okActive and active == false then return false end

    -- Interactable is not present in every client/runtime; use it only when readable.
    local okInteractable, interactable = pcall(function() return button.Interactable end)
    if okInteractable and interactable == false then return false end
    return true
end

local function findVisibleThrowButton()
    local playerGui = getPlayerGui()
    if not playerGui then return nil end

    local fallback = nil
    for _, obj in ipairs(getVisibleTextButtons()) do
        local text = normalizeGuiText(obj.Text)
        local name = normalizeGuiText(obj.Name)
        if text == "throw" then
            return obj
        end
        if text == "throw stone" or name == "throwbutton" or name == "throw button" then
            fallback = fallback or obj
        end
    end
    return fallback
end

local function findVisibleNativeAutoThrowControl()
    local playerGui = getPlayerGui()
    if not playerGui then return nil end

    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox"))
            and isActuallyVisible(obj, playerGui) then
            local text = normalizeGuiText(textOf(obj))
            local name = normalizeGuiText(obj.Name)
            local path = normalizeGuiText(safeFullName(obj))
            local ownControl = path:find("yuen", 1, true) ~= nil
                or text:find("find native auto throw", 1, true) ~= nil
                or text:find("auto throw visible button", 1, true) ~= nil
            if not ownControl and (text:find("auto throw", 1, true) or name:find("auto throw", 1, true)) then
                return obj
            end
        end
    end
    return nil
end

local function contextForButton(button, maxParents)
    local pieces = { normalizeGuiText(button.Name), normalizeGuiText(textOf(button)) }
    local current = button.Parent
    local parents = 0
    while current and parents < (maxParents or 3) do
        table.insert(pieces, normalizeGuiText(current.Name))
        if current:IsA("TextLabel") or current:IsA("TextButton") or current:IsA("TextBox") then
            table.insert(pieces, normalizeGuiText(textOf(current)))
        end
        current = current.Parent
        parents += 1
    end
    return table.concat(pieces, " ")
end

local function hasPaidContext(button)
    local context = contextForButton(button, 6)
    local forbidden = {
        "robux", "premium", "gamepass", "game pass", "developer product",
        "purchase", "buy now", "real money", "paid offer", "starter pack"
    }
    for _, word in ipairs(forbidden) do
        if context:find(word, 1, true) then return true end
    end
    return false
end

local claimLabels = {
    ["claim"] = true,
    ["claim reward"] = true,
    ["claim rewards"] = true,
    ["claim your reward"] = true,
    ["claim now"] = true,
    ["claim all"] = true,
    ["collect"] = true,
    ["collect reward"] = true,
    ["collect rewards"] = true,
    ["collect now"] = true,
}

local function getVisibleFreeClaimButtons()
    local found = {}
    for _, button in ipairs(getVisibleTextButtons()) do
        local normalized = normalizeGuiText(button.Text)
        if claimLabels[normalized] and not hasPaidContext(button) then
            table.insert(found, button)
        end
    end
    return found
end

local equipBestLabels = {
    ["equip best"] = true,
    ["equip best pet"] = true,
    ["equip best pets"] = true,
    ["equip best team"] = true,
}

local function findVisibleEquipBestButton()
    for _, button in ipairs(getVisibleTextButtons()) do
        local normalized = normalizeGuiText(button.Text)
        if equipBestLabels[normalized] and not hasPaidContext(button) then
            return button
        end
    end
    return nil
end

-- ============================================================================
-- AUTOMATION: VISIBLE CONTROLS ONLY
-- ============================================================================

-- Auto Throw (existing feature, retained)
local AutoThrowEnabled = false
local AutoThrowDelay = 2
local AutoThrowGeneration = 0

local function setAutoThrow(enabled)
    AutoThrowEnabled = enabled
    AutoThrowGeneration += 1

    if not enabled then
        print("[YUEN Auto Throw] Stopped.")
        notify("Auto Throw", "Stopped.", 3)
        return
    end

    local thisGeneration = AutoThrowGeneration
    print(string.format("[YUEN Auto Throw] Started. Minimum interval: %s seconds.", tostring(AutoThrowDelay)))
    notify("Auto Throw", "Started. Stay on the yellow Throw Zone; YUEN waits for the visible, active THROW button.", 5)

    task.spawn(function()
        local lastActivationAt = -math.huge
        local lastStatusAt = 0
        local lastMissingWarningAt = 0

        while AutoThrowEnabled and thisGeneration == AutoThrowGeneration do
            local now = os.clock()
            if now - lastActivationAt >= math.max(1, tonumber(AutoThrowDelay) or 2) then
                local button = findVisibleThrowButton()
                if button and isButtonInteractable(button) then
                    local ok, err = pcall(function() button:Activate() end)
                    if ok then
                        lastActivationAt = now
                        -- Throttle logs so a long auto session doesn't flood F9.
                        if now - lastStatusAt >= 10 then
                            print("[YUEN Auto Throw] Activated visible THROW control:", safeFullName(button))
                            lastStatusAt = now
                        end
                        lastMissingWarningAt = 0
                    else
                        warn("[YUEN Auto Throw] Visible button activation failed:", err)
                    end
                elseif not button and now - lastMissingWarningAt >= 20 then
                    warn("[YUEN Auto Throw] No visible THROW button. This is normal during a skip; stand on the Throw Zone and check HUD Scan if it never appears.")
                    lastMissingWarningAt = now
                end
            end
            -- Poll quickly for the game to re-show THROW after a skip; the delay controls throw cadence.
            task.wait(0.25)
        end
    end)
end

-- Auto-claim only currently visible claim/collect buttons with safe labels.
-- Paid-context and disabled/inactive buttons are ignored. Only one button is clicked per cooldown.
-- This is a heuristic, so keep the relevant free-reward window visible and supervise the first use.
local AutoClaimEnabled = false
local AutoClaimDelay = 20
local AutoClaimGeneration = 0

local function setAutoClaim(enabled)
    AutoClaimEnabled = enabled
    AutoClaimGeneration += 1

    if not enabled then
        print("[YUEN Auto Claim] Stopped.")
        notify("Auto Claim", "Stopped.", 3)
        return
    end

    local thisGeneration = AutoClaimGeneration
    print("[YUEN Auto Claim] Started. Exact visible Claim/Collect labels only; one click per cooldown.")
    notify("Auto Claim", "Started. Keep a free-reward window open. Paid/premium contexts and disabled buttons are skipped.", 5)

    task.spawn(function()
        local lastActionAt = -math.huge
        local lastNoButtonNoticeAt = 0

        while AutoClaimEnabled and thisGeneration == AutoClaimGeneration do
            local now = os.clock()
            local cooldown = math.max(5, tonumber(AutoClaimDelay) or 15)

            if now - lastActionAt >= cooldown then
                local claims = getVisibleFreeClaimButtons()
                local activated = false
                for _, button in ipairs(claims) do
                    if isButtonInteractable(button) then
                        local ok, err = pcall(function() button:Activate() end)
                        lastActionAt = now
                        if ok then
                            print("[YUEN Auto Claim] Activated one visible free-reward-looking button:", safeFullName(button), "| Text:", textOf(button))
                            notify("Auto Claim", "Clicked one visible Claim/Collect button. Check the game response before leaving it running.", 4)
                        else
                            warn("[YUEN Auto Claim] Button activation failed:", err)
                        end
                        activated = true
                        break -- avoid activating several different claim buttons in one pass
                    end
                end
                if not activated and now - lastNoButtonNoticeAt >= 30 then
                    print("[YUEN Auto Claim] No eligible visible claim button right now.")
                    lastNoButtonNoticeAt = now
                end
            end
            task.wait(1)
        end
    end)
end

-- Auto Equip Best uses only the exact visible Equip Best button; it never buys eggs.
local AutoEquipBestEnabled = false
local AutoEquipBestGeneration = 0
local EquipBestCooldown = 45
local lastEquipBestAt = -math.huge

local function setAutoEquipBest(enabled)
    AutoEquipBestEnabled = enabled
    AutoEquipBestGeneration += 1

    if not enabled then
        print("[YUEN Auto Equip Best] Stopped.")
        notify("Auto Equip Best", "Stopped.", 3)
        return
    end

    local thisGeneration = AutoEquipBestGeneration
    notify("Auto Equip Best", "Started. Open the Pets menu so its visible Equip Best button can be found.", 5)
    task.spawn(function()
        while AutoEquipBestEnabled and thisGeneration == AutoEquipBestGeneration do
            local button = findVisibleEquipBestButton()
            if button and isButtonInteractable(button) and (os.clock() - lastEquipBestAt >= EquipBestCooldown) then
                local ok, err = pcall(function()
                    button:Activate()
                end)
                lastEquipBestAt = os.clock()
                if ok then
                    print("[YUEN Auto Equip Best] Activated:", safeFullName(button))
                    notify("Auto Equip Best", "Activated the visible Equip Best control.", 3)
                else
                    warn("[YUEN Auto Equip Best] Activation failed:", err)
                end
            end
            task.wait(3)
        end
    end)
end

-- This monitor only alerts; it deliberately never clicks the Rebirth button.
local RebirthAlertEnabled = false
local RebirthAlertGeneration = 0

local function scanRebirthReadiness()
    local playerGui = getPlayerGui()
    if not playerGui then return false, "PlayerGui unavailable" end

    local visibleTexts = {}
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and isActuallyVisible(obj, playerGui) then
            local parent = obj.Parent
            local parentContext = ""
            if parent and parent ~= playerGui then
                parentContext = normalizeGuiText(parent.Name .. " " .. textOf(parent))
            end
            local value = normalizeGuiText(obj.Name .. " " .. textOf(obj) .. " " .. parentContext)
            if value ~= "" then table.insert(visibleTexts, value) end
        end
    end

    -- Conservative: require readiness words and the percentage on one visible UI element or its immediate parent.
    -- Don't combine unrelated labels across the whole screen (e.g. a boost and a separate Rebirth button).
    for _, value in ipairs(visibleTexts) do
        local hasRebirth = value:find("rebirth", 1, true) ~= nil
        local hasReady = value:find("ready", 1, true) ~= nil or value:find("max level", 1, true) ~= nil
        local hasFull = value:find("100", 1, true) ~= nil or value:find("100 percent", 1, true) ~= nil
        if hasRebirth and (hasFull or hasReady) then
            return true, "A single visible UI label suggests Rebirth readiness: " .. value
        end
        if hasReady and hasFull then
            return true, "A single visible UI label contains MAX LEVEL/ready and 100%: " .. value
        end
    end
    return false, "No visible UI element/parent clearly combined Rebirth/readiness with 100% or MAX LEVEL."
end

local function setRebirthAlert(enabled)
    RebirthAlertEnabled = enabled
    RebirthAlertGeneration += 1

    if not enabled then
        print("[YUEN Rebirth Alert] Stopped.")
        notify("Rebirth Alert", "Stopped.", 3)
        return
    end

    local thisGeneration = RebirthAlertGeneration
    local wasReady = false
    notify("Rebirth Alert", "Monitoring the visible HUD. It will alert only; it will never click Rebirth for you.", 5)
    task.spawn(function()
        while RebirthAlertEnabled and thisGeneration == RebirthAlertGeneration do
            local ready, reason = scanRebirthReadiness()
            if ready and not wasReady then
                print("[YUEN Rebirth Alert] Possible ready state:", reason)
                notify("Check Rebirth", "HUD may show MAX LEVEL and 100%. Check the reset details before rebirthing.", 8)
            end
            wasReady = ready
            task.wait(5)
        end
    end)
end

local function scanClaimButtons()
    local safeButtons = getVisibleFreeClaimButtons()
    local allButtons = getVisibleTextButtons()
    local suspiciousCount = 0

    print("========== YUEN CLAIM BUTTON SCAN ==========")
    print("Visible TextButtons:", #allButtons)
    print("Eligible exact-label claim/collect buttons:", #safeButtons)
    for index, button in ipairs(safeButtons) do
        print(string.format("[SAFE CLAIM %02d] %s | Text=%s", index, safeFullName(button), textOf(button)))
    end
    for _, button in ipairs(allButtons) do
        local label = normalizeGuiText(button.Text)
        if label:find("claim", 1, true) or label:find("collect", 1, true) then
            if hasPaidContext(button) then
                suspiciousCount += 1
                print("[SKIPPED PAID-CONTEXT BUTTON]", safeFullName(button), "| Text=", textOf(button))
            end
        end
    end
    print("Skipped paid/premium-context button candidates:", suspiciousCount)
    print("============================================")
    notify("Claim Button Scan", string.format("%d safe-looking visible claim buttons found. See F9 console.", #safeButtons), 6)
end

-- ============================================================================
-- OPTIONAL READ-ONLY HUD CHANGE WATCHER
-- Reports when visible Skill/Wins/Level/Rebirth-related text changes.
-- It doesn't read server-only stats or modify any values.
-- ============================================================================

local HudWatchEnabled = false
local HudWatchGeneration = 0

local function setHudWatch(enabled)
    HudWatchEnabled = enabled
    HudWatchGeneration += 1
    if not enabled then
        print("[YUEN HUD Watch] Stopped.")
        notify("HUD Watch", "Stopped.", 3)
        return
    end

    local generation = HudWatchGeneration
    notify("HUD Watch", "Watching visible Skill/Wins/Level/Rebirth UI text. Changes are logged to F9.", 5)
    task.spawn(function()
        local previous = {}
        local firstPass = true
        while HudWatchEnabled and generation == HudWatchGeneration do
            local playerGui = getPlayerGui()
            local current = {}
            local count = 0
            if playerGui then
                for _, obj in ipairs(playerGui:GetDescendants()) do
                    if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and isActuallyVisible(obj, playerGui) then
                        local textValue = textOf(obj)
                        local combined = normalizeGuiText(obj.Name .. " " .. textValue)
                        local isMetric = combined:find("skill", 1, true)
                            or combined:find("wins", 1, true)
                            or combined:find("level", 1, true)
                            or combined:find("rebirth", 1, true)
                        if isMetric and textValue ~= "" then
                            local key = safeFullName(obj)
                            current[key] = textValue
                            count += 1
                            if not firstPass and previous[key] ~= textValue then
                                print("[YUEN HUD Watch]", key, "=>", textValue)
                            end
                        end
                    end
                end
            end
            if firstPass then
                print(string.format("[YUEN HUD Watch] Started. Tracking %d visible metric-related UI items; later changes will be printed.", count))
                firstPass = false
            end
            previous = current
            task.wait(4)
        end
    end)
end

local function stopAllAutomation()
    if AutoThrowEnabled then setAutoThrow(false) end
    if AutoClaimEnabled then setAutoClaim(false) end
    if AutoEquipBestEnabled then setAutoEquipBest(false) end
    if RebirthAlertEnabled then setRebirthAlert(false) end
    if HudWatchEnabled then setHudWatch(false) end
    notify("YUEN Automation", "Loops stopped. Some Rayfield versions may leave toggle switches visually ON; turn those toggles OFF before starting them again.", 6)
end

-- ============================================================================
-- CURRENT PUBLIC RESEARCH NOTES / CODES (as of 2026-10-19)
-- Codes are crowdsourced reports, not guaranteed and not tested by this script.
-- ============================================================================

local codeGroups = {
    {
        title = "Newest codes reported active on 2026-10-18 (try first; not redeemed by this script)",
        codes = { "HALLOWEEN", "WORLD7", "50MVISITS" }
    },
    {
        title = "Also listed active by recent code guides; status may differ by server/update",
        codes = { "40MVISITS", "30MVISITS", "WORLD6", "2MGROUP", "40KLIKES", "1MFAV", "20MVISITS", "3KMEMBERS" }
    },
    {
        title = "Conflicting / older reports; test in-game, do not assume working",
        codes = { "2KSPECIAL", "500KFAV", "10MVISITS", "10KLIKES", "50KCCU", "40KCCU", "WORLD5", "SECRET2", "SECRET", "10KCCU", "5KCCU", "WORLD4", "WELCOME", "3000LIKES" }
    },
    {
        title = "Reported expired by at least one recent tracker",
        codes = { "WORLD3", "THANKYOU" }
    }
}

local function printCodeList()
    print("========== YUEN +1 STONE SKIPPING CODE NOTES ==========")
    print("Research snapshot: 2026-10-19. Codes are third-party reports, NOT live-verified. The in-game response is authoritative.")
    for _, group in ipairs(codeGroups) do
        print("--- " .. group.title .. " ---")
        print(table.concat(group.codes, ", "))
    end
    print("Redeem manually: Shop on left -> scroll to bottom -> Enter Code Here -> Redeem.")
    print("Finish the tutorial first if the game rejects codes. Exact status can change.")
    print("=======================================================")
    notify("Code List Printed", "Printed web-reported codes to F9. Newest codes are not guaranteed; test them in-game.", 7)
end

-- ============================================================================
-- UI: Home, Progression, Automation, Rewards & Codes, Diagnostics
-- ============================================================================

local HomeTab = Window:CreateTab("Home", 4483362458)
HomeTab:CreateSection("Welcome")
HomeTab:CreateParagraph({
    Title = "YUEN Stone Skipping Helper v3.0",
    Content = "Research-updated helper for the October 2026 build. Includes smarter visible-button Auto Throw, one-at-a-time free-reward claims, Equip Best cooldown, conservative rebirth alerts, live HUD change watching, code notes, and diagnostics. It does not invoke hidden game remotes or modify server-owned stats."
})
HomeTab:CreateButton({
    Name = "Scan HUD labels (F9 console)",
    Callback = function() scanHud() end
})
HomeTab:CreateButton({
    Name = "Scan world object names (F9 console)",
    Callback = function() scanWorldNames() end
})
HomeTab:CreateButton({
    Name = "Print researched code notes",
    Callback = function() printCodeList() end
})
HomeTab:CreateSection("The verified core loop")
HomeTab:CreateParagraph({
    Title = "Train → Throw → Wins → Upgrade → Rebirth",
    Content = "The official description says every bounce gives +1 Skill; Skill and level multipliers help throws travel farther, and farther zones earn more Wins. Stand on the highest training pad you have unlocked (Skill rises while training), jump to leave the pad, then throw from the yellow Throw Zone. Spend Wins on stronger stones and pets. Rebirth only when the current HUD and confirmation show you are ready."
})
HomeTab:CreateParagraph({
    Title = "Important automation note",
    Content = "Recent community guides report a native AUTO THROW sign/control or AUTO tag. If it's available to you, read the live unlock/price prompt and prefer the game's own feature. YUEN only detects the visible control for diagnosis; it never clicks it. The fallback Auto Throw activates the visible, active THROW button at your selected interval."
})

local ProgressTab = Window:CreateTab("Progression", 4483362458)
ProgressTab:CreateSection("Early route")
ProgressTab:CreateParagraph({
    Title = "Fresh account checklist",
    Content = "Community guides report the tutorial sequence as: gain 30 Skill → earn 2 Wins → equip a new stone/relic → reach Level 20 → rebirth. Follow live prompts in your own game if they differ. A visible THROW button reportedly appears only while standing on the yellow Throw Zone and hides during a throw; wait for it to return rather than spam-clicking."
})
ProgressTab:CreateSection("Training lanes and rebirth")
ProgressTab:CreateParagraph({
    Title = "Use your best unlocked multiplier",
    Content = "Stand on the highest unlocked training lane and let Skill rise. Guides report the 4x lane unlocking at 2 rebirths and the 10x lane at 4 rebirths; other lane signs (including 2x, 6x and 20x) have also been reported, so use the signage in your current build. Jump to exit the training zone—walking off reportedly may not work. Rebirth commonly resets Level and Skill, adds +1 to the Skill multiplier, and raises the level cap by 20 (observed caps include 20, 40, 60 and 80). Check the live confirmation before accepting."
})
ProgressTab:CreateSection("Zones, stones and pets")
ProgressTab:CreateParagraph({
    Title = "Observed first zone chain",
    Content = "Observed first-zone chain: Palm Beach → Cactus Desert → Autumn Woods → Mushroom Marsh → Frost Lake. Frost Lake has been reported around 35,000 Skill, but this is approximate and not play-verified. Some footage reports roughly 100 million Skill to reach world 2; this and later world gates are creator-reported, so read the in-game sign. Each world has its own stone ladder. Throwables reported in footage include roof tile, frisbee stone, cookie stone, donut, watermelon, runic tablet, meteorite, lily pad and pancake/waffle; this is not a complete catalogue and exact prices/stat formulas are unpublished. Pets are passive boosts; observed boosts vary by pet and world, so read each pet card and use Equip Best if available."
})
ProgressTab:CreateSection("Current worlds and Halloween event — community-reported")
ProgressTab:CreateParagraph({
    Title = "World gates reported on 18 October 2026",
    Content = "A recent community progression guide reports World 1 → Pirate World at 100M Skill; Pirate → Space at 400B; Space → Chocolate Factory at 15 QA (quadrillion); Chocolate Factory → Dragon Volcano at 500 QI (quintillion); World 6 opens after clearing World 5; and World 7 / Sakura Castle at 60 Oc (octillion) Skill. These are third-party observations, not official Roblox-published gate values; always trust the portal text in your running server."
})
ProgressTab:CreateParagraph({
    Title = "Halloween event (reported window)",
    Content = "A community guide reports the Halloween event running until 3 November 2026 at 19:00 UTC. Throws may trigger candy pumpkins; the Pumpkin King is reported every 20 minutes, with a 3-minute +50% Skill/Wins boost after defeating it. The guide also reports a Candy-based Halloween Pass and five hidden ghosts. YUEN doesn't guess internal pumpkin/boss names or automate event interactions, because those objects and rewards aren't verified in this client."
})

ProgressTab:CreateSection("Skill, Wins and boosts")
ProgressTab:CreateParagraph({
    Title = "What the numbers mean",
    Content = "The official description says every bounce grants +1 Skill. Actual gain can scale with stones, level multiplier, rebirth, training pads, pets, and timed boosts. A recent community guide reports 2x Skill and 2x Wins timed chips and a +10% Friend Boost when a friend is present; exact stacking formulas are not officially published. Wins depend on distance/zones, so examples from other players are not a fixed payout table."
})
ProgressTab:CreateSection("Free rewards")
ProgressTab:CreateParagraph({
    Title = "Rewards worth checking",
    Content = "Community footage describes a 7-day Daily Rewards calendar (Skill Boost, Fortune Neko pet, Win Boost, 2x Luck Boost, 3x Skill Boost, Win Boost, then a limited Shooting Star Relic), a 12-step Playtime Gifts wall with rewards that can include Wins, Skill, boosts and a Common Egg, a separate timed CLAIM chest near spawn, and offline Skill claimed through a Welcome Back popup. Playtime gifts reportedly extend to about 1h45m. These are guide-reported and may change. YUEN's Auto Claim can click visible, exact-label Claim/Collect buttons, but only when you enable it and keep the relevant free-reward window visible."
})
ProgressTab:CreateSection("Purchases")
ProgressTab:CreateParagraph({
    Title = "No automatic purchases",
    Content = "Stones, eggs, and boosts use in-game currencies or may be premium offers. Exact costs and item stats vary by world/progression and change over time. This script intentionally does not automate purchases, spend Robux, open eggs, or perform Rebirth without confirmation."
})

local AutomationTab = Window:CreateTab("Automation", 4483362458)
AutomationTab:CreateSection("Control")
AutomationTab:CreateButton({
    Name = "STOP ALL YUEN AUTOMATION",
    Callback = function() stopAllAutomation() end
})
AutomationTab:CreateParagraph({
    Title = "Safety and reliability",
    Content = "All automations use visible client-side buttons only. YUEN does not call RemoteEvents/RemoteFunctions directly; the game may run its normal handlers after a visible button is activated. STOP ALL stops every loop; in some Rayfield versions, toggle switches may still look ON afterward, so turn them OFF before restarting. Auto Claim is one-button-at-a-time and should be supervised on first use."
})
AutomationTab:CreateSection("Auto Throw")
AutomationTab:CreateParagraph({
    Title = "Visible THROW button only",
    Content = "Stand on the yellow Throw Zone so the game displays its THROW button. YUEN polls for the visible, active button and triggers it no more often than your selected interval. Polling is fast so it can react when THROW returns after a skip. It does not call remote APIs directly or modify server-owned stats."
})
AutomationTab:CreateSlider({
    Name = "Auto Throw delay",
    Range = {1, 8},
    Increment = 1,
    Suffix = " sec",
    CurrentValue = 2,
    Flag = "YUEN_AutoThrowDelay_v3",
    Callback = function(Value)
        AutoThrowDelay = math.clamp(tonumber(Value) or 2, 1, 8)
        print("[YUEN Auto Throw] Delay set to", AutoThrowDelay, "seconds.")
    end
})
AutomationTab:CreateToggle({
    Name = "Auto Throw (visible button)",
    CurrentValue = false,
    Flag = "YUEN_AutoThrow_v3",
    Callback = function(Value)
        setAutoThrow(Value == true)
    end
})
AutomationTab:CreateButton({
    Name = "Find visible THROW button",
    Callback = function()
        local button = findVisibleThrowButton()
        if button then
            print("[YUEN Auto Throw] Found:", safeFullName(button), "| Text:", textOf(button))
            notify("Throw Button Found", safeFullName(button), 5)
        else
            print("[YUEN Auto Throw] No visible THROW button. Stand in the Throw Zone and run Diagnostics > HUD scan.")
            notify("Throw Button Not Found", "Stand on the yellow Throw Zone so the game's button appears, then retry.", 6)
        end
    end
})
AutomationTab:CreateButton({
    Name = "Find native AUTO THROW toggle",
    Callback = function()
        local button = findVisibleNativeAutoThrowControl()
        if button then
            print("[YUEN] Native AUTO THROW control found:", safeFullName(button), "| Text:", textOf(button))
            notify("Native Auto Throw Found", "Found the game's own AUTO THROW control. Check its displayed price/access before using it; YUEN will not purchase it.", 7)
        else
            print("[YUEN] Native AUTO THROW control not found in visible TextButtons. It may be hidden, differently named, or not available in this version.")
            notify("Native Auto Throw Not Found", "No visible matching control. See Diagnostics > HUD scan.", 6)
        end
    end
})

AutomationTab:CreateSection("Free reward claiming")
AutomationTab:CreateParagraph({
    Title = "Auto Claim (opt-in)",
    Content = "Looks for visible TextButtons labeled exactly Claim, Claim Reward, Claim Your Reward, Claim All, Collect, or similar. Buttons whose nearby UI context mentions Robux, premium, gamepass, purchase, or paid offers are skipped. YUEN does not call remote APIs directly, redeem codes, or make purchases; the game may process its normal handler after a visible button is activated. UI labels can vary, so watch the first run."
})
AutomationTab:CreateSlider({
    Name = "Auto Claim cooldown",
    Range = {10, 60},
    Increment = 5,
    Suffix = " sec",
    CurrentValue = 20,
    Flag = "YUEN_AutoClaimDelay_v3",
    Callback = function(Value)
        AutoClaimDelay = math.clamp(tonumber(Value) or 20, 10, 60)
        print("[YUEN Auto Claim] Cooldown set to", AutoClaimDelay, "seconds.")
    end
})
AutomationTab:CreateToggle({
    Name = "Auto Claim visible free rewards",
    CurrentValue = false,
    Flag = "YUEN_AutoClaim_v3",
    Callback = function(Value)
        setAutoClaim(Value == true)
    end
})
AutomationTab:CreateButton({
    Name = "Scan visible claim buttons",
    Callback = function() scanClaimButtons() end
})

AutomationTab:CreateSection("Pet helper")
AutomationTab:CreateParagraph({
    Title = "Auto Equip Best",
    Content = "When the Pets menu is open, this can activate an exact visible Equip Best button. It does not hatch eggs or spend Wins."
})
AutomationTab:CreateToggle({
    Name = "Auto Equip Best (visible button)",
    CurrentValue = false,
    Flag = "YUEN_AutoEquipBest_v3",
    Callback = function(Value)
        setAutoEquipBest(Value == true)
    end
})
AutomationTab:CreateButton({
    Name = "Find visible Equip Best button",
    Callback = function()
        local button = findVisibleEquipBestButton()
        if button then
            print("[YUEN] Equip Best found:", safeFullName(button), "| Text:", textOf(button))
            notify("Equip Best Found", "Found the visible Equip Best control.", 5)
        else
            notify("Equip Best Not Found", "Open the Pets menu first, then try again or run HUD Scan.", 6)
        end
    end
})

AutomationTab:CreateSection("Rebirth readiness alert")
AutomationTab:CreateParagraph({
    Title = "Alert only — no automatic reset",
    Content = "Monitors visible HUD text for a combination suggesting MAX LEVEL, Rebirth, and 100%. It can miss custom UI layouts or produce a false alert. It never clicks the Rebirth button because rebirth resets Level/Skill and the reset confirmation should be checked manually."
})
AutomationTab:CreateToggle({
    Name = "Alert when rebirth may be ready",
    CurrentValue = false,
    Flag = "YUEN_RebirthAlert_v3",
    Callback = function(Value)
        setRebirthAlert(Value == true)
    end
})

local CodesTab = Window:CreateTab("Rewards & Codes", 4483362458)
CodesTab:CreateSection("Code notes from current public research")
CodesTab:CreateParagraph({
    Title = "Research snapshot: 19 October 2026",
    Content = "The official Roblox page confirms the core loop but does not publish full gate values or a detailed changelog. A community progression guide updated 18 October reports Worlds 5–7 and the Halloween event through 3 November 2026 at 19:00 UTC. Code trackers disagree on older codes. The newest codes below were listed active by a guide published 18 October; no code has been redeemed by this script. The live in-game response is authoritative."
})
CodesTab:CreateParagraph({
    Title = "Newest codes reported 18 October — try first",
    Content = "HALLOWEEN\nWORLD7\n50MVISITS"
})
CodesTab:CreateParagraph({
    Title = "Milestone codes reported active 17 October by another tracker",
    Content = "WORLD6\n40MVISITS\n30MVISITS\n2MGROUP\n40KLIKES\n1MFAV\n20MVISITS\n3KMEMBERS"
})
CodesTab:CreateParagraph({
    Title = "Status disputed by sources — may work or may be expired",
    Content = "2KSPECIAL, 500KFAV, 10MVISITS, 10KLIKES, 50KCCU, 40KCCU, WORLD5, SECRET2, SECRET, 10KCCU, 5KCCU, WORLD4, WELCOME, 3000LIKES. Try newer codes first; code lists may lag behind game updates."
})
CodesTab:CreateParagraph({
    Title = "How to redeem",
    Content = "Finish the opening tutorial if the game rejects codes. Open Shop from the left side, scroll to the bottom, enter the code exactly in Enter Code Here, and press the green Redeem button. Don't use third-party code-redeemer websites."
})
CodesTab:CreateButton({
    Name = "Print all researched codes to F9",
    Callback = function() printCodeList() end
})
CodesTab:CreateSection("Free progression rewards")
CodesTab:CreateParagraph({
    Title = "Claim these when ready",
    Content = "• Daily Rewards: calendar icon near the top right; the reported 7-day cycle includes Skill/Win/Luck boosts, Fortune Neko, and a limited Shooting Star Relic.\n• Playtime Gifts: Gifts button; reports describe 12 time-gated rewards up to about 1h45m.\n• Offline Skill: claim the Welcome Back popup after returning.\n• Spawn chest: a separate timed CLAIM chest has been reported near spawn.\nThese systems are independent; a ready timer or button in your live UI is the best evidence."
})

local DiagnosticsTab = Window:CreateTab("Diagnostics", 4483362458)
DiagnosticsTab:CreateSection("Read-only diagnostics and live HUD change watcher")
DiagnosticsTab:CreateParagraph({
    Title = "Why scans matter",
    Content = "This script has not been tested against private game code. HUD Scan reports client-visible UI labels, World Name Scan reports matching Workspace names, and Claim Button Scan reports exact visible Claim/Collect matches. Server-only data is not visible to this client, and unknown internal names are left unguessed."
})
DiagnosticsTab:CreateButton({
    Name = "Run HUD scan",
    Callback = function() scanHud() end
})
DiagnosticsTab:CreateButton({
    Name = "Run world name scan",
    Callback = function() scanWorldNames() end
})
DiagnosticsTab:CreateButton({
    Name = "Run claim button scan",
    Callback = function() scanClaimButtons() end
})
DiagnosticsTab:CreateSection("Progress monitor")
DiagnosticsTab:CreateParagraph({
    Title = "Read-only HUD Watch",
    Content = "Watches visible Skill/Wins/Level/Rebirth-related labels and prints changes in F9. It is useful for checking whether the game's visible counters change after an action; it cannot inspect server-only values."
})
DiagnosticsTab:CreateToggle({
    Name = "Watch visible HUD changes",
    CurrentValue = false,
    Flag = "YUEN_HudWatch_v3",
    Callback = function(Value) setHudWatch(Value == true) end
})
DiagnosticsTab:CreateButton({
    Name = "Stop all automation/watch loops",
    Callback = function() stopAllAutomation() end
})
DiagnosticsTab:CreateButton({
    Name = "Print player/game basics",
    Callback = function()
        print("========== YUEN CLIENT INFO ==========")
        print("Player:", LocalPlayer.Name)
        print("PlaceId:", game.PlaceId)
        print("GameId/UniverseId:", game.GameId)
        print("Players in server:", #Players:GetPlayers())
        print("PlayerGui present:", getPlayerGui() ~= nil)
        print("Auto Throw enabled:", AutoThrowEnabled)
        print("Auto Claim enabled:", AutoClaimEnabled)
        print("Auto Equip Best enabled:", AutoEquipBestEnabled)
        print("Rebirth alert enabled:", RebirthAlertEnabled)
        print("HUD Watch enabled:", HudWatchEnabled)
        print("Expected main PlaceId: 111543903102439")
        print("======================================")
        notify("Client Info", "Printed player and experience identifiers to F9 console.")
    end
})
DiagnosticsTab:CreateButton({
    Name = "Check possible rebirth readiness",
    Callback = function()
        local ready, reason = scanRebirthReadiness()
        print("[YUEN Rebirth Readiness] Ready-like state:", ready, "|", reason)
        notify("Rebirth Readiness Scan", ready and "HUD may indicate readiness. Review the actual confirmation manually." or ("No clear ready state detected: " .. reason), 7)
    end
})

if game.PlaceId ~= 111543903102439 then
    warn("[YUEN] This experience PlaceId is " .. tostring(game.PlaceId) .. "; research was gathered for main PlaceId 111543903102439. The script will continue, but UI scans may not match this place.")
end
notify("YUEN v3.0 Ready", "Research-updated helper loaded. Smart Auto Throw, cautious Auto Claim, Equip Best, rebirth alert, HUD watcher, current world notes, codes, and diagnostics are available.", 7)
