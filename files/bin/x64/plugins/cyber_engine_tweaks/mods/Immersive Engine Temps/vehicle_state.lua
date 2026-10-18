local TEMP = require("temp_logic") 

local S = {}

-- Every vehicle, keys = Hash, Value = State
local vehicles = {}

local function readTweakMaxRpm(vehKey)
    if not vehKey then return nil end
    local ok, value = pcall(function()
        return TweakDB:GetRecord(vehKey):VehEngineData():MaxRPM()
    end)
    if ok and type(value) == "number" and value > 0 then
        return value
    end
    return nil
end

function S.getOrCreate(vehID, vehKey, ambientNow, CFG)
    local v = vehicles[vehID]

    if not v then
        print("[Immersive Engine Temps] New Entry for VehID=" .. tostring(vehID))
        v = {
            coolant_temp = ambientNow,
            oil_temp = ambientNow,
            max_rpm = readTweakMaxRpm(vehKey) or CFG.default_max_rpm,
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
return S