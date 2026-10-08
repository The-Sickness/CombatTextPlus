-- Made by Sharpedge_Gaming
-- v3.4 for 12.0 Midnight
--
-- Data source: UNIT_COMBAT on nameplates. Works everywhere, including boss
-- encounters and Mythic+. Numbers that Blizzard marks secret are passed
-- straight to FontString:SetText and never touched by Lua math.
-- The combat log is not used at all. In 12.0, registering
-- COMBAT_LOG_EVENT_UNFILTERED from an addon is a forbidden action.

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
    "shadow", "arcane", "chaos", "dot", "heal", "crit",
}

local TYPE_LABELS = {
    physical = "Physical", holy = "Holy", fire = "Fire", nature = "Nature",
    frost = "Frost", shadow = "Shadow", arcane = "Arcane", chaos = "Chaos",
    dot = "DOT", heal = "Heal", crit = "Crit",
}

local SCHOOL_TO_TYPE = {
    [1] = "physical", [2] = "holy", [4] = "fire", [8] = "nature",
    [16] = "frost", [32] = "shadow", [64] = "arcane", [124] = "chaos",
}

------------------------------------------------------------
-- Defaults
------------------------------------------------------------
local savedVariables = {
    profile = {
        font = "Friz Quadrata TT",
        textColor = {r = 1, g = 1, b = 1, a = 1},
        fontSize = 24,
        labelFontSize = 14,
        enabled = true,
        scrollDuration = 0.5,
        animationStyle = "fade",
        animationEasing = "linear",
        startYOffset = 0,
        maxYOffset = 100,
        speedFactor = 2.0,
        damageTypeOffsets = {
            physical = -10, holy = 10, fire = 0, nature = -15, frost = 15,
            shadow = 0, arcane = 0, chaos = 0, dot = 10, heal = 0, crit = 5,
        },
        damageTypeFilters = {
            physical = true, holy = true, fire = true, nature = true, frost = true,
            shadow = true, arcane = true, chaos = true, dot = true, heal = true, crit = true,
        },
        damageTypeColors = {
            physical = {r = 1, g = 1, b = 1}, holy = {r = 1, g = 1, b = 1}, fire = {r = 1, g = 1, b = 1},
            nature = {r = 1, g = 1, b = 1}, frost = {r = 1, g = 1, b = 1}, shadow = {r = 1, g = 1, b = 1},
            arcane = {r = 1, g = 1, b = 1}, chaos = {r = 1, g = 1, b = 1}, dot = {r = 1, g = 1, b = 1},
            heal = {r = 1, g = 1, b = 1}, crit = {r = 1, g = 1, b = 1},
        },
        labelColors = {
            physical = {r = 1, g = 1, b = 1}, holy = {r = 1, g = 1, b = 1}, fire = {r = 1, g = 1, b = 1},
            nature = {r = 1, g = 1, b = 1}, frost = {r = 1, g = 1, b = 1}, shadow = {r = 1, g = 1, b = 1},
            arcane = {r = 1, g = 1, b = 1}, chaos = {r = 1, g = 1, b = 1}, dot = {r = 1, g = 1, b = 1},
            heal = {r = 1, g = 1, b = 1}, crit = {r = 1, g = 1, b = 1},
        },
        minimap = { hide = false },
        dotYOffsetMultiplier = 1.0,
        damageTypeFontSizes = {
            physical = 24, holy = 24, fire = 24, nature = 24,
            frost = 24, shadow = 24, arcane = 24, chaos = 24,
            dot = 24, heal = 24, crit = 24,
        },
        showLabels = true,
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
        restrictedColor = {r = 1, g = 0.82, b = 0},
    }
}

------------------------------------------------------------
-- State
------------------------------------------------------------
local db
local debugMode = false

local activeTexts = {}      -- [frame] = true
local stacks = {}           -- stacks[anchor][damageType] = { frame, frame, ... }
local framePool = {}

local plateByUnit = {}      -- "nameplate3" -> plate frame
local engagedPlates = {}    -- [plate] = GetTime() of your last attack on that enemy
local healedPlates = {}     -- [plate] = GetTime() of your last heal cast on that friendly

local AUTO_ATTACK_ID = 6603
local AUTO_SHOT_ID = 75

local previewAnchor

local eventFrame = CreateFrame("Frame", "CombatTextPlusFrame", UIParent)

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

