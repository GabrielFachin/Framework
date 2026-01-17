local ServerStorage = game:GetService("ServerStorage")
local StateTable = require(ServerStorage.Modules.Combat.StateTable)
local Skill = {

	data = {
		cooldown = 1,
		duration = 5,
		castTime = 0,

	},

	callbacks = {

	
--		# Local Utils

		clearControl = function(runner,stateID)
			runner.Entity.StopAllAnimations(0.2)
			runner.Entity.RemoveStatusByID(stateID)
			runner.Entity.RemovePlayerState()
		end,
			

		
--		# Eventos
		
		onStart = function(self)
			
--		#Referencias/vars

			self.damage = 2
			
			self.M1Start = self.charLib.M1.M1Start
			self.M1S2 = self.charLib.M1.M1S2
			
			self.track = self.Entity.PlayAnimation(self.M1Start)
			self.track.Looped = false

			local statsTable = self.statusTable

			self.control = statsTable.States.NoControl

			self.PlayerState = statsTable.PlayerStates.Out.cast			 

			self.Entity.SetPlayerState(self.PlayerState, self)

			self.stateID = self.Entity.ApplyStatus(self.control,9999,self)			
			
			self.Entity.StartHitbox(self.data.duration)
			

			local shield = statsTable:BuildEffect(statsTable.Status.StatusShield,
			StateTable.Enum.SkillBreakpoints.onTrigger,
		    function(runner,context) warn("shield atingido por:",context.data.name)
			end)

			self.Entity.ApplyStatus(shield,9999,self)

			self.Entity.ApplyStatus(statsTable.Status.Bleed,9999,self)
			
		end,
		
		
		onHit = function(self,hitResult)


			local statsTable = self.statusTable
			
			local targetEntity = hitResult.target
			
			targetEntity.TakeDamage(self.damage,self)
			targetEntity.ApplyStatus(statsTable.Status.Bleed,9999,self)

		end,
		

		onStep = function(self, dt)

			if self.counter == 1 then
			self.track:GetMarkerReachedSignal("End"):Once(function()

				self.Entity.StopAnimation(self.M1Start,0.2)
				self.Entity.RemoveStatusByID(self.stateID)
				self.Entity.RemovePlayerState()
				self.Entity.StopHitbox()
				end)

			-------

			elseif self.counter == 2 then
				
				self.track:GetMarkerReachedSignal("End"):Once(function()
						self:Stop(false)
						self.Entity.RemoveStatusByID(self.stateID)
						self.Entity.RemovePlayerState()
						self.Entity.StopHitbox()
				end)

			end
		
		
		end,
		
		
		onRecast = function(self)
			self.counter += 1
			if self.counter == 2 then
				self.track = self.Entity.PlayAnimation(self.M1S2)
				
				
				self.Entity.SetPlayerState(self.PlayerState, self)

				self.Entity.ApplyStatus(self.control, 9999, self, self.stateID)
				
				self.Entity.StartHitbox(self.data.duration,function(hitResult) self:onHit(hitResult.target, hitResult)end)
				
				self.damage = 3
				
			end
		end,

		onEnd = function(self)
			self.callbacks.clearControl(self,self.stateID)
		end,
		
		onCancel = function(self)
				self.callbacks.clearControl(self,self.stateID)
		end,
		
	}

}

return Skill