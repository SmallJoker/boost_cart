minetest.register_node(":default:rail", {
	description = "Rail",
	drawtype = "raillike",
	tiles = {"default_rail.png", "default_rail_curved.png", "default_rail_t_junction.png", "default_rail_crossing.png"},
	inventory_image = "default_rail.png",
	wield_image = "default_rail.png",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = true,
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	groups = {dig_immediate = 2, attached_node = 1, rail = 1, connect_to_raillike = 1},
})

if minetest.get_modpath("moreores") then
	-- Moreores' copper rail
	minetest.register_alias("carts:copperrail", "moreores:copper_rail")
else
	boost_cart:register_rail(":carts:copperrail", {
		description = "Copper rail",
		tiles = {"carts_rail_cp.png", "carts_rail_curved_cp.png", "carts_rail_t_junction_cp.png", "carts_rail_crossing_cp.png"},
		groups = {dig_immediate = 2, attached_node = 1, rail = 1, connect_to_raillike = 1},
	})

	minetest.register_craft({
		output = "carts:copperrail 12",
		recipe = {
			{"default:copper_ingot", "group:stick", "default:copper_ingot"},
			{"default:copper_ingot", "group:stick", "default:copper_ingot"},
			{"default:copper_ingot", "group:stick", "default:copper_ingot"},
		}
	})
end

-- Speed up

boost_cart:register_rail(":carts:powerrail", {
	description = "Powered rail",
	tiles = {"carts_rail_pwr.png", "carts_rail_curved_pwr.png", "carts_rail_t_junction_pwr.png", "carts_rail_crossing_pwr.png"},
	groups = {dig_immediate = 2, attached_node = 1, rail = 1, connect_to_raillike = 1},
	
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

boost_cart:register_rail(":carts:brakerail", {
	description = "Brake rail",
	tiles = {"carts_rail_brk.png", "carts_rail_curved_brk.png", "carts_rail_t_junction_brk.png", "carts_rail_crossing_brk.png"},
	groups = {dig_immediate = 2, attached_node = 1, rail = 1, connect_to_raillike = 1},

	after_place_node = function(pos, placer, itemstack)
		if not mesecon then
			minetest.get_meta(pos):set_string("cart_acceleration", "-0.2")
		end
	end,

	mesecons = {
		effector = {
			action_on = function(pos, node)
				boost_cart:boost_rail(pos, -0.2)
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