--!strict
-- src/server/economy/EconomyManager.luau
-- Pillar 4: Authoritative server-side Match & Persistent Economy Service.
-- Integrates with CombatValidator.luau for velocity-scaled B-hop kill bounties and Exo-Shield absorption.
-- Obeys Rule 2.1 (Zero Tool/Backpack usage) and Rule 2.5 (16-byte binary buffer state sync).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local Network = Shared:WaitForChild("network")

local EconomyConfig = require(Configs:WaitForChild("EconomyConfig"))
local EconomyPacket = require(Network:WaitForChild("EconomyPacket"))

export type AssistEntry = {
	AttackerUserId: number,
	DamageDealt: number,
	LastHitTimestamp: number,
}

export type PlayerEconomyLedger = {
	Player: Player,
	MatchCredits: number,
	LossStreak: number,
	ArmorPoints: number,
	ArmorTier: number,
	PrimaryWeaponId: number,
	SecondaryWeaponId: number,
	UtilityBitmask: number,
	BuyPhaseOpen: boolean,
	RoundPurchases: { [number]: number }, -- ItemId -> Price paid this round (for full buy-phase refund)
	LastRequestTime: number,
	LastSequenceId: number,
	AccountFlux: number,
	UnlockedItemIds: { [number]: boolean },
	DamageLedger: { [number]: AssistEntry }, -- AttackerUserId -> AssistEntry
}

export type DamageAbsorptionResult = {
	HealthDamage: number,
	ArmorAbsorbed: number,
	RemainingArmor: number,
}

local DATASTORE_NAME = "SciFiBhopFPS_Economy_v1"
local AUTOSAVE_INTERVAL_SECONDS = 120.0
local DEFAULT_SECONDARY_ID = 1 -- K-14 Pulse Pistol

local EconomyManager = {}
local playerLedgers: { [Player]: PlayerEconomyLedger } = {}
local isGlobalBuyPhaseActive: boolean = true
local economyRemote: RemoteEvent? = nil
local economyStore: DataStore? = nil

-- Safely initializes DataStore (handles unpublished Studio test sessions gracefully)
local function getEconomyDataStore(): DataStore?
	if economyStore ~= nil then
		return economyStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok and result then
		economyStore = result
		return result
	end
	return nil
end

-- Sends a 16-byte binary EconomyStatePacket to the target client
local function replicateStateToClient(
	ledger: PlayerEconomyLedger,
	reasonCode: number,
	creditDelta: number
): ()
	if economyRemote == nil then
		return
	end

	local packetBuffer = EconomyPacket.encodeEconomyState({
		MatchCredits = ledger.MatchCredits,
		LossStreak = ledger.LossStreak,
		ArmorPoints = ledger.ArmorPoints,
		ArmorTier = ledger.ArmorTier,
		PrimaryWeaponId = ledger.PrimaryWeaponId,
		SecondaryWeaponId = ledger.SecondaryWeaponId,
		UtilityBitmask = ledger.UtilityBitmask,
		ReasonCode = reasonCode,
		CreditDelta = creditDelta,
		BuyPhaseOpen = ledger.BuyPhaseOpen and isGlobalBuyPhaseActive,
		AccountFlux = ledger.AccountFlux,
	})

	economyRemote:FireClient(ledger.Player, packetBuffer)
end

-- Syncs non-Tool weapon attributes onto the Player for CombatValidator & StanceReplicator reads
local function syncServerLoadoutAttributes(ledger: PlayerEconomyLedger): ()
	local player = ledger.Player
	local primaryDef = EconomyConfig.ItemsById[ledger.PrimaryWeaponId]
	local secondaryDef = EconomyConfig.ItemsById[ledger.SecondaryWeaponId]

	player:SetAttribute("PrimaryWeaponKey", if primaryDef then primaryDef.CodeKey else "")
	player:SetAttribute("SecondaryWeaponKey", if secondaryDef then secondaryDef.CodeKey else "wpn_pulse_pistol")
	player:SetAttribute("ArmorPoints", ledger.ArmorPoints)
	player:SetAttribute("ArmorTier", ledger.ArmorTier)
	player:SetAttribute("UtilityBitmask", ledger.UtilityBitmask)
