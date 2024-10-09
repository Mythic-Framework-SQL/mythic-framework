_loadedFurniture = {}

--Broken by SicklyAbility #Fanks

function CreateFurnitureCallbacks()
    Callbacks:RegisterServerCallback("Properties:PlaceFurniture", function(source, data, cb)
        local char = Fetch:Source(source):GetData("Character")
        if char then
            local insideProperty = GlobalState[string.format("%s:Property", source)]
            if insideProperty and data.model and data.coords and data.heading then
                local property = _properties[insideProperty]
                if property and (property.keys ~= nil and property.keys[char:GetData("ID")]) and _loadedFurniture[property.id]  and property.keys[char:GetData("ID")] ~= nil and (property.keys[char:GetData("ID")].Permissions?.furniture or property.keys[char:GetData("ID")].Owner) then
                    local fData = FurnitureConfig[data.model]
                    if fData then
                        local currentId = 0
                        if #_loadedFurniture[property.id] > 0 and _loadedFurniture[property.id][#_loadedFurniture[property.id]] then
                            currentId = _loadedFurniture[property.id][#_loadedFurniture[property.id]].id
                        end

                        local addedItem = {
                            id = currentId + 1,
                            name = fData.name,
                            model = data.model,
                            coords = data.coords,
                            heading = data.heading,
                            data = data.data or {},
                        }

                        table.insert(_loadedFurniture[property.id], addedItem)

                        local updated = SetPropertyFurniture(property.id, _loadedFurniture[property.id], {
                            ID = char:GetData("ID"),
                            SID = char:GetData("SID"),
                            First = char:GetData("First"),
                            Last = char:GetData("Last")
                        })

                        if updated then
                            if _insideProperties[property.id] then
                                for k, v in pairs(_insideProperties[property.id]) do
                                    TriggerClientEvent("Furniture:Client:AddItem", k, property.id, #_loadedFurniture[property.id], addedItem)
                                end
                            end

                            cb(true)
                            return
                        end
                    end
                end
            end
        end

        cb(false)
    end)

    Callbacks:RegisterServerCallback("Properties:MoveFurniture", function(source, data, cb)
        local char = Fetch:Source(source):GetData("Character")
        if char then
            local insideProperty = GlobalState[string.format("%s:Property", source)]
            if insideProperty and data.id and data.coords and data.heading then
                local property = _properties[insideProperty]
                if property and (property.keys ~= nil and property.keys[char:GetData("ID")]) and _loadedFurniture[property.id] and property.keys[char:GetData("ID")] ~= nil and (property.keys[char:GetData("ID")].Permissions?.furniture or property.keys[char:GetData("ID")].Owner) then
                    local index = 0
                    for k, v in ipairs(_loadedFurniture[property.id]) do
                        if v.id == data.id then
                            index = k
                        end
                    end

                    if index > 0 then
                        _loadedFurniture[property.id][index].coords = data.coords
                        _loadedFurniture[property.id][index].heading = data.heading

                        local updated = SetPropertyFurniture(property.id, _loadedFurniture[property.id], {
                            ID = char:GetData("ID"),
                            SID = char:GetData("SID"),
                            First = char:GetData("First"),
                            Last = char:GetData("Last")
                        })

                        if updated then
                            if _insideProperties[property.id] then
                                for k, v in pairs(_insideProperties[property.id]) do
                                    TriggerClientEvent("Furniture:Client:MoveItem", k, property.id, data.id, _loadedFurniture[property.id][index])
                                end
                            end

                            cb(true)
                            return
                        end
                    end
                end
            end
        end

        cb(false)
    end)

    Callbacks:RegisterServerCallback("Properties:DeleteFurniture", function(source, data, cb)
        local char = Fetch:Source(source):GetData("Character")
        if char then
            local insideProperty = GlobalState[string.format("%s:Property", source)]
            if insideProperty and data.id then
                local property = _properties[insideProperty]
                if property and (property.keys ~= nil and property.keys[char:GetData("ID")]) and _loadedFurniture[property.id] and property.keys[char:GetData("ID")] ~= nil and (property.keys[char:GetData("ID")].Permissions?.furniture or property.keys[char:GetData("ID")].Owner) then

                    local nF = {}
                    for k, v in ipairs(_loadedFurniture[property.id]) do
                        if v.id ~= data.id then
                            table.insert(nF, v)
                        end
                    end

                    local updated = SetPropertyFurniture(property.id, nF, {
                        ID = char:GetData("ID"),
                        SID = char:GetData("SID"),
                        First = char:GetData("First"),
                        Last = char:GetData("Last")
                    })

                    if updated then
                        if _insideProperties[property.id] then
                            for k, v in pairs(_insideProperties[property.id]) do
                                TriggerClientEvent("Furniture:Client:DeleteItem", k, property.id, data.id, _loadedFurniture[property.id])
                            end
                        end

                        cb(true, _loadedFurniture[property.id])
                        return
                    end
                end
            end
        end

        cb(false)
    end)
end

function GetPropertyFurniture(pId, pInt)
    if _loadedFurniture[pId] then
        return _loadedFurniture[pId]
    end

    local results = MySQL.single.await('SELECT furniture FROM properties_furniture WHERE property = @property', {
        ['@property'] = pId
    })

    local furniture
    if results and #results > 0 and results[1] and results[1].furniture then
        furniture = json.decode(results[1].furniture)
    else
        local interior = PropertyInteriors[pInt]
        if interior and interior.defaultFurniture then
            furniture = interior.defaultFurniture
        else
            furniture = {}
        end
    end

    _loadedFurniture[pId] = furniture

    return furniture
end


function SetPropertyFurniture(pId, newFurniture, updater)
    local success = MySQL.query.await('UPDATE properties_furniture SET furniture = @furniture, updatedTime = @updatedTime, updatedBy = @updatedBy WHERE property = @property', {
        ['@furniture'] = json.encode(newFurniture),
        ['@updatedTime'] = os.time(),
        ['@updatedBy'] = updater,
        ['@property'] = pId
    })

    if success == 0 then -- if not fucking rows updated insert a new shit record FUCK SAKE
        success = MySQL.query.await('INSERT INTO properties_furniture (property, furniture, updatedTime, updatedBy) VALUES (@property, @furniture, @updatedTime, @updatedBy)', {
            ['@property'] = pId,
            ['@furniture'] = json.encode(newFurniture),
            ['@updatedTime'] = os.time(),
            ['@updatedBy'] = updater
        })
    end

    if success then
        _loadedFurniture[pId] = newFurniture
        return newFurniture
    else
        return false
    end
end


function DeletePropertyFurniture(pId)
    local success = MySQL.query.await('DELETE FROM properties_furniture WHERE property = @property', {
        ['@property'] = pId
    })

    if success then
        _loadedFurniture[pId] = nil
        return true
    else
        return false
    end
end
