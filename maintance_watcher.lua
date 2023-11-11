local component = require('component')
local shell = require('shell')
local filesystem = require("filesystem")
local MultiWaypoints = "multi_waypoint" --файл с для связи многоблока и точки
local gt_machine = component.list("gt_machine")
local waypoints = component.list("waypoint")
local check_period = 300
local RouteListTable = {}

-- 5 для обычных ГТ машин
-- 10 для ГТ++ 
-- строка вида "Problems: &c0&r Efficiency: &e0.0&r %"

function table_len(table_item)
	local lengthNum = 0

	for k, v in pairs(table_item) do
	   lengthNum = lengthNum + 1
	end
	return lengthNum
end

function SaveCodeToFile(code, filename) --сохранить текст в файл
    local file = io.open(filename .. ".lua", "w")
    file:write(code)
    file:close()
end

function createWaypointsTableText() --возвращает таблицу маршрута точек ремонта в виде текста 
    local code = ""
 
    code = code .. "\n-- Файл с маршрутом точек ремонта робота ремонтника"
    code = code .. "\n"
    code = code .. "\nlocal RouteListTable = {"
 
    for pointIndex, point in pairs(RouteListTable) do
        code = code .. "\n  { waypoint = '" .. point.waypoint .. "', gt = '" .. point.gt .. "'},"
    end
    code = code .. "\n}"
    code = code .. "\n\nreturn RouteListTable"
 
    return code
end

function need_maintance(gt)
	local info = gt.getSensorInformation()
	if info[10] ~= nil then
		return info[10]:match('%d') ~= '0'
	else
		return info[5]:match('%d') ~= '0'
	end
end

function process_gt(gt_id, way_id)
	local gt = component.proxy(gt_id)
	local waypoint = component.proxy(way_id)
	if need_maintance(gt) then
		x,y,z=gt.getCoordinates()
		print(gt.getName().." в точке "..x.." "..y.." "..z.." сломался")
		gt.setWorkAllowed(false)
		waypoint.setLabel("fix_"..gt.getName())
	else
		gt.setWorkAllowed(true)
		waypoint.setLabel("")
	end
end

function set_points_pair()
	if table_len(gt_machine) ~= table_len(waypoints) then
		print("Не совпадает количество адаптеров и путевых точек! "..table_len(gt_machine).." != "..table_len(waypoints))
		os.exit()
	end
end

function debug_gt_machines()
	for k, v in pairs(gt_machine) do
	   item = component.proxy(k)
	   x,y,z=item.getCoordinates()
	   print(item.getName().." "..x.." "..y.." "..z..", problems: "..tostring(need_maintance(item)))
	end
end

function setup_waypoints(ignore_exists)
	print("Сопоставление путевых точек и многоблоков")
	print("Будет показан адрес и имя контроллера, нужно ввести адрес точки (не менее трех символов): ")
	index = 1
	for k, v in pairs(gt_machine) do
	    if ignore_exists then
			for i, file_item in pairs(RouteListTable) do
				if k == file_item.gt then
					goto continue
				end
			end
	    end
	    item = component.proxy(k)
	    x,y,z=item.getCoordinates()
	    print(item.getName().." "..x.." "..y.." "..z.. " -> ")
	    point_addr = io.read()
	    table.insert(RouteListTable, {waypoint=component.get(point_addr), gt=k})
	    ::continue::
	end
end

function loop_work_step()
	for k,v in pairs(RouteListTable) do
		process_gt(v.gt, v.waypoint)
	end
end

function loop_work()
	while true do
		loop_work_step()
		os.sleep(30)
	end
end

if filesystem.exists(shell.resolve(MultiWaypoints..".lua")) == true then
    RouteListTable = require (MultiWaypoints)
end

local args, options = shell.parse(...)
-- доступные режимы setup, work, debug
if #args > 0 then
  options.mode = args[1]
else
  options.mode = 'work'
end

if options.mode == 'setup' then
	if next(RouteListTable) ~= nil then
		print("Найдены существующие настройки, настроить заново или добавить? (new/add)")
		local full_path = shell.resolve(MultiWaypoints..".lua")
		filesystem.copy(full_path, full_path..".old")
		choice = io.read()
		if choice == 'new' then
		    print('Выбран режим создания, старые точки сохранены в '..MultiWaypoints..'.lua.old')
			RouteListTable = {}
			setup_waypoints(false)
		elseif choice == 'add' then
			print('Выбран режим добавления, старые точки сохранены в '..MultiWaypoints..'.lua.old')
			setup_waypoints(true)
		else
			print("Режим не опознан, ввежите new/add")
			os.exit()
		end
	end
	SaveCodeToFile(createWaypointsTableText(), MultiWaypoints)
elseif options.mode == 'debug' then
	debug_gt_machines()
elseif options.mode == 'work' then
	loop_work()
end