end

-- Loads persistent Flux Shards and permanent unlocks from DataStoreService
local function loadPersistentProfile(ledger: PlayerEconomyLedger): ()
	local store = getEconomyDataStore()
	if store == nil then
		return
	end

	local key = "Player_" .. tostring(ledger.Player.UserId)
	local success, savedData = pcall(function()
		return store:GetAsync(key)
	end)

	if success and typeof(savedData) == "table" then
		local data = savedData :: { [string]: any }
		if typeof(data.AccountFlux) == "number" then
			ledger.AccountFlux = math.max(0, math.floor(data.AccountFlux))
		end
		if typeof(data.UnlockedIds) == "table" then
			for _, idVal in data.UnlockedIds :: { any } do
				if typeof(idVal) == "number" then
					ledger.UnlockedItemIds[idVal] = true
				end
			end
		end
	end
end

-- Saves persistent Flux Shards and permanent unlocks to DataStoreService
local function savePersistentProfile(ledger: PlayerEconomyLedger): ()
	local store = getEconomyDataStore()
	if store == nil then
		return
	end

	local unlockedArray: { number } = {}
	for itemId, isUnlocked in ledger.UnlockedItemIds do
		if isUnlocked then
			table.insert(unlockedArray, itemId)
		end
	end

	local key = "Player_" .. tostring(ledger.Player.UserId)
	local payload = {
		AccountFlux = ledger.AccountFlux,
		UnlockedIds = unlockedArray,
		UpdatedAt = os.time(),
	}

	pcall(function()
		store:SetAsync(key, payload)
	end)
end

-- Checks if a utility bit is currently set in the player's bitmask
local function hasUtilityBit(bitmask: number, bitIndex: number): boolean
	return bit32.band(bitmask, bit32.lshift(1, bitIndex)) ~= 0
end

-- Sets or clears a utility bit in the player's bitmask
local function setUtilityBit(bitmask: number, bitIndex: number, enabled: boolean): number
	local mask = bit32.lshift(1, bitIndex)
	if enabled then
		return bit32.bor(bitmask, mask)
	else
		return bit32.band(bitmask, bit32.bnot(mask))
	end
end

-- Processes a validated BuyItem request during the active Buy Phase
local function handleBuyItem(ledger: PlayerEconomyLedger, itemId: number): ()
	local itemDef = EconomyConfig.ItemsById[itemId]
	if itemDef == nil then
		replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
		return
	end

	if not (ledger.BuyPhaseOpen and isGlobalBuyPhaseActive) then
		replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
		return
	end

	-- Verify permanent unlock requirement
	if itemDef.PermanentUnlockFluxCost > 0 and not ledger.UnlockedItemIds[itemId] then
		replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
		return
	end

	-- Check category-specific ownership & refund trade-in value if upgrading in same round
	local tradeInRefund = 0
	if itemDef.Category == "Primary" then
		if ledger.PrimaryWeaponId == itemId then
			replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
			return
		end
		if ledger.PrimaryWeaponId ~= 0 and ledger.RoundPurchases[ledger.PrimaryWeaponId] ~= nil then
			tradeInRefund = ledger.RoundPurchases[ledger.PrimaryWeaponId]
		end
	elseif itemDef.Category == "Secondary" then
		if ledger.SecondaryWeaponId == itemId then
			replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
			return
		end
		if ledger.SecondaryWeaponId ~= 0 and ledger.RoundPurchases[ledger.SecondaryWeaponId] ~= nil then
			tradeInRefund = ledger.RoundPurchases[ledger.SecondaryWeaponId]
		end
	elseif itemDef.Category == "Armor" then
		local targetAP = itemDef.ArmorPoints or 25
		if ledger.ArmorPoints >= targetAP then
			replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
			return
		end
	elseif itemDef.Category == "Utility" then
		local bitIndex = itemDef.UtilityBitIndex or 0
		if hasUtilityBit(ledger.UtilityBitmask, bitIndex) then
			replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
			return
		end
	end

	local netCost = math.max(0, itemDef.Cost - tradeInRefund)
	if ledger.MatchCredits < netCost then
		replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
		return
	end

	-- Deduct credits and apply item to ledger
	ledger.MatchCredits = math.clamp(ledger.MatchCredits - netCost, 0, EconomyConfig.MaxMatchCredits)

	if itemDef.Category == "Primary" then
		if ledger.PrimaryWeaponId ~= 0 then
			ledger.RoundPurchases[ledger.PrimaryWeaponId] = nil
		end
		ledger.PrimaryWeaponId = itemId
		ledger.RoundPurchases[itemId] = itemDef.Cost
	elseif itemDef.Category == "Secondary" then
		if ledger.SecondaryWeaponId ~= 0 then
			ledger.RoundPurchases[ledger.SecondaryWeaponId] = nil
		end
		ledger.SecondaryWeaponId = itemId
		ledger.RoundPurchases[itemId] = itemDef.Cost
	elseif itemDef.Category == "Armor" then
		ledger.ArmorPoints = itemDef.ArmorPoints or 25
		ledger.ArmorTier = if itemId == 41 then 2 else 1
		ledger.RoundPurchases[itemId] = itemDef.Cost
	elseif itemDef.Category == "Utility" then
		local bitIndex = itemDef.UtilityBitIndex or 0
		ledger.UtilityBitmask = setUtilityBit(ledger.UtilityBitmask, bitIndex, true)
		ledger.RoundPurchases[itemId] = itemDef.Cost
	end

	syncServerLoadoutAttributes(ledger)
	replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseSuccess, -netCost)
