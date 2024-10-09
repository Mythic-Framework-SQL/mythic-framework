AddEventHandler('Proxy:Shared:RegisterReady', function()
    exports['mythic-base']:RegisterComponent('EntityTypes', ENTITYTYPES)
end)

ENTITYTYPES = {
    Get = function(self, cb)
        MySQL.query('SELECT * FROM entitytypes', {}, function(results)
            if not results then return end
            cb(results)
        end)
    end,
    GetID = function(self, id, cb)
        cb(LoadedEntitys[id])
    end
}