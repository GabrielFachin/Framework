

local StateTable = {}


local Enum = require(script.Enum)
local Helper = require(script.Helper)


StateTable.Enum = Enum
StateTable.Categories = Enum.categories
StateTable.reactTags  = Enum.reactTags

StateTable.Status = {}       -- Buffs, Debuffs
StateTable.States = {}       -- Stun, Root, Silence
StateTable.PlayerStates = {} -- SelfCast, GlobalCast, LockedCast

Helper.LoadModules(script, "States", StateTable.States) 
Helper.LoadModules(script, "Status", StateTable.Status)
Helper.LoadModules(script, "PlayerStates", StateTable.PlayerStates)


function StateTable:GetTags(stateName)
	return Helper.GetTags(self, stateName)
end

function StateTable:IsState(meta)
	return Helper.IsState(self, meta)
end

-- A função que você pediu de volta
function StateTable:BuildShield(spell, callbackName, action)
	return Helper.BuildShield(spell, callbackName, action)
end

warn(StateTable)
return StateTable