end

-- Processes a full-price buy-phase sell/refund for items bought in the current round
local function handleSellRefundItem(ledger: PlayerEconomyLedger, itemId: number): ()
	if not (ledger.BuyPhaseOpen and isGlobalBuyPhaseActive) then
		replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
		return
	end

	local paidAmount = ledger.RoundPurchases[itemId]
	local itemDef = EconomyConfig.ItemsById[itemId]
	if paidAmount == nil or itemDef == nil then
		replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
		return
	end

	ledger.RoundPurchases[itemId] = nil
	ledger.MatchCredits = math.clamp(ledger.MatchCredits + paidAmount, 0, EconomyConfig.MaxMatchCredits)

	if itemDef.Category == "Primary" and ledger.PrimaryWeaponId == itemId then
		ledger.PrimaryWeaponId = 0
	elseif itemDef.Category == "Secondary" and ledger.SecondaryWeaponId == itemId then
		ledger.SecondaryWeaponId = DEFAULT_SECONDARY_ID
	elseif itemDef.Category == "Armor" then
		ledger.ArmorPoints = 0
		ledger.ArmorTier = 0
	elseif itemDef.Category == "Utility" then
		local bitIndex = itemDef.UtilityBitIndex or 0
		ledger.UtilityBitmask = setUtilityBit(ledger.UtilityBitmask, bitIndex, false)
	end

	syncServerLoadoutAttributes(ledger)
	replicateStateToClient(ledger, EconomyConfig.ReasonCodes.SellRefund, paidAmount)
end

-- Unlocks a weapon or utility permanently using persistent Account Flux Shards
local function handleUnlockPermanentItem(ledger: PlayerEconomyLedger, itemId: number): ()
	local itemDef = EconomyConfig.ItemsById[itemId]
	if itemDef == nil or ledger.UnlockedItemIds[itemId] then
		replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
		return
	end

	local fluxCost = itemDef.PermanentUnlockFluxCost
	if fluxCost <= 0 or ledger.AccountFlux < fluxCost then
		replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseDenied, 0)
		return
	end

	ledger.AccountFlux -= fluxCost
	ledger.UnlockedItemIds[itemId] = true
	replicateStateToClient(ledger, EconomyConfig.ReasonCodes.PurchaseSuccess, 0)
end

