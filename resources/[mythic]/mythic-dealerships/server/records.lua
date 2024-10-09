-- Dealership Sale Records

DEALERSHIPS.Records = {
    Get = function(self, dealership)
        if _dealerships[dealership] then
            local p = promise.new()
            MySQL.Async.fetchAll('SELECT * FROM dealer_records WHERE dealership = @dealership ORDER BY time DESC LIMIT 100', {
                ['@dealership'] = dealership
            }, function(results)
                if results then
                    p:resolve(results)
                else
                    p:resolve(false)
                end
            end)
            return Citizen.Await(p)
        end
        return false
    end,
    Create = function(self, dealership, document)
        if type(document) == 'table' then
            document.dealership = dealership
            local p = promise.new()
            MySQL.Async.execute('INSERT INTO dealer_records SET ?', document, function(affectedRows)
                p:resolve(affectedRows > 0)
            end)
            return Citizen.Await(p)
        end
        return false
    end,
    CreateBuyBack = function(self, dealership, document)
        if type(document) == 'table' then
            document.dealership = dealership
            local p = promise.new()
            MySQL.Async.execute('INSERT INTO dealer_records_buybacks SET ?', document, function(affectedRows)
                p:resolve(affectedRows > 0)
            end)
            return Citizen.Await(p)
        end
        return false
    end,
}