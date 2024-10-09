local _selling = {}
local _pendingLoanAccept = {}

local govCut = 5
local commissionCut = 5
local companyCut = 10

AddEventHandler("Phone:Server:RegisterCallbacks", function()
  Callbacks:RegisterServerCallback("Phone:Dyn8:Search", function(source, data, cb)
    local char = Fetch:Source(source):GetData("Character")
    if char then
      local qry = {
        label = {
          ["$regex"] = data,
          ["$options"] = "i",
        },
        sold = false,
      }

      if Player(source).state.onDuty == 'realestate' then
        qry = {
          label = {
            ["$regex"] = data,
            ["$options"] = "i",
          },
        }
      end

      local query = [[
        SELECT *
        FROM properties
        WHERE label LIKE ?
        LIMIT 80
      ]]

      local term = '%' .. (data or '') .. '%'
      local params = { term }

      MySQL.Async.fetchAll(query, params, function(results)
        if not results then
          cb(false)
          return
        end
        cb(results)
      end)
    else
      cb(false)
    end
  end)
end)
