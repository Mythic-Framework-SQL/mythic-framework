function GetVehicleOwnerData(sid)
  local fetchUser = MySQL.single.await('SELECT First, Last, SID FROM `characters` WHERE SID = ?', { sid })
  return fetchUser or nil
end

_MDT.Vehicles = {
  Search = function(self, term, page, perPage)
    local p = promise.new()

    local skip = 0
    if page > 1 then
      skip = perPage * (page - 1)
    end

    local query = [[
      SELECT
        -- List the required fields here, e.g., VIN, RegisteredPlate, Make, Model, etc.
        VIN, RegisteredPlate, Make, Model, Type, Owner -- Add other required fields
      FROM vehicles
      WHERE
    ]]

    local params = {}

    if term and term:sub(1, 5) == "SID: " then
      local sid = tonumber(term:sub(6, #term))
      print('our search sid', sid)
      if sid then
        query = query ..
            "JSON_UNQUOTE(JSON_EXTRACT(Owner, '$.Id')) = ?"
        table.insert(params, sid)
      end
    else
      query = query .. [[
        (
          VIN LIKE ?
          OR RegisteredPlate LIKE ?
          OR CONCAT(Make, ' ', Model) LIKE ?
        )
      ]]
      local likeTerm = '%' .. term .. '%'
      table.insert(params, likeTerm)
      table.insert(params, likeTerm)
      table.insert(params, likeTerm)
    end

    query = query .. " LIMIT ? OFFSET ?"
    table.insert(params, perPage + 1)
    table.insert(params, skip)

    MySQL.Async.fetchAll(query, params, function(results)
      if not results then
        p:resolve(false)
        return
      end

      if #results > perPage then -- There are more results for the next pages
        table.remove(results)
        pageCount = page + 1
      end

      for k, v in pairs(results) do
        results[k].Owner = json.decode(v.Owner)
      end
      print(json.encode(results))
      p:resolve({
        data = results,
        pages = pageCount,
      })
    end)

    print(json.encode(p.data));
    return Citizen.Await(p)
  end,
  View = function(self, VIN)
    local fetchVehicle = MySQL.single.await('SELECT * FROM vehicles WHERE VIN = ?', { VIN })

    if not fetchVehicle then
      return false
    end

    fetchVehicle.Owner = json.decode(fetchVehicle.Owner)
    fetchVehicle.Storage = json.decode(fetchVehicle.Storage)

    if fetchVehicle.Owner then
      if fetchVehicle.Owner.Type == 0 then
        fetchVehicle.Owner.Person = GetVehicleOwnerData(fetchVehicle.Owner.Id)
      elseif fetchVehicle.Owner.Type == 1 or fetchVehicle.Owner.Type == 2 then
        local jobData = Jobs:DoesExist(fetchVehicle.Owner.Id, fetchVehicle.Owner.Workplace)
        if jobData then
          if jobData.Workplace then
            fetchVehicle.Owner.JobName = string.format('%s (%s)', jobData.Name, jobData.Workplace.Name)
          else
            fetchVehicle.Owner.JobName = jobData.Name
          end
        end
      end

      if fetchVehicle.Owner.Type == 2 then
        fetchVehicle.Owner.JobName = fetchVehicle.Owner.JobName .. " (Dealership Buyback)"
      end
    end

    if fetchVehicle.Storage then
      if fetchVehicle.Storage.Type == 0 then
        fetchVehicle.Storage.Name = Vehicles.Garages:Impound().name
      elseif fetchVehicle.Storage.Type == 1 then
        fetchVehicle.Storage.Name = Vehicles.Garages:Get(fetchVehicle.Storage.Id).name
      elseif fetchVehicle.Storage.Type == 2 then
        local prop = Properties:Get(fetchVehicle.Storage.Id)
        fetchVehicle.Storage.Name = prop?.label
      end
    end

    if fetchVehicle.RegisteredPlate then
      local flagged = Radar:CheckPlate(fetchVehicle.RegisteredPlate)
      if flagged ~= "Vehicle Flagged in MDT" then
        fetchVehicle.RadarFlag = flagged
      end
    end

    fetchVehicle.Flags = json.decode(fetchVehicle.Flags)
    fetchVehicle.Strikes = json.decode(fetchVehicle.Strikes)

    return fetchVehicle
  end,
  Flags = {
    Add = function(self, VIN, data, plate)
      local fetchVehicle = MySQL.single.await('SELECT `Flags` FROM `vehicles` WHERE VIN = ?', { VIN })
      if not fetchVehicle then
        return false
      end
      local flags = json.decode(fetchVehicle.Flags)
      if not flags then
        flags = {}
      end

      table.insert(flags, data)

      local updateFlags = MySQL.update.await('UPDATE `vehicles` SET Flags = ? WHERE VIN = ?', { json.encode(flags), VIN })
      if updateFlags > 0 and data.Type and data.Description and plate then
        Radar:AddFlaggedPlate(plate, 'Vehicle Flagged in MDT')
      end
      return true
    end,
    Remove = function(self, VIN, flag, plate, removeRadarFlag)
      local fetchVehicle = MySQL.single.await('SELECT `Flags` FROM `vehicles` WHERE VIN = ?', { VIN })
      if not fetchVehicle then
        return false
      end
      local flags = json.decode(fetchVehicle.Flags)
      if not flags then
        return false
      end

      for k, v in pairs(flags) do
        if v.Type == flag then
          table.remove(flags, k)
          break
        end
      end

      local updateFlags = MySQL.update.await('UPDATE `vehicles` SET Flags = ? WHERE VIN = ?', { json.encode(flags), VIN })
      if updateFlags > 0 and plate and removeRadarFlag then
        local isFlagged = Radar:CheckPlate(plate)
        if isFlagged == "Vehicle Flagged in MDT" then
          Radar:RemoveFlaggedPlate(plate)
        end
      end
      return true
    end,
  },
  UpdateStrikes = function(self, VIN, strikes)
    -- local fetchVehicles = MySQL.single.await('SELECT `Strikes` FROM `vehicles` WHERE VIN = ?', { VIN })
    -- if not fetchVehicles then
    --   return false
    -- end
    -- local Strikes = json.decode(fetchVehicles.Strikes)
    -- if not Strikes then
    --   Strikes = {}
    -- end
    -- table.insert(Strikes, strikes)



    local updateStrikes = MySQL.update.await('UPDATE `vehicles` SET Strikes = ? WHERE VIN = ?',
      { json.encode(strikes), VIN })
    return updateStrikes > 0
  end,
  GetStrikes = function(self, VIN)
    local fetchVehicles = MySQL.single.await('SELECT `Strikes` FROM `vehicles` WHERE VIN = ?', { VIN })
    if not fetchVehicles then
      return false
    end
    local Strikes = json.decode(fetchVehicles.Strikes)
    if not Strikes then
      return false
    end
    return Strikes
  end
}

AddEventHandler("MDT:Server:RegisterCallbacks", function()
  Callbacks:RegisterServerCallback("MDT:Search:vehicle", function(source, data, cb)
    if CheckMDTPermissions(source, false) then
      cb(MDT.Vehicles:Search(data.term, data.page, data.perPage))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:View:vehicle", function(source, data, cb)
    if CheckMDTPermissions(source, false) then
      cb(MDT.Vehicles:View(data))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:Create:vehicle-flag", function(source, data, cb)
    if CheckMDTPermissions(source, false, 'police') then
      cb(MDT.Vehicles.Flags:Add(data.parent, data.doc, data.plate))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:Delete:vehicle-flag", function(source, data, cb)
    if CheckMDTPermissions(source, false, 'police') then
      cb(MDT.Vehicles.Flags:Remove(data.parent, data.id, data.plate, data.removeRadarFlag))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:Update:vehicle-strikes", function(source, data, cb)
    if CheckMDTPermissions(source, false, 'police') then
      cb(MDT.Vehicles:UpdateStrikes(data.VIN, data.strikes))
    else
      cb(false)
    end
  end)
end)
