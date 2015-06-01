local mesecons_rules = mesecon.rules.flat

--local 
function turnoff_detector_rail(pos)
	local node = minetest.get_node(pos)
	if minetest.get_item_group(node.name, "detector_rail") == 1 then
		if node.name=="carts:detectrail_on" then --has not been dug
			minetest.swap_node(pos, {name = "carts:detectrail", param2=node.param2})
		end
		mesecon.receptor_off(pos, mesecon.rules.flat)
	end
end

function boost_cart:signal_detector_rail(pos)
	local node = minetest.get_node(pos)
	if minetest.get_item_group(node.name, "detector_rail") ~= 1 then
		return
	end
	print("Signaling detector at " .. vector.tostr(pos))
	if node.name == "carts:detectrail" then
		minetest.swap_node(pos, {name = "carts:detectrail_on", param2=node.param2})
	end
	mesecon.receptor_on(pos, mesecon.rules.flat)
	minetest.after(0.5, turnoff_detector_rail, pos)
end

minetest.register_node(":carts:detectrail", {
	description = "Detector rail",
	drawtype = "raillike",
	tiles = {"carts_rail_dtc.png", "carts_rail_curved_dtc.png", "carts_rail_t_junction_dtc.png", "carts_rail_crossing_dtc.png"},
	inventory_image = "carts_rail_dtc.png",
	wield_image = "carts_rail_dtc.png",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = true,
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	groups = {dig_immediate = 2, attached_node = 1, rail = 1, connect_to_raillike = 1, detector_rail = 1},
	
	mesecons = {receptor = {state = "off", rules = mesecons_rules }},
})

minetest.register_node(":carts:detectrail_on", {
	description = "Detector rail ON (you hacker you)",
	drawtype = "raillike",
	tiles = {"carts_rail_dtc_on.png", "carts_rail_curved_dtc_on.png", "carts_rail_t_junction_dtc_on.png", "carts_rail_crossing_dtc_on.png"},
	inventory_image = "carts_rail_dtc_on.png",
	wield_image = "carts_rail_dtc_on.png",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = true,
	walkable = false,
	selection_box = {
		type = "fixed",
		-- but how to specify the dimensions for curved and sideways rails?
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	groups = {dig_immediate = 2, attached_node = 1, rail = 1, connect_to_raillike = 1, detector_rail = 1, not_in_creative_inventory = 1},
	drop = "carts:detectrail",
	
	mesecons = {receptor = {state = "on", rules = mesecons_rules }},
})

minetest.register_craft({
	output = "carts:detectrail 6",
	recipe = {
		{"default:steel_ingot", "mesecon:mesecon", "default:steel_ingot"},
		{"default:steel_ingot", "group:stick", "default:steel_ingot"},
		{"default:steel_ingot", "mesecon:mesecon", "default:steel_ingot"},
	},
})
