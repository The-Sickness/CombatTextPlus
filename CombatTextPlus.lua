-- Made by Sharpedge_Gaming
-- v2.2 - 11.2

local addonName = "CombatTextPlus"

local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LDB = LibStub("LibDataBroker-1.1") 
local icon = LibStub("LibDBIcon-1.0") 

local CombatTextPlus = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local savedVariables = {
    profile = {
        font = "Friz Quadrata TT",  -- Default font
        textColor = {r = 1, g = 1, b = 1, a = 1},  -- White text by default
        fontSize = 24,
        labelFontSize = 14,
        enabled = true,
        scrollDuration = 0.5,
		animationStyle = "fade", -- default
        animationEasing = "linear", -- default
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
        dotYOffsetMultiplier = 1.0, -- Default to 1.0 for clarity
        damageTypeFontSizes = {
            physical = 24, holy = 24, fire = 24, nature = 24,
            frost = 24, shadow = 24, arcane = 24, chaos = 24,
            dot = 24, heal = 24, crit = 24,
        }
    }
}

local frame = CreateFrame("Frame", "CombatTextPlusFrame", UIParent)
frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.text:SetPoint("CENTER", frame, "CENTER")

local db
local inCombat = false
local activeCombatTexts = {}
local damageTypeLastYPositions = {
    physical = {}, holy = {}, fire = {}, nature = {},
    frost = {}, shadow = {}, arcane = {}, chaos = {}, dot = {},
    heal = {}, crit = {}
}

local damageAggregation = {}
local aggregationDelay = .05

local function DisableBlizzardCombatText()
    SetCVar("floatingCombatTextCombatDamage", 0)
    CombatTextPlus:Print("Blizzard combat text for damage has been disabled.")
end

local CombatTextPlusLDB = LDB:NewDataObject("CombatTextPlus", {
    type = "launcher",
    text = "CombatTextPlus",
    icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    OnClick = function(self, button)
        if button == "LeftButton" then
            if Settings and Settings.OpenToCategory then
                Settings.OpenToCategory("CombatTextPlus")
            else
                InterfaceOptionsFrame_OpenToCategory("CombatTextPlus")
                InterfaceOptionsFrame_OpenToCategory("CombatTextPlus")
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("|cFF00FF00CombatTextPlus|r")
        tooltip:AddLine("|cFFFFFFFFLeft-click to open settings.|r")
    end,
})

function CombatTextPlus:ShowPreviewCombatText()
    local previewTypes = {"physical", "fire", "heal", "crit"}
    local previewValues = {
        physical = 1234,
        fire = 5678,
        heal = 3456,
        crit = 9999,
    }
    local previewLabels = {
        physical = "Physical",
        fire = "Fire",
        heal = "Heal",
        crit = "Crit",
    }
    
    local anchor = nil
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        anchor = nameplate
        break
    end
    if not anchor then
        anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(1, 1)
        anchor:SetPoint("CENTER", UIParent, "CENTER", -600, 0) 
    end

    for i, damageType in ipairs(previewTypes) do
        C_Timer.After((i-1)*0.25, function()
            CombatTextPlus:DisplayCombatText(
                anchor, 
                previewValues[damageType], 
                damageType, 
                nil, 
                previewLabels[damageType], 
                damageType=="crit"
            )
        end)
    end
end

function CombatTextPlus:GetEasedProgress(progress)
    local easing = db.profile.animationEasing
    if easing == "linear" then
        return progress
    elseif easing == "quadratic" then
        return progress * progress
    elseif easing == "exponential" then
        return progress ^ 3
    end
    return progress
end

