local requiredCharacterData = {
  SID = 1,
  User = 1,
  First = 1,
  Last = 1,
  Gender = 1,
  Origin = 1,
  Jobs = 1,
  DOB = 1,
  Callsign = 1,
  Phone = 1,
  Licenses = 1,
  Qualifications = 1,
  Flags = 1,
  Mugshot = 1,
  MDTSystemAdmin = 1,
  MDTHistory = 1,
  MDTSuspension = 1,
  Attorney = 1,
  LastClockOn = 1,
  TimeClockedOn = 1,
}

local _tablesToDecode = {
  'Jobs',
  'Origin',
  'Licenses',
  'Qualifications',
  'Flags',
  'MDTHistory',
  'MDTSuspension',
  'LastClockOn',
  'TimeClockedOn',
}

function GetCharacterVehiclesData(sid)
  local p = promise.new()

  local query = [[
    SELECT
      Type,
      VIN,
      Make,
      Model,
      RegisteredPlate
    FROM vehicles
    WHERE JSON_UNQUOTE(JSON_EXTRACT(Owner, '$.Type')) = ?
      AND JSON_UNQUOTE(JSON_EXTRACT(Owner, '$.Id')) = ?
  ]]
  local params = { 0, sid }

  local fetchVehicles = MySQL.query.await(query, params)
  return fetchVehicles
end

_MDT.People = {
  Search = {
    People = function(self, term)
      local p = promise.new()

      local query = [[
        SELECT
          First, Last, SID
        FROM characters
        WHERE
          (
            CONCAT(First, ' ', Last) LIKE ?
            OR CAST(SID AS CHAR) LIKE ?
          )
          AND (
            Deleted = 0
            OR Deleted IS NULL
          )
        LIMIT 12
      ]]
      local params = { '%' .. term .. '%', '%' .. term .. '%' }

      MySQL.Async.fetchAll(query, params, function(results)
        if not results then
          p:resolve(false)
          return
        end
        p:resolve(results)
      end)

      return Citizen.Await(p)
    end,
  },
  View = function(self, id, requireAllData)
    local SID = tonumber(id)
    local query = [[
      SELECT
        c.*,
        cp.end AS parole_end,
        cp.total AS parole_total,
        cp.parole AS parole_status,
        mrp.charges AS charges
      FROM characters c
      LEFT JOIN character_parole cp ON c.SID = cp.SID
      LEFT JOIN mdt_reports_people mrp ON c.SID = mrp.SID AND mrp.sentenced = 1 AND mrp.type = 'suspect' AND mrp.expunged = 0
      WHERE c.SID = ?
    ]]
    local params = { SID }

    local fetchCharacter = MySQL.single.await(query, params)
    if not fetchCharacter then
      return false
    end

    for k, v in pairs(_tablesToDecode) do
      if fetchCharacter[v] then
        fetchCharacter[v] = json.decode(fetchCharacter[v])
      end
    end

    local vehicles = GetCharacterVehiclesData(SID)
    local ownedBusinesses = {}

    if fetchCharacter.Jobs then
      for k, v in ipairs(fetchCharacter.Jobs) do
        local jobData = Jobs:Get(v.Id)
        if jobData.Owner and jobData.Owner == fetchCharacter.SID then
          table.insert(ownedBusinesses, v.Id)
        end
      end
    end

    local parole = {
      ["end"] = fetchCharacter.parole_end,
      total = fetchCharacter.parole_total,
      parole = fetchCharacter.parole_status
    }

    local convictions = {}
    local c = json.decode(fetchCharacter.charges)
    if c ~= nil then
      for _, ch in ipairs(c) do
        table.insert(convictions, ch)
      end
    end

    return {
      data = fetchCharacter,
      parole = parole,
      convictions = convictions,
      vehicles = vehicles,
      ownedBusinesses = ownedBusinesses,
    }
  end,
  Update = function(self, requester, id, key, value)
    local p = promise.new()
    local logVal = value
    if type(value) == "table" then
      logVal = json.encode(value)
    end


    if requester == -1 then
      MDTHistory = {
        Time = (os.time() * 1000),
        Char = -1,
        Log = string.format("System Updated Profile, Set %s To %s", key, logVal),
      }
    else
      MDTHistory = {
        Time = (os.time() * 1000),
        Char = requester:GetData("SID"),
        Log = string.format(
          "%s Updated Profile, Set %s To %s",
          requester:GetData("Character"):GetData("First") .. " " .. requester:GetData("Character"):GetData("Last"),
          key,
          logVal
        ),
      }
    end

    local updateUserMDTHistory = MySQL.update.await(
      "UPDATE characters SET MDTHistory = JSON_ARRAY_APPEND(MDTHistory, '$', ?) WHERE SID = ?", {
        json.encode(MDTHistory),
        id,
      })

    --now update characters, based upon key and value
    local updateCharacter = MySQL.update.await("UPDATE characters SET " .. key .. " = ? WHERE SID = ?", {
      logVal,
      id,
    })
    if updateCharacter > 0 then
      local target = Fetch:SID(id)
      if target then
        target:GetData("Character"):SetData(key, value)
      end
    else
      return false
    end

    return updateCharacter > 0
  end,
}

AddEventHandler("MDT:Server:RegisterCallbacks", function()
  Callbacks:RegisterServerCallback("MDT:InputSearch:people", function(source, data, cb)
    cb(MDT.People.Search:People(data.term))
  end)

  Callbacks:RegisterServerCallback("MDT:InputSearchSID", function(source, data, cb)
    cb(MDT.People.Search:People(data.term))
  end)

  Callbacks:RegisterServerCallback("MDT:Search:people", function(source, data, cb)
    cb(MDT.People.Search:People(data.term))
  end)

  Callbacks:RegisterServerCallback("MDT:View:person", function(source, data, cb)
    cb(MDT.People:View(data, true))
  end)

  Callbacks:RegisterServerCallback("MDT:Update:person", function(source, data, cb)
    local char = Fetch:Source(source)
    if char and CheckMDTPermissions(source, false) and data.SID then
      cb(MDT.People:Update(char, data.SID, data.Key, data.Data))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:CheckCallsign", function(source, data, cb)
    if CheckMDTPermissions(source, false) then
      local query = [[
        SELECT
          SID,
          Callsign
        FROM characters
        WHERE Callsign = ?
      ]]
      local params = { data }
      local fetchCallsign = MySQL.single.await(query, params)
      if fetchCallsign then
        cb(true)
      else
        cb(false)
      end
    else
      cb(false)
    end
  end)
end)