local function ReleaseTextFrame(f)
    if not f or f.released then return end
    f.released = true
    f:SetScript("OnUpdate", nil)
    RemoveFromStack(f)
    activeTexts[f] = nil
    f:Hide()
    f:ClearAllPoints()
    f:SetParent(UIParent)
    f:SetScale(1)
    f:SetAlpha(1)
    f.text:SetText("")
    f.label:SetText("")
    f.anchor = nil
    f.damageType = nil
    framePool[#framePool + 1] = f
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
        ReleaseAllOnAnchor(plate)
    end
    if plate then
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
    if not IsAttackSpell(spellID) then return end
    if not UnitExists("target") then return end
    local canAttack = UnitCanAttack("player", "target")
    if IsSecret(canAttack) or not canAttack then return end
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if plate then
        engagedPlates[plate] = GetTime()
    end
end

local function IsPlateEngaged(plate)
    local stamp = plate and engagedPlates[plate]
    if not stamp then return false end
    local timeout = (db and db.profile.engageTimeout) or 6
    if timeout > 0 and (GetTime() - stamp) > timeout then
        engagedPlates[plate] = nil
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
    local previewTypes = {"physical", "fire", "heal", "crit"}
    local previewValues = { physical = 1234, fire = 5678, heal = 3456, crit = 9999 }

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

    for i, damageType in ipairs(previewTypes) do
        C_Timer.After((i - 1) * 0.25, function()
            CombatTextPlus:DisplayCombatText(anchor, previewValues[damageType], damageType)
        end)
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
    local startYOffset = db.profile.startYOffset or 0
    local maxYOffset = db.profile.maxYOffset or 100
    local yOffset = startYOffset + maxYOffset * progress * db.profile.speedFactor

    if damageType == "dot" then
        yOffset = yOffset * (db.profile.dotYOffsetMultiplier or 1.0)
    end

    return xOffset, yOffset
end

function CombatTextPlus:ApplyAnimationStyle(f, anchor, damageType, progress, stackIndex, stackCount)
    local function ClampAlpha(a)
        return math.max(0, math.min(1, a or 0))
    end

    local style = db.profile.animationStyle
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
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "off" then
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))
        f:SetScale(1)

    elseif style == "bounce" then
        local bounce = math.abs(math.sin(eased * math.pi * 3) * (1 - eased) * 100)
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX, baseY + bounce)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "shake" then
        local shakeX = math.sin(eased * 30) * 25
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX + shakeX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "spiral" then
        local angle = eased * 8 * math.pi
        local radius = 80 * eased
        local sx = math.cos(angle) * radius
        local sy = math.sin(angle) * radius + (maxY * eased * speedFactor)
        f:SetPoint("CENTER", anchor, "BOTTOM", sx, sy)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "scale" then
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))
        f:SetScale(1 + eased * 2)

    elseif style == "pop" then
        local popScale
        if eased < 0.2 then
            popScale = 1 + eased * 4
        else
            popScale = 1.8 - (eased - 0.2) * 2
        end
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX, baseY)
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
        f:SetPoint("CENTER", anchor, "BOTTOM", moveX, moveY)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "zigzag" then
        local steps = math.max(1, math.floor(frequency * 2))
        local zig = math.sin(eased * math.pi * steps) * amplitude * (1 - eased)
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX + zig, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))
        f:SetScale(1)

    elseif style == "spiral_out" then
        local angle = eased * 2 * 2 * math.pi
        local radius = (80 + amplitude) * eased
        local sx = math.cos(angle) * radius
        local sy = math.sin(angle) * radius + (maxY * eased * speedFactor)
        f:SetPoint("CENTER", anchor, "BOTTOM", sx, sy)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "spiral_in" then
        local angle = (1 - eased) * 2 * 2 * math.pi
        local radius = (80 + amplitude) * (1 - eased)
        local sx = math.cos(angle) * radius
        local sy = math.sin(angle) * radius + (maxY * eased * speedFactor * 0.5)
        f:SetPoint("CENTER", anchor, "BOTTOM", sx, sy)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "ripple" then
        local pulse = math.sin(eased * math.pi * pulses) * 0.25 * (1 - eased)
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX, baseY)
        f:SetScale(1 + pulse)
        f:SetAlpha(ClampAlpha(1 - eased))

    elseif style == "flip" then
        local flipWave = math.sin(eased * math.pi)
        local tilt = math.cos(eased * math.pi * 2) * 12 * (1 - eased)
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX + tilt, baseY)
        f:SetScale(1 + flipWave * 0.6)
        f:SetAlpha(ClampAlpha((1 - eased) * (0.85 + 0.15 * math.cos(eased * math.pi * 2))))

    else
        f:SetPoint("CENTER", anchor, "BOTTOM", baseX, baseY)
        f:SetAlpha(ClampAlpha(1 - eased))
    end