function CombatTextPlus:ApplyAnimationStyle(frame, nameplate, damageType, progress, index)
    local function ClampAlpha(a)
        return math.max(0, math.min(1, a or 0))
    end

    local style = db.profile.animationStyle
    local eased = self:GetEasedProgress(progress)
    if style == "fade" then
        local xOffset, yOffset = self:GetMovementOffsets(nameplate, damageType, eased, index)
        frame:SetPoint("CENTER", nameplate, "BOTTOM", xOffset, yOffset)
        frame:SetAlpha(ClampAlpha(1 - eased))
	elseif style == "off" then
        local xOffset, yOffset = self:GetMovementOffsets(nameplate, damageType, eased, index)
        frame:SetPoint("CENTER", nameplate, "BOTTOM", xOffset, yOffset)
        frame:SetAlpha(ClampAlpha(1 - eased))
        frame:SetScale(1)	
    elseif style == "bounce" then
        local xOffset, yOffset = self:GetMovementOffsets(nameplate, damageType, eased, index)
        local bounce = math.abs(math.sin(eased * math.pi * 3) * (1 - eased) * 100)
        yOffset = yOffset + bounce
        frame:SetPoint("CENTER", nameplate, "BOTTOM", xOffset, yOffset)
        frame:SetAlpha(ClampAlpha(1 - eased))
    elseif style == "shake" then
        local xOffset, yOffset = self:GetMovementOffsets(nameplate, damageType, eased, index)
        xOffset = xOffset + math.sin(eased * 30) * 25
        frame:SetPoint("CENTER", nameplate, "BOTTOM", xOffset, yOffset)
        frame:SetAlpha(ClampAlpha(1 - eased))
    elseif style == "spiral" then
        local angle = eased * 8 * math.pi
        local radius = 80 * eased
        local xOffset = math.cos(angle) * radius
        local yOffset = math.sin(angle) * radius + (db.profile.maxYOffset * eased * db.profile.speedFactor)
        frame:SetPoint("CENTER", nameplate, "BOTTOM", xOffset, yOffset)
        frame:SetAlpha(ClampAlpha(1 - eased))
    elseif style == "scale" then
        local xOffset, yOffset = self:GetMovementOffsets(nameplate, damageType, eased, index)
        local scale = 1 + eased * 2
        frame:SetPoint("CENTER", nameplate, "BOTTOM", xOffset, yOffset)
        frame:SetAlpha(ClampAlpha(1 - eased))
        frame:SetScale(scale)
    elseif style == "pop" then
        local xOffset, yOffset = self:GetMovementOffsets(nameplate, damageType, eased, index)
        local popScale
        if eased < 0.2 then
            popScale = 1 + eased * 4
        else
            popScale = 1.8 - (eased - 0.2) * 2
        end
        frame:SetPoint("CENTER", nameplate, "BOTTOM", xOffset, yOffset)
        frame:SetAlpha(ClampAlpha(1 - eased))
        frame:SetScale(popScale)
    else
        local xOffset, yOffset = self:GetMovementOffsets(nameplate, damageType, eased, index)
        frame:SetPoint("CENTER", nameplate, "BOTTOM", xOffset, yOffset)
        frame:SetAlpha(ClampAlpha(1 - eased))
    end
end

function CombatTextPlus:OnInitialize()
    db = LibStub("AceDB-3.0"):New("CombatTextPlusDB", savedVariables, true)
    self.db = db
    self:SetupProfileOptions()
    db:SetProfile(UnitName("player") .. " - " .. GetRealmName())
    icon:Register("CombatTextPlus", CombatTextPlusLDB, db.profile.minimap)
    local fontPath = LSM:Fetch("font", db.profile.font)
    frame.text:SetFont(fontPath, db.profile.fontSize, "OUTLINE")
    frame.text:SetTextColor(db.profile.textColor.r, db.profile.textColor.g, db.profile.textColor.b, db.profile.textColor.a)
    self:ToggleEnabled(db.profile.enabled)
    DisableBlizzardCombatText()
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            CombatTextPlus:OnCombatLogEvent(CombatLogGetCurrentEventInfo())
        elseif event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
            for _, combatTextFrame in pairs(activeCombatTexts) do
                combatTextFrame:Hide()
                combatTextFrame:SetScript("OnUpdate", nil)
            end
            activeCombatTexts = {}
            for k in pairs(damageTypeLastYPositions) do
                damageTypeLastYPositions[k] = {}
            end
        end
    end)
end

function CombatTextPlus:OnCombatLogEvent(...)
    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, spellName, school, amount = ...
    local isCritical = select(21, ...)

    if not db.profile.enabled then return end

    -- Handle damage events
    if subEvent == "SPELL_DAMAGE" or subEvent == "SWING_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        if sourceGUID == UnitGUID("player") and amount and amount > 0 then
            local damageType = self:GetDamageType(school, subEvent)
            local keyCrit = isCritical and "crit" or damageType
            if db.profile.damageTypeFilters[keyCrit] then
                local key = destGUID .. "-" .. spellId .. "-" .. keyCrit
                if not damageAggregation[key] then
                    damageAggregation[key] = { amount = 0, timer = nil }
                end
                damageAggregation[key].amount = damageAggregation[key].amount + amount
                if not damageAggregation[key].timer then
                    damageAggregation[key].timer = C_Timer.NewTimer(aggregationDelay, function()
                        for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
                            if UnitGUID(nameplate.UnitFrame.unit) == destGUID then
                                self:DisplayCombatText(nameplate, damageAggregation[key].amount, keyCrit, spellId, spellName, isCritical)
                            end
                        end
                        damageAggregation[key] = nil
                    end)
                end
            end
        end
    end

    -- Handle healing events
    if subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
        local isCriticalHeal = select(21, ...)
        if sourceGUID == UnitGUID("player") and amount and amount > 0 then
            if db.profile.damageTypeFilters.heal then
                for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
                    if UnitGUID(nameplate.UnitFrame.unit) == destGUID then
                        self:DisplayCombatText(nameplate, amount, "heal", spellId, spellName, isCriticalHeal)
                    end
                end
            end
        end
    end
