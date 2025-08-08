-- src/server/items/ItemUseHandler.server.lua
-- Central handler for UsePrompt interactions on purchased items
-- Routes to appropriate services for tool granting or ammo addition

local ProximityPromptService = game:GetService("ProximityPromptService")

-- Services
local ToolGrantService = require(script.Parent.Parent.services.ToolGrantService)
local AmmoService = require(script.Parent.Parent.services.AmmoService)

local ItemUseHandler = {}

-- Handle UsePrompt triggers
local function onProximityPromptTriggered(promptObject, player)
	-- Only handle UsePrompt objects
	if promptObject.Name ~= "UsePrompt" then
		return
	end
	
	if not promptObject.Enabled then
		return
	end
	
	-- Get use type and routing information
	local useType = promptObject:GetAttribute("UseType")
	if not useType then
		warn("[ItemUseHandler] UsePrompt missing UseType attribute")
		return
	end
	
	-- Disable prompt immediately to prevent double-triggers
	promptObject.Enabled = false
	
	local success = false
	
	-- Route based on use type
	if useType == "GrantTool" then
		local toolName = promptObject:GetAttribute("ToolTemplate")
		if toolName then
			success = ToolGrantService.grantTool(player, toolName)
			if success then
				print("[ItemUseHandler] Granted tool", toolName, "to", player.Name)
			end
		else
			warn("[ItemUseHandler] GrantTool UsePrompt missing ToolTemplate attribute")
		end
		
	elseif useType == "AddAmmo" then
		local ammoType = promptObject:GetAttribute("AmmoType")
		local ammoAmount = promptObject:GetAttribute("AmmoAmount")
		
		if ammoType and ammoAmount then
			success = AmmoService.addAmmo(player, ammoType, ammoAmount)
			if success then
				print("[ItemUseHandler] Added", ammoAmount, ammoType, "to", player.Name)
			end
		else
			warn("[ItemUseHandler] AddAmmo UsePrompt missing AmmoType or AmmoAmount attributes")
		end
		
	else
		warn("[ItemUseHandler] Unknown UseType:", useType)
	end
	
	-- Clean up the item if use was successful
	if success then
		local hostPart = promptObject.Parent
		if hostPart then
			-- Destroy the entire item (Model or BasePart)
			local itemToDestroy = hostPart.Parent
			if itemToDestroy and itemToDestroy ~= workspace then
				itemToDestroy:Destroy()
				print("[ItemUseHandler] Destroyed used item:", itemToDestroy.Name)
			else
				-- Fallback: destroy just the host part
				hostPart:Destroy()
				print("[ItemUseHandler] Destroyed host part:", hostPart.Name)
			end
		end
	else
		-- Re-enable prompt if use failed
		promptObject.Enabled = true
	end
end

-- Initialize the handler
local function init()
	ProximityPromptService.PromptTriggered:Connect(onProximityPromptTriggered)
	print("[ItemUseHandler] Initialized - Listening for UsePrompt interactions")
end

-- Initialize on script load
init()

return ItemUseHandler