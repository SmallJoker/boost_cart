function boost_cart:get_sign(z)
	if z == 0 then
		return 0
	else
		return z / math.abs(z)
	end
end

function boost_cart:velocity_to_dir(v)
	if math.abs(v.x) > math.abs(v.z) then
		return {x=boost_cart:get_sign(v.x), y=boost_cart:get_sign(v.y), z=0}
	else
		return {x=0, y=boost_cart:get_sign(v.y), z=boost_cart:get_sign(v.z)}
	end
end

function boost_cart:is_rail(pos)
	local node = minetest.get_node(pos).name
	return minetest.get_item_group(node, "rail") ~= 0
end

function boost_cart:get_rail_direction(pos_, dir_)
	local pos = vector.round(pos_)
	local dir = vector.new(dir_)
	local cur = nil
	
	-- Front
	dir.y = 0
	cur = vector.add(pos, dir)
	if boost_cart:is_rail(cur) then
		return dir
	end
	
	-- Down
	dir.y = -1
	cur = vector.add(pos, dir)
	if boost_cart:is_rail(cur) then
		return dir
	end
	
	-- Up
	dir.y = 1
	cur = vector.add(pos, dir)
	if boost_cart:is_rail(cur) then
		return dir
	end
	
	-- Left, right
	dir.y = 0
	
	-- Check left and right
	local view, opposite, val
	
	if dir.x == 0 and dir.z ~= 0 then
		view = "z"
		other = "x"
		if dir.z < 0 then
			val = {1, -1}
		else
			val = {-1, 1}
		end
	elseif dir.z == 0 and dir.x ~= 0 then
		view = "x"
		other = "z"
		if dir.x > 0 then
			val = {1, -1}
		else
			val = {-1, 1}
		end
	else
		return {x=0, y=0, z=0}
	end
	
	dir[view] = 0
	dir[other] = val[1]
	cur = vector.add(pos, dir)
	if boost_cart:is_rail(cur) then
		return dir
	end
	
	-- Down
	dir.y = -1
	cur = vector.add(pos, dir)
	if boost_cart:is_rail(cur) then
		return dir
	end
	dir.y = 0
	
	dir[other] = val[2]
	cur = vector.add(pos, dir)
	if boost_cart:is_rail(cur) then
		return dir
	end
	
	-- Down
	dir.y = -1
	cur = vector.add(pos, dir)
	if boost_cart:is_rail(cur) then
		return dir
	end
	
	return {x=0, y=0, z=0}
end
