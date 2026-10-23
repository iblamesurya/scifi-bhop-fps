--!strict
-- 3D Hooke's Law damped harmonic oscillator (8x substepped)

local SUBSTEPS: number = 8

export type Spring = {
	Position: Vector3,
	Velocity: Vector3,
	Target: Vector3,
	Stiffness: number,
	Damping: number,
	Update: (self: Spring, dt: number) -> (),
	Impulse: (self: Spring, force: Vector3) -> (),
	Reset: (self: Spring) -> (),
}

local SpringClass = {}
SpringClass.__index = SpringClass

function SpringClass.new(stiffness: number, damping: number): Spring
	local self = setmetatable({}, SpringClass)
	self.Position = Vector3.zero
	self.Velocity = Vector3.zero
	self.Target = Vector3.zero
	self.Stiffness = stiffness
	self.Damping = damping
	return self :: any
end

function SpringClass.Update(self: Spring, dt: number): ()
	local subDt: number = dt / SUBSTEPS
	for _ = 1, SUBSTEPS do
		local displacement: Vector3 = self.Position - self.Target
		local springForce: Vector3 = -displacement * self.Stiffness
		local dampForce: Vector3 = -self.Velocity * self.Damping
		local acceleration: Vector3 = springForce + dampForce
		self.Velocity += acceleration * subDt
		self.Position += self.Velocity * subDt
	end
end

function SpringClass.Impulse(self: Spring, force: Vector3): ()
	self.Velocity += force
end

function SpringClass.Reset(self: Spring): ()
	self.Position = Vector3.zero
	self.Velocity = Vector3.zero
	self.Target = Vector3.zero
end

return SpringClass
