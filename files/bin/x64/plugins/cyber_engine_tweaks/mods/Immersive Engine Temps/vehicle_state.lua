local TEMP = require("temp_logic") 

local S = {}

-- Every vehicle, keys = Hash, Value = State
local vehicles = {}

function S.getOrCreate(vehID, ambientNow, CFG)
    local v = vehicles[vehID]

    if not v then
        print("[Immersive Engine Temps] New Entry for VehID=" .. tostring(vehID))
        v = {
            coolant_temp = ambientNow,
            oil_temp = ambientNow,
            max_rpm = CFG.default_max_rpm
        }
        vehicles[vehID] = v
    end

    return v
end

function S.tickAllUnmounted(dt, CFG, ambientNow, skipID)
    for vehID, v in pairs(vehicles) do
        if vehID ~= skipID then
            TEMP.tickUnmounted(v, ambientNow, dt, CFG)
        end
    end
end
-- The following is not relevant ill maybe implement it fully sometimes
--function S.cleanUpVehicles(CFG)
 --   local ambientNow = TEMP.computeAmbient(hour, CFG)
 --   for vehID, v in pairs(vehicles) do
 --       if v.coolant_temp <= ambientNow and v.oil_temp <= ambientNow then
 --           -- remove the Car from the list        
 --       end
 --   end
return S