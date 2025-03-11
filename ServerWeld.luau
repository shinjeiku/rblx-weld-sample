--[=[

Author: 新ジェイク | shinjeiku
Date: 01/05/2025

Required: Trove by sleitnick

	This is a character weld module -- it welds two characters together on the server. This module also
	addresses the issue of both welded characters dying when one of them dies or leaves the game.
	
]=]

--// Types \\--

export type WeldInfo = {
	Part0 : BasePart,
	Part1 : BasePart,
}


--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")


--// Imports \\--

local Trove = require(ReplicatedStorage.Modules.Utility.Trove)


--// Storage \\--

local ServerWeld = {}
ServerWeld.__index = ServerWeld


--// Functions \\--

-- Create new weld object.
function ServerWeld.new(player: Player, eChar: Model)
	
	-- Get player character, and ensure minimum conditions met.
	local char: Model = player.Character
	if not char or not eChar then return end
	
	local self = setmetatable({
		_Maid = Trove.new(), -- New trove to manage cleanup and memory.
		
		Player = player,
		Char = char,
		eChar = eChar,
		
		Hum = char:FindFirstChildOfClass("Humanoid"),
		eHum = eChar:FindFirstChildOfClass("Humanoid"),
		
	}, ServerWeld)
	
	-- General signals to monitor for both players and NPCs.
	self._clearSignals = {
		self.Hum.HealthChanged,
		self.eHum.HealthChanged,
		self.Player.CharacterRemoving,
	}
	
	self.ePlayer = Players:GetPlayerFromCharacter(eChar)
	
	-- If weld is between two players, then monitor character removing of enemy player as well.
	if self.ePlayer then table.insert(self._clearSignals, self.ePlayer.CharacterRemoving) end
	
	-- Create the connections for each signal in the signal table, and add connections to the maid.
	for _, signal: RBXScriptSignal in ipairs(self._clearSignals) do
		
		self._Maid:Connect(signal, function(param: number? | Model?)
			if param and type(param) == "number" and param > 0 then return end -- Specifically for HealthChanged. Don't want to clear if health > 0.
			
			self:Clear()
		end)
		
	end 
	
	-- Return new weld object to script.
	return self
end

-- Activates the weld.
function ServerWeld:Begin(info: WeldInfo)
	
	local HRP: BasePart = self.Char.HumanoidRootPart
	local eHRP: BasePart = self.eChar.HumanoidRootPart
	
	eHRP:SetNetworkOwner(self.Player) -- Sets network ownership of enemy HRP to player who initiated the weld for most accurate movement.
	
	if not self.ePlayer then self.eHum.PlatformStand = true end -- If there IS an ePlayer, we do this on the ePlayer's client.
	
	-- Makes eChar massless and without collision to negate change in center of gravity.
	for _, p: BasePart in ipairs(self.eChar:GetChildren()) do
		if not p:IsA("BasePart") then continue end
		
		p.Massless = true
		p.CanCollide = false
	end
	
	-- Creates the actual weld instance, and applies to specified parts.
	self.Weld = Instance.new("WeldConstraint")
	self.Weld.Parent = HRP
	
	self.Weld.Part1 = info.Part1 or HRP
	self.Weld.Part0 = info.Part0 or eHRP
	
	self._Maid:Add(self.Weld) -- Adds the weld instance to the maid.
	
	-- Adds a welded state to each character for external state management.
	self.Char:SetAttribute("Welded", true)
	self.eChar:SetAttribute("Welded", true)
end

-- Clears the weld object when requested, or when specified signals are fired.
function ServerWeld:Clear()
	
	self._Maid:Destroy() -- Clears the maid instantly in order to get rid of weld instance ASAP.
	
	self._clearSignals = nil
	
	-- Existence checks in case died or left the game.
	if self.eChar and self.eChar:IsDescendantOf(workspace) then
		local eHRP: BasePart = self.eChar.HumanoidRootPart
		
		eHRP:SetNetworkOwnershipAuto() -- Resets network ownership of enemy HRP.
		
		if not self.ePlayer then self.eHum.PlatformStand = false end
		
		-- Resets physical properties of enemy character.
		for _, p: BasePart in ipairs(self.eChar:GetChildren()) do
			if not p:IsA("BasePart") then continue end
			
			if p.Name == "Head" or p.Name == "Torso" then p.CanCollide = true end

			p.Massless = false
		end
		
		-- Removes welded state.
		self.eChar:SetAttribute("Welded", false)
	end
	
	-- If it wasn't the player character who left/died, then removes welded state.
	if self.Char and self.Char:IsDescendantOf(workspace) then self.Char:SetAttribute("Welded", false) end
	
	-- Clears the current weld object.
	table.clear(self)
	setmetatable(self, nil)
	table.freeze(self)
end


--// Return \\--

return ServerWeld
