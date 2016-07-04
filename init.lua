
boost_cart = {}
boost_cart.modpath = minetest.get_modpath("boost_cart")

-- Maximal speed of the cart in m/s
boost_cart.speed_max = 10
-- Set to nil to disable punching the cart from inside (min = -1)
boost_cart.punch_speed_min = 7


if not boost_cart.modpath then
	error("\nWrong mod directory name! Please change it to 'boost_cart'.\n" ..
			"See also: http://dev.minetest.net/Installing_Mods")
end

function vector.floor(v)
	return {
		x = math.floor(v.x),
		y = math.floor(v.y),
		z = math.floor(v.z)
	}
end

dofile(boost_cart.modpath.."/functions.lua")
dofile(boost_cart.modpath.."/rails.lua")

if mesecon then
	dofile(boost_cart.modpath.."/detector.lua")
end

-- Support for non-default games
if not default.player_attached then
	default.player_attached = {}
end

boost_cart.cart = {
	physical = false,
	collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	visual = "mesh",
	mesh = "cart.x",
	visual_size = {x=1, y=1},
	textures = {"cart.png"},

	driver = nil,
	punched = false, -- used to re-send velocity and position
	velocity = {x=0, y=0, z=0}, -- only used on punch
	old_dir = {x=0, y=0, z=0},
	old_pos = nil,
	old_switch = 0,
	railtype = nil,
	attached_items = {}
}

