-- CursorGlow
-- Made by Sharpedge_Gaming
-- v6.1  2025.08 

local LibStub = LibStub or _G.LibStub
local AceDB = LibStub:GetLibrary("AceDB-3.0")
local AceAddon = LibStub:GetLibrary("AceAddon-3.0")
local AceConfig = LibStub:GetLibrary("AceConfig-3.0")
local AceConfigDialog = LibStub:GetLibrary("AceConfigDialog-3.0")
local AceDBOptions = LibStub:GetLibrary("AceDBOptions-3.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")
local AceGUI = LibStub:GetLibrary("AceGUI-3.0")
local icon = LibStub("LibDBIcon-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("CursorGlow", true)

local CursorGlow = AceAddon:NewAddon("CursorGlow", "AceEvent-3.0", "AceConsole-3.0")

-- Constants
local NUM_PARTICLES = 100
local EXPLOSION_SPEED = 30

-- Texture and Color Options
local textureOptions = {
    ["ring1"] = "Interface\\Addons\\CursorGlow\\Textures\\Test2.png",
    ["ring2"] = "Interface\\Addons\\CursorGlow\\Textures\\Test3.png",
    ["ring3"] = "Interface\\Addons\\CursorGlow\\Textures\\Test4.png",
    ["ring4"] = "Interface\\Addons\\CursorGlow\\Textures\\Test6.png",
    ["ring5"] = "Interface\\Addons\\CursorGlow\\Textures\\Test5.png",
    ["ring6"] = "Interface\\Addons\\CursorGlow\\Textures\\Test8.png",
    ["ring7"] = "Interface\\Addons\\CursorGlow\\Textures\\Test7.png",
    ["ring8"] = "Interface\\Addons\\CursorGlow\\Textures\\Test9.png",
    ["ring9"] = "Interface\\Addons\\CursorGlow\\Textures\\Test10.png",
    ["ring10"] = "Interface\\Addons\\CursorGlow\\Textures\\Test11.png",
    ["ring11"] = "Interface\\Addons\\CursorGlow\\Textures\\Star1.png",
    ["ring12"] = "Interface\\Addons\\CursorGlow\\Textures\\Star2.png",
    ["ring13"] = "Interface\\Addons\\CursorGlow\\Textures\\Star3.png",
    ["ring14"] = "Interface\\Cooldown\\star4",
    ["ring15"] = "Interface\\Cooldown\\starburst",
    ["ring16"] = "Interface\\Addons\\CursorGlow\\Textures\\Test12.png",
    ["ring17"] = "Interface\\Addons\\CursorGlow\\Textures\\Test13.png",
    ["ring18"] = "Interface\\Addons\\CursorGlow\\Textures\\Test14.png",
    ["ring19"] = "Interface\\Addons\\CursorGlow\\Textures\\Test15.png",
    ["ring20"] = "Interface\\Addons\\CursorGlow\\Textures\\Test16.png",
    ["ring21"] = "Interface\\Addons\\CursorGlow\\Textures\\Test17.png",
    ["ring22"] = "Interface\\Addons\\CursorGlow\\Textures\\Test18.png",
    ["ring23"] = "Interface\\Addons\\CursorGlow\\Textures\\Burst.png",
    ["ring24"] = "Interface\\Addons\\CursorGlow\\Textures\\Fireball1.png",
    ["ring25"] = "Interface\\Addons\\CursorGlow\\Textures\\Spiderweb.png",
    ["ring26"] = "Interface\\Addons\\CursorGlow\\Textures\\ShatteredGlass.png",
    ["ring27"] = "Interface\\Addons\\CursorGlow\\Textures\\Bubbles.png",
    ["ring28"] = "Interface\\Addons\\CursorGlow\\Textures\\Eyeball.png",
    ["ring29"] = "Interface\\Addons\\CursorGlow\\Textures\\Skull.png",
    ["ring30"] = "Interface\\Addons\\CursorGlow\\Textures\\Snowflake.png",
    ["ring31"] = "Interface\\Addons\\CursorGlow\\Textures\\Paw.png",
    ["explosionParticle"] = "Interface\\Addons\\CursorGlow\\Textures\\Test17.png",
}

local orderedKeys = {
    "ring1", "ring2", "ring3", "ring4", "ring5", "ring6", "ring7", "ring8", "ring9", "ring10",
    "ring11", "ring12", "ring13", "ring14", "ring15", "ring16", "ring17", "ring18", "ring19", "ring20",
    "ring21", "ring22", "ring23", "ring24", "ring25", "ring26", "ring27", "ring28", "ring29", "ring30", "ring31",
}

local displayNames = {
    ring1 = 'Ring 1', ring2 = 'Ring 2', ring3 = 'Ring 3', ring4 = 'Ring 4', ring5 = 'Ring 5',
    ring6 = 'Ring 6', ring7 = 'Ring 7', ring8 = 'Ring 8', ring9 = 'Ring 9', ring10 = 'Star 1',
    ring11 = 'Star 2', ring12 = 'Star 3', ring13 = 'Star 4', ring14 = 'Star 5', ring15 = 'Starburst',
    ring16 = 'Butterfly', ring17 = 'Butterfly2', ring18 = 'Butterfly3', ring19 = 'Swirl', ring20 = 'Swirl2',
    ring21 = 'Horde', ring22 = 'Alliance', ring23 = 'Burst', ring24 = 'Fireball', ring25 = 'Spiderweb',
    ring26 = 'ShatteredGlass', ring27 = 'Bubbles', ring28 = 'Eyeball', ring29 = 'Skull', ring30 = 'Snowflake', ring31 = 'Paw',
}
local values = {}
for _, key in ipairs(orderedKeys) do values[key] = displayNames[key] end

local colorOptions = {
    red = {1, 0, 0}, green = {0, 1, 0}, blue = {0, 0, 1}, purple = {1, 0, 1}, white = {1, 1, 1},
    pink = {1, 0.08, 0.58}, orange = {1, 0.65, 0}, cyan = {0, 1, 1}, yellow = {1, 1, 0}, gray = {0.5, 0.5, 0.5},
    gold = {1, 0.84, 0}, teal = {0, 0.5, 0.5}, magenta = {1, 0, 1}, lime = {0.75, 1, 0}, olive = {0.5, 0.5, 0}, navy = {0, 0, 0.5},
    warrior = {0.78, 0.61, 0.43}, paladin = {0.96, 0.55, 0.73}, hunter = {0.67, 0.83, 0.45}, rogue = {1.00, 0.96, 0.41},
    priest = {1.00, 1.00, 1.00}, deathknight = {0.77, 0.12, 0.23}, shaman = {0.00, 0.44, 0.87}, mage = {0.41, 0.80, 0.94},
    warlock = {0.58, 0.51, 0.79}, monk = {0.00, 1.00, 0.59}, druid = {1.00, 0.49, 0.04}, demonhunter = {0.64, 0.19, 0.79}, evoker = {0.20, 0.58, 0.50}
}

-- Main frame and texture
local frame = CreateFrame("Frame", nil, UIParent)
frame:SetFrameStrata("TOOLTIP")
local texture = frame:CreateTexture()
texture:SetTexture(textureOptions["star4"])
texture:SetBlendMode("ADD")
texture:SetSize(32, 32)

-- Tail effect variables
local tailTextures = {}
local tailPositions = {}
CursorGlow.tailLength = 60

-- Explosion particle pool
local particles = {}
local function CreateExplosionParticles(textureKey, size)
    for i = 1, NUM_PARTICLES do
        if not particles[i] then
            local particle = CreateFrame("Frame", nil, UIParent)
            particle:SetFrameStrata("TOOLTIP")
            particle:SetSize(size, size)
            local tex = particle:CreateTexture(nil, "ARTWORK")
            tex:SetBlendMode("ADD")
            tex:SetAllPoints(particle)
            particle.texture = tex
            particle:Hide()
            particles[i] = particle
        end
        local texturePath = textureOptions[textureKey]
        particles[i].texture:SetTexture(texturePath)
        particles[i]:SetSize(size, size)
        particles[i].texture:SetVertexColor(1, 1, 1, 1)
    end
end

local function GetDefaultClassColor()
    local _, class = UnitClass("player")
    if class then
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            return {classColor.r, classColor.g, classColor.b}
        end
    end
    return {1, 1, 1}
end

local function UpdateTextureColor()
    local colorValue = colorOptions[CursorGlow.db.profile.color] or {1, 1, 1}
    texture:SetVertexColor(colorValue[1], colorValue[2], colorValue[3], CursorGlow.db.profile.opacity)
    for _, tailGroup in pairs(tailTextures) do
        for _, tailTexture in ipairs(tailGroup or {}) do
            tailTexture:SetVertexColor(colorValue[1], colorValue[2], colorValue[3], CursorGlow.db.profile.opacity)
        end
    end
end

local function UpdateTexture(textureKey)
    local texturePath = textureOptions[textureKey] or textureOptions["star4"]
    texture:SetTexture(texturePath)
    for _, tailGroup in pairs(tailTextures) do
        for _, tailTexture in ipairs(tailGroup or {}) do
            tailTexture:SetTexture(texturePath)
        end
    end
    UpdateTextureColor()
end

local function ToggleAddon(enable)
    if not CursorGlow.db.profile.combatOnly or UnitAffectingCombat("player") then
        if enable then frame:Show() else frame:Hide() end
    end
end

local function UpdateAddonVisibility()
    local mode = CursorGlow.db.profile.operationMode
    if mode == "disabled" then frame:Hide()
    elseif mode == "enabledAlways" or mode == "enabledAlwaysOnCursor" then frame:Show()
    elseif mode == "enabledInCombat" then
        if UnitAffectingCombat("player") then frame:Show() else frame:Hide() end
    end
end

local function InitializeTailTextures()
    for _, tailGroup in pairs(tailTextures) do
        for _, tailTexture in ipairs(tailGroup or {}) do
            tailTexture:Hide()
            tailTexture:SetTexture(nil)
        end
    end
    wipe(tailTextures)
    wipe(tailPositions)

    local numTails = CursorGlow.db.profile.numTails or 1
    local colorValue = colorOptions[CursorGlow.db.profile.color] or {1, 1, 1}
    local texturePath = textureOptions[CursorGlow.db.profile.texture] or textureOptions["star4"]
    for tailIndex = 1, numTails do
        tailTextures[tailIndex] = {}
        tailPositions[tailIndex] = {}
        for i = 1, CursorGlow.tailLength do
            local tailTexture = frame:CreateTexture(nil, "BACKGROUND")
            tailTexture:SetTexture(texturePath)
            tailTexture:SetBlendMode("ADD")
            tailTexture:SetSize(32, 32)
            tailTexture:SetVertexColor(colorValue[1], colorValue[2], colorValue[3], CursorGlow.db.profile.opacity)
            tailTextures[tailIndex][i] = tailTexture
        end
    end
    
end

local function UpdateExplosionTextureSize(size)
    for _, particle in ipairs(particles) do
        particle:SetSize(size, size)
    end
end

-- Performance Profile for explosion
local function TriggerExplosion(cursorX, cursorY)   
    local scale = UIParent:GetEffectiveScale()
    local color = CursorGlow.db.profile.explosionColor
    local explosionSize = CursorGlow.db.profile.explosionSize or 15
    local textureSize = CursorGlow.db.profile.explosionTextureSize or 10
    local explosionTexture = CursorGlow.db.profile.explosionTexture or "ring1"

    CreateExplosionParticles(explosionTexture, textureSize)

    for _, particle in ipairs(particles) do
        local angle = math.random() * 2 * math.pi
        local distance = math.random(1, explosionSize)
        local xOffset = math.cos(angle) * distance
        local yOffset = math.sin(angle) * distance

        particle:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)
        particle:SetAlpha(1)
        particle.texture:SetAlpha(1)
        particle.texture:SetVertexColor(unpack(color))
        particle:Show()
        particle:SetScript("OnUpdate", function(self, elapsed)
            local dx, dy = EXPLOSION_SPEED * xOffset * elapsed, EXPLOSION_SPEED * yOffset * elapsed
            local currentX, currentY = self:GetCenter()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", currentX + dx, currentY + dy)
            local currentAlpha = self:GetAlpha() or 1
            local newAlpha = currentAlpha - (elapsed * 0.8)
            if newAlpha <= 0 then self:Hide()
            else self:SetAlpha(newAlpha) end
        end)
    end   