end

------------------------------------------------------------
-- Display
-- amount may be a secret value. If it is, it goes straight into SetText
-- with no formatting, math, or comparison.
------------------------------------------------------------
function CombatTextPlus:DisplayCombatText(anchor, amount, damageType)
    if not anchor then return end
    if anchor.IsForbidden and anchor:IsForbidden() then return end

    local secret = IsSecret(amount)
    local shownText
    if not secret then
        shownText = self:FormatNumber(amount)
        if not shownText then return end
    end

    local f = AcquireTextFrame(anchor)
    f.damageType = damageType

    stacks[anchor] = stacks[anchor] or {}
    stacks[anchor][damageType] = stacks[anchor][damageType] or {}
    local list = stacks[anchor][damageType]
    list[#list + 1] = f

    local fontPath = LSM:Fetch("font", db.profile.font)
    local fontSize = db.profile.damageTypeFontSizes[damageType] or db.profile.fontSize
    f.text:SetFont(fontPath, fontSize, "OUTLINE")
    f.label:SetFont(fontPath, db.profile.labelFontSize, "OUTLINE")

    local dR, dG, dB
    if damageType == "restricted" then
        local c = db.profile.restrictedColor
        dR, dG, dB = c.r, c.g, c.b
    else
        dR, dG, dB = self:GetDamageTypeColor(damageType)
    end

    -- Labels anchor to the number's width, so they are skipped for secret numbers.
    local labelText = self:GetDamageTypeLabel(damageType)
    if db.profile.showLabels and not secret and labelText ~= "" then
        local lR, lG, lB = self:GetLabelColor(damageType)
        f.label:SetTextColor(lR, lG, lB)
        f.label:SetText(labelText)
        f.label:Show()
    else
        f.label:Hide()
    end

    f.text:SetTextColor(dR, dG, dB)
    if secret then
        f.text:SetText(amount)
    else
        f.text:SetText(shownText)
    end

    self:ApplyAnimationStyle(f, anchor, damageType, 0, #list, #list)
    f:Show()

    local startTime = GetTime()
    f:SetScript("OnUpdate", function(selfFrame)
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
        CombatTextPlus:ApplyAnimationStyle(selfFrame, selfFrame.anchor, selfFrame.damageType, progress, stackIndex, stackCount)
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

------------------------------------------------------------
-- UNIT_COMBAT handler
-- Args: unit, action, flagText, amount, schoolMask
------------------------------------------------------------
function CombatTextPlus:HandleUnitCombat(unit, action, flagText, amount, schoolMask)
    if not db.profile.enabled then return end
    if IsSecret(unit) or type(unit) ~= "string" then return end

    -- Debug only: UNIT_COMBAT also fires for your target. If a heal shows up
    -- here with no nameplate event after it, the unit simply has no nameplate.
    if debugMode and unit == "target" then
        local plate = C_NamePlate.GetNamePlateForUnit("target")
        local plateState
        if not plate then
            plateState = "NONE. This unit has no nameplate, so nothing can show on it. For friendly NPCs like the healing dummy, turn on Friendly NPC Nameplates in /ctp."
        elseif plate.IsForbidden and plate:IsForbidden() then
            plateState = "locked by Blizzard (instance)"
        else
            plateState = "ok"
        end
        self:Print(("target | action: %s | target nameplate: %s"):format(
            IsSecret(action) and "[secret]" or tostring(action), plateState))
    end

    if not unit:find("^nameplate%d") then return end

    local plate = plateByUnit[unit]
    if not plate then
        if debugMode then
            self:Print(unit .. " | skipped: no usable nameplate. Blizzard locks friendly nameplates inside dungeons, raids, and battlegrounds, so heals cannot show there.")
        end
        return
    end

    -- Hostile or friendly decides what is allowed on this plate.
    -- Damage only on enemies, heals only on friendlies. No guessing.
    local canAttack = UnitCanAttack("player", unit)
    local hostileKnown = not IsSecret(canAttack)
    local isHostile = hostileKnown and canAttack and true or false

    if debugMode then
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

    local isHeal
    if isHostile then
        -- Enemy plate: damage only.
        if not IsSecret(action) and action ~= "WOUND" then return end
        isHeal = false
    else
        -- Friendly plate: heals only. If Blizzard hides the action, we cannot
        -- tell a heal from damage, so nothing is shown rather than a wrong number.
        if IsSecret(action) or action ~= "HEAL" then return end
        isHeal = true
    end

    if not IsSecret(amount) then
        if type(amount) ~= "number" or amount <= 0 then return end
    end

    if not isHeal and db.profile.onlyMyFights and not self:IsFightingUnit(unit, plate) then
        return
    end

    if isHeal and not self:IsHealAllowed(unit, plate) then
        if debugMode then
            local scope = db.profile.healScope or "auto"
            if scope == "auto" then
                scope = "auto (" .. (IsHealerSpec() and "group" or "mine") .. ")"
            end
            self:Print(unit .. " | heal filtered by Show Healing On: " .. scope)
        end
        return
    end

    local damageType
    if isHeal then
        if not db.profile.damageTypeFilters.heal then return end
        damageType = "heal"
    else
        local isCrit = (not IsSecret(flagText)) and flagText == "CRITICAL"
        if isCrit then
            damageType = "crit"
        elseif not IsSecret(schoolMask) and type(schoolMask) == "number" then
            damageType = self:GetDamageType(schoolMask)
        else
            damageType = "restricted"
        end
        if damageType ~= "restricted" and not db.profile.damageTypeFilters[damageType] then return end
    end

    self:DisplayCombatText(plate, amount, damageType)
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
        local fontSize = db.profile.damageTypeFontSizes[f.damageType] or db.profile.fontSize
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
            local fontSize = db.profile.damageTypeFontSizes[f.damageType] or db.profile.fontSize
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
    elseif input == "debug" then
        debugMode = not debugMode
        self:Print("Debug " .. (debugMode and "ON. Every nameplate combat event will print to chat. Type /ctp debug again to stop." or "OFF."))
    else
        OpenOptions()
    end
end

------------------------------------------------------------
-- Options
------------------------------------------------------------
local function TypeNames(t)
    if t == "dot" then
        return "DOT Damage", "DOT Damage Color", "DOT Damage Font Size", "DOT Label Color", "DOT Offset", "DOT effects"
    elseif t == "heal" then
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
            desc = "Enable or disable the display of " .. noun .. ".",
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
                        desc = "Hide damage on enemies you have not attacked. An enemy counts as yours once you target it and cast or auto attack, or once you are on its threat table. Stops other players' hits on a dummy or mob you never touched. On enemies you are fighting, other players' hits will still appear.",
                        get = function() return db.profile.onlyMyFights end,
                        set = function(_, value) db.profile.onlyMyFights = value end,
                        order = 2.5,
                    },
                    strictEngage = {
                        name = "Strict: Only Enemies I Targeted",
                        type = "toggle",
                        width = "double",
                        desc = "Only show damage on enemies you targeted and attacked. Removes numbers on neighboring mobs or dummies you only hit with AoE, which is where most other players' hits leak in. Your own AoE damage on untargeted enemies will not show either.",
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
            scrollDuration = {
                name = "Scroll Duration",
                type = "range",
                desc = "Set the duration of the scroll animation.",
                min = 0.1, max = 3.0, step = 0.1,
                get = function() return db.profile.scrollDuration end,
                set = function(_, value) db.profile.scrollDuration = value end,
                order = 2,
            },
            startYOffset = {
                name = "Start Y Offset",
                type = "range",
                min = -200, max = 200, step = 5,
                desc = "Initial vertical offset for combat text. This helps to position combat text above or below nameplates.",
                get = function() return db.profile.startYOffset end,
                set = function(_, value) db.profile.startYOffset = value end,
                order = 3,
            },
            maxYOffset = {
                name = "Max Y Offset",
                type = "range",
                desc = "Set the maximum vertical offset for the text to scroll upwards.",
                min = 50, max = 300, step = 10,
                get = function() return db.profile.maxYOffset end,
                set = function(_, value) db.profile.maxYOffset = value end,
                order = 4,
            },
            speedFactor = {
                name = "Speed Factor",
                type = "range",
                desc = "Set the speed of the text movement. Higher values animate faster.",
                min = 0.5, max = 5.0, step = 0.1,
                get = function() return db.profile.speedFactor end,
                set = function(_, value) db.profile.speedFactor = value end,
                order = 5,
            },
            damageTypeOffsets = {
                name = "Damage Type Offsets",
                type = "group",
                inline = true,
                desc = "Customize the horizontal movement of text based on damage type.",
                args = offsetArgs,
                order = 6,
            },
            dotYOffsetMultiplier = {
                name = "DOT Y Offset Multiplier",
                type = "range",
                desc = "Adjust the vertical movement of DOT text.",
                min = 0.1, max = 2.0, step = 0.1,
                get = function() return db.profile.dotYOffsetMultiplier end,
                set = function(_, value) db.profile.dotYOffsetMultiplier = value end,
                order = 7,
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
                order = 8,
            },
            labelFontSize = {
                name = "Label Font Size",
                type = "range",
                desc = "Set the font size of the damage type label (for example Physical, Fire, Shadow, DOT).",
                min = 8, max = 32, step = 1,
                get = function() return db.profile.labelFontSize end,
                set = function(_, value)
                    db.profile.labelFontSize = value
                    CombatTextPlus:RefreshFonts()
                end,
                order = 9,
            },
            showLabels = {
                name = "Show Labels",
                type = "toggle",
                desc = "Show or hide damage type labels (for example Fire, Frost, DOT). Labels are hidden on numbers Blizzard marks as restricted.",
                get = function() return db.profile.showLabels end,
                set = function(_, value)
                    db.profile.showLabels = value
                    CombatTextPlus:ApplySettings()
                end,
                order = 10,
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
                order = 11,
            },
            labelColors = {
                name = "Label Colors",
                type = "group",
                inline = true,
                desc = "Customize the color of the labels that appear next to each type of damage.",
                args = labelColorArgs,
                order = 12,
            },
            damageTypeFilters = {
                name = "Damage Type Filters",
                type = "group",
                inline = true,
                desc = "Select which types of damage you want to see displayed during combat.",
                args = filterArgs,
                order = 13,
            },
            damageTypeColors = {
                name = "Damage Type Colors",
                type = "group",
                inline = true,
                desc = "Customize the color of the combat text for each damage type.",
                args = colorArgs,
                order = 14,
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
                order = 15,
            },
            damageTypeFontSizes = {
                name = "Damage Type Font Sizes",
                type = "group",
                inline = true,
                desc = "Customize the font size for each damage type.",
                args = fontSizeArgs,
                order = 16,
            },
            animationStyle = {
                name = "Animation Style",
                type = "select",
                desc = "Choose how the combat text animates.",
                values = {
                    off = "Off (Normal)",
                    fade = "Fade",
                    bounce = "Bounce",
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
                },
                get = function() return db.profile.animationStyle end,
                set = function(_, value) db.profile.animationStyle = value end,
                order = 17,
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
                order = 18,
            },
            tuning = {
                name = "Animation Tuning",
                type = "group",
                inline = true,
                order = 19,
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
                        desc = "How far the Left → Right and Right → Left animations travel from the nameplate, in pixels.",
                        get = function() return db.profile.animationHorizontalDistance end,
                        set = function(_, v) db.profile.animationHorizontalDistance = v end,
                        order = 4,
                    },
                    horizontalStagger = {
                        name = "Horizontal Stagger",
                        type = "range",
                        min = 0, max = 60, step = 1,
                        desc = "Spacing in pixels between simultaneous left and right texts on the same nameplate so they do not overlap.",
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
    db = AceDB:New("CombatTextPlusDB", savedVariables)
    self.db = db

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
        elseif event == "PLAYER_ENTER_COMBAT" then
            MarkTargetEngaged()
        elseif event == "PLAYER_TARGET_CHANGED" then
            if IsAutoAttacking() then
                MarkTargetEngaged()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            wipe(engagedPlates)
        elseif event == "PLAYER_ENTERING_WORLD" then
            RebuildPlates()
        end
    end)

    self:ApplySettings()
end
