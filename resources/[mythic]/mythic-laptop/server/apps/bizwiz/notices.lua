AddEventHandler("Laptop:Server:RegisterCallbacks", function()
  local fetchBusinessNotices = MySQL.query.await("SELECT * FROM business_notices")

  Logger:Trace("Laptop", "[BizWiz] Loaded ^2" .. #fetchBusinessNotices .. "^7 Business Notices", { console = true })
  if #fetchBusinessNotices > 0 then
    for k, v in ipairs(fetchBusinessNotices) do
      v.author = json.decode(v.author)
    end
  end
  _businessNotices = fetchBusinessNotices

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Notice:Create", function(source, data, cb)
    local job = CheckBusinessPermissions(source, "TABLET_CREATE_NOTICE")
    if job then
      cb(Laptop.BizWiz.Notices:Create(source, job, data.doc))
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("Laptop:BizWiz:Notice:Delete", function(source, data, cb)
    local job = CheckBusinessPermissions(source, "TABLET_DELETE_NOTICE")
    if job then
      cb(Laptop.BizWiz.Notices:Delete(job, data.id))
    else
      cb(false)
    end
  end)
end)

LAPTOP.BizWiz = LAPTOP.BizWiz or {}
LAPTOP.BizWiz.Notices = {
  Create = function(self, source, job, data)
    local char = Fetch:Source(source):GetData("Character")
    if char then
      local insertNotice = MySQL.insert.await(
        "INSERT INTO business_notices (job, author, title, description, date) VALUES (@job, @author, @title, @description, @date)",
        {
          ["@job"] = job,
          ["@author"] = json.encode({
            SID = char:GetData("SID"),
            First = char:GetData("First"),
            Last = char:GetData("Last"),
          }),
          ["@title"] = data.title,
          ["@description"] = data.description,
          ["@date"] = os.time() * 1000,
        })

      if not insertNotice then
        return false
      end

      local notice = {
        id = insertNotice,
        job = job,
        author = {
          SID = char:GetData("SID"),
          First = char:GetData("First"),
          Last = char:GetData("Last"),
        },
        title = data.title,
        description = data.description,
        date = os.time() * 1000,
      }
      table.insert(_businessNotices, notice)

      local jobDutyData = Jobs.Duty:GetDutyData(job)
      if jobDutyData and jobDutyData.DutyPlayers then
        for k, v in ipairs(jobDutyData.DutyPlayers) do
          TriggerClientEvent("Laptop:Client:AddData", v, "businessNotices", notice)
        end
      end
      return true
    end
    return false
  end,
  Delete = function(self, job, id)
    local deleted = MySQL.query.await("DELETE FROM business_notices WHERE id = @id AND job = @job", {
      ["@id"] = id,
      ["@job"] = job,
    })

    if not deleted then
      return false
    end

    for k, v in ipairs(_businessNotices) do
      if v.id == id then
        table.remove(_businessNotices, k)
        break
      end
    end

    local jobDutyData = Jobs.Duty:GetDutyData(job)
    if jobDutyData and jobDutyData.DutyPlayers then
      for k, v in ipairs(jobDutyData.DutyPlayers) do
        TriggerClientEvent("Laptop:Client:RemoveData", v, "businessNotices", id)
      end
    end
    return true
  end,
}
