-- Made by Sharpedge_Gaming
-- v3.8 for 12.1.5 Midnight/Wow Forever

local addonName = "CombatTextPlus"

local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")

local CombatTextPlus = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

------------------------------------------------------------
-- Secret value helper
-- issecretvalue exists on 12.0 retail. On older clients nothing is secret.
-- Always call IsSecret BEFORE any truth test, comparison, math, or string
-- operation on a combat value. Those operations error on secrets.
------------------------------------------------------------
local IsSecret = issecretvalue or function() return false end

------------------------------------------------------------
-- Damage type data
------------------------------------------------------------
local DAMAGE_TYPES = {
    "physical", "holy", "fire", "nature", "frost",
    "shadow", "arcane", "chaos", "heal", "crit",
}

local TYPE_LABELS = {
    physical = "Physical", holy = "Holy", fire = "Fire", nature = "Nature",
    frost = "Frost", shadow = "Shadow", arcane = "Arcane", chaos = "Chaos",
    heal = "Heal", crit = "Crit",
}

local ANIMATION_STYLES = {
    off = "Off (Normal)",
    fade = "Fade",
    bounce = "Bounce",
    pulse = "Pulse",
    shake = "Shake",
    spiral = "Spiral",
    scale = "Scale",
    pop = "Pop",
    left = "Left → Right",
    right = "Right → Left",
    zigzag = "Zigzag",
    spiral_out = "Spiral Out",
    spiral_in = "Spiral In",
    ripple = "Wave Fade (Ripple)",
    flip = "Flip (3D style)",
    arc = "Arc (Blizzard style)",
    rainbow_lr = "Rainbow Left → Right",
    rainbow_rl = "Rainbow Right → Left",
}

-- UNIT_COMBAT actions that mean the attack did no normal damage.
local MISS_ACTIONS = {
    "MISS", "DODGE", "PARRY", "BLOCK", "RESIST",
    "IMMUNE", "EVADE", "DEFLECT", "REFLECT", "ABSORB",
}
local MISS_TEXT = {
    MISS = "Miss", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block",
    RESIST = "Resist", IMMUNE = "Immune", EVADE = "Evade",
    DEFLECT = "Deflect", REFLECT = "Reflect", ABSORB = "Absorb",
}

local SCHOOL_TO_TYPE = {
    [1] = "physical", [2] = "holy", [4] = "fire", [8] = "nature",
    [16] = "frost", [32] = "shadow", [64] = "arcane", [124] = "chaos",
}

------------------------------------------------------------
-- Default color preset
-- Standard school colors players expect: gold holy, orange fire, green
-- nature, light blue frost, purple shadow, pink arcane. Labels use the
-- same color as their number so each type reads as one unit.
------------------------------------------------------------
local PRESET_COLORS = {
    physical = {r = 1.00, g = 1.00, b = 1.00},  -- white
    holy     = {r = 1.00, g = 0.85, b = 0.20},  -- gold
    fire     = {r = 1.00, g = 0.50, b = 0.00},  -- orange
    nature   = {r = 0.30, g = 0.90, b = 0.30},  -- green
    frost    = {r = 0.45, g = 0.80, b = 1.00},  -- light blue
    shadow   = {r = 0.60, g = 0.35, b = 1.00},  -- purple
    arcane   = {r = 1.00, g = 0.45, b = 0.95},  -- pink
    chaos    = {r = 0.70, g = 1.00, b = 0.15},  -- fel green
    heal     = {r = 0.20, g = 1.00, b = 0.45},  -- bright green
    crit     = {r = 1.00, g = 0.25, b = 0.25},  -- red
}

-- Used when Blizzard hides the school. Neutral gray so it is not mistaken
-- for holy gold.
local PRESET_RESTRICTED_COLOR = {r = 0.80, g = 0.80, b = 0.80}

local function CopyColor(c)
    return {r = c.r, g = c.g, b = c.b}
end

local function CopyColorSet(set)
    local out = {}
    for k, c in pairs(set) do
        out[k] = CopyColor(c)
    end
    return out
end

------------------------------------------------------------
-- Old defaults, needed only for the one time saved variable migration.
-- AceDB saves only the color parts that differ from the defaults. A custom
-- color like red {1, 0, 0} was stored as {g = 0, b = 0} because r matched
-- the old white default. If the default changes, the missing r would be
-- filled from the new default and the player's color would shift. The
-- migration writes the old values back into any customized color first.
------------------------------------------------------------
local OLD_TYPE_COLOR = {r = 1, g = 1, b = 1}
local OLD_RESTRICTED_COLOR = {r = 1, g = 0.82, b = 0}
local COLOR_MIGRATION_VERSION = 1

------------------------------------------------------------
-- Defaults
-- Speed math: a number stays on screen for scrollDuration / speedFactor
-- seconds and travels maxYOffset * speedFactor pixels. The old defaults
-- (0.5 / 2.0) gave a quarter second over 200 pixels, which nobody could
-- read. New defaults give 1.5 seconds over 100 pixels.
------------------------------------------------------------
local savedVariables = {
    profile = {
        font = "Friz Quadrata TT",
        textColor = {r = 1, g = 1, b = 1, a = 1},
        fontSize = 24,
        labelFontSize = 14,
        enabled = true,
        scrollDuration = 1.5,
        animationStyle = "fade",
        animationEasing = "linear",
        startYOffset = 0,           -- where numbers start, above (+) or below (-) the nameplate. Contributed by Borod4r.
        maxYOffset = 100,
        speedFactor = 1.0,
        damageTypeOffsets = {
            physical = -10, holy = 10, fire = 0, nature = -15, frost = 15,
            shadow = 0, arcane = 0, chaos = 0, heal = 0, crit = 5,
        },
        damageTypeFilters = {
            physical = true, holy = true, fire = true, nature = true, frost = true,
            shadow = true, arcane = true, chaos = true, heal = true, crit = true,
        },
        damageTypeColors = CopyColorSet(PRESET_COLORS),
        labelColors = CopyColorSet(PRESET_COLORS),
        minimap = { hide = false },
        damageTypeFontSizes = {
            physical = 24, holy = 24, fire = 24, nature = 24,
            frost = 24, shadow = 24, arcane = 24, chaos = 24,
            heal = 24, crit = 24,
        },
        showLabels = true,
        showSpellIcons = false,     -- icon of the spell that made each hit
        spellIconPosition = "left", -- "left" or "right" of the number
        spellIconSize = 1.0,        -- icon size as a multiple of the number's font size
        spellIconGuess = false,     -- when a hit cannot be confirmed, use your last cast if it clearly fits
        animationAmplitude = 30,
        animationFrequency = 2,
        animationPulses = 3,
        animationHorizontalDistance = 120,
        horizontalStagger = 14,

        -- Midnight settings
        unitEventScope = "all",     -- "all" or "target"
        onlyMyFights = true,        -- hide damage on enemies you are not fighting
        engageTimeout = 6,          -- seconds an enemy stays "yours" after your last attack on it
        strictEngage = false,       -- only enemies you targeted and attacked, no threat fallback
        pvpTargetOnly = false,      -- in battlegrounds and arenas, only show numbers on your current target
        healScope = "auto",         -- "auto", "mine", "group", "target", "all", or "off"
        healTimeout = 15,           -- seconds a friendly stays "healed by you" after your last heal on it
        restrictedColor = CopyColor(PRESET_RESTRICTED_COLOR),

        -- Display
        keepTextOnRemoval = true,   -- numbers finish their animation when a nameplate disappears
        displayMode = "nameplates", -- "nameplates", "center", or "both"
        centerX = 0,                -- center display position, pixels from screen center
        centerY = 150,
        centerMaxNumbers = 6,       -- most numbers the center display shows at once

        -- Overlap and volume
        preventOverlap = true,      -- push older numbers up so new ones never land on top of them
        lineSpacing = 1.1,          -- space between pushed numbers, as a multiple of the font size
        maxPerPlate = 8,            -- most numbers on one nameplate at once (0 = no limit)

        -- Crits
        critColorMode = "crit",     -- "crit" (Crit color and size) or "school" (damage type color, bigger)
        critSizeMultiplier = 2.0,   -- school mode: crit font size = damage type font size x this
        critAnimation = "same",     -- "same" as normal hits, or any animation style
        critLabel = false,          -- school mode: label reads "Fire Crit" instead of "Fire"

        -- Misses on enemies (Miss, Dodge, Parry, Immune...)
        showMisses = false,
        missTypes = {
            MISS = true, DODGE = true, PARRY = true, BLOCK = true, RESIST = true,
            IMMUNE = true, EVADE = true, DEFLECT = true, REFLECT = true, ABSORB = true,
        },
        missColor = {r = 0.75, g = 0.75, b = 0.75},
        missFontSize = 20,

        -- Your own avoidance (attacks on you that missed)
        showMyAvoidance = false,
        avoidanceColor = {r = 0.40, g = 0.75, b = 1.00},
        avoidanceFontSize = 22,
        avoidanceX = -150,
        avoidanceY = 40,
        avoidanceMaxNumbers = 4,
    }
}

------------------------------------------------------------
-- Saved variable migration
-- Runs on the raw saved table BEFORE AceDB wraps it, so missing color
-- parts read as nil instead of falling through to the new defaults.
------------------------------------------------------------
local function FillMissing(c, old)
    if type(c) ~= "table" then return end
    if c.r == nil then c.r = old.r end
    if c.g == nil then c.g = old.g end
    if c.b == nil then c.b = old.b end
end

local function MigrateSavedColors()
    local sv = _G.CombatTextPlusDB
    if type(sv) ~= "table" then return end
    if type(sv.global) == "table" and (sv.global.colorMigration or 0) >= COLOR_MIGRATION_VERSION then
        return
    end

    if type(sv.profiles) == "table" then
        for _, profile in pairs(sv.profiles) do
            if type(profile) == "table" then
                for _, key in ipairs({"damageTypeColors", "labelColors"}) do
                    local group = profile[key]
                    if type(group) == "table" then
                        for _, c in pairs(group) do
                            FillMissing(c, OLD_TYPE_COLOR)
                        end
                    end
                end
                FillMissing(profile.restrictedColor, OLD_RESTRICTED_COLOR)
            end
        end
    end

    sv.global = sv.global or {}
    sv.global.colorMigration = COLOR_MIGRATION_VERSION
end

------------------------------------------------------------
-- State
------------------------------------------------------------
local db
local debugMode = false     -- false, "target" (current target only), or "all"

local activeTexts = {}      -- [frame] = true
local stacks = {}           -- stacks[anchor][damageType] = { frame, frame, ... }
local framePool = {}
local pendingIcons = {}     -- text frames still waiting for the damage meter to confirm their spell
local arcSide = 1           -- flips each hit so Arc numbers alternate left and right

local ghostPool = {}        -- spare anchors for numbers whose nameplate went away
local centerAnchor          -- fixed anchor for the center screen display
local avoidAnchor           -- fixed anchor for your own avoidance text
local targetEngagedAt = 0   -- GetTime() of your last attack on your current target

local plateByUnit = {}      -- "nameplate3" -> plate frame
local engagedPlates = {}    -- [plate] = GetTime() of your last attack on that enemy
local healedPlates = {}     -- [plate] = GetTime() of your last heal cast on that friendly

local AUTO_ATTACK_ID = 6603
local AUTO_SHOT_ID = 75

local previewAnchor

local eventFrame = CreateFrame("Frame", "CombatTextPlusFrame", UIParent)

-- Decides whether a debug line should print for this unit. Target mode keeps
-- chat readable on a crowded dummy row by only reporting your current target.
local function DebugWants(unit)
    if not debugMode then return false end
    if debugMode == "all" then return true end
    if not UnitExists("target") then return false end
    local isTarget = UnitIsUnit(unit, "target")
    if IsSecret(isTarget) then return false end
    return isTarget and true or false
end

------------------------------------------------------------
-- Utility
------------------------------------------------------------
-- Turns off Blizzard's damage and healing numbers over targets so they do not
-- double up with ours. Self text (numbers over your own character) is left alone.
-- Midnight renamed these settings with a _v2 suffix. The old names are kept for
-- older clients; setting a name that does not exist is harmless inside pcall.
local BLIZZARD_COMBAT_TEXT_CVARS = {
    "floatingCombatTextCombatDamage_v2",
    "floatingCombatTextCombatHealing_v2",
    "floatingCombatTextCombatLogPeriodicSpells_v2",
    "floatingCombatTextPetMeleeDamage_v2",
    "floatingCombatTextPetSpellDamage_v2",
    "floatingCombatTextCombatDamage",
    "floatingCombatTextCombatHealing",
    "floatingCombatTextCombatLogPeriodicSpells",
    "floatingCombatTextPetMeleeDamage",
    "floatingCombatTextPetSpellDamage",
}

local function DisableBlizzardCombatText()
    for _, cvar in ipairs(BLIZZARD_COMBAT_TEXT_CVARS) do
        pcall(SetCVar, cvar, 0)
    end
end

-- Blizzard's settings panel opener is protected in 12.0 and pcall cannot stop
-- the blocked action popup. The Ace standalone window is never protected.
local function OpenOptions()
    if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames["CombatTextPlus"] then
        AceConfigDialog:Close("CombatTextPlus")
    else
        AceConfigDialog:Open("CombatTextPlus")
    end
end

-- Used only by /ctp status so you can confirm what the addon thinks is going on.
local function IsRestrictedContext()
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end
    return false
end

------------------------------------------------------------
-- LDB launcher
------------------------------------------------------------
local CombatTextPlusLDB = LDB:NewDataObject("CombatTextPlus", {
    type = "launcher",
    text = "CombatTextPlus",
    icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    OnClick = function(_, button)
        if button == "LeftButton" then
            OpenOptions()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("|cFF00FF00CombatTextPlus|r")
        tooltip:AddLine("|cFFFFFFFFLeft click to open or close settings.|r")
    end,
})

