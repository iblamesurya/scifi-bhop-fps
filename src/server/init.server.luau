--!strict
-- Server bootstrapper: initializes combat, replication, character, and loadout systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HitboxHistory = require(script.combat.HitboxHistory)
local CombatValidator = require(script.combat.CombatValidator)
local LoadoutService = require(script.combat.LoadoutService)
local CharacterService = require(script.character.CharacterService)
local StanceReplicator = require(script.replication.StanceReplicator)

-- Create RemoteEvents
local shotEvent: RemoteEvent = Instance.new("RemoteEvent")
shotEvent.Name = "ShotEvent"
shotEvent.Parent = ReplicatedStorage

local stanceEvent: UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")
stanceEvent.Name = "StanceEvent"
stanceEvent.Parent = ReplicatedStorage

-- Initialize systems
CharacterService.init()
LoadoutService.init()
CombatValidator.init(shotEvent)
StanceReplicator.init(stanceEvent)

-- Start 60Hz hitbox recording
RunService.Heartbeat:Connect(function(_dt: number): ()
	HitboxHistory.recordSnapshot()
end)

-- Player lifecycle
Players.PlayerAdded:Connect(function(player: Player): ()
	LoadoutService.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player: Player): ()
	LoadoutService.removePlayer(player)
end)

print("[Server] SciFi B-Hop FPS server initialized")
