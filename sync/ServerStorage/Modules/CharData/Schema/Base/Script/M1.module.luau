local Skill = {

	data = {
		cooldown = 1,
		duration = 5,
		castTime = 0,

	},

	callbacks = {

	
--		# Local Utils

		clearControl = function(runner,stateID)
			runner.Entity:StopAllAnimations(0.2)
			runner.Entity:RemoveID(stateID)
		end,
		
		
--		# Eventos
		
		onStart = function(self)
			
--		#Referencias/vars

			damage = 2
			
			M1Start = self.charLib.M1.M1Start
			M1S2 = self.charLib.M1.M1S2
			
			local keyM1 = tostring(M1Start)
			self.Entity:PlayAnimation(M1Start)
			
			local statsTable = self.statusTable

			 control = statsTable.States.noControl

			 state = statsTable.PlayerStates.Out.cast
			 

			--Gera o primeiro ID do pacote de estados (usado pra controle), esse ID  será usado como parametro no resto dos estados de controle pra serem removidos juntos ao fim do m1!
			stateID = self.Entity:ApplyStatus(state,self.Entity, 9999, self)

			self.Entity:ApplyStatus(control,self.Entity,5,self,stateID)
			
			
			self.Entity:StartHitbox(self.data.duration)
			
			
		end,
		
		
		onHit = function(self,hitResult)
			
			local targetEntity = hitResult.target
			
			print(self)

			print(targetEntity)

			if self.Entity:TryHit(targetEntity,{}) then
			targetEntity:ApplyDamage(damage,self)
			end

		end,
		

		onStep = function(self, dt)
			
			if self.counter == 1 then
			local signal = self.Entity:GetMarkerSignal(M1Start,"End")
			if signal then signal:Once(function()
						self.Entity:StopAnimation(M1Start,0.2)
						self.Entity:RemoveID(stateID)
						self.Entity:StopHitbox()
				
				end)
			end
			elseif self.counter == 2 then
				
				
				local signal = self.Entity:GetMarkerSignal(M1S2,"End")
				if signal then signal:Once(function()
						self:StopAnimation(false)
						self.cd:RemoveID(stateID)
						self.weaponHitbox:StopHitbox()

					end)
				end

			end
		
		
		end,
		
		
		
		
		onRecast = function(self)
			self.counter += 1
			if self.counter == 2 then
				self.Entity:PlayAnimation(M1S2)
				
				warn("ESTAGIO 2!")
				
				self.Entity:ApplyStatus(state,self.ED, 9999, self,stateID)

				self.Entity:ApplyStatus(control,self.ED,5,self,stateID)
				
				self.Entity:StartHitbox(self.data.duration,function(hitResult) self:onHit(hitResult.target, hitResult)end)
				
				damage = 3
				
			end
		end,

		onEnd = function(self)
			self.callbacks.clearControl(self,stateID)
		end,
		
		onCancel = function(self)
				self.callbacks.clearControl(self,stateID)
		end,
		
	}

}

return Skill