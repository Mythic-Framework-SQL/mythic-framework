AddEventHandler('Finance:Server:Startup', function()
  RegisterLoanCallbacks()

  CreateLoanTasks()
end)

function CreateLoanTasks()
  Tasks:Register('loan_payment', 60, function()
    local TASK_RUN_TIMESTAMP = os.time()

    -- Update loans that have missed payments
    local updateQuery = [[
      UPDATE loans
      SET
        InterestRate = InterestRate + ?,
        LastMissedPayment = ?,
        MissedPayments = MissedPayments + 1,
        TotalMissedPayments = TotalMissedPayments + 1,
        NextPayment = NextPayment + ?,
        Remaining = Remaining + (Total * ?)
      WHERE
        NextPayment > 0 AND NextPayment <= ? AND
        Defaulted = 0 AND Remaining >= 0
    ]]

    local params = {
      _loanConfig.missedPayments.interestIncrease,
      TASK_RUN_TIMESTAMP,
      _loanConfig.paymentInterval,
      _loanConfig.missedPayments.charge / 100,
      TASK_RUN_TIMESTAMP
    }

    exports.oxmysql:execute(updateQuery, params, function(affectedRows)
      if affectedRows > 0 then
        -- Handle defaulted loans
        local defaultedQuery = [[
          SELECT * FROM loans
          WHERE MissedPayments >= MissablePayments AND Defaulted = 0
        ]]

        exports.oxmysql:execute(defaultedQuery, {}, function(results)
          if results and #results > 0 then
            local updatingAssets = {}
            for _, v in ipairs(results) do
              table.insert(updatingAssets, v.AssetIdentifier)
            end

            local updateDefaultedQuery = [[
              UPDATE loans
              SET Defaulted = 1
              WHERE AssetIdentifier IN (?)
            ]]

            exports.oxmysql:execute(updateDefaultedQuery, { updatingAssets }, function(success)
              if success then
                Logger:Info('Loans', '^2' .. #results .. '^7 Loans Have Just Been Defaulted')
                for _, v in ipairs(results) do
                  if v.SID then
                    DecreaseCharacterCreditScore(v.SID, _creditScoreConfig.removal.defaultedLoan)
                    local onlineChar = Fetch:SID(v.SID)
                    if onlineChar then
                      SendDefaultedLoanNotification(onlineChar:GetData('Source'), v)
                    end
                  end

                  if v.AssetIdentifier then
                    if v.Type == 'vehicle' then
                      Vehicles.Owned:Seize(v.AssetIdentifier, true)
                    elseif v.Type == 'property' then
                      Properties.Commerce:Foreclose(v.AssetIdentifier, true)
                    end
                  end
                end
              end
            end)
          end
        end)

        -- Notify missed payments
        local missedPaymentsQuery = [[
          SELECT * FROM loans
          WHERE MissedPayments < MissablePayments AND Defaulted = 0 AND LastMissedPayment = ?
        ]]

        exports.oxmysql:execute(missedPaymentsQuery, { TASK_RUN_TIMESTAMP }, function(results)
          if results and #results > 0 then
            Logger:Info('Loans', '^2' .. #results .. '^7 Loan Payments Were Just Missed')
            for _, v in ipairs(results) do
              if v.SID then
                DecreaseCharacterCreditScore(v.SID, _creditScoreConfig.removal.missedLoanPayment)
                local onlineChar = Fetch:SID(v.SID)
                if onlineChar then
                  SendMissedLoanNotification(onlineChar:GetData('Source'), v)
                end
              end
            end
          end
        end)
      end
    end)
  end)

  Tasks:Register('loan_reminder', 120, function()
    local TASK_RUN_TIMESTAMP = os.time()
    local reminderQuery = [[
      SELECT * FROM loans
      WHERE Remaining > 0 AND Defaulted = 0 AND
      ((NextPayment > 0 AND NextPayment <= ?) OR MissedPayments > 0)
    ]]

    exports.oxmysql:execute(reminderQuery, { TASK_RUN_TIMESTAMP + (60 * 60 * 6) }, function(results)
      if results and #results > 0 then
        for _, v in ipairs(results) do
          if v.SID then
            local onlineChar = Fetch:SID(v.SID)
            if onlineChar then
              Phone.Notification:Add(onlineChar:GetData("Source"), "Loan Payment Due",
                "You have a loan payment that is due very soon.", os.time(), 7500, "loans", {})
            end
            Citizen.Wait(100)
          end
        end
      end
    end)
  end)
end

function SendMissedLoanNotification(source, loanData)
  Phone.Notification:Add(source, "Loan Payment Missed", "You just missed a loan payment on one of your loans.", os.time(),
    7500, "loans", {})
end

function SendDefaultedLoanNotification(source, loanData)
  Phone.Notification:Add(source, "Loan Defaulted",
    "One of your loans just got defaulted and the assets are going to be seized.", os.time(), 7500, "loans", {})
end

local typeNames = {
  vehicle = 'Vehicle Loan',
  property = 'Property Loan',
}

function GetLoanTypeName(type)
  return typeNames[type]
end
