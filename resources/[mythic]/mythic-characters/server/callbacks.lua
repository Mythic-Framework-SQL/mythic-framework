local _tempLastLocation = {}
local _lastSpawnLocations = {}

RegisterNetEvent("characters:Server:StoreUpdate")
AddEventHandler("characters:Server:StoreUpdate", function()
  local src = source
  local char = Fetch:Source(src):GetData("Character")

  if char ~= nil then
    local data = char:GetData()
  end
end)

function RegisterCallbacks()
  Callbacks:RegisterServerCallback("Characters:GetServerData", function(source, data, cb)
    while Fetch:Source(source) == nil do
      Citizen.Wait(100)
    end
    local motd = GetConvar("motd", "Welcome to MythicRP")
    cb({ changelog = nil, motd = motd })
  end)

  Callbacks:RegisterServerCallback("Characters:GetCharacters", function(source, data, cb)
    local player = Fetch:Source(source)
    local myCharacters = MySQL.query.await(
      [[
        SELECT * FROM `characters` WHERE `User` = @User AND `Deleted` = 0
      ]],
      {
        ["@User"] = player:GetData("AccountID"),
      }
    )
    if #myCharacters == 0 then
      return cb({})
    end

    local cData = {}
    for k, v in ipairs(myCharacters) do
      local pedData = MySQL.single.await(
        [[
          SELECT * FROM `peds` WHERE `Char` = @Char
        ]],
        {
          ["@Char"] = v._id,
        }
      )
      table.insert(cData, {
        ID = v._id,
        First = v.First,
        Last = v.Last,
        Phone = v.Phone,
        DOB = v.DOB,
        Gender = v.Gender,
        LastPlayed = v.LastPlayed,
        Jobs = json.decode(v.Jobs),
        SID = v.SID,
        GangChain = json.decode(v.GangChain) or false,
        Preview = pedData and json.decode(pedData?.ped) or false
      })
    end

    player:SetData("Characters", cData)
    cb(cData)
  end)

  Callbacks:RegisterServerCallback("Characters:CreateCharacter", function(source, data, cb)
    local player = Fetch:Source(source)
    local pNumber = GeneratePhoneNumber()
    while IsNumberInUse(pNumber) do
      pNumber = GeneratePhoneNumber()
    end

    local doc = {
      User = player:GetData("AccountID"),
      First = data.first,
      Last = data.last,
      Phone = pNumber,
      Gender = tonumber(data.gender),
      Bio = data.bio,
      Origin = data.origin,
      DOB = data.dob,
      LastPlayed = -1,
      Jobs = {},
      SID = Sequence:Get("Character"),
      Cash = 5000,
      New = true,
      Licenses = {
        Drivers = {
          Active = true,
          Points = 0,
          Suspended = false,
        },
        Weapons = {
          Active = false,
          Suspended = false,
        },
        Hunting = {
          Active = false,
          Suspended = false,
        },
        Fishing = {
          Active = false,
          Suspended = false,
        },
        Pilot = {
          Active = false,
          Suspended = false,
        },
      },
      ICU = {},
    }

    local extra = Middleware:TriggerEventWithData("Characters:Creating", source, doc)
    for k, v in ipairs(extra) do
      for k2, v2 in pairs(v) do
        if k2 ~= "ID" then
          doc[k2] = v2
        end
      end
    end

    local dbData = Utils:DeepClone(doc)
    for k, v in pairs(dbData) do
      if type(v) == 'table' then
        dbData[k] = json.encode(v)
      end
    end

    local insertedCharacter = MySQL.insert.await('INSERT INTO `characters` SET ?', { dbData })
    if insertedCharacter <= 0 then
      return cb(nil)
    end

    local myChar = MySQL.single.await('SELECT `_id` FROM `characters` WHERE `SID` = ? AND `User` = ?',
      { insertedCharacter, player:GetData("AccountID") })
    if myChar == nil then
      return cb(nil)
    end
    doc.ID = myChar._id
    TriggerEvent("Characters:Server:CharacterCreated", doc)
    Middleware:TriggerEvent("Characters:Created", source, doc)


    Logger:Info(
      "Characters",
      string.format(
        "%s [%s] Created a New Character %s %s (%s)",
        player:GetData("Name"),
        player:GetData("AccountID"),
        doc.First,
        doc.Last,
        doc.SID
      ),
      {
        console = true,
        file = true,
        database = true,
      })
    return cb(doc)
  end)

  Callbacks:RegisterServerCallback("Characters:DeleteCharacter", function(source, data, cb)
    local player = Fetch:Source(source)

    local myCharacter = MySQL.single.await(
      [[
        SELECT * FROM `characters` WHERE `User` = @User AND `_id` = @ID
      ]],
      {
        ["@User"] = player:GetData("AccountID"),
        ["@ID"] = data,
      }
    )

    if myCharacter == nil then
      return cb(nil)
    end

    local deletingChar = Utils:DeepClone(myCharacter)
    local deletedCharacter = MySQL.update.await(
      [[
        UPDATE `characters` SET `Deleted` = 1 WHERE `User` = @User AND `_id` = @ID
      ]],
      {
        ["@User"] = player:GetData("AccountID"),
        ["@ID"] = data,
      }
    )

    if deletedCharacter then
      TriggerEvent("Characters:Server:CharacterDeleted", data)
      cb(true)

      Logger:Warn(
        "Characters",
        string.format(
          "%s [%s] Deleted Character %s %s (%s)",
          player:GetData("Name"),
          player:GetData("AccountID"),
          deletingChar.First,
          deletingChar.Last,
          deletingChar.SID
        ),
        {
          console = true,
          file = true,
          database = true,
          discord = {
            embed = true,
          },
        }
      )
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Characters:GetSpawnPoints", function(source, data, cb)
    local player = Fetch:Source(source)
    local myCharacter = MySQL.single.await(
      [[
        SELECT * FROM `characters` WHERE `User` = @User AND `_id` = @ID
      ]],
      {
        ["@User"] = player:GetData("AccountID"),
        ["@ID"] = data,
      }
    )
    if myCharacter == nil then
      return cb(nil)
    end
    myCharacter.Jobs = json.decode(myCharacter.Jobs)
    if myCharacter.New then
      return cb({
        {
          id = 1,
          label = "Character Creation",
          location = Apartment:GetInteriorLocation(myCharacter.Apartment or 1),
        },
      })
    elseif myCharacter.Jailed and myCharacter.Jailed.Released ~= nil then
      return cb({ Config.PrisonSpawn })
    elseif myCharacter.ICU and myCharacter.ICU.Released ~= nil then
      return cb({ Config.ICUSpawn })
    end

    local spawns = Middleware:TriggerEventWithData("Characters:GetSpawnPoints", source, data, myCharacter)
    cb(spawns)
  end)

  Callbacks:RegisterServerCallback("Characters:GetCharacterData", function(source, data, cb)
    local player = Fetch:Source(source)
    local myCharacter = MySQL.single.await(
      [[
        SELECT * FROM `characters` WHERE `User` = @User AND `_id` = @ID
      ]],
      {
        ["@User"] = player:GetData("AccountID"),
        ["@ID"] = data,
      }
    )

    if myCharacter == nil then
      return cb(nil)
    end

    local cData = myCharacter

    for k, v in ipairs(_tablesToDecode) do
      if cData[v] then
        cData[v] = json.decode(cData[v])
      end
    end

    cData.Source = source
    cData.ID = myCharacter._id
    cData._id = nil


    local store = DataStore:CreateStore(source, "Character", cData)
    player:SetData("Character", store)
    GlobalState[string.format("SID:%s", source)] = cData.SID
    GlobalState[string.format("Account:%s", source)] = player:GetData("AccountID")

    Middleware:TriggerEvent("Characters:CharacterSelected", source)

    cb(cData)
  end)

  Callbacks:RegisterServerCallback("Characters:Logout", function(source, data, cb)
    local player = Fetch:Source(source)
    Middleware:TriggerEvent("Characters:Logout", source)
    player:SetData("Character", nil)
    GlobalState[string.format("SID:%s", source)] = nil
    GlobalState[string.format("Account:%s", source)] = nil
    cb("ok")
    TriggerClientEvent("Characters:Client:Logout", source)
    Routing:RoutePlayerToHiddenRoute(source)
  end)

  Callbacks:RegisterServerCallback("Characters:GlobalSpawn", function(source, data, cb)
    Routing:RoutePlayerToGlobalRoute(source)
    cb()
  end)
