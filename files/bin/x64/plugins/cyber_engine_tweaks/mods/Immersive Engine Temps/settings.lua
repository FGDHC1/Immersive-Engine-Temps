local DEFAULTS = require("config")

local S = {
    values   = {}, -- current values
    global   = {}, -- changes from defaults
    vehicles = {},
    presets  = {},
    dirty    = false, -- unsaved changes?
}

local SAVE_FILE = "settings.json"

local GLOBAL_ONLY = {
    hud2d_enabled = true,
    hud2d_x       = true,
    hud2d_y       = true,
    hud2d_scale   = true,
    hud2d_opacity = true,
    hud2d_unit    = true,
    hud3d_enabled = true,
}
local PLACEMENT = {
    hud3d_x = true,
    hud3d_y = true,
    hud3d_z = true,
    hud3d_pitch = true,
    hud3d_yaw = true,
    hud3d_roll = true,
    hud3d_scale = true,
}

local function apply(target, src)
    if type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if DEFAULTS[k] ~= nil then
            target[k] = v
        end
    end
end

function S.resolve(key)
    for k, v in pairs(DEFAULTS) do
        S.values[k] = v
    end

    apply(S.values, S.global)

    if key and S.vehicles[key] then
        apply(S.values, S.vehicles[key].values)
    end
end

function S.load()
    local file = io.open(SAVE_FILE, "r")
    if file then
        local content = file:read("*a")
        file:close()

        local ok, decoded = pcall(json.decode, content)
        if ok and type(decoded) == "table" then
            S.global   = decoded.global   or {}
            S.vehicles = decoded.vehicles or {}
            S.presets = decoded.presets or {}
        else
            print("[Immersive Engine Temps] settings.json unlesbar, nutze Defaults")
        end
    end

    S.resolve(nil)
    S.dirty = false
end

function S.write()
    local ok, encoded = pcall(json.encode, { global = S.global, vehicles = S.vehicles, presets = S.presets })
    if not ok then
        print("[Immersive Engine Temps] Speichern fehlgeschlagen: " .. tostring(encoded))
        return
    end

    local file = io.open(SAVE_FILE, "w")
    if not file then return end
    file:write(encoded)
    file:close()
end

local function diff(base, skipGlobalOnly)
    local out = {}
    for k in pairs(DEFAULTS) do
        if not (skipGlobalOnly and GLOBAL_ONLY[k]) then
            if S.values[k] ~= base[k] then
                out[k] = S.values[k]
            end
        end
    end
    return out
end

function S.saveGlobal()
    S.global = diff(DEFAULTS)
    S.write()
    S.dirty = false
end

function S.saveVehicle(key, name)
    if not key then return end

    local base = {}
    for k, v in pairs(DEFAULTS) do base[k] = v end
    apply(base, S.global)

    S.vehicles[key] = { name = name or key, values = diff(base, true), }
    S.write()
    S.dirty = false
end

function S.clearVehicle(key)
    if not key then return end
    S.vehicles[key] = nil
    S.write()
end

local function loadVehicleValues(values)
        for k, v in pairs(DEFAULTS) do
        if not GLOBAL_ONLY[k] and not PLACEMENT[k] then
            if S.global[k] ~= nil then
                S.values[k] = S.global[k]
            else
                S.values[k] = v
            end
        end
    end
    apply(S.values, values)
    S.dirty = true
end


function S.import(key)
    local entry = S.vehicles[key]
    if not entry then return end
    loadVehicleValues(entry.values)
end

function S.savePreset(name)
    if not name or name == "" then return end
    local presetValues = {}
    for k in pairs(DEFAULTS) do
        if not GLOBAL_ONLY[k] and not PLACEMENT[k] then
            presetValues[k] = S.values[k]
        end
    end
    S.presets[name] = { values = presetValues }
    S.write()
end

function S.loadPreset(name)
    local entry = S.presets[name]
    if not entry then return end
    loadVehicleValues(entry.values)
end

function S.deletePreset(name)
    if not name then return end
    S.presets[name] = nil
    S.write()
end


function S.resetHud()
    for k in pairs(GLOBAL_ONLY) do
        S.values[k] = DEFAULTS[k]
    end
    S.dirty = true
end

return S