------------------------------------------------------------
-- Frame pool
-- The old version created a new frame per hit. WoW never frees frames,
-- so that leaked memory for the whole session. Frames are now recycled.
------------------------------------------------------------
local function RemoveFromStack(f)
    local anchorStacks = f.anchor and stacks[f.anchor]
    if not anchorStacks then return end
    local list = anchorStacks[f.damageType]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == f then
            table.remove(list, i)
            break
        end
    end
end

local function ReleaseGhostRef(anchor)
    if not anchor or not anchor.isGhost then return end
    anchor.refs = (anchor.refs or 1) - 1
    if anchor.refs <= 0 then
        anchor.refs = 0
        stacks[anchor] = nil
        anchor:Hide()
        anchor:ClearAllPoints()
        ghostPool[#ghostPool + 1] = anchor
    end
end

local function ReleaseTextFrame(f)
    if not f or f.released then return end
    f.released = true
    f:SetScript("OnUpdate", nil)
    RemoveFromStack(f)
    activeTexts[f] = nil
    local oldAnchor = f.anchor
    f:Hide()
    f:ClearAllPoints()
    f:SetParent(UIParent)
    f:SetScale(1)
    f:SetAlpha(1)
    f.text:SetText("")
    f.label:SetText("")
    if f.icon then f.icon:Hide() end
    f.spellIconID = nil
    pendingIcons[f] = nil
    f.anchor = nil
    f.damageType = nil
    f.startTime = nil
    f.isCrit = nil
    f.bumpY, f.bumpTarget, f.curY, f.lineH = 0, 0, nil, nil
    framePool[#framePool + 1] = f
    ReleaseGhostRef(oldAnchor)
end

local function AcquireTextFrame(anchor)
    local f = table.remove(framePool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(200, 50)
        f.text = f:CreateFontString(nil, "OVERLAY")
        f.text:SetPoint("CENTER", f, "CENTER")
        f.label = f:CreateFontString(nil, "OVERLAY")
        f.label:SetPoint("LEFT", f.text, "RIGHT", 5, 0)
        f.icon = f:CreateTexture(nil, "OVERLAY")
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's built in border
        f.icon:Hide()
    end
    f.released = false
    f:SetParent(anchor)
    f:ClearAllPoints()
    f:SetScale(1)
    f:SetAlpha(1)
    f.anchor = anchor
    activeTexts[f] = true
    return f
end

local function ReleaseAllOnAnchor(anchor)
    for f in pairs(activeTexts) do
        if f.anchor == anchor then
            ReleaseTextFrame(f)
        end
    end
    stacks[anchor] = nil
end

local function ReleaseAll()
    for f in pairs(activeTexts) do
        ReleaseTextFrame(f)
    end
    wipe(stacks)
end

------------------------------------------------------------
-- Keep numbers when a nameplate disappears
-- A nameplate goes away when its enemy dies or leaves range, and the game
-- hands that same frame to another unit right after. Numbers attached to it
-- would vanish or jump to the wrong enemy. Instead, they move to a stand in
-- anchor pinned to the nameplate's last screen position and finish their
-- animation there. Only frames move; the numbers are never read, so this is
-- safe with secret values.
------------------------------------------------------------
local function AcquireGhost()
    local g = table.remove(ghostPool)
    if not g then
        g = CreateFrame("Frame", nil, UIParent)
        g:SetSize(1, 1)
        g.isGhost = true
    end
    g.refs = 0
    g:Show()
    return g
end

local function DetachPlateTexts(plate)
    local hasTexts = false
    for f in pairs(activeTexts) do
        if f.anchor == plate then
            hasTexts = true
            break
        end
    end
    if not hasTexts then
        stacks[plate] = nil
        return
    end

    local okC, cx = pcall(plate.GetCenter, plate)
    local okB, bottom = pcall(plate.GetBottom, plate)
    local okS, plateScale = pcall(plate.GetEffectiveScale, plate)
    if not (okC and okB and okS) or cx == nil or bottom == nil or plateScale == nil
        or IsSecret(cx) or IsSecret(bottom) or IsSecret(plateScale) then
        ReleaseAllOnAnchor(plate)
        return
    end

    local uiScale = UIParent:GetEffectiveScale()
    if not uiScale or uiScale <= 0 or plateScale <= 0 then
        ReleaseAllOnAnchor(plate)
        return
    end

    -- Matching the nameplate's scale keeps the numbers the same size, and
    -- lets the nameplate's own coordinates be used directly.
    local ghost = AcquireGhost()
    ghost:SetScale(plateScale / uiScale)
    ghost:ClearAllPoints()
    ghost:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx, bottom)

    for f in pairs(activeTexts) do
        if f.anchor == plate then
            f:SetParent(ghost)
            f:ClearAllPoints()
            f.anchor = ghost
            ghost.refs = ghost.refs + 1
        end
    end
    stacks[ghost] = stacks[plate]
    stacks[plate] = nil
end

------------------------------------------------------------
-- Center screen display
------------------------------------------------------------
local function GetCenterAnchor()
    if not centerAnchor then
        centerAnchor = CreateFrame("Frame", "CombatTextPlusCenterAnchor", UIParent)
        centerAnchor:SetSize(1, 1)
    end
    return centerAnchor
end

local function PositionCenterAnchor()
    local a = GetCenterAnchor()
    a:ClearAllPoints()
    a:SetPoint("CENTER", UIParent, "CENTER", db.profile.centerX or 0, db.profile.centerY or 150)
end

-- Keeps the center display readable. When it is full, the oldest number
-- goes first, but a crit is only bumped when everything showing is a crit.
local function MakeRoomOn(anchor, maxNumbers)
    if not anchor then return end
    while true do
        local count, oldest, oldestCrit = 0, nil, nil
        for f in pairs(activeTexts) do
            if f.anchor == anchor then
                count = count + 1
                local t = f.startTime or 0
                if f.isCrit then
                    if not oldestCrit or t < (oldestCrit.startTime or 0) then oldestCrit = f end
                else
                    if not oldest or t < (oldest.startTime or 0) then oldest = f end
                end
            end
        end
        if count < maxNumbers then return end
        ReleaseTextFrame(oldest or oldestCrit)
    end
end

------------------------------------------------------------
-- Your own avoidance display
-- Fixed spot near your character. Attacks on you are aimed at you, so
-- unlike enemy numbers there is no question of whose event it is.
------------------------------------------------------------
local function GetAvoidAnchor()
    if not avoidAnchor then
        avoidAnchor = CreateFrame("Frame", "CombatTextPlusAvoidAnchor", UIParent)
        avoidAnchor:SetSize(1, 1)
    end
    return avoidAnchor
end

local function PositionAvoidAnchor()
    local a = GetAvoidAnchor()
    a:ClearAllPoints()
    a:SetPoint("CENTER", UIParent, "CENTER", db.profile.avoidanceX or -150, db.profile.avoidanceY or 40)
end

------------------------------------------------------------
-- Nameplate tracking
------------------------------------------------------------
local function TrackPlate(unit)
    if not unit then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    if plate.IsForbidden and plate:IsForbidden() then return end
    plateByUnit[unit] = plate
end

local function UntrackPlate(unit)
    if not unit then return end
    local plate = plateByUnit[unit]
    if plate then
        if db and db.profile.keepTextOnRemoval then
            DetachPlateTexts(plate)
        else
            ReleaseAllOnAnchor(plate)
        end
        engagedPlates[plate] = nil
        healedPlates[plate] = nil
    end
    plateByUnit[unit] = nil
end

local function RebuildPlates()
    ReleaseAll()
    wipe(plateByUnit)
    wipe(engagedPlates)
    wipe(healedPlates)
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            TrackPlate(unit)
        end
    end
end

------------------------------------------------------------
-- Engagement tracking
-- Marks your current target's nameplate when you cast, channel, or auto
-- attack. This is how we know a dummy or mob is yours even when threat
-- data is not available.
------------------------------------------------------------
local function IsInPvPInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

-- Only harmful spells count as attacking. A heal, buff, mount, or trinket
-- used while an enemy is targeted must not mark that enemy as yours.
local function IsAttackSpell(spellID)
    if spellID == nil or IsSecret(spellID) or type(spellID) ~= "number" then
        return true
    end
    -- Only the C_Spell version takes a spell ID. The old global takes a
    -- spellbook slot and would answer about the wrong spell.
    local check = C_Spell and C_Spell.IsSpellHarmful
    if not check then return true end
    local ok, harmful = pcall(check, spellID)
    if not ok or harmful == nil or IsSecret(harmful) then
        return true
    end
    return harmful and true or false
end

local function MarkTargetEngaged(spellID)
    if not IsAttackSpell(spellID) then
        if debugMode and spellID and not IsSecret(spellID) then
            CombatTextPlus:Print(("engage | spell %s not counted as an attack (game says it is not harmful)"):format(tostring(spellID)))
        end
        return
    end
    if not UnitExists("target") then return end
    local canAttack = UnitCanAttack("player", "target")
    if IsSecret(canAttack) or not canAttack then return end
    -- Tracked separately so the center display works even when the target
    -- has no nameplate.
    targetEngagedAt = GetTime()
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if plate then
        engagedPlates[plate] = GetTime()
        if debugMode then
            CombatTextPlus:Print(("engage | target marked as yours (spell %s)"):format(
                (spellID == nil and "auto attack") or (IsSecret(spellID) and "[secret]") or tostring(spellID)))
        end
    elseif debugMode then
        CombatTextPlus:Print("engage | target has no nameplate, nothing marked")
    end
end

-- The stamp is kept after it times out (it is wiped when you leave combat
-- or the nameplate goes away). Strict mode uses "attacked at some point this
-- fight" to decide whether your debuff on an enemy counts.
local function IsPlateEngaged(plate)
    local stamp = plate and engagedPlates[plate]
    if not stamp then return false end
    local timeout = (db and db.profile.engageTimeout) or 6
    if timeout > 0 and (GetTime() - stamp) > timeout then
        return false
    end
    return true
end

------------------------------------------------------------
-- Debuff check
-- A single DoT cast can tick for 20 seconds or more, long after the engage
-- timeout runs out. If one of YOUR debuffs is on the enemy, it is your
-- fight. The PLAYER filter only returns auras you cast. In restricted
-- content the answer may be hidden, in which case this returns false and
-- the normal checks decide.
------------------------------------------------------------
local function PlayerHasDebuffOn(unit)
    local getAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not getAura then return false end
    local ok, aura = pcall(getAura, unit, 1, "HARMFUL|PLAYER")
    if not ok or aura == nil or IsSecret(aura) then
        return false
    end
    return true
end

------------------------------------------------------------
-- Heal tracking
-- UNIT_COMBAT reports every heal a friendly receives, from anyone. That is
-- why a stranger at the Auction House was showing numbers: someone else was
-- healing them. The fix mirrors the damage side: a friendly only counts as
-- yours once you cast a helpful spell with it targeted.
------------------------------------------------------------

-- True unless the game says for certain the spell is not helpful. When the
-- answer is hidden we still mark, since the target must also be friendly.
local function IsHelpfulSpell(spellID)
    if spellID == nil or IsSecret(spellID) or type(spellID) ~= "number" then
        return true
    end
    local check = C_Spell and C_Spell.IsSpellHelpful
    if not check then return true end
    local ok, helpful = pcall(check, spellID)
    if not ok or helpful == nil or IsSecret(helpful) then
        return true
    end
    return helpful and true or false
end

local function MarkTargetHealed(spellID)
    if not IsHelpfulSpell(spellID) then return end
    if not UnitExists("target") then return end
    local canAttack = UnitCanAttack("player", "target")
    if IsSecret(canAttack) or canAttack then return end
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if plate then
        healedPlates[plate] = GetTime()
    end
end

-- Healers rarely target who they heal. Mouseover, raid frame and click
-- casting all skip the target. UNIT_SPELLCAST_SENT still reports the name
-- of whoever the spell went to, so that name is matched to a friendly plate.
local function MarkNamedFriendlyHealed(targetName, spellID)
    if targetName == nil or IsSecret(targetName) or type(targetName) ~= "string" or targetName == "" then
        return
    end
    if not IsHelpfulSpell(spellID) then return end

    local shortName = targetName:match("^([^%-]+)") or targetName
    local now = GetTime()

    for unit, plate in pairs(plateByUnit) do
        local canAttack = UnitCanAttack("player", unit)
        if not IsSecret(canAttack) and not canAttack then
            local name, realm = UnitName(unit)
            if name and not IsSecret(name) and not IsSecret(realm) then
                local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
                if fullName == targetName or name == shortName then
                    healedPlates[plate] = now
                end
            end
        end
    end
end

local function IsHealerSpec()
    if not GetSpecialization or not GetSpecializationRole then return false end
    local index = GetSpecialization()
    if not index or index == 0 then return false end
    return GetSpecializationRole(index) == "HEALER"
end

local function IsPlateHealed(plate)
    local stamp = plate and healedPlates[plate]
    if not stamp then return false end
    local timeout = (db and db.profile.healTimeout) or 15
    if timeout > 0 and (GetTime() - stamp) > timeout then
        healedPlates[plate] = nil
        return false
    end
    return true
end

-- One entry point for your own casts: marks an enemy target as fought
-- or a friendly target as healed, whichever applies.
local function OnPlayerCast(spellID)
    MarkTargetEngaged(spellID)
    MarkTargetHealed(spellID)
end

local function IsAutoAttacking()
    if not IsCurrentSpell then return false end
    return IsCurrentSpell(AUTO_ATTACK_ID) or IsCurrentSpell(AUTO_SHOT_ID)
end

------------------------------------------------------------
-- Preview
------------------------------------------------------------
function CombatTextPlus:ShowPreviewCombatText()
    local previewTypes = {"physical", "holy", "fire", "frost", "shadow", "heal", "crit"}
    local previewValues = {
        physical = 1234, holy = 2345, fire = 5678, frost = 4321,
        shadow = 3210, heal = 3456, crit = 9999,
    }

    local anchor
    for _, plate in pairs(plateByUnit) do
        anchor = plate
        break
    end
    if not anchor then
        if not previewAnchor then
            previewAnchor = CreateFrame("Frame", nil, UIParent)
            previewAnchor:SetSize(1, 1)
            previewAnchor:SetPoint("CENTER", UIParent, "CENTER", -600, 0)
        end
        anchor = previewAnchor
    end

    local mode = db.profile.displayMode or "nameplates"
    for i, previewType in ipairs(previewTypes) do
        C_Timer.After((i - 1) * 0.25, function()
            -- In Damage Type Color mode the sample crit shows as a Fire crit.
            local damageType, isCrit = previewType, previewType == "crit"
            if isCrit and db.profile.critColorMode == "school" then
                damageType = "fire"
            end
            local value = previewValues[previewType]
            if previewType == "frost" and db.profile.showMisses then
                damageType, value = "miss", "Dodge"
            end
            if mode ~= "center" then
                CombatTextPlus:DisplayCombatText(anchor, value, damageType, isCrit, "preview")
            end
            if mode ~= "nameplates" then
                PositionCenterAnchor()
                CombatTextPlus:DisplayCombatText(GetCenterAnchor(), value, damageType, isCrit, "preview")
            end
        end)
    end
    if db.profile.showMyAvoidance then
        for i, text in ipairs({"Parry", "Dodge"}) do
            C_Timer.After(i * 0.5, function()
                PositionAvoidAnchor()
                CombatTextPlus:DisplayCombatText(GetAvoidAnchor(), text, "avoid")
            end)
        end
    end
end

------------------------------------------------------------
-- Animation
------------------------------------------------------------
function CombatTextPlus:GetEasedProgress(progress)
    local easing = db.profile.animationEasing
    if easing == "quadratic" then
        return progress * progress
    elseif easing == "exponential" then
        return progress ^ 3
    end
    return progress
end

function CombatTextPlus:GetMovementOffsets(damageType, progress)
    local xOffset = (db.profile.damageTypeOffsets[damageType] or 0) * progress
    local maxYOffset = db.profile.maxYOffset or 100
    local yOffset = maxYOffset * progress * db.profile.speedFactor

    return xOffset, yOffset
end

-- Every animation style positions its text through this. It adds the
-- overlap push and remembers where the text sits, using only our own
-- numbers. Frame positions are never read back from the game, since
-- anything attached to a nameplate can come back hidden in Midnight.
local function SetTextPos(f, anchor, x, y)
    local bump = f.bumpY or 0
    -- Start Y Offset (contributed by Borod4r) is applied here so every
    -- animation style starts from the same raised or lowered spot.
    -- Fixed displays (center screen, avoidance) are already placed by their
    -- own position sliders, so it only applies to nameplates.
    local start = 0
    if anchor ~= centerAnchor and anchor ~= avoidAnchor then
        start = db.profile.startYOffset or 0
    end
    f:SetPoint("CENTER", anchor, "BOTTOM", x, y + bump + start)
    f.curY = y + bump
end

function CombatTextPlus:ApplyAnimationStyle(f, anchor, damageType, progress, stackIndex, stackCount)
    local function ClampAlpha(a)
        return math.max(0, math.min(1, a or 0))
    end

    local style = db.profile.animationStyle
    if f.isCrit then
        local critStyle = db.profile.critAnimation or "same"
        if critStyle ~= "same" then
            style = critStyle
        end
    end
    local eased = self:GetEasedProgress(progress)
    local baseX, baseY = self:GetMovementOffsets(damageType, eased)

    local amplitude = db.profile.animationAmplitude or 30
    local frequency = db.profile.animationFrequency or 2
    local pulses = db.profile.animationPulses or 3
    local maxY = db.profile.maxYOffset or 100
    local speedFactor = db.profile.speedFactor or 1
    local stagger = db.profile.horizontalStagger or 14
    local horizDist = db.profile.animationHorizontalDistance or (maxY * speedFactor)

    if style == "fade" then
        SetTextPos(f, anchor, baseX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "off" then
        SetTextPos(f, anchor, baseX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))
        f:SetScale(1)

    elseif style == "bounce" then
        local bounce = math.abs(math.sin(eased * math.pi * 3) * (1 - eased) * 100)
        SetTextPos(f, anchor, baseX, baseY + bounce)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "pulse" then
        -- Rises while throbbing in size a few times, fading out at the end.
        local throb = math.abs(math.sin(eased * math.pi * 3)) * 0.35 * (1 - eased)
        SetTextPos(f, anchor, baseX, baseY)
        f:SetScale(1 + throb)
        f:SetAlpha(ClampAlpha(eased < 0.6 and 1 or (1 - (eased - 0.6) / 0.4)))

    elseif style == "shake" then
        local shakeX = math.sin(eased * 30) * 25
        SetTextPos(f, anchor, baseX + shakeX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "spiral" then
        local angle = eased * 8 * math.pi
        local radius = 80 * eased
        local sx = math.cos(angle) * radius
        local sy = math.sin(angle) * radius + (maxY * eased * speedFactor)
        SetTextPos(f, anchor, sx, sy)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "scale" then
        SetTextPos(f, anchor, baseX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))
        f:SetScale(1 + eased * 2)

    elseif style == "pop" then
        local popScale
        if eased < 0.2 then
            popScale = 1 + eased * 4
        else
            popScale = 1.8 - (eased - 0.2) * 2
        end
        SetTextPos(f, anchor, baseX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))
        f:SetScale(popScale)

    elseif style == "left" or style == "right" then
        local direction = (style == "left") and 1 or -1
        local moveX = direction * horizDist * eased

        local scount = tonumber(stackCount) or 1
        if scount < 1 then scount = 1 end
        local sindex = tonumber(stackIndex) or 1
        local centerOffset = ((scount - 1) * stagger) * 0.5
        local staggerY = ((sindex - 1) * stagger) - centerOffset

        local moveY = baseY + (maxY * eased * 0.6) + staggerY
        SetTextPos(f, anchor, moveX, moveY)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "zigzag" then
        local steps = math.max(1, math.floor(frequency * 2))
        local zig = math.sin(eased * math.pi * steps) * amplitude * (1 - eased)
        SetTextPos(f, anchor, baseX + zig, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))
        f:SetScale(1)

    elseif style == "spiral_out" then
        local angle = eased * 2 * 2 * math.pi
        local radius = (80 + amplitude) * eased
        local sx = math.cos(angle) * radius
        local sy = math.sin(angle) * radius + (maxY * eased * speedFactor)
        SetTextPos(f, anchor, sx, sy)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "spiral_in" then
        local angle = (1 - eased) * 2 * 2 * math.pi
        local radius = (80 + amplitude) * (1 - eased)
        local sx = math.cos(angle) * radius
        local sy = math.sin(angle) * radius + (maxY * eased * speedFactor * 0.5)
        SetTextPos(f, anchor, sx, sy)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "ripple" then
        local pulse = math.sin(eased * math.pi * pulses) * 0.25 * (1 - eased)
        SetTextPos(f, anchor, baseX, baseY)
        f:SetScale(1 + pulse)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "arc" then
        -- Blizzard style arc: the number pops up, curves out to one side, and
        -- drops back down like a fountain. Hits alternate left and right.
        -- Crits get a quick pop in size at the start.
        local dir = f.arcDir or 1
        local moveX = dir * horizDist * 0.6 * eased
        local moveY = maxY * (2.5 * eased - 3 * eased * eased)
        SetTextPos(f, anchor, baseX + moveX, moveY)

        local s = 1
        if f.isCrit then
            if eased < 0.1 then
                s = 1 + eased * 5
            elseif eased < 0.35 then
                s = 1.5 - ((eased - 0.1) / 0.25) * 0.5
            end
        end
        f:SetScale(s)
        f:SetAlpha(ClampAlpha(eased < 0.6 and 1 or (1 - (eased - 0.6) / 0.4)))

    elseif style == "rainbow_lr" or style == "rainbow_rl" then
        -- Rainbow: the number travels over a half circle arch from the
        -- nameplate to one side, peaking in the middle. Width is set by
        -- Horizontal Distance, height by Max Y Offset.
        local dir = (style == "rainbow_lr") and 1 or -1
        local radius = horizDist * 0.5
        local moveX = dir * radius * (1 - math.cos(math.pi * eased))

        local scount = tonumber(stackCount) or 1
        if scount < 1 then scount = 1 end
        local sindex = tonumber(stackIndex) or 1
        local centerOffset = ((scount - 1) * stagger) * 0.5
        local staggerY = ((sindex - 1) * stagger) - centerOffset

        local moveY = maxY * math.sin(math.pi * eased) + staggerY
        SetTextPos(f, anchor, baseX + moveX, moveY)
        f:SetScale(1)
        f:SetAlpha(ClampAlpha(eased < 0.7 and 1 or (1 - (eased - 0.7) / 0.3)))

    elseif style == "flip" then
        local flipWave = math.sin(eased * math.pi)
        local tilt = math.cos(eased * math.pi * 2) * 12 * (1 - eased)
        SetTextPos(f, anchor, baseX + tilt, baseY)
        f:SetScale(1 + flipWave * 0.6)
        f:SetAlpha(ClampAlpha((1 - eased) * (0.85 + 0.15 * math.cos(eased * math.pi * 2))))

    else
        SetTextPos(f, anchor, baseX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))
    end