end

local function TriggerExplosionOnClick()
    local cursorX, cursorY = GetCursorPosition()
    TriggerExplosion(cursorX, cursorY)
end

-- Mouse event frame
local eventHandlerFrame = CreateFrame("Frame", nil, UIParent)
eventHandlerFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
eventHandlerFrame:SetScript("OnEvent", function(self, event, buttonName)
    if event == "GLOBAL_MOUSE_DOWN" and buttonName == "LeftButton" and CursorGlow.db.profile.enableExplosion then
        TriggerExplosionOnClick()
    end
end)

-- Minimap Button
local minimapButton = LDB:NewDataObject("CursorGlow", {
    type = "data source",
    text = "CursorGlow",
    icon = "Interface\\Icons\\Spell_Frost_Frost",
    OnClick = function(self, button)
        if button == "LeftButton" then
            if Settings and Settings.OpenToCategory then
                Settings.OpenToCategory("CursorGlow")
            else
                InterfaceOptionsFrame_OpenToCategory("CursorGlow")
                InterfaceOptionsFrame_OpenToCategory("CursorGlow")
            end
        elseif button == "RightButton" then
            CursorGlow.db.profile.enabled = not CursorGlow.db.profile.enabled
            ToggleAddon(CursorGlow.db.profile.enabled)
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("|cFF00FF00CursorGlow|r")
        tooltip:AddLine("|cFFFFFFFFLeft-click to open settings.|r")
        tooltip:AddLine("|cFFFFFFFFRight-click to toggle addon.|r")
    end,
})

