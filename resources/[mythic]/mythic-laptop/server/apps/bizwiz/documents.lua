LAPTOP.BizWiz = LAPTOP.BizWiz or {}

LAPTOP.BizWiz.Documents = {
  Search = function(self, jobId, term)
    if not term then term = '' end

    local findDocuments = MySQL.query.await([[
      SELECT * FROM `business_documents` WHERE `job` = @job AND (`title` LIKE @term OR `author` LIKE @term)
    ]], {
      ['@job'] = jobId,
      ['@term'] = '%' .. term .. '%',
    })

    if #findDocuments == 0 or findDocuments == nil then
      return {}
    end

    for k, v in pairs(findDocuments) do
      findDocuments[k].author = json.decode(v.author)
      findDocuments[k].Report = json.decode(v.Report)
      findDocuments[k].history = json.decode(v.history)
    end

    return findDocuments
  end,
  View = function(self, jobId, id)
    local fetchDocument = MySQL.single.await([[
      SELECT * FROM business_documents WHERE job = @job AND _id = @id
    ]], {
      ['@job'] = jobId,
      ['@id'] = id,
    })
    print(fetchDocument)
    if not fetchDocument then
      print("Returning")
      return false
    end
    print("Here");
    fetchDocument.author = json.decode(fetchDocument.author)
    fetchDocument.Report = json.decode(fetchDocument.Report)
    fetchDocument.history = json.decode(fetchDocument.history)
    return fetchDocument
  end,
  Create = function(self, jobId, data)
    local insert = MySQL.insert.await(
      'INSERT INTO business_documents (job, title, notes, Report, author, history, pinned) VALUES (@job, @title, @Notes, @Report, @author, @history, @pinned)',
      {
        ['@job'] = jobId,
        ['@title'] = data.title,
        ['@Notes'] = data.notes,
        ['@Report'] = json.encode(data.Report or {}),
        ['@author'] = json.encode({
          SID = data.author.SID,
          First = data.author.First,
          Last = data.author.Last,
        }),
        ['@history'] = json.encode({
          {
            Time = (os.time() * 1000),
            Char = data.author.SID,
            Log = string.format(
              "%s Created Report",
              data.author.First .. " " .. data.author.Last
            ),
          },
        }),
        ['@pinned'] = data.pinned or false,
      })

    if not insert then
      return false
    end

    return {
      _id = insert,
    }
  end,
  Update = function(self, jobId, id, char, report)
    local p = promise.new()
    local timeStamp = os.time() * 1000
    local charSID = char:GetData("SID")
    local charName = string.format("%s %s", char:GetData("First"), char:GetData("Last"))
    local logMessage = string.format("%s Updated Report", charName)

    -- Update the report in the business_documents table
    local updateQuery = [[
      UPDATE business_documents
      SET report = ?
      WHERE _id = ? AND job = ?
    ]]

    local updateParams = { json.encode(report), id, jobId }

    MySQL.Async.execute(updateQuery, updateParams, function(affectedRows)
      if affectedRows > 0 then
        -- Insert a new history entry
        local insertHistoryQuery = [[
          INSERT INTO history (document_id, Time, Char, Log)
          VALUES (?, ?, ?, ?)
        ]]

        local insertHistoryParams = { id, timeStamp, charSID, logMessage }

        MySQL.Async.execute(insertHistoryQuery, insertHistoryParams, function(historyAffectedRows)
          if historyAffectedRows > 0 then
            p:resolve(true)
          else
            p:resolve(false)
          end
        end)
      else
        p:resolve(false)
      end
    end)

    return Citizen.Await(p)
  end,
  Delete = function(self, jobId, id)
    local p = promise.new()

    local deleteQuery = [[
      DELETE FROM business_documents
      WHERE _id = ? AND job = ?
    ]]

    local deleteParams = { id, jobId }

    MySQL.Async.execute(deleteQuery, deleteParams, function(affectedRows)
      local success = affectedRows > 0
      p:resolve(success)
    end)

    return Citizen.Await(p)
  end,
}



AddEventHandler("Laptop:Server:RegisterCallbacks", function()
  Callbacks:RegisterServerCallback("Laptop:BizWiz:Document:Search", function(source, data, cb)
    local job = CheckBusinessPermissions(source, 'TABLET_VIEW_DOCUMENT')
    if job then
      cb(Laptop.BizWiz.Documents:Search(job, data.term))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Document:Create", function(source, data, cb)
    local char = Fetch:Source(source):GetData("Character")
    local job = CheckBusinessPermissions(source, 'TABLET_CREATE_DOCUMENT')
    if job then
      data.doc.author = {
        SID = char:GetData("SID"),
        First = char:GetData("First"),
        Last = char:GetData("Last"),
      }
      cb(Laptop.BizWiz.Documents:Create(job, data.doc))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Document:Update", function(source, data, cb)
    local char = Fetch:Source(source):GetData("Character")
    local job = CheckBusinessPermissions(source, 'TABLET_CREATE_DOCUMENT')
    if char and job then
      data.Report.lastUpdated = {
        Time = (os.time() * 1000),
        SID = char:GetData("SID"),
        First = char:GetData("First"),
        Last = char:GetData("Last"),
      }
      cb(Laptop.BizWiz.Documents:Update(job, data.id, char, data.Report))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Document:Delete", function(source, data, cb)
    local job = CheckBusinessPermissions(source, 'TABLET_DELETE_DOCUMENT')
    if job then
      cb(Laptop.BizWiz.Documents:Delete(job, data.id))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Document:View", function(source, data, cb)
    local job = CheckBusinessPermissions(source, 'TABLET_VIEW_DOCUMENT')
    if job then
      cb(Laptop.BizWiz.Documents:View(job, data))
    else
      cb(false)
    end
  end)
end)
