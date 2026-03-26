local Framework = require("@Shared/Framework")
local AnimateComponent = require("@Shared/UI/Components/AnimationComponent")
local Trove = require("@Pckgs/Dumpster")
local Net = require("@Shared/Net")

local UnitsClass = {
	_activeButtons = {},
	_trove = nil,
	_currentEquipped = {},
}

function UnitsClass:Init(frame)
	if self._trove then
		self:Destroy()
	end
	
	self._trove = Trove.new()
	self._activeButtons = {}
	self._currentEquipped = {}
	
	self.ProfileService = Framework.WaitFor("ProfileService") 
	self.Utils = require("@Shared/UI/Classes/BottomScreen/Utils")
	
	self.Frame = frame
	self.SFrame = self.Frame:WaitForChild("ScrollingFrame")
	self.TempButton = self.SFrame:WaitForChild("Template")
	self.UnitCountLabel = self.Frame:WaitForChild("Bottom_Frame"):WaitForChild("Unit_Count")
	
	self.TempButton.Visible = false

	self._trove:Add(self.ProfileService:Observe("Towers", function(towers)
		self:UpdateButtons(towers or {})
	end))

	self._trove:Add(self.ProfileService:Observe("EquippedTowers", function(equipped)
		self._currentEquipped = equipped or {}
		self:RefreshEquippedStatus(self._currentEquipped)
	end))
end

function UnitsClass:UpdateButtons(towerList)
	local towerCounts = {}
	for _, towerData in ipairs(towerList) do
		towerCounts[towerData.Name] = (towerCounts[towerData.Name] or 0) + 1
	end
	
	self.UnitCountLabel.Text = #towerList .. " / 100"

	for towerName, buttonData in pairs(self._activeButtons) do
		if not towerCounts[towerName] then
			buttonData.Anim:Destroy()
			buttonData.UI:Destroy()
			self._activeButtons[towerName] = nil
		end
	end

	for towerName, count in pairs(towerCounts) do
		local buttonData = self._activeButtons[towerName]
		
		if not buttonData then
			local newButton = self.TempButton:Clone()
			newButton.Name = towerName
			newButton.Visible = true
			newButton.Parent = self.SFrame
			
			local properties = self.Utils:GetTowerProperties(towerName)
			if properties then
				newButton.Tower_Name.Text = towerName
				newButton.Ingame_Price.Text = "$" .. properties.Cost
				newButton.Images.Tower_Icon.Image = "rbxassetid://" .. properties.ImageID
			end
            
			if newButton.Images:FindFirstChild("Checkmark") then
				newButton.Images.Checkmark.Visible = false
			end

			local anim = AnimateComponent.new(newButton)
            
			anim:Init(nil, function()
				self.ProfileService:Get("EquippedTowers"):andThen(function(equippedTowers)
					local equippedID = nil

					for _, towerObj in pairs(equippedTowers or {}) do
						if towerObj and towerObj.Name == towerName then
							equippedID = towerObj.ID
							break
						end
					end

					if equippedID then
						Net.UnequipTower.Call(equippedID)
					else
						self.ProfileService:Get("Towers"):andThen(function(allTowers) 
							local towerToEquipID = nil
							for _, towerObj in ipairs(allTowers or {}) do
								if towerObj.Name == towerName then
									towerToEquipID = towerObj.ID
									break
								end
							end

							if towerToEquipID then
								Net.EquipTower.Call(towerToEquipID)
							end
						end)
					end
				end)
			end)

			buttonData = {
				UI = newButton,
				Anim = anim
			}
			self._activeButtons[towerName] = buttonData
		end

		local amountLabel = buttonData.UI:FindFirstChild("Tower_Amount")
		if amountLabel then
			amountLabel.Visible = true
			amountLabel.Text = "x" .. count
		end
	end
	
	if self._currentEquipped then
		self:RefreshEquippedStatus(self._currentEquipped)
	end
end

function UnitsClass:RefreshEquippedStatus(equippedList)
	local equippedNames = {}
	for _, towerObj in pairs(equippedList) do
		if towerObj and towerObj.Name then
			equippedNames[towerObj.Name] = true
		end
	end

	for towerName, buttonData in pairs(self._activeButtons) do
		local isAnyEquipped = (equippedNames[towerName] ~= nil)
		
		local images = buttonData.UI:FindFirstChild("Images")
		if images then
			local checkmark = images:FindFirstChild("Checkmark") 
			if checkmark then
				checkmark.Visible = isAnyEquipped
			end
		end
	end
end

function UnitsClass:Destroy()
	if self._activeButtons then
		for _, data in pairs(self._activeButtons) do
			if data.Anim then data.Anim:Destroy() end
			if data.UI then data.UI:Destroy() end
		end
		self._activeButtons = {}
	end
	
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return UnitsClass