--!strict
-- src/client/combat/EconomyClient.luau
-- Pillar 4: Client-side Economy Service receiving 16-byte state packets and sending 4-byte purchase requests.
-- Obeys Rule 2.5: Zero GC binary buffer networking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local Network = Shared:WaitForChild("network")

local EconomyConfig = require(Configs:WaitForChild("EconomyConfig"))
local EconomyPacket = require(Network:WaitForChild("EconomyPacket"))

type EconomyStateData = EconomyPacket.EconomyStateData

local clientRoot = script.Parent.Parent
local AudioController: any = nil
do
	local audioFolder = clientRoot:FindFirstChild("audio")
	local acModule = if audioFolder then audioFolder:FindFirstChild("AudioController") else nil
	if acModule and acModule:IsA("ModuleScript") then
		local ok, mod = pcall(require, acModule)
		if ok then
			AudioController = mod
		end
	end
end

local EconomyClient = {
	State = {
		MatchCredits = EconomyConfig.StartingMatchCredits,
		LossStreak = 0,
		ArmorPoints = 0,
		ArmorTier = 0,
		PrimaryWeaponId = 0,
		SecondaryWeaponId = 1,
		UtilityBitmask = 0,
		ReasonCode = EconomyConfig.ReasonCodes.RoundStart,
		CreditDelta = 0,
		BuyPhaseOpen = true,
		AccountFlux = 0,
	} :: EconomyStateData,
	OnStateChanged = {} :: { (state: EconomyStateData) -> () },
}

local isInitialized = false
local sequenceCounter = 0
local economyRemote: RemoteEvent? = nil

local function getNextSequence(): number
	sequenceCounter = (sequenceCounter + 1) % 65536
	return sequenceCounter
end

local function playAudioFeedback(reasonCode: number): ()
	if not AudioController or type(AudioController.PlayUISound) ~= "function" then
		return
	end

	if reasonCode == EconomyConfig.ReasonCodes.PurchaseSuccess then
		AudioController.PlayUISound(EconomyConfig.AudioKeys.PurchaseSuccess)
	elseif reasonCode == EconomyConfig.ReasonCodes.PurchaseDenied then
		AudioController.PlayUISound(EconomyConfig.AudioKeys.PurchaseDenied)
	elseif reasonCode == EconomyConfig.ReasonCodes.SellRefund then
		AudioController.PlayUISound(EconomyConfig.AudioKeys.SellRefund)
	elseif
		reasonCode == EconomyConfig.ReasonCodes.KillOverdrive
		or reasonCode == EconomyConfig.ReasonCodes.KillHyperdrive
	then
		AudioController.PlayUISound(EconomyConfig.AudioKeys.OverdriveBounty)
	end
end

function EconomyClient.Init(): ()
	if isInitialized then
		return
	end
	isInitialized = true

	local remote = ReplicatedStorage:WaitForChild("EconomyPacketRemote", 10)
	if remote and remote:IsA("RemoteEvent") then
		economyRemote = remote
		remote.OnClientEvent:Connect(function(rawPacket: unknown)
			local decoded = EconomyPacket.decodeEconomyState(rawPacket)
			if not decoded then
				return
			end

			EconomyClient.State = decoded
			playAudioFeedback(decoded.ReasonCode)

			for _, callback in ipairs(EconomyClient.OnStateChanged) do
				task.spawn(callback, decoded)
			end
		end)
	end
end

function EconomyClient.BuyItem(itemId: number): ()
	if not economyRemote then
		EconomyClient.Init()
	end
	if not economyRemote then
		return
	end

	local buf = EconomyPacket.encodePurchaseRequest(
		EconomyConfig.ActionTypes.BuyItem,
		itemId,
		getNextSequence()
	)
	economyRemote:FireServer(buf)
end

function EconomyClient.SellRefund(itemId: number): ()
	if not economyRemote then
		EconomyClient.Init()
	end
	if not economyRemote then
		return
	end

	local buf = EconomyPacket.encodePurchaseRequest(
		EconomyConfig.ActionTypes.SellRefundItem,
		itemId,
		getNextSequence()
	)
	economyRemote:FireServer(buf)
end

function EconomyClient.UnlockPermanent(itemId: number): ()
	if not economyRemote then
		EconomyClient.Init()
	end
	if not economyRemote then
		return
	end

	local buf = EconomyPacket.encodePurchaseRequest(
		EconomyConfig.ActionTypes.UnlockPermanentItem,
		itemId,
		getNextSequence()
	)
	economyRemote:FireServer(buf)
end

function EconomyClient.RequestSync(): ()
	if not economyRemote then
		EconomyClient.Init()
	end
	if not economyRemote then
		return
	end

	local buf = EconomyPacket.encodePurchaseRequest(
		EconomyConfig.ActionTypes.RequestFullSync,
		0,
		getNextSequence()
	)
	economyRemote:FireServer(buf)
end

function EconomyClient.GetCredits(): number
	return EconomyClient.State.MatchCredits
end

function EconomyClient.GetArmor(): (number, number)
	return EconomyClient.State.ArmorPoints, EconomyClient.State.ArmorTier
end

function EconomyClient.GetFlux(): number
	return EconomyClient.State.AccountFlux
end

function EconomyClient.IsBuyPhaseOpen(): boolean
	return EconomyClient.State.BuyPhaseOpen
end

return table.freeze(EconomyClient)
