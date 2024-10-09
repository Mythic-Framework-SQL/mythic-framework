local _ran = false

function Startup()
    if _ran then return end
    _ran = true

    local query = "SELECT * FROM vehicles"
    local results = MySQL.Sync.fetchAll(query)
    
    if results then
        local count = 0
        for _, vehicle in ipairs(results) do
            local owner = json.decode(vehicle.Owner)
            if owner.Type == 0 then
                count = count + 1
            end
        end
        Logger:Trace('Vehicles', string.format('Loaded ^2%s^7 Character Owned Vehicles', count))
        return count
    else
        Logger:Trace('Vehicles', 'Failed to load Character Owned Vehicles')
        return false
    end
    
    

    local query = "SELECT * FROM vehicles"
    local results = MySQL.Sync.fetchAll(query)

    if results then
        local count = 0
        for _, vehicle in ipairs(results) do
            local owner = json.decode(vehicle.Owner)
            if owner.Type == 1 then
                count = count + 1
            end
        end
        Logger:Trace('Vehicles', string.format('Loaded ^2%s^7 Fleet Owned Vehicles', count))
        return count
    else
        Logger:Trace('Vehicles', 'Failed to load Fleet Owned Vehicles')
        return false
    end

    Citizen.CreateThread(function()
        -- Let the server startup, no vehicles need to be saved in the first 2 mins
        Citizen.Wait(120000)
        while true do
            local savingVINs = {}
            for k, v in pairs(ACTIVE_OWNED_VEHICLES) do
                if v ~= nil then
                    local vData = v:GetData()
                    if vData.EntityId and DoesEntityExist(vData.EntityId) then
                        local vehEnt = Entity(vData.EntityId)
                        if (vehEnt and vehEnt.state and vehEnt.state.NeedSave) then
                            vehEnt.state.NeedSave = false
                            table.insert(savingVINs, vData.VIN)
                        end
                    end
                end
            end

            if #savingVINs > 0 then
                local timeSpread = math.floor((720 * 1000) / #savingVINs)
                if timeSpread < 2000 then
                    timeSpread = 2000
                end
    
                Logger:Info('Vehicles', 'Running Periodical Save For '.. #savingVINs .. ' Vehicles')
    
                for k, v in ipairs(savingVINs) do
                    SaveVehicle(v)
                    Citizen.Wait(timeSpread)
                end
            else
                Citizen.Wait(180000)
            end
        end
    end)
end