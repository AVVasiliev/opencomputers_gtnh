local component = require("component")
local sides = require("sides")

function get_gt_by_name(name)
  for k, _ in component.list("gt_machine") do
    gt = component.proxy(k)
	if string.find(gt.getName(), name) ~= nil then
	  return gt
	end
  end
end

function try(f, catch_f)
	local status, exception = pcall(f)
	if status == false then
	    os.sleep(3)
		catch_f(exception)
	end
end

VatController = {}

function VatController:new()
    local obj = {}
		obj.input_bus = component.inventory_controller
		obj.radio_info = get_gt_by_name("bw.radiohatch")
		obj.vat = get_gt_by_name("bw.biovat")
		obj.vat.setWorkAllowed(false)
		obj.tr_fluid = nil
		obj.tr_radio = nil
		obj.out_half = 0
		
	function obj:calc_max_half_output()
		obj.out_half = obj.tr_fluid.getFluidInTank(sides.top)[1]["capacity"] // 2
	end
	
	function obj:define_transposers()
		for k,v in pairs(component.list('transposer')) do
			local tmp = component.proxy(k)
			if tmp.getFluidInTank(sides.top)[1] ~= nil then
				self.tr_fluid = tmp
			else
				self.tr_radio = tmp
			end
		end
	end
	
	function obj:vat_blink()
		self.vat.setWorkAllowed(true)
		os.sleep(0.3)
		self.vat.setWorkAllowed(false)
	end
	
	function obj:getRecipeLostTime()
	    return self.vat.getWorkMaxProgress() - self.vat.getWorkProgress()
	end
	
	function obj:getResultFluidCount()
		return self.tr_fluid.getFluidInTank(sides.top)[1]["amount"] - self.out_half
	end
	
	function obj:getRadioTime()
		local data = self.radio_info.getSensorInformation()[4]
		if data == nil then
		    return 0
		else
		    return tonumber(string.match(data, "(%d+)t"))
		end
	end
	
	function obj:requireInsertRadio()
		return self:getRecipeLostTime() >= self:getRadioTime() 
	end
	
	function obj:insertRadio()
		obj.tr_radio.transferItem(sides.bottom, sides.top, 1)
	end
	
	function obj:extractFluid()
		local amount = self:getResultFluidCount()
		if amount <= 0 then
			return
		end
		print("Выход жидкости: "..tostring(amount))
		self.tr_fluid.transferFluid(sides.top, sides.bottom, amount)
	end
	
	function obj:requireStart()
		return self.input_bus.getSlotStackSize(sides.top, 1) > 0
	end
	
	function obj:processing()
	    if self:requireStart() then
		    if self:getRadioTime() <= 20 then
				self:insertRadio()
			end
			self:vat_blink()
			if self:requireInsertRadio() then
			    self:insertRadio()
			end
			os.sleep(self:getRecipeLostTime() / 20)
			self:extractFluid()
		else
		    os.sleep(1)
		end
	end

	obj:define_transposers()
	obj:calc_max_half_output()
	setmetatable(obj, self)
    self.__index = self; return obj

end

print("Запуск работы бактериального чана")
vat_controller = VatController:new()
print("Поддерживаемый уровень: "..tostring(vat_controller.out_half))
while true do
	try(vat_controller:processing(), print)
end
