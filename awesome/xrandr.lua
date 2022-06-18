--- Separating Multiple Monitor functions as a separeted module (taken from awesome wiki)
--
local gtable  = require("gears.table")
local spawn   = require("awful.spawn")
local naughty = require("naughty")
local gears   = require("gears")
--
---- A path to a fancy icon
--local icon_path = ""
--
---- Get active outputs
local function outputs()
	local outputs = {}
	local xrandr = io.popen("xrandr -q --current")

	if xrandr then
		for line in xrandr:lines() do
			local output = line:match("^([%w-]+) connected ")
			if output then
				outputs[#outputs + 1] = output
			end
		end
		xrandr:close()
	end

	return outputs
end

local function arrange(out)
-- We need to enumerate all permutations of horizontal outputs.

	local choices  = {}
	local previous = { {} }
	for i = 1, #out do
		-- Find all permutation of length `i`: we take the permutation
		-- of length `i-1` and for each of them, we create new
		-- permutations by adding each output at the end of it if it is
		-- not already present.
		local new = {}
		for _, p in pairs(previous) do
			for _, o in pairs(out) do
				if not gtable.hasitem(p, o) then
					new[#new + 1] = gtable.join(p, {o})
				end
			end
		end
		choices = gtable.join(choices, new)
		previous = new
	end

	return choices
end

-- Build available choices
local function menu()
	local menu = {}
	local out = outputs()
	local choices = arrange(out)

	for _, choice in pairs(choices) do
		local cmd = "xrandr"
		-- Enabled outputs
		for i, o in pairs(choice) do
			if o == "eDP-1" then
				cmd = cmd .. " --output " .. o .. " --mode 3840x2400 --pos 0x0"
			elseif o == "HDMI-1" then
				cmd = cmd .. " --output " .. o .. " --mode 2560x1080 --pos 3840x0 --scale 2x2"
				-- cmd = cmd .. " --output " .. o .. " --mode auto --pos 3840x0 --scale 2x2"
			else
				cmd = cmd .. " --output " .. o .. " --auto"
			end
			if i > 1 then
				cmd = cmd .. " --right-of " .. choice[i-1]
			end
		end
		-- Disabled outputs
		for _, o in pairs(out) do
			if not gtable.hasitem(choice, o) then
					cmd = cmd .. " --output " .. o .. " --off"
			end
	end

	local label = ""
	if #choice == 1 then
		label = 'Only <span weight="bold">' .. choice[1] .. '</span>'
	else
		for i, o in pairs(choice) do
			if i > 1 then label = label .. " + " end
			label = label .. '<span weight="bold">' .. o .. '</span>'
		end
	end

	menu[#menu + 1] = { label, cmd }
	end

	return menu
end

-- Display xrandr notifications from choices
local state = { cid = nil }

local function naughty_destroy_callback(reason)
	if reason == naughty.notificationClosedReason.expired or
	reason == naughty.notificationClosedReason.dismissedByUser then
		local action = state.index and state.menu[state.index - 1][2]
		if action then
			spawn(action, false)
			state.index = nil
		end
	end
	--spawn.with_shell("~/.config/awesome/setup_monitors.sh")
end

	local function xrandr()
	-- Build the list of choices
	if not state.index then
		state.menu = menu()
		state.index = 1
	end

	-- Select one and display the appropriate notification
	local label, action
	local next  = state.menu[state.index]
	state.index = state.index + 1

	if not next then
		label = "Keep the current configuration"
		state.index = nil
	else
		label, action = next[1], next[2]
	end
	state.cid = naughty.notify({ text = label,
	icon = icon_path,
	shape = function (cr, w, h) 
		gears.shape.rounded_rect(cr, w, h, 25)
	end,
	timeout = 4,
	screen = mouse.screen,
	replaces_id = state.cid,
	destroy = naughty_destroy_callback}).id
end

return {
	outputs = outputs,
	arrange = arrange,
	menu = menu,
	xrandr = xrandr
}
