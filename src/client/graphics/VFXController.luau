--!strict
-- Muzzle flash and impact particle dispatcher

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetRegistry = require(ReplicatedStorage:WaitForChild("Shared").configs.AssetRegistry)

local VFXController = {}

local impactTemplate: Instance? = nil

function VFXController.init(): ()
	impactTemplate = AssetRegistry.VFX.ImpactSparks
end

function VFXController.playMuzzleFlash(attachment: Attachment): ()
	-- Enable all ParticleEmitters on the attachment briefly
	for _, child: Instance in attachment:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local emitter: ParticleEmitter = child
			emitter:Emit(emitter.Rate)
		end
	end

	-- Also handle lights
	for _, child: Instance in attachment:GetChildren() do
		if child:IsA("PointLight") or child:IsA("SpotLight") then
			(child :: PointLight).Enabled = true
			task.delay(0.06, function(): ()
				(child :: PointLight).Enabled = false
			end)
		end
	end
end

function VFXController.playImpactSparks(position: Vector3, normal: Vector3): ()
	if not impactTemplate then
		return
	end

	local impact: Instance = impactTemplate:Clone()
	local part: BasePart? = impact:IsA("BasePart") and impact :: BasePart or impact:FindFirstChildWhichIsA("BasePart") :: BasePart?
	if part then
		part.CFrame = CFrame.lookAt(position, position + normal)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Parent = workspace

		-- Emit particles
		for _, child: Instance in impact:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child:Emit(child.Rate)
			end
		end

		-- Clean up
		task.delay(1.5, function(): ()
			impact:Destroy()
		end)
	end
end

return VFXController
