AddEventHandler("MDT:Server:RegisterCallbacks", function()
  Callbacks:RegisterServerCallback("MDT:ViewVehicleFleet", function(source, data, cb)
    local hasPerms, loggedInJob = CheckMDTPermissions(source, {
      'FLEET_MANAGEMENT',
    })

    if hasPerms and loggedInJob then
      local query = [[
        SELECT
          VIN,
          Make,
          Model,
          Type,
          Owner,
          Storage,
          GovAssigned,
          RegistrationDate,
          RegisteredPlate
        FROM vehicles
        WHERE JSON_UNQUOTE(JSON_EXTRACT(Owner, '$.Type')) = ?
          AND JSON_UNQUOTE(JSON_EXTRACT(Owner, '$.Id')) = ?
      ]]
      local params = { 1, loggedInJob }

      MySQL.Async.fetchAll(query, params, function(results)
        if results then
          for k, v in ipairs(results) do
            v.Owner = json.decode(v.Owner)
            v.Storage = json.decode(v.Storage)

            if v.Storage then
              if v.Storage.Type == 0 then
                v.Storage.Name = Vehicles.Garages:Impound().name
              elseif v.Storage.Type == 1 then
                v.Storage.Name = Vehicles.Garages:Get(v.Storage.Id).name
              elseif v.Storage.Type == 2 then
                local prop = Properties:Get(v.Storage.Id)
                v.Storage.Name = prop and prop.label or nil
              end
            end
          end
          cb(results)
        else
          cb(false)
        end
      end)
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:SetAssignedDrivers", function(source, data, cb)
    local hasPerms, loggedInJob = CheckMDTPermissions(source, {
      'FLEET_MANAGEMENT',
    })

    if hasPerms and loggedInJob and data.vehicle and data.assigned then
      local ass = {}
      for k, v in ipairs(data.assigned) do
        table.insert(ass, {
          SID = v.SID,
          First = v.First,
          Last = v.Last,
          Callsign = v.Callsign
        })
      end

      local query = [[
        UPDATE vehicles
        SET GovAssigned = ?
        WHERE VIN = ?
      ]]
      local params = { ass, data.vehicle }

      local updatedVeh = MySQL.update.await(query, params)
      return cb(updatedVeh > 0)
    else
      return cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:TrackFleetVehicle", function(source, data, cb)
    local hasPerms, loggedInJob = CheckMDTPermissions(source, {
      'FLEET_MANAGEMENT',
    })

    if hasPerms and loggedInJob and data.vehicle then
      cb(Vehicles.Owned:Track(data.vehicle))
    else
      cb(false)
    end
  end)
end)
