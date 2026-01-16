--[[
	StateTable (Main)
	Centralizador de dados de combate.
]]

local StateTable = {}

-- 1. Dependências Internas
local Enums = require(script.Enums)
local Helpers = require(script.Helpers)

-- 2. Exposição de Dados
StateTable.Enums = Enums
StateTable.Categories = Enums.Categories
StateTable.reactTags = Enums.ReactTags

-- Tabelas de Dados (Populadas pelo Helpers)
StateTable.Status = {}       -- Buffs, Debuffs
StateTable.States = {}       -- Stun, Root, Silence
StateTable.PlayerStates = {} -- SelfCast, GlobalCast, LockedCast

-- 3. Carregamento (Aponta para a pasta Definitions)
-- Note que agora passamos 'script' para o helper saber onde procurar
Helpers.LoadModules(script, "Buffs", StateTable.Status)
Helpers.LoadModules(script, "Debuffs", StateTable.Status)
Helpers.LoadModules(script, "ControlStates", StateTable.States) -- ou "States" se manteve o nome da pasta
Helpers.LoadModules(script, "PlayerStates", StateTable.PlayerStates)

-- 4. Exposição de Funções (Redireciona para Helpers passando self)

function StateTable:GetTags(stateName)
	return Helpers.GetTags(self, stateName)
end

function StateTable:IsState(meta)
	return Helpers.IsState(self, meta)
end

-- A função que você pediu de volta
function StateTable:BuildShield(spell, callbackName, action)
	return Helpers.BuildShield(spell, callbackName, action)
end

return StateTable