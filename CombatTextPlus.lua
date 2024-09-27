-- Made by Sharpedge_Gaming
-- v1.8 - 11.0.2

local addonName = "CombatTextPlus"

local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LDB = LibStub("LibDataBroker-1.1") 
local icon = LibStub("LibDBIcon-1.0") 

local CombatTextPlus = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

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

local savedVariables = {
    profile = {
        font = "Friz Quadrata TT",  -- Default font
        textColor = {r = 1, g = 1, b = 1, a = 1},  -- White text by default
        fontSize = 24,
        labelFontSize = 14,
        enabled = true,
        scrollDuration = 0.5,
        maxYOffset = 100,
        speedFactor = 2.0,
        damageTypeOffsets = {
            physical = -10,
            holy = 10,
            fire = 0,
            nature = -15,
            frost = 15,
            shadow = 0,
            arcane = 0,
            chaos = 0,
            dot = 10,
            heal = 0,  -- Healing offset
        },
        damageTypeFilters = {
            physical = true,
            holy = true,
            fire = true,
            nature = true,
            frost = true,
            shadow = true,
            arcane = true,
            chaos = true,
            dot = true,
            heal = true,  -- Enable healing filter by default
        },
        damageTypeColors = {
            physical = {r = 1, g = 1, b = 1},  -- Default to white
            holy = {r = 1, g = 1, b = 1},      -- White by default
            fire = {r = 1, g = 1, b = 1},      -- White by default
            nature = {r = 1, g = 1, b = 1},    -- White by default
            frost = {r = 1, g = 1, b = 1},     -- White by default
            shadow = {r = 1, g = 1, b = 1},    -- White by default
            arcane = {r = 1, g = 1, b = 1},    -- White by default
            chaos = {r = 1, g = 1, b = 1},     -- White by default
            dot = {r = 1, g = 1, b = 1},       -- White by default
            heal = {r = 1, g = 1, b = 1},      -- White by default for healing
        },
        labelColors = {
            physical = {r = 1, g = 1, b = 1},  -- Label colors set to white
            holy = {r = 1, g = 1, b = 1},
            fire = {r = 1, g = 1, b = 1},
            nature = {r = 1, g = 1, b = 1},
            frost = {r = 1, g = 1, b = 1},
            shadow = {r = 1, g = 1, b = 1},
            arcane = {r = 1, g = 1, b = 1},
            chaos = {r = 1, g = 1, b = 1},
            dot = {r = 1, g = 1, b = 1},
            heal = {r = 1, g = 1, b = 1},      -- Healing label white by default
        },
        minimap = { hide = false }, 
        dotYOffsetMultiplier = 1.0  -- Default value to avoid nil
    }
}

local frame = CreateFrame("Frame", "CombatTextPlusFrame", UIParent)
frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.text:SetPoint("CENTER", frame, "CENTER")

local db
local inCombat = false
local activeCombatTexts = {}
local scrollDuration = 1.0  
local damageTypeLastYPositions = {
    physical = {}, holy = {}, fire = {}, nature = {},
    frost = {}, shadow = {}, arcane = {}, chaos = {}, dot = {},
    heal = {}  -- Add heal here
}

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
            for nameplate, combatTextFrame in pairs(activeCombatTexts) do
                combatTextFrame:Hide()
                combatTextFrame:SetScript("OnUpdate", nil)
            end
            activeCombatTexts = {}
            damageTypeLastYPositions = {
                physical = {}, holy = {}, fire = {}, nature = {},
                frost = {}, shadow = {}, arcane = {}, chaos = {}, dot = {},
                heal = {}  -- Reset heal as well
            }
        end
    end)  -- This closes the SetScript function

end  -- This closes the OnInitialize function

function CombatTextPlus:SetupProfileOptions()
    local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    AceConfig:RegisterOptionsTable("CombatTextPlus_Profiles", profiles)
    AceConfigDialog:AddToBlizOptions("CombatTextPlus_Profiles", "Profiles", "CombatTextPlus")
end

function CombatTextPlus:ToggleEnabled(value)
    if value then
        frame:Show()
    else
        frame:Hide()
    end
end

local damageAggregation = {}  
local aggregationDelay = 0.1  