function boost_cart.cart:on_rightclick(clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local player_name = clicker:get_player_name()
	if self.driver and player_name == self.driver then
		self.driver = nil
		boost_cart:manage_attachment(clicker, false)
	elseif not self.driver then
		self.driver = player_name
		boost_cart:manage_attachment(clicker, true, self.object)
	end
end

function boost_cart.cart:on_activate(staticdata, dtime_s)
	self.object:set_armor_groups({immortal=1})
	if string.sub(staticdata, 1, string.len("return")) ~= "return" then
		return
	end
	local data = minetest.deserialize(staticdata)
	if not data or type(data) ~= "table" then
		return
	end
	self.railtype = data.railtype
end

function boost_cart.cart:get_staticdata()
	return minetest.serialize({
		railtype = self.railtype
	})
end

function boost_cart.cart:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	local pos = self.object:getpos()
	if not self.railtype then
		local bar = vector.floor(vector.add(pos, 0.1))
		local node = minetest.get_node(bar).name
		self.railtype = minetest.get_item_group(node, "connect_to_raillike")
	end

	if not puncher or not puncher:is_player() then
		local cart_dir = boost_cart:get_rail_direction(pos, {x=1, y=0, z=0}, nil, nil, self.railtype)
		if vector.equals(cart_dir, {x=0, y=0, z=0}) then
			return
		end
		self.velocity = vector.multiply(cart_dir, 3)
		self.old_pos = nil
		self.punched = true
		return
	end

	if puncher:get_player_control().sneak then
		-- Pick up cart: Drop all attachments
		if self.driver then
			if self.old_pos then
				self.object:setpos(self.old_pos)
			end
			local player = minetest.get_player_by_name(self.driver)
			boost_cart:manage_attachment(player, false)
		end
		for _,obj_ in ipairs(self.attached_items) do
			if obj_ then
				obj_:set_detach()
			end
		end

		local leftover = puncher:get_inventory():add_item("main", "carts:cart")
		if not leftover:is_empty() then
			minetest.add_item(self.object:getpos(), leftover)
		end
		self.object:remove()
		return
	end

	local vel = self.object:getvelocity()
	if puncher:get_player_name() == self.driver then
		if math.abs(vel.x + vel.z) > boost_cart.punch_speed_min then
			return
		end
	end

	local punch_dir = boost_cart:velocity_to_dir(puncher:get_look_dir())
	punch_dir.y = 0
	local cart_dir = boost_cart:get_rail_direction(pos, punch_dir, nil, nil, self.railtype)
	if vector.equals(cart_dir, {x=0, y=0, z=0}) then
		return
	end

	local punch_interval = 1
	if tool_capabilities and tool_capabilities.full_punch_interval then
		punch_interval = tool_capabilities.full_punch_interval
	end
	time_from_last_punch = math.min(time_from_last_punch or punch_interval, punch_interval)
	local f = 3 * (time_from_last_punch / punch_interval)

	self.velocity = vector.multiply(cart_dir, f)
	self.old_pos = nil
	self.punched = true
end

function boost_cart.cart:on_step(dtime)
	local vel = self.object:getvelocity()
	local update = {}
	if self.punched then
		vel = vector.add(vel, self.velocity)
		self.object:setvelocity(vel)
		self.old_dir.y = 0
	elseif vector.equals(vel, {x=0, y=0, z=0}) then
		return
	end

	-- dir:         New moving direction of the cart
	-- last_switch: Currently pressed L/R key, used to ignore the key on the next rail node
	local dir, last_switch
	local pos = self.object:getpos()

	if self.old_pos and not self.punched then
		local flo_pos = vector.round(pos)
		local flo_old = vector.round(self.old_pos)
		if vector.equals(flo_pos, flo_old) then
			-- Do not check one node multiple times
			return
		end
	end

	local ctrl, player

	-- Get player controls
	if self.driver then
		player = minetest.get_player_by_name(self.driver)
		if player then
			ctrl = player:get_player_control()
		end
	end

	if self.old_pos then
		-- Detection for "skipping" nodes
		local expected_pos = vector.add(self.old_pos, self.old_dir)
		local found_path = boost_cart:pathfinder(pos, expected_pos, self.old_dir, ctrl, self.old_switch, self.railtype)

		if not found_path then
			-- No rail found: reset back to the expected position
			pos = expected_pos
			update.pos = true
		end
	end

	if vel.y == 0 then
		-- Stop cart completely (do not swing)
		for _,v in ipairs({"x", "z"}) do
			if vel[v] ~= 0 and math.abs(vel[v]) < 0.9 then
				vel[v] = 0
				update.vel = true
			end
		end
	end

	local cart_dir = boost_cart:velocity_to_dir(vel)
	local max_vel = boost_cart.speed_max
	if not dir then
		dir, last_switch = boost_cart:get_rail_direction(pos, cart_dir, ctrl, self.old_switch, self.railtype)
	end

	local new_acc = {x=0, y=0, z=0}
	if vector.equals(dir, {x=0, y=0, z=0}) then
		vel = {x=0, y=0, z=0}
		pos = vector.round(pos)
		update.pos = true
		update.vel = true
	else
		-- If the direction changed
		if dir.x ~= 0 and self.old_dir.z ~= 0 then
			vel.x = dir.x * math.abs(vel.z)
			vel.z = 0
			pos.z = math.floor(pos.z + 0.5)
			update.pos = true
		end
		if dir.z ~= 0 and self.old_dir.x ~= 0 then
			vel.z = dir.z * math.abs(vel.x)
			vel.x = 0
			pos.x = math.floor(pos.x + 0.5)
			update.pos = true
		end
		-- Up, down?
		if dir.y ~= self.old_dir.y then
			vel.y = dir.y * math.abs(vel.x + vel.z)
			pos = vector.round(pos)
			update.pos = true
		end

		-- Slow down or speed up..
		local acc = dir.y * -1.8

		local speed_mod = tonumber(minetest.get_meta(pos):get_string("cart_acceleration"))
		if speed_mod and speed_mod ~= 0 then
			if speed_mod > 0 then
				for _,v in ipairs({"x","y","z"}) do
					if math.abs(vel[v]) >= max_vel then
						speed_mod = 0
						break
					end
				end
			end
			-- Try to make it similar to the original carts mod
			acc = acc + (speed_mod * 10)
		else
			acc = acc - 0.4
			-- Handbrake
			if ctrl and ctrl.down and math.abs(vel.x + vel.z) > 1.2 then
				acc = acc - 1.2
			end
		end

		new_acc = vector.multiply(dir, acc)
	end

	if mesecon then
		boost_cart:signal_detector_rail(vector.round(pos))
	end

	-- Limits
	for _,v in ipairs({"x","y","z"}) do
		if math.abs(vel[v]) > max_vel then
			vel[v] = boost_cart:get_sign(vel[v]) * max_vel
			new_acc[v] = 0
			update.vel = true
		end
	end
	
	self.object:setacceleration(new_acc)
	self.old_pos = vector.new(pos)
	self.old_dir = vector.new(dir)
	self.old_switch = last_switch


	if self.punched then
		-- Collect dropped items
		for _,obj_ in ipairs(minetest.get_objects_inside_radius(pos, 1)) do
			if not obj_:is_player() and
					obj_:get_luaentity() and
					not obj_:get_luaentity().physical_state and
					obj_:get_luaentity().name == "__builtin:item" then
				obj_:set_attach(self.object, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
				self.attached_items[#self.attached_items + 1] = obj_
			end
		end
		self.punched = false
	end

	if not (update.vel or update.pos) then
		return
	end

	local yaw = 0
	if dir.x < 0 then
		yaw = 0.5
	elseif dir.x > 0 then
		yaw = 1.5
	elseif dir.z < 0 then
		yaw = 1
	end
	self.object:setyaw(yaw * math.pi)

	local anim = {x=0, y=0}
	if dir.y == -1 then
		anim = {x=1, y=1}
	elseif dir.y == 1 then
		anim = {x=2, y=2}
	end
	self.object:set_animation(anim, 1, 0)

	self.object:setvelocity(vel)
	if update.pos then
		self.object:setpos(pos)
	end
	update = nil
end

minetest.register_entity(":carts:cart", boost_cart.cart)
minetest.register_craftitem(":carts:cart", {
	description = "Cart (Sneak+Click to pick up)",
	inventory_image = minetest.inventorycube("cart_top.png", "cart_side.png", "cart_side.png"),
	wield_image = "cart_side.png",
	on_place = function(itemstack, placer, pointed_thing)
		if not pointed_thing.type == "node" then
			return
		end
		if boost_cart:is_rail(pointed_thing.under) then
			minetest.add_entity(pointed_thing.under, "carts:cart")
		elseif boost_cart:is_rail(pointed_thing.above) then
			minetest.add_entity(pointed_thing.above, "carts:cart")
		else return end

		itemstack:take_item()
		return itemstack
	end,
})

minetest.register_craft({
	output = "carts:cart",
	recipe = {
		{"default:steel_ingot", "", "default:steel_ingot"},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
	},
})