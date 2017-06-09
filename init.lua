
boost_cart = {}
boost_cart.modpath = minetest.get_modpath("boost_cart")


-- Settings glue for <= 0.4.15
local setting_getter = minetest.setting_get
if minetest.settings then
	setting_getter = function (key)
		return minetest.settings:get(key)
	end
end

-- Maximal speed of the cart in m/s
boost_cart.speed_max = tonumber(setting_getter("boost_cart.speed_max")) or 10
-- Set to -1 to disable punching the cart from inside
boost_cart.punch_speed_max = tonumber(setting_getter("boost_cart.punch_speed_max")) or 7


if not boost_cart.modpath then
	-- For Minetest 0.4.12 and older that don't look at the "mod.conf" file
	error("\nWrong mod directory name! Please change it to 'boost_cart'.\n" ..
			"See also: http://dev.minetest.net/Installing_Mods")
end

-- Support for non-default games
if not default.player_attached then
	default.player_attached = {}
end

dofile(boost_cart.modpath.."/functions.lua")
dofile(boost_cart.modpath.."/rails.lua")

if minetest.global_exists("mesecon") then
	dofile(boost_cart.modpath.."/detector.lua")
--else
--	minetest.register_alias("carts:powerrail", "boost_cart:detectorrail")
--	minetest.register_alias("carts:powerrail", "boost_cart:detectorrail_on")
end

boost_cart.mtg_compat = minetest.global_exists("carts") and carts.pathfinder
if boost_cart.mtg_compat then
	minetest.log("action", "[boost_cart] Overwriting definitions of similar carts mod")
end
dofile(boost_cart.modpath.."/cart_entity.lua")