-- Profile Defaults
local defaultClassColor = GetDefaultClassColor()
local profileDefaults = {
    profile = {
        operationMode = "enabledAlways",
        enableExplosion = false,
        explosionColor = {1, 1, 1},
        explosionSize = 15,
        explosionTextureSize = 10,
        explosionTexture = "ring1",
        opacity = 1,
        minSize = 16,
        maxSize = 175,
        texture = "ring1",
        color = "white",
        enableTail = false,
        tailLength = 60,
        numTails = 1,
        tailSpacing = 10,
        minimap = { hide = false },
        pulseEnabled = false,
        pulseMinSize = 50,
        pulseMaxSize = 100,
        pulseSpeed = 1,
        combatOnly = false,
        enabled = true,
    }
}
local globalDefaults = { global = { profileEnabled = false } }
local charDefaults = { char = { lastSelectedProfile = nil } }

function CursorGlow:ApplySettings()
    
    local profile = self.db.profile
    profile.minimap = profile.minimap or { hide = false }
    profile.explosionColor = profile.explosionColor or {1, 1, 1}
    profile.minSize = profile.minSize or 16
    profile.maxSize = profile.maxSize or 175
    profile.pulseEnabled = profile.pulseEnabled or false
    profile.pulseMinSize = profile.pulseMinSize or 50
    profile.pulseMaxSize = profile.pulseMaxSize or 100
    profile.pulseSpeed = profile.pulseSpeed or 1
    UpdateTexture(profile.texture)
    UpdateTextureColor()
    UpdateAddonVisibility()
    CursorGlow.tailLength = profile.tailLength or 60
    InitializeTailTextures()
    if profile.minimap.hide then icon:Hide("CursorGlow") else icon:Show("CursorGlow") end   
