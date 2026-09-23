local STATE = require("vehicle_state")
local TEMP = require("temp_logic")
local SETTINGS = require("settings")
local CONFIG = SETTINGS.values
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

local lastSec = nil

local sysCache = nil

local vehKey = nil
local vehName = nil

local hudDirty = true

local selectedPreset
local newPresetName = ""

local function discardChanges()
    SETTINGS.resolve(vehKey)
    SETTINGS.dirty = false
    hudDirty = true
end

local function getSystem()
    if sysCache then return sysCache end
    local c = Game.GetScriptableSystemsContainer()
    if not c then return nil end
    sysCache = c:Get("ImmersiveEngineTemps.EngineTempSystem")
    return sysCache
end

local function getVehKey(veh)
    local ok, rec = pcall(function() return veh:GetRecordID() end)
    if not ok or not rec then return nil end
    local key = rec.value
    if key == nil or key == "" then key = tostring(rec) end
    return key
end

registerForEvent("onOverlayOpen", function()
    isOverlayVisible = true
end)

registerForEvent("onOverlayClose", function()
    isOverlayVisible = false
end)

registerForEvent("onShutdown", function() 
    SETTINGS.write() 
end)

registerForEvent("onInit", function()
    SETTINGS.load()
    Observe("CarComponent",  "OnVehicleRPMChange", function(self, rpm)
        -- print("[Immersive Engine Temps] RPM event fired, rpm=" .. tostring(rpm))
        if not self or not self.mounted then return end -- Is it the player vehicle?
        LIVE.rpm = tonumber(rpm)
    end)
end)


registerForEvent("onUpdate", function(dt)
    local player = Game.GetPlayer()

    local gTime = Game.GetTimeSystem():GetGameTime()
    local nowSec = gTime:Hours() * 3600 + gTime:Minutes() * 60 + gTime:Seconds() 
    local ambientNow = TEMP.computeAmbient(nowSec / 3600.0, CONFIG)

    if not player then 
        sysCache = nil
        hudDirty = true
        return 
    end
    
    local veh = player:GetMountedVehicle()
    local skipID = nil
    if veh then skipID = tostring(veh:GetEntityID().hash) end

    if lastSec then
        local skippedSeconds = TEMP.detectTimeskip(lastSec, nowSec, CONFIG)
        if skippedSeconds then
            STATE.tickAllUnmounted(skippedSeconds, CONFIG, ambientNow, skipID)
        end
    end
    lastSec = nowSec

    if not veh then
        DEBUG.mounted = false
        STATE.tickAllUnmounted(dt, CONFIG, ambientNow, skipID)
        local sys = getSystem()
        if sys then sys:HideHUD() end
        if vehKey ~= nil then
            vehKey = nil
            discardChanges()
        end
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
    local key = getVehKey(veh)
    if key ~= vehKey then
        vehKey = key
        vehName = veh:GetDisplayName()
        discardChanges()
    end

    local v = STATE.getOrCreate(vehID, ambientNow, CONFIG)

    local engineReadyness = TEMP.computeEngineReadyness(v, ambientNow, CONFIG)

    TEMP.UpdateMaxRpm(v, rpm)
    TEMP.tickCoolant(v, kmh, rpm, dt, CONFIG)
    TEMP.tickOil(v, kmh, rpm, dt, CONFIG)

    DEBUG.mounted = true
    DEBUG.kmh = kmh
    DEBUG.rpm = rpm
    DEBUG.hour = nowSec / 3600.0
    DEBUG.ambientNow = ambientNow
    DEBUG.vehID = vehID
    DEBUG.vehKey = vehKey
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
        if CONFIG.hud2d_enabled then
            if hudDirty then
                sys:PushConfig(CONFIG.hud2d_x, CONFIG.hud2d_y, CONFIG.hud2d_scale, CONFIG.hud2d_opacity, CONFIG.hud2d_unit == "F")
                hudDirty = false
            end
            sys:PushValues(math.floor(rpm), v.coolant_temp, v.oil_temp)
        else
            sys:HideHUD()
        end
    end
end)


