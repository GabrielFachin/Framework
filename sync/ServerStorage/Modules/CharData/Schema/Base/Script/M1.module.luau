local Skill = {

	data = {
		cooldown = 1,
		duration = 5,
		castTime = 0,

	},

	callbacks = {

	
--		# Local Utils

		clearControl = function(runner,stateID)
			runner.anim:StopAll(0.2)
			runner.cd:RemoveID(stateID)
		end,
		
		
--		# Eventos
		
		onStart = function(self)
			
--		#Referencias/vars

			damage = 2
			
			M1Start = self.charLib.M1.M1Start
			M1S2 = self.charLib.M1.M1S2
			
			
			self.anim:Play(M1Start)
			
			local statsTable = self.statusTable

			 control = statsTable.States.noControl

			 state = statsTable.PlayerStates.Out.cast
			 

			--Gera o primeiro ID do pacote de estados (usado pra controle), esse ID  será usado como parametro no resto dos estados de controle pra serem removidos juntos ao fim do m1!
			stateID = self.cd:ApplyStatus(state,self.ED, 9999, self)

			self.cd:ApplyStatus(control,self.ED,5,self,stateID)
			
			
			self.weaponHitbox:Start(self.data.duration)
			
			
		end,
		
		
		onHit = function(self,hitResult)
			
			local targetED = hitResult.target
			
			print(self)

			print(targetED)

			print(self.cd)

			if self.cd:TryHit(targetED,{}) then
			targetED.CombatData:ApplyDamage(damage,self)
			end

		end,
		

		onStep = function(self, dt)
			
			if self.counter == 1 then
			local signal = self.anim:GetAnimMark(M1Start,"End")
			if signal then signal:Once(function()
						self.anim:Stop(M1Start,0.2)
						self.cd:RemoveID(stateID)
						self.weaponHitbox:Stop()
				
				end)
			end
			elseif self.counter == 2 then
				
				
				local signal = self.anim:GetAnimMark(M1S2,"End")
				if signal then signal:Once(function()
						self:Stop(false)
						self.cd:RemoveID(stateID)
						self.weaponHitbox:Stop()

					end)
				end

			end
		
		
		end,
		
		
		
		
		onRecast = function(self)
			self.counter += 1
			if self.counter == 2 then
				self.anim:Play(M1S2)
				
				warn("ESTAGIO 2!")
				
				self.cd:ApplyStatus(state,self.ED, 9999, self,stateID)

				self.cd:ApplyStatus(control,self.ED,5,self,stateID)
				
				self.weaponHitbox:Start(self.data.duration,function(hitResult) self:onHit(hitResult.target, hitResult)end)
				
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