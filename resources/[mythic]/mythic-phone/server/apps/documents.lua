PHONE.Documents = {
  Create = function(self, source, doc)
    local char = Fetch:Source(source):GetData("Character")
    if char ~= nil and type(doc) == "table" then
      local p = promise.new()

      doc.owner = char:GetData("ID")
      doc.time = os.time()

      exports.oxmysql:insert('INSERT INTO character_documents (owner, time, title, content) VALUES (?, ?, ?, ?)',
        { doc.owner, doc.time, doc.title, doc.content },
        function(id)
          if id then
            local fetchDocID = MySQL.single.await("SELECT `_id` FROM character_documents WHERE id = ?", { id })
            doc._id = fetchDocID?._id or nil
            p:resolve(doc)
          else
            p:resolve(false)
          end
        end
      )

      return Citizen.Await(p)
    end
    return false
  end,

  Edit = function(self, source, id, doc)
    local char = Fetch:Source(source):GetData("Character")
    if char ~= nil and type(doc) == "table" then
      local p = promise.new()

      exports.oxmysql:execute(
        'UPDATE character_documents SET title = ?, content = ?, time = ? WHERE _id = ? AND owner = ?',
        { doc.title, doc.content, os.time(), id, char:GetData("ID") },
        function(result)
          if result.affectedRows > 0 then
            exports.oxmysql:execute('SELECT * FROM character_documents WHERE _id = ?', { id }, function(results)
              if #results > 0 then
                local res = results[1]
                p:resolve(true)

                if res.sharedWith then
                  local sharedWith = json.decode(res.sharedWith)
                  for k, v in ipairs(sharedWith) do
                    if v.ID then
                      local char = Fetch:ID(v.ID)
                      if char then
                        TriggerClientEvent("Phone:Client:UpdateData", char:GetData("Source"), "myDocuments", res.id, res)
                      end
                    end
                  end
                end
              else
                p:resolve(false)
              end
            end)
          else
            p:resolve(false)
          end
        end
      )

      return Citizen.Await(p)
    end
    return false
  end,

  Delete = function(self, source, id)
    local char = Fetch:Source(source):GetData("Character")
    if char ~= nil then
      local p = promise.new()

      exports.oxmysql:execute('SELECT * FROM character_documents WHERE id = ?', { id }, function(results)
        if #results > 0 then
          local doc = results[1]
          if doc.owner == char:GetData("ID") then
            exports.oxmysql:execute('DELETE FROM character_documents WHERE id = ?', { id }, function(result)
              p:resolve(result.affectedRows > 0)

              if result.affectedRows > 0 and doc.sharedWith then
                local sharedWith = json.decode(doc.sharedWith)
                for k, v in ipairs(sharedWith) do
                  if v.ID then
                    local char = Fetch:ID(v.ID)
                    if char then
                      TriggerClientEvent("Phone:Client:RemoveData", char:GetData("Source"), "myDocuments", doc.id)
                    end
                  end
                end
              end
            end)
          else
            local sharedWith = json.decode(doc.sharedWith or '[]')
            local updatedSharedWith = {}
            for k, v in ipairs(sharedWith) do
              if v.ID ~= char:GetData("ID") then
                table.insert(updatedSharedWith, v)
              end
            end

            exports.oxmysql:execute('UPDATE character_documents SET sharedWith = ? WHERE id = ?',
              { json.encode(updatedSharedWith), id },
              function(result)
                p:resolve(result.affectedRows > 0)
              end
            )
          end
        else
          p:resolve(false)
        end
      end)

      return Citizen.Await(p)
    end
    return false
  end,
}

AddEventHandler("Phone:Server:RegisterMiddleware", function()
  Middleware:Add("Characters:Spawning", function(source)
    local char = Fetch:Source(source):GetData("Character")
    exports.oxmysql:execute(
      'SELECT * FROM character_documents WHERE owner = ? OR JSON_CONTAINS(sharedWith, JSON_OBJECT("ID", ?))',
      { char:GetData("ID"), char:GetData("ID") },
      function(results)
        for k, v in pairs(results) do
          v.sharedWith = json.decode(v.sharedWith) or {}
          v.sharedBy = json.decode(v.sharedBy) or {}
          v.signed = json.decode(v.signed) or {}
        end
        TriggerClientEvent("Phone:Client:SetData", source, "myDocuments", results)
      end
    )
  end, 2)

  Middleware:Add("Phone:UIReset", function(source)
    local char = Fetch:Source(source):GetData("Character")
    exports.oxmysql:execute(
      'SELECT * FROM character_documents WHERE owner = ? OR JSON_CONTAINS(sharedWith, JSON_OBJECT("ID", ?))',
      { char:GetData("ID"), char:GetData("ID") },
      function(results)
        TriggerClientEvent("Phone:Client:SetData", source, "myDocuments", results)
      end
    )
  end, 2)
end)

