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

			self.control = statsTable.States.noControl

			self.PlayerState = statsTable.PlayerStates.Out.cast			 

			--Gera o primeiro ID do pacote de estados (usado pra controle), esse ID  será usado como parametro no resto dos estados de controle pra serem removidos juntos ao fim do m1!
			self.stateID = self.Entity.ApplyStatus(self.PlayerState, 9999, self)

			self.Entity.ApplyStatus(self.control,9999,self,self.stateID)			
			
			self.Entity.StartHitbox(self.data.duration)

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
				self.Entity.StopHitbox()
				end)

			-------

			elseif self.counter == 2 then
				
				self.track:GetMarkerReachedSignal("End"):Once(function()
						self:Stop(false)
						self.Entity.RemoveStatusByID(self.stateID)
						self.Entity.StopHitbox()
				end)

			end
		
		
		end,
		
		
		onRecast = function(self)
			self.counter += 1
			if self.counter == 2 then
				self.track = self.Entity.PlayAnimation(self.M1S2)
				
				
				self.Entity.ApplyStatus(self.PlayerState, 9999, self, self.stateID)

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