end

function CombatTextPlus:SetupProfileOptions()
    self.options = self.options or {
        name = "CombatTextPlus",
        type = "group",
        args = {}
    }

    local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    AceConfig:RegisterOptionsTable("CombatTextPlus_Profiles", profiles)
    AceConfigDialog:AddToBlizOptions("CombatTextPlus_Profiles", "Profiles", "CombatTextPlus")

    self.options.args.profile = {
        name = "Profile",
        type = "group",
        args = {
            currentProfile = {
                name = "Current Profile",
                type = "select",
                desc = "Select which profile to use.",
                values = function() return self.db:GetProfiles() end,
                get = function() return self.db:GetCurrentProfile() end,
                set = function(_, value)
                    self.db:SetProfile(value)
                    CombatTextPlus:Print("Switched to profile: " .. value)
                    self:ApplySettings()
                end,
                order = 1
            },
            deleteProfile = {
                name = "Delete Profile",
                type = "execute",
                desc = "Delete the current profile.",
                confirm = true,
                confirmText = "Are you sure you want to delete this profile?",
                func = function()
                    local currentProfile = self.db:GetCurrentProfile()
                    self.db:DeleteProfile(currentProfile)
                    CombatTextPlus:Print("Deleted profile: " .. currentProfile)
                end,
                order = 2
            },
            copyProfile = {
                name = "Copy From",
                type = "select",
                desc = "Copy settings from another profile.",
                values = function() return self.db:GetProfiles() end,
                set = function(_, value)
                    self.db:CopyProfile(value)
                    CombatTextPlus:Print("Copied profile: " .. value)
                    self:ApplySettings()
                end,
                order = 3
            }
        }
    }
end

function CombatTextPlus:ApplySettings()
    local fontPath = LSM:Fetch("font", db.profile.font or "Friz Quadrata TT")
    frame.text:SetFont(fontPath, db.profile.fontSize, "OUTLINE")
    frame.text:SetTextColor(db.profile.textColor.r, db.profile.textColor.g, db.profile.textColor.b, db.profile.textColor.a)
    icon:Register("CombatTextPlus", CombatTextPlusLDB, db.profile.minimap)
    for _, combatTextFrame in pairs(activeCombatTexts) do
        local damageType = combatTextFrame.damageType or "physical"
        local fontSize = db.profile.damageTypeFontSizes[damageType] or db.profile.fontSize
        combatTextFrame.text:SetFont(fontPath, fontSize, "OUTLINE")
        combatTextFrame.text:SetTextColor(db.profile.textColor.r, db.profile.textColor.g, db.profile.textColor.b, db.profile.textColor.a)
        combatTextFrame.label:SetFont(fontPath, db.profile.labelFontSize, "OUTLINE")
    end
    self:ToggleEnabled(db.profile.enabled)
    DisableBlizzardCombatText()
end

function CombatTextPlus:ToggleEnabled(value)
    if value then
        frame:Show()
    else
        frame:Hide()
    end
end