-- Public API: Absorbs incoming weapon damage via Exo-Shield before applying health reduction
function EconomyManager.AbsorbDamageWithArmor(
	victim: Player,
	rawDamage: number,
	attacker: Player?
): DamageAbsorptionResult
	local ledger = playerLedgers[victim]
	if ledger == nil then
		return {
			HealthDamage = rawDamage,
			ArmorAbsorbed = 0,
			RemainingArmor = 0,
		}
	end

	-- Record damage for assist tracking
	if attacker ~= nil and attacker ~= victim then
		local now = workspace:GetServerTimeNow()
		local existing = ledger.DamageLedger[attacker.UserId]
		if existing ~= nil and (now - existing.LastHitTimestamp) <= EconomyConfig.AssistWindowSeconds then
			existing.DamageDealt += rawDamage
			existing.LastHitTimestamp = now
		else
			ledger.DamageLedger[attacker.UserId] = {
				AttackerUserId = attacker.UserId,
				DamageDealt = rawDamage,
				LastHitTimestamp = now,
			}
		end
	end

	if ledger.ArmorPoints <= 0 then
		return {
			HealthDamage = rawDamage,
			ArmorAbsorbed = 0,
			RemainingArmor = 0,
		}
	end

	local potentialAbsorb = rawDamage * EconomyConfig.ArmorAbsorptionRatio
	local maxAbsorbByCurrentAP = ledger.ArmorPoints / EconomyConfig.ArmorDurabilityCostPerDamage
	local actualAbsorbed = math.min(potentialAbsorb, maxAbsorbByCurrentAP)
	local apConsumed = math.ceil(actualAbsorbed * EconomyConfig.ArmorDurabilityCostPerDamage)

	ledger.ArmorPoints = math.max(0, ledger.ArmorPoints - apConsumed)
	if ledger.ArmorPoints == 0 then
		ledger.ArmorTier = 0
	end

	syncServerLoadoutAttributes(ledger)
	local remainingHealthDamage = math.max(1, math.floor(rawDamage - actualAbsorbed))

	return {
		HealthDamage = remainingHealthDamage,
		ArmorAbsorbed = actualAbsorbed,
		RemainingArmor = ledger.ArmorPoints,
	}
end

-- Public API: Called by CombatValidator.luau when a player scores a confirmed elimination
function EconomyManager.RecordElimination(
	killer: Player,
	victim: Player,
	weaponId: number,
	isHeadshot: boolean,
	killerHorizontalSpeed: number,
	isAirborne: boolean
): ()
	local killerLedger = playerLedgers[killer]
	local victimLedger = playerLedgers[victim]
	local now = workspace:GetServerTimeNow()

	if killerLedger ~= nil and killer ~= victim then
		local weaponDef = EconomyConfig.ItemsById[weaponId]
		local weaponMultiplier = if weaponDef ~= nil then weaponDef.KillAwardMultiplier else 1.0

		local baseCreditAward = math.floor(EconomyConfig.BaseKillReward * weaponMultiplier)
		local totalCreditAward = baseCreditAward
		local totalFluxAward = EconomyConfig.FluxPerStandardKill
		local reasonCode = EconomyConfig.ReasonCodes.KillStandard

		if isHeadshot then
			totalCreditAward += EconomyConfig.HeadshotBonusReward
			totalFluxAward += EconomyConfig.FluxPerHeadshotBonus
		end

		if isAirborne then
			totalCreditAward += EconomyConfig.AirborneKillBonusReward
		end

		-- Velocity-scaled bunny-hop / air-strafe momentum bounty
		if killerHorizontalSpeed >= EconomyConfig.HyperdriveSpeedThreshold then
			totalCreditAward += EconomyConfig.HyperdriveKillBonusReward
			totalFluxAward += EconomyConfig.FluxPerHyperdriveBonus
			reasonCode = EconomyConfig.ReasonCodes.KillHyperdrive
		elseif killerHorizontalSpeed > EconomyConfig.OverdriveSpeedThreshold then
			totalCreditAward += EconomyConfig.OverdriveKillBonusReward
			totalFluxAward += EconomyConfig.FluxPerOverdriveBonus
			reasonCode = EconomyConfig.ReasonCodes.KillOverdrive
		end

		killerLedger.MatchCredits = math.clamp(
			killerLedger.MatchCredits + totalCreditAward,
			0,
			EconomyConfig.MaxMatchCredits
		)
		killerLedger.AccountFlux += totalFluxAward

		replicateStateToClient(killerLedger, reasonCode, totalCreditAward)
	end

	-- Process assist rewards and reset victim equipment on death
	if victimLedger ~= nil then
		for attackerUserId, assistEntry in victimLedger.DamageLedger do
			if attackerUserId ~= killer.UserId and (now - assistEntry.LastHitTimestamp) <= EconomyConfig.AssistWindowSeconds then
				if assistEntry.DamageDealt >= EconomyConfig.AssistDamageThreshold then
					local assister = Players:GetPlayerByUserId(attackerUserId)
					if assister ~= nil then
						local assisterLedger = playerLedgers[assister]
						if assisterLedger ~= nil then
							assisterLedger.MatchCredits = math.clamp(
								assisterLedger.MatchCredits + EconomyConfig.AssistReward,
								0,
								EconomyConfig.MaxMatchCredits
							)
							assisterLedger.AccountFlux += 5
							replicateStateToClient(
								assisterLedger,
								EconomyConfig.ReasonCodes.Assist,
								EconomyConfig.AssistReward
							)
						end
					end
				end
			end
		end

		-- Strip victim's weapons, armor, and utility upon elimination
		table.clear(victimLedger.DamageLedger)
		table.clear(victimLedger.RoundPurchases)
		victimLedger.PrimaryWeaponId = 0
		victimLedger.SecondaryWeaponId = DEFAULT_SECONDARY_ID
		victimLedger.ArmorPoints = 0
		victimLedger.ArmorTier = 0
		victimLedger.UtilityBitmask = 0
		syncServerLoadoutAttributes(victimLedger)
		replicateStateToClient(victimLedger, EconomyConfig.ReasonCodes.RoundStart, 0)
	end
