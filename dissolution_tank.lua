local component = require("component")
local sides = require("sides")
local other_step = 9000
local water_step = other_step * 10
local water = {}
local other = {}

function try(f, catch_f)
	local status, exception = pcall(f)
	if status == false then
		catch_f(exception)
	end
end

for i,v in pairs(component.list("transposer")) do
	local tmp = component.proxy(i)
	if tmp.getFluidInTank(sides.down)[1].name == "water" then
		local water = tmp
	else
		local other = tmp
	end
end

function loop_step()
	local other_enabled = other.getFluidInTank(sides.down)[1].amount >= other_step
	local top_water = water.getFluidInTank(sides.top)[1]
	local water_enabled = top_water.capacity - top_water.amount >= water_step
	if other_enabled and water_enabled then
		water.transferFluid(sides.down, sides.top, water_step)
		other.transferFluid(sides.down, sides.top, other_step)
	end
end

print("Запуск контроля пропорций 1:10")
while true do
	try(
	function()
		loop_step()
		os.sleep()
	end, function(e)
		print("Программа завершена с ошибкой "..e)
		os.exit()
	end)
end
