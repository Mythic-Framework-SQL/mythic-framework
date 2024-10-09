PHONE.Email = {
  Read = function(self, charId, id)
    local p = promise.new()
    exports.oxmysql:execute(
      "UPDATE character_emails SET unread = 0 WHERE owner = ? AND _id = ?",
      { charId, id },
      function(affectedRows)
        p:resolve(#affectedRows > 0)
      end
    )
    return Citizen.Await(p)
  end,

  Send = function(self, serverId, sender, time, subject, body, flags)
    local plyr = Fetch:Source(serverId)
    if plyr ~= nil then
      local char = plyr:GetData("Character")
      if char ~= nil then
        local doc = {
          owner = char:GetData("ID"),
          sender = sender,
          time = time,
          subject = subject,
          body = body,
          unread = true,
          flags = flags or {},
        }
        exports.oxmysql:insert(
          "INSERT INTO character_emails (owner, sender, time, subject, body, unread, flags) VALUES (?, ?, ?, ?, ?, ?, ?)",
          { doc.owner, doc.sender, doc.time, doc.subject, doc.body, doc.unread, json.encode(doc.flags) },
          function(insertId)
            if insertId then
              doc._id = insertId
              TriggerClientEvent("Phone:Client:Email:Receive", serverId, doc)
            end
          end
        )
      end
    end
  end,

  Delete = function(self, charId, id)
    exports.oxmysql:execute(
      "DELETE FROM character_emails WHERE owner = ? AND _id = ?",
      { charId, id },
      function(affectedRows)
        if #affectedRows > 0 then
          local char = Fetch:ID(charId)
          if char then
            TriggerClientEvent("Phone:Client:Email:Delete", char:GetData("Source"), id)
          end
        end
      end
    )
  end,
}

AddEventHandler("Phone:Server:RegisterMiddleware", function()
  Middleware:Add("Characters:Spawning", function(source)
    local char = Fetch:Source(source):GetData("Character")
    exports.oxmysql:query(
      "SELECT * FROM character_emails WHERE owner = ?",
      { char:GetData("ID") },
      function(results)
        for k, v in ipairs(results) do
          v.flags = json.decode(v.flags)
        end
        TriggerClientEvent("Phone:Client:SetData", source, "emails", results)
      end
    )
  end, 2)

  Middleware:Add("Phone:UIReset", function(source)
    local char = Fetch:Source(source):GetData("Character")
    exports.oxmysql:query(
      "SELECT * FROM character_emails WHERE owner = ?",
      { char:GetData("ID") },
      function(results)
        for k, v in ipairs(results) do
          v.flags = json.decode(v.flags)
        end
        TriggerClientEvent("Phone:Client:SetData", source, "emails", results)
      end
    )
  end, 2)

  Middleware:Add("Phone:CharacterCreated", function(source, cData)
    return {
      {
        app = "email",
        alias = string.format("%s_%s%s@plugged.net", cData.First, cData.Last, cData.SID),
      },
    }
  end)
end)

AddEventHandler("Phone:Server:RegisterCallbacks", function()
  Chat:RegisterAdminCommand("email", function(source, args, rawCommand)
    local plyr = Fetch:CharacterData("SID", tonumber(args[1]))
    if plyr ~= nil then
      Phone.Email:Send(plyr:GetData("Source"), args[2], os.time() * 1000, args[3], args[4])
    else
      Chat.Send.System:Single(source, "Invalid State ID")
    end
  end, {
    help = "Send Email To Player",
    params = {
      { name = "Target",       help = "State ID" },
      { name = "Sender Email", help = "Email To Show As Sender, EX: scaryman@something.net" },
      { name = "Subject",      help = "Subject Line Of Email" },
      { name = "Body",         help = "Body of email to send" },
    },
  }, 4)

  Callbacks:RegisterServerCallback("Phone:Email:Read", function(source, data, cb)
    local src = source
    local char = Fetch:Source(src):GetData("Character")
    cb(Phone.Email:Read(char:GetData("Phone"), data))
  end)

  Callbacks:RegisterServerCallback("Phone:Email:Delete", function(source, data, cb)
    local src = source
    local char = Fetch:Source(src):GetData("Character")
    cb(Phone.Email:Delete(char:GetData("ID"), data))
  end)

  Callbacks:RegisterServerCallback("Phone:Email:DeleteExpired", function(source, data, cb)
    local src = source
    local plyr = Fetch:Source(src)
    if plyr ~= nil then
      local char = plyr:GetData("Character")
      if char ~= nil then
        exports.oxmysql:query(
          "SELECT _id FROM character_emails WHERE owner = ? AND JSON_EXTRACT(flags, '$.expires') < ?",
          { char:GetData("ID"), os.time() * 1000 },
          function(results)
            exports.oxmysql:execute(
              "DELETE FROM character_emails WHERE owner = ? AND JSON_EXTRACT(flags, '$.expires') < ?",
              { char:GetData("ID"), os.time() * 1000 },
              function(affectedRows)
                local ids = {}
                for _, v in ipairs(results) do
                  table.insert(ids, v._id)
                end
                cb(ids)
              end
            )
          end
        )
      end
    end
  end)
end)
