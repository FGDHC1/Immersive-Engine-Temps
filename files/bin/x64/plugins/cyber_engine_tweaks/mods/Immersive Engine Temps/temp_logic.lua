local T = {}

T.DEBUG = {
    engine_readyness = 0.0,
    coolant_heat = 0.0,
    coolant_cool = 0.0,
    coolant_target = 0.0,
    coolant_delta = 0.0,
    oil_heat = 0.0,
    oil_target = 0.0,
    oil_delta = 0.0
}

local function clamp01(x)
    if x < 0.0 then return 0.0 end
    if x > 1.0 then return 1.0 end
    return x
end

function T.UpdateMaxRpm(v, rpm)
    if rpm > v.max_rpm then
        v.max_rpm = rpm
    end
end

function T.tickCoolant(v, kmh, rpm, dt, CFG)
    -- normalize RPM to 0-1 range
    local rpmNorm = clamp01((rpm - CFG.idle_rpm) / (v.max_rpm - CFG.idle_rpm))

    -- normalize speed to 0-1 range
    local spdNorm = clamp01(kmh / CFG.cool_speed_ref_kmh)

    -- compute target temperature
    local heat = rpmNorm * CFG.coolant_heat_max_c
    local cool = spdNorm * CFG.coolant_cool_max_c
    local target = CFG.coolant_setpoint_c + heat - cool

    local delta_value_1 = v.coolant_temp

    -- pullToward target temperature
    v.coolant_temp = v.coolant_temp + (target - v.coolant_temp) * CFG.k_coolant * dt

    local delta_value_2 = v.coolant_temp

    -- max threshold too simplify things
    if v.coolant_temp > 130 then 
        v.coolant_temp = 130
    end

    T.DEBUG.coolant_heat = heat
    T.DEBUG.coolant_cool = cool
    T.DEBUG.coolant_target = target
    T.DEBUG.coolant_delta = (delta_value_2 - delta_value_1) / dt
end

function T.tickOil(v, kmh, rpm, dt, CFG)
    -- normalize RPM to 0-1 range
    local rpmNorm = clamp01((rpm - CFG.idle_rpm) / (v.max_rpm - CFG.idle_rpm))

    -- No dedicated oil cooler: in Night City, corpos and gangs cut every corner
    -- that isn't survival-critical this part gets skipped as long as the
    -- regular coolant loop barely keeps up.

    -- compute target temperature
    local heat = rpmNorm * CFG.oil_self_heat_max_c
    local target = v.coolant_temp + CFG.oil_offset_c + heat

    local delta_value_1 = v.oil_temp

    -- pullToward target temperature
    v.oil_temp = v.oil_temp + (target - v.oil_temp) * CFG.k_oil * dt

    local delta_value_2 = v.oil_temp

    -- max threshold too simplify things
    if v.oil_temp > 160 then 
        v.oil_temp = 160
    end

    T.DEBUG.oil_heat = heat
    T.DEBUG.oil_target = target
    T.DEBUG.oil_delta = (delta_value_2 - delta_value_1) / dt
end

function T.tickUnmounted(v, ambientNow, dt, CFG)
    v.coolant_temp = v.coolant_temp + (ambientNow - v.coolant_temp) * math.exp(-CFG.k_unmounted * dt)
    v.oil_temp = v.oil_temp + (ambientNow - v.oil_temp) * math.exp(-CFG.k_unmounted * dt)
end

local function easeInOut(progress)
    return (1.0 - math.cos(progress * math.pi)) / 2.0
end

function T.computeAmbient(hour, CFG)
    if hour >= CFG.ambient_low_hour and hour < CFG.ambient_peak_hour then
        -- rising phase low --> peak
        local span = CFG.ambient_peak_hour - CFG.ambient_low_hour
        local progress = (hour - CFG.ambient_low_hour) / span
        local eased = easeInOut(progress)
        return CFG.ambient_low_c + (CFG.ambient_peak_c - CFG.ambient_low_c) * eased
    else
        -- falling phase peak --> low
        local span = 24 - CFG.ambient_peak_hour + CFG.ambient_low_hour
        local hoursSincePeak = (hour - CFG.ambient_peak_hour) % 24
        local progress = hoursSincePeak / span
        local eased = easeInOut(progress)
        return CFG.ambient_peak_c + (CFG.ambient_low_c - CFG.ambient_peak_c) * eased
    end
end

function T.computeEngineReadyness(v, ambientNow, CFG)
    local coolant_delta = CFG.coolant_ready_temp - v.coolant_temp
    local oil_delta = CFG.oil_ready_temp - v.oil_temp

    local coolantReady = clamp01(1.0 - coolant_delta / (CFG.coolant_ready_temp - ambientNow))
    local oilReady = clamp01(1.0 - oil_delta / (CFG.oil_ready_temp - ambientNow))

    return clamp01(coolantReady * 0.8 + oilReady * 0.2)
end

function T.detectTimeskip(lastHour, currentHour, CFG)
    local difference = (currentHour - lastHour) % 24
    if difference > CFG.timeskipDetectionThreshold then
        return difference * 3600
    end
    return nil
end
return T