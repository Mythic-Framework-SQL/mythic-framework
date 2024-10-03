local _ran = false

function Startup()
    if _ran then
        return
    end
    _ran = true

    local locations = json.decode([[
    [
        {
            "Type": "spawn",
            "Name": "Bolingbroke Penitentiary",
            "Heading": 90.70865631103516,
            "Coords": {
                "y": 2586.32958984375,
                "z": 45.6578369140625,
                "x": 1850.5845947265625
            }
        },
        {
            "Type": "spawn",
            "Name": "Mission Row PD",
            "Heading": 87.87401580810547,
            "Coords": {
                "y": -974.4263916015625,
                "z": 30.7120361328125,
                "x": 436.6681213378906
            }
        },
        {
            "Type": "spawn",
            "Name": "Sandy PD",
            "Heading": 257.9527587890625,
            "Coords": {
                "y": 3688.2724609375,
                "z": 34.2674560546875,
                "x": 1866.09228515625
            }
        },
        {
            "Type": "spawn",
            "Name": "Paleto PD",
            "Heading": 0,
            "Coords": {
                "y": 6026.5712890625,
                "z": 31.4871826171875,
                "x": -448.32525634765625
            }
        }
    ]
    ]])

    for _, location in ipairs(locations) do
        local exists = MySQL.single.await('SELECT 1 FROM `locations` WHERE `Type` = ? AND `Name` = ?', {location.Type, location.Name})
        if not exists then
            MySQL.insert.await('INSERT INTO `locations` (Type, Name, Heading, Coords) VALUES (?, ?, ?, ?)', 
            {location.Type, location.Name, location.Heading, json.encode(location.Coords)}, function(affectedRows)
                if affectedRows > 0 then
                    TriggerEvent("Locations:Server:Added", location.Type, location)
                end
            end)
        else
            --print("Location already exists: " .. location.Name) debug
        end
    end
end