end

-- Font size for a number. In damage type color mode a crit uses its damage
-- type's size times the Crit Size multiplier.
function CombatTextPlus:GetFontSizeFor(damageType, isCrit)
    local profile = db.profile
    if damageType == "miss" then
        return profile.missFontSize or 20
    elseif damageType == "avoid" then
        return profile.avoidanceFontSize or 22
    end
    local size = profile.damageTypeFontSizes[damageType] or profile.fontSize
    if isCrit and damageType ~= "crit" then
        size = size * (profile.critSizeMultiplier or 2)
    end
    return math.max(6, math.min(96, size))
end

------------------------------------------------------------
-- Overlap prevention
-- Each style positions the frame; afterwards its vertical push (bump) is
-- added on top. When a new number appears, numbers on the same anchor that
-- sit too close above its starting spot are pushed up one line, like a
-- scroll area. Only frame positions are used, never the numbers, so this
-- is safe with secret values.
------------------------------------------------------------
function CombatTextPlus:PlaceFrame(f, progress, stackIndex, stackCount, elapsed)
    local target = f.bumpTarget or 0
    local bump = f.bumpY or 0
    if bump ~= target then
        -- Glide to the new spot instead of jumping.
        local step = math.min(1, (elapsed or 1) * 18)
        bump = bump + (target - bump) * step
        if math.abs(target - bump) < 0.5 then bump = target end
        f.bumpY = bump
    end
    self:ApplyAnimationStyle(f, f.anchor, f.damageType, progress, stackIndex, stackCount)
end

