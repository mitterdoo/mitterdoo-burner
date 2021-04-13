function ENT:WriteCell( addr, value )

	--[[

		[0-4094] = write to our memory
		[4095] = read-only

	]]

	if addr < 0 or addr >= 4095 then return false end
	self.Memory[ addr ] = value
	return true

end

function ENT:ReadCell( addr )

	--[[

		[0-4094] = if there is a destination, reads from destination. otherwise, reads from our own memory
		[4095] = 0 or 1; is 1 when reading from destination

	]]

	if addr < 0 or addr >= 4096 then return end
	local dest = self:GetDestination()

	local valid = self:DestValid()
	if addr == 4095 then
		return valid and 1 or 0
	end

	if valid then
		return dest.Memory[addr]
	else
		return self.Memory[addr]
	end

end
