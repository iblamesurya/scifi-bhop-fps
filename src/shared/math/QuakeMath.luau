--!strict
-- Shared vector projection accelerate() and applyFriction() (Quake/Source engine math)

local QuakeMath = {}

function QuakeMath.accelerate(currentVel: Vector3, wishDir: Vector3, wishSpeed: number, accel: number, dt: number): Vector3
	local currentSpeed: number = currentVel:Dot(wishDir)
	local addSpeed: number = wishSpeed - currentSpeed
	if addSpeed <= 0 then
		return currentVel
	end
	local accelSpeed: number = math.min(accel * wishSpeed * dt, addSpeed)
	return currentVel + wishDir * accelSpeed
end

function QuakeMath.applyFriction(velocity: Vector3, friction: number, dt: number): Vector3
	local speed: number = velocity.Magnitude
	if speed < 0.1 then
		return Vector3.zero
	end
	local drop: number = speed * friction * dt
	local newSpeed: number = math.max(speed - drop, 0)
	return velocity * (newSpeed / speed)
end

function QuakeMath.getHorizontalSpeed(velocity: Vector3): number
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

function QuakeMath.clampHorizontalSpeed(velocity: Vector3, maxSpeed: number): Vector3
	local horizontal: Vector3 = Vector3.new(velocity.X, 0, velocity.Z)
	local hSpeed: number = horizontal.Magnitude
	if hSpeed <= maxSpeed then
		return velocity
	end
	local scale: number = maxSpeed / hSpeed
	return Vector3.new(velocity.X * scale, velocity.Y, velocity.Z * scale)
end

return QuakeMath
