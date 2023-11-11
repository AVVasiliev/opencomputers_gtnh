local component = require("component")
local event = require("event")
local modem = component.modem
local nav = component.navigation
local sides = require("sides")
local robot = require('robot')
local shell = require('shell')
local scaner = component.geolyzer
local dock = "dock"
local max_y = 7
local neg_sides = {east="west", west="east", north='south', south='north'}

function rotate(dst)
	local src = nav.getFacing()
    local right = {{sides.north, sides.west}, {sides.west, sides.south}, {sides.south, sides.east}, {sides.east, sides.north}}
    if src == dst then
        return
    end
    for _, v in pairs(right) do
        if v[1] == src and v[2] == dst then 
            robot.turnLeft()
			return
        elseif v[1] == dst and v[2] == src then
            robot.turnRight()
			return
        end
    end
    robot.turnAround()
end

function go(v)
  v = math.abs(v)
  for i = 0, v - 1 do
    robot.forward()
  end
end

function up(y)
  for i = 1, y do
    robot.up()
  end
end

function down(y)
  for i = 1, y do
    robot.down()
  end
end

function move_to(x, z)
  if x == 0 and y == 0 then
    return
  end
  
  up(max_y)
  
  if x < 0 then
    rotate(sides.west)
  elseif x > 0 then
    rotate(sides.east)
  end
 
  go(x)
  
  if z < 0 then
    rotate(sides.north)
  elseif z > 0 then
    rotate(sides.south)
  end
 
  go(z)
  
  down(max_y)
end

function get_point(name)
  points = nav.findWaypoints(128)
  for i = 1, #points do
    if points[i].label == name then
	  pos = points[i].position
	  return pos[1], pos[3]
	end
  end  
  return 0, 0
end

function move_to_point(name)
  x, z = get_point(name)
  move_to(x, z)
end

function repair()
	for i = 2, 5 do
		local info = scaner.analyze(i)
		if info["name"] == "gregtech:gt.blockmachines" and next(info["sensorInformation"]) == nil then
			rotate(sides[neg_sides[string.lower(info.facing)]])
			robot.use(sides.back)
			print("Поломка починена!")
			return
		end
	end
	print("Не найден люк обслуживания! Проверьте корректность путевой точки")
end


function loop_over_points()
  points = nav.findWaypoints(128)
  for i = 1, #points do
    local label = points[i].label
    if string.sub(label, 1, 3) == "fix" then
	  print("Поломка "..string.sub(label, 5, string.len(label)).." "..os.date("%m/%d/%Y %H:%M"))
	  move_to_point(label)
	  repair()
	end
  end
end


local args, options = shell.parse(...)
-- доступные режимы fix и modem
if #args > 0 then
  options.mode = args[1]
else
  options.mode = 'fix'
end

if options.mode == 'fix' then
	print('Запуск программы. Режим: '..options.mode)
	os.sleep(10)	
	while true do
	  loop_over_points()
	  move_to_point(dock)
	  os.sleep(120)
	end
elseif options.mode == 'modem' then
	print('Запуск программы. Режим: '..options.mode)
	modem.open(5000)
	while true do
		local _, _, from, port, _, message = event.pull("modem_message")
		if port == 5000 then
		  if message == "exit" then
			os.exit()
		  end
		  move_to_point(message)
		end
	end
else
    print('Программа не запущена, не опознан режим: '..options.mode)
end