end

-- Public API: Starts a new round, opens the buy window, and schedules buy window expiration
function EconomyManager.BeginRoundBuyPhase(isPistolResetRound: boolean): ()
	isGlobalBuyPhaseActive = true

	for _, ledger in playerLedgers do
		table.clear(ledger.RoundPurchases)
		table.clear(ledger.DamageLedger)
		ledger.BuyPhaseOpen = true

		if isPistolResetRound then
			ledger.MatchCredits = EconomyConfig.StartingMatchCredits
			ledger.LossStreak = 0
			ledger.PrimaryWeaponId = 0
			ledger.SecondaryWeaponId = DEFAULT_SECONDARY_ID
			ledger.ArmorPoints = 0
			ledger.ArmorTier = 0
			ledger.UtilityBitmask = 0
			syncServerLoadoutAttributes(ledger)
		end

		replicateStateToClient(ledger, EconomyConfig.ReasonCodes.RoundStart, 0)
	end

	task.delay(EconomyConfig.BuyPhaseDurationSeconds, function()
		isGlobalBuyPhaseActive = false
		for _, ledger in playerLedgers do
			ledger.BuyPhaseOpen = false
			replicateStateToClient(ledger, EconomyConfig.ReasonCodes.RoundStart, 0)
		end
	end)
end

-- Public API: Distributes round win/loss payouts and updates consecutive loss streaks
function EconomyManager.ResolveRoundOutcome(winningPlayers: { [Player]: boolean }): ()
	for player, ledger in playerLedgers do
		if winningPlayers[player] then
			ledger.LossStreak = 0
			local winAward = EconomyConfig.RoundWinCredits
			ledger.MatchCredits = math.clamp(ledger.MatchCredits + winAward, 0, EconomyConfig.MaxMatchCredits)
			ledger.AccountFlux += EconomyConfig.FluxPerRoundWin
			replicateStateToClient(ledger, EconomyConfig.ReasonCodes.RoundWin, winAward)
		else
			ledger.LossStreak = math.min(4, ledger.LossStreak + 1)
			local lossAward = EconomyConfig.LossStreakRewards[ledger.LossStreak] or 3400
			ledger.MatchCredits = math.clamp(ledger.MatchCredits + lossAward, 0, EconomyConfig.MaxMatchCredits)
			ledger.AccountFlux += EconomyConfig.FluxPerRoundLoss
			replicateStateToClient(ledger, EconomyConfig.ReasonCodes.RoundLoss, lossAward)
		end
	end
