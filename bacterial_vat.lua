function get_gt_by_name(component, name)
  for k, _ in component.list("gt_machine") do
    gt = component.proxy(k)
	if string.find(gt.getName(), name) ~= nil then
	  return gt
	end
  end
end

local comp = require("component")
local red = comp.redstone
local si = require("sides")
red.setOutput(si.top, 0)


VatController = {}

function VatController:new(tr_fluid_arg, tr_item_arg)
    local obj = {}
	    obj.comp = require("component")
		obj.red = obj.comp.redstone
		obj.input_bus = obj.comp.inventory_controller
		obj.fluid_out = get_gt_by_name(obj.comp, "hatch.output")
		obj.radio_info = get_gt_by_name(obj.comp, "bw.radiohatch")
		obj.vat = get_gt_by_name(obj.comp, "bw.biovat")
		obj.tr_fluid = obj.comp.proxy(obj.comp.get(tr_fluid_arg))
		obj.tr_radio = obj.comp.proxy(obj.comp.get(tr_item_arg))
		obj.si = require("sides")
		obj.out_half = 0
		
	function obj:calc_max_half_output()
		local tmp = self.fluid_out.getSensorInformation()[4]:gsub(",", "")
		tmp = tmp:gsub(string.match(tmp, "%d+"), "")
		return tonumber(string.match(tmp, "%d+")) // 2
	end
	
	function obj:getRecipeLostTime()
	    return self.vat.getWorkMaxProgress() - self.vat.getWorkProgress()
	end
	
	function obj:getResultFluidCount()
	    local fluid = string.match(self.fluid_out.getSensorInformation()[4]:gsub(",", ""), "%d+")
		return tonumber(fluid) - self.out_half
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
		obj.tr_radio.transferItem(self.si.bottom, self.si.top, 1)
	end
	
	function obj:extractFluid()
		local amount = self:getResultFluidCount()
		self.tr_fluid.transferFluid(self.si.top, self.si.bottom, amount)
	end
	
	function obj:requireStart()
		return self.input_bus.getSlotStackSize(self.si.top, 1) > 0
	end
	
	function obj:processing()
	    if self:requireStart() then
		    if self:getRadioTime() <= 20 then
				self:insertRadio()
			end
			self.red.setOutput(si.top, 15)
			self.red.setOutput(si.top, 0)
			if self:requireInsertRadio() then
			    self:insertRadio()
			end
			os.sleep(self:getRecipeLostTime() / 20)
			self:extractFluid()
		else
		    os.sleep(1)
		end
	end

	obj.out_half = obj:calc_max_half_output()
	setmetatable(obj, self)
    self.__index = self; return obj

end


vat_controller = VatController:new("7b1b", "7de3")
while true do
    vat_controller:processing()
end
