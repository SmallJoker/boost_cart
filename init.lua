-- TODO:
--  Add a todo list

boost_cart = {}
boost_cart.modpath = minetest.get_modpath("boost_cart")
boost_cart.speed_max = 11

function vector.floor(v)
	return {
		x = math.floor(v.x),
		y = math.floor(v.y),
		z = math.floor(v.z)
	}
end

dofile(boost_cart.modpath.."/functions.lua")
dofile(boost_cart.modpath.."/rails.lua")

boost_cart.cart = {
	physical = false,
	collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	visual = "mesh",
	mesh = "cart.x",
	visual_size = {x=1, y=1},
	textures = {"cart.png"},
	
	driver = nil,
	punch = false, -- used to re-send velocity and position
	velocity = {x=0, y=0, z=0}, -- only used on punch
	old_dir = {x=0, y=0, z=0},
	old_pos = nil,
	old_switch = nil,
	attached_items = {}
}

function boost_cart.cart:on_rightclick(clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local player_name = clicker:get_player_name()
	if self.driver and player_name == self.driver then
		self.driver = nil
		clicker:set_detach()
	elseif not self.driver then
		self.driver = player_name
		default.player_attached[player_name] = true
		clicker:set_attach(self.object, "", {x=0, y=3, z=0}, {x=0, y=0, z=0})
	end
end

function boost_cart.cart:on_activate(staticdata, dtime_s)
	self.object:set_armor_groups({immortal=1})
end

function boost_cart.cart:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	if not puncher or not puncher:is_player() then
		return
	end

	if puncher:get_player_control().sneak then
		if self.driver then
			if self.old_pos then
				self.object:setpos(self.old_pos)
			end
			default.player_attached[self.driver] = nil
			local player = minetest.get_player_by_name(self.driver)
			if player then
				player:set_detach()
			end
		end
		for _,obj_ in ipairs(self.attached_items) do
			if obj_ then
				obj_:set_detach()
			end
		end
		
		self.object:remove()
		puncher:get_inventory():add_item("main", "carts:cart")
		return
	end
	
	local vel = self.object:getvelocity()
	if puncher:get_player_name() == self.driver then
		if math.abs(vel.x) + math.abs(vel.z) > 6 then
			return
		end
	end
	
	local cart_dir = boost_cart:velocity_to_dir(direction)
	if cart_dir.x == 0 and cart_dir.z == 0 then
		local fd = minetest.dir_to_facedir(puncher:get_look_dir())
		if fd == 0 then
			cart_dir.x = 1
		elseif fd == 1 then
			cart_dir.z = -1
		elseif fd == 2 then
			cart_dir.x = -1
		elseif fd == 3 then
			cart_dir.z = 1
		end
	end

	if time_from_last_punch > tool_capabilities.full_punch_interval then
		time_from_last_punch = tool_capabilities.full_punch_interval
	end
	local dir = boost_cart:get_rail_direction(self.object:getpos(), cart_dir)
	
	if vector.equals(dir, {x=0, y=0, z=0}) then
		return
	end
	
	local f = 4 * (time_from_last_punch / tool_capabilities.full_punch_interval)
	vel.x = dir.x * f
	vel.y = dir.y * f
	vel.z = dir.z * f
	self.velocity = vel
	self.old_pos = nil
	self.punch = true
end

function boost_cart.cart:on_step(dtime)
	local vel = self.object:getvelocity()
	local is_realpunch = self.punch
	if self.punch then
		vel = vector.add(vel, self.velocity)
		self.velocity = {x=0, y=0, z=0}
	elseif vector.equals(vel, {x=0, y=0, z=0}) then
		return
	end
	
	local dir, last_switch = nil, nil
	local pos = self.object:getpos()
	if self.old_pos and not self.punch then
		local flo_pos = vector.floor(pos)
		local flo_old = vector.floor(self.old_pos)
		if vector.equals(flo_pos, flo_old) then
			return
		end
	end
	local ctrl = nil
	if self.driver then
		local player = minetest.get_player_by_name(self.driver)
		if player then
			ctrl = player:get_player_control()
		end
	end
	if self.old_pos then
		local diff = vector.subtract(self.old_pos, pos)
		for _,v in ipairs({"x","y","z"}) do
			if math.abs(diff[v]) > 1.1 then
				local expected_pos = vector.add(self.old_pos, self.old_dir)
				dir, last_switch = boost_cart:get_rail_direction(pos, self.old_dir, ctrl, self.old_switch)
				if vector.equals(dir, {x=0, y=0, z=0}) then
					dir = false
					pos = vector.new(expected_pos)
					self.punch = true
				end
				break
			end
		end
	end
	
	if vel.y == 0 then
		for _,v in ipairs({"x", "z"}) do
			if vel[v] ~= 0 and math.abs(vel[v]) < 0.9 then
				vel[v] = 0
				self.punch = true
			end
		end
	end
	
	local cart_dir = {
		x = boost_cart:get_sign(vel.x),
		y = boost_cart:get_sign(vel.y),
		z = boost_cart:get_sign(vel.z)
	}
	
	local max_vel = boost_cart.speed_max
	if not dir then
		dir, last_switch = boost_cart:get_rail_direction(pos, cart_dir, ctrl, self.old_switch)
	end
	
	local new_acc = {x=0, y=0, z=0}
	if vector.equals(dir, {x=0, y=0, z=0}) then
		vel = {x=0, y=0, z=0}
		self.punch = true
	else
		-- If the direction changed
		if dir.x ~= 0 and self.old_dir.z ~= 0 then
			vel.x = dir.x * math.abs(vel.z)
			vel.z = 0
			pos.z = math.floor(pos.z + 0.5)
			self.punch = true
		end
		if dir.z ~= 0 and self.old_dir.x ~= 0 then
			vel.z = dir.z * math.abs(vel.x)
			vel.x = 0
			pos.x = math.floor(pos.x + 0.5)
			self.punch = true
		end
		-- Up, down?
		if dir.y ~= self.old_dir.y then
			vel.y = dir.y * (math.abs(vel.x) + math.abs(vel.z))
			pos = vector.round(pos)
			self.punch = true
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
			acc = acc + (speed_mod * 8)
		else
			acc = acc - 0.4
			-- Handbrake
			if ctrl and ctrl.down and math.abs(vel.x) + math.abs(vel.z) > 1.2 then
				acc = acc - 1.2
			end
		end
		
		new_acc = {
			x = dir.x * acc, 
			y = dir.y * acc, 
			z = dir.z * acc
		}
		
	end
	
	self.object:setacceleration(new_acc)
	self.old_pos = vector.new(pos)
	self.old_dir = vector.new(dir)
	self.old_switch = last_switch
	
	-- Limits
	for _,v in ipairs({"x","y","z"}) do
		if math.abs(vel[v]) > max_vel then
			vel[v] = boost_cart:get_sign(vel[v]) * max_vel
			self.punch = true
		end
	end
	
	if not self.punch then
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
	self.object:setpos(pos)
	
	if is_realpunch then
		for _,obj_ in ipairs(minetest.get_objects_inside_radius(pos, 1)) do
			if not obj_:is_player() and
					obj_:get_luaentity() and
					not obj_:get_luaentity().physical_state and
					obj_:get_luaentity().name == "__builtin:item" then
				obj_:set_attach(self.object, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
				self.attached_items[#self.attached_items + 1] = obj_
			end
		end
	end
	self.punch = false
end

minetest.register_entity(":carts:cart", boost_cart.cart)
minetest.register_craftitem(":carts:cart", {
	description = "Cart",
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