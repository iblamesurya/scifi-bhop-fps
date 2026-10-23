--!strict
--[[
	Spring.luau
	3D Hooke's Law damped harmonic oscillator with 8 fixed substeps per update.
	Used for procedural viewmodel sway, recoil kick, landing bob, and camera tilt.
]]

local ITERATIONS = 8

local Spring = {}
Spring.__index = Spring

export type Spring = typeof(setmetatable(
	{} :: {
		Target: Vector3,
		Position: Vector3,
		Velocity: Vector3,
		Mass: number,
		Force: number,
		Damping: number,
		Speed: number,
	},
	Spring
))

function Spring.new(mass: number?, force: number?, damping: number?, speed: number?): Spring
	local self = setmetatable({
		Target = Vector3.zero,
		Position = Vector3.zero,
		Velocity = Vector3.zero,
		Mass = mass or 5,
		Force = force or 50,
		Damping = damping or 4,
		Speed = speed or 4,
	}, Spring)

	return self
end

function Spring.Shove(self: Spring, impulse: Vector3): ()
	local x = impulse.X
	local y = impulse.Y
	local z = impulse.Z

	if x ~= x or x == math.huge or x == -math.huge then
		x = 0
	end
	if y ~= y or y == math.huge or y == -math.huge then
		y = 0
	end
	if z ~= z or z == math.huge or z == -math.huge then
		z = 0
	end

	self.Velocity += Vector3.new(x, y, z)
end

function Spring.Update(self: Spring, dt: number): Vector3
	local scaledDeltaTime = math.min(dt, 0.1) * self.Speed / ITERATIONS
	local mass = math.max(self.Mass, 1e-4)
	local force = self.Force
	local damping = self.Damping
	local target = self.Target
	local position = self.Position
	local velocity = self.Velocity

	for _ = 1, ITERATIONS do
		local displacement = target - position
		local acceleration = (displacement * force) / mass - velocity * damping

		velocity += acceleration * scaledDeltaTime
		position += velocity * scaledDeltaTime
	end

	self.Position = position
	self.Velocity = velocity

	return position
end

function Spring.Reset(self: Spring): ()
	self.Target = Vector3.zero
	self.Position = Vector3.zero
	self.Velocity = Vector3.zero
end

return table.freeze(Spring)
