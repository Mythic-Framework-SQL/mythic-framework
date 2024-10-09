function UpdateCharacterCasinoStats(source, statType, isWin, amount)
    local char = Fetch:Source(source)
    if char then
        local char = char:GetData("Character")
        local winColumn = string.format("AmountWon_%s", statType)
        local lossColumn = string.format("AmountLost_%s", statType)

        local query
        if isWin then
            query = string.format([[
                INSERT INTO casino_statistics (SID, TotalAmountWon, %s)
                VALUES (@sid, @amount, @amount)
                ON DUPLICATE KEY UPDATE
                TotalAmountWon = TotalAmountWon + @amount,
                %s = %s + @amount
            ]], winColumn, winColumn, winColumn)
        else
            query = string.format([[
                INSERT INTO casino_statistics (SID, TotalAmountLost, %s)
                VALUES (@sid, @amount, @amount)
                ON DUPLICATE KEY UPDATE
                TotalAmountLost = TotalAmountLost + @amount,
                %s = %s + @amount
            ]], lossColumn, lossColumn, lossColumn)
        end

        local params = {
            ['@sid'] = sid,
            ['@amount'] = amount
        }

        local affectedRows = MySQL.insert.await(query, params)

        if affectedRows > 0 then
            return true
        else
            return false
        end
    end
    return false
end


function SaveCasinoBigWin(source, machine, prize, data)
    local char = Fetch:Source(source)
    if char then
        local char = char:GetData("Character")
        local query = [[
            INSERT INTO casino_bigwins (Type, Time, SID, First, Last, ID, Prize, MetaData)
            VALUES (@type, @time, @sid, @first, @last, @id, @prize, @metadata)
        ]]

        local params = {
            ['@type'] = machine,
            ['@time'] = os.time(),
            ['@sid'] = char:GetData("SID"),
            ['@first'] = char:GetData("First"),
            ['@last'] = char:GetData("Last"),
            ['@id'] = char:GetData("ID"),
            ['@prize'] = prize,
            ['@metadata'] = json.encode(data)  
        }

        local affectedRows = MySQL.insert.await(query, params)
        return affectedRows > 0
    end
    return false
end