--- the modpath of unified inventoy or nil
local have_ui = minetest.get_modpath("unified_inventory")

--- the recipe table containing all factory recipes
factory.recipes = { cooking = { input_size = 1, output_size = 1 } }

---
--Register a new recipe.
--Adds a category to the factory recipe table
--
--@function [parent=#factory] register_recipe_type
--@param #string typename the name of the recipe category to be added
--@param #table origdata the definition of this recipe type
function factory.register_recipe_type(typename, origdata)
	local data = {}
	for k, v in pairs(origdata) do data[k] = v end
	data.input_size = data.input_size or 1
	data.output_size = data.output_size or 1
	if have_ui and unified_inventory.register_craft_type and data.output_size == 1 then
		unified_inventory.register_craft_type(typename, {
			description = data.description,
			width = data.input_size,
			height = 1,
		})
	end
	data.recipes = data.recipes or {}
	factory.recipes[typename] = data
end

local function get_recipe_index(items)
	if not items or type(items) ~= "table" then return false end
	local l = {}
	for i, stack in ipairs(items) do
		l[i] = ItemStack(stack):get_name()
	end
	table.sort(l)
	return table.concat(l, "/")
end

local function register_recipe(typename, data)
	-- Handle aliases
	for i, stack in ipairs(data.input) do
		data.input[i] = ItemStack(stack):to_string()
	end
	if type(data.output) == "table" then
		for i,_ in ipairs(data.output) do
			data.output[i] = ItemStack(data.output[i]):to_string()
		end
	else
		data.output = ItemStack(data.output):to_string()
	end

	local recipe = {time = data.time, input = {}, output = data.output}
	if not recipe.time then recipe.time = 1 end
	local index = get_recipe_index(data.input)
	if not index then
		factory.log.warning("ignored registration of garbage recipe!")
		return
	end
	for _, stack in ipairs(data.input) do
		recipe.input[ItemStack(stack):get_name()] = ItemStack(stack):get_count()
	end

	factory.recipes[typename].recipes[index] = recipe
	if have_ui and unified_inventory and factory.recipes[typename].output_size == 1 then
		unified_inventory.register_craft({
			type = typename,
			output = data.output,
			items = data.input,
			width = 0,
		})
	end
end

function factory.register_recipe(typename, data)
	minetest.after(0.01, register_recipe, typename, data) -- Handle aliases
end

function factory.get_recipe(typename, items)
	if typename == "cooking" then -- Already builtin in Minetest, so use that
		local result, new_input = minetest.get_craft_result({
			method = "cooking",
			width = 1,
			items = items})
		-- Compatibility layer
		if not result or result.time == 0 then
			return nil
		else
			return {time = result.time,
							new_input = new_input.items,
							output = result.item}
		end
	end
	local index = get_recipe_index(items)
	if not index then
		factory.log.warning("ignored registered garbage recipe!")
		return
	end
	local recipe = factory.recipes[typename].recipes[index]
	if recipe then
		local new_input = {}
		for i, stack in ipairs(items) do
			if stack:get_count() < recipe.input[stack:get_name()] then
				return nil
			else
				new_input[i] = ItemStack(stack)
				new_input[i]:take_item(recipe.input[stack:get_name()])
			end
		end
		return {time = recipe.time,
						new_input = new_input,
						output = recipe.output}
	else
		return nil
	end
end