end

-- Public API: Initializes the EconomyManager and binds binary RemoteEvent handlers
function EconomyManager.Init(): ()
	local existingRemote = ReplicatedStorage:FindFirstChild("EconomyPacketRemote")
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		economyRemote = existingRemote
	else
		local newRemote = Instance.new("RemoteEvent")
		newRemote.Name = "EconomyPacketRemote"
		newRemote.Parent = ReplicatedStorage
		economyRemote = newRemote
	end

	local activeRemote = economyRemote :: RemoteEvent
	activeRemote.OnServerEvent:Connect(function(player: Player, rawPacket: unknown)
		local ledger = playerLedgers[player]
		if ledger == nil then
			return
		end

		local now = workspace:GetServerTimeNow()
		if (now - ledger.LastRequestTime) < EconomyConfig.RequestRateLimitInterval then
			return
		end

		local decoded = EconomyPacket.decodePurchaseRequest(rawPacket)
		if decoded == nil then
			return
		end

		ledger.LastRequestTime = now
		ledger.LastSequenceId = decoded.SequenceId

		if decoded.ActionType == EconomyConfig.ActionTypes.BuyItem then
			handleBuyItem(ledger, decoded.ItemId)
		elseif decoded.ActionType == EconomyConfig.ActionTypes.SellRefundItem then
			handleSellRefundItem(ledger, decoded.ItemId)
		elseif decoded.ActionType == EconomyConfig.ActionTypes.UnlockPermanentItem then
			handleUnlockPermanentItem(ledger, decoded.ItemId)
		elseif decoded.ActionType == EconomyConfig.ActionTypes.RequestFullSync then
			replicateStateToClient(ledger, EconomyConfig.ReasonCodes.RoundStart, 0)
		end
	end)

	local function onPlayerAdded(player: Player): ()
		local defaultUnlocks: { [number]: boolean } = {}
		for _, itemDef in EconomyConfig.ItemsList do
			if itemDef.PermanentUnlockFluxCost == 0 then
				defaultUnlocks[itemDef.Id] = true
			end
		end

		local newLedger: PlayerEconomyLedger = {
			Player = player,
			MatchCredits = EconomyConfig.StartingMatchCredits,
			LossStreak = 0,
			ArmorPoints = 0,
			ArmorTier = 0,
			PrimaryWeaponId = 0,
			SecondaryWeaponId = DEFAULT_SECONDARY_ID,
			UtilityBitmask = 0,
			BuyPhaseOpen = true,
			RoundPurchases = {},
			LastRequestTime = 0,
			LastSequenceId = 0,
			AccountFlux = 0,
			UnlockedItemIds = defaultUnlocks,
			DamageLedger = {},
		}

		playerLedgers[player] = newLedger
		syncServerLoadoutAttributes(newLedger)

		task.spawn(function()
			loadPersistentProfile(newLedger)
			if playerLedgers[player] ~= nil then
				replicateStateToClient(newLedger, EconomyConfig.ReasonCodes.RoundStart, 0)
			end
		end)
	end

	local function onPlayerRemoving(player: Player): ()
		local ledger = playerLedgers[player]
		if ledger ~= nil then
			playerLedgers[player] = nil
			task.spawn(function()
				savePersistentProfile(ledger)
			end)
		end
	end

	for _, existingPlayer in Players:GetPlayers() do
		task.spawn(onPlayerAdded, existingPlayer)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Periodic background autosave loop
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL_SECONDS)
			for _, ledger in playerLedgers do
				task.spawn(savePersistentProfile, ledger)
			end
		end
	end)

	game:BindToClose(function()
		for _, ledger in playerLedgers do
			savePersistentProfile(ledger)
		end
	end)
end

return table.freeze(EconomyManager)