AddEventHandler("Phone:Server:RegisterCallbacks", function()
  Callbacks:RegisterServerCallback("Phone:Documents:Create", function(source, data, cb)
    cb(Phone.Documents:Create(source, data))
  end)

  Callbacks:RegisterServerCallback("Phone:Documents:Edit", function(source, data, cb)
    cb(Phone.Documents:Edit(source, data.id, data.data))
  end)

  Callbacks:RegisterServerCallback("Phone:Documents:Delete", function(source, data, cb)
    cb(Phone.Documents:Delete(source, data))
  end)

  Callbacks:RegisterServerCallback("Phone:Documents:Refresh", function(source, data, cb)
    local char = Fetch:Source(source):GetData("Character")
    exports.oxmysql:execute(
      'SELECT * FROM character_documents WHERE owner = ? OR JSON_CONTAINS(sharedWith, JSON_OBJECT("ID", ?))',
      { char:GetData("ID"), char:GetData("ID") },
      function(results)
        cb("myDocuments", results)
      end
    )
  end)

  Callbacks:RegisterServerCallback("Phone:Documents:Share", function(source, data, cb)
    -- The sharing logic remains largely the same, just update the database operations
    -- ... (previous share logic)

    if sharedData then
      if target then
        TriggerClientEvent("Phone:Client:ReceiveShare", target:GetData("Source"), {
          type = "documents",
          data = sharedData,
        }, os.time() * 1000)

        return cb(true)
      else
        -- ... (nearby share logic)
      end
    end

    cb(false)
  end)

  Callbacks:RegisterServerCallback("Phone:Documents:RecieveShare", function(source, data, cb)
    if data then
      if data.isCopy then
        cb(Phone.Documents:Create(source, data.document))
      else
        local char = Fetch:Source(source):GetData("Character")
        if char then
          exports.oxmysql:execute(
            'UPDATE character_documents SET sharedWith = JSON_ARRAY_APPEND(IFNULL(sharedWith, "[]"), "$", ?), sharedBy = ? WHERE _id = ? AND owner != ? AND NOT JSON_CONTAINS(IFNULL(sharedWith, "[]"), JSON_OBJECT("ID", ?))',
            { json.encode({
              Time = os.time(),
              ID = char:GetData("ID"),
              First = char:GetData("First"),
              Last = char:GetData("Last"),
              SID = char:GetData("SID"),
              RequireSignature = data.requireSignature,
            }), json.encode(data.document.sharedBy), data.document._id, char:GetData("ID"), char:GetData("ID") },
            function(result)
              if result.affectedRows > 0 then
                exports.oxmysql:execute('SELECT * FROM character_documents WHERE _id = ?', { data.document._id },
                  function(results)
                    if #results > 0 then
                      cb(results[1])
                    else
                      cb(false)
                    end
                  end)
              else
                cb(false)
              end
            end
          )
        else
          cb(false)
        end
      end
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Phone:Documents:Sign", function(source, data, cb)
    local char = Fetch:Source(source):GetData("Character")
    if char then
      exports.oxmysql:execute(
        'UPDATE character_documents SET signed = JSON_ARRAY_APPEND(IFNULL(signed, "[]"), "$", ?) WHERE _id = ? AND owner != ? AND NOT JSON_CONTAINS(IFNULL(signed, "[]"), JSON_OBJECT("ID", ?))',
        { json.encode({
          Time = os.time(),
          ID = char:GetData("ID"),
          First = char:GetData("First"),
          Last = char:GetData("Last"),
          SID = char:GetData("SID"),
        }), data, char:GetData("ID"), char:GetData("ID") },
        function(result)
          cb(result.affectedRows > 0)

          if result.affectedRows > 0 then
            exports.oxmysql:execute('SELECT * FROM character_documents WHERE id = ?', { data }, function(results)
              if #results > 0 then
                local res = results[1]
                if res.sharedWith then
                  local sharedWith = json.decode(res.sharedWith)
                  for k, v in ipairs(sharedWith) do
                    if v.ID then
                      local char = Fetch:ID(v.ID)
                      if char then
                        TriggerClientEvent("Phone:Client:UpdateData", char:GetData("Source"), "myDocuments", res.id, res)
                      end
                    end
                  end

                  local char = Fetch:ID(res.owner)
                  if char then
                    TriggerClientEvent("Phone:Client:UpdateData", char:GetData("Source"), "myDocuments", res.id, res)
                  end
                end
              end
            end)
          end
        end
      )
    else
      cb(false)
    end
  end)
end)