end

function HandleLastLocation(source)
  local player = Fetch:Source(source)
  if player ~= nil then
    local char = player:GetData("Character")
    if char ~= nil then
      local lastLocation = _tempLastLocation[source]
      if lastLocation and type(lastLocation) == "vector3" then
        _lastSpawnLocations[char:GetData("ID")] = {
          coords = lastLocation,
          time = os.time(),
        }
      end
    end
  end

  _tempLastLocation[source] = nil
end

function RegisterMiddleware()
  Middleware:Add("Characters:Spawning", function(source)
    TriggerClientEvent("Characters:Client:Spawned", source)
  end, 100000)
  Middleware:Add("Characters:ForceStore", function(source)
    local player = Fetch:Source(source)
    if player ~= nil then
      local char = player:GetData("Character")
      if char ~= nil then
        StoreData(source)
      end
    end
  end, 100000)
  Middleware:Add("Characters:Logout", function(source)
    local player = Fetch:Source(source)
    if player ~= nil then
      local char = player:GetData("Character")
      if char ~= nil then
        StoreData(source)
      end
    end
  end, 10000)

  Middleware:Add("Characters:GetSpawnPoints", function(source, id)
    if id then
      local hasLastLocation = _lastSpawnLocations[id]
      if hasLastLocation and hasLastLocation.time and (os.time() - hasLastLocation.time) <= (60 * 5) then
        return {
          {
            id = "LastLocation",
            label = "Last Location",
            location = {
              x = hasLastLocation.coords.x,
              y = hasLastLocation.coords.y,
              z = hasLastLocation.coords.z,
              h = 0.0,
            },
            icon = "location-smile",
            event = "Characters:GlobalSpawn",
          },
        }
      end
    end
    return {}
  end, 1)

  Middleware:Add("Characters:GetSpawnPoints", function(source)
    local spawns = {}
    for k, v in ipairs(Spawns) do
      v.event = "Characters:GlobalSpawn"
      table.insert(spawns, v)
    end
    return spawns
  end, 5)

  Middleware:Add("playerDropped", function(source, message)
    local player = Fetch:Source(source)
    if player ~= nil then
      local char = player:GetData("Character")
      if char ~= nil then
        StoreData(source)
      end
    end
  end, 10000)

  Middleware:Add("Characters:Logout", HandleLastLocation, 6)
  Middleware:Add("playerDropped", HandleLastLocation, 6)
end

function IsNumberInUse(number)
  local result = MySQL.single.await([[SELECT `Phone` FROM `characters` WHERE `Phone` = @Phone]], { ["@Phone"] = number })
  if result == nil then
    return false
  end
  return true
end

function GeneratePhoneNumber()
  local phone = ""

  for i = 1, 10, 1 do
    local d = math.random(0, 9)
    phone = phone .. d

    if i == 3 or i == 6 then
      phone = phone .. "-"
    end
  end

  return phone
end

RegisterNetEvent(
  "Characters:Server:LastLocation",
  function(coords) -- Probably Going to make the server explode but ¯\_(ツ)_/¯
    local src = source
    _tempLastLocation[src] = coords
  end
)
