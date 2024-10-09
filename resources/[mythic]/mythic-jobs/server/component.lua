_characterDuty = {}
_dutyData = {}

_JOBS = {
  GetAll = function(self)
    return JOB_CACHE
  end,
  Get = function(self, jobId)
    return JOB_CACHE[jobId]
  end,
  DoesExist = function(self, jobId, workplaceId, gradeId)
    local job = Jobs:Get(jobId)
    if job then
      if workplaceId and job.Workplaces then
        for _, workplace in ipairs(job.Workplaces) do
          if workplace.Id == workplaceId then
            if not gradeId then
              return {
                Id = job.Id,
                Name = job.Name,
                Workplace = false,
                Hidden = job.Hidden,
              }
            end

            for _, grade in ipairs(workplace.Grades) do
              if grade.Id == gradeId then
                return {
                  Id = job.Id,
                  Name = job.Name,
                  Workplace = {
                    Id = workplace.Id,
                    Name = workplace.Name,
                  },
                  Grade = {
                    Id = grade.Id,
                    Name = grade.Name,
                    Level = grade.Level,
                  },
                  Hidden = job.Hidden,
                }
              end
            end
          end
        end
      elseif not workplaceId then
        if not gradeId then
          return {
            Id = job.Id,
            Name = job.Name,
            Workplace = false,
            Hidden = job.Hidden,
          }
        elseif gradeId and job.Grades then
          for _, grade in ipairs(job.Grades) do
            if grade.Id == gradeId then
              return {
                Id = job.Id,
                Name = job.Name,
                Workplace = false,
                Grade = {
                  Id = grade.Id,
                  Name = grade.Name,
                  Level = grade.Level,
                },
                Hidden = job.Hidden,
              }
            end
          end
        end
      end
    end
    return false
  end,
  GiveJob = function(self, stateId, jobId, workplaceId, gradeId, noOverride)
    local newJob = Jobs:DoesExist(jobId, workplaceId, gradeId)
    if not newJob or not newJob.Grade then
      return false
    end

    local char = Fetch:SID(stateId)
    if char then
      char = char:GetData('Character')
    end

    if char then
      local charJobData = char:GetData('Jobs')
      if not charJobData then charJobData = {} end

      for k, v in ipairs(charJobData) do
        if v.Id == newJob.Id then
          if noOverride then
            return false
          else
            table.remove(charJobData, k)
          end
        end
      end

      table.insert(charJobData, newJob)

      local source = char:GetData('Source')
      char:SetData('Jobs', charJobData)

      Middleware:TriggerEvent('Characters:ForceStore', source)
      Phone:UpdateJobData(source)
      TriggerEvent('Jobs:Server:JobUpdate', source)

      return true
    else
      local user = MySQL.single.await('SELECT * FROM characters WHERE SID = @sid', {
        ['@sid'] = stateId
      })

      if user == nil then
        return false
      end

      local charJobData = json.decode(user.Jobs)
      if not charJobData then charJobData = {} end
      for k, v in ipairs(charJobData) do
        if v.Id == newJob.Id then
          if noOverride then
            return false
          else
            table.remove(charJobData, k)
          end
        end
      end
      table.insert(charJobData, newJob)

      local affectedRows = MySQL.update.await('UPDATE characters SET Jobs = @jobs WHERE SID = @sid', {
        ['@jobs'] = json.encode(charJobData),
        ['@sid'] = stateId
      })

      return affectedRows > 0
    end
  end,
  RemoveJob = function(self, stateId, jobId)
    local char = Fetch:SID(stateId)
    if char then
      char = char:GetData('Character')
    end

    if char then
      local found = false
      local charJobData = char:GetData('Jobs')
      if not charJobData then charJobData = {}; end
      local removedJobData

      for k, v in ipairs(charJobData) do
        if v.Id == jobId then
          removedJobData = v
          found = true
          table.remove(charJobData, k)
        end
      end

      if found then
        local source = char:GetData('Source')
        char:SetData('Jobs', charJobData)
        Jobs.Duty:Off(source, jobId, true)

        Middleware:TriggerEvent('Characters:ForceStore', source)
        Phone:UpdateJobData(source)
        TriggerEvent('Jobs:Server:JobUpdate', source)

        if removedJobData.Workplace and removedJobData.Workplace.Name then
          Execute:Client(source, 'Notification', 'Info', 'No Longer Employed at ' .. removedJobData.Workplace.Name)
        else
          Execute:Client(source, 'Notification', 'Info', 'No Longer Employed at ' .. removedJobData.Name)
        end

        return true
      end
    else
      local result = MySQL.single.await('SELECT Jobs FROM characters WHERE SID = @stateId', {
        ['@stateId'] = stateId
      })

      if result == nil then return false end

      local charJobData = json.decode(result.Jobs)
      local found = false

      for k, v in ipairs(charJobData) do
        if v.Id == jobId then
          found = true
          table.remove(charJobData, k)
        end
      end

      if found then
        local affectedRows = MySQL.update.await('UPDATE characters SET Jobs = @jobs WHERE SID = @stateId', {
          ['@jobs'] = json.encode(charJobData),
          ['@stateId'] = stateId
        })

        return affectedRows > 0
      end
    end
  end,

  Duty = {
    On = function(self, source, jobId, hideNotify)
      local player = Fetch:Source(source)
      if player then
        local char = player:GetData('Character')
        if char then
          local stateId = char:GetData('SID')
          local charJobs = char:GetData('Jobs')
          local hasJob = false

          for k, v in ipairs(charJobs) do
            if v.Id == jobId then
              hasJob = v
              break
            end
          end

          if hasJob then
            local dutyData = _characterDuty[stateId]
            if dutyData then
              if dutyData.Id == hasJob.Id then
                return true -- Already on duty as that job
              else
                local success = Jobs.Duty:Off(source, false, true)
                if not success then
                  return false
                end
              end
            end

            _characterDuty[stateId] = {
              Source = source,
              Id = hasJob.Id,
              StartTime = os.time(),
              Time = os.time(),
              WorkplaceId = (hasJob.Workplace and hasJob.Workplace.Id or false),
              GradeId = hasJob.Grade.Id,
              GradeLevel = hasJob.Grade.Level,
              First = char:GetData('First'),
              Last = char:GetData('Last'),
              Callsign = char:GetData('Callsign'),
            }

            local ply = Player(source)
            if ply and ply.state then
              ply.state.onDuty = _characterDuty[stateId].Id
            end

            local callsign = char:GetData('Callsign')
            TriggerEvent('Job:Server:DutyAdd', _characterDuty[stateId], source, stateId, callsign)
            TriggerClientEvent('Job:Client:DutyChanged', source, _characterDuty[stateId].Id)
            Jobs.Duty:RefreshDutyData(hasJob.Id)

            local lastOnDutyData = char:GetData('LastClockOn') or {}
            lastOnDutyData[hasJob.Id] = os.time()
            char:SetData('LastClockOn', lastOnDutyData)

            if not hideNotify then
              if hasJob.Workplace then
                Execute:Client(source, 'Notification', 'Success',
                  string.format('You\'re Now On Duty as %s - %s', hasJob.Workplace.Name, hasJob.Grade.Name))
              else
                Execute:Client(source, 'Notification', 'Success',
                  string.format('You\'re Now On Duty as %s - %s', hasJob.Name, hasJob.Grade.Name))
              end
            end

            return hasJob
          end
        end
      end

      if not hideNotify then
        Execute:Client(source, 'Notification', 'Error', 'Failed to Go On Duty')
      end

      return false
    end,
    Off = function(self, source, jobId, hideNotify)
      local player = Fetch:Source(source)
      if player then
        local char = player:GetData('Character')
        if char then
          local stateId = char:GetData('SID')
          local dutyData = _characterDuty[stateId]
          if dutyData and (not jobId or (dutyData.Id == jobId)) then
            local dutyId = dutyData.Id
            local ply = Player(source)
            if ply and ply.state then
              ply.state.onDuty = false
            end

            local existing = char:GetData("Salary") or {}
            local workedMinutes = math.floor((os.time() - dutyData.Time) / 60)
            local j = Jobs:Get(dutyData.Id)
            local salary = math.ceil((j.Salary * j.SalaryTier) * (workedMinutes / _payPeriod))

            Logger:Info("Jobs",
              string.format("Adding Salary Data For ^3%s^7 Going Off-Duty (^2%s Minutes^7 - ^3$%s^7)",
                char:GetData("SID"), workedMinutes, salary))

            if existing[dutyData.Id] then
              existing[dutyData.Id] = {
                date = os.time(),
                job = dutyData.Id,
                minutes = (existing[dutyData.Id]?.minutes or 0) + workedMinutes,
                total = (existing[dutyData.Id]?.total or 0) + salary,
              }
            else
              existing[dutyData.Id] = {
                date = os.time(),
                job = dutyData.Id,
                minutes = workedMinutes,
                total = salary,
              }
            end

            char:SetData("Salary", existing)

            TriggerEvent('Job:Server:DutyRemove', dutyData, source, stateId)
            TriggerClientEvent('Job:Client:DutyChanged', source, false)
            _characterDuty[stateId] = nil
            Jobs.Duty:RefreshDutyData(dutyId)

            local totalWorkedMinutes = math.floor((os.time() - dutyData.StartTime) / 60)
            local allTimeWorked = char:GetData("TimeClockedOn") or {}
            local jobTimeWorked = allTimeWorked[dutyData.Id] or {}

            if totalWorkedMinutes and totalWorkedMinutes >= 5 then
              table.insert(jobTimeWorked, {
                time = os.time(),
                minutes = totalWorkedMinutes,
              })

              local deleteBefore = os.time() - (60 * 60 * 24 * 14) -- Only Keep Last 14 Days
              for k, v in ipairs(jobTimeWorked) do
                if tonumber(v.time) < deleteBefore then
                  table.remove(jobTimeWorked, k)
                end
              end

              allTimeWorked[dutyData.Id] = jobTimeWorked
            end
            char:SetData("TimeClockedOn", allTimeWorked)

            if not hideNotify then
              Execute:Client(source, 'Notification', 'Info', 'You\'re Now Off Duty')
            end

            return true
          end
        end
      end

      if not hideNotify then
        Execute:Client(source, 'Notification', 'Error', 'Failed to Go Off Duty')
      end

      return false
    end,
    Get = function(self, source, jobId)
      local player = Fetch:Source(source)
      if player then
        local char = player:GetData('Character')
        if char then
          local dutyData = _characterDuty[char:GetData('SID')]
          if dutyData and (not jobId or (jobId == dutyData.Id)) then
            return dutyData
          end
        end
      end
      return false
    end,
    GetDutyData = function(self, jobId)
      return _dutyData[jobId]
    end,
    RefreshDutyData = function(self, jobId)
      if not _dutyData[jobId] then
        _dutyData[jobId] = {}
      end

      local onDutyPlayers = {}
      local totalCount = 0
      local workplaceCounts = false

      for k, v in pairs(_characterDuty) do
        if v ~= nil and v.Id == jobId then
          totalCount = totalCount + 1
          table.insert(onDutyPlayers, v.Source)
          if v.WorkplaceId then
            if not workplaceCounts then
              workplaceCounts = {}
            end

            if not workplaceCounts[v.WorkplaceId] then
              workplaceCounts[v.WorkplaceId] = 1
            else
              workplaceCounts[v.WorkplaceId] = workplaceCounts[v.WorkplaceId] + 1
            end
          end
        end
      end

      _dutyData[jobId] = {
        Active = totalCount > 0,
        Count = totalCount,
        WorkplaceCounts = workplaceCounts,
        DutyPlayers = onDutyPlayers,
      }

      GlobalState[string.format('Duty:%s', jobId)] = totalCount
      if workplaceCounts then
        for workplace, count in pairs(workplaceCounts) do
          GlobalState[string.format('Duty:%s:%s', jobId, workplace)] = count
        end
      end
    end,
  },
  Permissions = {
    IsOwner = function(self, source, jobId)
      local player = Fetch:Source(source)
      if player then
        local char = player:GetData('Character')
        if char then
          local jobData = Jobs:Get(jobId)
          if jobData.Owner and jobData.Owner == char:GetData('SID') then
            return true
          end
        end
      end
      return false
    end,
    IsOwnerOfCompany = function(self, source)
      local player = Fetch:Source(source)
      if player then
        local char = player:GetData('Character')
        if char then
          local stateId = char:GetData('SID')
          local jobs = char:GetData('Jobs') or {}
          for k, v in ipairs(jobs) do
            local jobData = Jobs:Get(v.Id)
            if jobData.Owner and jobData.Owner == stateId then
              return true
            end
          end
        end
      end
      return false
    end,
    GetJobs = function(self, source)
      local player = Fetch:Source(source)
      if player then
        local char = player:GetData('Character')
        if char then
          local jobs = char:GetData('Jobs') or {}
          return jobs
        end
      end
      return false
    end,
    HasJob = function(self, source, jobId, workplaceId, gradeId, gradeLevel, checkDuty, permissionKey)
      local jobs = Jobs.Permissions:GetJobs(source)
      if not jobs then return false end
      if jobId then
        for k, v in ipairs(jobs) do
          if v.Id == jobId then
            if (not workplaceId or (v.Workplace and v.Workplace.Id == workplaceId)) then
              if (not gradeId or (v.Grade.Id == gradeId)) then
                if (not gradeLevel or (v.Grade.Level and v.Grade.Level >= gradeLevel)) then
                  if not checkDuty or (checkDuty and Jobs.Duty:Get(source, jobId)) then
                    if not permissionKey or (permissionKey and Jobs.Permissions:HasPermissionInJob(source, jobId, permissionKey)) then
                      return v
                    end
                  end
                end
              end
            end
            break
          end
        end
      elseif permissionKey then
        return Jobs.Permissions:HasPermission(source, permissionKey)
      end
      return false
    end,
    -- Gets the permissions the character has in a job they have
    GetPermissionsFromJob = function(self, source, jobId, workplaceId)
      local jobData = Jobs.Permissions:HasJob(source, jobId, workplaceId)
      if jobData then
        local perms = GlobalState
            [string.format('JobPerms:%s:%s:%s', jobData.Id, (jobData.Workplace and jobData.Workplace.Id or false), jobData.Grade.Id)]
        if perms then
          return perms
        end
      end
      return false
    end,
    -- Checks if character has a permission in a specific job they have
    HasPermissionInJob = function(self, source, jobId, permissionKey)
      local permissionsInJob = Jobs.Permissions:GetPermissionsFromJob(source, jobId)
      if permissionsInJob then
        if permissionsInJob[permissionKey] then
          return true
        end
      end
      return false
    end,
    -- Gets permissions from all jobs
    GetAllPermissions = function(self, source)
      local allPermissions = {}
      local jobs = Jobs.Permissions:GetJobs(source)
      if jobs and #jobs > 0 then
        for k, v in ipairs(jobs) do
          local perms = GlobalState
              [string.format('JobPerms:%s:%s:%s', v.Id, (v.Workplace and v.Workplace.Id or false), v.Grade.Id)]
          if perms ~= nil then
            for k, v in pairs(perms) do
              if not allPermissions[k] then
                allPermissions[k] = v
              end
            end
          end
        end
      end
      return allPermissions
    end,
    -- Checks if character has a permission in any of their jobs
    HasPermission = function(self, source, permissionKey)
      local allPermissions = Jobs.Permissions:GetAllPermissions(source)
      return allPermissions[permissionKey]
    end,
  },
  Management = {
    Create = function(self, name, ownerSID) -- For player business creations
      if not name then
        name = Generator:Company()
      end
      local jobId = string.format('Company_%s', Sequence:Get('Company'))
      if jobId and name then
        local existing = Jobs:Get(jobId)
        if not existing then
          local p = promise.new()
          local document = {
            Type = 'Company',
            Custom = true,
            Id = jobId,
            Name = name,
            Owner = ownerSID,
            Salary = 100,
            SalaryTier = 1,
            Grades = {
              {
                Id = 'owner',
                Name = 'Owner',
                Level = 100,
                Permissions = {
                  JOB_MANAGEMENT = true,
                  JOB_FIRE = true,
                  JOB_HIRE = true,
                  JOB_MANAGE_EMPLOYEES = true,
                },
              }
            },
          }

          local insertBusiness = MySQL.insert.await(
            'INSERT INTO `jobs` (`Id`, `Name`, `Owner`, `Type`, `Workplace`, `Grades`, `Salary`, `SalaryTier`) values (?, ?, ?, ?, ?, ?, ?)',
            {
              document.Id,
              document.Name,
              document.Owner,
              document.Type,
              nil,
              json.encode(document.Grades),
              100,
              1,
            })

          if insertBusiness > 0 then
            RefreshAllJobData(document.Id)

            Jobs:GiveJob(ownerSID, document.Id, false, 'owner')
            return document
          end
          return false
        end
      end
      return false
    end,
    Transfer = function(self, jobId, newOwner)
      -- TODO
      --Middleware:TriggerEvent("Business:Transfer", jobId, source:GetData("SID"), target:GetData("SID"))
    end,
    Upgrades = {
      -- TODO
      Has = function(self, jobId, upgradeKey)

      end,
      Unlock = function(self, jobId, upgradeKey)

      end,
      Lock = function(self, jobId, upgradeKey)

      end,
      Reset = function(self, jobId)

      end,
    },
    Delete = function(self, jobId)
      -- TODO
    end,
    Edit = function(self, jobId, settingData)
      if Jobs:DoesExist(jobId) then
        local actualSettingData = {}

        for k, v in pairs(settingData) do
          if k ~= 'Grades' and k ~= 'Workplaces' and k ~= 'Id' and v ~= nil then
            actualSettingData[k] = v
          end
        end

        local success = false
        local affectedRows = exports.oxmysql:executeSync('UPDATE jobs SET ? WHERE Id = ?', { actualSettingData, jobId })

        if affectedRows > 0 then
          RefreshAllJobData(jobId)
          if actualSettingData.Name then
            Jobs.Management.Employees:UpdateAllJob(jobId, actualSettingData.Name)
          end
          success = true
        end
        return {
          success = success,
          code = 'ERROR',
        }
      else
        return {
          success = false,
          code = 'MISSING_JOB',
        }
      end
    end,
    Workplace = {
      Edit = function(self, jobId, workplaceId, newWorkplaceName)
        if Jobs:DoesExist(jobId, workplaceId) then
          local query = [[
            UPDATE jobs
            SET Workplaces = JSON_SET(
                Workplaces,
                CONCAT('$[', JSON_UNQUOTE(JSON_SEARCH(Workplaces, 'one', ?, '$[*].Id')), '].Name'),
                ?
            )
            WHERE Type = ? AND Id = ? AND JSON_CONTAINS(Workplaces, JSON_OBJECT('Id', ?))
        ]]

          local params = { workplaceId, newWorkplaceName, 'Government', jobId, workplaceId }

          local affectedRows = exports.oxmysql:executeSync(query, params)

          local success = false
          if affectedRows > 0 then
            RefreshAllJobData(jobId)
            Jobs.Management.Employees:UpdateAllWorkplace(jobId, workplaceId, newWorkplaceName)
            success = true
          end

          return {
            success = success,
            code = 'ERROR',
          }
        else
          return {
            success = false,
            code = 'ERROR',
          }
        end
      end,
    },
    Grades = {
      Create = function(self, jobId, workplaceId, gradeName, gradeLevel, gradePermissions)
        if Jobs:DoesExist(jobId, workplaceId) then
          local gradeId
          if workplaceId then
            gradeId = string.format("Grade_%s", Sequence:Get(string.format("Company:%s:%s:Grades", jobId, workplaceId)))
          else
            gradeId = string.format("Grade_%s", Sequence:Get(string.format("Company:%s:Grades", jobId)))
          end

          -- Check if grade exists (you'll need to implement this function)
          if Jobs:DoesExist(jobId, workplaceId, gradeId) then
            print("This grade exists, lets return")
            return false
          end

          local gradeData = {
            Id = gradeId,
            Name = gradeName,
            Level = gradeLevel,
            Permissions = gradePermissions or {}
          }
          -- Fetch the current job data
          local query = "SELECT * FROM jobs WHERE Id = ?"
          local result = exports.oxmysql:executeSync(query, { jobId })

          if #result == 0 then
            return false
          end

          local jobData = result[1]

          if workplaceId then
            -- Government job
            if jobData.Workplaces then
              local workplaces = json.decode(jobData.Workplaces)
              for i, workplace in ipairs(workplaces) do
                if workplace.Id == workplaceId then
                  workplace.Grades = workplace.Grades or {}
                  table.insert(workplace.Grades, gradeData)
                  break
                end
              end
              jobData.Workplaces = json.encode(workplaces)
            else
              return false
            end
          else
            -- Company job
            local grades = jobData.Grades and json.decode(jobData.Grades) or {}
            table.insert(grades, gradeData)
            jobData.Grades = json.encode(grades)
          end

          -- Update the job data in the database
          local updateQuery = [[
        UPDATE jobs
        SET Grades = ?, Workplaces = ?
        WHERE Id = ?
    ]]
          local params = { jobData.Grades, jobData.Workplaces, jobId }

          local affectedRows = MySQL.update.await(updateQuery, params)
          if affectedRows > 0 then
            RefreshAllJobData(jobId)
            return {
              success = true,
              code = 'ERROR',
            }
          else
            return {
              success = false,
              code = 'ERROR',
            }
          end
        else
          return {
            success = false,
            code = 'MISSING_JOB',
          }
        end
      end,
      Edit = function(self, jobId, workplaceId, gradeId, settingData)
        if Jobs:DoesExist(jobId, workplaceId, gradeId) then
          -- Fetch the current job data
          local query = "SELECT * FROM jobs WHERE Id = ?"
          local result = exports.oxmysql:executeSync(query, { jobId })

          if #result == 0 then
            return false
          end

          local jobData = result[1]
          local updated = false

          if workplaceId then
            -- Government job
            if jobData.Workplaces then
              local workplaces = json.decode(jobData.Workplaces)
              for _, workplace in ipairs(workplaces) do
                if workplace.Id == workplaceId then
                  for i, grade in ipairs(workplace.Grades or {}) do
                    if grade.Id == gradeId then
                      for k, v in pairs(settingData) do
                        if k ~= 'Id' then
                          grade[k] = v
                        end
                      end
                      updated = true
                      break
                    end
                  end
                  break
                end
              end
              if updated then
                jobData.Workplaces = json.encode(workplaces)
              end
            end
          else
            -- Company job
            if jobData.Grades then
              local grades = json.decode(jobData.Grades)
              for i, grade in ipairs(grades) do
                if grade.Id == gradeId then
                  for k, v in pairs(settingData) do
                    if k ~= 'Id' then
                      grade[k] = v
                    end
                  end
                  updated = true
                  break
                end
              end
              if updated then
                jobData.Grades = json.encode(grades)
              end
            end
          end

          if updated then
            -- Update the job data in the database
            local updateQuery = [[
            UPDATE jobs
            SET Grades = ?, Workplaces = ?
            WHERE Id = ?
        ]]
            local params = { jobData.Grades, jobData.Workplaces, jobId }

            local affectedRows = exports.oxmysql:executeSync(updateQuery, params)

            if affectedRows > 0 then
              RefreshAllJobData(jobId)
              Jobs.Management.Employees:UpdateAllGrade(jobId, workplaceId, gradeId, settingData)
              return {
                success = true,
                code = 'ERROR',
              }
            end
            return {
              success = false,
              code = 'MISSING_JOB',
            }
          end
        else
          return {
            success = false,
            code = 'MISSING_JOB',
          }
        end
      end,
      Delete = function(self, jobId, workplaceId, gradeId)
        local peopleWithJobGrade = Jobs.Management.Employees:GetAll(jobId, workplaceId, gradeId)
        if #peopleWithJobGrade > 0 then
          return {
            success = false,
            code = 'JOB_OCCUPIED',
          }
        end

        if not Jobs:DoesExist(jobId, workplaceId, gradeId) then
          return {
            success = false,
            code = 'MISSING_JOB',
          }
        end

        -- Fetch the current job data
        local query = "SELECT * FROM jobs WHERE Id = ?"
        local result = exports.oxmysql:executeSync(query, { jobId })

        if #result == 0 then
          return {
            success = false,
            code = 'MISSING_JOB',
          }
        end

        local jobData = result[1]
        local updated = false

        if workplaceId then
          -- Government job
          if jobData.Workplaces then
            local workplaces = json.decode(jobData.Workplaces)
            for _, workplace in ipairs(workplaces) do
              if workplace.Id == workplaceId then
                for i = #workplace.Grades, 1, -1 do
                  if workplace.Grades[i].Id == gradeId then
                    table.remove(workplace.Grades, i)
                    updated = true
                    break
                  end
                end
                break
              end
            end
            if updated then
              jobData.Workplaces = json.encode(workplaces)
            end
          end
        else
          -- Company job
          if jobData.Grades then
            local grades = json.decode(jobData.Grades)
            for i = #grades, 1, -1 do
              if grades[i].Id == gradeId then
                table.remove(grades, i)
                updated = true
                break
              end
            end
            if updated then
              jobData.Grades = json.encode(grades)
            end
          end
        end

        if updated then
          -- Update the job data in the database
          local updateQuery = [[
                UPDATE jobs
                SET Grades = ?, Workplaces = ?
                WHERE Id = ?
            ]]
          local params = { jobData.Grades, jobData.Workplaces, jobId }

          local affectedRows = exports.oxmysql:executeSync(updateQuery, params)

          if affectedRows > 0 then
            RefreshAllJobData(jobId)
            return {
              success = true,
              code = 'SUCCESS',
            }
          end
        end

        return {
          success = false,
          code = 'ERROR',
        }
      end,
    },
    Employees = {
      GetAll = function(self, jobId, workplaceId, gradeId)
        local jobCharacters = {}
        local onlineCharacters = {}

        -- Process online characters
        for k, v in pairs(Fetch:All()) do
          local char = v:GetData('Character')
          if char then
            table.insert(onlineCharacters, char:GetData('SID'))
            local jobs = char:GetData('Jobs')
            if jobs and #jobs > 0 then
              for k, v in ipairs(jobs) do
                if v.Id == jobId and
                    (not workplaceId or (workplaceId and (v.Workplace and v.Workplace.Id == workplaceId))) and
                    (not gradeId or (v.Grade.Id == gradeId)) then
                  table.insert(jobCharacters, {
                    Source = char:GetData('Source'),
                    SID = char:GetData('SID'),
                    First = char:GetData('First'),
                    Last = char:GetData('Last'),
                    Phone = char:GetData('Phone'),
                    JobData = v,
                  })
                end
              end
            end
          end
        end

        -- Construct the query for offline characters
        local query = [[
            SELECT c.SID, c.First, c.Last, c.Phone, c.Jobs
            FROM characters c
            WHERE JSON_CONTAINS(c.Jobs, JSON_OBJECT('Id', ?))
        ]]

        local params = { jobId }

        if #onlineCharacters > 0 then
          query = query .. " AND c.SID NOT IN (" .. table.concat(onlineCharacters, ',') .. ")"
        end

        if workplaceId then
          query = query .. " AND JSON_CONTAINS(c.Jobs, JSON_OBJECT('Id', ?, 'Workplace', JSON_OBJECT('Id', ?)), '$[*]')"
          table.insert(params, jobId)
          table.insert(params, workplaceId)
        end

        if gradeId then
          query = query .. " AND JSON_CONTAINS(c.Jobs, JSON_OBJECT('Id', ?, 'Grade', JSON_OBJECT('Id', ?)), '$[*]')"
          table.insert(params, jobId)
          table.insert(params, gradeId)
        end

        local results = exports.oxmysql:executeSync(query, params)

        for _, c in ipairs(results) do
          local jobs = json.decode(c.Jobs)
          for k, v in ipairs(jobs) do
            if v.Id == jobId and
                (not workplaceId or (workplaceId and (v.Workplace and v.Workplace.Id == workplaceId))) and
                (not gradeId or (v.Grade.Id == gradeId)) then
              table.insert(jobCharacters, {
                Source = false,
                SID = c.SID,
                First = c.First,
                Last = c.Last,
                Phone = c.Phone,
                JobData = v,
              })
            end
          end
        end

        return jobCharacters
      end,
      UpdateAllJob = function(self, jobId, newJobName)
        local onlineCharacters = {}
        local updatedCount = 0

        -- Process online characters
        for k, v in pairs(Fetch:All()) do
          local char = v:GetData('Character')
          if char then
            table.insert(onlineCharacters, char:GetData('SID'))
            local jobs = char:GetData('Jobs')
            if jobs and #jobs > 0 then
              local updated = false
              for k, v in ipairs(jobs) do
                if v.Id == jobId then
                  v.Name = newJobName
                  updated = true
                end
              end
              if updated then
                char:SetData('Jobs', jobs)
                Phone:UpdateJobData(char:GetData('Source'))
                updatedCount = updatedCount + 1
              end
            end
          end
        end

        -- Update offline characters
        local query = [[
            UPDATE characters
            SET Jobs = JSON_ARRAY(
                IF(
                    JSON_CONTAINS(Jobs, JSON_OBJECT('Id', ?)),
                    JSON_ARRAY_INSERT(
                        JSON_REMOVE(Jobs, '$[0]'),
                        '$[0]',
                        JSON_SET(
                            JSON_EXTRACT(Jobs, '$[0]'),
                            '$.Name',
                            ?
                        )
                    ),
                    Jobs
                )
            )
            WHERE JSON_CONTAINS(Jobs, JSON_OBJECT('Id', ?))
        ]]

        if #onlineCharacters > 0 then
          query = query .. " AND SID NOT IN (" .. table.concat(onlineCharacters, ',') .. ")"
        end

        local params = { jobId, newJobName, jobId }

        local result = exports.oxmysql:executeSync(query, params)

        updatedCount = updatedCount + result.affectedRows

        return updatedCount
      end,
      UpdateAllWorkplace = function(self, jobId, workplaceId, newWorkplaceName)
        local onlineCharacters = {}
        local updatedCount = 0

        -- Process online characters
        for k, v in pairs(Fetch:All()) do
          local char = v:GetData('Character')
          if char then
            table.insert(onlineCharacters, char:GetData('SID'))
            local jobs = char:GetData('Jobs')
            if jobs and #jobs > 0 then
              local updated = false
              for k, v in ipairs(jobs) do
                if v.Id == jobId and v.Workplace and v.Workplace.Id == workplaceId then
                  v.Workplace.Name = newWorkplaceName
                  updated = true
                end
              end
              if updated then
                char:SetData('Jobs', jobs)
                Phone:UpdateJobData(char:GetData('Source'))
                updatedCount = updatedCount + 1
              end
            end
          end
        end

        -- Update offline characters
        local query = [[
            UPDATE characters
            SET Jobs = JSON_ARRAY_MAP(
                Jobs,
                CASE
                    WHEN JSON_EXTRACT(elem, '$.Id') = ?
                         AND JSON_EXTRACT(elem, '$.Type') = 'Government'
                         AND JSON_EXTRACT(elem, '$.Workplace.Id') = ?
                    THEN JSON_SET(elem, '$.Workplace.Name', ?)
                    ELSE elem
                END
            )
            WHERE JSON_CONTAINS(Jobs, JSON_OBJECT('Id', ?, 'Type', 'Government', 'Workplace', JSON_OBJECT('Id', ?)))
        ]]

        if #onlineCharacters > 0 then
          query = query .. " AND SID NOT IN (" .. table.concat(onlineCharacters, ',') .. ")"
        end

        local params = { jobId, workplaceId, newWorkplaceName, jobId, workplaceId }

        local result = exports.oxmysql:executeSync(query, params)

        updatedCount = updatedCount + result.affectedRows

        return updatedCount
      end,
      UpdateAllGrade = function(self, jobId, workplaceId, gradeId, settingData)
        local onlineCharacters = {}
        local updatedCount = 0

        if not (settingData.Name or settingData.Level) then
          return 0
        end

        -- Process online characters
        for k, v in pairs(Fetch:All()) do
          local char = v:GetData('Character')
          if char then
            table.insert(onlineCharacters, char:GetData('SID'))
            local jobs = char:GetData('Jobs')
            if jobs and #jobs > 0 then
              local updated = false
              for k, v in ipairs(jobs) do
                if v.Id == jobId and
                    (not workplaceId or (workplaceId and v.Workplace and v.Workplace.Id == workplaceId)) and
                    v.Grade.Id == gradeId then
                  if settingData.Name then
                    v.Grade.Name = settingData.Name
                  end
                  if settingData.Level then
                    v.Grade.Level = settingData.Level
                  end
                  updated = true
                end
              end
              if updated then
                char:SetData('Jobs', jobs)
                Phone:UpdateJobData(char:GetData('Source'))
                updatedCount = updatedCount + 1
              end
            end
          end
        end

        -- Construct the update part of the query
        local updateParts = {}
        if settingData.Name then
          table.insert(updateParts, "JSON_SET(elem, '$.Grade.Name', '" .. settingData.Name .. "')")
        end
        if settingData.Level then
          table.insert(updateParts, "JSON_SET(elem, '$.Grade.Level', " .. settingData.Level .. ")")
        end
        local updateString = table.concat(updateParts, ", ")

        -- Construct the full query
        local query = [[
            UPDATE characters
            SET Jobs = JSON_ARRAY_MAP(
                Jobs,
                CASE
                    WHEN JSON_EXTRACT(elem, '$.Id') = ?
                         AND JSON_EXTRACT(elem, '$.Grade.Id') = ?
        ]]
        if workplaceId then
          query = query .. " AND JSON_EXTRACT(elem, '$.Workplace.Id') = ?"
        end
        query = query .. [[
                    THEN ]] .. updateString .. [[
                    ELSE elem
                END
            )
            WHERE JSON_CONTAINS(Jobs, JSON_OBJECT('Id', ?, 'Grade', JSON_OBJECT('Id', ?)))
        ]]

        local params = { jobId, gradeId }
        if workplaceId then
          table.insert(params, workplaceId)
        end
        table.insert(params, jobId)
        table.insert(params, gradeId)

        if #onlineCharacters > 0 then
          query = query .. " AND SID NOT IN (" .. table.concat(onlineCharacters, ',') .. ")"
        end

        local result = exports.oxmysql:executeSync(query, params)

        updatedCount = updatedCount + result.affectedRows

        return updatedCount
      end,
    }
  },
  Data = {
    Set = function(self, jobId, key, val)
      if Jobs:DoesExist(jobId) and key then
        local updatedRows = MySQL.update.await('UPDATE `jobs` SET ' .. key .. ' = @val WHERE `Id` = @jobId', {
          ['@val'] = type(val) == 'table' and json.encode(val) or val,
          ['@jobId'] = jobId
        })
        return {
          success = updatedRows > 0,
          code = "ERROR",
        }
      else
        return {
          success = false,
          code = "MISSING_JOB",
        }
      end
    end,
    Get = function(self, jobId, key)
      if key and JOB_CACHE[jobId] and JOB_CACHE[jobId].Data then
        return JOB_CACHE[jobId].Data[key]
      end
    end,
  },
}

AddEventHandler('Proxy:Shared:RegisterReady', function()
  exports['mythic-base']:RegisterComponent('Jobs', _JOBS)
end)
