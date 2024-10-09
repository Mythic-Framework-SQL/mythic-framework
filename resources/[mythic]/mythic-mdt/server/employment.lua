AddEventHandler("MDT:Server:RegisterCallbacks", function()
  Callbacks:RegisterServerCallback("MDT:Hire", function(source, data, cb)
    local player = Fetch:Source(source)
    local char = player:GetData("Character")

    local isSystemAdmin = char:GetData('MDTSystemAdmin')
    local hasPerms, loggedInJob = CheckMDTPermissions(source, {
      'MDT_HIRE',
      'PD_HIGH_COMMAND',
      'DOC_HIGH_COMMAND',
    }, data.JobId)

    if char and data.SID and data.WorkplaceId and data.GradeId and (hasPerms or isSystemAdmin) then
      local added = Jobs:GiveJob(data.SID, data.JobId, data.WorkplaceId, data.GradeId, true)
      cb(added)

      if added then
        local MDTHistory = MySQL.single.await(
          'SELECT MDTHistory FROM characters WHERE SID = @SID', {
            ['@SID'] = data.SID
          })

        if not MDTHistory then
          cb(false)
          return
        end

        local MDTHistory = json.decode(MDTHistory.MDTHistory)

        table.insert(MDTHistory, {
          Time = (os.time() * 1000),
          Char = char:GetData("SID"),
          Log = string.format(
            "%s Hired Them To %s",
            char:GetData("First") .. " " .. char:GetData("Last"),
            json.encode(data)
          ),
        })

        MySQL.update.await('UPDATE `characters` SET MDTHistory = @MDTHistory WHERE SID = @SID', {
          ['@MDTHistory'] = json.encode(MDTHistory),
          ['@SID'] = data.SID
        })

        local target = Fetch:SID(data.SID)
        if target then
          target:GetData("Character"):SetData("Callsign", false)
        end
      end
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:Fire", function(source, data, cb)
    local char = Fetch:Source(source):GetData("Character")

    local isSystemAdmin = char:GetData('MDTSystemAdmin')
    local hasPerms, loggedInJob = CheckMDTPermissions(source, {
      'MDT_FIRE',
      'PD_HIGH_COMMAND',
      'DOC_HIGH_COMMAND',
    }, data.JobId)

    if char and data and data.SID and (hasPerms or isSystemAdmin) then
      local charData = MDT.People:View(data.SID)
      if charData then
        local canRemove = false
        if isSystemAdmin then
          canRemove = true
        else
          local plyrJob = Jobs.Permissions:HasJob(source, loggedInJob)
          for k, v in ipairs(charData.Jobs) do
            if v.Id == data.JobId then
              if plyrJob.Grade.Level > v.Grade.Level then
                canRemove = true
              end
              break
            end
          end
        end

        if canRemove then
          local removed = Jobs:RemoveJob(data.SID, data.JobId)
          cb(removed)

          if removed then
            local MDTHistory = MySQL.single.await(
              'SELECT MDTHistory FROM characters WHERE SID = @SID', {
                ['@SID'] = data.SID
              })

            if not MDTHistory then
              cb(false)
              return
            end

            local MDTHistory = json.decode(MDTHistory.MDTHistory)

            table.insert(MDTHistory, {
              Time = (os.time() * 1000),
              Char = char:GetData("SID"),
              Log = string.format(
                "%s Fired Them From Job %s",
                char:GetData("First") .. " " .. char:GetData("Last"),
                data.JobId
              ),
            })

            MySQL.update.await(
              'UPDATE `characters` SET `MDTHistory` = @MDTHistory, `Callsign` = @Callsign WHERE `SID` = @SID', {
                ['@MDTHistory'] = json.encode(MDTHistory),
                ['@Callsign'] = nil,
                ['@SID'] = data.SID
              })

            local target = Fetch:SID(data.SID)
            if target then
              target:GetData("Character"):SetData("Callsign", false)
            end
            return cb(true)
          end
        else
          return cb(false)
        end
      end
    else
      return cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:ManageEmployment", function(source, data, cb)
    local player = Fetch:Source(source)
    local char = player:GetData("Character")

    local isSystemAdmin = char:GetData('MDTSystemAdmin')
    local hasPerms, loggedInJob = CheckMDTPermissions(source, {
      'MDT_FIRE',
      'PD_HIGH_COMMAND',
      'DOC_HIGH_COMMAND',
    }, data.JobId)

    local newJobData = Jobs:DoesExist(data.data.Id, data.data.Workplace.Id, data.data.Grade.Id)

    if char and data and data.SID and (hasPerms or isSystemAdmin) and newJobData then
      local charData = MDT.People:View(data.SID)
      if charData then
        local canDoItBitch = false
        if isSystemAdmin then
          canDoItBitch = true
        else
          local plyrJob = Jobs.Permissions:HasJob(source, loggedInJob)
          for k, v in ipairs(charData.Jobs) do
            if v.Id == data.JobId then
              if plyrJob.Grade.Level > v.Grade.Level and plyrJob.Grade.Level > newJobData.Grade.Level then
                canDoItBitch = true
              end
              break
            end
          end
        end

        if canDoItBitch then
          local updated = Jobs:GiveJob(data.SID, newJobData.Id, newJobData.Workplace.Id, newJobData.Grade.Id)

          cb(updated)

          if updated then
            local MDTHistory = MySQL.single.await(
              'SELECT MDTHistory FROM characters WHERE SID = @SID', {
                ['@SID'] = data.SID
              })

            if not MDTHistory then
              cb(false)
              return
            end

            local MDTHistory = json.decode(MDTHistory.MDTHistory)

            table.insert(MDTHistory, {
              Time = (os.time() * 1000),
              Char = char:GetData("SID"),
              Log = string.format(
                "%s Promoted Them To %s",
                char:GetData("First") .. " " .. char:GetData("Last"),
                json.encode(newJobData)
              ),
            })

            MySQL.update.await(
              'UPDATE `characters` SET `MDTHistory` = @MDTHistor WHERE `SID` = @SID', {
                ['@MDTHistory'] = json.encode(MDTHistory),
                ['@SID'] = data.SID
              })
            return cb(true)
          end
        else
          return cb(false)
        end
      end
    else
      return cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:Update:jobPermissions", function(source, data, cb)
    local player = Fetch:Source(source)
    local char = player:GetData("Character")
    local isSystemAdmin = char:GetData('MDTSystemAdmin')
    local hasPerms, loggedInJob = CheckMDTPermissions(source, {
      'PD_HIGH_COMMAND',
      'SAFD_HIGH_COMMAND',
      'DOC_HIGH_COMMAND',
    }, data.JobId)

    local targetData = Jobs:DoesExist(data.JobId, data.WorkplaceId, data.GradeId)

    if char and data and data.UpdatedPermissions and (hasPerms or isSystemAdmin) and targetData then
      local plyrJob = Jobs.Permissions:HasJob(source, loggedInJob)
      if isSystemAdmin or (plyrJob and plyrJob.Grade.Level > targetData.Grade.Level) then
        cb(
          Jobs.Management.Grades:Edit(data.JobId, data.WorkplaceId, data.GradeId, {
            Permissions = data.UpdatedPermissions,
          })
        )
      else
        cb(false)
      end
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:Suspend", function(source, data, cb)
    local player = Fetch:Source(source)
    local char = player:GetData("Character")

    local isSystemAdmin = char:GetData('MDTSystemAdmin')
    local hasPerms, loggedInJob = CheckMDTPermissions(source, {
      'MDT_FIRE',
      'PD_HIGH_COMMAND',
      'DOC_HIGH_COMMAND',
    }, data.JobId)

    if char and data and data.SID and (hasPerms or isSystemAdmin) then
      local charData = MDT.People:View(data.SID)
      if charData then
        local canRemove = false
        if isSystemAdmin then
          canRemove = true
        else
          local plyrJob = Jobs.Permissions:HasJob(source, loggedInJob)
          for k, v in ipairs(charData.Jobs) do
            if v.Id == data.JobId then
              if plyrJob.Grade.Level > v.Grade.Level then
                canRemove = true
              end
              break
            end
          end
        end

        if canRemove and data.Length and type(data.Length) == "number" and data.Length > 0 and data.Length < 99 then
          local suspendData = {
            Actioned = {
              First = char:GetData("First"),
              Last = char:GetData("Last"),
              SID = char:GetData("SID"),
              Callsign = char:GetData("Callsign")
            },
            Length = data.Length,
            Expires = os.time() + (60 * 60 * 24 * data.Length),
          }

          -- Update MDTHistory and MDTSuspension in the characters table
          local updateQuery = [[
            UPDATE characters
            SET
              MDTHistory = JSON_ARRAY_APPEND(MDTHistory, '$', JSON_OBJECT(
                'Time', ?,
                'Char', ?,
                'Log', ?
              )),
              MDTSuspension = JSON_SET(MDTSuspension, ?, ?)
            WHERE SID = ?
          ]]
          local time = os.time() * 1000
          local charSID = char:GetData("SID")
          local log = string.format(
            "%s Suspended Them From Job %s for %s Days",
            char:GetData("First") .. " " .. char:GetData("Last"),
            data.JobId,
            data.Length
          )
          local suspensionPath = string.format("$.%s", data.JobId)
          local params = { time, charSID, log, suspensionPath, json.encode(suspendData), data.SID }

          local updateUserDB = MySQL.update.await(updateQuery, params)
          if updateUserDB then
            local char = Fetch:SID(data.SID)
            if char then
              local suspensionShit = char:GetData("Character"):GetData("MDTSuspension") or {}

              suspensionShit[data.JobId] = suspendData
              char:GetData("Character"):SetData("MDTSuspension", suspensionShit)

              Jobs.Duty:Off(char:GetData("Source"), data.JobId)
            end
          end
        else
          cb(false)
        end
      end
    else
      cb(false)
    end
  end)

  Callbacks:RegisterServerCallback("MDT:Unsuspend", function(source, data, cb)
    local player = Fetch:Source(source)
    local char = player:GetData("Character")

    local isSystemAdmin = char:GetData('MDTSystemAdmin')
    local hasPerms, loggedInJob = CheckMDTPermissions(source, {
      'MDT_FIRE',
      'PD_HIGH_COMMAND',
      'DOC_HIGH_COMMAND',
    }, data.JobId)

    if char and data and data.SID and (hasPerms or isSystemAdmin) then
      local charData = MDT.People:View(data.SID)
      if charData then
        local canRemove = false
        if isSystemAdmin then
          canRemove = true
        else
          local plyrJob = Jobs.Permissions:HasJob(source, loggedInJob)
          for k, v in ipairs(charData.Jobs) do
            if v.Id == data.JobId then
              if plyrJob.Grade.Level > v.Grade.Level then
                canRemove = true
              end
              break
            end
          end
        end


        if canRemove then
          local updateQuery = [[
            UPDATE characters
            SET
              MDTHistory = JSON_ARRAY_APPEND(MDTHistory, '$', JSON_OBJECT(
                'Time', ?,
                'Char', ?,
                'Log', ?
              )),
              MDTSuspension = JSON_REMOVE(MDTSuspension, ?)
            WHERE SID = ?
          ]]
          local time = os.time() * 1000
          local charSID = char:GetData("SID")
          local log = string.format(
            "%s Revoked Suspension From Job %s",
            char:GetData("First") .. " " .. char:GetData("Last"),
            data.JobId
          )
          local suspensionPath = string.format("$.%s", data.JobId)
          local params = { time, charSID, log, suspensionPath, data.SID }

          local updateUserDB = MySQL.update.await(updateQuery, params)
          if updateUserDB then
            local char = Fetch:SID(data.SID)
            if char then
              local suspensionShit = char:GetData("Character"):GetData("MDTSuspension") or {}
              suspensionShit[data.JobId] = nil
              char:GetData("Character"):SetData("MDTSuspension", suspensionShit)
            end
          end
        end
        return cb(true)
      end
    else
      cb(false)
    end
  end)
end)
