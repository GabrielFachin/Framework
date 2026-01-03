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
			runner.Entity.RemoveID(stateID)
		end,
			

		
--		# Eventos
		
		onStart = function(self)
			
--		#Referencias/vars

			self.damage = 2
			
			self.M1Start = self.charLib.M1.M1Start
			self.M1S2 = self.charLib.M1.M1S2
			
			self.Entity.PlayAnimation(self.M1Start)
			
			local statsTable = self.statusTable

			self.control = statsTable.States.noControl

			self.state = statsTable.PlayerStates.Out.cast
			 

			--Gera o primeiro ID do pacote de estados (usado pra controle), esse ID  será usado como parametro no resto dos estados de controle pra serem removidos juntos ao fim do m1!
			self.stateID = self.Entity.ApplyStatus(self.state,self.Entity, 9999, self)

			self.Entity.ApplyStatus(self.control,self.Entity,5,self,self.stateID)			
			
			self.Entity.StartHitbox(self.data.duration)
			
		end,
		
		
		onHit = function(self,hitResult)
			
			local targetEntity = hitResult.target
			
			print(self)

			print(targetEntity)

			if self.Entity.TryHit(targetEntity,{}) then
			targetEntity.ApplyDamage(self.damage,self)
			end

		end,
		

		onStep = function(self, dt)
			
			if self.counter == 1 then
			local signal = self.Entity.WaitForMarker(self.M1Start,"End")
			if signal then
				self.Entity.StopAnimation(self.M1Start,0.2)
				self.Entity.RemoveID(self.stateID)
				self.Entity.StopHitbox()
				
				end
			elseif self.counter == 2 then
				
				
				local signal = self.Entity.WaitForMarker(self.M1S2,"End")
				if signal then
						self.Entity.StopAnimation(false)
						self.Entity:RemoveID(self.stateID)
						self.Entity:StopHitbox()
				end

			end
		
		
		end,
		
		
		
		
		onRecast = function(self)
			self.counter += 1
			if self.counter == 2 then
				self.Entity.PlayAnimation(self.M1S2)
				
				warn("ESTAGIO 2!")
				
				self.Entity.ApplyStatus(self.state,self.ED, 9999, self,self.stateID)

				self.Entity.ApplyStatus(self.control,self.ED,5,self,self.stateID)
				
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