function CombatTextPlus:OnCombatLogEvent(...)
    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, spellName, school, amount = ...

    if not db.profile.enabled then return end

    -- Handle damage events
    if subEvent == "SPELL_DAMAGE" or subEvent == "SWING_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        if sourceGUID == UnitGUID("player") and amount and amount > 0 then
            local damageType = self:GetDamageType(school, subEvent)
            if db.profile.damageTypeFilters[damageType] then
                local key = destGUID .. "-" .. spellId .. "-" .. damageType
                if not damageAggregation[key] then
                    damageAggregation[key] = { amount = 0, timer = nil }
                end

                damageAggregation[key].amount = damageAggregation[key].amount + amount

                if not damageAggregation[key].timer then
                    damageAggregation[key].timer = C_Timer.NewTimer(aggregationDelay, function()
                        for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
                            if UnitGUID(nameplate.UnitFrame.unit) == destGUID then
                                self:DisplayCombatText(nameplate, damageAggregation[key].amount, damageType, spellId, spellName)
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
            -- Only show healing if the filter is enabled
            if db.profile.damageTypeFilters.heal then
                -- Display healing text on nameplates where possible
                for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
                    if UnitGUID(nameplate.UnitFrame.unit) == destGUID then
                        self:DisplayCombatText(nameplate, amount, "heal", spellId, spellName, isCriticalHeal)
                    end
                end
            end
        end
    end
end

function CombatTextPlus:DisplayCombatText(nameplate, amount, damageType, spellId, spellName, isCriticalHeal)
    local formattedAmount = self:FormatNumber(amount)
    if formattedAmount then
        local combatTextFrame = self:CreateCombatTextFrame(nameplate, damageType)

        -- Fetch the label for the damage type (if any)
        local damageLabel = self:GetDamageTypeLabel(damageType)

        -- Get the colors for the label and the damage/healing text
        local labelColorR, labelColorG, labelColorB = self:GetLabelColor(damageType)
        local damageColorR, damageColorG, damageColorB = self:GetDamageTypeColor(damageType)

        -- Set the label text and color
        if damageLabel ~= "" and combatTextFrame.label then
            combatTextFrame.label:SetText(damageLabel)
            combatTextFrame.label:SetTextColor(labelColorR, labelColorG, labelColorB)
        end

        -- Set the damage/healing text and color
        combatTextFrame.text:SetText(formattedAmount)
        combatTextFrame.text:SetTextColor(damageColorR, damageColorG, damageColorB)

        combatTextFrame:SetAlpha(1)
        combatTextFrame:Show()

        local startTime = GetTime()
        local index = #damageTypeLastYPositions[damageType] + 1
        table.insert(damageTypeLastYPositions[damageType], index)
		
        combatTextFrame:SetScript("OnUpdate", function(self, elapsed)
            local now = GetTime()
            local progress = (now - startTime) / (scrollDuration / db.profile.speedFactor * 10) 
            if progress >= 1 then
                combatTextFrame:Hide()
                combatTextFrame:SetScript("OnUpdate", nil)
                table.remove(damageTypeLastYPositions[damageType], index)
            else
                local xOffset, yOffset = CombatTextPlus:GetMovementOffsets(nameplate, damageType, progress, index)
                combatTextFrame:SetPoint("CENTER", nameplate, "BOTTOM", xOffset, yOffset)
                local alpha = 1 - progress
                combatTextFrame:SetAlpha(alpha)  -- Fade out as it scrolls up
            end
        end)
    end
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
    -- Fetch the damage type color from the profile
    local color = db.profile.damageTypeColors[damageType]
    if not color then
        return 1, 1, 1  -- Default to white if no color is found
    end
    return color.r, color.g, color.b
end

function CombatTextPlus:GetLabelColor(damageType)
    -- Fetch the label color for the given damage type
    local color = db.profile.labelColors[damageType]
    if not color then
        return 1, 1, 1  -- Default to white if no label color is found
    end
    return color.r, color.g, color.b
end

function CombatTextPlus:GetDamageTypeLabel(damageType)
    if damageType == "physical" then
        return "Physical"
    elseif damageType == "holy" then
        return "Holy"
    elseif damageType == "fire" then
        return "Fire"
    elseif damageType == "nature" then
        return "Nature"
    elseif damageType == "frost" then
        return "Frost"
    elseif damageType == "shadow" then
        return "Shadow"
    elseif damageType == "arcane" then
        return "Arcane"
    elseif damageType == "chaos" then
        return "Chaos"
    elseif damageType == "dot" then
        return "DOT"
    elseif damageType == "heal" then
        return "Heal"
    else
        return ""  -- Return empty if no label
    end
end

function CombatTextPlus:CreateCombatTextFrame(nameplate, damageType)
    local combatTextFrame = CreateFrame("Frame", nil, nameplate)
    combatTextFrame:SetSize(200, 50)
    combatTextFrame:SetPoint("CENTER", nameplate, "TOP", 0, 10)

    local combatText = combatTextFrame:CreateFontString(nil, "OVERLAY")
    local fontPath = LSM:Fetch("font", db.profile.font)

    -- Set the font size for the damage/healing text
    combatText:SetFont(fontPath, db.profile.fontSize, "OUTLINE")
    combatText:SetPoint("CENTER", combatTextFrame, "CENTER")
    combatTextFrame.text = combatText

    -- Optionally, you can also create another FontString for the label if needed
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
    -- Ensure we have a valid offset for this damageType, default to 0 if missing
    local xOffset = (db.profile.damageTypeOffsets[damageType] or 0) * progress

    -- Define the starting Y position from the bottom of the nameplate
    local startingYOffset = 0  -- Start directly at the bottom of the nameplate

    -- Calculate the vertical scrolling range based on the user's max Y offset setting
    local maxYOffset = db.profile.maxYOffset or 100  -- Use a default if the option is not set

    -- Vertical movement based on progress and index, using maxYOffset as the upper limit
    local yOffset = startingYOffset + (maxYOffset * progress * db.profile.speedFactor)

    -- Adjust for DOT damage if needed
    if damageType == "dot" then
        local dotMultiplier = db.profile.dotYOffsetMultiplier or 1.0
        yOffset = yOffset * dotMultiplier
    end

    -- Ensure healing follows the same movement logic as damage
    if damageType == "heal" then
        yOffset = startingYOffset + (maxYOffset * progress * db.profile.speedFactor)
    end

    -- Additional custom xOffset adjustments for specific damage types
    if damageType == "fire" then
        xOffset = (db.profile.damageTypeOffsets.fire or 0) * progress  
    elseif damageType == "nature" then
        xOffset = (db.profile.damageTypeOffsets.nature or 0) * progress
    elseif damageType == "frost" then
        xOffset = (db.profile.damageTypeOffsets.frost or 0) * progress
    elseif damageType == "shadow" then
        xOffset = (db.profile.damageTypeOffsets.shadow or 0) * progress
    elseif damageType == "arcane" then
        xOffset = (db.profile.damageTypeOffsets.arcane or 0) * progress
    elseif damageType == "chaos" then
        xOffset = (db.profile.damageTypeOffsets.chaos or 0) * progress
    end

    return xOffset, yOffset
end

function CalculateDistanceToTarget(nameplate)
    local playerX, playerY, playerZ = UnitPosition("player")
    local targetX, targetY, targetZ = UnitPosition(nameplate.UnitFrame.unit)
    
    if playerX and playerY and targetX and targetY then
        local dx = playerX - targetX
        local dy = playerY - targetY
        local dz = playerZ and targetZ and (playerZ - targetZ) or 0  
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        return distance
    else
        return nil  
    end
end

function CombatTextPlus:FormatNumber(amount)
    if not amount or amount == "" then return nil end
    local formatted = tostring(amount)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
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
                physical = {
                    name = "Physical Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for Physical damage.",
                    get = function() return db.profile.damageTypeOffsets.physical end,
                    set = function(info, value) db.profile.damageTypeOffsets.physical = value end,
                    order = 1,
                },
                holy = {
                    name = "Holy Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for Holy damage.",
                    get = function() return db.profile.damageTypeOffsets.holy end,
                    set = function(info, value) db.profile.damageTypeOffsets.holy = value end,
                    order = 2,
                },
                fire = {
                    name = "Fire Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for Fire damage.",
                    get = function() return db.profile.damageTypeOffsets.fire end,
                    set = function(info, value) db.profile.damageTypeOffsets.fire = value end,
                    order = 3,
                },
                nature = {
                    name = "Nature Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for Nature damage.",
                    get = function() return db.profile.damageTypeOffsets.nature end,
                    set = function(info, value) db.profile.damageTypeOffsets.nature = value end,
                    order = 4,
                },
                frost = {
                    name = "Frost Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for Frost damage.",
                    get = function() return db.profile.damageTypeOffsets.frost end,
                    set = function(info, value) db.profile.damageTypeOffsets.frost = value end,
                    order = 5,
                },
                shadow = {
                    name = "Shadow Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for Shadow damage.",
                    get = function() return db.profile.damageTypeOffsets.shadow end,
                    set = function(info, value) db.profile.damageTypeOffsets.shadow = value end,
                    order = 6,
                },
                arcane = {
                    name = "Arcane Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for Arcane damage.",
                    get = function() return db.profile.damageTypeOffsets.arcane end,
                    set = function(info, value) db.profile.damageTypeOffsets.arcane = value end,
                    order = 7,
                },
                chaos = {
                    name = "Chaos Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for Chaos damage.",
                    get = function() return db.profile.damageTypeOffsets.chaos end,
                    set = function(info, value) db.profile.damageTypeOffsets.chaos = value end,
                    order = 8,
                },
                dot = {
                    name = "DOT Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for DOT effects.",
                    get = function() return db.profile.damageTypeOffsets.dot end,
                    set = function(info, value) db.profile.damageTypeOffsets.dot = value end,
                    order = 9,
                },
                heal = {
                    name = "Heal Offset",
                    type = "range",
                    min = -50,
                    max = 50,
                    step = 1,
                    desc = "Adjust the horizontal movement of the combat text for Healing.",
                    get = function() return db.profile.damageTypeOffsets.heal end,
                    set = function(info, value) db.profile.damageTypeOffsets.heal = value end,
                    order = 10,
                },
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
            get = function()
                return db.profile.fontSize
            end,
            set = function(info, value)
                db.profile.fontSize = value
                for _, combatTextFrame in pairs(activeCombatTexts) do
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
    get = function()
        return db.profile.labelFontSize
    end,
    set = function(info, value)
        db.profile.labelFontSize = value
        CombatTextPlus:UpdateLabelFontSize()  -- Ensure labels are updated
    end,
    order = 8,
        },
        font = {
            name = "Font",
            type = "select",
            desc = "Set the font of the combat text.",
            values = LSM:HashTable("font"),
            dialogControl = "LSM30_Font",
            get = function()
                return db.profile.font
            end,
            set = function(info, value)
                db.profile.font = value
                for _, combatTextFrame in pairs(activeCombatTexts) do
                    combatTextFrame.text:SetFont(LSM:Fetch("font", value), db.profile.fontSize, "OUTLINE")
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
                    get = function()
                        local color = db.profile.labelColors.physical
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.physical
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 1,
                },
                holyLabelColor = {
                    name = "Holy Label Color",
                    type = "color",
                    desc = "Set the color of the 'Holy' damage label.",
                    get = function()
                        local color = db.profile.labelColors.holy
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.holy
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 2,
                },
                fireLabelColor = {
                    name = "Fire Label Color",
                    type = "color",
                    desc = "Set the color of the 'Fire' damage label.",
                    get = function()
                        local color = db.profile.labelColors.fire
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.fire
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 3,
                },
                natureLabelColor = {
                    name = "Nature Label Color",
                    type = "color",
                    desc = "Set the color of the 'Nature' damage label.",
                    get = function()
                        local color = db.profile.labelColors.nature
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.nature
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 4,
                },
                frostLabelColor = {
                    name = "Frost Label Color",
                    type = "color",
                    desc = "Set the color of the 'Frost' damage label.",
                    get = function()
                        local color = db.profile.labelColors.frost
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.frost
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 5,
                },
                shadowLabelColor = {
                    name = "Shadow Label Color",
                    type = "color",
                    desc = "Set the color of the 'Shadow' damage label.",
                    get = function()
                        local color = db.profile.labelColors.shadow
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.shadow
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 6,
                },
                arcaneLabelColor = {
                    name = "Arcane Label Color",
                    type = "color",
                    desc = "Set the color of the 'Arcane' damage label.",
                    get = function()
                        local color = db.profile.labelColors.arcane
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.arcane
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 7,
                },
                chaosLabelColor = {
                    name = "Chaos Label Color",
                    type = "color",
                    desc = "Set the color of the 'Chaos' damage label.",
                    get = function()
                        local color = db.profile.labelColors.chaos
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.chaos
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 8,
                },
                dotLabelColor = {
                    name = "DOT Label Color",
                    type = "color",
                    desc = "Set the color of the 'DOT' label.",
                    get = function()
                        local color = db.profile.labelColors.dot
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.dot
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 9,
                },
                healLabelColor = {
                    name = "Heal Label Color",
                    type = "color",
                    desc = "Set the color of the 'Heal' label.",
                    get = function()
                        local color = db.profile.labelColors.heal
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.labelColors.heal
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 10,
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
                physical = {
                    name = "Physical Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of Physical damage.",
                    get = function()
                        return db.profile.damageTypeFilters.physical
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.physical = value
                    end,
                    order = 1,
                },
                holy = {
                    name = "Holy Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of Holy damage.",
                    get = function()
                        return db.profile.damageTypeFilters.holy
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.holy = value
                    end,
                    order = 2,
                },
                fire = {
                    name = "Fire Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of Fire damage.",
                    get = function()
                        return db.profile.damageTypeFilters.fire
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.fire = value
                    end,
                    order = 3,
                },
                nature = {
                    name = "Nature Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of Nature damage.",
                    get = function()
                        return db.profile.damageTypeFilters.nature
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.nature = value
                    end,
                    order = 4,
                },
                frost = {
                    name = "Frost Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of Frost damage.",
                    get = function()
                        return db.profile.damageTypeFilters.frost
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.frost = value
                    end,
                    order = 5,
                },
                shadow = {
                    name = "Shadow Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of Shadow damage.",
                    get = function()
                        return db.profile.damageTypeFilters.shadow
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.shadow = value
                    end,
                    order = 6,
                },
                arcane = {
                    name = "Arcane Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of Arcane damage.",
                    get = function()
                        return db.profile.damageTypeFilters.arcane
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.arcane = value
                    end,
                    order = 7,
                },
                chaos = {
                    name = "Chaos Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of Chaos damage.",
                    get = function()
                        return db.profile.damageTypeFilters.chaos
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.chaos = value
                    end,
                    order = 8,
                },
                dot = {
                    name = "DOT Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of DOT damage.",
                    get = function()
                        return db.profile.damageTypeFilters.dot
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.dot = value
                    end,
                    order = 9,
                },
                heal = {
                    name = "Healing",
                    type = "toggle",
                    desc = "Enable or disable the display of Healing.",
                    get = function() return db.profile.damageTypeFilters.heal end,
                    set = function(info, value) db.profile.damageTypeFilters.heal = value end,
                    order = 10,
                },
            },
            order = 11,
        },
        damageTypeColors = {
            name = "Damage Type Colors",
            type = "group",
            inline = true,
            desc = "Customize the color of the combat text for each damage type.",
            args = {
                physicalColor = {
                    name = "Physical Damage Color",
                    type = "color",
                    desc = "Set the color for Physical damage.",
                    get = function()
                        local color = db.profile.damageTypeColors.physical
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.physical
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 1,
                },
                holyColor = {
                    name = "Holy Damage Color",
                    type = "color",
                    desc = "Set the color for Holy damage.",
                    get = function()
                        local color = db.profile.damageTypeColors.holy
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.holy
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 2,
                },
                fireColor = {
                    name = "Fire Damage Color",
                    type = "color",
                    desc = "Set the color for Fire damage.",
                    get = function()
                        local color = db.profile.damageTypeColors.fire
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.fire
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 3,
                },
                natureColor = {
                    name = "Nature Damage Color",
                    type = "color",
                    desc = "Set the color for Nature damage.",
                    get = function()
                        local color = db.profile.damageTypeColors.nature
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.nature
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 4,
                },
                frostColor = {
                    name = "Frost Damage Color",
                    type = "color",
                    desc = "Set the color for Frost damage.",
                    get = function()
                        local color = db.profile.damageTypeColors.frost
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.frost
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 5,
                },
                shadowColor = {
                    name = "Shadow Damage Color",
                    type = "color",
                    desc = "Set the color for Shadow damage.",
                    get = function()
                        local color = db.profile.damageTypeColors.shadow
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.shadow
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 6,
                },
                arcaneColor = {
                    name = "Arcane Damage Color",
                    type = "color",
                    desc = "Set the color for Arcane damage.",
                    get = function()
                        local color = db.profile.damageTypeColors.arcane
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.arcane
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 7,
                },
                chaosColor = {
                    name = "Chaos Damage Color",
                    type = "color",
                    desc = "Set the color for Chaos damage.",
                    get = function()
                        local color = db.profile.damageTypeColors.chaos
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.chaos
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 8,
                },
                dotColor = {
                    name = "DOT Damage Color",
                    type = "color",
                    desc = "Set the color for DOT effects.",
                    get = function()
                        local color = db.profile.damageTypeColors.dot
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.dot
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 9,
                },
                healColor = {
                    name = "Healing Color",
                    type = "color",
                    desc = "Set the color for Healing effects.",
                    get = function()
                        local color = db.profile.damageTypeColors.heal
                        return color.r, color.g, color.b
                    end,
                    set = function(info, r, g, b)
                        local color = db.profile.damageTypeColors.heal
                        color.r, color.g, color.b = r, g, b
                    end,
                    order = 10,
                },
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
    },
}

AceConfig:RegisterOptionsTable("CombatTextPlus", options)
AceConfigDialog:AddToBlizOptions("CombatTextPlus", "CombatTextPlus")

