_warrants = {}
_charges = {}
_notices = {}

local _ran = false

function Startup()
  if _ran then
    return
  end
  RegisterTasks()

  -- Set Expired Active Warrants to Expired
  MySQL.query.await("UPDATE mdt_warrants SET state = ? WHERE state = ? AND expires < NOW()", {
    "expired",
    "active",
  })

  _charges = MySQL.query.await("SELECT * from mdt_charges")
  Logger:Trace("MDT", "Loaded ^2" .. #_charges .. "^7 Charges", { console = true })

  local fetchVehicles = MySQL.query.await("SELECT * from vehicles", {})

  for k, v in ipairs(fetchVehicles) do
    if v.RegisteredPlate and v.Type == 0 then
      Radar:AddFlaggedPlate(v.RegisteredPlate, "Vehicle Flagged in MDT")
    end
  end

  _ran = true

  -- SetHttpHandler(function(req, res)
  -- 	if req.path == '/charges' then
  -- 		res.send(json.encode(_charges))
  -- 	end
  -- end)

  local thirtyDaysAgo = (os.time() * 1000) - (60 * 60 * 24 * 30 * 1000)
  -- Select vehicles that match the query
  local selectQuery = [[
    SELECT _id, Strikes
    FROM vehicles
    WHERE NOT EXISTS (
      SELECT 1
      FROM JSON_TABLE(Strikes, '$[*]' COLUMNS (
        Date BIGINT PATH '$.Date'
      )) AS jt
      WHERE jt.Date >= ?
    )
    AND EXISTS (
      SELECT 1
      FROM JSON_TABLE(Strikes, '$[*]' COLUMNS (
        Date BIGINT PATH '$.Date'
      )) AS jt
      WHERE jt.Date <= ?
    )
  ]]
  local selectParams = { thirtyDaysAgo, thirtyDaysAgo }

  MySQL.Async.fetchAll(selectQuery, selectParams, function(results)
    for _, vehicle in ipairs(results) do
      local strikes = json.decode(vehicle.Strikes)
      local updatedStrikes = {}

      for _, strike in ipairs(strikes) do
        if strike.Date < thirtyDaysAgo then
          table.insert(updatedStrikes, strike)
        end
      end

      local updateQuery = [[
        UPDATE vehicles
        SET Strikes = ?
        WHERE id = ?
      ]]
      local updateParams = { json.encode(updatedStrikes), vehicle._id }

      MySQL.Async.execute(updateQuery, updateParams, function(affectedRows)
        -- Handle the result if needed
      end)
    end
  end)
end