function CombatTextPlus:DisplayCombatText(nameplate, amount, damageType, spellId, spellName, isCritical)
    local formattedAmount = self:FormatNumber(amount)
    if not formattedAmount then return end

    -- Frame management: one combat text per nameplate per damageType
    local frameKey = tostring(nameplate) .. "-" .. damageType
    local combatTextFrame = activeCombatTexts[frameKey]
    if not combatTextFrame then
        combatTextFrame = self:CreateCombatTextFrame(nameplate, damageType)
        activeCombatTexts[frameKey] = combatTextFrame
    end

    -- Font size
    local fontSize = db.profile.damageTypeFontSizes[damageType] or db.profile.fontSize
    combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), fontSize, "OUTLINE")

    -- Color and label
    local label = self:GetDamageTypeLabel(damageType)
    local labelColorR, labelColorG, labelColorB = self:GetLabelColor(damageType)
    local damageColorR, damageColorG, damageColorB = self:GetDamageTypeColor(damageType)
    if isCritical and damageType == "crit" then
        label = "Crit"
        labelColorR, labelColorG, labelColorB = self:GetLabelColor("crit")
        damageColorR, damageColorG, damageColorB = self:GetDamageTypeColor("crit")
    end

    if combatTextFrame.label then
        combatTextFrame.label:SetTextColor(labelColorR, labelColorG, labelColorB)
        combatTextFrame.label:SetText(label)
    end
    combatTextFrame.text:SetTextColor(damageColorR, damageColorG, damageColorB)
    combatTextFrame.text:SetText(formattedAmount)
    combatTextFrame:SetAlpha(1)
    combatTextFrame:Show()

    -- Scrolling behavior
    local startTime = GetTime()
    local index = #damageTypeLastYPositions[damageType] + 1
    table.insert(damageTypeLastYPositions[damageType], index)
    combatTextFrame:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local progress = (now - startTime) / (db.profile.scrollDuration / db.profile.speedFactor * 10)
        if progress >= 1 then
            self:Hide()
            self:SetScript("OnUpdate", nil)
            table.remove(damageTypeLastYPositions[damageType], index)
            activeCombatTexts[frameKey] = nil
            self:SetScale(1) -- reset scale if used
        else
            CombatTextPlus:ApplyAnimationStyle(self, nameplate, damageType, progress, index)
        end
    end)
end

function CombatTextPlus:GetDamageType(school, subEvent)
    if subEvent == "SPELL_PERIODIC_DAMAGE" then
        return "dot"
    end
    if subEvent == "SWING_DAMAGE" or school == 1 then
        return "physical"
    elseif school == 2 then
        return "holy"
    elseif school == 4 then
        return "fire"
    elseif school == 8 then
        return "nature"
    elseif school == 16 then
        return "frost"
    elseif school == 32 then
        return "shadow"
    elseif school == 64 then
        return "arcane"
    elseif school == 124 then
        return "chaos"
    else
        return "physical"
    end
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
    local map = {
        physical = "Physical", holy = "Holy", fire = "Fire", nature = "Nature",
        frost = "Frost", shadow = "Shadow", arcane = "Arcane", chaos = "Chaos",
        dot = "DOT", heal = "Heal", crit = "Crit"
    }
    return map[damageType] or ""
end

function CombatTextPlus:CreateCombatTextFrame(nameplate, damageType)
    local combatTextFrame = CreateFrame("Frame", nil, nameplate)
	combatTextFrame.damageType = damageType 
    combatTextFrame:SetSize(200, 50)
    combatTextFrame:SetPoint("CENTER", nameplate, "TOP", 0, 10)
    local fontPath = LSM:Fetch("font", db.profile.font)
    combatTextFrame.text = combatTextFrame:CreateFontString(nil, "OVERLAY")
    combatTextFrame.text:SetFont(fontPath, db.profile.fontSize, "OUTLINE")
    combatTextFrame.text:SetPoint("CENTER", combatTextFrame, "CENTER")
    combatTextFrame.label = combatTextFrame:CreateFontString(nil, "OVERLAY")
    combatTextFrame.label:SetFont(fontPath, db.profile.labelFontSize, "OUTLINE")
    combatTextFrame.label:SetPoint("LEFT", combatTextFrame.text, "RIGHT", 5, 0)
    return combatTextFrame
end

function CombatTextPlus:UpdateLabelFontSize()
    local fontPath = LSM:Fetch("font", db.profile.font)
    for _, combatTextFrame in pairs(activeCombatTexts) do
        if combatTextFrame.label then
            combatTextFrame.label:SetFont(fontPath, db.profile.labelFontSize, "OUTLINE")
        end
    end
end

function CombatTextPlus:GetMovementOffsets(nameplate, damageType, progress, index)
    local xOffset = (db.profile.damageTypeOffsets[damageType] or 0) * progress
    local startingYOffset = 0
    local maxYOffset = db.profile.maxYOffset or 100
    local yOffset = startingYOffset + (maxYOffset * progress * db.profile.speedFactor)

    if damageType == "dot" then
        local dotMultiplier = db.profile.dotYOffsetMultiplier or 1.0
        yOffset = yOffset * dotMultiplier
    elseif damageType == "heal" then
        yOffset = startingYOffset + (maxYOffset * progress * db.profile.speedFactor)
    end

    return xOffset, yOffset
end

