local Config = nil
local textUIData = {}
local animationInProgress = false
local panelCounter = 0

Citizen.CreateThread(function()
    while not Config do
        local configFile = LoadResourceFile(GetCurrentResourceName(), 'config.lua')
        if configFile then
            local env = { Config = {} }
            setmetatable(env, { __index = _G })
            local success = pcall(function()
                load(configFile, 'config.lua', 't', env)()
                Config = env.Config
            end)
            if success and Config and Config.Colors and Config.KeyMap then
                break
            end
        end
        Citizen.Wait(100)
    end
    SendNUIMessage({
        action = 'open'
    })
    SendNUIMessage({
        action = 'setColor',
        color = Config.Colors[Config.Color]
    })
    SendNUIMessage({
        action = 'setAnimationDuration',
        duration = Config.AnimationDuration
    })
    SendNUIMessage({
        action = 'showIndicator',
        x = 0.5,
        y = 0.5,
        text = '',
        key = ''
    })
end)

function DrawText(key, text, coords, colorName, showMarker, identifier)
    if not key or not text or not coords then
        return
    end
    while not Config or not Config.KeyMap do
        Citizen.Wait(10)
    end
    local keyCode = Config.KeyMap[string.upper(key)]
    if not keyCode then
        return
    end
    colorName = colorName or Config.Color
    showMarker = showMarker ~= false
    identifier = identifier or (key .. '_' .. text)
    
    for i, textData in ipairs(textUIData) do
        if textData.identifier == identifier then
            textData.key = key
            textData.text = text
            textData.coords = coords
            textData.keyCode = keyCode
            textData.colorName = colorName
            textData.showMarker = showMarker
            return
        end
    end
	panelCounter = panelCounter + 1
    table.insert(textUIData, {
         id = panelCounter,
         identifier = identifier,
         key = key,
         text = text,
         coords = coords,
         keyCode = keyCode,
         colorName = colorName,
         showMarker = showMarker,
         distance = 10.0,
         fullUIDistance = 5.0
     })
end

Citizen.CreateThread(function()
    while not Config or not Config.Colors do
        Citizen.Wait(10)
    end
    while true do
        Citizen.Wait(0)
        local playerCoords = GetEntityCoords(PlayerPedId())
        local hasActiveMarker = false
        for _, textData in ipairs(textUIData) do
            local dist = #(playerCoords - textData.coords)
            if dist < textData.distance then
                local onScreen, screenX, screenY = World3dToScreen2d(textData.coords.x, textData.coords.y, textData.coords.z + 1.0)
                if onScreen then
                    hasActiveMarker = true
                    local colorName = textData.colorName or Config.Color
                    local colorData = Config.Colors[colorName]
                    if colorData then
                        local r = colorData.r or 255
                        local g = colorData.g or 255
                        local b = colorData.b or 255
                        if textData.showMarker ~= false then
                            DrawMarker(27, 
                                textData.coords.x, 
                                textData.coords.y, 
                                textData.coords.z - 0.9,
                                0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0,
                                r, g, b, 180, false, true, 2, false, nil, nil, false
                            )
                        end
                    end
                    SendNUIMessage({
                        action = 'setColor',
                        panelId = textData.id,
                        color = colorData
                    })
                    if dist < textData.fullUIDistance then
                        SendNUIMessage({
                            action = 'showFull',
                            panelId = textData.id,
                            x = screenX,
                            y = screenY,
                            text = textData.text,
                            key = textData.key
                        })
                    else
                        SendNUIMessage({
                            action = 'showIndicator',
                            panelId = textData.id,
                            x = screenX,
                            y = screenY,
                            text = textData.text,
                            key = textData.key
                        })
                    end
                end
            end
        end
        if not hasActiveMarker then
            SendNUIMessage({
                action = 'close'
            })
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerCoords = GetEntityCoords(PlayerPedId())
        if not animationInProgress then
            for _, textData in ipairs(textUIData) do
                if textData.coords then
                    local dist = #(playerCoords - textData.coords)
                    if dist < 5.0 then
                        local keyCode = textData.keyCode
                        if keyCode and IsControlJustReleased(0, keyCode) then
                             SendNUIMessage({
                                 action = 'triggerAnimation',
                                 panelId = textData.id
                             })
                        end
                    end
                end
            end
        end
    end
end)

function GetTextUIData()
    return textUIData
end

function GetAnimationStatus()
    return animationInProgress
end

function ClearTextUI()
    textUIData = {}
end

RegisterNUICallback('close', function(data, cb)
    cb('ok')
end)

RegisterNUICallback('animationStarted', function(data, cb)
    animationInProgress = true
    cb('ok')
end)

RegisterNUICallback('animationEnded', function(data, cb)
    animationInProgress = false
    cb('ok')
end)

exports('DrawText', DrawText)
exports('GetTextUIData', GetTextUIData)
exports('GetAnimationStatus', GetAnimationStatus)
exports('ClearTextUI', ClearTextUI)