registerForEvent("onDraw", function()
    if not isOverlayVisible then return end
    ImGui.Begin("Engine Temp Sim")
    if ImGui.BeginTabBar("##maintabs") then
    
        if ImGui.BeginTabItem("Debug") then
            if DEBUG.mounted then
                if ImGui.CollapsingHeader("Raw Data") then
                    ImGui.Text(("Record: %s"):format(tostring(DEBUG.vehKey)))
                    ImGui.Text(("Vehicle ID: %s"):format(tostring(DEBUG.vehID)))
                    ImGui.Text(("Speed: %.1f km/h"):format(DEBUG.kmh))
                    ImGui.Text(("RPM: %.0f"):format(DEBUG.rpm))
                    ImGui.Text(("Game hour: %.2f"):format(DEBUG.hour))
                end

                ImGui.Separator()
                if ImGui.CollapsingHeader(("Derived Values")) then
                    ImGui.Text(("Ambient now: %.1f C"):format(DEBUG.ambientNow))
                    ImGui.Text(("Max RPM learned: %.0f"):format(DEBUG.max_rpm))
                    ImGui.Text(("Coolant Heat: %.1f"):format(DEBUG.coolant_heat))
                    ImGui.Text(("Coolant Cool: %.1f"):format(DEBUG.coolant_cool))
                    ImGui.Text(("Coolant Target: %.1f"):format(DEBUG.coolant_target))
                    ImGui.Text(("Coolant Delta: %.1f"):format(DEBUG.coolant_delta))
                    ImGui.Text(("Oil Heat: %.1f"):format(DEBUG.oil_heat))
                    ImGui.Text(("Oil Target: %.1f"):format(DEBUG.oil_target))
                    ImGui.Text(("Oil Delta: %.1f"):format(DEBUG.oil_delta))
                end

                ImGui.Separator()
                if ImGui.CollapsingHeader(("Simulation")) then
                    ImGui.Text(("Coolant temp: %.1f C"):format(DEBUG.coolant_temp))
                    ImGui.Text(("Oil temp: %.1f C"):format(DEBUG.oil_temp))
                    ImGui.Text(("Engine Ready: %.0f %%"):format(DEBUG.engineReadyness * 100))
                end
            else
                ImGui.Text("Not mounted.")
            end
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Settings") then
            if DEBUG.mounted then
                local used
                local changed = false

                CONFIG.coolant_setpoint_c, used = ImGui.SliderFloat("Setpoint C", CONFIG.coolant_setpoint_c, 60, 120)
                changed = changed or used

                CONFIG.k_coolant, used = ImGui.SliderFloat("k coolant", CONFIG.k_coolant, 0.001, 0.100)
                changed = changed or used

                CONFIG.coolant_heat_max_c, used = ImGui.SliderFloat("Heat max C", CONFIG.coolant_heat_max_c, 0, 60)
                changed = changed or used

                CONFIG.coolant_cool_max_c, used = ImGui.SliderFloat("Cool max C", CONFIG.coolant_cool_max_c, 0, 40)
                changed = changed or used

                CONFIG.k_oil, used = ImGui.SliderFloat("k oil", CONFIG.k_oil, 0.001, 0.100)
                changed = changed or used

                CONFIG.oil_offset_c, used = ImGui.SliderFloat("Oil offset C", CONFIG.oil_offset_c, 0, 40)
                changed = changed or used

                if changed then SETTINGS.dirty = true end

                if SETTINGS.dirty then
                    ImGui.TextColored(1.0, 0.6, 0.1, 1.0, "THESE VALUES HAVEN'T YET BEEN SAVED")
                else
                    ImGui.Text("Saved")
                end

                ImGui.Separator()

                if ImGui.Button("Save Global") then
                    SETTINGS.saveGlobal()
                end
                ImGui.SameLine()
                if ImGui.Button("Save To this Car") then
                    SETTINGS.saveVehicle(vehKey, vehName)
                end
                ImGui.SameLine()
                if ImGui.Button("Reset Car Setting") then
                    SETTINGS.clearVehicle(vehKey)
                    discardChanges()
                end
                if SETTINGS.dirty then
                    ImGui.SameLine()
                    if ImGui.Button("Discard Changes##settings") then
                        discardChanges()
                    end
                end
                ImGui.Separator()
                ImGui.Text("Presets")
                local names = {}
                for name in pairs(SETTINGS.presets) do
                    table.insert(names, name)
                end
                table.sort(names)
                local preview = selectedPreset or "Select..."
                if ImGui.BeginCombo("##presets", preview) then
                    for _, name in ipairs(names) do
                        if ImGui.Selectable(name, selectedPreset == name) then
                            selectedPreset = name
                        end
                    end
                    ImGui.EndCombo()
                end
                if selectedPreset and SETTINGS.presets[selectedPreset] then
                    if ImGui.Button("Load##preset") then
                        SETTINGS.loadPreset(selectedPreset)
                    end
                    ImGui.SameLine()
                    if ImGui.Button("Overwrite##preset") then
                        SETTINGS.savePreset(selectedPreset)
                    end
                    ImGui.SameLine()
                    if ImGui.Button("Delete##preset") then
                        SETTINGS.deletePreset(selectedPreset)
                        selectedPreset = nil
                    end
                end
                newPresetName = ImGui.InputText("##newpreset", newPresetName, 32)
                ImGui.SameLine()
                if SETTINGS.presets[newPresetName] then
                    ImGui.Text("Preset name already exists")
                elseif ImGui.Button("Save new preset") and newPresetName ~= "" then
                    SETTINGS.savePreset(newPresetName)
                    selectedPreset = newPresetName
                    newPresetName = ""
                end
            else
                ImGui.Text("Not mounted")
            end
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("2D HUD") then
            local used
            local changed = false

            CONFIG.hud2d_enabled, used = ImGui.Checkbox("HUD enabled", CONFIG.hud2d_enabled)
            changed = changed or used

            CONFIG.hud2d_x, used = ImGui.DragFloat("Offset X", CONFIG.hud2d_x, 1.0, -2000, 2000, "%.0f")
            changed = changed or used

            CONFIG.hud2d_y, used = ImGui.DragFloat("Offset Y", CONFIG.hud2d_y, 1.0, -2000, 2000, "%.0f")
            changed = changed or used

            CONFIG.hud2d_scale, used = ImGui.SliderFloat("Scale", CONFIG.hud2d_scale, 0.2, 3.0)
            changed = changed or used

            CONFIG.hud2d_opacity, used = ImGui.SliderFloat("Opacity", CONFIG.hud2d_opacity, 0.0, 1.0)
            changed = changed or used

            ImGui.Text("Unit")
            ImGui.SameLine()
            if ImGui.RadioButton("C", CONFIG.hud2d_unit == "C") then
                CONFIG.hud2d_unit = "C"
                changed = true
            end
            ImGui.SameLine()
            if ImGui.RadioButton("F", CONFIG.hud2d_unit == "F") then
                CONFIG.hud2d_unit = "F"
                changed = true
            end

            if changed then
                SETTINGS.dirty = true
                hudDirty = true
            end

            if SETTINGS.dirty then
                ImGui.TextColored(1.0, 0.6, 0.1, 1.0, "THESE VALUES HAVEN'T YET BEEN SAVED")
            else
                ImGui.Text("Saved")
            end

            ImGui.Separator()
            
            if ImGui.Button("Reset to defaults##hud2d") then
                SETTINGS.resetHud()
                hudDirty = true
            end
            ImGui.SameLine()
            if ImGui.Button("Save Global##hud2d") then
                SETTINGS.saveGlobal()
            end

            if SETTINGS.dirty then
                ImGui.SameLine()
                if ImGui.Button("Discard Changes##hud2d") then
                    discardChanges()
                end
            end


            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end

    ImGui.End()
end)