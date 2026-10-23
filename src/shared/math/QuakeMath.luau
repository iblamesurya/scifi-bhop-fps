--!strict
--[[
	QuakeMath.luau
	Pure vector math library implementing Quake III / Source Engine air-strafe
	dot-product velocity projection, ground friction decay, and planar speed clamping.
]]

local STOP_SPEED_DEFAULT = 10

local QuakeMath = {}

--[[
	Projects currentVel onto wishDir and adds acceleration up to wishSpeed.
	Because projection uses the dot product (currentVel:Dot(wishDir)), strafing
	nearly perpendicular to currentVel yields a small currentSpeed projection,
	allowing total planar speed to exceed wishSpeed during air-strafing.
]]
function QuakeMath.Accelerate(
	currentVel: Vector3,
	wishDir: Vector3,
	wishSpeed: number,
	accel: number,
	dt: number
): Vector3
	local planarWish = Vector3.new(wishDir.X, 0, wishDir.Z)
	if planarWish.Magnitude <= 1e-6 or wishSpeed <= 0 or dt <= 0 then
		return currentVel
	end
	local unitWish = planarWish.Unit

	local currentSpeed = currentVel:Dot(unitWish)
	local addSpeed = wishSpeed - currentSpeed
	if addSpeed <= 0 then
		return currentVel
	end

	local accelSpeed = accel * dt * wishSpeed
	if accelSpeed > addSpeed then
		accelSpeed = addSpeed
	end

	return currentVel + (unitWish * accelSpeed)
end

--[[
	Applies Quake/Source ground friction to the horizontal (XZ) components of currentVel
	while preserving vertical (Y) velocity.
]]
function QuakeMath.ApplyFriction(
	currentVel: Vector3,
	friction: number,
	dt: number,
	stopSpeed: number?
): Vector3
	local planarVel = Vector3.new(currentVel.X, 0, currentVel.Z)
	local speed = planarVel.Magnitude
	if speed <= 1e-5 or dt <= 0 or friction <= 0 then
		return Vector3.new(0, currentVel.Y, 0)
	end

	local effectiveStopSpeed = stopSpeed or STOP_SPEED_DEFAULT
	local control = if speed < effectiveStopSpeed then effectiveStopSpeed else speed
	local drop = control * friction * dt

	local newSpeed = speed - drop
	if newSpeed < 0 then
		newSpeed = 0
	end

	local scale = newSpeed / speed
	return Vector3.new(currentVel.X * scale, currentVel.Y, currentVel.Z * scale)
end

--[[
	Hard-clamps horizontal (XZ) speed to maxSpeed while preserving vertical (Y) velocity.
]]
function QuakeMath.ClampPlanarSpeed(vel: Vector3, maxSpeed: number): Vector3
	if maxSpeed <= 0 then
		return Vector3.new(0, vel.Y, 0)
	end

	local planarVel = Vector3.new(vel.X, 0, vel.Z)
	local planarSpeed = planarVel.Magnitude
	if planarSpeed <= maxSpeed or planarSpeed <= 1e-6 then
		return vel
	end

	local clampedPlanar = planarVel.Unit * maxSpeed
	return Vector3.new(clampedPlanar.X, vel.Y, clampedPlanar.Z)
end

return table.freeze(QuakeMath)
