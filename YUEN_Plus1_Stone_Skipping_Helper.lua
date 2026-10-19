--[=[
    YUEN | +1 Stone Skipping Helper
    Version: 1.0
    Type: client-side guide + read-only diagnostics

    This script does not award Skill/Wins, call game remotes, automate purchases,
    teleport characters, or modify server-owned gameplay. The scanner only reads
    text/names currently replicated to the local client.
]=]

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
    LoadingSubtitle = "Guide • HUD scan • Diagnostics",
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

local keywords = {
    "skill", "wins", "level", "rebirth", "throw", "auto", "stone",
    "training", "train", "pet", "egg", "shop", "zone", "gift", "relic"
}

local function matchesKeywords(value)
    local lower = string.lower(tostring(value or ""))
    for _, word in ipairs(keywords) do
        if string.find(lower, word, 1, true) then return true end
    end
    return false
end

local function scanHud()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
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
                print(string.format("[HUD %02d] %s | Class=%s | Text=%s", count, safeFullName(obj), obj.ClassName, text))
            end
        end
    end
    print("[YUEN] HUD entries matched:", count)
    print("===================================")
    notify("HUD Scan Complete", string.format("Found %d matching UI labels/buttons. Check the client console (F9).", count))
    return count
end

local worldKeywords = {
    "training", "throw", "stone", "skill", "rebirth", "egg", "pet", "shop",
    "gift", "relic", "zone", "water", "lane", "spawn"
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
            if printed < 100 then
                printed += 1
                local details = ""
                if obj:IsA("BasePart") then
                    details = string.format(" | Position=(%.1f, %.1f, %.1f)", obj.Position.X, obj.Position.Y, obj.Position.Z)
                end
                print(string.format("[WORLD %03d] %s | Class=%s%s", count, safeFullName(obj), obj.ClassName, details))
            end
        end
    end
    print(string.format("[YUEN] Total name matches: %d (printed up to 100)", count))
    print("==========================================")
    notify("World Scan Complete", string.format("Found %d names matching common game keywords. See F9 console.", count))
    return count
end

local HomeTab = Window:CreateTab("Home", 4483362458)
HomeTab:CreateSection("Welcome")
HomeTab:CreateParagraph({
    Title = "YUEN Stone Skipping Helper",
    Content = "A mobile-friendly guide and read-only diagnostic menu. It does not exploit server remotes or create Skill/Wins. Use the in-game controls for throws, purchases, eggs, and rebirths."
})
HomeTab:CreateButton({
    Name = "Scan HUD labels (F9 console)",
    Callback = function() scanHud() end
})
HomeTab:CreateButton({
    Name = "Scan world object names (F9 console)",
    Callback = function() scanWorldNames() end
})
HomeTab:CreateSection("Basic Loop")
HomeTab:CreateParagraph({
    Title = "Train → Throw → Upgrade",
    Content = "Train Skill on a training lane, throw from the marked Throw Zone to earn Wins, spend Wins on better stones/relics/pets, then rebirth when the game says you are eligible. Every bounce is reported to grant Skill; longer throws generally reach farther zones and pay more Wins."
})

local ProgressTab = Window:CreateTab("Progression", 4483362458)
ProgressTab:CreateSection("Beginner Checklist")
ProgressTab:CreateParagraph({
    Title = "Suggested early route",
    Content = "1) Follow the live tutorial. Community guides report that it starts with Skill, then Wins, equipping a new stone, reaching Level 20, and rebirthing.\n\n2) Stand on the highest training lane you have unlocked. Jump to leave a lane if walking off does not work.\n\n3) Use the yellow Throw Zone and the game's own THROW button (some guides report E as the keyboard control).\n\n4) Early upgrade examples reported by a community guide: +3 Skill stone for 2 Wins, +5 Skill stone for 10 Wins, and Ammonite Fossil relic for 10 Wins. Check current in-game prices before buying.\n\n5) Rebirth only when the in-game meter says it is ready; this resets some progress but raises the multiplier/level cap."
})
ProgressTab:CreateSection("Later Progress")
ProgressTab:CreateParagraph({
    Title = "Training lanes and pets",
    Content = "A community guide reports that the 4x Skill lane unlocks at 2 rebirths and the 10x lane at 4 rebirths. Pets and stronger throwables can improve progression. The game updates, so treat these details as guide-reported and verify them in the current UI."
})
ProgressTab:CreateButton({
    Name = "Show important safety reminder",
    Callback = function()
        notify("Check before clicking", "Some boosts, instant-Skill buttons, and Auto Throw options may cost Robux or another premium currency. Read the price shown in-game first.", 7)
    end
})

local DiagnosticsTab = Window:CreateTab("Diagnostics", 4483362458)
DiagnosticsTab:CreateSection("Read-only diagnostics")
DiagnosticsTab:CreateParagraph({
    Title = "What these scans do",
    Content = "HUD Scan lists matching visible UI text. World Name Scan lists object names containing common gameplay keywords. The scans do not move objects, buy items, invoke remotes, change stats, or guarantee every server-side object is visible to the client."
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
    Name = "Print player/game basics",
    Callback = function()
        print("========== YUEN CLIENT INFO ==========")
        print("Player:", LocalPlayer.Name)
        print("PlaceId:", game.PlaceId)
        print("GameId/UniverseId:", game.GameId)
        print("Players in server:", #Players:GetPlayers())
        print("PlayerGui present:", LocalPlayer:FindFirstChildOfClass("PlayerGui") ~= nil)
        print("======================================")
        notify("Client Info", "Printed player and experience identifiers to F9 console.")
    end
})

notify("YUEN Ready", "Open Progression for tips or Diagnostics to inspect the current client UI.", 6)
