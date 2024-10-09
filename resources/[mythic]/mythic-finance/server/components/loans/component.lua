_LOANS = {
  GetAllowedLoanAmount = function(self, stateId, type)
    if not type then
      type = "vehicle"
    end
    if _creditScoreConfig.allowedLoanMultipliers[type] then
      local creditScore = GetCharacterCreditScore(stateId)

      local creditMult = 0
      for k, v in ipairs(_creditScoreConfig.allowedLoanMultipliers[type]) do
        if creditScore >= v.value then
          creditMult = v.multiplier
        else
          break
        end
      end

      return {
        creditScore = creditScore,
        maxBorrowable = creditScore * creditMult,
        limit = creditScore > 420 and 3 or 2,
      }
    end
  end,
  GetDefaultInterestRate = function(self)
    return _loanConfig.defaultInterestRate
  end,
  GetPlayerLoans = function(self, stateId, type)
    local p = promise.new()

    local query = [[
      SELECT *
      FROM loans
      WHERE
        SID = ? AND
        Type = ? AND
        (
          Remaining > 0 OR
          (Remaining = 0 AND LastPayment >= ?)
        )
    ]]
    local params = { stateId, type, os.time() + (60 * 60 * 24 * 1) }
    local fetchLoans = MySQL.query.await(query, params)
    return fetchLoans
  end,
  CreateVehicleLoan = function(self, targetSource, VIN, totalCost, downPayment, totalWeeks)
    local char = Fetch:Source(targetSource):GetData("Character")
    if char then
      local remainingCost = totalCost - downPayment
      local timeStamp = os.time()

      local query = [[
        INSERT INTO loans (
          Creation, SID, Type, AssetIdentifier, Defaulted, InterestRate, Total, Remaining, Paid, DownPayment,
          TotalPayments, PaidPayments, MissablePayments, MissedPayments, TotalMissedPayments, NextPayment, LastPayment
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ]]

      local params = {
        timeStamp,
        char:GetData("SID"),
        "vehicle",
        VIN,
        false,
        _loanConfig.defaultInterestRate,
        totalCost,
        remainingCost,
        downPayment,
        downPayment,
        totalWeeks,
        0,
        _loanConfig.missedPayments.limit,
        0,
        0,
        timeStamp + _loanConfig.paymentInterval,
        0
      }

      local insertId = MySQL.insert.await(query, params)
      return insertId > 0
    end
    return false
  end,
  CreatePropertyLoan = function(self, targetSource, propertyId, totalCost, downPayment, totalWeeks)
    local char = Fetch:Source(targetSource):GetData("Character)")
    if char then
      local remainingCost = totalCost - downPayment
      local timeStamp = os.time()

      local query = [[
        INSERT INTO loans (
          Creation, SID, Type, AssetIdentifier, Defaulted, InterestRate, Total, Remaining, Paid, DownPayment,
          TotalPayments, PaidPayments, MissablePayments, MissedPayments, TotalMissedPayments, NextPayment, LastPayment
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ]]

      local params = {
        timeStamp,
        char:GetData("SID"),
        "property",
        propertyId,
        false,
        _loanConfig.defaultInterestRate,
        totalCost,
        remainingCost,
        downPayment,
        downPayment,
        totalWeeks,
        0,
        _loanConfig.missedPayments.limit,
        0,
        0,
        timeStamp + _loanConfig.paymentInterval,
        0
      }

      local insertId = MySQL.insert.await(query, params)
      return insertId > 0
    end
    return false
  end,
  MakePayment = function(self, source, loanId, inAdvanced, advancedPaymentCount)
    local char = Fetch:Source(source):GetData("Character")
    if char then
      local SID = char:GetData("SID")
      local Account = char:GetData("BankAccount")
      local loan = GetLoanByID(loanId, SID)
      if loan then
        local timeStamp = os.time()

        local remainingPayments = loan.TotalPayments - loan.PaidPayments

        local totalCreditGained = _creditScoreConfig.addition.loanPaymentMin
        if loan.Total >= 50000 then
          totalCreditGained += (math.floor(loan.Total / 50000) * 10)

          if totalCreditGained > _creditScoreConfig.addition.loanPaymentMax then
            totalCreditGained = _creditScoreConfig.addition.loanPaymentMax
          end
        end

        if remainingPayments > 0 and loan.Remaining > 0 then
          local interestMult = ((100 + loan.InterestRate) / 100)
          local creditScoreIncrease = 0
          local actuallyAdvancedPayments = 0
          local payments = 1
          if loan.MissedPayments > 0 then
            payments = loan.MissedPayments

            if payments > remainingPayments then
              payments = remainingPayments
            end

            creditScoreIncrease += math.floor(((totalCreditGained / loan.TotalPayments) * payments) / 2)
          else
            local timeUntilDue = loan.NextPayment - timeStamp
            local doneMinLoanLength = (timeStamp - loan.Creation) >= (60 * 60 * 24 * 5)

            if timeUntilDue >= (_loanConfig.paymentInterval * 4) and not doneMinLoanLength then -- Can only pay 2 weeks in advanced or wait until loan is 1 week old
              return {
                success = false,
                message = "Can't Pay That Far in Advanced - Hold Loan For At Least 5 Days",
              }
            end

            local loanPaymentCreditIncrease = math.floor(totalCreditGained / loan.TotalPayments)
            creditScoreIncrease += loanPaymentCreditIncrease

            local earlyTime = loan.NextPayment - (_loanConfig.paymentInterval * 0.5)
            if timeStamp <= earlyTime then -- Well Done You Are Early
              creditScoreIncrease += 2
            end
          end

          -- TODO: (maybe) Interest Going to the Government Account?

          local dueAmount = math.ceil(((loan.Remaining / remainingPayments) * payments) * interestMult)
          local chargeSuccess = Banking.Balance:Charge(Account, dueAmount, {
            type = "loan",
            title = "Loan Payment",
            description = string.format(
              "Loan Payment for %s %s",
              GetLoanTypeName(loan.Type),
              loan.AssetIdentifier
            ),
            data = {
              loan = loan._id,
            },
          })

          if chargeSuccess then
            local updateQuery
            local loanPaidOff = false
            local nowRemainingPayments = remainingPayments - payments
            if nowRemainingPayments <= 0 then
              loanPaidOff = true
            end

            if loan.Defaulted then -- Unseize Assets
              if loan.Type == "vehicle" then
                Vehicles.Owned:Seize(loan.AssetIdentifier, false)
              elseif loan.Type == "property" then
                Properties.Commerce:Foreclose(loan.AssetIdentifier, false)
              end
            end

            if loanPaidOff then
              if loan.TotalMissedPayments <= 0 then
                creditScoreIncrease += _creditScoreConfig.addition.completingLoanNoMissed
              else
                creditScoreIncrease += _creditScoreConfig.addition.completingLoan
              end

              updateQuery = {
                LastPayment = timeStamp,
                NextPayment = 0,
                Remaining = 0,
                Defaulted = false,
                Paid = dueAmount,
                PaidPayments = payments,
              }
            else
              updateQuery = {
                LastPayment = timeStamp,
                NextPayment = (loan.NextPayment + _loanConfig.paymentInterval),
                Defaulted = false,
                Paid = dueAmount,
                PaidPayments = payments,
                Remaining = -dueAmount,
              }

              if loan.MissedPayments > 0 then
                updateQuery["MissedPayments"] = 0
                updateQuery["MissablePayments"] = math.max(1, loan.MissablePayments - loan.MissedPayments)
              end
            end

            local updated = UpdateLoanById(loan._id, updateQuery)

            if creditScoreIncrease > 0 then
              IncreaseCharacterCreditScore(SID, creditScoreIncrease)
            end

            if updated then
              return {
                success = true,
                paidOff = loanPaidOff,
                paymentAmount = dueAmount,
                creditIncrease = creditScoreIncrease,
              }
            end
          else
            return {
              success = false,
              message = "Insufficient Funds in Checking Account",
            }
          end
        end
      end
    end
    return {
      success = false,
    }
  end,
  HasRemainingPayments = function(self, assetType, assetId, checkAge)
    -- checkAge (check if older than certain age (days))
    local fetchLoan = MySQL.single.await(
      "SELECT * FROM loans WHERE Type = ? AND AssetIdentifier = ?",
      { assetType, assetId }
    )

    if not fetchLoan then return false end

    if checkAge then
      if fetchLoan.Creation >= (os.time() - (60 * 60 * 24 * checkAge)) then
        return true
      end
    end

    if fetchLoan.Remaining > 0 then
      return true
    end

    return false
  end,
  Credit = {
    Get = function(self, stateId)
      return GetCharacterCreditScore(stateId)
    end,
    Set = function(self, stateId, newVal)
      return SetCharacterCreditScore(stateId, newVal)
    end,
    Increase = function(self, stateId, increase)
      return IncreaseCharacterCreditScore(stateId, increase)
    end,
    Decrease = function(self, stateId, decrease)
      return DecreaseCharacterCreditScore(stateId, decrease)
    end,
  },
  HasBeenDefaulted = function(self, assetType, assetId)
    local myLoan = MySQL.single.await(
      "SELECT * FROM loans WHERE Type = ? AND AssetIdentifier = ? AND Defaulted = 1",
      { assetType, assetId }
    )

    if myLoan then
      return myLoan
    else
      return false
    end
  end,
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
  exports["mythic-base"]:RegisterComponent("Loans", _LOANS)
end)

function GetLoanByID(loanId, stateId)
  local fetchLoanById = MySQL.single.await(
    "SELECT * FROM loans WHERE _id = ? AND SID = ?",
    { loanId, stateId }
  )

  if fetchLoanById then
    return fetchLoanById
  else
    return false
  end
end

function UpdateLoanById(loanId, update)
  --build out the update query, update k = row v = value

  local Query = [[
    UPDATE loans
    SET
  ]]
  local QueryData = {}
  for k, v in pairs(update) do
    table.insert(QueryData, k .. " = " .. '?')
  end
  Query = Query .. table.concat(QueryData, ", ") .. " WHERE _id = " .. '?'

  local QueryData = {}
  for k, v in pairs(update) do
    table.insert(QueryData, v)
  end

  table.insert(QueryData, loanId)

  local updateLoan = MySQL.update.await(Query, QueryData)
  return updateLoan > 0
end
