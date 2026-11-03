local isRunning = false

local DEFAULTS = {
    temperatureRise = 1.00,
    temperatureCool = 1.00,
    depthRate = 0.10,
    speedRate = 0.50,
    maxDuration = 120000,
    showTextUI = true,
    disableMovement = true,
}

local MIN_CUT_SPEED = 0.1

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local drillKeybinds = {
    depthUp = lib.addKeybind({
        name = 'pi-drilling_depth_up',
        description = 'Drilling: More depth',
        defaultMapper = 'keyboard',
        defaultKey = 'W',
    }),

    depthDown = lib.addKeybind({
        name = 'pi-drilling_depth_down',
        description = 'Drilling: Less depth',
        defaultMapper = 'keyboard',
        defaultKey = 'S',
    }),

    speedUp = lib.addKeybind({
        name = 'pi-drilling_speed_up',
        description = 'Drilling: More speed',
        defaultMapper = 'keyboard',
        defaultKey = 'D',
    }),

    speedDown = lib.addKeybind({
        name = 'pi-drilling_speed_down',
        description = 'Drilling: Less speed',
        defaultMapper = 'keyboard',
        defaultKey = 'A',
    }),
}

local function StartDrilling(options)
    if isRunning then
        return false, 'already_running'
    end

    options = options or {}
    local config = {}

    for key, value in pairs(DEFAULTS) do
        config[key] = value
    end

    for key, value in pairs(options) do
        if config[key] ~= nil then
            config[key] = value
        end
    end

    isRunning = true

    local active = true
    local result = false
    local scaleform

    local drillSpeed = 0.0
    local drillPos = 0.0
    local drillTemp = 0.0
    local holeDepth = 0.0
    local startedAt = GetGameTimer()

    local function cleanup()
        active = false
        if config.showTextUI then
            lib.hideTextUI()
        end
        
        if scaleform then
            pcall(function()
                scaleform:stopDrawing()
            end)

            pcall(function()
                scaleform:dispose()
            end)

            scaleform = nil
        end

        isRunning = false
    end

    local ok, err = pcall(function()
        scaleform = lib.scaleform:new({
            name = 'DRILLING',
            fullScreen = true
        })

        scaleform:callMethod('SET_SPEED', {0.0})
        scaleform:callMethod('SET_DRILL_POSITION', {0.0})
        scaleform:callMethod('SET_TEMPERATURE', {0.0})
        scaleform:callMethod('SET_HOLE_DEPTH', {0.0})
        scaleform:startDrawing()

        if config.showTextUI then
            lib.showTextUI('W / S: Depth  \nD / A: Speed')
        end

        while active do
            if config.disableMovement then
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 32, true)
                DisableControlAction(0, 33, true)
                DisableControlAction(0, 34, true)
                DisableControlAction(0, 35, true)
            end

            local dt = GetFrameTime()

            local lastPos = drillPos
            local lastSpeed = drillSpeed
            local lastTemp = drillTemp
            local lastHole = holeDepth

            local depthUp = drillKeybinds.depthUp:isControlPressed()
            local depthDown = drillKeybinds.depthDown:isControlPressed()
            local speedUp = drillKeybinds.speedUp:isControlPressed()
            local speedDown = drillKeybinds.speedDown:isControlPressed()

            if depthUp and not depthDown then
                local heatSlowdown = MIN_CUT_SPEED / math.max(MIN_CUT_SPEED, drillTemp)
                drillPos = clamp(drillPos + (config.depthRate * heatSlowdown * dt), 0.0, 1.0)
            elseif depthDown and not depthUp then
                drillPos = clamp(drillPos - (config.depthRate * dt), 0.0, 1.0)
            end

            if speedUp and not speedDown then
                drillSpeed = clamp(drillSpeed + (config.speedRate * dt), 0.0, 1.0)
            elseif speedDown and not speedUp then
                drillSpeed = clamp(drillSpeed - (config.speedRate * dt), 0.0, 1.0)
            end

            if drillPos > holeDepth then
                if drillSpeed > MIN_CUT_SPEED then
                    drillTemp = clamp(drillTemp + (drillSpeed * config.temperatureRise * dt), 0.0, 1.0)
                    holeDepth = drillPos
                else
                    drillPos = holeDepth
                end
            else
                drillTemp = clamp(drillTemp - (config.temperatureCool * dt), 0.0, 1.0)
            end

            if drillSpeed ~= lastSpeed then
                scaleform:callMethod('SET_SPEED', {drillSpeed})
            end

            if drillPos ~= lastPos then
                scaleform:callMethod('SET_DRILL_POSITION', {drillPos})
            end

            if drillTemp ~= lastTemp then
                scaleform:callMethod('SET_TEMPERATURE', {drillTemp})
            end

            if holeDepth ~= lastHole then
                scaleform:callMethod('SET_HOLE_DEPTH', {holeDepth})
            end

            if drillTemp >= 1.0 then
                result = false
                active = false
            elseif drillPos >= 1.0 then
                result = true
                active = false
            elseif config.maxDuration > 0 and (GetGameTimer() - startedAt) >= config.maxDuration then
                result = false
                active = false
            end

            Wait(0)
        end
    end)

    cleanup()

    if not ok then
        print(('[pi-drilling] Minigame error: %s'):format(tostring(err)))
        return false, 'error'
    end

    return result
end

exports('StartDrilling', StartDrilling)

RegisterNetEvent('pi-drilling:client:start', function(requestId, options)
    local result, reason = StartDrilling(options)
    TriggerEvent('pi-drilling:client:result', requestId, result, reason)
end)

exports('IsDrilling', function()
    return isRunning
end)