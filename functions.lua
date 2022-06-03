function boost_cart:get_sign(z)
	if z == 0 then
		return 0
	else
		return z / math.abs(z)
	end
end

function boost_cart:manage_attachment(player, obj)
	if not player then
		return
	end
	local do_attach = obj ~= nil

	if obj and player:get_attach() == obj then
		return
	end

	if boost_cart.PLAYER_API then
		local player_name = player:get_player_name()
		player_api.player_attached[player_name] = do_attach
	end

	if do_attach then
		player:set_attach(obj, "", {x=0, y=-4, z=0}, {x=0, y=0, z=0})
		player:set_eye_offset({x=0, y=-4, z=0},{x=0, y=-4, z=0})

		if boost_cart.PLAYER_API then
			-- player_api does not update the animation
			-- when the player is attached, reset to default animation
			player_api.set_animation(player, "stand")
		end
	else
		player:set_detach()
		player:set_eye_offset({x=0, y=0, z=0},{x=0, y=0, z=0})
		-- HACK in effect! Force updating the attachment rotation
		player:set_properties({})
	end
end

function boost_cart:velocity_to_dir(v)
	if math.abs(v.x) > math.abs(v.z) then
		return {x=self:get_sign(v.x), y=self:get_sign(v.y), z=0}
	else
		return {x=0, y=self:get_sign(v.y), z=self:get_sign(v.z)}
	end
end

local get_node = minetest.get_node
local get_item_group = minetest.get_item_group
function boost_cart:is_rail(pos, railtype)
	local node = get_node(pos).name
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
	if get_item_group(node, "rail") == 0 then
		return false
	end
	if not railtype then
		return true
	end
	return get_item_group(node, "connect_to_raillike") == railtype
end

function boost_cart:check_front_up_down(pos, dir_, check_up, railtype)
	local dir = vector.new(dir_)
	local cur = nil

	-- Front
	dir.y = 0
	cur = vector.add(pos, dir)
	if self:is_rail(cur, railtype) then
		return dir
	end
	-- Up
	if check_up then
		dir.y = 1
		cur = vector.add(pos, dir)
		if self:is_rail(cur, railtype) then
			return dir
		end
	end
	-- Down
	dir.y = -1
	cur = vector.add(pos, dir)
	if self:is_rail(cur, railtype) then
		return dir
	end
	return nil
end

function boost_cart:get_rail_direction(pos_, dir, ctrl, old_switch, railtype)
	local pos = vector.round(pos_)
	local cur = nil
	local left_check, right_check = true, true

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

	local straight_priority = ctrl and dir.y ~= 0

	-- Normal, to disallow rail switching up- & downhill
	if straight_priority then
		cur = self:check_front_up_down(pos, dir, true, railtype)
		if cur then
			return cur
		end
	end

	if ctrl then
		if old_switch == 1 then
			left_check = false
		elseif old_switch == 2 then
			right_check = false
		end
		if ctrl.left and left_check then
			cur = self:check_front_up_down(pos, left, false, railtype)
			if cur then
				return cur, 1
			end
			left_check = false
		end
		if ctrl.right and right_check then
			cur = self:check_front_up_down(pos, right, false, railtype)
			if cur then
				return cur, 2
			end
			right_check = true
		end
	end

	-- Normal
	if not straight_priority then
		cur = self:check_front_up_down(pos, dir, true, railtype)
		if cur then
			return cur
		end
	end

	-- Left, if not already checked
	if left_check then
		cur = self:check_front_up_down(pos, left, false, railtype)
		if cur then
			return cur
		end
	end

	-- Right, if not already checked
	if right_check then
		cur = self:check_front_up_down(pos, right, false, railtype)
		if cur then
			return cur
		end
	end

	-- Backwards
	if not old_switch then
		cur = self:check_front_up_down(pos, {
				x = -dir.x,
				y = dir.y,
				z = -dir.z
			}, true, railtype)
		if cur then
			return cur
		end
	end

	return {x=0, y=0, z=0}
end

function boost_cart:pathfinder(pos_, old_pos, old_dir, distance, ctrl,
		pf_switch, railtype)

	local pos = vector.round(pos_)
	if vector.equals(old_pos, pos) then
		return
	end

	local pf_pos = vector.round(old_pos)
	local pf_dir = vector.new(old_dir)
	distance = math.min(boost_cart.path_distance_max,
		math.floor(distance + 1))

	for i = 1, distance do
		pf_dir, pf_switch = self:get_rail_direction(
			pf_pos, pf_dir, ctrl, pf_switch or 0, railtype)

		if vector.equals(pf_dir, {x=0, y=0, z=0}) then
			-- No way forwards
			return pf_pos, pf_dir
		end

		pf_pos = vector.add(pf_pos, pf_dir)

		if vector.equals(pf_pos, pos) then
			-- Success! Cart moved on correctly
			return
		end
	end
	-- Not found. Put cart to predicted position
	return pf_pos, pf_dir
end

function boost_cart:boost_rail(pos, amount)
	minetest.get_meta(pos):set_string("cart_acceleration", tostring(amount))
	for _,obj_ in ipairs(minetest.get_objects_inside_radius(pos, 0.5)) do
		if not obj_:is_player() and
				obj_:get_luaentity() and
				obj_:get_luaentity().name == "carts:cart" then
			obj_:get_luaentity():on_punch()
		end
	end
end

function boost_cart:register_rail(name, def_overwrite)
	local sound_func = default.node_sound_metal_defaults
		or default.node_sound_defaults

	local def = {
		drawtype = "raillike",
		paramtype = "light",
		sunlight_propagates = true,
		is_ground_content = false,
		walkable = false,
		selection_box = {
			type = "fixed",
			fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
		},
		sounds = sound_func()
	}
	for k, v in pairs(def_overwrite) do
		def[k] = v
	end
	if not def.inventory_image then
		def.wield_image = def.tiles[1]
		def.inventory_image = def.tiles[1]
	end

	minetest.register_node(name, def)
end

function boost_cart:get_rail_groups(additional_groups)
	-- Get the default rail groups and add more when a table is given
	local groups = {
		dig_immediate = 2,
		attached_node = 1,
		rail = 1,
		connect_to_raillike = 1
	}
	if minetest.raillike_group then
		groups.connect_to_raillike = minetest.raillike_group("rail")
	end
	if type(additional_groups) == "table" then
		for k, v in pairs(additional_groups) do
			groups[k] = v
		end
	end
	return groups
end
