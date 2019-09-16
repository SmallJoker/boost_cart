-- Common rail registrations

local regular_rail_itemname = "default:rail"
if minetest.registered_nodes["carts:rail"] then
	-- MTG Compatibility
	regular_rail_itemname = "carts:rail"
end

boost_cart:register_rail(":"..regular_rail_itemname, {
	description = "Rail",
	tiles = {
		"carts_rail_straight.png", "carts_rail_curved.png",
		"carts_rail_t_junction.png", "carts_rail_crossing.png"
	},
	groups = boost_cart:get_rail_groups()
})

-- Moreores' copper rail
if minetest.get_modpath("moreores") then
	minetest.register_alias("carts:copperrail", "moreores:copper_rail")

	if minetest.raillike_group then
		-- Ensure that this rail uses the same connect_to_raillike
		local new_groups = minetest.registered_nodes["moreores:copper_rail"].groups
		new_groups.connect_to_raillike = minetest.raillike_group("rail")
		minetest.override_item("moreores:copper_rail", {
			groups = new_groups
		})
	end
else
	boost_cart:register_rail(":carts:copperrail", {
		description = "Copper rail",
		tiles = {
			"carts_rail_straight_cp.png", "carts_rail_curved_cp.png",
			"carts_rail_t_junction_cp.png", "carts_rail_crossing_cp.png"
		},
		groups = boost_cart:get_rail_groups()
	})

	minetest.register_craft({
		output = "carts:copperrail 12",
		recipe = {
			{"default:copper_ingot", "", "default:copper_ingot"},
			{"default:copper_ingot", "group:stick", "default:copper_ingot"},
			{"default:copper_ingot", "", "default:copper_ingot"},
		}
	})
end

-- Power rail
boost_cart:register_rail(":carts:powerrail", {
	description = "Powered rail",
	tiles = {
		"carts_rail_straight_pwr.png", "carts_rail_curved_pwr.png",
		"carts_rail_t_junction_pwr.png", "carts_rail_crossing_pwr.png"
	},
	groups = boost_cart:get_rail_groups(),
	after_place_node = function(pos, placer, itemstack)
		if not mesecon then
			minetest.get_meta(pos):set_string("cart_acceleration", "0.5")
		end
	end,
	mesecons = {
		effector = {
			action_on = function(pos, node)
				boost_cart:boost_rail(pos, 0.5)
			end,
			action_off = function(pos, node)
				minetest.get_meta(pos):set_string("cart_acceleration", "0")
			end,
		},
	},
})

minetest.register_craft({
	output = "carts:powerrail 6",
	recipe = {
		{"default:steel_ingot", "default:mese_crystal_fragment", "default:steel_ingot"},
		{"default:steel_ingot", "group:stick", "default:steel_ingot"},
		{"default:steel_ingot", "default:mese_crystal_fragment", "default:steel_ingot"},
	}
})

-- Brake rail
boost_cart:register_rail(":carts:brakerail", {
	description = "Brake rail",
	tiles = {
		"carts_rail_straight_brk.png", "carts_rail_curved_brk.png",
		"carts_rail_t_junction_brk.png", "carts_rail_crossing_brk.png"
	},
	groups = boost_cart:get_rail_groups(),
	after_place_node = function(pos, placer, itemstack)
		if not mesecon then
			minetest.get_meta(pos):set_string("cart_acceleration", "-0.3")
		end
	end,
	mesecons = {
		effector = {
			action_on = function(pos, node)
				minetest.get_meta(pos):set_string("cart_acceleration", "-0.3")
			end,
			action_off = function(pos, node)
				minetest.get_meta(pos):set_string("cart_acceleration", "0")
			end,
		},
	},
})

minetest.register_craft({
	output = "carts:brakerail 6",
	recipe = {
		{"default:steel_ingot", "default:coal_lump", "default:steel_ingot"},
		{"default:steel_ingot", "group:stick", "default:steel_ingot"},
		{"default:steel_ingot", "default:coal_lump", "default:steel_ingot"},
	}
})

boost_cart:register_rail("boost_cart:startstoprail", {
	description = "Start-stop rail",
	tiles = {
		"carts_rail_straight_ss.png", "carts_rail_curved_ss.png",
		"carts_rail_t_junction_ss.png", "carts_rail_crossing_ss.png"
	},
	groups = boost_cart:get_rail_groups(),
	after_place_node = function(pos, placer, itemstack)
		if not mesecon then
			minetest.get_meta(pos):set_string("cart_acceleration", "halt")
		end
	end,
	mesecons = {
		effector = {
			action_on = function(pos, node)
				boost_cart:boost_rail(pos, 0.5)
			end,
			action_off = function(pos, node)
				minetest.get_meta(pos):set_string("cart_acceleration", "halt")
			end,
		},
	},
})

minetest.register_craft({
	type = "shapeless",
	output = "boost_cart:startstoprail 2",
	recipe = {"carts:powerrail", "carts:brakerail"},
})

boost_cart.player_formspecs = {}

boost_cart:register_rail("boost_cart:waitrail", {
	description = "Wait rail",
	tiles = {
		"carts_rail_straight_wt.png", "carts_rail_curved_wt.png",
		"carts_rail_t_junction_wt.png", "carts_rail_crossing_wt.png"
	},
	groups = boost_cart:get_rail_groups(),
	after_place_node = function(pos, placer, itemstack)
		if not mesecon then
			local meta = minetest.get_meta(pos)
			meta:set_string("cart_acceleration", "wait:5")
			meta:set_string("cart_acceleration_backup", "wait:5")
			meta:set_string("infotext", "Wait time: 5 seconds.")

			-- Show formspec to change the value.
			local player_name = placer:get_player_name()
			boost_cart.player_formspecs[player_name] = pos
			minetest.show_formspec(player_name, "boost_cart:waitrail", "field[time;Wait time (in seconds):;5]")
		end
	end,
	mesecons = {
		effector = {
			action_on = function(pos, node)
				boost_cart:boost_rail(pos, 0.5)
			end,
			action_off = function(pos, node)
				local meta = minetest.get_meta(pos)
				meta:set_string("cart_acceleration", meta:get_string("cart_acceleration_backup"))
			end,
		},
	},
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local player_name = player:get_player_name()
	if not player_name or formname ~= "boost_cart:waitrail" then
		return false
	end
	if fields.time then
		local num = tonumber(fields.time)
		if not num then
			minetest.chat_send_player(player_name, "Value must be a number; defaulting to 5 seconds.")
			return false
		end
		if num <= 0 then
			minetest.chat_send_player(player_name, "Value must be greater than 0; defaulting to 5 seconds.")
			return false
		end

		local meta = minetest.get_meta(boost_cart.player_formspecs[player_name])
		meta:set_string("cart_acceleration", "wait:" .. num)
		meta:set_string("cart_acceleration_backup", "wait:" .. num)
		meta:set_string("infotext", "Wait time: " .. num .. " seconds.")
		minetest.chat_send_player(player_name, "Wait rail time set to " .. num .. " seconds.")
	else
		minetest.chat_send_player(player_name, "No value given; defaulting to 5 seconds.")
	end
end)

minetest.register_craft({
	type = "shapeless",
	output = "boost_cart:waitrail 3",
	recipe = {"carts:brakerail", "carts:powerrail", "carts:brakerail"},
})