function CombatTextPlus:MakeRoomAbove(newFrame)
    if not db.profile.preventOverlap then return end
    local anchor = newFrame.anchor
    local startY = newFrame.curY or 0
    local newH = newFrame.lineH or 24

    -- Everything else on this anchor at or above the new number's start,
    -- lowest first.
    local others = {}
    for f in pairs(activeTexts) do
        if f ~= newFrame and f.anchor == anchor and f.curY then
            local finalY = f.curY - (f.bumpY or 0) + (f.bumpTarget or 0)
            if finalY >= startY - newH * 0.5 then
                others[#others + 1] = f
            end
        end
    end
    if #others == 0 then return end
    table.sort(others, function(a, b)
        return (a.curY - (a.bumpY or 0) + (a.bumpTarget or 0)) < (b.curY - (b.bumpY or 0) + (b.bumpTarget or 0))
    end)

    local floorY, floorH = startY, newH
    for _, f in ipairs(others) do
        local h = f.lineH or 24
        local need = (floorH + h) * 0.5
        local finalY = f.curY - (f.bumpY or 0) + (f.bumpTarget or 0)
        if finalY < floorY + need then
            local push = (floorY + need) - finalY
            f.bumpTarget = (f.bumpTarget or 0) + push
            finalY = finalY + push
        end
        floorY, floorH = finalY, h
    end
end

------------------------------------------------------------
-- Display
-- amount may be a secret value. If it is, it goes straight into SetText
-- with no formatting, math, or comparison.
------------------------------------------------------------
------------------------------------------------------------
-- Spell icons
--
-- Damage events in Midnight do not say which spell hit, so the icon is
-- confirmed another way: Blizzard's built in damage meter (C_DamageMeter)
-- keeps your damage totals per spell, with real spell IDs, for you and your
-- pet. When a number appears, the addon looks for the spell whose total
-- just went up by that same amount. A match is the real spell. If the meter
-- updates a moment later, the icon is added a split second after the
-- number. A hit that cannot be matched (another player's hit, or an amount
-- Blizzard hides) gets no icon, unless Best Guess is turned on.
--
-- Retail only. Built from Blizzard's API; no code copied from other addons.
------------------------------------------------------------
local meterTotals = {}      -- ["guid:spellID"] = last total seen
local meterPrimed = false   -- first poll only records a starting point
local unclaimed = {}        -- [spellID] = { amount = damage not yet matched to a hit, at = time }
local lastPollAt = 0
local iconCache = {}
local iconTestMode = false
local iconDriver
local lastCast = { id = nil, at = 0, targetGUID = nil }
local meterEvents = {}      -- recent { id = spellID, at = time } each time a spell's total went up

local METER_MAX_AGE = 1.0   -- meter damage older than this can no longer claim a hit
local PENDING_MAX_WAIT = 0.5

local function CanUseMeter()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
        and C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType
        and Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone
        and true or false
end

local function SpellIconFor(spellID)
    if iconCache[spellID] ~= nil then return iconCache[spellID] or nil end
    local icon
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and tex and not IsSecret(tex) then icon = tex end
    end
    if not icon and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info and not IsSecret(info) and info.iconID and not IsSecret(info.iconID) then
            icon = info.iconID
        end
    end
    iconCache[spellID] = icon or false
    return icon
end

local function SpellNameFor(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and name and not IsSecret(name) then return name end
    end
    return tostring(spellID)
end

local function ReadMeterSource(guid, now)
    local ok, src = pcall(C_DamageMeter.GetCombatSessionSourceFromType, 0, Enum.DamageMeterType.DamageDone, guid)
    if not ok or src == nil or IsSecret(src) then return end
    local spells = src.combatSpells
    if type(spells) ~= "table" or IsSecret(spells) then return end
    pcall(function()
        for _, sp in ipairs(spells) do
            local id, total = sp.spellID, sp.totalAmount
            if type(id) == "number" and not IsSecret(id) and total ~= nil and not IsSecret(total) then
                total = tonumber(total)
                if total and total > 0 then
                    local key = guid .. ":" .. id
                    local last = meterTotals[key]
                    local delta
                    if last == nil then
                        delta = meterPrimed and total or 0
                    else
                        delta = total - last
                        if delta < 0 then delta = total end -- the meter started a new session
                    end
                    meterTotals[key] = total
                    if delta > 0 then
                        meterEvents[#meterEvents + 1] = { id = id, at = now }
                        local u = unclaimed[id]
                        if not u or (now - u.at) > METER_MAX_AGE then
                            u = { amount = 0, at = now }
                            unclaimed[id] = u
                        end
                        u.amount = u.amount + delta
                        u.at = now
                    end
                end
            end
        end
    end)
end

local function PollMeter(force)
    if not CanUseMeter() then return end
    local now = GetTime()
    if not force and (now - lastPollAt) < 0.03 then return end
    lastPollAt = now
    local seen = {}
    for _, unit in ipairs({ "player", "pet" }) do
        local guid = UnitGUID(unit)
        if type(guid) == "string" and not IsSecret(guid) and not seen[guid] then
            seen[guid] = true
            ReadMeterSource(guid, now)
        end
    end
    meterPrimed = true
    -- Keep only the last two seconds of meter activity.
    local keep = 1
    for i = 1, #meterEvents do
        if (now - meterEvents[i].at) <= 2 then
            meterEvents[keep] = meterEvents[i]
            keep = keep + 1
        end
    end
    for i = #meterEvents, keep, -1 do meterEvents[i] = nil end
end

-- Hidden amounts cannot be matched by value, so match by timing instead:
-- which of your spells' meter totals went up at the moment this hit
-- landed. Returns spellID, or nil plus a reason.
local TIMING_BEFORE = 0.20  -- meter activity this long before the hit still counts
local TIMING_SETTLE = 0.12  -- wait this long after the hit for the meter to catch up
local TIMING_GAP = 0.06     -- the closest spell must beat the next one by this much

local function MatchByTiming(hitAt, now)
    local best, bestDist, second, secondDist
    local seenSpell = {}
    for i = 1, #meterEvents do
        local e = meterEvents[i]
        if e.at >= hitAt - TIMING_BEFORE and e.at <= now then
            local dist = math.abs(e.at - hitAt)
            local prev = seenSpell[e.id]
            if not prev or dist < prev then seenSpell[e.id] = dist end
        end
    end
    for id, dist in pairs(seenSpell) do
        if not bestDist or dist < bestDist then
            second, secondDist = best, bestDist
            best, bestDist = id, dist
        elseif not secondDist or dist < secondDist then
            second, secondDist = id, dist
        end
    end
    if not best then return nil, "no meter activity: likely not your hit" end
    if second and (secondDist - bestDist) < TIMING_GAP then
        return nil, ("too close to call: %s or %s"):format(tostring(best), tostring(second))
    end
    return best
end

-- Finds the spell whose fresh meter damage matches this hit, and marks that
-- damage as used so the next hit cannot claim it twice.
local function ClaimFromMeter(amount)
    if amount == nil or IsSecret(amount) or type(amount) ~= "number" or amount <= 0 then return nil end
    local now = GetTime()
    local tol = math.max(1, amount * 0.005)

    -- 1. One hit, one spell: the meter went up by exactly this amount.
    local match
    for id, u in pairs(unclaimed) do
        if (now - u.at) <= METER_MAX_AGE and math.abs(u.amount - amount) <= tol then
            match = id
            break
        end
    end

    -- 2. Several hits from one spell landed together (AoE, multi hit).
    -- Only trusted when exactly one spell has enough fresh damage to cover it.
    if not match then
        local count
        count, match = 0, nil
        for id, u in pairs(unclaimed) do
            if (now - u.at) <= 0.5 and u.amount + tol >= amount then
                count = count + 1
                match = id
            end
        end
        if count ~= 1 then match = nil end
    end

    if match then
        local u = unclaimed[match]
        u.amount = u.amount - amount
        if u.amount <= tol then unclaimed[match] = nil end
    end
    return match
end

-- Best Guess (optional): the hit landed right after your cast, on the
-- enemy you cast at.
local function GuessFromLastCast(unit)
    -- While you channel (Rapid Fire, Drain Soul), every tick belongs to the
    -- channel, however long after it started.
    if UnitChannelInfo then
        local ok, name, _, _, _, _, _, _, channelID = pcall(UnitChannelInfo, "player")
        if ok and name and channelID and not IsSecret(channelID) and type(channelID) == "number" then
            if unit and lastCast.targetGUID then
                local g = UnitGUID(unit)
                if g ~= nil and not IsSecret(g) and g == lastCast.targetGUID then
                    return channelID
                end
            else
                return channelID
            end
        end
    end
    if not lastCast.id then return nil end
    if (GetTime() - lastCast.at) > 0.6 then return nil end
    if unit and lastCast.targetGUID then
        local g = UnitGUID(unit)
        if g == nil or IsSecret(g) or g ~= lastCast.targetGUID then return nil end
    end
    return lastCast.id
end

-- True when the spell is one you actually know (or replaces one you know).
-- Hidden helper spells that Blizzard triggers behind the scenes are not
-- known spells, so this keeps them from replacing your real cast.
local function IsKnownPlayerSpell(spellID)
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known == true then return true end
    end
    if FindBaseSpellByID and IsPlayerSpell then
        local ok, base = pcall(FindBaseSpellByID, spellID)
        if ok and base and not IsSecret(base) and base ~= spellID then
            local ok2, known = pcall(IsPlayerSpell, base)
            if ok2 and known == true then return true end
        end
    end
    if not IsPlayerSpell then return true end -- older clients: cannot check, allow
    return false
end

local function IsAutoRepeat(spellID)
    if spellID == AUTO_SHOT_ID or spellID == AUTO_ATTACK_ID then return true end
    if C_Spell and C_Spell.IsAutoRepeatSpell then
        local ok, auto = pcall(C_Spell.IsAutoRepeatSpell, spellID)
        if ok and auto == true then return true end
    end
    return false
end

local function RecordCast(spellID)
    if spellID == nil or IsSecret(spellID) or type(spellID) ~= "number" then return end
    local why
    -- Auto Shot, Auto Attack, and anything that replaces them (like Bleak
    -- Arrows) fire a cast event on every shot. Recording them would keep
    -- replacing your real ability.
    if IsAutoRepeat(spellID) then
        why = "auto shot or auto attack"
    elseif not IsKnownPlayerSpell(spellID) then
        why = "hidden helper spell, not in your spellbook"
    else
        local check = C_Spell and C_Spell.IsSpellHarmful
        if check then
            local ok, harmful = pcall(check, spellID)
            if ok and harmful ~= nil and not IsSecret(harmful) and not harmful then
                why = "not an attack"
            end
        end
    end
    if iconTestMode then
        CombatTextPlus:Print(("icontest | cast: %s (%d) %s"):format(SpellNameFor(spellID), spellID,
            why and ("|cffff5555ignored: " .. why .. "|r") or "|cff55ff55recorded|r"))
    end
    if why then return end
    local g = UnitGUID("target")
    lastCast.id, lastCast.at = spellID, GetTime()
    lastCast.targetGUID = (g ~= nil and not IsSecret(g)) and g or nil
end

-- Positions the number, label, and icon. A hidden (secret) number's width
-- cannot be used, so for those the number and icon meet at the frame's
-- center instead of being placed against the number's edges.
local function LayoutTextPieces(f)
    local iconShown = f.icon:IsShown()
    local iconPos = db.profile.spellIconPosition or "left"
    f.text:ClearAllPoints()
    f.label:ClearAllPoints()
    f.icon:ClearAllPoints()

    if not f.amountSecret then
        f.text:SetPoint("CENTER", f, "CENTER")
        f.label:SetPoint("LEFT", f.text, "RIGHT", 5, 0)
        if iconShown then
            if iconPos == "left" then
                f.icon:SetPoint("RIGHT", f.text, "LEFT", -4, 0)
            elseif f.label:IsShown() then
                f.icon:SetPoint("LEFT", f.label, "RIGHT", 4, 0)
            else
                f.icon:SetPoint("LEFT", f.text, "RIGHT", 4, 0)
            end
        end
        return
    end

    if not iconShown then
        f.text:SetPoint("CENTER", f, "CENTER")
    elseif iconPos == "left" then
        f.icon:SetPoint("RIGHT", f, "CENTER", -2, 0)
        f.text:SetPoint("LEFT", f, "CENTER", 2, 0)
    else
        f.text:SetPoint("RIGHT", f, "CENTER", -2, 0)
        f.icon:SetPoint("LEFT", f, "CENTER", 3, 0)
    end
end

local function ApplySpellIcon(f, spellID)
    local icon = spellID and SpellIconFor(spellID)
    if not icon then return false end
    local size = (f.fontSize or 24) * (db.profile.spellIconSize or 1)
    f.icon:SetTexture(icon)
    f.icon:SetSize(size, size)
    f.icon:Show()
    f.spellIconID = spellID
    LayoutTextPieces(f)
    return true
end

local function IconTestPrint(f, result)
    if not iconTestMode then return end
    local amountText = f.amountSecret and "[hidden]" or tostring(f.amountValue)
    CombatTextPlus:Print(("icontest | %s %s -> %s"):format(tostring(f.damageType), amountText, result))
end

local function StopIconDriver()
    if iconDriver then iconDriver:SetScript("OnUpdate", nil) end
end

local function IconDriverUpdate()
    PollMeter(false)
    local now = GetTime()
    local any = false
    for f, p in pairs(pendingIcons) do
        if f.released then
            pendingIcons[f] = nil
        elseif p.byTiming then
            if (now - p.at) >= TIMING_SETTLE then
                pendingIcons[f] = nil
                local id, why = MatchByTiming(p.at, now)
                if id and ApplySpellIcon(f, id) then
                    IconTestPrint(f, SpellNameFor(id) .. " (meter timing)")
                else
                    local guess = db.profile.spellIconGuess and GuessFromLastCast(p.unit)
                    if guess and ApplySpellIcon(f, guess) then
                        IconTestPrint(f, SpellNameFor(guess) .. " (best guess)")
                    else
                        IconTestPrint(f, "no icon (" .. tostring(why) .. ")")
                    end
                end
            else
                any = true
            end
        else
            local id = ClaimFromMeter(p.amount)
            if id and ApplySpellIcon(f, id) then
                pendingIcons[f] = nil
                IconTestPrint(f, ("%s (meter, %.2fs later)"):format(SpellNameFor(id), now - p.at))
            elseif (now - p.at) > PENDING_MAX_WAIT then
                pendingIcons[f] = nil
                local guess = db.profile.spellIconGuess and GuessFromLastCast(p.unit)
                if guess and ApplySpellIcon(f, guess) then
                    IconTestPrint(f, SpellNameFor(guess) .. " (best guess)")
                else
                    IconTestPrint(f, "no icon (no meter match: likely not your hit)")
                end
            else
                any = true
            end
        end
    end
    if not any then StopIconDriver() end
end

local function StartIconDriver()
    if not iconDriver then iconDriver = CreateFrame("Frame") end
    iconDriver:SetScript("OnUpdate", IconDriverUpdate)
end

-- /ctp metertest: prints exactly what Blizzard's damage meter returns, so
-- we can see whether it is readable and which way of asking works.
local function MeterShow(v)
    if v == nil then return "nil" end
    if IsSecret(v) then return "[secret]" end
    return tostring(v)
end

local function RunMeterTest()
    local P = function(msg) CombatTextPlus:Print(msg) end
    P("|cffffd100METER TEST|r")
    if not C_DamageMeter then
        P("  C_DamageMeter does not exist on this client.")
        return
    end

    local names = {}
    for k, v in pairs(C_DamageMeter) do
        if type(v) == "function" then names[#names + 1] = k end
    end
    table.sort(names)
    P("  Functions: " .. table.concat(names, ", "))

    for _, enumName in ipairs({ "DamageMeterType", "DamageMeterSessionType" }) do
        local e = Enum and Enum[enumName]
        if e then
            local parts = {}
            for k, v in pairs(e) do parts[#parts + 1] = k .. "=" .. tostring(v) end
            table.sort(parts)
            P(("  Enum.%s: %s"):format(enumName, table.concat(parts, ", ")))
        else
            P(("  Enum.%s: missing"):format(enumName))
        end
    end

    for _, cvar in ipairs({ "damageMeterEnabled", "damageMeter", "enableDamageMeter", "showDamageMeter" }) do
        if C_CVar and C_CVar.GetCVar then
            local ok, v = pcall(C_CVar.GetCVar, cvar)
            if ok and v ~= nil then P(("  CVar %s = %s"):format(cvar, MeterShow(v))) end
        end
    end

    local guid = UnitGUID("player")
    P("  Player GUID: " .. (IsSecret(guid) and "[secret]" or (guid and "readable" or "nil")))
    if not (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or not C_DamageMeter.GetCombatSessionSourceFromType then
        P("  GetCombatSessionSourceFromType or DamageDone type missing.")
        return
    end

    for session = 0, 2 do
        local ok, src = pcall(C_DamageMeter.GetCombatSessionSourceFromType, session, Enum.DamageMeterType.DamageDone, guid)
        if not ok then
            P(("  session %d: ERROR %s"):format(session, MeterShow(src)))
        elseif src == nil then
            P(("  session %d: returned nil"):format(session))
        elseif IsSecret(src) then
            P(("  session %d: whole result [secret]"):format(session))
        else
            local keys = {}
            pcall(function()
                for k, v in pairs(src) do keys[#keys + 1] = k .. "(" .. type(v) .. ")" end
            end)
            table.sort(keys)
            P(("  session %d fields: %s"):format(session, table.concat(keys, ", ")))
            local spells = src.combatSpells
            if type(spells) ~= "table" then
                P(("  session %d combatSpells: %s"):format(session, MeterShow(spells)))
            else
                local count = 0
                pcall(function()
                    for i, sp in ipairs(spells) do
                        count = i
                        if i <= 5 then
                            local id = sp.spellID
                            local nm = (type(id) == "number" and not IsSecret(id)) and SpellNameFor(id) or MeterShow(id)
                            P(("    #%d spell %s (%s) total %s"):format(i, MeterShow(id), nm, MeterShow(sp.totalAmount)))
                        end
                    end
                end)
                P(("  session %d: %d spells"):format(session, count))
            end
        end
    end
end

-- Called for every damage number as it appears.
function CombatTextPlus:ResolveSpellIcon(f, amount, unit)
    f.icon:Hide()
    if not db.profile.showSpellIcons then return end
    local t = f.damageType
    if t == "heal" or t == "miss" or t == "avoid" then return end

    if unit == "preview" then
        ApplySpellIcon(f, AUTO_ATTACK_ID or 6603)
        return
    end

    if CanUseMeter() and not f.amountSecret then
        PollMeter(true)
        local id = ClaimFromMeter(amount)
        if id and ApplySpellIcon(f, id) then
            IconTestPrint(f, SpellNameFor(id) .. " (meter)")
            return
        end
        pendingIcons[f] = { amount = amount, at = GetTime(), unit = unit }
        StartIconDriver()
        return
    end

    if CanUseMeter() and f.amountSecret then
        -- Hidden amount: match by when the meter moved instead.
        PollMeter(true)
        pendingIcons[f] = { at = GetTime(), unit = unit, byTiming = true }
        StartIconDriver()
        return
    end

    local guess = db.profile.spellIconGuess and GuessFromLastCast(unit)
    if guess and ApplySpellIcon(f, guess) then
        IconTestPrint(f, SpellNameFor(guess) .. " (best guess)")
    else
        IconTestPrint(f, f.amountSecret and "no icon (amount hidden by Blizzard)" or "no icon (damage meter not available)")
    end
end

function CombatTextPlus:DisplayCombatText(anchor, amount, damageType, isCrit, unit)
    if not anchor then return end
    if anchor.IsForbidden and anchor:IsForbidden() then return end

    local secret = IsSecret(amount)
    local shownText
    if not secret then
        shownText = self:FormatNumber(amount)
        if not shownText then return end
    end

    if anchor == centerAnchor then
        MakeRoomOn(centerAnchor, db.profile.centerMaxNumbers or 6)
    elseif anchor == avoidAnchor then
        MakeRoomOn(avoidAnchor, db.profile.avoidanceMaxNumbers or 4)
    elseif (db.profile.maxPerPlate or 0) > 0 then
        MakeRoomOn(anchor, db.profile.maxPerPlate)
    end

    local f = AcquireTextFrame(anchor)
    f.damageType = damageType
    f.isCrit = isCrit or damageType == "crit"
    f.startTime = GetTime()
    arcSide = -arcSide
    f.arcDir = arcSide

    stacks[anchor] = stacks[anchor] or {}
    stacks[anchor][damageType] = stacks[anchor][damageType] or {}
    local list = stacks[anchor][damageType]
    list[#list + 1] = f

    local fontPath = LSM:Fetch("font", db.profile.font)
    local fontSize = self:GetFontSizeFor(damageType, f.isCrit)
    f.text:SetFont(fontPath, fontSize, "OUTLINE")
    f.label:SetFont(fontPath, db.profile.labelFontSize, "OUTLINE")

    local dR, dG, dB
    if damageType == "restricted" then
        local c = db.profile.restrictedColor
        dR, dG, dB = c.r, c.g, c.b
    elseif damageType == "miss" then
        local c = db.profile.missColor
        dR, dG, dB = c.r, c.g, c.b
    elseif damageType == "avoid" then
        local c = db.profile.avoidanceColor
        dR, dG, dB = c.r, c.g, c.b
    else
        dR, dG, dB = self:GetDamageTypeColor(damageType)
    end

    f.amountSecret = secret
    f.amountValue = (not secret) and amount or nil
    f.fontSize = fontSize

    -- Labels anchor to the number's width, so they are skipped for secret numbers.
    local labelText = self:GetDamageTypeLabel(damageType)
    if f.isCrit and damageType ~= "crit" and db.profile.critLabel then
        labelText = (labelText ~= "") and (labelText .. " Crit") or "Crit"
    end
    if db.profile.showLabels and not secret and labelText ~= "" then
        local lR, lG, lB = self:GetLabelColor(damageType)
        f.label:SetTextColor(lR, lG, lB)
        f.label:SetText(labelText)
        f.label:Show()
    else
        f.label:Hide()
    end

    self:ResolveSpellIcon(f, amount, unit)
    LayoutTextPieces(f)

    f.text:SetTextColor(dR, dG, dB)
    if secret then
        f.text:SetText(amount)
    else
        f.text:SetText(shownText)
    end

    f.bumpY, f.bumpTarget = 0, 0
    f.lineH = fontSize * (db.profile.lineSpacing or 1.1)
    self:PlaceFrame(f, 0, #list, #list, 0)
    self:MakeRoomAbove(f)
    f:Show()

    local startTime = GetTime()
    f:SetScript("OnUpdate", function(selfFrame, elapsed)
        local profile = db.profile
        local duration = math.max(0.001, profile.scrollDuration or 0.5)
        local speed = math.max(0.0001, profile.speedFactor or 1)
        local progress = (GetTime() - startTime) / (duration / speed)

        if progress >= 1 then
            ReleaseTextFrame(selfFrame)
            return
        end

        local stackList = stacks[selfFrame.anchor] and stacks[selfFrame.anchor][selfFrame.damageType]
        local stackIndex, stackCount = 1, stackList and #stackList or 1
        if stackList then
            for i = 1, #stackList do
                if stackList[i] == selfFrame then
                    stackIndex = i
                    break
                end
            end
        end
        CombatTextPlus:PlaceFrame(selfFrame, progress, stackIndex, stackCount, elapsed)
    end)
end

-- UNIT_COMBAT has no source, so we cannot tell whose hit it was. What we can
-- tell is whether you are fighting that enemy at all. First check: did you
-- target it and attack it (engaged)? Second check, for AoE and cleave on
-- mobs you never targeted: are you in combat and on its threat table?
-- This drops other players' hits on mobs you never touched, like a dummy
-- someone else is attacking.
function CombatTextPlus:IsFightingUnit(unit, plate)
    if IsPlateEngaged(plate) then
        return true
    end

    -- Your DoTs keep an enemy yours. In strict mode the enemy must also have
    -- been your attacked target at some point this fight, so a debuff that
    -- spread by AoE onto a neighbor does not pull in other players' hits.
    if PlayerHasDebuffOn(unit) then
        if not db.profile.strictEngage or (plate and engagedPlates[plate]) then
            if plate then engagedPlates[plate] = GetTime() end
            return true
        end
    end

    -- Strict mode: only enemies you targeted and attacked. Skips the threat
    -- fallback below, which lets AoE on neighboring mobs or dummies count
    -- and brings in other players' hits on them.
    if db.profile.strictEngage then
        return false
    end

    -- Players have no threat table, and in battlegrounds and arenas threat
    -- is useless or hidden. Only enemies you actually attacked count there.
    if IsInPvPInstance() then
        return false
    end
    local isPlayer = UnitIsPlayer(unit)
    if IsSecret(isPlayer) or isPlayer then
        return false
    end

    local inCombat = UnitAffectingCombat("player")
    if not IsSecret(inCombat) and not inCombat then
        return false
    end

    local threat = UnitThreatSituation("player", unit)
    if IsSecret(threat) then
        -- Threat is hidden here, so being in combat is the best check left.
        return true
    end
    return threat ~= nil
end

-- Same idea as IsFightingUnit, for your current target in the center
-- display. Works whether or not the target has a nameplate.
function CombatTextPlus:IsFightingTarget()
    local now = GetTime()
    local timeout = db.profile.engageTimeout or 6
    if targetEngagedAt > 0 and (timeout <= 0 or (now - targetEngagedAt) <= timeout) then
        return true
    end
    if targetEngagedAt > 0 and PlayerHasDebuffOn("target") then
        targetEngagedAt = now
        return true
    end
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if plate and plate.IsForbidden and plate:IsForbidden() then plate = nil end
    return self:IsFightingUnit("target", plate)
end

-- Decides whether a heal on a friendly nameplate should show. Same source
-- problem as damage: the event never says who cast the heal.
function CombatTextPlus:IsHealAllowed(unit, plate)
    local scope = db.profile.healScope or "auto"

    -- Auto: healer specs see their group, everyone else only their own heals
    if scope == "auto" then
        scope = IsHealerSpec() and "group" or "mine"
    end

    if scope == "off" then
        return false
    elseif scope == "all" then
        return true
    elseif scope == "target" then
        return plate == C_NamePlate.GetNamePlateForUnit("target")
    end

    -- "mine" and "group" both include friendlies you healed recently
    if IsPlateHealed(plate) then
        return true
    end

    if scope == "group" then
        local inParty = UnitInParty(unit)
        if not IsSecret(inParty) and inParty then return true end
        local inRaid = UnitInRaid(unit)
        if not IsSecret(inRaid) and inRaid then return true end
    end

    return false
end

function CombatTextPlus:GetDamageType(school)
    return SCHOOL_TO_TYPE[school] or "physical"
end

function CombatTextPlus:GetDamageTypeColor(damageType)
    local color = db.profile.damageTypeColors[damageType]
    if not color then return 1, 1, 1 end
    return color.r, color.g, color.b
end

function CombatTextPlus:GetLabelColor(damageType)
    local color = db.profile.labelColors[damageType]
    if not color then return 1, 1, 1 end
    return color.r, color.g, color.b
end

-- Restores the standard color preset for every number and label without
-- touching any other setting (fonts, positions, speed, filters).
function CombatTextPlus:ApplyColorPreset()
    local profile = db.profile
    for _, t in ipairs(DAMAGE_TYPES) do
        local preset = PRESET_COLORS[t]
        if preset then
            local c = profile.damageTypeColors[t]
            c.r, c.g, c.b = preset.r, preset.g, preset.b
            local l = profile.labelColors[t]
            l.r, l.g, l.b = preset.r, preset.g, preset.b
        end
    end
    local rc = profile.restrictedColor
    rc.r, rc.g, rc.b = PRESET_RESTRICTED_COLOR.r, PRESET_RESTRICTED_COLOR.g, PRESET_RESTRICTED_COLOR.b

    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry then
        registry:NotifyChange("CombatTextPlus")
    end
    self:Print("Default color preset applied.")
end

function CombatTextPlus:GetDamageTypeLabel(damageType)
    return TYPE_LABELS[damageType] or ""
end

function CombatTextPlus:FormatNumber(amount)
    if amount == nil or amount == "" then return nil end
    local n = tonumber(amount)
    if not n then return tostring(amount) end
    local formatted = tostring(math.floor(n + 0.5))
    local k
    repeat
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
    until k == 0
    return formatted
end

-- Turns a damage event into a display type. Returns nil when the type is
-- switched off in Damage Type Filters.
-- Returns the text to show for a miss action, or nil if it should not show.
-- A secret action can never be read, so it is never treated as a miss.
function CombatTextPlus:GetMissText(action, enabledTypes)
    if action == nil or IsSecret(action) then return nil end
    local text = MISS_TEXT[action]
    if not text then return nil end
    if enabledTypes and not enabledTypes[action] then return nil end
    return text
end

-- Third return is true when the hit is shown as a crit.
--
-- Crit handling:
--   Crit treatment off (the Critical Hits toggle): crits show as normal hits.
--   Crit Color mode: crits use the Crit type (its color, size, offset).
--   Damage Type Color mode: crits keep their school type (a Fire crit is
--   orange, follows the Fire filter and offset) and are drawn larger.
function CombatTextPlus:ClassifyDamage(flagText, schoolMask)
    local schoolType
    if not IsSecret(schoolMask) and type(schoolMask) == "number" then
        schoolType = self:GetDamageType(schoolMask)
    else
        schoolType = "restricted"
    end

    local isCrit = (not IsSecret(flagText)) and flagText == "CRITICAL"
        and db.profile.damageTypeFilters.crit and true or false

    if isCrit and db.profile.critColorMode ~= "school" then
        return "crit", nil, true
    end

    if schoolType ~= "restricted" and not db.profile.damageTypeFilters[schoolType] then
        return nil, schoolType
    end
    return schoolType, nil, isCrit
end

------------------------------------------------------------
-- Center screen display handler
-- Uses the UNIT_COMBAT events the game sends for your target. Damage only,
-- and only on an enemy target. Like the nameplate display it cannot tell
-- whose hit it was, so in a group it shows everyone's damage on your target.
------------------------------------------------------------
function CombatTextPlus:HandleCenterTarget(action, flagText, amount, schoolMask)
    if not UnitExists("target") then return end

    local canAttack = UnitCanAttack("player", "target")
    if IsSecret(canAttack) or not canAttack then return end

    local missText
    if not IsSecret(action) and action ~= "WOUND" then
        if not db.profile.showMisses then return end
        missText = self:GetMissText(action, db.profile.missTypes)
        if not missText then return end
    elseif not IsSecret(amount) then
        if type(amount) ~= "number" or amount <= 0 then return end
    end

    if db.profile.onlyMyFights and not self:IsFightingTarget() then
        if debugMode then
            self:Print("center | HIDDEN by Only Enemies I'm Fighting")
        end
        return
    end

    if missText then
        if debugMode then
            self:Print(("center | SHOWN as miss (%s)"):format(missText))
        end
        PositionCenterAnchor()
        self:DisplayCombatText(GetCenterAnchor(), missText, "miss")
        return
    end

    local damageType, filtered, isCrit = self:ClassifyDamage(flagText, schoolMask)
    if not damageType then
        if debugMode then
            self:Print(("center | HIDDEN by Damage Type Filters (%s is off)"):format(filtered))
        end
        return
    end

    if debugMode then
        self:Print(("center | SHOWN as %s%s"):format(damageType, isCrit and " (crit)" or ""))
    end
    PositionCenterAnchor()
    self:DisplayCombatText(GetCenterAnchor(), amount, damageType, isCrit, "target")
end

function CombatTextPlus:HandleSelfAvoidance(action)
    if not db.profile.showMyAvoidance then return end
    local text = self:GetMissText(action, db.profile.missTypes)
    if not text then return end
    if debugMode then
        self:Print(("player | avoidance SHOWN (%s)"):format(text))
    end
    PositionAvoidAnchor()
    self:DisplayCombatText(GetAvoidAnchor(), text, "avoid")
end

------------------------------------------------------------
-- UNIT_COMBAT handler
-- Args: unit, action, flagText, amount, schoolMask
------------------------------------------------------------
function CombatTextPlus:HandleUnitCombat(unit, action, flagText, amount, schoolMask)
    if not db.profile.enabled then return end
    if IsSecret(unit) or type(unit) ~= "string" then return end

    -- Debug only: UNIT_COMBAT also fires for your target. If a heal shows up
    -- here with no nameplate event after it, the unit simply has no nameplate.
    -- In target mode this line only prints when the nameplate is missing or
    -- locked, since the nameplate line below already covers the normal case.
    if debugMode and unit == "target" then
        local plate = C_NamePlate.GetNamePlateForUnit("target")
        local plateState, plateOk
        if not plate then
            plateState = "NONE. This unit has no nameplate, so nothing can show on it. For friendly NPCs like the healing dummy, turn on Friendly NPC Nameplates in /ctp."
        elseif plate.IsForbidden and plate:IsForbidden() then
            plateState = "locked by Blizzard (instance)"
        else
            plateState = "ok"
            plateOk = true
        end
        if debugMode == "all" or not plateOk then
            self:Print(("target | action: %s | target nameplate: %s"):format(
                IsSecret(action) and "[secret]" or tostring(action), plateState))
        end
    end

    if unit == "player" then
        self:HandleSelfAvoidance(action)
        return
    end

    local mode = db.profile.displayMode or "nameplates"
    if unit == "target" then
        if mode ~= "nameplates" then
            self:HandleCenterTarget(action, flagText, amount, schoolMask)
        end
        return
    end
    if mode == "center" then return end

    if not unit:find("^nameplate%d") then return end

    local plate = plateByUnit[unit]
    if not plate then
        if DebugWants(unit) then
            self:Print(unit .. " | skipped: no usable nameplate. Blizzard locks friendly nameplates inside dungeons, raids, and battlegrounds, so heals cannot show there.")
        end
        return
    end

    -- Hostile or friendly decides what is allowed on this plate.
    -- Damage only on enemies, heals only on friendlies. No guessing.
    local canAttack = UnitCanAttack("player", unit)
    local hostileKnown = not IsSecret(canAttack)
    local isHostile = hostileKnown and canAttack and true or false

    if DebugWants(unit) then
        local function Show(v)
            if IsSecret(v) then return "[secret]" end
            return tostring(v)
        end
        self:Print(("%s | hostile: %s | action: %s | flag: %s | amount: %s | school: %s"):format(
            unit, hostileKnown and tostring(isHostile) or "[secret]",
            Show(action), Show(flagText), IsSecret(amount) and "[secret]" or tostring(amount), Show(schoolMask)))
    end

    if not hostileKnown then return end

    if db.profile.unitEventScope == "target"
        or (db.profile.pvpTargetOnly and IsInPvPInstance()) then
        if plate ~= C_NamePlate.GetNamePlateForUnit("target") then return end
    end

    local isHeal, missText
    if isHostile then
        -- Enemy plate: damage, plus misses when Show Misses is on.
        if not IsSecret(action) and action ~= "WOUND" then
            if not db.profile.showMisses then return end
            missText = self:GetMissText(action, db.profile.missTypes)
            if not missText then return end
        end
        isHeal = false
    else
        -- Friendly plate: heals only. If Blizzard hides the action, we cannot
        -- tell a heal from damage, so nothing is shown rather than a wrong number.
        if IsSecret(action) or action ~= "HEAL" then return end
        isHeal = true
    end

    if not missText and not IsSecret(amount) then
        if type(amount) ~= "number" or amount <= 0 then return end
    end

    if not isHeal and db.profile.onlyMyFights then
        local stamp = engagedPlates[plate]
        if not self:IsFightingUnit(unit, plate) then
            if DebugWants(unit) then
                local function Show(v)
                    if IsSecret(v) then return "[secret]" end
                    return tostring(v)
                end
                local engaged = stamp and ("%.1fs ago (timeout %ds)"):format(GetTime() - stamp, db.profile.engageTimeout or 6) or "never"
                self:Print(("%s | HIDDEN by Only Enemies I'm Fighting | last attack: %s | your debuff on it: %s | strict: %s | in combat: %s | threat: %s"):format(
                    unit, engaged, PlayerHasDebuffOn(unit) and "yes" or "no", tostring(db.profile.strictEngage),
                    Show(UnitAffectingCombat("player")), Show(UnitThreatSituation("player", unit))))
            end
            return
        end
    end

    if missText then
        if DebugWants(unit) then
            self:Print(("%s | SHOWN as miss (%s)"):format(unit, missText))
        end
        self:DisplayCombatText(plate, missText, "miss")
        return
    end

    if isHeal and not self:IsHealAllowed(unit, plate) then
        if DebugWants(unit) then
            local scope = db.profile.healScope or "auto"
            if scope == "auto" then
                scope = "auto (" .. (IsHealerSpec() and "group" or "mine") .. ")"
            end
            self:Print(unit .. " | heal filtered by Show Healing On: " .. scope)
        end
        return
    end

    local damageType, isCrit
    if isHeal then
        if not db.profile.damageTypeFilters.heal then return end
        damageType = "heal"
    else
        local filtered
        damageType, filtered, isCrit = self:ClassifyDamage(flagText, schoolMask)
        if not damageType then
            if DebugWants(unit) then
                self:Print(("%s | HIDDEN by Damage Type Filters (%s is off)"):format(unit, filtered))
            end
            return
        end
    end

    if DebugWants(unit) then
        self:Print(("%s | SHOWN as %s%s"):format(unit, damageType, isCrit and " (crit)" or ""))
    end
    self:DisplayCombatText(plate, amount, damageType, isCrit, unit)
end

------------------------------------------------------------
-- Settings
------------------------------------------------------------
function CombatTextPlus:ApplySettings()
    local fontPath = LSM:Fetch("font", db.profile.font or "Friz Quadrata TT")

    if icon then
        if db.profile.minimap and db.profile.minimap.hide then
            pcall(icon.Hide, icon, "CombatTextPlus")
        else
            pcall(icon.Show, icon, "CombatTextPlus")
        end
    end

    for f in pairs(activeTexts) do
        local fontSize = self:GetFontSizeFor(f.damageType, f.isCrit)
        f.text:SetFont(fontPath, fontSize, "OUTLINE")
        f.label:SetFont(fontPath, db.profile.labelFontSize, "OUTLINE")
        if not db.profile.showLabels then
            f.label:Hide()
        end
    end

    self:ToggleEnabled(db.profile.enabled)
    DisableBlizzardCombatText()
end

function CombatTextPlus:ToggleEnabled(value)
    if not value then
        ReleaseAll()
    end
end

function CombatTextPlus:RefreshFonts(onlyType)
    local fontPath = LSM:Fetch("font", db.profile.font)
    for f in pairs(activeTexts) do
        if not onlyType or f.damageType == onlyType then
            local fontSize = self:GetFontSizeFor(f.damageType, f.isCrit)
            f.text:SetFont(fontPath, fontSize, "OUTLINE")
            f.label:SetFont(fontPath, db.profile.labelFontSize, "OUTLINE")
        end
    end
end

function CombatTextPlus:SlashCommand(input)
    input = strtrim(input or ""):lower()
    if input == "status" then
        local tracked = 0
        for _ in pairs(plateByUnit) do tracked = tracked + 1 end
        self:Print(("Enabled: %s | Restricted content: %s | Nameplates tracked: %d | Secret API present: %s"):format(
            tostring(db.profile.enabled), tostring(IsRestrictedContext()), tracked, tostring(issecretvalue ~= nil)))
    elseif input == "preview" then
        self:ShowPreviewCombatText()
    elseif input == "colors" then
        self:ApplyColorPreset()
    elseif input == "metertest" then
        RunMeterTest()
    elseif input == "icontest" then
        iconTestMode = not iconTestMode
        if iconTestMode then
            PollMeter(true)
            local count = 0
            for _ in pairs(meterTotals) do count = count + 1 end
            self:Print(("Spell icon test ON. Damage meter: %s, spells with readable totals: %d (0 is normal before your first fight). Each damage number prints which spell it was matched to. Type /ctp icontest again to stop."):format(
                CanUseMeter() and "available" or "NOT AVAILABLE", count))
        else
            self:Print("Spell icon test OFF.")
        end
    elseif input == "debug" then
        if debugMode then
            debugMode = false
            self:Print("Debug OFF.")
        else
            debugMode = "target"
            self:Print("Debug ON (current target only). Combat events on your target's nameplate will print to chat. Type /ctp debug again to stop, or /ctp debug all to see every nameplate.")
        end
    elseif input == "debug all" then
        if debugMode == "all" then
            debugMode = false
            self:Print("Debug OFF.")
        else
            debugMode = "all"
            self:Print("Debug ON (all nameplates). Every nameplate combat event will print to chat. Type /ctp debug again to stop.")
        end
    else
        OpenOptions()
    end
end

------------------------------------------------------------
-- Options
------------------------------------------------------------
local function TypeNames(t)
    if t == "heal" then
        return "Healing", "Healing Color", "Healing Font Size", "Heal Label Color", "Heal Offset", "Healing"
    elseif t == "crit" then
        return "Critical Hits", "Crit Damage Color", "Crit Damage Font Size", "Crit Label Color", "Crit Offset", "Critical hits"
    end
    local L = TYPE_LABELS[t]
    return L .. " Damage", L .. " Damage Color", L .. " Damage Font Size", L .. " Label Color", L .. " Offset", L .. " damage"
end

local function BuildOptions()
    local offsetArgs, filterArgs, colorArgs, labelColorArgs, fontSizeArgs = {}, {}, {}, {}, {}

    for i, t in ipairs(DAMAGE_TYPES) do
        local filterName, colorName, fontName, labelColorName, offsetName, noun = TypeNames(t)

        if t ~= "crit" then
            offsetArgs[t] = {
                name = offsetName, type = "range", min = -50, max = 50, step = 1, order = i,
                desc = "Adjust the horizontal movement of the combat text for " .. noun .. ".",
                get = function() return db.profile.damageTypeOffsets[t] end,
                set = function(_, value) db.profile.damageTypeOffsets[t] = value end,
            }
        end

        filterArgs[t] = {
            name = filterName, type = "toggle", order = i,
            desc = (t == "crit")
                and "Give critical hits special treatment (see the Crits section). Turn off to show crits as normal hits."
                or ("Enable or disable the display of " .. noun .. "."),
            get = function() return db.profile.damageTypeFilters[t] end,
            set = function(_, value) db.profile.damageTypeFilters[t] = value end,
        }

        colorArgs[t .. "Color"] = {
            name = colorName, type = "color", order = i,
            desc = "Set the color for " .. noun .. ".",
            get = function() local c = db.profile.damageTypeColors[t]; return c.r, c.g, c.b end,
            set = function(_, r, g, b) local c = db.profile.damageTypeColors[t]; c.r, c.g, c.b = r, g, b end,
        }

        labelColorArgs[t .. "LabelColor"] = {
            name = labelColorName, type = "color", order = i,
            desc = "Set the color of the '" .. TYPE_LABELS[t] .. "' label.",
            get = function() local c = db.profile.labelColors[t]; return c.r, c.g, c.b end,
            set = function(_, r, g, b) local c = db.profile.labelColors[t]; c.r, c.g, c.b = r, g, b end,
        }

        fontSizeArgs[t .. "FontSize"] = {
            name = fontName, type = "range", min = 6, max = 36, step = 1, order = i,
            desc = "Set the font size for " .. noun .. ".",
            get = function() return db.profile.damageTypeFontSizes[t] end,
            set = function(_, value)
                db.profile.damageTypeFontSizes[t] = value
                CombatTextPlus:RefreshFonts(t)
            end,
        }
    end

    return {
        name = "CombatTextPlus",
        type = "group",
        args = {
            enabled = {
                name = "Enabled",
                type = "toggle",
                desc = "Enable or disable the combat text.",
                get = function() return db.profile.enabled end,
                set = function(_, value)
                    db.profile.enabled = value
                    CombatTextPlus:ToggleEnabled(value)
                end,
                order = 1,
            },
            midnight = {
                name = "Midnight Settings",
                type = "group",
                inline = true,
                order = 1.5,
                args = {
                    info = {
                        type = "description",
                        name = "Blizzard no longer lets addons read the combat log. CombatTextPlus shows numbers from nameplate combat events instead. It cannot tell who caused the damage or healing, so the options below decide which nameplates are allowed to show numbers. In boss fights and Mythic+ the school may also be hidden. Type /ctp status in game for a quick check.",
                        order = 0,
                    },
                    unitEventScope = {
                        name = "Unit Event Scope",
                        type = "select",
                        desc = "Unit events cannot tell who caused the damage, so in a group other players' hits will show up too. Current target only cuts that noise down.",
                        values = {
                            all = "All nameplates",
                            target = "Current target only",
                        },
                        get = function() return db.profile.unitEventScope end,
                        set = function(_, value) db.profile.unitEventScope = value end,
                        order = 2,
                    },
                    onlyMyFights = {
                        name = "Only Enemies I'm Fighting",
                        type = "toggle",
                        width = "double",
                        desc = "Hide damage on enemies you have not attacked. An enemy counts as yours once you target it and cast or auto attack, while one of your damage over time effects is on it, or once you are on its threat table. Stops other players' hits on a dummy or mob you never touched. On enemies you are fighting, other players' hits will still appear.",
                        get = function() return db.profile.onlyMyFights end,
                        set = function(_, value) db.profile.onlyMyFights = value end,
                        order = 2.5,
                    },
                    strictEngage = {
                        name = "Strict: Only Enemies I Targeted",
                        type = "toggle",
                        width = "double",
                        desc = "Only show damage on enemies you targeted and attacked. Your damage over time effects keep an enemy yours, but only one you attacked directly, not one your AoE spread a debuff onto. Removes numbers on neighboring mobs or dummies you only hit with AoE, which is where most other players' hits leak in. Your own AoE damage on untargeted enemies will not show either.",
                        get = function() return db.profile.strictEngage end,
                        set = function(_, value) db.profile.strictEngage = value end,
                        order = 2.55,
                    },
                    engageTimeout = {
                        name = "Engage Timeout (seconds)",
                        type = "range",
                        desc = "How long an enemy stays yours after your last harmful spell or auto attack on it. Keeps old targets from showing numbers for the rest of a long battleground fight. Set to 0 to keep them until you leave combat.",
                        min = 0, max = 30, step = 1,
                        get = function() return db.profile.engageTimeout end,
                        set = function(_, value) db.profile.engageTimeout = value end,
                        order = 2.6,
                    },
                    pvpTargetOnly = {
                        name = "PvP: Current Target Only",
                        type = "toggle",
                        width = "double",
                        desc = "In battlegrounds and arenas, only show numbers on your current target. Cleanest option in PvP. Teammates hitting your target will still show, since Blizzard does not tell addons who dealt the damage.",
                        get = function() return db.profile.pvpTargetOnly end,
                        set = function(_, value) db.profile.pvpTargetOnly = value end,
                        order = 2.7,
                    },
                    healScope = {
                        name = "Show Healing On",
                        type = "select",
                        width = "double",
                        desc = "Heal events do not say who cast the heal, so this decides which friendly nameplates can show healing numbers. Auto uses Group on a healer spec and Players I've healed on everything else. Players I've healed counts any friendly you cast a helpful spell on, including mouseover and raid frame casts. Group also shows heals on your party or raid, including other healers' heals on them. Friendly nameplates are locked by Blizzard inside dungeons, raids, and battlegrounds, so heals can only show in the open world.",
                        values = {
                            auto   = "Auto (by spec)",
                            mine   = "Players I've healed",
                            group  = "My group + players I've healed",
                            target = "My current target only",
                            all    = "All friendly nameplates",
                            off    = "Off",
                        },
                        sorting = { "auto", "mine", "group", "target", "all", "off" },
                        get = function() return db.profile.healScope end,
                        set = function(_, value) db.profile.healScope = value end,
                        order = 2.8,
                    },
                    healTimeout = {
                        name = "Heal Timeout (seconds)",
                        type = "range",
                        desc = "How long a friendly stays yours after your last helpful spell on it. Long enough by default to cover heal over time effects. Set to 0 to keep them until they leave your screen.",
                        min = 0, max = 60, step = 1,
                        get = function() return db.profile.healTimeout end,
                        set = function(_, value) db.profile.healTimeout = value end,
                        order = 2.9,
                    },
                    friendlyNPCPlates = {
                        name = "Show Friendly NPC Nameplates",
                        type = "toggle",
                        width = "double",
                        desc = "Healing numbers need a nameplate to sit on. Friendly NPCs, including the healing training dummy, have no nameplate unless this is on. This is Blizzard's own setting; the addon just flips it for you. Can only be changed out of combat.",
                        get = function()
                            return GetCVarBool and GetCVarBool("nameplateShowFriendlyNPCs") or false
                        end,
                        set = function(_, value)
                            if InCombatLockdown() then
                                CombatTextPlus:Print("Leave combat first. Nameplate settings cannot change in combat.")
                                return
                            end
                            local ok = pcall(SetCVar, "nameplateShowFriendlyNPCs", value and 1 or 0)
                            if not ok or GetCVar("nameplateShowFriendlyNPCs") == nil then
                                CombatTextPlus:Print("This client does not have the friendly NPC nameplate setting.")
                            end
                        end,
                        order = 2.95,
                    },
                    restrictedColor = {
                        name = "Restricted Number Color",
                        type = "color",
                        desc = "Color used when Blizzard hides the damage school during restricted content.",
                        get = function() local c = db.profile.restrictedColor; return c.r, c.g, c.b end,
                        set = function(_, r, g, b) local c = db.profile.restrictedColor; c.r, c.g, c.b = r, g, b end,
                        order = 3,
                    },
                },
            },
            display = {
                name = "Display",
                type = "group",
                inline = true,
                order = 1.7,
                args = {
                    keepTextOnRemoval = {
                        name = "Finish Numbers When Nameplate Disappears",
                        type = "toggle",
                        width = "full",
                        desc = "When an enemy dies or goes out of range, its nameplate disappears. With this on, the numbers already showing on it finish their animation where the enemy was, so your killing hit is not cut off. With this off, they vanish with the nameplate.",
                        get = function() return db.profile.keepTextOnRemoval end,
                        set = function(_, value) db.profile.keepTextOnRemoval = value end,
                        order = 1,
                    },
                    preventOverlap = {
                        name = "Prevent Overlap",
                        type = "toggle",
                        desc = "When a new number appears, numbers too close above it are pushed up one line so they never sit on top of each other. Works with every animation style.",
                        get = function() return db.profile.preventOverlap end,
                        set = function(_, value) db.profile.preventOverlap = value end,
                        order = 1.1,
                    },
                    lineSpacing = {
                        name = "Line Spacing",
                        type = "range",
                        min = 0.6, max = 2.0, step = 0.05,
                        desc = "How far apart pushed numbers sit, as a multiple of their font size. 1.0 is touching, higher is looser.",
                        get = function() return db.profile.lineSpacing end,
                        set = function(_, value) db.profile.lineSpacing = value end,
                        disabled = function() return not db.profile.preventOverlap end,
                        order = 1.2,
                    },
                    maxPerPlate = {
                        name = "Max Numbers Per Nameplate",
                        type = "range",
                        min = 0, max = 20, step = 1,
                        desc = "The most numbers one nameplate shows at once. When full, the oldest is removed to make room, and crits are kept over normal hits. 0 means no limit. Keeps busy targets like world bosses readable.",
                        get = function() return db.profile.maxPerPlate end,
                        set = function(_, value) db.profile.maxPerPlate = value end,
                        order = 1.3,
                    },
                    displayMode = {
                        name = "Show Numbers On",
                        type = "select",
                        desc = "Nameplates: numbers appear on each enemy's nameplate. Center Screen: damage on your current target appears in a fixed spot on screen, and works even with enemy nameplates turned off. Both: shows both at once.\n\nCenter Screen cannot tell whose hit it was either, so in a group it shows everyone's damage on your target.",
                        values = {
                            nameplates = "Nameplates",
                            center = "Center Screen",
                            both = "Both",
                        },
                        sorting = {"nameplates", "center", "both"},
                        get = function() return db.profile.displayMode end,
                        set = function(_, value)
                            db.profile.displayMode = value
                            ReleaseAll()
                        end,
                        order = 2,
                    },
                    centerMaxNumbers = {
                        name = "Center Max Numbers",
                        type = "range",
                        min = 1, max = 20, step = 1,
                        desc = "The most numbers the center display shows at once. When it is full, the oldest number is removed to make room. Crits are kept over normal hits.",
                        get = function() return db.profile.centerMaxNumbers end,
                        set = function(_, value) db.profile.centerMaxNumbers = value end,
                        disabled = function() return db.profile.displayMode == "nameplates" end,
                        order = 3,
                    },
                    centerX = {
                        name = "Center Horizontal Position",
                        type = "range",
                        min = -800, max = 800, step = 5,
                        desc = "Moves the center display left or right from the middle of the screen. Use Preview to see the spot.",
                        get = function() return db.profile.centerX end,
                        set = function(_, value)
                            db.profile.centerX = value
                            PositionCenterAnchor()
                        end,
                        disabled = function() return db.profile.displayMode == "nameplates" end,
                        order = 4,
                    },
                    centerY = {
                        name = "Center Vertical Position",
                        type = "range",
                        min = -500, max = 500, step = 5,
                        desc = "Moves the center display up or down from the middle of the screen. Use Preview to see the spot.",
                        get = function() return db.profile.centerY end,
                        set = function(_, value)
                            db.profile.centerY = value
                            PositionCenterAnchor()
                        end,
                        disabled = function() return db.profile.displayMode == "nameplates" end,
                        order = 5,
                    },
                },
            },
            scrollDuration = {
                name = "Scroll Duration",
                type = "range",
                desc = "How long each number stays on screen, before Speed Factor is applied. Actual time on screen is Scroll Duration divided by Speed Factor. Default 1.5.",
                min = 0.1, max = 5.0, step = 0.1,
                get = function() return db.profile.scrollDuration end,
                set = function(_, value) db.profile.scrollDuration = value end,
                order = 2,
            },
            startYOffset = {
                name = "Start Y Offset",
                type = "range",
                desc = "Where numbers start, relative to the nameplate. Raise it so numbers spawn above the nameplate instead of covering it, or lower it to start below. 0 is the original spot.",
                min = -100, max = 200, step = 5,
                get = function() return db.profile.startYOffset end,
                set = function(_, value) db.profile.startYOffset = value end,
                order = 2.9,
            },
            maxYOffset = {
                name = "Max Y Offset",
                type = "range",
                desc = "Set the maximum vertical offset for the text to scroll upwards.",
                min = 50, max = 300, step = 10,
                get = function() return db.profile.maxYOffset end,
                set = function(_, value) db.profile.maxYOffset = value end,
                order = 3,
            },
            speedFactor = {
                name = "Speed Factor",
                type = "range",
                desc = "Higher values make numbers move farther and disappear sooner. 1.0 is the readable default. At 2.0 a number is gone in half the time and travels twice as far.",
                min = 0.25, max = 5.0, step = 0.05,
                get = function() return db.profile.speedFactor end,
                set = function(_, value) db.profile.speedFactor = value end,
                order = 4,
            },
            damageTypeOffsets = {
                name = "Damage Type Offsets",
                type = "group",
                inline = true,
                desc = "Customize the horizontal movement of text based on damage type.",
                args = offsetArgs,
                order = 5,
            },
            fontSize = {
                name = "Font Size",
                type = "range",
                desc = "Set the font size of the combat text. This also resets every damage type size to this value.",
                min = 8, max = 32, step = 1,
                get = function() return db.profile.fontSize end,
                set = function(_, value)
                    db.profile.fontSize = value
                    for k in pairs(db.profile.damageTypeFontSizes) do
                        db.profile.damageTypeFontSizes[k] = value
                    end
                    CombatTextPlus:RefreshFonts()
                end,
                order = 7,
            },
            labelFontSize = {
                name = "Label Font Size",
                type = "range",
                desc = "Set the font size of the damage type label (for example Physical, Fire, Shadow).",
                min = 8, max = 32, step = 1,
                get = function() return db.profile.labelFontSize end,
                set = function(_, value)
                    db.profile.labelFontSize = value
                    CombatTextPlus:RefreshFonts()
                end,
                order = 8,
            },
            showLabels = {
                name = "Show Labels",
                type = "toggle",
                desc = "Show or hide damage type labels (for example Fire, Frost, Heal). Labels are hidden on numbers Blizzard marks as restricted.",
                get = function() return db.profile.showLabels end,
                set = function(_, value)
                    db.profile.showLabels = value
                    CombatTextPlus:ApplySettings()
                end,
                order = 9,
            },
            showSpellIcons = {
                name = "Show Spell Icons",
                type = "toggle",
                desc = "Show the icon of the spell that made each hit. Icons are confirmed with Blizzard's built in damage meter, so a hit only gets an icon when its spell can be matched. Hits from other players, and hits whose amount Blizzard hides, show no icon. Retail only.",
                get = function() return db.profile.showSpellIcons end,
                set = function(_, value) db.profile.showSpellIcons = value end,
                order = 9.1,
            },
            spellIconPosition = {
                name = "Icon Position",
                type = "select",
                values = { left = "Left of Number", right = "Right of Number" },
                sorting = { "left", "right" },
                get = function() return db.profile.spellIconPosition end,
                set = function(_, value) db.profile.spellIconPosition = value end,
                disabled = function() return not db.profile.showSpellIcons end,
                order = 9.2,
            },
            spellIconSize = {
                name = "Icon Size",
                type = "range",
                min = 0.5, max = 2.0, step = 0.05,
                desc = "Icon size compared to the number's font size. 1.0 matches the number, so bigger numbers like crits get bigger icons.",
                get = function() return db.profile.spellIconSize end,
                set = function(_, value) db.profile.spellIconSize = value end,
                disabled = function() return not db.profile.showSpellIcons end,
                order = 9.3,
            },
            spellIconGuess = {
                name = "Best Guess When Unconfirmed",
                type = "toggle",
                desc = "When a hit cannot be confirmed (for example Blizzard hides the amount in boss fights), use your last cast if the hit landed right after it, on the enemy you cast at. More icons, but some may be wrong. Off by default.",
                get = function() return db.profile.spellIconGuess end,
                set = function(_, value) db.profile.spellIconGuess = value end,
                disabled = function() return not db.profile.showSpellIcons end,
                order = 9.4,
            },
            font = {
                name = "Font",
                type = "select",
                desc = "Set the font of the combat text.",
                values = LSM:HashTable("font"),
                dialogControl = "LSM30_Font",
                get = function() return db.profile.font end,
                set = function(_, value)
                    db.profile.font = value
                    CombatTextPlus:RefreshFonts()
                end,
                order = 10,
            },
            colorPreset = {
                name = "Use Default Colors",
                type = "execute",
                width = "double",
                desc = "Apply the standard color preset to every damage type, label, and the restricted number color: gold holy, orange fire, green nature, light blue frost, purple shadow, pink arcane, and so on. Only colors change. Fonts, speed, filters, and positions are left alone.",
                confirm = true,
                confirmText = "Replace all damage and label colors with the default preset?",
                func = function() CombatTextPlus:ApplyColorPreset() end,
                order = 10.5,
            },
            labelColors = {
                name = "Label Colors",
                type = "group",
                inline = true,
                desc = "Customize the color of the labels that appear next to each type of damage.",
                args = labelColorArgs,
                order = 11,
            },
            damageTypeFilters = {
                name = "Damage Type Filters",
                type = "group",
                inline = true,
                desc = "Select which types of damage you want to see displayed during combat.",
                args = filterArgs,
                order = 12,
            },
            damageTypeColors = {
                name = "Damage Type Colors",
                type = "group",
                inline = true,
                desc = "Customize the color of the combat text for each damage type.",
                args = colorArgs,
                order = 13,
            },
            minimap = {
                name = "Show Minimap Button",
                type = "toggle",
                desc = "Toggle the display of the minimap button.",
                get = function() return not db.profile.minimap.hide end,
                set = function(_, val)
                    db.profile.minimap.hide = not val
                    if db.profile.minimap.hide then
                        icon:Hide("CombatTextPlus")
                    else
                        icon:Show("CombatTextPlus")
                    end
                end,
                order = 14,
            },
            damageTypeFontSizes = {
                name = "Damage Type Font Sizes",
                type = "group",
                inline = true,
                desc = "Customize the font size for each damage type.",
                args = fontSizeArgs,
                order = 15,
            },
            animationStyle = {
                name = "Animation Style",
                type = "select",
                desc = "Choose how the combat text animates.",
                values = ANIMATION_STYLES,
                get = function() return db.profile.animationStyle end,
                set = function(_, value) db.profile.animationStyle = value end,
                order = 16,
            },
            misses = {
                name = "Misses & Avoidance",
                type = "group",
                inline = true,
                order = 16.7,
                args = {
                    info = {
                        type = "description",
                        name = "Enemy misses have the same limit as damage: the game does not say whose attack missed, so in a group you will see other players' misses too. In boss fights and Mythic+, Blizzard may hide the result, and those misses cannot be shown.",
                        order = 0,
                    },
                    showMisses = {
                        name = "Show Misses on Enemies",
                        type = "toggle",
                        width = "full",
                        desc = "Show Miss, Dodge, Parry, Immune, and so on when an attack on an enemy you are fighting does no damage. Follows Show Numbers On, so it appears on nameplates, center screen, or both.",
                        get = function() return db.profile.showMisses end,
                        set = function(_, value) db.profile.showMisses = value end,
                        order = 1,
                    },
                    showMyAvoidance = {
                        name = "Show My Avoidance",
                        type = "toggle",
                        width = "full",
                        desc = "Show Dodge, Parry, Block, and so on when you avoid an attack. Appears in its own spot near your character. Handy for tanks.",
                        get = function() return db.profile.showMyAvoidance end,
                        set = function(_, value) db.profile.showMyAvoidance = value end,
                        order = 2,
                    },
                    missTypes = {
                        name = "Show These Results",
                        type = "multiselect",
                        desc = "Pick which results to show. Applies to both enemy misses and your own avoidance.",
                        values = MISS_TEXT,
                        get = function(_, key) return db.profile.missTypes[key] end,
                        set = function(_, key, value) db.profile.missTypes[key] = value end,
                        disabled = function() return not db.profile.showMisses and not db.profile.showMyAvoidance end,
                        order = 3,
                    },
                    missColor = {
                        name = "Enemy Miss Color",
                        type = "color",
                        get = function() local c = db.profile.missColor; return c.r, c.g, c.b end,
                        set = function(_, r, g, b) local c = db.profile.missColor; c.r, c.g, c.b = r, g, b end,
                        disabled = function() return not db.profile.showMisses end,
                        order = 4,
                    },
                    missFontSize = {
                        name = "Enemy Miss Font Size",
                        type = "range",
                        min = 6, max = 48, step = 1,
                        get = function() return db.profile.missFontSize end,
                        set = function(_, value)
                            db.profile.missFontSize = value
                            CombatTextPlus:RefreshFonts("miss")
                        end,
                        disabled = function() return not db.profile.showMisses end,
                        order = 5,
                    },
                    avoidanceColor = {
                        name = "My Avoidance Color",
                        type = "color",
                        get = function() local c = db.profile.avoidanceColor; return c.r, c.g, c.b end,
                        set = function(_, r, g, b) local c = db.profile.avoidanceColor; c.r, c.g, c.b = r, g, b end,
                        disabled = function() return not db.profile.showMyAvoidance end,
                        order = 6,
                    },
                    avoidanceFontSize = {
                        name = "My Avoidance Font Size",
                        type = "range",
                        min = 6, max = 48, step = 1,
                        get = function() return db.profile.avoidanceFontSize end,
                        set = function(_, value)
                            db.profile.avoidanceFontSize = value
                            CombatTextPlus:RefreshFonts("avoid")
                        end,
                        disabled = function() return not db.profile.showMyAvoidance end,
                        order = 7,
                    },
                    avoidanceMaxNumbers = {
                        name = "My Avoidance Max Shown",
                        type = "range",
                        min = 1, max = 10, step = 1,
                        desc = "The most avoidance texts shown at once. The oldest is removed to make room.",
                        get = function() return db.profile.avoidanceMaxNumbers end,
                        set = function(_, value) db.profile.avoidanceMaxNumbers = value end,
                        disabled = function() return not db.profile.showMyAvoidance end,
                        order = 8,
                    },
                    avoidanceX = {
                        name = "My Avoidance Horizontal Position",
                        type = "range",
                        min = -800, max = 800, step = 5,
                        desc = "Left or right from the middle of the screen. Use Preview to see the spot.",
                        get = function() return db.profile.avoidanceX end,
                        set = function(_, value)
                            db.profile.avoidanceX = value
                            PositionAvoidAnchor()
                        end,
                        disabled = function() return not db.profile.showMyAvoidance end,
                        order = 9,
                    },
                    avoidanceY = {
                        name = "My Avoidance Vertical Position",
                        type = "range",
                        min = -500, max = 500, step = 5,
                        desc = "Up or down from the middle of the screen. Use Preview to see the spot.",
                        get = function() return db.profile.avoidanceY end,
                        set = function(_, value)
                            db.profile.avoidanceY = value
                            PositionAvoidAnchor()
                        end,
                        disabled = function() return not db.profile.showMyAvoidance end,
                        order = 10,
                    },
                },
            },
            crits = {
                name = "Crits",
                type = "group",
                inline = true,
                order = 16.5,
                disabled = function() return not db.profile.damageTypeFilters.crit end,
                args = {
                    info = {
                        type = "description",
                        name = "Turn off Critical Hits in Damage Type Filters to show crits as normal hits instead.",
                        order = 0,
                    },
                    critColorMode = {
                        name = "Crit Color",
                        type = "select",
                        desc = "Crit Color: crits use the Crit color, font size, and offset.\n\nDamage Type Color: crits keep their damage type's color (a Fire crit is orange), follow that type's filter and offset, and are drawn larger using Crit Size.",
                        values = {
                            crit = "Crit Color",
                            school = "Damage Type Color",
                        },
                        sorting = {"crit", "school"},
                        get = function() return db.profile.critColorMode end,
                        set = function(_, value) db.profile.critColorMode = value end,
                        order = 1,
                    },
                    critAnimation = {
                        name = "Crit Animation",
                        type = "select",
                        desc = "Animation used for crits only. Normal hits keep the Animation Style above.",
                        values = function()
                            local v = { same = "Same as normal hits" }
                            for k, label in pairs(ANIMATION_STYLES) do v[k] = label end
                            return v
                        end,
                        get = function() return db.profile.critAnimation end,
                        set = function(_, value) db.profile.critAnimation = value end,
                        order = 2,
                    },
                    critSizeMultiplier = {
                        name = "Crit Size",
                        type = "range",
                        min = 1, max = 3, step = 0.1,
                        isPercent = false,
                        desc = "How much bigger a crit is than a normal hit of the same damage type. 2.0 is double size. Used with Damage Type Color. With Crit Color, crits use the Crit Damage Font Size instead.",
                        get = function() return db.profile.critSizeMultiplier end,
                        set = function(_, value)
                            db.profile.critSizeMultiplier = value
                            CombatTextPlus:RefreshFonts()
                        end,
                        disabled = function()
                            return not db.profile.damageTypeFilters.crit or db.profile.critColorMode ~= "school"
                        end,
                        order = 3,
                    },
                    critLabel = {
                        name = "Add \"Crit\" to Label",
                        type = "toggle",
                        desc = "With Damage Type Color, labels read \"Fire Crit\" instead of \"Fire\" so crits stand out. Needs Show Labels on.",
                        get = function() return db.profile.critLabel end,
                        set = function(_, value) db.profile.critLabel = value end,
                        disabled = function()
                            return not db.profile.damageTypeFilters.crit or db.profile.critColorMode ~= "school"
                        end,
                        order = 4,
                    },
                },
            },
            animationEasing = {
                name = "Animation Easing",
                type = "select",
                desc = "Choose the easing function for the animation.",
                values = {
                    linear = "Linear",
                    quadratic = "Quadratic",
                    exponential = "Exponential",
                },
                get = function() return db.profile.animationEasing end,
                set = function(_, value) db.profile.animationEasing = value end,
                order = 17,
            },
            tuning = {
                name = "Animation Tuning",
                type = "group",
                inline = true,
                order = 18,
                args = {
                    amplitude = {
                        name = "Amplitude",
                        type = "range",
                        min = 0, max = 200, step = 1,
                        desc = "How far the text moves side to side for oscillating animations like Zigzag. Higher means wider swings.",
                        get = function() return db.profile.animationAmplitude end,
                        set = function(_, v) db.profile.animationAmplitude = v end,
                        order = 1,
                    },
                    frequency = {
                        name = "Frequency",
                        type = "range",
                        min = 0.5, max = 8, step = 0.1,
                        desc = "How many oscillations happen over the animation. Higher means more wiggles.",
                        get = function() return db.profile.animationFrequency end,
                        set = function(_, v) db.profile.animationFrequency = v end,
                        order = 2,
                    },
                    pulses = {
                        name = "Pulses (ripple)",
                        type = "range",
                        min = 1, max = 8, step = 1,
                        desc = "Number of quick scale pulses for the Wave Fade (Ripple) animation.",
                        get = function() return db.profile.animationPulses end,
                        set = function(_, v) db.profile.animationPulses = v end,
                        order = 3,
                    },
                    horizontalDistance = {
                        name = "Horizontal Distance",
                        type = "range",
                        min = 20, max = 400, step = 1,
                        desc = "How far the Left → Right, Right → Left, Rainbow, and Arc animations travel sideways from the nameplate, in pixels. Rainbow uses this as the full width of the arch.",
                        get = function() return db.profile.animationHorizontalDistance end,
                        set = function(_, v) db.profile.animationHorizontalDistance = v end,
                        order = 4,
                    },
                    horizontalStagger = {
                        name = "Horizontal Stagger",
                        type = "range",
                        min = 0, max = 60, step = 1,
                        desc = "Spacing in pixels between simultaneous texts on the same nameplate for the Left, Right, and Rainbow animations so they do not overlap.",
                        get = function() return db.profile.horizontalStagger end,
                        set = function(_, v) db.profile.horizontalStagger = v end,
                        order = 5,
                    },
                },
            },
            preview = {
                name = "Preview Combat Text",
                type = "execute",
                desc = "Show sample combat text using current settings.",
                func = function() CombatTextPlus:ShowPreviewCombatText() end,
                order = 99,
            },
        },
    }
end

------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------
function CombatTextPlus:OnInitialize()
    -- No default profile argument: AceDB then defaults each character to its own
    -- "Name - Realm" profile, and a profile the player picks actually sticks.
    MigrateSavedColors()
    db = AceDB:New("CombatTextPlusDB", savedVariables)
    self.db = db
    -- Fresh installs have nothing to migrate; mark them done so the
    -- migration never runs against data saved by this version.
    db.global.colorMigration = COLOR_MIGRATION_VERSION

    AceConfig:RegisterOptionsTable("CombatTextPlus", BuildOptions())
    AceConfigDialog:AddToBlizOptions("CombatTextPlus", "CombatTextPlus")

    AceConfig:RegisterOptionsTable("CombatTextPlus_Profiles", AceDBOptions:GetOptionsTable(db))
    AceConfigDialog:AddToBlizOptions("CombatTextPlus_Profiles", "Profiles", "CombatTextPlus")

    db.RegisterCallback(self, "OnProfileChanged", "ApplySettings")
    db.RegisterCallback(self, "OnProfileCopied", "ApplySettings")
    db.RegisterCallback(self, "OnProfileReset", "ApplySettings")

    pcall(icon.Register, icon, "CombatTextPlus", CombatTextPlusLDB, db.profile.minimap)

    self:RegisterChatCommand("ctp", "SlashCommand")
    self:RegisterChatCommand("combattextplus", "SlashCommand")

    eventFrame:RegisterEvent("UNIT_COMBAT")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_COMBAT" then
            CombatTextPlus:HandleUnitCombat(...)
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            TrackPlate(...)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            UntrackPlate(...)
        elseif event == "UNIT_SPELLCAST_SENT" then
            -- unit, targetName, castGUID, spellID
            local _, targetName, _, spellID = ...
            OnPlayerCast(spellID)
            MarkNamedFriendlyHealed(targetName, spellID)
        elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED"
            or event == "UNIT_SPELLCAST_CHANNEL_START" then
            -- unit, castGUID, spellID
            local _, _, spellID = ...
            OnPlayerCast(spellID)
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                RecordCast(spellID)
            end
        elseif event == "PLAYER_ENTER_COMBAT" then
            MarkTargetEngaged()
        elseif event == "PLAYER_TARGET_CHANGED" then
            targetEngagedAt = 0
            if IsAutoAttacking() then
                MarkTargetEngaged()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            wipe(engagedPlates)
            targetEngagedAt = 0
        elseif event == "PLAYER_ENTERING_WORLD" then
            RebuildPlates()
        end
    end)

    self:ApplySettings()
end
