local AttributeComponents = {}
AttributeComponents.__index = AttributeComponents

local ServerStorage = game:GetService("ServerStorage")
local Enum = require(ServerStorage.Modules.Combat.StateTable.Enum)

function AttributeComponents.new(entity, config)
    local self = setmetatable({}, AttributeComponents)
    self.Entity = entity

    -- Valores Base (vindos do CharacterDatabase)
    self.BaseAttributes = config.BaseAttributes or {
        Speed = 16,
        JumpForce = 50,
        MaxHP = 100,
        Defense = 0,
        DamageMult = 1,
    }

    -- Modificadores ativos
    -- Ex: table["Speed"]["BuffID"] = { Type = "Flat", Value = -0.5 }
    self.Modifiers = {} 

    return self
end

--=============================================================================
--  PIPELINE ATRIBUTOS
--=============================================================================

function AttributeComponents:GetAttribute(AttributeName, default)
    local base = self.BaseAttributes[AttributeName] or default or 0
    local mods = self.Modifiers[AttributeName]

    if not mods then return base end

    local finalBase = base
    local flatSum = 0
    local AddPercentSum = 0
    local MultPercentTotal = 1
    
    local activeOverride = nil

    --Busca o método de alteração e soma/subtrai no atributo.
    for _, mod in pairs(mods) do
        if mod.Type == Enum.ModifierType.Override then
            --Se o modificador for override, guarde o menor valor 
            if activeOverride == nil or mod.Value < activeOverride then
                activeOverride = mod.Value
            end
        elseif mod.Type == Enum.ModifierType.Flat then
            flatSum += mod.Value
        elseif mod.Type == Enum.ModifierType.AddPercent then
            AddPercentSum += mod.Value
        elseif mod.Type == Enum.ModifierType.MultPercent then
            MultPercentTotal *= mod.Value
        end
    end

    -- Se houver um Override, ele substitui o valor base original
    if activeOverride ~= nil then
        finalBase = activeOverride
    end


    -- Fórmula: ((Base + Flat) * (1 + %Add)) * %Mult)
    local result = ((finalBase + flatSum) * (1 + AddPercentSum)) * MultPercentTotal
    
    return math.max(0, result) -- Impede que atributos fiquem negativos
end

function AttributeComponents:SetBase(AttributeName, value)
    self.BaseAttributes[AttributeName] = value
end

--=============================================================================
--  GERENCIAMENTO
--=============================================================================

--Adiciona um modificador com base num ID e nome de atributo
function AttributeComponents:AddModifier(AttributeName, sourceID, type, value)
    if not self.Modifiers[AttributeName] then
        self.Modifiers[AttributeName] = {}
    end
    self.Modifiers[AttributeName][sourceID] = { Type = type, Value = value }
end

--Remove o modificador pelo ID da origem
function AttributeComponents:RemoveModifier(AttributeName, sourceID)
    if self.Modifiers[AttributeName] then
        self.Modifiers[AttributeName][sourceID] = nil
    end
end

local ExposeAPI = {
    GetAttribute = function(component, ...) return component:GetAttribute(...) end,
    SetBaseAttribute = function(component, ...) return component:SetBase(...) end,
    AddModifier = function(component, ...) return component:AddModifier(...) end,
    RemoveModifier = function(component, ...) return component:RemoveModifier(...) end,
}

return {
    new = AttributeComponents.new,
    ExposeAPI = ExposeAPI
}