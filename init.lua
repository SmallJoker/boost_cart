-- TODO: 
--  Fix way-up
--  Add rail-cross switching
--  Prevent from floating carts
--  Speed up and brake rails

boost_cart = {}
boost_cart.modpath = minetest.get_modpath("boost_cart")
boost_cart.speed_max = 20

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
	old_pos = nil
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
		clicker:set_attach(self.object, "", {x=0,y=5,z=0}, {x=0,y=0,z=0})
	end
end

function boost_cart.cart:on_activate(staticdata, dtime_s)
	self.object:set_armor_groups({immortal=1})
	self.old_pos = self.object:getpos()
end

function boost_cart.cart:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	if not puncher or not puncher:is_player() then
		return
	end

	if puncher:get_player_control().sneak then
		if self.driver then
			local player = minetest.get_player_by_name(self.driver)
			if player then
				player:set_detach()
			end
		end
    	self.object:remove()
		puncher:get_inventory():add_item("main", "boost_cart:cart")
		return
	end
	
	local vel = self.velocity
	--[[if puncher:get_player_name() == self.driver then
		if math.abs(vel.x) + math.abs(vel.z) > 6 then
			return
		end
	end]]
	
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
	
	local f = 3 * (time_from_last_punch / tool_capabilities.full_punch_interval)
	vel.x = dir.x * f
	vel.z = dir.y * f
	vel.z = dir.z * f
	self.velocity = vel
	self.old_pos = nil
	self.punch = true
end

function boost_cart.cart:on_step(dtime)
	local vel = self.object:getvelocity()
	if self.punch then
		vel = vector.add(vel, self.velocity)
		self.velocity = {x=0, y=0, z=0}
		for _,v in ipairs({"x","y","z"}) do
			if math.abs(vel[v]) > boost_cart.speed_max then
				vel[v] = boost_cart:get_sign(vel[v]) * boost_cart.speed_max
			end
		end
	elseif vector.equals(vel, {x=0, y=0, z=0}) then
		return
	end
	
	local pos = self.object:getpos()
	local flo_pos = vector.floor(pos)
	if self.old_pos and not self.punch then
		if vector.equals(flo_pos, self.old_pos) then
			return
		end
		local expected_pos = vector.add(self.old_pos, self.old_dir)
		if not vector.equals(flo_pos, expected_pos) then
			pos = vector.new(expected_pos)
			self.punch = true
		end
	end
	
	local cart_dir = {
		x = boost_cart:get_sign(vel.x),
		y = boost_cart:get_sign(vel.y),
		z = boost_cart:get_sign(vel.z)
	}
	local dir = boost_cart:get_rail_direction(pos, cart_dir)
	if vector.equals(dir, {x=0, y=0, z=0}) then
		vel = {x=0, y=0, z=0}
		self.object:setacceleration({x=0, y=0, z=0})
		self.old_pos = nil
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
			--if dir.y == 1 then
			--	pos.y = pos.y + 1.5
			--end
			pos = vector.round(pos)
			self.punch = true
		end
		
		-- Slow down or speed up..
		local acc = (dir.y * -1.4) - 0.4
		local new_acc = {
			x = dir.x * acc, 
			y = dir.y * acc, 
			z = dir.z * acc
		}
		
		--for _,v in ipairs({"x","y","z"}) do
		--	if math.abs(vel[v]) < math.abs(new_acc[v] * 1.3) then
		--		vel[v] = 0
		--		new_acc[v] = 0
		--		self.punch = true
		--	end
		--end
		self.object:setacceleration(new_acc)
	end
	
	self.old_pos = vector.floor(pos)
	self.old_dir = vector.new(dir)
	
	-- Limits
	for _,v in ipairs({"x","y","z"}) do
		if math.abs(vel[v]) > boost_cart.speed_max then
			vel[v] = boost_cart:get_sign(vel[v]) * boost_cart.speed_max
			self.punch = true
		end
	end
	
	if dir.x < 0 then
		self.object:setyaw(math.pi / 2)
	elseif dir.x > 0 then
		self.object:setyaw(3 * math.pi / 2)
	elseif dir.z < 0 then
		self.object:setyaw(math.pi)
	elseif dir.z > 0 then
		self.object:setyaw(0)
	end

	if dir.y == -1 then
		self.object:set_animation({x=1, y=1}, 1, 0)
	elseif dir.y == 1 then
		self.object:set_animation({x=2, y=2}, 1, 0)
	else
		self.object:set_animation({x=0, y=0}, 1, 0)
	end
	if self.punch then
		self.object:setvelocity(vel)
		self.object:setpos(pos)
	end
	self.punch = false
end

minetest.register_entity("boost_cart:cart", boost_cart.cart)
minetest.register_craftitem("boost_cart:cart", {
	description = "Cart",
	inventory_image = minetest.inventorycube("cart_top.png", "cart_side.png", "cart_side.png"),
	wield_image = "cart_side.png",
	on_place = function(itemstack, placer, pointed_thing)
		if not pointed_thing.type == "node" then
			return
		end
		if boost_cart:is_rail(pointed_thing.under) then
			minetest.add_entity(pointed_thing.under, "boost_cart:cart")
		elseif boost_cart:is_rail(pointed_thing.above) then
			minetest.add_entity(pointed_thing.above, "boost_cart:cart")
		else return end
		
		itemstack:take_item()
		return itemstack
	end,
})