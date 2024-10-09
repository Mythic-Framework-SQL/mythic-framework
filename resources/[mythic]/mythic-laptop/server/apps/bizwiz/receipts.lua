LAPTOP.BizWiz = LAPTOP.BizWiz or {}
LAPTOP.BizWiz.Receipts = {
  Search = function(self, jobId, term)
    if not term then term = '' end
    local p = promise.new()

    local query = [[
      SELECT * FROM business_receipts
      WHERE job = ? AND (
        customerName LIKE ? OR
        JSON_EXTRACT(author, '$.First') LIKE ? OR
        JSON_EXTRACT(author, '$.Last') LIKE ? OR
        JSON_EXTRACT(author, '$.SID') LIKE ?
      )
    ]]
    local params = { jobId, '%' .. term .. '%', '%' .. term .. '%', '%' .. term .. '%', '%' .. term .. '%' }

    exports.oxmysql:query(query, params, function(results)
      if results then
        p:resolve(results)
      else
        p:resolve(false)
      end
    end)

    return Citizen.Await(p)
  end,

  View = function(self, jobId, id)
    local p = promise.new()

    local query = "SELECT * FROM business_receipts WHERE job = ? AND id = ? LIMIT 1"
    local params = { jobId, id }

    exports.oxmysql:query(query, params, function(results)
      if results and #results > 0 then
        p:resolve(results[1])
      else
        p:resolve(false)
      end
    end)

    return Citizen.Await(p)
  end,

  Create = function(self, jobId, data)
    if not _bizWizConfig[jobId] then
      return false
    end

    local p = promise.new()
    data.job = jobId

    local query = [[
      INSERT INTO business_receipts
      (job, customerName, author, content)
      VALUES (?, ?, ?, ?)
    ]]
    local params = {
      data.job,
      data.customerName,
      json.encode(data.author),
      json.encode(data.content)
    }

    exports.oxmysql:insert(query, params, function(insertId)
      if insertId then
        p:resolve({ _id = insertId })
      else
        p:resolve(false)
      end
    end)

    return Citizen.Await(p)
  end,

  Update = function(self, jobId, id, char, report)
    local p = promise.new()

    local lastUpdated = json.encode({
      Time = (os.time() * 1000),
      SID = char:GetData("SID"),
      First = char:GetData("First"),
      Last = char:GetData("Last"),
    })

    local query = [[
      UPDATE business_receipts
      SET customerName = ?, content = ?,
          lastUpdated = ?,
          history = JSON_ARRAY_APPEND(
            IFNULL(history, JSON_ARRAY()),
            '$',
            JSON_OBJECT(
              'Time', ?,
              'Char', ?,
              'Log', ?
            )
          )
      WHERE _id = ? AND job = ?
    ]]
    local params = {
      report.customerName,
      json.encode(report.content),
      lastUpdated,
      os.time() * 1000,
      char:GetData("SID"),
      string.format("%s Updated Report", char:GetData("First") .. " " .. char:GetData("Last")),
      id,
      jobId
    }

    exports.oxmysql:execute(query, params, function(affectedRows)
      p:resolve(affectedRows > 0)
    end)

    return Citizen.Await(p)
  end,

  Delete = function(self, jobId, id)
    local p = promise.new()

    local query = "DELETE FROM business_receipts WHERE _id = ? AND job = ?"
    local params = { id, jobId }

    exports.oxmysql:execute(query, params, function(affectedRows)
      p:resolve(affectedRows > 0)
    end)

    return Citizen.Await(p)
  end,

  DeleteAll = function(self, jobId)
    if not jobId then return false; end

    local p = promise.new()

    local query = "DELETE FROM business_receipts WHERE job = ?"
    local params = { jobId }

    exports.oxmysql:execute(query, params, function(affectedRows)
      p:resolve(affectedRows > 0)
    end)

    return Citizen.Await(p)
  end,
}


AddEventHandler("Laptop:Server:RegisterCallbacks", function()
  Callbacks:RegisterServerCallback("Laptop:BizWiz:Receipt:Search", function(source, data, cb)
    local job = CheckBusinessPermissions(source)
    if job then
      cb(Laptop.BizWiz.Receipts:Search(job, data.term))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Receipt:Create", function(source, data, cb)
    local char = Fetch:Source(source):GetData("Character")
    local job = CheckBusinessPermissions(source, 'TABLET_CREATE_RECEIPT')
    if job then
      data.doc.author = {
        SID = char:GetData("SID"),
        First = char:GetData("First"),
        Last = char:GetData("Last"),
      }
      cb(Laptop.BizWiz.Receipts:Create(job, data.doc))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Receipt:Update", function(source, data, cb)
    local char = Fetch:Source(source):GetData("Character")
    local job = CheckBusinessPermissions(source, 'TABLET_MANAGE_RECEIPT')
    if char and job then
      data.Report.lastUpdated = {
        Time = (os.time() * 1000),
        SID = char:GetData("SID"),
        First = char:GetData("First"),
        Last = char:GetData("Last"),
      }
      cb(Laptop.BizWiz.Receipts:Update(job, data.id, char, data.Report))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Receipt:Delete", function(source, data, cb)
    local job = CheckBusinessPermissions(source, 'TABLET_MANAGE_RECEIPT')
    if job then
      cb(Laptop.BizWiz.Receipts:Delete(job, data.id))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Receipt:DeleteAll", function(source, data, cb)
    local job = CheckBusinessPermissions(source, 'TABLET_CLEAR_RECEIPT')
    if job then
      cb(Laptop.BizWiz.Receipts:DeleteAll(job))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Receipt:View", function(source, data, cb)
    local job = CheckBusinessPermissions(source)
    if job then
      cb(Laptop.BizWiz.Receipts:View(job, data))
    else
      cb(false)
    end
  end)
end)
