local CONFIG = require("config")
local STATE = require("vehicle_state")
local TEMP = require("temp_logic")
-- I Just want to see every value, to see if everything is correct
local DEBUG = {
    mounted = false,
    kmh = 0.0,
    rpm = 0,
    hour = 0.0,
    ambientNow = 0.0,
    vehID = nil,
    coolant_temp = 0.0,
    coolant_heat = 0.0,
    coolant_cool = 0.0,
    coolant_target = 0.0,
    coolant_delta = 0.0,
    oil_temp = 0.0,
    oil_heat = 0.0,
    oil_target = 0.0,
    oil_delta = 0.0,
    max_rpm = 0
}


local LIVE = { rpm=nil} -- Collectionpoint for async data

local isOverlayVisible = false

local lastHour = nil

local sysCache = nil

local function getSystem()
    if sysCache then return sysCache end
    local c = Game.GetScriptableSystemsContainer()
    if not c then return nil end
    sysCache = c:Get("ImmersiveEngineTemps.EngineTempSystem")
    return sysCache
end


registerForEvent("onOverlayOpen", function()
    isOverlayVisible = true
end)

registerForEvent("onOverlayClose", function()
    isOverlayVisible = false
end)

registerForEvent("onInit", function()
    Observe("CarComponent",  "OnVehicleRPMChange", function(self, rpm)
        -- print("[Immersive Engine Temps] RPM event fired, rpm=" .. tostring(rpm))
        if not self or not self.mounted then return end -- Is it the player vehicle?
        LIVE.rpm = tonumber(rpm)
    end)
end)


registerForEvent("onUpdate", function(dt)
    local player = Game.GetPlayer()

    local hour = Game.GetTimeSystem():GetGameTime():Hours()
    local ambientNow = TEMP.computeAmbient(hour, CONFIG)

    if not player then 
        sysCache = nil
        return 
    end
    
    local veh = player:GetMountedVehicle()

    if lastHour then
        local skippedSeconds = TEMP.detectTimeskip(lastHour, hour, CONFIG)
        if skippedSeconds then
            STATE.tickAllUnmounted(skippedSeconds, CONFIG, ambientNow)
        end
    end
    lastHour = hour

    if not veh then
        DEBUG.mounted = false
        STATE.tickAllUnmounted(dt, CONFIG, ambientNow)
        local sys = getSystem()
        if sys then sys:HideHUD() end
        return
    end


    local ok, speed = pcall(function() return veh:GetCurrentSpeed() end)
    local kmh = 0.0
    -- found speed function
    if ok and speed then
        --print("[Immersive Engine Temps] Got speed speed=" .. tostring(speed))
        kmh = math.abs(speed) * 3.6
    end
    local rpm = LIVE.rpm or 0

    local vehID = tostring(veh:GetEntityID().hash)

    local v = STATE.getOrCreate(vehID, ambientNow, CONFIG)

    local engineReadyness = TEMP.computeEngineReadyness(v, ambientNow, CONFIG)

    TEMP.UpdateMaxRpm(v, rpm)
    TEMP.tickCoolant(v, kmh, rpm, dt, CONFIG)
    TEMP.tickOil(v, kmh, rpm, dt, CONFIG)

    DEBUG.mounted = true
    DEBUG.kmh = kmh
    DEBUG.rpm = rpm
    DEBUG.hour = hour
    DEBUG.ambientNow = ambientNow
    DEBUG.vehID = vehID
    DEBUG.coolant_temp = v.coolant_temp
    DEBUG.coolant_heat = TEMP.DEBUG.coolant_heat
    DEBUG.coolant_cool = TEMP.DEBUG.coolant_cool
    DEBUG.coolant_target = TEMP.DEBUG.coolant_target
    DEBUG.coolant_delta = TEMP.DEBUG.coolant_delta
    DEBUG.oil_temp = v.oil_temp
    DEBUG.oil_heat = TEMP.DEBUG.oil_heat
    DEBUG.oil_target = TEMP.DEBUG.oil_target
    DEBUG.oil_delta = TEMP.DEBUG.oil_delta
    DEBUG.max_rpm = v.max_rpm
    DEBUG.engineReadyness = engineReadyness

    local sys = getSystem()
    if sys then
        sys:PushValues(math.floor(rpm), v.coolant_temp, v.oil_temp)
    end
end)


registerForEvent("onDraw", function()
    if not isOverlayVisible then return end
    ImGui.Begin("Engine Temp Sim")
    if DEBUG.mounted then
        ImGui.Text(("--- Raw Data ---"))
        ImGui.Text(("Vehicle ID: %s"):format(tostring(DEBUG.vehID)))
        ImGui.Text(("Speed: %.1f km/h"):format(DEBUG.kmh))
        ImGui.Text(("RPM: %.0f"):format(DEBUG.rpm))
        ImGui.Text(("Game hour: %.2f"):format(DEBUG.hour))

        ImGui.Separator()
        ImGui.Text(("--- Derived Values ---"))
        ImGui.Text(("Ambient now: %.1f C"):format(DEBUG.ambientNow))
        ImGui.Text(("Max RPM learned: %.0f"):format(DEBUG.max_rpm))
        ImGui.Text(("Coolant Heat: %.1f"):format(DEBUG.coolant_heat))
        ImGui.Text(("Coolant Cool: %.1f"):format(DEBUG.coolant_cool))
        ImGui.Text(("Coolant Target: %.1f"):format(DEBUG.coolant_target))
        ImGui.Text(("Coolant Delta: %.1f"):format(DEBUG.coolant_delta))
        ImGui.Text(("Oil Heat: %.1f"):format(DEBUG.oil_heat))
        ImGui.Text(("Oil Target: %.1f"):format(DEBUG.oil_target))
        ImGui.Text(("Oil Delta: %.1f"):format(DEBUG.oil_delta))

        ImGui.Separator()
        ImGui.Text(("--- Simulation ---"))
        ImGui.Text(("Coolant temp: %.1f C"):format(DEBUG.coolant_temp))
        ImGui.Text(("Oil temp: %.1f C"):format(DEBUG.oil_temp))
        ImGui.Text(("Engine Ready: %.0f %%"):format(DEBUG.engineReadyness * 100))

    else
        ImGui.Text("Not mounted.")
    end
    ImGui.End()        
end)