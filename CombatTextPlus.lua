-- Made by Sharpedge_Gaming
-- v1.5 - 11.0.2

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
        textColor = {r = 1, g = 1, b = 1, a = 1}, 
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
        },
        damageTypeYOffsetMultiplier = {
            dot = 0.8,  
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
        },
        damageTypeColors = {
            physical = {r = 1, g = 0.8, b = 0.2},  -- Yellowish
            holy = {r = 1, g = 1, b = 0.6},        -- Light Yellow
            fire = {r = 1, g = 0.5, b = 0.2},      -- Orange
            nature = {r = 0.3, g = 1, b = 0.3},    -- Green
            frost = {r = 0.4, g = 0.8, b = 1},     -- Light Blue
            shadow = {r = 0.5, g = 0, b = 0.5},    -- Dark Purple
            arcane = {r = 0.7, g = 0.4, b = 1},    -- Violet
            chaos = {r = 1, g = 0.3, b = 0.3},     -- Reddish
            dot = {r = 0.6, g = 0.2, b = 0.6},     -- Purple
        },
        labelColors = {
            physical = {r = 1, g = 1, b = 1},  -- White
            holy = {r = 1, g = 1, b = 1},      -- White
            fire = {r = 1, g = 1, b = 1},      -- White
            nature = {r = 1, g = 1, b = 1},    -- White
            frost = {r = 1, g = 1, b = 1},     -- White
            shadow = {r = 1, g = 1, b = 1},    -- White
            arcane = {r = 1, g = 1, b = 1},    -- White
            chaos = {r = 1, g = 1, b = 1},     -- White
            dot = {r = 1, g = 1, b = 1},       -- White
        },
        minimap = { hide = false } 
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
    frost = {}, shadow = {}, arcane = {}, chaos = {}, dot = {}
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

    -- Call the function to disable Blizzard combat text for damage
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
                frost = {}, shadow = {}, arcane = {}, chaos = {}, dot = {}
            }
        end
    end)
end


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
end