end

function CursorGlow:SwitchProfile(forceGlobal, profileName)
    if profileName then
        self.db:SetProfile(profileName)
        self.dbChar.char.lastSelectedProfile = profileName
    elseif forceGlobal or self.dbGlobal.global.profileEnabled then
        self.db:SetProfile("Global")
        self.dbGlobal.global.profileEnabled = true
    else
        local characterProfileName = UnitName("player") .. " - " .. GetRealmName()
        self.db:SetProfile(characterProfileName)
        self.dbGlobal.global.profileEnabled = false
        self.dbChar.char.lastSelectedProfile = characterProfileName
    end
    self:ApplySettings()
end

function CursorGlow:OnProfileChanged(event, db, newProfile)
    self.dbChar.char.lastSelectedProfile = self.db:GetCurrentProfile()
    self:ApplySettings()
end

-- Create and register the main options
local options = {
    name = "CursorGlow",
    type = 'group',
    args = {
        -- General Settings Header
        generalHeader = {
            type = 'header',
            name = L["General Settings"],
            order = 1,
        },
        general = {
            type = 'group',
            name = L["General"],
            order = 2,
            inline = true,
            args = {
                globalProfileEnabled = {
                    type = 'toggle',
                    name = L["Enable Global Profile"],
                    desc = L["Use the same settings for all characters"],
                    order = 1,
                    get = function() return CursorGlow.dbGlobal.global.profileEnabled end,
                    set = function(_, val)
                        CursorGlow.dbGlobal.global.profileEnabled = val
                        if val then
                            CursorGlow.db:SetProfile("Global")
                        else
                            local characterProfileName = UnitName("player") .. " - " .. GetRealmName()
                            CursorGlow.db:SetProfile(characterProfileName)
                        end
                        CursorGlow:ApplySettings()
                    end,
                },
                operationMode = {
                    type = 'select',
                    name = L["Operation Mode"],
                    desc = L["Select when the addon should be active"],
                    order = 2,
                    values = {
                        enabledAlways = L["Enabled Always"],
                        enabledInCombat = L["Enabled in Combat Only"],
                        enabledAlwaysOnCursor = L["Always Show on Cursor"],
                    },
                    get = function() return CursorGlow.db.profile.operationMode end,
                    set = function(_, val)
                        CursorGlow.db.profile.operationMode = val
                        UpdateAddonVisibility()
                    end,
                },
                showMinimapIcon = {
                    type = 'toggle',
                    name = L["Show Minimap Icon"],
                    desc = L["Show or hide the minimap icon"],
                    order = 3,
                    get = function() return not CursorGlow.db.profile.minimap.hide end,
                    set = function(_, val)
                        CursorGlow.db.profile.minimap.hide = not val
                        if val then
                            icon:Show("CursorGlow")
                        else
                            icon:Hide("CursorGlow")
                        end
                    end,
                },
                spacerGeneral1 = {
                    type = 'description',
                    name = " ",  
                    order = 4,
                },
            },
        },

        -- Explosion Settings Header
        explosionHeader = {
            type = 'header',
            name = L["Explosion Settings"],
            order = 10,
        },
        explosion = {
            type = 'group',
            name = L["Explosion"],
            order = 11,
            inline = true,
            args = {
                enableExplosion = {
                    type = 'toggle',
                    name = L["Enable Explosion Effect"],
                    desc = L["Enable or disable the explosion effect on left-click"],
                    order = 1,
                    get = function() return CursorGlow.db.profile.enableExplosion end,
                    set = function(_, val)
                        CursorGlow.db.profile.enableExplosion = val
                    end,
                },
                explosionColor = {
                    type = 'color',
                    name = L["Explosion Color"],
                    desc = L["Pick a color for the explosion effect"],
                    order = 2,
                    get = function()
                        local color = CursorGlow.db.profile.explosionColor
                        return unpack(color or {1, 1, 1})
                    end,
                    set = function(_, r, g, b)
                        CursorGlow.db.profile.explosionColor = {r, g, b}
                    end,
                    disabled = function() return not CursorGlow.db.profile.enableExplosion end,
                },
                spacerExplosion1 = {
                    type = 'description',
                    name = " ",  
                    order = 3,
                },
                explosionSize = {
                    type = 'range',
                    name = L["Explosion Size"],
                    desc = L["Adjust the size of the explosion effect"],
                    order = 4,
                    min = 5,
                    max = 50,
                    step = 1,
                    get = function() return CursorGlow.db.profile.explosionSize end,
                    set = function(_, val)
                        CursorGlow.db.profile.explosionSize = val
                    end,
                    disabled = function() return not CursorGlow.db.profile.enableExplosion end,
                },
                explosionTextureSize = {
                    type = 'range',
                    name = L["Explosion Texture Size"],
                    desc = L["Adjust the texture size for the explosion effect"],
                    order = 5,
                    min = 10,
                    max = 40,
                    step = 1,
                    get = function() return CursorGlow.db.profile.explosionTextureSize end,
                    set = function(_, val)
                        CursorGlow.db.profile.explosionTextureSize = val
                        UpdateExplosionTextureSize(val)
                    end,
                    disabled = function() return not CursorGlow.db.profile.enableExplosion end,
                },
                explosionTexture = {
                    type = 'select',
                    name = L["Explosion Texture"],
                    desc = L["Select the texture for the explosion effect"],
                    order = 6,
                    values = {
                        ring1 = "Ring 1",
                        ring2 = "Ring 2",
                        ring3 = "Ring 3",
                        ring4 = "Ring 4",
                        ring5 = "Ring 5",
                        ring6 = "Ring 6",
                        ring7 = "Ring 7",
                        ring8 = "Ring 8",
                        ring9 = "Ring 9",
                        ring10 = "Star 1",
                        ring11 = "Star 2",
                        ring12 = "Star 3",
                        ring13 = "Star 4",
                        ring14 = "Star 5",
                        ring15 = "Starburst",
                        ring16 = "Butterfly",
                        ring17 = "Butterfly 2",
                        ring18 = "Butterfly 3",
                        ring19 = "Swirl",
                        ring20 = "Swirl 2",
                        ring21 = "Horde",
                        ring22 = "Alliance",
                        ring23 = "Burst",
						ring24 = "Fireball",
						ring25 = "SpiderWeb",
						ring26 = "ShatteredGlass",
						ring27 = "Bubbles",
						ring28 = "Eyeball",
						ring29 = "Skull",
						ring30 = "Snowflake",
						ring31 = "Paw",
                    },
                    get = function() return CursorGlow.db.profile.explosionTexture end,
                    set = function(_, val)
                     CursorGlow.db.profile.explosionTexture = val
                     CreateExplosionParticles(val, CursorGlow.db.profile.explosionTextureSize or 10)
                    local color = CursorGlow.db.profile.explosionColor or {1, 1, 1}
                        for _, particle in ipairs(particles) do
                            particle.texture:SetVertexColor(unpack(color))
                            end
                         end,
                    disabled = function() return not CursorGlow.db.profile.enableExplosion end,
                },
            },
        },

        -- Appearance Settings Header
        appearanceHeader = {
            type = 'header',
            name = L["Appearance Settings"],
            order = 20,
        },
        appearance = {
            type = 'group',
            name = L["Appearance"],
            order = 21,
            inline = true,
            args = {
                texture = {
                    type = 'select',
                    name = L["Texture"],
                    desc = L["Select the texture for the cursor glow"],
                    order = 1,
                    values = values,
                    get = function() return CursorGlow.db.profile.texture end,
                    set = function(_, val)
                        CursorGlow.db.profile.texture = val
                        UpdateTexture(val)
                        InitializeTailTextures()
                    end,
                },
                color = {
                    type = 'select',
                    name = L["Color"],
                    desc = L["Select the color for the texture"],
                    order = 2,
                    values = {
                        red = L["Red"],
                        green = L["Green"],
                        blue = L["Blue"],
                        purple = L["Purple"],
                        white = L["White"],
                        pink = L["Pink"],
                        orange = L["Orange"],
                        cyan = L["Cyan"],
                        yellow = L["Yellow"],
                        gray = L["Gray"],
                        gold = L["Gold"],
                        teal = L["Teal"],
                        magenta = L["Magenta"],
                        lime = L["Lime"],
                        olive = L["Olive"],
                        navy = L["Navy"],
                        -- WoW Class Colors
                        warrior = L["Warrior"],
                        paladin = L["Paladin"],
                        hunter = L["Hunter"],
                        rogue = L["Rogue"],
                        priest = L["Priest"],
                        deathknight = L["Death Knight"],
                        shaman = L["Shaman"],
                        mage = L["Mage"],
                        warlock = L["Warlock"],
                        monk = L["Monk"],
                        druid = L["Druid"],
                        demonhunter = L["Demon Hunter"],
                        evoker = L["Evoker"],
                    },
                    get = function() return CursorGlow.db.profile.color end,
                    set = function(_, val)
                        CursorGlow.db.profile.color = val
                        UpdateTextureColor()
                        InitializeTailTextures()
                    end,
                },
                opacity = {
                    type = 'range',
                    name = L["Opacity"],
                    desc = L["Adjust the opacity of the texture"],
                    order = 3,
                    min = 0,
                    max = 1,
                    step = 0.01,
                    get = function() return CursorGlow.db.profile.opacity end,
                    set = function(_, val)
                        CursorGlow.db.profile.opacity = val
                        UpdateTextureColor(CursorGlow.db.profile.color)
                    end,
                },
                spacerAppearance1 = {
                    type = 'description',
                    name = " ",  
                    order = 4,
                },
                minSize = {
                    type = 'range',
                    name = L["Minimum Size"],
                    desc = L["Set the minimum size of the texture"],
                    order = 5,
                    min = 16,
                    max = 64,
                    step = 1,
                    get = function() return CursorGlow.db.profile.minSize end,
                    set = function(_, val)
                        CursorGlow.db.profile.minSize = val
                    end,
                },
                maxSize = {
                    type = 'range',
                    name = L["Maximum Size"],
                    desc = L["Set the maximum size of the texture"],
                    order = 6,
                    min = 20,
                    max = 256,
                    step = 1,
                    get = function() return CursorGlow.db.profile.maxSize end,
                    set = function(_, val)
                        CursorGlow.db.profile.maxSize = val
                    end,
                },
            },
        },

        -- Tail Effect Settings Header
        tailHeader = {
            type = 'header',
            name = L["Tail Effect Settings"],
            order = 30,
        },
        tailSettings = {
            type = 'group',
            name = L["Tail Effect"],
            order = 31,
            inline = true,
            args = {
                enableTail = {
                    type = 'toggle',
                    name = L["Enable Tail Effect"],
                    desc = L["Toggle the tail effect behind the cursor"],
                    order = 1,
                    get = function() return CursorGlow.db.profile.enableTail end,
                    set = function(_, val)
                        CursorGlow.db.profile.enableTail = val
                        if not val then
                            for _, tailGroup in pairs(tailTextures or {}) do
                                if tailGroup then
                                    for _, tailTexture in ipairs(tailGroup) do
                                        if tailTexture and tailTexture.Hide then
                                            tailTexture:Hide()
                                        end
                                    end
                                end
                            end
                            tailPositions = {}
                        end
                    end,
                },
                tailLength = {
                    type = 'range',
                    name = L["Tail Length"],
                    desc = L["Adjust the length of the cursor tail"],
                    order = 2,
                    min = 10,
                    max = 80,
                    step = 1,
                    get = function() return CursorGlow.db.profile.tailLength end,
                    set = function(_, val)
                        CursorGlow.db.profile.tailLength = val
                        CursorGlow.tailLength = val
                        InitializeTailTextures()
                    end,
                    disabled = function() return not CursorGlow.db.profile.enableTail end,
                },
                numTails = {
                    type = 'range',
                    name = L["Number of Tails"],
                    desc = L["Select the number of tails"],
                    order = 3,
                    min = 1,
                    max = 5,
                    step = 1,
                    get = function() return CursorGlow.db.profile.numTails or 1 end,
                    set = function(_, val)
                        CursorGlow.db.profile.numTails = val
                        InitializeTailTextures()
                    end,
                    disabled = function() return not CursorGlow.db.profile.enableTail end,
                },
                tailSpacing = {
                    type = 'range',
                    name = L["Tail Spacing"],
                    desc = L["Adjust the spacing between multiple tails"],
                    order = 4,
                    min = 0,
                    max = 50,
                    step = 1,
                    get = function() return CursorGlow.db.profile.tailSpacing or 10 end,
                    set = function(_, val)
                        CursorGlow.db.profile.tailSpacing = val
                    end,
                    disabled = function() return not CursorGlow.db.profile.enableTail end,
                },
            },
        },

        -- Pulse Effect Settings Header
        pulseHeader = {
            type = 'header',
            name = L["Pulse Effect Settings"],
            order = 40,
        },
        pulseSettings = {
            type = 'group',
            name = L["Pulse Effect"],
            order = 41,
            inline = true,
            args = {
                pulseEnabled = {
                    type = 'toggle',
                    name = L["Enable Pulse Effect"],
                    desc = L["Toggle the pulsing effect when cursor is stationary"],
                    order = 1,
                    get = function() return CursorGlow.db.profile.pulseEnabled end,
                    set = function(_, val)
                        CursorGlow.db.profile.pulseEnabled = val
                    end,
                },
                pulseMinSize = {
                    type = 'range',
                    name = L["Pulse Minimum Size"],
                    desc = L["Set the minimum size of the pulse effect"],
                    order = 2,
                    min = 10,
                    max = 150,
                    step = 1,
                    get = function() return CursorGlow.db.profile.pulseMinSize end,
                    set = function(_, val)
                        CursorGlow.db.profile.pulseMinSize = val
                    end,
                    disabled = function() return not CursorGlow.db.profile.pulseEnabled end,
                },
                pulseMaxSize = {
                    type = 'range',
                    name = L["Pulse Maximum Size"],
                    desc = L["Set the maximum size of the pulse effect"],
                    order = 3,
                    min = 20,
                    max = 200,
                    step = 1,
                    get = function() return CursorGlow.db.profile.pulseMaxSize end,
                    set = function(_, val)
                        CursorGlow.db.profile.pulseMaxSize = val
                    end,
                    disabled = function() return not CursorGlow.db.profile.pulseEnabled end,
                },
                pulseSpeed = {
                    type = 'range',
                    name = L["Pulse Speed"],
                    desc = L["Adjust the speed of the pulsing effect"],
                    order = 4,
                    min = 0.1,
                    max = 5,
                    step = 0.1,
                    get = function() return CursorGlow.db.profile.pulseSpeed end,
                    set = function(_, val)
                        CursorGlow.db.profile.pulseSpeed = val
                    end,
                    disabled = function() return not CursorGlow.db.profile.pulseEnabled end,
                },
            },
        },
    },
}

