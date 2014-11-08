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
	if node == "ignore" then
		local vm = minetest.get_voxel_manip()
		local emin, emax = vm:read_from_map(pos, pos)
		local area = VoxelArea:new{
			MinEdge = emin,
			MaxEdge = emax,
		}
		local data = vm:get_data()
		local vi = area:indexp(pos)
		node = minetest.get_name_from_content_id(data[vi])
	end
	return minetest.get_item_group(node, "rail") ~= 0
end

function boost_cart:check_front_up_down(pos, dir, onlyDown)
	local cur = nil
	
	-- Front
	dir.y = 0
	cur = vector.add(pos, dir)
	if boost_cart:is_rail(cur) then
		return dir
	end
	-- Up
	if not onlyDown then
		dir.y = 1
		cur = vector.add(pos, dir)
		if boost_cart:is_rail(cur) then
			return dir
		end
	end
	-- Down
	dir.y = -1
	cur = vector.add(pos, dir)
	if boost_cart:is_rail(cur) then
		return dir
	end
	return nil
end

function boost_cart:get_rail_direction(pos_, dir_, ctrl, old_switch)
	local pos = vector.round(pos_)
	local dir = vector.new(dir_)
	local cur = nil
	local left_check, right_check = true, true
	old_switch = old_switch or 0
	
	-- Check left and right
	local left = {x=0, y=0, z=0}
	local right = {x=0, y=0, z=0}
	if dir.z ~= 0 and dir.x == 0 then
		left.x = -dir.z
		right.x = dir.z
	elseif dir.x ~= 0 and dir.z == 0 then
		left.z = dir.x
		right.z = -dir.x
	end
	
	if ctrl then
		if old_switch == 1 then
			left_check = false
		elseif old_switch == 2 then
			right_check = false
		end
		if ctrl.left and left_check then
			cur = boost_cart:check_front_up_down(pos, left, true)
			if cur then
				return cur, 1
			end
			left_check = false
		end
		if ctrl.right and right_check then
			cur = boost_cart:check_front_up_down(pos, right, true)
			if cur then
				return cur, 2
			end
			right_check = true
		end
	end
	
	-- Normal
	cur = boost_cart:check_front_up_down(pos, dir)
	if cur then
		return cur
	end
	
	-- Left, if not already checked
	if left_check then
		cur = boost_cart:check_front_up_down(pos, left, true)
		if cur then
			return cur
		end
	end
	
	-- Right, if not already checked
	if right_check then
		cur = boost_cart:check_front_up_down(pos, right, true)
		if cur then
			return cur
		end
	end
	
	return {x=0, y=0, z=0}
end