function CombatTextPlus:DisplayCombatText(nameplate, amount, damageType, spellId, spellName)
    local formattedAmount = self:FormatNumber(amount)
    if formattedAmount then
        local combatTextFrame = self:CreateCombatTextFrame(nameplate, damageType)
        combatTextFrame.text:SetText(formattedAmount)
        combatTextFrame.text:SetTextColor(self:GetDamageTypeColor(damageType))
        combatTextFrame:SetAlpha(1)
        combatTextFrame:Show()

        local label = combatTextFrame:CreateFontString(nil, "OVERLAY")
        label:SetFont(LSM:Fetch("font", db.profile.font), db.profile.labelFontSize, "OUTLINE")
        label:SetText(self:GetDamageTypeLabel(damageType))
        label:SetTextColor(self:GetLabelColor(damageType))
        label:SetPoint("LEFT", combatTextFrame.text, "RIGHT", 5, 0)
        label:Show()

        local startTime = GetTime()
        local index = #damageTypeLastYPositions[damageType] + 1
        table.insert(damageTypeLastYPositions[damageType], index)

        combatTextFrame:SetScript("OnUpdate", function(self, elapsed)
            local now = GetTime()
            local progress = (now - startTime) / scrollDuration
            if progress >= 1 then
                combatTextFrame:Hide()
                combatTextFrame:SetScript("OnUpdate", nil)
                table.remove(damageTypeLastYPositions[damageType], index)
            else
                local xOffset, yOffset = CombatTextPlus:GetMovementOffsets(nameplate, damageType, progress, index)
                combatTextFrame:SetPoint("CENTER", nameplate, "TOP", xOffset, yOffset)
                combatTextFrame:SetAlpha(0.2 * (1 - progress) + 0.8)
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
    local color = db.profile.damageTypeColors[damageType]
    return color.r, color.g, color.b
end

function CombatTextPlus:GetLabelColor(damageType)
    local color = db.profile.labelColors[damageType]
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
    else
        return ""  
    end
end

function CombatTextPlus:CreateCombatTextFrame(nameplate, damageType)
    local combatTextFrame = CreateFrame("Frame", nil, nameplate)
    combatTextFrame:SetSize(200, 50)
    combatTextFrame:SetPoint("CENTER", nameplate, "TOP", 0, 10)

    local combatText = combatTextFrame:CreateFontString(nil, "OVERLAY")
    combatText:SetFont(LSM:Fetch("font", db.profile.font), db.profile.fontSize, "OUTLINE")
    combatText:SetTextColor(self:GetDamageTypeColor(damageType))
    combatText:SetPoint("CENTER", combatTextFrame, "CENTER")
    combatTextFrame.text = combatText

    return combatTextFrame
end

function CombatTextPlus:GetMovementOffsets(nameplate, damageType, progress, index)
    local xOffset, yOffset = 0, 0

    xOffset = db.profile.damageTypeOffsets[damageType] * progress
    yOffset = math.min(50 * progress * db.profile.speedFactor + (index * 10), db.profile.maxYOffset)

    if damageType == "fire" then
        xOffset = math.sin(progress * 5) * 10  
    elseif damageType == "nature" then
        xOffset = -15 * progress * (1 - progress)  
    elseif damageType == "frost" then
        xOffset = 15 * progress * (1 - progress) 
    elseif damageType == "shadow" then
        xOffset = math.sin(progress * 10) * 10  
    elseif damageType == "arcane" then
        xOffset = math.sin(progress * 10) * 15 * progress  
    elseif damageType == "chaos" then
        xOffset = math.sin(progress * 20) * 5  
    elseif damageType == "dot" then
        xOffset = db.profile.damageTypeOffsets.dot * progress  
        yOffset = yOffset * db.profile.damageTypeYOffsetMultiplier.dot  
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
            desc = "Set the maximum vertical offset for the text.",
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
            desc = "Adjust the horizontal movement of the combat text for Physical damage.\n\nA negative value will move the text to the left, and a positive value will move it to the right.",
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
            desc = "Adjust the horizontal movement of the combat text for Holy damage.\n\nA negative value will move the text to the left, and a positive value will move it to the right.",
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
            desc = "Adjust the horizontal movement of the combat text for Fire damage.\n\nA negative value will move the text to the left, and a positive value will move it to the right.",
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
            desc = "Adjust the horizontal movement of the combat text for Nature damage.\n\nA negative value will move the text to the left, and a positive value will move it to the right.",
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
            desc = "Adjust the horizontal movement of the combat text for Frost damage.\n\nA negative value will move the text to the left, and a positive value will move it to the right.",
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
            desc = "Adjust the horizontal movement of the combat text for Shadow damage.\n\nA negative value will move the text to the left, and a positive value will move it to the right.",
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
            desc = "Adjust the horizontal movement of the combat text for Arcane damage.\n\nA negative value will move the text to the left, and a positive value will move it to the right.",
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
            desc = "Adjust the horizontal movement of the combat text for Chaos damage.\n\nA negative value will move the text to the left, and a positive value will move it to the right.",
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
            desc = "Adjust the horizontal movement of the combat text for DOT (Damage Over Time) effects.\n\nA negative value will move the text to the left, and a positive value will move it to the right.",
            get = function() return db.profile.damageTypeOffsets.dot end,
            set = function(info, value) db.profile.damageTypeOffsets.dot = value end,
            order = 9,
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
            desc = "Customize the color of the labels that appear next to each type of damage (e.g., 'Physical', 'Fire', 'DOT'). These labels help you quickly identify the type of damage at a glance.",
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
                    desc = "Set the color of the 'DOT' (Damage Over Time) label. This label appears for periodic damage effects like bleeds, poisons, and other DOT abilities.",
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
            },
            order = 10,
        },
        damageTypeFilters = {
            name = "Damage Type Filters",
            type = "group",
            inline = true,
            desc = "Select which types of damage you want to see displayed during combat. You can enable or disable specific damage types like Physical, Fire, Frost, etc. This allows you to focus only on the information that matters most to you.",
            args = {
                physical = {
                    name = "Physical Damage",
                    type = "toggle",
                    desc = "Enable or disable the display of Physical damage. Physical damage includes attacks like melee swings, bleeds, and physical-based abilities.",
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
                    desc = "Enable or disable the display of Holy damage. Holy damage is often associated with Paladin abilities and certain healing effects.",
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
                    desc = "Enable or disable the display of Fire damage. Fire damage includes abilities like Fireball, Flame Shock, and other fire-based spells.",
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
                    desc = "Enable or disable the display of Nature damage. Nature damage includes abilities like Lightning Bolt, Poison, and other nature-based effects.",
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
                    desc = "Enable or disable the display of Frost damage. Frost damage includes abilities like Frostbolt, Blizzard, and other frost-based spells.",
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
                    desc = "Enable or disable the display of Shadow damage. Shadow damage is associated with abilities like Shadow Word: Pain, Shadow Bolt, and other shadow-based spells.",
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
                    desc = "Enable or disable the display of Arcane damage. Arcane damage includes abilities like Arcane Missiles, Arcane Blast, and other arcane-based spells.",
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
                    desc = "Enable or disable the display of Chaos damage. Chaos damage is a unique type that combines all magic schools and is often associated with Demon Hunter abilities.",
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
                    desc = "Enable or disable the display of DOT (Damage Over Time) damage. This includes periodic damage from effects like bleeds, poisons, and other DOT abilities.",
                    get = function()
                        return db.profile.damageTypeFilters.dot
                    end,
                    set = function(info, value)
                        db.profile.damageTypeFilters.dot = value
                    end,
                    order = 9,
                },
            },
            order = 11,
        },
        damageTypeColors = {
            name = "Damage Type Colors",
            type = "group",
            inline = true,
            desc = "Customize the color of the combat text for each damage type. This allows you to assign distinct colors to each type of damage, making it easier to differentiate between them during combat.",
            args = {
                physicalColor = {
                    name = "Physical Damage Color",
                    type = "color",
                    desc = "Set the color for Physical damage. This color will be used for all combat text related to physical attacks and abilities.",
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
                    desc = "Set the color for Holy damage. This color will be used for all combat text related to holy-based attacks and abilities.",
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
                    desc = "Set the color for Fire damage. This color will be used for all combat text related to fire-based attacks and abilities.",
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
                    desc = "Set the color for Nature damage. This color will be used for all combat text related to nature-based attacks and abilities.",
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
                    desc = "Set the color for Frost damage. This color will be used for all combat text related to frost-based attacks and abilities.",
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
                    desc = "Set the color for Shadow damage. This color will be used for all combat text related to shadow-based attacks and abilities.",
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
                    desc = "Set the color for Arcane damage. This color will be used for all combat text related to arcane-based attacks and abilities.",
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
                    desc = "Set the color for Chaos damage. This color will be used for all combat text related to chaos-based attacks and abilities.",
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
                    desc = "Set the color for DOT (Damage Over Time) effects. This color will be used for all combat text related to periodic damage from effects like bleeds, poisons, and other DOT abilities.",
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