-- Initialization
function CursorGlow:OnInitialize()   
    self.db = AceDB:New("CursorGlowDB", profileDefaults)
    self.dbChar = AceDB:New("CursorGlowCharDB", charDefaults)
    self.dbGlobal = AceDB:New("CursorGlowGlobalDB", globalDefaults)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    if self.dbGlobal.global.profileEnabled then
        self.db:SetProfile("Global")
    elseif self.dbChar.char.lastSelectedProfile then
        self.db:SetProfile(self.dbChar.char.lastSelectedProfile)
    else
        local characterProfileName = UnitName("player") .. " - " .. GetRealmName()
        self.db:SetProfile(characterProfileName)
    end
    self:ApplySettings()
    if minimapButton and icon then
        icon:Register("CursorGlow", minimapButton, self.db.profile.minimap)
    else
        DEFAULT_CHAT_FRAME:AddMessage("CursorGlow: Error initializing minimap button or LibDBIcon.")
    end
    if self.db.profile.minimap and self.db.profile.minimap.hide then icon:Hide("CursorGlow") else icon:Show("CursorGlow") end
    AceConfig:RegisterOptionsTable("CursorGlow", options)
    AceConfigDialog:AddToBlizOptions("CursorGlow", "CursorGlow")
    local profilesOptions = AceDBOptions:GetOptionsTable(self.db)
    AceConfig:RegisterOptionsTable("CursorGlow Profiles", profilesOptions)
    AceConfigDialog:AddToBlizOptions("CursorGlow Profiles", "Profiles", "CursorGlow")   
