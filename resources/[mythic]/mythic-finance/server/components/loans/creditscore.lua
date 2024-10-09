function GetCharacterCreditScore(stateId)
  local myCreditScore = MySQL.single.await("SELECT Score FROM loans_credit_scores WHERE SID = @SID", {
    ['@SID'] = stateId
  })

  if myCreditScore then
    return myCreditScore.Score
  else
    return _creditScoreConfig.default
  end
end

function SetCharacterCreditScore(stateId, score)
  local p = promise.new()

  if score > _creditScoreConfig.max then
    score = _creditScoreConfig.max
  end

  if score < _creditScoreConfig.min then
    score = _creditScoreConfig.min
  end

  local doesCharHaveScore = MySQL.single.await("SELECT * FROM loans_credit_scores WHERE SID = @SID", {
    ['@SID'] = stateId
  })

  if doesCharHaveScore then
    local ranQuery = MySQL.update.await("UPDATE loans_credit_scores SET Score = @Score WHERE SID = @SID", {
      ['@Score'] = score,
      ['@SID'] = stateId
    })
    return ranQuery > 0
  else
    local ranQuery = MySQL.insert.await("INSERT INTO loans_credit_scores (SID, Score) VALUES (@SID, @Score)", {
      ['@SID'] = stateId,
      ['@Score'] = score
    })
    return ranQuery > 0
  end
end

function IncreaseCharacterCreditScore(stateId, amount)
  local creditScore = GetCharacterCreditScore(stateId)
  return SetCharacterCreditScore(stateId, math.min(_creditScoreConfig.max, creditScore + amount))
end

function DecreaseCharacterCreditScore(stateId, amount)
  local creditScore = GetCharacterCreditScore(stateId)
  return SetCharacterCreditScore(stateId, math.max(_creditScoreConfig.min, creditScore - amount))
end