function CombatTextPlus:FormatNumber(amount)
    if not amount or amount == "" then return nil end
    local formatted = tostring(amount)
    -- Add thousands separators
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local options = {
    name = "CombatTextPlus",
    type = 'group',
    args = {
        enabled = {
            name = "Enabled",
            type = "toggle",
            desc = "Enable or disable the combat text",
            get = function()
                return db.profile.enabled
            end,
            set = function(info, value)
                db.profile.enabled = value
                CombatTextPlus:ToggleEnabled(value)
            end,
            order = 1,
        },
        scrollDuration = {
            name = "Scroll Duration",
            type = "range",
            desc = "Set the duration of the scroll animation.",
            min = 0.1,
            max = 3.0,
            step = 0.1,
            get = function() return db.profile.scrollDuration end,
            set = function(info, value) db.profile.scrollDuration = value end,
            order = 2,
        },
        maxYOffset = {
            name = "Max Y Offset",
            type = "range",
            desc = "Set the maximum vertical offset for the text to scroll upwards.",
            min = 50,
            max = 300,
            step = 10,
            get = function() return db.profile.maxYOffset end,
            set = function(info, value) db.profile.maxYOffset = value end,
            order = 3,
        },
        speedFactor = {
            name = "Speed Factor",
            type = "range",
            desc = "Set the speed of the text movement.",
            min = 0.5,
            max = 5.0,
            step = 0.1,
            get = function() return db.profile.speedFactor end,
            set = function(info, value) db.profile.speedFactor = value end,
            order = 4,
        },
        damageTypeOffsets = {
            name = "Damage Type Offsets",
            type = "group",
            inline = true,
            desc = "Customize the horizontal movement of text based on damage type.",
            args = {
                physical = { name = "Physical Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for Physical damage.", get = function() return db.profile.damageTypeOffsets.physical end, set = function(info, value) db.profile.damageTypeOffsets.physical = value end, order = 1 },
                holy = { name = "Holy Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for Holy damage.", get = function() return db.profile.damageTypeOffsets.holy end, set = function(info, value) db.profile.damageTypeOffsets.holy = value end, order = 2 },
                fire = { name = "Fire Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for Fire damage.", get = function() return db.profile.damageTypeOffsets.fire end, set = function(info, value) db.profile.damageTypeOffsets.fire = value end, order = 3 },
                nature = { name = "Nature Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for Nature damage.", get = function() return db.profile.damageTypeOffsets.nature end, set = function(info, value) db.profile.damageTypeOffsets.nature = value end, order = 4 },
                frost = { name = "Frost Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for Frost damage.", get = function() return db.profile.damageTypeOffsets.frost end, set = function(info, value) db.profile.damageTypeOffsets.frost = value end, order = 5 },
                shadow = { name = "Shadow Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for Shadow damage.", get = function() return db.profile.damageTypeOffsets.shadow end, set = function(info, value) db.profile.damageTypeOffsets.shadow = value end, order = 6 },
                arcane = { name = "Arcane Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for Arcane damage.", get = function() return db.profile.damageTypeOffsets.arcane end, set = function(info, value) db.profile.damageTypeOffsets.arcane = value end, order = 7 },
                chaos = { name = "Chaos Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for Chaos damage.", get = function() return db.profile.damageTypeOffsets.chaos end, set = function(info, value) db.profile.damageTypeOffsets.chaos = value end, order = 8 },
                dot = { name = "DOT Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for DOT effects.", get = function() return db.profile.damageTypeOffsets.dot end, set = function(info, value) db.profile.damageTypeOffsets.dot = value end, order = 9 },
                heal = { name = "Heal Offset", type = "range", min = -50, max = 50, step = 1, desc = "Adjust the horizontal movement of the combat text for Healing.", get = function() return db.profile.damageTypeOffsets.heal end, set = function(info, value) db.profile.damageTypeOffsets.heal = value end, order = 10 },
            },
            order = 5,
        },
        dotYOffsetMultiplier = {
            name = "DOT Y Offset Multiplier",
            type = "range",
            desc = "Adjust the vertical movement of DOT text.",
            min = 0.1,
            max = 2.0,
            step = 0.1,
            get = function() return db.profile.dotYOffsetMultiplier end,
            set = function(info, value) db.profile.dotYOffsetMultiplier = value end,
            order = 6,
        },
        fontSize = {
            name = "Font Size",
            type = "range",
            desc = "Set the font size of the combat text.",
            min = 8,
            max = 32,
            step = 1,
            get = function() return db.profile.fontSize end,
            set = function(info, value)
                db.profile.fontSize = value
                for k,_ in pairs(db.profile.damageTypeFontSizes) do
                    db.profile.damageTypeFontSizes[k] = value
                end
                for _, combatTextFrame in pairs(activeCombatTexts) do
                    local damageType = combatTextFrame.damageType or "physical"
                    combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                end
            end,
            order = 7,
        },
        labelFontSize = {
            name = "Label Font Size",
            type = "range",
            desc = "Set the font size of the damage type label (e.g., Physical, Fire, Shadow, DOT).",
            min = 8,
            max = 32,
            step = 1,
            get = function() return db.profile.labelFontSize end,
            set = function(info, value)
                db.profile.labelFontSize = value
                CombatTextPlus:UpdateLabelFontSize()
            end,
            order = 8,
        },
        font = {
            name = "Font",
            type = "select",
            desc = "Set the font of the combat text.",
            values = LSM:HashTable("font"),
            dialogControl = "LSM30_Font",
            get = function() return db.profile.font end,
            set = function(info, value)
                db.profile.font = value
                for _, combatTextFrame in pairs(activeCombatTexts) do
                    local damageType = combatTextFrame.damageType or "physical"
                    local fontSize = db.profile.damageTypeFontSizes[damageType] or db.profile.fontSize
                    combatTextFrame.text:SetFont(LSM:Fetch("font", value), fontSize, "OUTLINE")
                end
            end,
            order = 9,
        },
        labelColors = {
            name = "Label Colors",
            type = "group",
            inline = true,
            desc = "Customize the color of the labels that appear next to each type of damage.",
            args = {
                physicalLabelColor = {
                    name = "Physical Label Color",
                    type = "color",
                    desc = "Set the color of the 'Physical' damage label.",
                    get = function() local color = db.profile.labelColors.physical; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.physical; color.r, color.g, color.b = r, g, b end,
                    order = 1,
                },
                holyLabelColor = {
                    name = "Holy Label Color",
                    type = "color",
                    desc = "Set the color of the 'Holy' damage label.",
                    get = function() local color = db.profile.labelColors.holy; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.holy; color.r, color.g, color.b = r, g, b end,
                    order = 2,
                },
                fireLabelColor = {
                    name = "Fire Label Color",
                    type = "color",
                    desc = "Set the color of the 'Fire' damage label.",
                    get = function() local color = db.profile.labelColors.fire; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.fire; color.r, color.g, color.b = r, g, b end,
                    order = 3,
                },
                natureLabelColor = {
                    name = "Nature Label Color",
                    type = "color",
                    desc = "Set the color of the 'Nature' damage label.",
                    get = function() local color = db.profile.labelColors.nature; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.nature; color.r, color.g, color.b = r, g, b end,
                    order = 4,
                },
                frostLabelColor = {
                    name = "Frost Label Color",
                    type = "color",
                    desc = "Set the color of the 'Frost' damage label.",
                    get = function() local color = db.profile.labelColors.frost; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.frost; color.r, color.g, color.b = r, g, b end,
                    order = 5,
                },
                shadowLabelColor = {
                    name = "Shadow Label Color",
                    type = "color",
                    desc = "Set the color of the 'Shadow' damage label.",
                    get = function() local color = db.profile.labelColors.shadow; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.shadow; color.r, color.g, color.b = r, g, b end,
                    order = 6,
                },
                arcaneLabelColor = {
                    name = "Arcane Label Color",
                    type = "color",
                    desc = "Set the color of the 'Arcane' damage label.",
                    get = function() local color = db.profile.labelColors.arcane; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.arcane; color.r, color.g, color.b = r, g, b end,
                    order = 7,
                },
                chaosLabelColor = {
                    name = "Chaos Label Color",
                    type = "color",
                    desc = "Set the color of the 'Chaos' damage label.",
                    get = function() local color = db.profile.labelColors.chaos; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.chaos; color.r, color.g, color.b = r, g, b end,
                    order = 8,
                },
                dotLabelColor = {
                    name = "DOT Label Color",
                    type = "color",
                    desc = "Set the color of the 'DOT' label.",
                    get = function() local color = db.profile.labelColors.dot; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.dot; color.r, color.g, color.b = r, g, b end,
                    order = 9,
                },
                healLabelColor = {
                    name = "Heal Label Color",
                    type = "color",
                    desc = "Set the color of the 'Heal' label.",
                    get = function() local color = db.profile.labelColors.heal; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.heal; color.r, color.g, color.b = r, g, b end,
                    order = 10,
                },
                critLabelColor = {
                    name = "Crit Label Color",
                    type = "color",
                    desc = "Set the color for Critical hit label.",
                    get = function() local color = db.profile.labelColors.crit; return color.r, color.g, color.b end,
                    set = function(info, r, g, b) local color = db.profile.labelColors.crit; color.r, color.g, color.b = r, g, b end,
                    order = 11,
                },
            },
            order = 10,
        },
        damageTypeFilters = {
            name = "Damage Type Filters",
            type = "group",
            inline = true,
            desc = "Select which types of damage you want to see displayed during combat.",
            args = {
                physical = { name = "Physical Damage", type = "toggle", desc = "Enable or disable the display of Physical damage.", get = function() return db.profile.damageTypeFilters.physical end, set = function(info, value) db.profile.damageTypeFilters.physical = value end, order = 1 },
                holy = { name = "Holy Damage", type = "toggle", desc = "Enable or disable the display of Holy damage.", get = function() return db.profile.damageTypeFilters.holy end, set = function(info, value) db.profile.damageTypeFilters.holy = value end, order = 2 },
                fire = { name = "Fire Damage", type = "toggle", desc = "Enable or disable the display of Fire damage.", get = function() return db.profile.damageTypeFilters.fire end, set = function(info, value) db.profile.damageTypeFilters.fire = value end, order = 3 },
                nature = { name = "Nature Damage", type = "toggle", desc = "Enable or disable the display of Nature damage.", get = function() return db.profile.damageTypeFilters.nature end, set = function(info, value) db.profile.damageTypeFilters.nature = value end, order = 4 },
                frost = { name = "Frost Damage", type = "toggle", desc = "Enable or disable the display of Frost damage.", get = function() return db.profile.damageTypeFilters.frost end, set = function(info, value) db.profile.damageTypeFilters.frost = value end, order = 5 },
                shadow = { name = "Shadow Damage", type = "toggle", desc = "Enable or disable the display of Shadow damage.", get = function() return db.profile.damageTypeFilters.shadow end, set = function(info, value) db.profile.damageTypeFilters.shadow = value end, order = 6 },
                arcane = { name = "Arcane Damage", type = "toggle", desc = "Enable or disable the display of Arcane damage.", get = function() return db.profile.damageTypeFilters.arcane end, set = function(info, value) db.profile.damageTypeFilters.arcane = value end, order = 7 },
                chaos = { name = "Chaos Damage", type = "toggle", desc = "Enable or disable the display of Chaos damage.", get = function() return db.profile.damageTypeFilters.chaos end, set = function(info, value) db.profile.damageTypeFilters.chaos = value end, order = 8 },
                dot = { name = "DOT Damage", type = "toggle", desc = "Enable or disable the display of DOT damage.", get = function() return db.profile.damageTypeFilters.dot end, set = function(info, value) db.profile.damageTypeFilters.dot = value end, order = 9 },
                heal = { name = "Healing", type = "toggle", desc = "Enable or disable the display of Healing.", get = function() return db.profile.damageTypeFilters.heal end, set = function(info, value) db.profile.damageTypeFilters.heal = value end, order = 10 },
                crit = { name = "Critical Hits", type = "toggle", desc = "Enable or disable the display of Critical hits.", get = function() return db.profile.damageTypeFilters.crit end, set = function(info, value) db.profile.damageTypeFilters.crit = value end, order = 11 },
            },
            order = 11,
        },
        damageTypeColors = {
            name = "Damage Type Colors",
            type = "group",
            inline = true,
            desc = "Customize the color of the combat text for each damage type.",
            args = {
                physicalColor = { name = "Physical Damage Color", type = "color", desc = "Set the color for Physical damage.", get = function() local color = db.profile.damageTypeColors.physical; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.physical; color.r, color.g, color.b = r, g, b end, order = 1 },
                holyColor = { name = "Holy Damage Color", type = "color", desc = "Set the color for Holy damage.", get = function() local color = db.profile.damageTypeColors.holy; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.holy; color.r, color.g, color.b = r, g, b end, order = 2 },
                fireColor = { name = "Fire Damage Color", type = "color", desc = "Set the color for Fire damage.", get = function() local color = db.profile.damageTypeColors.fire; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.fire; color.r, color.g, color.b = r, g, b end, order = 3 },
                natureColor = { name = "Nature Damage Color", type = "color", desc = "Set the color for Nature damage.", get = function() local color = db.profile.damageTypeColors.nature; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.nature; color.r, color.g, color.b = r, g, b end, order = 4 },
                frostColor = { name = "Frost Damage Color", type = "color", desc = "Set the color for Frost damage.", get = function() local color = db.profile.damageTypeColors.frost; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.frost; color.r, color.g, color.b = r, g, b end, order = 5 },
                shadowColor = { name = "Shadow Damage Color", type = "color", desc = "Set the color for Shadow damage.", get = function() local color = db.profile.damageTypeColors.shadow; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.shadow; color.r, color.g, color.b = r, g, b end, order = 6 },
                arcaneColor = { name = "Arcane Damage Color", type = "color", desc = "Set the color for Arcane damage.", get = function() local color = db.profile.damageTypeColors.arcane; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.arcane; color.r, color.g, color.b = r, g, b end, order = 7 },
                chaosColor = { name = "Chaos Damage Color", type = "color", desc = "Set the color for Chaos damage.", get = function() local color = db.profile.damageTypeColors.chaos; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.chaos; color.r, color.g, color.b = r, g, b end, order = 8 },
                dotColor = { name = "DOT Damage Color", type = "color", desc = "Set the color for DOT effects.", get = function() local color = db.profile.damageTypeColors.dot; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.dot; color.r, color.g, color.b = r, g, b end, order = 9 },
                healColor = { name = "Healing Color", type = "color", desc = "Set the color for Healing effects.", get = function() local color = db.profile.damageTypeColors.heal; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.heal; color.r, color.g, color.b = r, g, b end, order = 10 },
                critColor = { name = "Crit Damage Color", type = "color", desc = "Set the color for Critical hit text.", get = function() local color = db.profile.damageTypeColors.crit; return color.r, color.g, color.b end, set = function(info, r, g, b) local color = db.profile.damageTypeColors.crit; color.r, color.g, color.b = r, g, b end, order = 11 },
            },
            order = 12,
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
            order = 13,
        },
        damageTypeFontSizes = {
            name = "Damage Type Font Sizes",
            type = "group",
            inline = true,
            desc = "Customize the font size for each damage type.",
            args = {
                physicalFontSize = {
                    name = "Physical Damage Font Size",
                    type = "range",
                    desc = "Set the font size for Physical damage.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.physical end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.physical = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "physical" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 1,
                },
                holyFontSize = {
                    name = "Holy Damage Font Size",
                    type = "range",
                    desc = "Set the font size for Holy damage.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.holy end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.holy = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "holy" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 2,
                },
                fireFontSize = {
                    name = "Fire Damage Font Size",
                    type = "range",
                    desc = "Set the font size for Fire damage.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.fire end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.fire = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "fire" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 3,
                },
                natureFontSize = {
                    name = "Nature Damage Font Size",
                    type = "range",
                    desc = "Set the font size for Nature damage.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.nature end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.nature = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "nature" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 4,
                },
                frostFontSize = {
                    name = "Frost Damage Font Size",
                    type = "range",
                    desc = "Set the font size for Frost damage.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.frost end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.frost = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "frost" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 5,
                },
                shadowFontSize = {
                    name = "Shadow Damage Font Size",
                    type = "range",
                    desc = "Set the font size for Shadow damage.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.shadow end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.shadow = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "shadow" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 6,
                },
                arcaneFontSize = {
                    name = "Arcane Damage Font Size",
                    type = "range",
                    desc = "Set the font size for Arcane damage.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.arcane end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.arcane = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "arcane" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 7,
                },
                chaosFontSize = {
                    name = "Chaos Damage Font Size",
                    type = "range",
                    desc = "Set the font size for Chaos damage.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.chaos end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.chaos = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "chaos" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 8,
                },
                dotFontSize = {
                    name = "DOT Damage Font Size",
                    type = "range",
                    desc = "Set the font size for DOT effects.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.dot end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.dot = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "dot" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 9,
                },
                healFontSize = {
                    name = "Healing Font Size",
                    type = "range",
                    desc = "Set the font size for Healing effects.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.heal end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.heal = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "heal" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 10,
                },
                critFontSize = {
                    name = "Crit Damage Font Size",
                    type = "range",
                    desc = "Set the font size for Critical hit text.",
                    min = 6,
                    max = 36,
                    step = 1,
                    get = function() return db.profile.damageTypeFontSizes.crit end,
                    set = function(info, value)
                        db.profile.damageTypeFontSizes.crit = value
                        for _, combatTextFrame in pairs(activeCombatTexts) do
                            if combatTextFrame.damageType == "crit" then
                                combatTextFrame.text:SetFont(LSM:Fetch("font", db.profile.font), value, "OUTLINE")
                            end
                        end
                    end,
                    order = 11,
                },
            },
            order = 14,
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
            },
            get = function() return db.profile.animationStyle end,
            set = function(_, value) db.profile.animationStyle = value end,
            order = 15,
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
            order = 16,
        },
        preview = {
            name = "Preview Combat Text",
            type = "execute",
            desc = "Show sample combat text using current settings.",
            func = function()
                CombatTextPlus:ShowPreviewCombatText()
            end,
            order = 17,
        },
    },
}

AceConfig:RegisterOptionsTable("CombatTextPlus", options)
AceConfigDialog:AddToBlizOptions("CombatTextPlus", "CombatTextPlus")