end

frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

function HandleCombatState()
    if CursorGlow.db.profile.combatOnly then
        ToggleAddon(CursorGlow.db.profile.enabled)
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        UpdateAddonVisibility()
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        UpdateTexture(CursorGlow.db.profile.texture)
        UpdateTextureColor()
        UpdateAddonVisibility()
        CursorGlow.speed = 0
    end   
end)

function CursorGlow:DisableTailEffect()
    if CursorGlow.db.profile.enableTail then
        for _, tailGroup in pairs(tailTextures or {}) do
            for _, tailTexture in ipairs(tailGroup or {}) do
                tailTexture:Hide()
            end
        end
        wipe(tailPositions)
    end
end

-- OnUpdate Handler (Profiled)
local speed, stationaryTime, pulseElapsedTime, prevX, prevY = 0, 0, 0
frame:SetScript("OnUpdate", function(self, elapsed)
    local profile = CursorGlow.db.profile
    local size = math.max(profile.minSize, profile.maxSize)
    local opacity = profile.opacity or 1
    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    prevX = prevX or cursorX
    prevY = prevY or cursorY

    if profile.operationMode == "enabledAlwaysOnCursor" then
        texture:SetHeight(size)
        texture:SetWidth(size)
        texture:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)
        texture:Show()        
        return
    end

    CursorGlow.tailLength = tonumber(CursorGlow.tailLength) or 60
    local numTails = tonumber(profile.numTails) or 1
    local tailSpacing = tonumber(profile.tailSpacing) or 10
    local dX, dY = cursorX - prevX, cursorY - prevY
    local distance = math.sqrt(dX * dX + dY * dY)

    if elapsed == 0 then elapsed = 0.0001 end
    local decayFactor = 2048 ^ -elapsed
    speed = math.min(decayFactor * speed + (1 - decayFactor) * distance / elapsed, 1024)

    if distance > 0 then
        stationaryTime = 0
        pulseElapsedTime = 0
        size = math.max(math.min(speed / 6, profile.maxSize), profile.minSize)
        texture:SetHeight(size)
        texture:SetWidth(size)
        texture:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (cursorX + 0.5 * dX) / scale, (cursorY + 0.5 * dY) / scale)
        texture:Show()
        if profile.enableTail then
            for tailIndex = 1, numTails do
                local offset = (tailIndex - (numTails + 1) / 2) * tailSpacing * scale
                local cursorPos = { x = (cursorX + offset) / scale, y = cursorY / scale }
                tailPositions[tailIndex] = tailPositions[tailIndex] or {}
                table.insert(tailPositions[tailIndex], 1, cursorPos)
                if #tailPositions[tailIndex] > CursorGlow.tailLength then table.remove(tailPositions[tailIndex]) end
                tailTextures[tailIndex] = tailTextures[tailIndex] or {}
                for i, tailTexture in ipairs(tailTextures[tailIndex]) do
                    local pos = tailPositions[tailIndex][i]
                    if pos and tailTexture then
                        tailTexture:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
                        local alpha = (CursorGlow.tailLength - i + 1) / CursorGlow.tailLength
                        tailTexture:SetAlpha(alpha * opacity)
                        tailTexture:SetSize(size, size)
                        tailTexture:Show()
                    elseif tailTexture then
                        tailTexture:Hide()
                    end
                end
            end
        else
            for _, tailGroup in pairs(tailTextures) do
                for _, tailTexture in ipairs(tailGroup or {}) do tailTexture:Hide() end
            end
            wipe(tailPositions)
        end
    else
        stationaryTime = stationaryTime + elapsed
        if profile.pulseEnabled then
            if stationaryTime >= 0.5 then
                pulseElapsedTime = pulseElapsedTime + elapsed
                local pulseSpeed = profile.pulseSpeed or 1
                local pulseProgress = (math.sin(pulseElapsedTime * pulseSpeed * math.pi * 2) + 1) / 2
                local pulseSize = profile.pulseMinSize + (profile.pulseMaxSize - profile.pulseMinSize) * pulseProgress
                texture:SetHeight(pulseSize)
                texture:SetWidth(pulseSize)
                texture:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)
                texture:SetAlpha(opacity)
                texture:Show()
            else
                texture:Hide()
            end
        else
            texture:Hide()
        end
        if profile.enableTail then
            if stationaryTime >= 1 then
                wipe(tailPositions)
            else
                for tailIndex = 1, numTails do
                    for i, tailTexture in ipairs(tailTextures[tailIndex] or {}) do
                        local pos = tailPositions[tailIndex] and tailPositions[tailIndex][i]
                        if pos and tailTexture then
                            tailTexture:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
                            local alpha = ((CursorGlow.tailLength - i + 1) / CursorGlow.tailLength) * math.max(1 - stationaryTime, 0)
                            tailTexture:SetAlpha(alpha * opacity)
                            tailTexture:SetSize(size * alpha, size * alpha)
                            if alpha > 0 then tailTexture:Show() else tailTexture:Hide() end
                        elseif tailTexture then
                            tailTexture:Hide()
                        end
                    end
                end
            end
        else
            for _, tailGroup in pairs(tailTextures) do
                for _, tailTexture in ipairs(tailGroup or {}) do tailTexture:Hide() end
            end
            wipe(tailPositions)
        end
    end
    prevX, prevY = cursorX, cursorY   
end)